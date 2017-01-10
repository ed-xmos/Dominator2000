#include <print.h>
#include <xs1.h>
#include <string.h>
#include "pwm_wide.h"
#include "buttons.h"
#include "quadrature.h"

#define PWM_PORT_BITS_N			4
#define PWM_DEPTH_BITS_N		8
#define PWM_WIDE_FREQ_HZ		500

out port p_leds = XS1_PORT_4F;
in port p_butt = XS1_PORT_4E;

in port p_quadrature[2] = {XS1_PORT_1G, XS1_PORT_1H};

#define PERIODIC_TIMER	8000000	//80ms

void app(static const unsigned port_bits, client i_buttons_t i_buttons, unsigned duties[PWM_PORT_BITS_N], client i_quadrature_t i_quadrature) {
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
				int rotation = i_quadrature.get_count();
				printintln(rotation);
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
	unsigned duties[PWM_PORT_BITS_N] = {10, 255, 0, 100};
	volatile unsigned * unsafe duties_ptr;

	i_buttons_t i_buttons;
	i_quadrature_t i_quadrature;


	unsafe{ duties_ptr = duties;}


	par {
		pwm_wide_unbuffered(p_leds, PWM_PORT_BITS_N, PWM_WIDE_FREQ_HZ, PWM_DEPTH_BITS_N, duties_ptr);
		port_input_debounced(p_butt, 4, i_buttons);
		app(4, i_buttons, duties, i_quadrature);
		quadrature(p_quadrature, i_quadrature);
	}
	return 0;
}