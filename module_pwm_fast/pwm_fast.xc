#include <xs1.h>
#include <string.h>
#include <print.h>
#include "pwm_fast.h"

#define ZERO_VALUE		128	//Value for a zero output (half duty)

static const unsigned transition_frame[33] = {
				0x00000000,
				0x00000001,
				0x00000003,
				0x00000007,
				0x0000000F,
				0x0000001F,
				0x0000003F,
				0x0000007F,
				0x000000FF,
				0x000001FF,
				0x000003FF,
				0x000007FF,
				0x00000FFF,
				0x00001FFF,
				0x00003FFF,
				0x00007FFF,
				0x0000FFFF,
				0x0001FFFF,
				0x0003FFFF,
				0x0007FFFF,
				0x000FFFFF,
				0x001FFFFF,
				0x003FFFFF,
				0x007FFFFF,
				0x00FFFFFF,
				0x01FFFFFF,
				0x03FFFFFF,
				0x07FFFFFF,
				0x0FFFFFFF,
				0x1FFFFFFF,
				0x3FFFFFFF,
				0x7FFFFFFF,
				0xFFFFFFFF,	
				};	

#pragma unsafe arrays
void pwm_fast(streaming chanend c_pwm, buffered out port:32 p_pwm) {
	unsigned whole_ones_count;
	unsigned transition_idx;
	unsigned whole_zeros_count;
	unsigned total_frames_count_minus_one = TOTAL_FRAMES - 1;

	unsigned duty;	//Current duty cycle 0..256
	unsigned buffer_base = 0;
	unsigned buffer_idx = 0;
	unsigned buffer_length = 0;
	unsigned char * unsafe ptr;

	c_pwm <: 0; //We're ready

	while(1) {
		select{
			case c_pwm :> buffer_base:
				c_pwm :> buffer_length;
				buffer_idx = 0;
			break;
			
			default:
				if (buffer_length) unsafe {
					unsigned tmp = buffer_base + buffer_idx;
					ptr = (unsigned char *)tmp; 
					duty = *ptr;
					buffer_idx++;
					buffer_length--;
					if (!buffer_length) c_pwm <: 0; //We're ready for more
				}
				else duty = ZERO_VALUE;
			break;
		}

		//printintln(buffer_length);

		//Add extra frame if 352KHz
		if (1) {
			p_pwm <: transition_frame[16];
		}

		whole_ones_count = duty >> 5;
		transition_idx = duty & 0x1f;
		whole_zeros_count = total_frames_count_minus_one - whole_ones_count;
		for (int i=whole_ones_count; i!=0; --i) p_pwm <: transition_frame[32];
		p_pwm <: transition_frame[transition_idx];
		for (int i=whole_zeros_count; i!=0; --i) p_pwm <: transition_frame[0];

	}
}