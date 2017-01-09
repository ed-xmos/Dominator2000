#include <print.h>
#include <xs1.h>
#include <string.h>

//@100MHz, can do 4b port 8b PWM 8.5KHz
//@100MHz, can do 8b port 8b PWM 5.0KHz

[[combinable]]
void pwm_wide_unbuffered(
						 out port p_pwm
						,static const unsigned port_bits_n
						,static const unsigned pwm_freq_hz
						,static const unsigned pwm_bits_n
						,volatile unsigned * unsafe duties_ptr ){
	
	unsigned duty;
	unsigned mask = 0x01;
	unsigned counter = 0;
	unsigned port_shadow = 0;

	const unsigned pwm_step_ticks = (XS1_TIMER_HZ / ((1 << pwm_bits_n) * pwm_freq_hz) ); 
	//printstr("PWM_STEP_TICKS: "); printintln(pwm_step_ticks);

	timer t;
	int time_delay;

	t :> time_delay;
	time_delay += pwm_step_ticks;

	while(1) {
#pragma loop unroll
		select {
			case t when timerafter(time_delay) :> int _:
				for (int i = 0; i < port_bits_n; i++) {
					unsafe {duty = *(duties_ptr + i);}
					if (counter < duty) port_shadow |= mask;
					mask <<= 1;
				}
				mask >>= port_bits_n;
				p_pwm <: port_shadow;
				port_shadow = 0;
				if (counter == ((1 << pwm_bits_n) - 2)) counter = 0;
				else counter++;

				//Check to see if we have missed the deadline
				int time_now; t :> time_now; if ((time_now - time_delay) > 0) {
					//printstr("Missed deadline by ticks: "); printintln(time_now - time_delay); __builtin_trap();
				}
				time_delay += pwm_step_ticks;
				break;
		}
	}
}