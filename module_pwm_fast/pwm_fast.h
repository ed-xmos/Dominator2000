#include <xs1.h>
#include <string.h>
#include <print.h>

//Each frame is 32b
#define TOTAL_FRAMES_352	9		//Gives us 347KHz from 100MHz, about 1.6% slow
#define TOTAL_FRAMES_384	8		//Gives us 390KHz from 100MHz, about 1.7% fast

///API - keep feeding 0-256 over the channel end for pwm duty at full rate
///If any of upper 16b word set, it assumes 352KHz mode

void pwm_fast(streaming chanend c_duty, buffered out port:32 p_pwm);