#include <xs1.h>

#define QUADRATURE_DEBOUNCE_PERIOD_MS	1
#define QUADRATURE_DEBOUNCE_READS_N		2
#define QUADRATURE_DEBOUNCE_READ_INTERVAL_TICKS	(QUADRATURE_DEBOUNCE_PERIOD_MS * (100000 / QUADRATURE_DEBOUNCE_READS_N))

typedef interface i_quadrature_t {
	[[clears_notification]]
	int get_count(void);
	[[notification]]
	slave void rotate_event(void);
} i_quadrature_t;

[[combinable]]
void quadrature(in port p_input[2], server i_quadrature_t i_quadrature_t);