#include <print.h>
#include <xs1.h>
#include <string.h>
#include "pwm_wide.h"
#include "buttons.h"
#include "quadrature.h"
#include "resistor.h"
#include "pwm_fast.h"

#define PWM_PORT_BITS_N			4
#define PWM_DEPTH_BITS_N		8
#define PWM_WIDE_FREQ_HZ		500

out port p_leds = XS1_PORT_4F;
in port p_butt = XS1_PORT_4E;
port p_adc = XS1_PORT_1I;
buffered out port:32 p_pwm_fast = XS1_PORT_1J;

in port p_quadrature[2] = {XS1_PORT_1G, XS1_PORT_1H};

#define PERIODIC_TIMER	8000000	//80ms

void app(static const unsigned port_bits, client i_buttons_t i_buttons, unsigned duties[PWM_PORT_BITS_N],
	client i_quadrature_t i_quadrature, client i_resistor_t i_resistor) {
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
				printintln(i_resistor.get_val());
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
	i_resistor_t i_resistor;
	streaming chan c_pwm_fast;

	unsafe{ duties_ptr = duties;}


	par {
		pwm_wide_unbuffered(p_leds, PWM_PORT_BITS_N, PWM_WIDE_FREQ_HZ, PWM_DEPTH_BITS_N, duties_ptr);
		port_input_debounced(p_butt, 4, i_buttons);
		app(4, i_buttons, duties, i_quadrature, i_resistor);
		quadrature(p_quadrature, i_quadrature);
		resistor_reader(p_adc, i_resistor);
		pwm_fast(c_pwm_fast, p_pwm_fast);
		{
			while(1){
				c_pwm_fast <: 128 + 0x10000;
			}
		}
	}
	return 0;
}