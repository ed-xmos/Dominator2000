#ifndef _RESISTOR_READ_
#define _RESISTOR_READ_

typedef interface i_resistor_t {
  [[clears_notification]]
  int get_val(void);
  [[notification]]
  slave void value_change_event(void);
} i_resistor_t;

[[combinable]]
void resistor_reader(port p_adc, server i_resistor_t i_resistor);
#endif