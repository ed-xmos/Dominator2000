#include <print.h>
#include <xs1.h>
#include <string.h>
#include "buttons.h"

[[combinable]]
void port_input_debounced(in port p_input, static const unsigned width, server i_buttons_t i_buttons) {
	timer t;
	int trigger_time;
	int debounce_state = 0;

	unsigned old_port_val;
	unsigned new_port_val;

	button_event_t button_event_log[MAX_INPUT_PORT_BITS] = {0};

	set_port_pull_down(p_input);
	delay_milliseconds(1); //Wait for port to settle after pulldowns enabled

	//Get initial port value
	p_input :> old_port_val;

	while(1){
		select {
			case i_buttons.get_state(button_event_t button_event[], unsigned n):
				memcpy(button_event, button_event_log, sizeof(button_event_log));
				break;

			case !debounce_state => p_input when pinsneq(old_port_val) :> int new_port_val:
				debounce_state = DEBOUNCE_READS_N;
				t :> trigger_time;
				trigger_time += DEBOUNCE_READ_INTERVAL_TICKS;
				//printstr("*");
				break;

			case debounce_state => t when timerafter(trigger_time) :> int _:
				int tmp_port_val;
				p_input :> tmp_port_val;
				if (new_port_val != tmp_port_val) {
					debounce_state = DEBOUNCE_READS_N; //start again until stable
				}
				else {
					debounce_state--;
					if (debounce_state == 0) {
						//find out which ones have changed
						unsigned changes;
						for (int i=0; i<width; i++) {
							changes = old_port_val ^ new_port_val;
							if ( (0x1 << i) & changes) {
								if ( (0x1 << i) & new_port_val) button_event_log[i] = BUTTON_RELEASED;
								else button_event_log[i] = BUTTON_PRESSED;
							} 
							else {
								button_event_log[i] = BUTTON_NOCHANGE;
							}
						}
						if (changes) i_buttons.buttons_event();
						old_port_val = new_port_val;
					}
				}
				trigger_time += DEBOUNCE_READ_INTERVAL_TICKS;
				new_port_val = tmp_port_val;
				//printstr(".");
				break;
		}
	}
}