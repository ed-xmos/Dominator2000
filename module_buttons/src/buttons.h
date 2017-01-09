#include <xs1.h>

#define DEBOUNCE_PERIOD_MS	20
#define DEBOUNCE_READS_N		4
#define DEBOUNCE_READ_INTERVAL_TICKS	(DEBOUNCE_PERIOD_MS * (100000 / DEBOUNCE_READS_N))
#define MAX_INPUT_PORT_BITS 8

typedef enum button_event_t {
	BUTTON_NOCHANGE = 0,
	BUTTON_PRESSED, 
	BUTTON_RELEASED,
} button_event_t;

typedef interface i_buttons_t {
	[[clears_notification]]
	void get_state(button_event_t button_event[], unsigned n);
	[[notification]]
	slave void buttons_event(void);
} i_buttons_t;

[[combinable]]
void port_input_debounced(in port p_input, static const unsigned width, server i_buttons_t i_buttons);