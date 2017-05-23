#include <print.h>
#include <xs1.h>
#include <string.h>
#include <stdio.h>
#include "quadrature.h"

#define DEBUG_POLL	1	//Print port value periodically

//This function is called  when one of the levels has changed (index p)
//So work out if this means cw or ccw turn
static inline void quadrature_decode(int p, unsigned old_port_val[2], unsigned new_port_val[2], int &count_diff) {
	//printf("p=%d\tnew[0]=%d\told[0]=%d\tnew[1]=%d\told[1]=%d\n", p, new_port_val[0], old_port_val[0], new_port_val[1], old_port_val[1]);
	if (p == 0){
		//Rising edge of signal index 0
		if (new_port_val[0] == 1) {
			//printstrln("0 rising");
			if (old_port_val[1] == 0) count_diff++;
			else	count_diff--;
		}
		//Falling edge of signal index 0
		else {
			//printstrln("0 falling");
			if (old_port_val[1] == 0) count_diff--;
			else	count_diff++;
		}
	}
	else { //p == 1
		//Rising edge of signal index 1
		if (new_port_val[1] == 1) {
  		//printstrln("1 rising");
			if (old_port_val[0] == 0) count_diff--;
			else	count_diff++;
		}
		//Falling edge of signal index 1
		else {
			//printstrln("1 falling");
			if (old_port_val[0] == 0) count_diff++;
			else	count_diff--;
		}
	}
}

[[combinable]]
void quadrature(in port p_input[2], server i_quadrature_t i_quadrature) {
	timer t[2];
	int trigger_time[2];
	int debounce_state[2] = {0, 0};

#if DEBUG_POLL
	const int print_period = 10000000; //100ms
	timer td;
	int trigger_time_d;
	td :> trigger_time_d;
#endif

	unsigned old_port_val[2];
	unsigned new_port_val[2];

	int count_diff = 0;

	for (int i=0; i<2; i++) set_port_pull_down(p_input[i]);

	delay_milliseconds(1); //Wait for port to settle after pulldowns enabled

	//Get initial port value
	for (int i=0; i<2; i++) p_input[i] :> old_port_val[i];
	
	while(1){
		select {
			case i_quadrature.get_count(void) -> int count_diff_ret:
				count_diff_ret = count_diff;
				count_diff = 0;
				printstrln("get_count");
				break;

			case (int p = 0; p < 2; ++p) !debounce_state[p] => p_input[p] when pinsneq(old_port_val[p]) :> new_port_val[p]:
				printstr("pinsneq");printintln(p);
				debounce_state[p] = QUADRATURE_DEBOUNCE_READS_N;
				t[p] :> trigger_time[p];
				trigger_time[p] += QUADRATURE_DEBOUNCE_READ_INTERVAL_TICKS;
				//printstr("port");printint(p);	//try to find out if this is firing constantly
				//printstr("=");printintln(new_port_val[p]);
				break;

			case (int p = 0; p < 2; ++p) debounce_state[p] => t[p] when timerafter(trigger_time[p]) :> int _:
				printstr("timerafter");printintln(p);
				int tmp_port_val;
				p_input[p] :> tmp_port_val;
				if (new_port_val[p] != tmp_port_val) {
					debounce_state[p] = QUADRATURE_DEBOUNCE_READS_N; //start again until stable
				}
				else {
					debounce_state[p]--;
					if (debounce_state[p] == 0) {
						//find out which ones have changed
						unsigned changed = old_port_val[p] ^ new_port_val[p];
						if (changed) {
							quadrature_decode(p, old_port_val, new_port_val, count_diff);
							if (count_diff != 0) i_quadrature.rotate_event();
						}
						old_port_val[p] = new_port_val[p];
					}
				}
				trigger_time[p] += QUADRATURE_DEBOUNCE_READ_INTERVAL_TICKS;
				new_port_val[p] = tmp_port_val;
				//printstr(".");printintln(p);
				break;

#if DEBUG_POLL
			case td when timerafter(trigger_time_d + print_period) :> trigger_time_d:
				int p0, p1;
				p_input[0] :> p0;
				p_input[1] :> p1;
				printf("p0=%d p1=%d\n", p0, p1);
				break;
#endif

		}
	}
}