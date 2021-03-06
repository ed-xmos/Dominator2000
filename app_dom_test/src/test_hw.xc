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
#include "led_7_seg.h"
#include "rgbx_pallette.h"
#include "i2c.h"
#include "led_matrix.h"

#define I2C_ADDR						0x70	//For LED matrix

#define PWM_DEPTH_BITS_N		8			//For wide PWM
#define PWM_WIDE_FREQ_HZ		500

fl_QSPIPorts qspi_flash_ports = {
  PORT_SQI_CS,
  PORT_SQI_SCLK,
  PORT_SQI_SIO,
  on tile[0]: XS1_CLKBLK_1
};

on tile[0]: out port p_butt_leds = XS1_PORT_8B; //X0D14..21
on tile[0]: out port p_bargraph = XS1_PORT_16B; //X0D26..27, X0D36..39
on tile[0]: out port p_bargraph3 = XS1_PORT_1K; //X0D34
on tile[0]: out port p_bargraph4 = XS1_PORT_1L; //X0D35
on tile[0]: in port p_quadrature[2] = {XS1_PORT_1G, XS1_PORT_1H}; //X0D22,33
on tile[0]: out port p_rgb_meter = XS1_PORT_4F; //X0D28..31
on tile[0]: port p_scl = XS1_PORT_1E; //X0D12
on tile[0]: port p_sda = XS1_PORT_1F; //X0D13
on tile[0]: in port p_red_butt = XS1_PORT_4A; //Bit 2 X0D08

on tile[1]: port p_adc = XS1_PORT_1A;	//X1D0
on tile[1]: buffered out port:32 p_pwm_fast = XS1_PORT_1C; //X1D10 TP14 R29(1k5)
on tile[1]: in port p_butt = XS1_PORT_8A; //X1D2..9
on tile[1]: out port p_phy_rst = XS1_PORT_1N;	//X1D37
on tile[1]: out port p_7_seg = XS1_PORT_8B;	//X1D14..X1D21
on tile[1]: out port p_7_seg_com[LED_N_DIGITS] = {XS1_PORT_1L, XS1_PORT_1O};	//X1D35, X1D38


//MP3 files
const char blaster[] = "BLASTER.MP3";	//0
const char chewy[] = "CHEWY.MP3";
const char entdoor[] = "ENTDOOR.MP3";
const char explode[] = "EXPLODE.MP3";
const char flashchg[] = "FLASHCHG.MP3";
const char hhgtelep[] = "HHGTELEP.MP3"; //5
const char hithere[] = "HITHERE.MP3";
const char laser2[] = "LASER2.MP3";
const char lightsbr[] = "LIGHTSBR.MP3";
const char protonpk[] = "PROTONPK.MP3";
const char quattro[] = "QUATTRO.MP3"; //10
const char r2d2[] = "R2D2.MP3";
const char spceinv1[] = "SPCEINV1.MP3";
const char spceinv2[] = "SPCEINV2.MP3";
const char spceinv3[] = "SPCEINV3.MP3";
const char strtrkbr[] = "STRTRKBR.MP3"; //15
const char strtrklb[] = "STRTRKLB.MP3";
const char strtrkpl[] = "STRTRKPL.MP3";
const char strtrktr[] = "STRTRKTR.MP3";
const char tainted[] = "TAINTED.MP3";
const char teeandmo[] = "TEEANDMO.MP3"; //20
const char vader[] = "VADER.MP3";

const char * sounds[] = {blaster, chewy, entdoor, explode, flashchg, hhgtelep, hithere, laser2, lightsbr, protonpk, 
	quattro, r2d2, spceinv1, spceinv2, spceinv3, strtrkbr, strtrklb, strtrkpl, strtrktr, tainted, teeandmo, vader};

void bargraph_update(unsigned bits) {
	unsigned write_val = 0;
	if (bits & 0x001) write_val |= 0x001;
	if (bits & 0x002) write_val |= 0x002;
	if (bits & 0x004) write_val |= 0x040;
	if (bits & 0x008) write_val |= 0x080;
	if (bits & 0x040) write_val |= 0x100;
	if (bits & 0x080) write_val |= 0x200;
	if (bits & 0x100) write_val |= 0x400;
	if (bits & 0x200) write_val |= 0x800;
	write_val = ~write_val;	//Active low so invert
	p_bargraph <: write_val;
		if (bits & 0x10) p_bargraph3 <: 0;
	else p_bargraph3 <: 1;
	if (bits & 0x20) p_bargraph4 <: 0;
	else p_bargraph4 <: 1;
}

#define PERIODIC_TIMER	1000000	//10ms app timer

[[combinable]]
void app(client i_buttons_t i_buttons, unsigned butt_led_duties[8], unsigned mbgr_duties[4],
	client i_quadrature_t i_quadrature, client i_resistor_t i_resistor, client i_mp3_player_t i_mp3_player, chanend c_atten,
	client i_7_seg_t i_7_seg, client i_led_matrix_t i_led_matrix) {
	
	const unsigned n_sounds = sizeof(sounds) / sizeof(const char *);
	unsigned sound_idx = 0;

	unsigned red_butt_count = 0;

	button_event_t button_event[MAX_INPUT_PORT_BITS] = {0};

	timer t_periodic;
	int time_periodic_trigger;

	int new_duty = 0x1;
	int led_index = 0;

	t_periodic :> time_periodic_trigger;

	i_led_matrix.scroll_text_msg("Domitron 2000", 13);

	while(1) {
		select {
			case i_buttons.buttons_event():
				//printchar('.');
				i_buttons.get_state(button_event);
				//printstrln("New buttons:");
				for (int i=0; i<8; i++) {
					//if (button_event[i] == BUTTON_PRESSED) printintln(i);
				}

				if (button_event[0] == BUTTON_PRESSED) {
					i_mp3_player.play_file(sounds[sound_idx], strlen(sounds[sound_idx]) + 1); //+1 because of the terminator
					//printstrln(sounds[sound_idx]);
					sound_idx++;
					if (sound_idx == n_sounds) sound_idx = 0;
					i_led_matrix.scroll_text_msg("1", 1);
				}
				if (button_event[1] == BUTTON_PRESSED) {
					const unsigned sprite_idxs[] = {2, 3};
					i_led_matrix.scroll_text_msg("2", 1);
				}
				if (button_event[2] == BUTTON_PRESSED) {
					const unsigned sprite_idxs[] = {2, 3};
					i_led_matrix.scroll_sprites(sprite_idxs, 2);
				}
				if (button_event[3] == BUTTON_PRESSED) {
					led_index++;
					if (led_index > 4) led_index = 0;
					i_led_matrix.scroll_text_msg("3", 1);
				}
				if (button_event[4] == BUTTON_PRESSED) {
					led_index--;
					if (led_index < 0) led_index = 4;
					i_led_matrix.scroll_text_msg("4", 1);
				}
				if (button_event[5] == BUTTON_PRESSED) {
					i_led_matrix.scroll_text_msg("su", 2);
					
				}
				if (button_event[5] == BUTTON_RELEASED) {
					i_led_matrix.scroll_text_msg("sd", 2);

				}
				if (button_event[6] == BUTTON_PRESSED) {
					butt_led_duties[5] = 0x100;
				}
				if (button_event[6] == BUTTON_RELEASED) {
					butt_led_duties[5] = 0x0;
				}
				if (button_event[7] == BUTTON_PRESSED) {
					i_led_matrix.scroll_text_msg("Mu", 2);
					butt_led_duties[6] = 0x00;
				}
				if (button_event[7] == BUTTON_RELEASED) {
					i_led_matrix.scroll_text_msg("Md", 2);
					butt_led_duties[6] = 0x100;

				}
				break;


			case i_quadrature.rotate_event():
#if 1
				static int last_rotation = 0;
				int rotation = i_quadrature.get_count();
				if (last_rotation != rotation) {
					//printstrln("");
					last_rotation = rotation;
				}
				if (rotation == 1) {
					i_7_seg.inc_val();
					//printstr("+");
				}
				if (rotation == -1) {
					i_7_seg.dec_val();
					//printstr("-");
				}
				unsigned count = i_7_seg.get_val();
				bargraph_update(1 << count / 10);
#endif
				break;

			case i_resistor.value_change_event():
				unsigned val = (unsigned)i_resistor.get_val();

				//printintln(val);
				q8_24 log_input = (q8_24)((val<<16) + 0x1000000);
				//printintln(val);
				q8_24 lin_output = dsp_math_log(log_input);
				val = (unsigned) (lin_output);
				unsigned scaled = val >> 18;
				if (scaled > 255) scaled = 255; //clip
				//printintln(scaled);
				mbgr_duties[0] = scaled;	//Meter

				mbgr_duties[1] = rgb_pallette[4 * scaled + 2];	//Blue
				mbgr_duties[2] = rgb_pallette[4 * scaled + 1];	//Green
				mbgr_duties[3] = rgb_pallette[4 * scaled + 0];	//Red
				break;

			case t_periodic when timerafter(time_periodic_trigger + PERIODIC_TIMER) :> time_periodic_trigger:
				butt_led_duties[led_index] = new_duty;
				new_duty <<= 1;
				//printintln(new_duty);
				if (new_duty == 0x100) new_duty = 0x1;

				//Do volume thing
				int red_butt;
				p_red_butt :> red_butt;
				if (red_butt != 0) red_butt_count++;
				else red_butt_count = 0;
				if (red_butt_count == 5) {
					unsigned val = (unsigned)i_resistor.get_val();
					val = (val * 42) >> 4; // * 42 / 16 to get to max just under 32K
					val = (val << 16);  //scale up to just under max int;
					if (val > MAX_VOL) val = MAX_VOL;
					c_atten <: val;
					//printintln(val);
					if (!i_mp3_player.is_playing()) {
						if (i_7_seg.get_val() == 42) i_mp3_player.play_file(sounds[20], strlen(sounds[20]) + 1); //Tee and mo
						else i_mp3_player.play_file(sounds[2], strlen(sounds[2]) + 1); //Entdoor
					}
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
	chan c_pcm_chan, c_mp3_stop, c_atten;
	interface fs_basic_if i_fs[1];
  interface fs_storage_media_if i_media;
  interface i_mp3_player_t i_mp3_player;
  i_7_seg_t i_7_seg;
  i2c_master_if i_i2c[1];
  i_led_matrix_t i_led_matrix;

	par {
  	on tile[0]: {
  		unsigned butt_led_duties[8] = {128, 128, 128, 128, 128, 128, 128, 128};
  		unsigned mbgr_duties[4] = {50, 100, 150, 200};
			volatile unsigned * unsafe butt_led_duties_ptr;
			volatile unsigned * unsafe mbgr_duties_ptr;
			unsafe{ butt_led_duties_ptr = butt_led_duties; mbgr_duties_ptr = mbgr_duties;}

		  fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_ISSI_IS25LQ016B;	//What we actually have on the explorer board
		  //fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_SPANSION_S25FL116K;	//What we are supposed to have on the explorer board

		  set_port_drive_low(p_butt_leds); //These are pulled high to 5v so open drain drive best
		  set_port_drive_low(p_bargraph); //As above
		  set_port_pull_down(p_red_butt); //So we can see it pulled high on press

		  for (int i = 0; i < 2; i++) set_port_pull_down(p_quadrature[i]); //Inputs are active high so pull down in chip

		  delay_milliseconds(500);	//Allow amp to power up

			par {			
				[[combine]] par {
					pwm_wide_unbuffered(p_rgb_meter, 4, PWM_WIDE_FREQ_HZ, PWM_DEPTH_BITS_N, mbgr_duties_ptr);
					quadrature(p_quadrature, i_quadrature);	//This doesn't like being non-combined (exception)
				}
				pwm_wide_unbuffered(p_butt_leds, 8, PWM_WIDE_FREQ_HZ, PWM_DEPTH_BITS_N, butt_led_duties_ptr);
				app(i_buttons, butt_led_duties, mbgr_duties, i_quadrature, i_resistor, i_mp3_player, c_atten, i_7_seg, i_led_matrix);
				qspi_flash_fs_media(i_media, qspi_flash_ports, qspi_spec, 512);
		    filesystem_basic(i_fs, 1, FS_FORMAT_FAT12, i_media);
				mp3_player(i_fs[0], c_mp3_chan, c_mp3_stop, i_mp3_player);
				i2c_master(i_i2c, 1, p_scl, p_sda, 400);
				led_matrix(i_led_matrix, i_i2c[0], 3);
			}
		}
		on tile[1]: {
			p_phy_rst <: 0; //Hold eth phy in reset to keep it off the bus and save power - we want to use those pins
			set_port_drive_low(p_7_seg); //These are pulled high to 5V so open drain drive best
			for (int i = 0; i < LED_N_DIGITS; i++) set_port_drive_low(p_7_seg_com[i]); //as above
			set_port_pull_down(p_butt); //Inputs are active high so pull down in chip

		  delay_milliseconds(500);	//Allow amp to power up

			par{
					while(1) {
						decoderMain(c_pcm_chan, c_mp3_chan, c_mp3_stop);
						//printstrln("Restart mp3");
					}
					{
						set_core_high_priority_on();
						pcm_post_process(c_pcm_chan, c_pwm_fast, c_atten);
					}
					pwm_fast(c_pwm_fast, p_pwm_fast);
					par {
					//[[combine]] par {
						resistor_reader(p_adc, i_resistor);
						port_input_debounced(p_butt, 8, i_buttons);
					}
					led_7_seg(i_7_seg, p_7_seg, p_7_seg_com);
				}
			}
		}
	return 0;
}