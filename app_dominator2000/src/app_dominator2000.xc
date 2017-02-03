#include <platform.h>
#include <print.h>
#include <xs1.h>
#include <string.h>
#include <xscope.h>
#include <stdlib.h> //_Exit()
#include <stdio.h>
#include "pwm_wide.h"
#include "buttons.h"
#include "quadrature.h"
#include "resistor.h"
#include "pwm_fast.h"
#include "decode_main.h"

#include "filesystem.h"
#include "qspi_flash_storage_media.h"
#include <quadflash.h>
#include <QuadSpecMacros.h>

#define PWM_PORT_BITS_N			4
#define PWM_DEPTH_BITS_N		8			//For wide PWM
#define PWM_WIDE_FREQ_HZ		500

#define MAX_MP3_FRAME_SIZE	1152	//samples
#define UPSAMPLE_RATIO			8

fl_QSPIPorts qspi_flash_ports = {
  PORT_SQI_CS,
  PORT_SQI_SCLK,
  PORT_SQI_SIO,
  on tile[0]: XS1_CLKBLK_1
};

on tile[0]: out port p_leds = XS1_PORT_4F;
on tile[0]: in port p_butt = XS1_PORT_4E;
on tile[0]: port p_adc = XS1_PORT_1I;
on tile[0]: buffered out port:32 p_pwm_fast = XS1_PORT_1J; //X0D25
///buffered out port:32 p_pwm_fast = XS1_PORT_1E; //X0D12


on tile[0]: in port p_quadrature[2] = {XS1_PORT_1G, XS1_PORT_1H};

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


#define BUFFER_SIZE      50
#define PARTIAL_READ_LEN 5
#define BUFFER_PATTERN   0xAAAAAAAA

unsigned malibu_idx = 0;

void mp3_player(client interface fs_basic_if i_fs, streaming chanend c_mp3_chan) {

  fs_result_t result;

	printf("Mounting filesystem...\n");
  result = i_fs.mount();
  if (result != FS_RES_OK) {
    printf("result = %d\n", result);
    exit(1);
  }

  printf("Opening file...\n");
  char filename[] = "HNDCLP.MP3";
  result = i_fs.open(filename, sizeof(filename));
  if (result != FS_RES_OK) {
    printf("result = %d\n", result);
    exit(1);
  }

  printf("Getting file size...\n");
  size_t file_size;
  result = i_fs.size(file_size);
  if (result != FS_RES_OK) {
    printf("result = %d\n", result);
    exit(1);
  }

  uint8_t buf[BUFFER_SIZE];

  printf("Reading part of file...\n");
  if(file_size < PARTIAL_READ_LEN) printf("Partial read length exceeds file size!\n");
  size_t bytes_to_read = 0;
  size_t num_bytes_read = 0;
  // Init buffer with pattern
  memset(buf, BUFFER_PATTERN, BUFFER_SIZE);
  bytes_to_read = PARTIAL_READ_LEN;
  result = i_fs.read(buf, sizeof(buf), bytes_to_read, num_bytes_read);
  if (result != FS_RES_OK) {
    printf("result = %d\n", result);
    exit(1);
  }

  printf("Attempted to read %d byte(s) of %d byte file.\n"
               "Read %d byte(s) of file:\n",
               bytes_to_read, file_size, num_bytes_read);
  for (int i = 0; i < num_bytes_read; i++) {
    printf("%c", buf[i]);
  }
  printf("\n");
  if (bytes_to_read != num_bytes_read) {
    exit(1);
  }
  // Check end of buffer hasn't been overwritten
  for (int i = bytes_to_read; i < BUFFER_SIZE; i++) {
    if (buf[i] != (uint8_t)BUFFER_PATTERN) {
      printf("Unexpected write to buffer at index %d, "
                   "found %x, expected %x!\n",
                   i, buf[i], (uint8_t)BUFFER_PATTERN);
    }
  }

  printf("Seeking back to beginning of file...\n");
  result = i_fs.seek(0, 1);
  if (result != FS_RES_OK) {
    printf("result = %d\n", result);
    exit(1);
  }

	unsigned data_file_size = sizeof(MP3_ARRAY_NAME);
	unsigned index = 0; //How far through the file we have gone

	printf("Loading mp3 file %s\n", filename);

	memset(MP3_ARRAY_NAME, 0, data_file_size);
	for (int i=0; i<250; i++) {
		unsigned char tmp_buff[512];
	  result = i_fs.read(tmp_buff, 512, 512, num_bytes_read);
	  if (result != FS_RES_OK) {
	    printf("result = %d\n", result);
	    exit(1);
	  }
		printintln((i * 512));
	  memcpy(MP3_ARRAY_NAME + (i * 512), tmp_buff, 512);
	}
  


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
	i_buttons_t i_buttons;
	i_quadrature_t i_quadrature;
	i_resistor_t i_resistor;
	streaming chan c_pwm_fast;
	streaming chan c_mp3_chan;
	chan c_pcm_chan;
	interface fs_basic_if i_fs[1];
  interface fs_storage_media_if i_media;

	par {
  	on tile[0]: {
  		unsigned duties[PWM_PORT_BITS_N] = {10, 255, 0, 100};
			volatile unsigned * unsafe duties_ptr;
			unsafe{ duties_ptr = duties;}
		  fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_ISSI_IS25LQ016B;	//What we have on the explorer board
		  //fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_SPANSION_S25FL116K;	//What we have on the explorer board

			par {			
				[[combine]] par {
					pwm_wide_unbuffered(p_leds, PWM_PORT_BITS_N, PWM_WIDE_FREQ_HZ, PWM_DEPTH_BITS_N, duties_ptr);
					port_input_debounced(p_butt, 4, i_buttons);
					quadrature(p_quadrature, i_quadrature);
				}
				app(4, i_buttons, duties, i_quadrature, i_resistor);

				//resistor_reader(p_adc, i_resistor);

				qspi_flash_fs_media(i_media, qspi_flash_ports, qspi_spec, 512);
		    filesystem_basic(i_fs, 1, FS_FORMAT_FAT12, i_media);

				mp3_player(i_fs[0], c_mp3_chan);
				decoderMain(c_pcm_chan, c_mp3_chan);
				pcm_post_process(c_pcm_chan, c_pwm_fast);
				pwm_fast(c_pwm_fast, p_pwm_fast);
			}
		}
		on tile[1]: {

		}


	}
	return 0;
}