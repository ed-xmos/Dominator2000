#include <xs1.h>

#define DEBOUNCE_PERIOD_MS	5
#define DEBOUNCE_READS_N		4
#define DEBOUNCE_READ_INTERVAL_TICKS	(DEBOUNCE_PERIOD_MS * (100000 / DEBOUNCE_READS_N))

typedef interface i_quadrature_t {
	[[clears_notification]]
	int get_count(void);
	[[notification]]
	slave void rotate_event(void);
} i_quadrature_t;

[[combinable]]
void quadrature(in port p_input[2], server i_quadrature_t i_quadrature_t);