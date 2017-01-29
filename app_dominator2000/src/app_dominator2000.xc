#include <platform.h>
#include <print.h>
#include <xs1.h>
#include <string.h>
#include <xscope.h>
#include <stdlib.h> //_Exit()
#include "pwm_wide.h"
#include "buttons.h"
#include "quadrature.h"
#include "resistor.h"
#include "pwm_fast.h"
#include "decode_main.h"

#define PWM_PORT_BITS_N			4
#define PWM_DEPTH_BITS_N		8			//For wide PWM
#define PWM_WIDE_FREQ_HZ		500

#define MAX_MP3_FRAME_SIZE	2048	//samples
#define UPSAMPLE_RATIO			8

out port p_leds = XS1_PORT_4F;
in port p_butt = XS1_PORT_4E;
port p_adc = XS1_PORT_1I;
//buffered out port:32 p_pwm_fast = XS1_PORT_1J;
buffered out port:32 p_pwm_fast = XS1_PORT_1E;


in port p_quadrature[2] = {XS1_PORT_1G, XS1_PORT_1H};

#define PERIODIC_TIMER	8000000	//80ms

[[combinable]]
void app(static const unsigned port_bits, client i_buttons_t i_buttons, unsigned duties[PWM_PORT_BITS_N],
	client i_quadrature_t i_quadrature, client i_resistor_t i_resistor) {
	button_event_t button_event[MAX_INPUT_PORT_BITS] = {0};
	duties[0] = 0;
	duties[1] = 0;
	duties[2] = 0;
	duties[3] = 0;

	timer t_periodic;
	int time_periodic_trigger;

	int new_duty = 0x1;
	int led_index = 1;

	t_periodic :> time_periodic_trigger;

	while(1) {
		select {
			case i_buttons.buttons_event():
				i_buttons.get_state(button_event, 0);
				//printstrln("New buttons:");
				for (int i=0; i<port_bits; i++) {
					//printintln(button_event[i]);
				}
				if ((button_event[0] == BUTTON_PRESSED) && led_index < 3) {
					led_index++;
				}
				if ((button_event[1] == BUTTON_PRESSED) && led_index > 0) {
					led_index--;
				}
				break;

			case i_quadrature.rotate_event():
				static int last_rotation = 0;
				int rotation = i_quadrature.get_count();
				if (last_rotation != rotation) {
					printstrln("");
					last_rotation = rotation;
				}
				if (rotation == 1) printstr("+");
				if (rotation == -1) printstr("-");
				break;

			case i_resistor.value_change_event():
				printintln(i_resistor.get_val());
				break;

			case t_periodic when timerafter(time_periodic_trigger + PERIODIC_TIMER) :> time_periodic_trigger:
				duties[led_index] = new_duty;
				new_duty <<= 1;
				//printintln(new_duty);
				if (new_duty == 0x100) new_duty = 0x1;


				break;
		}
	}
}


#include "malibu_diet.h"
#include "sine_left.h"
//#define MP3_ARRAY_NAME	malibu_diet_stripped_mp3
#define MP3_ARRAY_NAME	__8khz_250ms_left_44Khz_mp3

unsigned malibu_idx = 0;

void mp3_player(streaming chanend c_mp3_chan) {
	int data_available_to_send = 417;
	int index = 0;

	while(1){
		//outuint(c_mp3_chan, data_available_to_send);
  	c_mp3_chan <: data_available_to_send;
  	sout_char_array(c_mp3_chan, &MP3_ARRAY_NAME[index], data_available_to_send);
		if (malibu_idx == sizeof(MP3_ARRAY_NAME)) _Exit(0);
		//printintln(index);
		index += data_available_to_send;
		c_mp3_chan <: 0xDEADBEEF;
		while(1);
	}
	c_mp3_chan <: 0xDEADBEEF;
}

void src(short * input_array, unsigned n_in_samples, unsigned char * output_array ) {
	for (int i = 0; i < n_in_samples; i++){
		unsigned out_idx = i << 3; //upsample by 8
		short sample = input_array[i];
		unsigned char duty = (sample >> 8) + 128;
		output_array[out_idx + 0] = duty;
		output_array[out_idx + 1] = duty;
		output_array[out_idx + 2] = duty;
		output_array[out_idx + 3] = duty;
		output_array[out_idx + 4] = duty;
		output_array[out_idx + 5] = duty;
		output_array[out_idx + 6] = duty;
		output_array[out_idx + 7] = duty;		          	
	}
}


unsigned char pwm_test[] = { 0 , 10, 20, 30, 40, 50, 60, 70, 80, 90 , 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240, 250};

void pcm_post_process(chanend c_pcm_chan, streaming chanend c_pwm_fast) {

	short sample_buff[2][32];		//Stereo = 32x l+r words
	unsigned char duty_dbl_buff[2][MAX_MP3_FRAME_SIZE * UPSAMPLE_RATIO];
	int duty_dbl_buff_idx = 0;

	unsigned index;
	unsigned sample_cnt;
	short sample;

	unsigned frame_ready = 0;

	unsigned channel = 0; 	//0 = left, 1 = right

	unsigned total_samps_this_frame = 0;
	unsigned total_duties = 0;

	c_pwm_fast :> int _; //Consume ready token

	//Initial values into table at startup
	c_pwm_fast <: (int)pwm_test;
	c_pwm_fast <: sizeof(pwm_test);

	printstrln("pcm_post_process started");

	while(1){
		select {
			case c_pcm_chan :> int word:
	    		sample = (word >> 16);
  				index = word & 0xFFFF;
  				sample_buff[channel][index >> 1] = sample;
  				channel ^= 1;
  				//fills in funny order with last entry being 35
  				if (index == 35) {
						frame_ready = 1;
						total_samps += 32;
						printstr("total_samps_this_frame:"); printintln(total_samps_this_frame);
						for (int i = 0; i < 32; i++) {
							printint(sample_buff[0][i]); printstr(", "); printintln(sample_buff[1][i]);
						}
  				}
  				//printint(total_samps_this_frame); printstr(" index:"); printintln(index);
  				//printint(total_samps_this_frame); printstr(" pcm:"); printintln(sample);
#if 0
  				if (0) {

	          //Do SRC
	          src(sample_buff, sample_cnt, duty_dbl_buff[duty_dbl_buff_idx]);

	          c_pwm_fast :> int _; //Synch - wait for PWM to say it's ready
	          unsigned duty_count = sample_cnt << 3;
	          total_dutues += duty_count;
	          //printintln(total_dutues);

	          //Send buffer to PWM
	          c_pwm_fast <: (int)duty_dbl_buff[duty_dbl_buff_idx];
	          c_pwm_fast <: duty_count;
	          duty_dbl_buff_idx ^= 1;		//Swap buffers
	        }
#endif
		    break;
		}
	}
}

int main(void) {
	unsigned duties[PWM_PORT_BITS_N] = {10, 255, 0, 100};
	volatile unsigned * unsafe duties_ptr;

	i_buttons_t i_buttons;
	i_quadrature_t i_quadrature;
	i_resistor_t i_resistor;
	streaming chan c_pwm_fast;
	streaming chan c_mp3_chan;
	chan c_pcm_chan;

	unsafe{ duties_ptr = duties;}


	par {
		[[combine]] par {
			//pwm_wide_unbuffered(p_leds, PWM_PORT_BITS_N, PWM_WIDE_FREQ_HZ, PWM_DEPTH_BITS_N, duties_ptr);
			//port_input_debounced(p_butt, 4, i_buttons);
			//quadrature(p_quadrature, i_quadrature);
		}
		app(4, i_buttons, duties, i_quadrature, i_resistor);

		//resistor_reader(p_adc, i_resistor);

		mp3_player(c_mp3_chan);
		decoderMain(c_pcm_chan, c_mp3_chan);
		pcm_post_process(c_pcm_chan, c_pwm_fast);
		pwm_fast(c_pwm_fast, p_pwm_fast);

	}
	return 0;
}