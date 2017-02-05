#include <us8_src.h>
#include <string.h>
#include "src_fir_inner_loop_asm.h"

#define STAGE_0_FIR_LENGTH  64
#define STAGE_1_FIR_LENGTH  32
#define STAGE_2_FIR_LENGTH  32

int stage_0_delay[STAGE_0_FIR_LENGTH];
int stage_1_delay[STAGE_1_FIR_LENGTH];
int stage_2_delay[STAGE_2_FIR_LENGTH];

int src_s0_fir_coeffs[STAGE_0_FIR_LENGTH];
int src_s1_fir_coeffs[STAGE_1_FIR_LENGTH];
int src_s2_fir_coeffs[STAGE_2_FIR_LENGTH];

void src_init(src_ctrl_t *src_ctrl)
{

    //Setup delay line
    src_ctrl->delay_base[0] = stage_0_delay;
    memset(stage_0_delay, 0, sizeof(stage_0_delay));
    src_ctrl->delay_len[0] = STAGE_0_FIR_LENGTH;
    src_ctrl->delay_idx[0] = 0;

    src_ctrl->delay_base[1] = stage_1_delay;
    memset(stage_1_delay, 0, sizeof(stage_1_delay));
    src_ctrl->delay_len[1] = STAGE_1_FIR_LENGTH;
    src_ctrl->delay_idx[1] = 0;


    src_ctrl->delay_base[2] = stage_2_delay;
    memset(stage_2_delay, 0, sizeof(stage_2_delay));
    src_ctrl->delay_len[2] = STAGE_2_FIR_LENGTH;
    src_ctrl->delay_idx[2] = 0;

    //Setup loops and coeffs
    src_ctrl->inner_loops[0] = STAGE_0_FIR_LENGTH / 2;
    src_ctrl->inner_loops[1] = STAGE_1_FIR_LENGTH / 2;
    src_ctrl->inner_loops[2] = STAGE_2_FIR_LENGTH / 2;

    src_ctrl->num_coeffs[0] = STAGE_0_FIR_LENGTH;
    src_ctrl->num_coeffs[1] = STAGE_1_FIR_LENGTH;
    src_ctrl->num_coeffs[2] = STAGE_2_FIR_LENGTH;

    src_ctrl->coeffs[0] = src_s0_fir_coeffs;
    src_ctrl->coeffs[1] = src_s1_fir_coeffs;
    src_ctrl->coeffs[2] = src_s2_fir_coeffs;

    src_ctrl->phase[0] = 0;
    src_ctrl->phase[1] = 0;
    src_ctrl->phase[2] = 0;
}

//asm inner takes: data, coeffs, return ptr, count and processes 2 samples at a time

unsigned src_process(int in_samp, int out_buff[], src_ctrl_t *src_ctrl){

    //First stage steep filter up by 2
    int stage_0_out[2];
    //Push sample in circular buffer
    *(src_ctrl->delay_base[0] + src_ctrl->delay_idx[0]) = in_samp;
    *(src_ctrl->delay_base[0] + src_ctrl->delay_idx[0] + src_ctrl->delay_len[0]) = in_samp;

    //Do the FIR
    src_fir_inner_loop_asm(
         &stage_0_out[0]
        ,src_ctrl->coeffs[0] + (src_ctrl->phase[0] * (src_ctrl->num_coeffs[0] / 2)) //Polyphase bit
        ,src_ctrl->delay_base[0] + src_ctrl->delay_idx[0]
        ,src_ctrl->inner_loops[0]);
    src_ctrl->phase[0] != 1;   //Swap phase of polyphase filter

    src_ctrl->delay_idx[0]++;
    if (src_ctrl->delay_idx[0] == src_ctrl->delay_len[0]) src_ctrl->delay_idx[0] = 0;

    //Second stage relaxed filter up by 2
    int stage_1_out[4];
    for (int i=0; i<2; i++) {
        //Push sample in circular buffer
        *(src_ctrl->delay_base[1] + src_ctrl->delay_idx[1]) = stage_1_out[i];
        *(src_ctrl->delay_base[1] + src_ctrl->delay_idx[1] + src_ctrl->delay_len[1]) = stage_1_out[i];

        //Do the FIR
        src_fir_inner_loop_asm(
             &stage_1_out[i * 2]
            ,src_ctrl->coeffs[1] + (src_ctrl->phase[1] * (src_ctrl->num_coeffs[1] / 2)) //Polyphase bit
            ,src_ctrl->delay_base[1] + src_ctrl->delay_idx[1]
            ,src_ctrl->inner_loops[1]);
        src_ctrl->phase[1] != 1;  //Swap phase of polyphase filter

        src_ctrl->delay_idx[1]++;
        if (src_ctrl->delay_idx[1] == src_ctrl->delay_len[1]) src_ctrl->delay_idx[1] = 0;
    }

    //Third stage relaxed filter up by 2
    for (int i=0; i<4; i++) {
        //Push sample in circular buffer
        *(src_ctrl->delay_base[2] + src_ctrl->delay_idx[2]) = out_buff[i];
        *(src_ctrl->delay_base[2] + src_ctrl->delay_idx[2] + src_ctrl->delay_len[2]) = out_buff[i];

        //Do the FIR
        src_fir_inner_loop_asm(
             &out_buff[i * 2]
            ,src_ctrl->coeffs[2] + (src_ctrl->phase[2] * (src_ctrl->num_coeffs[2] / 2)) //Polyphase bit
            ,src_ctrl->delay_base[2] + src_ctrl->delay_idx[2]
            ,src_ctrl->inner_loops[2]);
        src_ctrl->phase[2] != 1;  //Swap phase of polyphase filter

        src_ctrl->delay_idx[2]++;
        if (src_ctrl->delay_idx[2] == src_ctrl->delay_len[2]) src_ctrl->delay_idx[2] = 0;
    }
}
