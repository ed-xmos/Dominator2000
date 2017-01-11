#include <xs1.h>
#include "resistor.h"

#define ADC_READ_INTERVAL   5000000       //50 milliseconds in between conversions
#define ADC_CHARGE_PERIOD    100000       //1000 microseconds to charge cap

static enum adc_state{
        ADC_IDLE = 0,
        ADC_CHARGING,
        ADC_CONVERTING
}adc_state;

[[combinable]]
void resistor_reader(port p_adc, server i_resistor_t i_resistor) {
  timer t_periodic, t_charge_end;
  int trigger_time_periodic, trigger_time_charge_end; //timers for state machine
  int discharge_start_time, discharge_end_time;       //port timers for adc conversion
  adc_state = ADC_IDLE;

  int processed_val = 0;

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
        p_adc <: 1;
        trigger_time_periodic += ADC_READ_INTERVAL;
        adc_state = ADC_CHARGING;
        break;

      case (adc_state == ADC_CHARGING) => t_charge_end when timerafter(trigger_time_charge_end) :> int _:
        trigger_time_charge_end += ADC_READ_INTERVAL;
        p_adc :> int _ @ discharge_start_time; //make input and start discharge
        adc_state = ADC_CONVERTING;
        break;

      case (adc_state == ADC_CONVERTING) => p_adc when pinseq(0) :> int _ @ discharge_end_time:
        unsigned discharge_time;
        if (discharge_end_time < discharge_end_time) discharge_time = (discharge_end_time + 0x10000) - discharge_start_time;
        else discharge_time = discharge_end_time - discharge_start_time;
        processed_val = discharge_time;
        //TODO = process properly and add deadband & event
        adc_state = ADC_IDLE;
        break;
    }
  }
}

