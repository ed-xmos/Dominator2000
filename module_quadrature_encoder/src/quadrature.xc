#include <print.h>
#include <xs1.h>
#include <string.h>
#include "quadrature.h"

[[combinable]]
void quadrature(in port p_input[2], server i_quadrature_t i_quadrature) {
	timer t[2];
	int trigger_time[2];
	int debounce_state[2] = {0};

	unsigned old_port_val[2];
	unsigned new_port_val[2];

	set_port_pull_down(p_input[0]);
	set_port_pull_down(p_input[1]);

	delay_milliseconds(1); //Wait for port to settle after pulldowns enabled

	//Get initial port value
	p_input[0] :> old_port_val[0];
	p_input[1] :> old_port_val[1];
	
	while(1){
		select {
			case i_quadrature.get_count(void) -> int count_diff_ret:
				count_diff_ret = 0;
				break;

			case !debounce_state[0] => p_input[0] when pinsneq(old_port_val[0]) :> new_port_val[0]:
				debounce_state[0] = DEBOUNCE_READS_N;
				t[0] :> trigger_time[0];
				trigger_time[0] += DEBOUNCE_READ_INTERVAL_TICKS;
				//printstr("*");
				break;

			case debounce_state[0] => t[0] when timerafter(trigger_time[0]) :> int _:
				int tmp_port_val;
				p_input[0] :> tmp_port_val;
				if (new_port_val[0] != tmp_port_val) {
					debounce_state[0] = DEBOUNCE_READS_N; //start again until stable
				}
				else {
					debounce_state[0]--;
					if (debounce_state[0] == 0) {
						//find out which ones have changed
						unsigned changed = old_port_val[0] ^ new_port_val[1];
						if (changed) {}
						//if (changes) i_buttons.buttons_event();
						old_port_val[0] = new_port_val[0];
					}
				}
				trigger_time[0] += DEBOUNCE_READ_INTERVAL_TICKS;
				new_port_val[0] = tmp_port_val;
				//printstr(".");
				break;
		}
	}
}