//@100MHz, can do 4b port 8b PWM 8.5KHz
//@100MHz, can do 8b port 8b PWM 5.0KHz

[[combinable]]
void pwm_wide_unbuffered(
						 out port p_pwm
						,static const unsigned port_bits_n
						,static const unsigned pwm_freq_hz
						,static const unsigned pwm_bits_n
						,volatile unsigned * unsafe duties_ptr );