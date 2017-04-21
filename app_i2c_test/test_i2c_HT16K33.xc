#include "led_matrix.h"
#include <stdio.h>
#include <stdlib.h>

port p_scl = XS1_PORT_1G; //X0D22
port p_sda = XS1_PORT_1H; //X0D23

void test(client i_led_matrix_t i_led_matrix){

	for(int i=0; i<4; i++) {
		i_led_matrix.show_sprite(1); //inavder top
		delay_milliseconds(100);
		i_led_matrix.show_sprite(4);	//ed
		delay_milliseconds(100);
	}
	i_led_matrix.show_sprite(5); //pacman

	i_led_matrix.scroll_text_msg("Hello world!", 12);

	delay_milliseconds(5000);

	unsafe {
		const unsigned sprite_idxs[2] = {1, 2};
		printf("starting scroll\n");
		while(1){
			i_led_matrix.scroll_sprites(sprite_idxs, 2);
		}
	}
	_Exit(0);	
}

int main(void){
	i2c_master_if i_i2c[1];
	i_led_matrix_t i_led_matrix;

	par {
		i2c_master(i_i2c, 1, p_scl, p_sda, 400);
		led_matrix(i_led_matrix, i_i2c[0], 5);
		test(i_led_matrix);
	}
	return 0;
}