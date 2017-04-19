#include <xs1.h>
#include <platform.h>
#include <string.h>
#include <xscope.h>
#include <stdlib.h> //_Exit()
#include <stdio.h>
#include <print.h>
#include "audio.h"
#include "us8_src.h"
#include "dsp.h"

#define MP3_DATA_TRANSFER_SIZE	1500 //Must be bigger than one frame (417B)
#define MP3_PCM_FRAME_SIZE	512	//samples. Must be multiple of 32
#define UPSAMPLE_RATIO			8

void mp3_player(client interface fs_basic_if i_fs, streaming chanend c_mp3_chan, chanend c_mp3_stop
	,server i_mp3_player_t i_mp3_player) {

  fs_result_t result;
  //This is DOS 8.3 so 16 enough..
  char filename[16] = "PROTONPK.MP3";	//Startup sound


	printf("Mounting filesystem...\n");
  result = i_fs.mount();
  if (result != FS_RES_OK) {
    printf("result = %d\n", result);
    exit(1);
  }

  while (2) {
	  printf("Opening file...\n");
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
	 
	  printf("Seeking back to beginning of file...\n");
	  result = i_fs.seek(0, 1);
	  if (result != FS_RES_OK) {
	    printf("result = %d\n", result);
	    exit(1);
	  }


		printf("Playing mp3 file %s\n", filename);
	  

		unsigned char tmp_buff[512];
		unsigned index = 0; //How far through the file we have gone
		unsigned num_bytes_read = ~0;
		while(num_bytes_read){
			result = i_fs.read(tmp_buff, 512, 512, num_bytes_read);
		  if (result != FS_RES_OK) {
		    printf("File read error: %d\n", result);
		    exit(1);
		  }

	  	c_mp3_chan <: num_bytes_read;
	  	sout_char_array(c_mp3_chan, tmp_buff, num_bytes_read);
			//printintln(index);
			index += num_bytes_read;
#if 0
			if (index > 30000){
				result = i_fs.seek(0, 1);
				index = 0;
				c_mp3_stop <: 1;
			}
#endif
		 	//This polls so we only do if needed
		 	select {
				case i_mp3_player.play_file(const char new_filename[], size_t n):
					memcpy(filename, new_filename, n);
					printf("Opening file(0)...\n");
					result = i_fs.open(filename, sizeof(filename));
					if (result != FS_RES_OK) {
					  printf("result = %d\n", result);
					  exit(1);
					}
					result = i_fs.seek(0, 1);
					index = 0;
					c_mp3_stop <: 1;
					break;
				//drop through
				default:
					break;
			}
		}
		c_mp3_chan <: 0xDEADBEEF;
		printstrln("MP3 player sent terminate\n");

		//This blocks as we want to wait for the next sound
		select {
			case i_mp3_player.play_file(const char new_filename[], size_t n):
				memcpy(filename, new_filename, n);
				printf("Opening file (1)...\n");
				result = i_fs.open(filename, sizeof(filename));
				if (result != FS_RES_OK) {
				  printf("result = %d\n", result);
				  exit(1);
				}
				result = i_fs.seek(0, 1);
				index = 0;
				c_mp3_stop <: 1;
				break;
		}
	} //while (2)
}

#pragma unsafe arrays
static inline void noise_shape(int * input_array, unsigned n_in_samples, unsigned char * output_array ) {
		static int carry = 0;
		for (int i = 0; i < n_in_samples; i++){
			int sample = input_array[i];
			sample <<= 2;	//FIR gain compensation
			if (sample > 0x7f000000) sample = 0x7f000000; //Clip
			sample += carry;
			char sample_byte;
			sample_byte = sample >> 24;
			carry = sample - (sample_byte << 24);
			unsigned char duty = (unsigned char)(sample_byte + 128);
			output_array[i] = duty;
		}
}

#pragma unsafe arrays
static inline void src(short * input_array, unsigned n_in_samples, unsigned char * output_array, src_ctrl_t *src_ctrl ) {
	int post_src_array[UPSAMPLE_RATIO];
	for (int i = 0; i < n_in_samples; i++){
		unsigned out_idx = i * UPSAMPLE_RATIO;
		int sample = (int)input_array[i] << 16;
		src_process(sample, post_src_array, src_ctrl);
		noise_shape(post_src_array, UPSAMPLE_RATIO, &output_array[out_idx]);
	}
}

#if 0
static void src_simple(short * input_array, unsigned n_in_samples, unsigned char * output_array ) {
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
#endif

unsigned char pwm_test[] = { 0 , 10, 20, 30, 40, 50, 60, 70, 80, 90 , 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240, 250};
//MP3 pcm value set upper bit of first byte of index if stereo
#define STEREO_FLAG	0x80
#define BAD_FRAME	0x0100

void pcm_post_process(chanend c_pcm_chan, streaming chanend c_pwm_fast) {

	short sample_buff[MP3_PCM_FRAME_SIZE];		//Stereo = 32x l+r words
	unsigned char duty_dbl_buff[2][MP3_PCM_FRAME_SIZE * UPSAMPLE_RATIO];
	int duty_dbl_buff_idx = 0;

	unsigned total_samps_this_frame = 0;
	unsigned total_duties = 0;

	src_ctrl_t src_ctrl;
	src_init(&src_ctrl);

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
					unsigned is_stereo;

	    		tmp_samp = (word >> 16);
  				mp3_subframe_index = word & 0xFFFF;
  				if (mp3_subframe_index & STEREO_FLAG) {
  					mp3_subframe_index &= ~STEREO_FLAG; //Clear stero flag from index
  					is_stereo = 1;
  				}
  				else is_stereo = 	0;
  				sample[channel] = tmp_samp;

  				if (mp3_subframe_index & BAD_FRAME) {
  					total_samps_this_frame = 0;
  					break;
  				}

  				if (is_stereo){
	  				//When L & R received, mix them together and store into mono sample buff
	  				if (channel == 1) {
	  					sample_buff[(mp3_subframe_index >> 1) + total_samps_this_frame] = ((sample[0] >> 1) + (sample[1] >> 1));
	  				}

	  				// L&R are interleaved so it's L followed by R
	  				channel ^= 1;

	  				//printint(total_samps_this_frame); printstr(" index:"); printintln(mp3_subframe_index);
	  				//printint(total_samps_this_frame); printstr(" pcm:"); printintln(sample);
	  				//printint((mp3_subframe_index >> 1) + total_samps_this_frame); printstr(","); printintln(tmp_samp);


	  				//fills in funny order with last entry of 64 sample block being index 35 for stereo, 17 for mono
	  				if (mp3_subframe_index == 35) {
							total_samps_this_frame += 32;
							//printstr("total_samps_this_frame:"); printintln(total_samps_this_frame);
	  				}
	  			}//stereo

	  			else { //mono
	  				sample_buff[mp3_subframe_index + total_samps_this_frame] = sample[0];
	  				if (mp3_subframe_index == 17) {
	  					total_samps_this_frame += 32;
	  				}
	  			}


  				if (total_samps_this_frame == MP3_PCM_FRAME_SIZE){
  					//printstr("Ready for SRC\n");
  					//for(int i = 0; i < total_samps_this_frame; i++) {printint(sample_buff[i]); printstr(", ");} printstrln("");
	          //Do SRC
	          //src_simple(sample_buff, total_samps_this_frame, duty_dbl_buff[duty_dbl_buff_idx]);
						src(sample_buff, total_samps_this_frame, duty_dbl_buff[duty_dbl_buff_idx], &src_ctrl);


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