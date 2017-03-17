#include <xs1.h>
#include <stdio.h>
#include "led_7_seg.h"

//Which segments to light for a given number
const unsigned char digit_map[] = {
	//abcdefg.
	0b11111110, //0
	0b01100000, //1
	0b11011010, //2
	0b11110010,	//3
	0b01100110,	//4
	0b10110110,	//5
	0b10111110,	//6
	0b11100100,	//7
	0b11111110, //8
	0b11110110, //9
};


static void update_display(unsigned disp_number, unsigned enabled, unsigned char bit_map[]) {
	char number_string[LED_N_DIGITS + 1];
	 sprintf(number_string, "%d", disp_number);

	for (int i = 0; i < LED_N_DIGITS; i++) {
		unsigned char digit = (*(number_string + LED_N_DIGITS - 1 + i)) - '0';
		bit_map[i] = digit_map[digit];
	}
}

[[combinable]]
void led_7_seg(
	server i_7_seg_t i_7seg, 
	out port p_segments, 
	out port p_com[LED_N_DIGITS]){

	unsigned enabled = 0;
	unsigned displayed_number = 0;

	unsigned char bit_map[LED_N_DIGITS];
	unsigned common_idx = 0;

	//mux and segments off
	p_segments <: 0;
	for (int i = 0; i < LED_N_DIGITS; i++) p_com[i] <: 1;

	int time_trig;
	timer t;
	
	t :> time_trig;

	update_display(displayed_number, enabled, bit_map);

	while(1){
		select{

			case t when timerafter(MUX_DELAY + time_trig) :> time_trig:
				//current mux off
				p_com[1 << common_idx] <: 1;
				//change display
				p_segments <: bit_map[common_idx];

				//next mux line
				common_idx++;
				if (common_idx == LED_N_DIGITS) common_idx = 0;
				//mux on
				p_com[1 << common_idx] <: 0;
				break;

			case i_7seg.set_val(unsigned new_displayed_number):
				displayed_number = new_displayed_number;
				if (displayed_number > MAX_VAL) displayed_number = MAX_VAL; //Unsigned so no mindisp_number
				update_display(displayed_number, enabled, bit_map);
				break;

			case i_7seg.get_val(void) -> unsigned ret_displayed_number:
				ret_displayed_number = displayed_number;
				break;

			case i_7seg.inc_val(void):
				displayed_number += 1;
				if (displayed_number > MAX_VAL) displayed_number = MAX_VAL; //Unsigned so no mindisp_number
				update_display(displayed_number, enabled, bit_map);
				break;
  
  		case i_7seg.dec_val(void):
  			displayed_number -= 1;
				if (displayed_number > MAX_VAL) displayed_number = 0; //Unsigned so will wrap around to max
				update_display(displayed_number, enabled, bit_map);
				break;

			case i_7seg.display_enable(unsigned enabled_new):
				enabled = enabled_new;
				update_display(displayed_number, enabled, bit_map);
				break;
		}
	}
}