#include <us8_src.h>
#include <string.h>
#include <print.h>
#include "src_fir_inner_loop_asm.h"
#include "coeffs.h"

int stage_0_delay[STAGE_0_FIR_LENGTH] = {0}; //Double what it needs to be for circular buffer simulation
int stage_1_delay[STAGE_1_FIR_LENGTH] = {0};
int stage_2_delay[STAGE_2_FIR_LENGTH] = {0};


void src_init(src_ctrl_t *src_ctrl)
{

    //Setup delay lines
    src_ctrl->delay_base[0] = stage_0_delay;
    memset(stage_0_delay, 0, sizeof(stage_0_delay));
    src_ctrl->delay_len[0] = STAGE_0_FIR_LENGTH / 2;
    src_ctrl->delay_idx[0] = 0;

    src_ctrl->delay_base[1] = stage_1_delay;
    memset(stage_1_delay, 0, sizeof(stage_1_delay));
    src_ctrl->delay_len[1] = STAGE_1_FIR_LENGTH / 2;
    src_ctrl->delay_idx[1] = 0;


    src_ctrl->delay_base[2] = stage_2_delay;
    memset(stage_2_delay, 0, sizeof(stage_2_delay));
    src_ctrl->delay_len[2] = STAGE_2_FIR_LENGTH / 2;
    src_ctrl->delay_idx[2] = 0;

    //Setup loops and coeffs
    src_ctrl->inner_loops[0] = STAGE_0_FIR_LENGTH / 2;
    src_ctrl->inner_loops[1] = STAGE_1_FIR_LENGTH / 2;
    src_ctrl->inner_loops[2] = STAGE_2_FIR_LENGTH / 2;

    src_ctrl->num_coeffs[0] = STAGE_0_FIR_LENGTH / 2; //per phase
    src_ctrl->num_coeffs[1] = STAGE_1_FIR_LENGTH / 2;
    src_ctrl->num_coeffs[2] = STAGE_2_FIR_LENGTH / 2;

    src_ctrl->coeffs[0] = (int *) stage_0_fir_coefs;
    src_ctrl->coeffs[1] = (int *) stage_1_fir_coefs;
    src_ctrl->coeffs[2] = (int *) stage_2_fir_coefs;

    src_ctrl->phase[0] = 0;
    src_ctrl->phase[1] = 0;
    src_ctrl->phase[2] = 0;
}

//Global for 64b alignment 
int result; //Intermediate result

//asm inner takes: data, coeffs, return ptr, count and processes 2 samples at a time
void src_process(int in_samp, int out_buff[], src_ctrl_t *src_ctrl){
    //First stage steep filter up by 2
    int stage_0_out[2];

    //Push sample in circular buffer
    //printhexln(src_ctrl); 
    int * delay_base = src_ctrl->delay_base[0] + src_ctrl->delay_idx[0]; 

    *delay_base = in_samp;
    *(delay_base + src_ctrl->delay_len[0]) = in_samp;

    for (int i=0; i<2; i++) {
        //Do the FIR
        //printintln(insamp);
        //printintln(src_ctrl->inner_loops[0]);
        if ((unsigned)delay_base & 0b0100) {
            src_fir_inner_loop_asm_odd(
                 src_ctrl->delay_base[0] + src_ctrl->delay_idx[0]
                ,src_ctrl->coeffs[0] + (src_ctrl->phase[0] * src_ctrl->num_coeffs[0]) //Polyphase bit
                ,&stage_0_out[i]
                ,src_ctrl->inner_loops[0]);
        }
        else {
            src_fir_inner_loop_asm(
                 src_ctrl->delay_base[0] + src_ctrl->delay_idx[0]
                ,src_ctrl->coeffs[0] + (src_ctrl->phase[0] * src_ctrl->num_coeffs[0]) //Polyphase bit
                ,&stage_0_out[i]
                ,src_ctrl->inner_loops[0]);
        }
        //printintln(stage_0_out[i]);
        src_ctrl->phase[0] ^= 1;   //Swap phase of polyphase filter
    }
    src_ctrl->delay_idx[0] += 1; 
    if (src_ctrl->delay_idx[0] == src_ctrl->delay_len[0]) src_ctrl->delay_idx[0] = 0;

    //Second stage relaxed filter up by 2
    int stage_1_out[4];
    for (int i=0; i<4; i++) {
        //Push sample in circular buffer
        int * delay_base = src_ctrl->delay_base[1] + src_ctrl->delay_idx[1]; 
        *delay_base = stage_0_out[i >> 1];
        *(delay_base + src_ctrl->delay_len[1]) = stage_0_out[i >> 1];

        //printintln(src_ctrl->inner_loops[1]);
        //Do the FIR
        if ((unsigned)delay_base & 0b0100) {
            src_fir_inner_loop_asm_odd(
             delay_base
            ,src_ctrl->coeffs[1] + (src_ctrl->phase[1] * src_ctrl->num_coeffs[1]) //Polyphase bit
            ,&stage_1_out[i]
            ,src_ctrl->inner_loops[1]);
        }
        else {
            src_fir_inner_loop_asm(
             delay_base
            ,src_ctrl->coeffs[1] + (src_ctrl->phase[1] * src_ctrl->num_coeffs[1]) //Polyphase bit
            ,&stage_1_out[i]
            ,src_ctrl->inner_loops[1]);
        }
        //printintln(stage_1_out[i]);

        src_ctrl->phase[1] ^= 1;  //Swap phase of polyphase filter
        if (i & 1) {
            src_ctrl->delay_idx[1] += 1;
            if (src_ctrl->delay_idx[1] == src_ctrl->delay_len[1]) src_ctrl->delay_idx[1] = 0;
        }
    }

    //Third stage relaxed filter up by 2
    for (int i=0; i<8; i++) {
        //Push sample in circular buffer
        int * delay_base = src_ctrl->delay_base[2] + src_ctrl->delay_idx[2]; 

        *delay_base = stage_1_out[i >> 1];
        *(delay_base + src_ctrl->delay_len[2]) = stage_1_out[i >> 1];

        //printintln(src_ctrl->inner_loops[2]);
        //Do the FIR
        if ((unsigned)delay_base & 0b0100) {
            src_fir_inner_loop_asm_odd(
                 src_ctrl->delay_base[2] + src_ctrl->delay_idx[2]
                ,src_ctrl->coeffs[2] + (src_ctrl->phase[2] * src_ctrl->num_coeffs[2]) //Polyphase bit
                ,&out_buff[i]
                ,src_ctrl->inner_loops[2]);
        }
        else {
            src_fir_inner_loop_asm(
                 src_ctrl->delay_base[2] + src_ctrl->delay_idx[2]
                ,src_ctrl->coeffs[2] + (src_ctrl->phase[2] * src_ctrl->num_coeffs[2]) //Polyphase bit
                ,&out_buff[i]
                ,src_ctrl->inner_loops[2]);
        }
        //printintln(out_buff[i]);

        src_ctrl->phase[2] ^= 1;  //Swap phase of polyphase filter
        if (i & 1) {
            src_ctrl->delay_idx[2] += 1;
            if (src_ctrl->delay_idx[2] == src_ctrl->delay_len[2]) src_ctrl->delay_idx[2] = 0;
        }
    }
}
