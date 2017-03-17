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


static void update_display(unsigned val, unsigned enabled, out port p_segments, out port p_com[LED_N_DIGITS], unsigned char bit_map[]) {
	char number_string[LED_N_DIGITS + 1];
	 sprintf(number_string, "%d", val);

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
	unsigned val = 0;
	unsigned char bit_map[LED_N_DIGITS] = {0};


	int time_trig;
	timer t;
	#error do upate stuff

	update_display(val, enabled, p_segments, p_com, bit_map);

	while(1){
		select{
			case i_7seg.set_val(unsigned new_val):
				val = new_val;
				if (val > MAX_VAL) val = MAX_VAL; //Unsigned so no minval
				update_display(val, enabled, p_segments, p_com, bit_map);
				break;

			case i_7seg.get_val(void) -> unsigned ret_val:
				ret_val = val;
				break;

			case i_7seg.inc_val(void):
				val += 1;
				if (val > MAX_VAL) val = MAX_VAL; //Unsigned so no minval
				update_display(val, enabled, p_segments, p_com, bit_map);
				break;
  
  		case i_7seg.dec_val(void):
  			val -= 1;
				if (val > MAX_VAL) val = 0; //Unsigned so will wrap around to max
				update_display(val, enabled, p_segments, p_com, bit_map);
				break;

			case i_7seg.display_enable(unsigned enabled_new):
				enabled = enabled_new;
				update_display(val, enabled, p_segments, p_com, bit_map);
				break;
		}
	}
}