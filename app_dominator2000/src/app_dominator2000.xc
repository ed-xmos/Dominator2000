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

#define MAX_MP3_FRAME_SIZE	1152	//samples
#define UPSAMPLE_RATIO			8

out port p_leds = XS1_PORT_4F;
in port p_butt = XS1_PORT_4E;
port p_adc = XS1_PORT_1I;
buffered out port:32 p_pwm_fast = XS1_PORT_1J; //X0D25
///buffered out port:32 p_pwm_fast = XS1_PORT_1E; //X0D12


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
#define MP3_ARRAY_NAME	malibu_diet_stripped_mp3
//#define MP3_ARRAY_NAME	__8khz_250ms_left_44Khz_mp3

#define MP3_DATA_TRANSFER_SIZE	1500 //Must be bigger than one frame (417B)



unsigned malibu_idx = 0;

void mp3_player(streaming chanend c_mp3_chan) {
	unsigned data_file_size = sizeof(MP3_ARRAY_NAME);
	unsigned index = 0; //How far through the file we have gone

	printint(data_file_size);
	while(data_file_size){
		unsigned data_size_this_frame;
		if (data_file_size > MP3_DATA_TRANSFER_SIZE) {
			data_size_this_frame = MP3_DATA_TRANSFER_SIZE;
			data_file_size -= MP3_DATA_TRANSFER_SIZE;
		}
		else {
			data_size_this_frame = data_file_size;
			data_file_size = 0;
		}
  	c_mp3_chan <: data_size_this_frame;
  	sout_char_array(c_mp3_chan, &MP3_ARRAY_NAME[index], data_size_this_frame);
		printintln(index);
		index += data_size_this_frame;
	}
	c_mp3_chan <: 0xDEADBEEF;
	printstrln("MP3 player sent terminate\n");

	//printstrln("MP3 player NOT sent terminate\n");

}

void src(short * input_array, unsigned n_in_samples, unsigned char * output_array ) {
	for (int i = 0; i < n_in_samples; i++){
		unsigned out_idx = i * UPSAMPLE_RATIO;
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

	short sample_buff[MAX_MP3_FRAME_SIZE];		//Stereo = 32x l+r words
	unsigned char duty_dbl_buff[2][MAX_MP3_FRAME_SIZE * UPSAMPLE_RATIO];
	int duty_dbl_buff_idx = 0;

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
					unsigned mp3_subframe_index;
					short tmp_samp;
					static short sample[2];
					static unsigned channel = 0; 	//0 = left, 1 = right

	    		tmp_samp = (word >> 16);
  				mp3_subframe_index = word & 0xFFFF;
  				sample[channel] = tmp_samp;
  				//When L & R received, mix them together and store into mono sample buff
  				if (channel == 1) {
  					sample_buff[(mp3_subframe_index >> 1) + total_samps_this_frame] = ((sample[0] >> 1) + (sample[1] >> 1));
  				}

  				// L&R are interleaved so it's L followed by R
  				channel ^= 1;

  				//printint(total_samps_this_frame); printstr(" index:"); printintln(mp3_subframe_index);
  				//printint(total_samps_this_frame); printstr(" pcm:"); printintln(sample);

  				//printint((mp3_subframe_index >> 1) + total_samps_this_frame); printstr(","); printintln(tmp_samp);

  				//fills in funny order with last entry of 64 sample block being index 35 for stereo
  				if (mp3_subframe_index == 35) {
						total_samps_this_frame += 32;
						//printstr("total_samps_this_frame:"); printintln(total_samps_this_frame);
  				}

  				if (total_samps_this_frame == MAX_MP3_FRAME_SIZE){
  					//printstr("Ready for SRC\n");
  					//for(int i = 0; i < total_samps_this_frame; i++) {printint(sample_buff[i]); printstr(", ");} printstrln("");
	          //Do SRC
	          src(sample_buff, total_samps_this_frame, duty_dbl_buff[duty_dbl_buff_idx]);

	          c_pwm_fast :> int _; //Synch - wait for PWM to say it's ready
	          unsigned duty_count = total_samps_this_frame * UPSAMPLE_RATIO;
	          total_duties += duty_count;
	          //printintln(total_dutues);

	          //Send buffer to PWM
	          c_pwm_fast <: (int)duty_dbl_buff[duty_dbl_buff_idx];
	          c_pwm_fast <: duty_count;
	          duty_dbl_buff_idx ^= 1;		//Swap buffers
	          total_samps_this_frame = 0; //Reset frame
	        }
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
			pwm_wide_unbuffered(p_leds, PWM_PORT_BITS_N, PWM_WIDE_FREQ_HZ, PWM_DEPTH_BITS_N, duties_ptr);
			port_input_debounced(p_butt, 4, i_buttons);
			quadrature(p_quadrature, i_quadrature);
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