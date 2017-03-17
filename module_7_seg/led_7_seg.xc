#include <xs1.h>
#include <stdio.h>
#include "led_7_seg.h"

//Which segments to light for a given number
const unsigned char digit_map[] = {
	0b00000000,
	0b00000000,
	0b00000000,
	0b00000000,
	0b00000000,
	0b00000000,
	0b00000000,
	0b00000000
	#error populate_me
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