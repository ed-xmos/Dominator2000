#include "i2c.h"
#include <xs1.h>

typedef interface i_led_matrix_t {
	void show_sprite(unsigned sprite_idx);
	void scroll_sprites(const unsigned sprite_idxs[n], const unsigned n);
	void scroll_text_msg(const char message[n], const unsigned n);
} i_led_matrix_t;

void led_matrix(server i_led_matrix_t i_led_matrix, client interface i2c_master_if i_i2c, unsigned duty_4b);