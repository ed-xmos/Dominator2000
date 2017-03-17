#include <xs1.h>

#define LED_N_DIGITS	2
#define MAX_VAL ((10 * LED_N_DIGITS) - 1)
#define MUX_DELAY		1000000	//10ms

typedef interface i_7_seg_t {
  void set_val(unsigned val);
  unsigned get_val(void);
  void inc_val(void);
  void dec_val(void);
  void display_enable(unsigned on_off);
} i_7_seg_t;

[[combinable]]
void led_7_seg(
	server i_7_seg_t i_7seg, 
	out port p_segments, 
	out port p_com[LED_N_DIGITS]);