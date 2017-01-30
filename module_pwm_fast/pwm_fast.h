#include <xs1.h>
#include <string.h>
#include <print.h>

//Each frame is 32b
//8 frames gives us 347KHz from 100MHz, about 1.6% slow
//9 frames gives us 390KHz from 100MHz, about 1.7% fast (we add a 50% padding frame to give 9 frames total)
#define TOTAL_FRAMES	8


///API - keep feeding 0-256 over the channel end for pwm duty at full rate
///If any of upper 16b word set, it assumes 352KHz mode

void pwm_fast(streaming chanend c_duty, buffered out port:32 p_pwm);