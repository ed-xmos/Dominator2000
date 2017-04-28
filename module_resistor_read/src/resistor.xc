#include <xs1.h>
#include <print.h>
#include "resistor.h"

#define ADC_READ_INTERVAL   5000000      //50 milliseconds in between conversions
#define ADC_CHARGE_PERIOD     20000      //200 microseconds to charge cap
#define ADC_NOISE_DEADBAND        2      // change of 1/256 will not trigger  

#define ABS(x) ((x)<0 ? (-x) : (x))

static enum adc_state{
        ADC_IDLE = 0,
        ADC_CHARGING,
        ADC_CONVERTING
}adc_state;

static int remove_offset(int discharge_time) {
  int offsetted = (discharge_time - 270);
  if (offsetted < 0) offsetted = 0;
  return offsetted;
}

[[combinable]]
void resistor_reader(port p_adc, server i_resistor_t i_resistor) {
  timer t_periodic, t_charge_end;
  int trigger_time_periodic, trigger_time_charge_end; //timers for state machine
  int discharge_start_time, discharge_end_time;   
  adc_state = ADC_IDLE;

  int processed_val = 0;
  int last_discharge_time = 0;

  t_periodic :> trigger_time_periodic;
  trigger_time_periodic += ADC_READ_INTERVAL;

  t_charge_end :> trigger_time_charge_end;
  trigger_time_charge_end += ADC_CHARGE_PERIOD + ADC_READ_INTERVAL;

  while(1) {
    select {
      case i_resistor.get_val(void) -> int ret_val:
        ret_val = processed_val;
        break;

      case (adc_state == ADC_IDLE) => t_periodic when timerafter(trigger_time_periodic) :> int _:
        p_adc <: 1; //charge cap
        trigger_time_periodic += ADC_READ_INTERVAL;
        adc_state = ADC_CHARGING;
        break;

      case (adc_state == ADC_CHARGING) => t_charge_end when timerafter(trigger_time_charge_end) :> int _:
        trigger_time_charge_end += ADC_READ_INTERVAL;
        p_adc :> int _; //make input and start discharge
        t_periodic :> discharge_start_time;
        adc_state = ADC_CONVERTING;
        break;

      case (adc_state == ADC_CONVERTING) => p_adc when pinseq(0) :> int _:
        t_periodic :> discharge_end_time;
        unsigned discharge_time = discharge_end_time - discharge_start_time;
        int upper = (last_discharge_time * (256 + ADC_NOISE_DEADBAND)) >> 8;
        int lower = (last_discharge_time * (256 - ADC_NOISE_DEADBAND)) >> 8;
        if ((discharge_time > upper) || (discharge_time < lower)) {
          processed_val = remove_offset(discharge_time);
          i_resistor.value_change_event();
          last_discharge_time = discharge_time;
        }

        adc_state = ADC_IDLE;
        break;
    }
  }
}

