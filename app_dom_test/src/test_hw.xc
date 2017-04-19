#include <platform.h>
#include <print.h>
#include <xs1.h>
#include <string.h>
#include <xscope.h>
#include <stdlib.h> //_Exit()
#include <stdio.h>
#include "qspi_flash_storage_media.h"
#include <quadflash.h>
#include <QuadSpecMacros.h>
#include "pwm_wide.h"
#include "buttons.h"
#include "quadrature.h"
#include "resistor.h"
#include "pwm_fast.h"
#include "audio.h"
#include "dsp.h"
#include "decode_main.h"


#define PWM_PORT_BITS_N			8
#define PWM_DEPTH_BITS_N		8			//For wide PWM
#define PWM_WIDE_FREQ_HZ		500

fl_QSPIPorts qspi_flash_ports = {
  PORT_SQI_CS,
  PORT_SQI_SCLK,
  PORT_SQI_SIO,
  on tile[0]: XS1_CLKBLK_1
};

on tile[0]: out port p_butt_leds = XS1_PORT_8B; //X0D14..21
on tile[0]: out port p_bargraph = XS1_PORT_16B; //X0D26..27, X0D32..39
on tile[0]: in port p_quadrature[2] = {XS1_PORT_1G, XS1_PORT_1H}; //X0D22,33
on tile[0]: out port p_rgb_meter = XS1_PORT_4F; //X0D28..31

on tile[1]: port p_adc = XS1_PORT_1A;	//X1D0
on tile[1]: buffered out port:32 p_pwm_fast = XS1_PORT_1C; //X1D10 TP14 R29(1k5)
on tile[1]: in port p_butt = XS1_PORT_8A; //X1D2..9
on tile[1]: out port p_phy_rst = XS1_PORT_1N;	//X1D37
on tile[1]: out port p_7_seg = XS1_PORT_8B;	//X1D14..X1D21
on tile[1]: out port p_7_seg_com_0 = XS1_PORT_1L;	//X1D35
on tile[1]: out port p_7_seg_com_1 = XS1_PORT_1O;	//X1D38
on tile[1]: out port p_7_seg_com_2 = XS1_PORT_1P;	//X1D39


//MP3 files
const char blaster[] = "BLASTER.MP3";	
const char chewy[] = "CHEWY.MP3";
const char entdoor[] = "ENTDOOR.MP3";
const char explode[] = "EXPLODE.MP3";
const char flashchg[] = "FLASHCHG.MP3";
const char hhgtelep[] = "HHGTELEP.MP3";
const char hithere[] = "HITHERE.MP3";
const char laser2[] = "LASER2.MP3";
const char lightsbr[] = "LIGHTSBR.MP3";
const char protonpk[] = "PROTONPK.MP3";
const char quattro[] = "QUATTRO.MP3";
const char r2d2[] = "R2D2.MP3";
const char spceinv1[] = "SPCEINV1.MP3";
const char spceinv2[] = "SPCEINV2.MP3";
const char spceinv3[] = "SPCEINV3.MP3";
const char strtrkbr[] = "STRTRKBR.MP3";
const char strtrklb[] = "STRTRKLB.MP3";
const char strtrkpl[] = "STRTRKPL.MP3";
const char strtrktr[] = "STRTRKTR.MP3";
const char tainted[] = "TAINTED.MP3";
const char teeandmo[] = "TEEANDMO.MP3";
const char vader[] = "VADER.MP3";

const char * sounds[] = {blaster, chewy, entdoor, explode, flashchg, hhgtelep, hithere, laser2, lightsbr, protonpk, 
	quattro, r2d2, spceinv1, spceinv2, spceinv3, strtrkbr, strtrklb, strtrkpl, strtrktr, tainted, teeandmo, vader};

void bargraph_update(unsigned bits) {
	unsigned write_val = (bits & 0x3) | (bits >> 4);
	p_bargraph <: write_val;
}

#define PERIODIC_TIMER	8000000	//80ms app timer

[[combinable]]
void app(static const unsigned port_bits, client i_buttons_t i_buttons, unsigned duties[PWM_PORT_BITS_N],
	client i_quadrature_t i_quadrature, client i_resistor_t i_resistor, client i_mp3_player_t i_mp3_player) {
	
	const unsigned n_sounds = sizeof(sounds) / sizeof(const char *);
	unsigned sound_idx = 0;

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
				if (button_event[0] == BUTTON_PRESSED) {
					//Do nothing - we will restart the mp3
				}
				if (button_event[1] == BUTTON_PRESSED) {
					sound_idx++;
					if (sound_idx == n_sounds) sound_idx = 0;
				}

				i_mp3_player.play_file(sounds[sound_idx], strlen(sounds[sound_idx]) + 1); //+1 because of the terminator
				printstrln(sounds[sound_idx]);
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
				unsigned val = (unsigned)i_resistor.get_val();
				printuintln(val);
				q8_24 log_input = (q8_24)val;
				q8_24 lin_output = dsp_math_log(log_input);
				val = (unsigned) (lin_output);
				printuintln(val);
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

int main(void) {
	i_buttons_t i_buttons;
	i_quadrature_t i_quadrature;
	i_resistor_t i_resistor;
	streaming chan c_pwm_fast;
	streaming chan c_mp3_chan;
	chan c_pcm_chan, c_mp3_stop;
	interface fs_basic_if i_fs[1];
  interface fs_storage_media_if i_media;
  interface i_mp3_player_t i_mp3_player;

	par {
  	on tile[0]: {
  		unsigned duties[PWM_PORT_BITS_N] = {10, 255, 0, 100};
			volatile unsigned * unsafe duties_ptr;
			unsafe{ duties_ptr = duties;}
		  fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_ISSI_IS25LQ016B;	//What we actually have on the explorer board
		  //fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_SPANSION_S25FL116K;	//What we are supposed to have on the explorer board

			par {			
				[[combine]] par {
					pwm_wide_unbuffered(p_butt_leds, PWM_PORT_BITS_N, PWM_WIDE_FREQ_HZ, PWM_DEPTH_BITS_N, duties_ptr);
					quadrature(p_quadrature, i_quadrature);
				}
				app(4, i_buttons, duties, i_quadrature, i_resistor, i_mp3_player);
				qspi_flash_fs_media(i_media, qspi_flash_ports, qspi_spec, 512);
		    filesystem_basic(i_fs, 1, FS_FORMAT_FAT12, i_media);

				mp3_player(i_fs[0], c_mp3_chan, c_mp3_stop, i_mp3_player);
			}
		}
		on tile[1]: {
			p_phy_rst <: 0; //Hold eth phy in reset to keep it off the bus and save power - we want to use those pins
			par{
					while(1) {
						decoderMain(c_pcm_chan, c_mp3_chan, c_mp3_stop);
						printstrln("Restart mp3");
					}
					pcm_post_process(c_pcm_chan, c_pwm_fast);
					pwm_fast(c_pwm_fast, p_pwm_fast);
					[[combine]] par {
						resistor_reader(p_adc, i_resistor);
						port_input_debounced(p_butt, 4, i_buttons);
					}
				}
			}
		}
	return 0;
}