#define ADC_READ_INTERVAL 5000000       //50 milliseconds 
#define ADC_CHARGE_PERIOD     10000       //100 microseconds to charge cap

static enum adc_state{
        ADC_IDLE = 0,
        ADC_CHARGING,
        ADC_CONVERTING
};

[[combinable]]
void resistor_reader(port p_adc, volatile unsigned * unsafe adc_ptr ){
  timer t_periodic, t_charge_end;
  int trigger_time_periodic, trigger_time_charge_end; //timers for state machine
  int discharge_start_time, discharge_end_time;       //port timers for adc conversion
  adc_state state = ADC_IDLE;


  t_periodic :> trigger_time_periodic;
  trigger_time_periodic += ADC_READ_INTERVAL;

  t_charge_end :> trigger_time_charge_end;
  trigger_time_charge_end += ADC_CHARGE_PERIOD + ADC_READ_INTERVAL;

  while(1) {
    select{
        case (state == ADC_IDLE) => t_periodic when timer_after(trigger_time_periodic):
          p_adc <: 1;
          trigger_time_periodic += ADC_READ_INTERVAL;
          state = ADC_CHARGING;
          break;

        case (state == ADC_CHARGING) => t_charge_end when timer_after(trigger_time_charge_end):
          trigger_time_charge_end += ADC_READ_INTERVAL;
          p_adc :> int _ @ discharge_start_time; //make input and start discharge
          state = ADC_CONVERTING;
          break;

        case (state == ADC_CONVERTING) => p_adc when pinseq(0) :> int _ @ discharge_end_time:
          unsigned discharge_time;
          if (discharge_end_time < discharge_end_time) discharge_time = (discharge_end_time + 0x10000) - discharge_start_time;
          else discharge_time = discharge_end_time - discharge_start_time;
          unsafe {*adc_ptr = discharge_time;}
          state = ADC_IDLE;
          break;
}

