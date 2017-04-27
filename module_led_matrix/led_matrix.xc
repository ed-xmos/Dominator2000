#include "i2c.h"
#include <xs1.h>
#include <stdio.h>
#include <xclib.h>
#include <stdlib.h>
#include <print.h>
#include <string.h>
#include "font.h"

#define FONT_V_SIZE	8
#define FONT_H_SIZE	6

#define I2C_ADDR    0x70
#define SCROLL_DELAY	10000000	//100ms

typedef interface i_led_matrix_t {
	void show_sprite(unsigned sprite_idx);
	void scroll_sprites(const unsigned sprite_idxs[n], const unsigned n);
	void scroll_text_msg(const char message[n], const unsigned n);
} i_led_matrix_t;

const unsigned char blank[8] = {0, 0, 0, 0, 0, 0, 0, 0};
const unsigned char blank2[8] = {0, 0, 0, 0, 0, 0, 0, 0};
const unsigned char invader_top[8] = {
	0b00011000,
	0b00111100,
	0b01111110,
	0b11011011,
	0b11111111,
	0b00100100,
	0b01011010,
	0b10100101
};
const unsigned char invader0[8] = {
	0b00001000,
	0b00000100,
	0b00001111,
	0b00011011,
	0b00111111,
	0b00101111,
	0b00101000,
	0b00000110
};
const unsigned char invader1[8] = {
	0b00100000,
	0b01000000,
	0b11100000,
	0b10110000,
	0b11111000,
	0b11101000,
	0b00101000,
	0b11000000
};
const unsigned char ed[8] = {
	0b11100110,
	0b10000101,
	0b11100101,
	0b10000101,
	0b11100110,
	0b00000000,
	0b11111111,
	0b00000000
};

const unsigned char pacman[8] = {
	0b00011000,
	0b00111100,
	0b01101110,
	0b11111000,
	0b11111000,
	0b01111110,
	0b00111100,
	0b00011000
};

const unsigned char * user_sprites[] = {blank2, invader_top, invader0, invader1, ed, pacman};

static void show_sprite(client interface i2c_master_if i_i2c, const unsigned char sprite[]){
	i2c_res_t result;
	for (unsigned char row = 0; row < 8; row++){
		unsigned char write_val;
		unsigned int intermediate = sprite[row];
		intermediate = (unsigned char)(bitrev(intermediate) >> 24);
		if (intermediate & 0x1) intermediate |= 0x100;
		intermediate >>= 1;
		write_val = (unsigned char)intermediate;
		result = i_i2c.write_reg(I2C_ADDR, row * 2, write_val);
		//if (result == I2C_NACK) printstrln("I2C_NACK");
	}
}

#if 0
static unsafe void scroll_msg(client interface i2c_master_if i_i2c, const unsigned char * unsafe sprite_array[n], const unsigned n) {
	unsigned char frame_buf[8];
	for (int sp = -1; sp < (int)n; sp++){
		const unsigned char * unsafe curr;
		const unsigned char * unsafe next;
		if (sp == -1) {
			curr = blank;
			next = sprite_array[0];
		}
		else if (sp == (n - 1)) {
			curr = sprite_array[sp];
			next = blank;
		}
		else if (sp == n) {
			curr = blank;
			next = blank;
		}
		else {
			curr = sprite_array[sp];
			next = sprite_array[sp + 1];
		}
		//Show first and scroll in next
		for (int step = 0; step < 8; step++) {
			for (int row = 0; row < 8; row++) {
				unsigned tmp_row;
				tmp_row = (*(curr + row) << 8) | (*(next + row));
				frame_buf[row] = tmp_row >> (8 - step);
			}
			show_sprite(i_i2c, frame_buf);
			delay_milliseconds(100);
		}
	}
}
#endif

static unsigned make_msg_string(const char *string, unsigned string_len, unsigned char sprite_array[64][8]) {
	unsigned horiz_pos = 0;
	unsigned msg_len = 0;

	memset(sprite_array, 0, sizeof(sprite_array));

	for (int i = 0; i < string_len; i++) {
		unsigned char tmp_out[8] = {0};
		char current = *(string + i);
		for (int h = 0; h < FONT_H_SIZE; h++) {					//6
			unsigned char tmp_in = f8x6fv[current][h];
			//printhexln(tmp_in);
			for (int v = 0; v < FONT_V_SIZE; v++) {				//8
				unsigned r = tmp_in & (0x01 << v);
				//printf("h:%d v:%d result:%d\n", h, v, r);
				if (r) {
					tmp_out[v] |= (0x80 >> h);
				}
			}
		}

		for (int v = 0; v < FONT_V_SIZE; v++) {				//8
			sprite_array[msg_len][v] |= tmp_out[v] >> horiz_pos;
			sprite_array[msg_len + 1][v] |= ((unsigned)tmp_out[v] << 8) >> horiz_pos;
		}

		horiz_pos += FONT_H_SIZE;
		if (horiz_pos >= 8) {
			horiz_pos -= 8;
			msg_len ++;
		}
	}
	return msg_len + 1;
}

void led_matrix(server i_led_matrix_t i_led_matrix, client interface i2c_master_if i_i2c, unsigned duty_4b) {
	i2c_res_t result;
	unsigned char buf[1];	//Used for init
	size_t bytes_sent;		//ditto

	unsigned char scroll_data[64][8];
	unsigned char * unsafe msg[64];

	//Stuff for scrolling
	int sp;	//Sprite pointer
	unsigned scrolling_flag = 0;
	timer t;
	unsigned timeout;
	int step = 0;
	unsigned n_sprites = 0;

	//Enable clk
	buf[0] = 0b00100001;	//enable osc
	result = i_i2c.write(I2C_ADDR, buf, 1, bytes_sent, 0);
	//Row output set
	buf[0] = 0b10100000; //Row driver output
	result = i_i2c.write(I2C_ADDR, buf, 1, bytes_sent, 0);
	//Dimming set
	buf[0] = 0b11100000; 
	buf[0] |= (duty_4b & 0x7); //duty up to 16
	result = i_i2c.write(I2C_ADDR, buf, 1, bytes_sent, 0);
	//Blinking off, display on
	buf[0] = 0b10000001;
	result = i_i2c.write(I2C_ADDR, buf, 1, bytes_sent, 0);

	while(1) {
		select {
			case i_led_matrix.show_sprite(unsigned sprite_idx):
				show_sprite(i_i2c, user_sprites[sprite_idx]);
				scrolling_flag = 0; //Cancel any previous scrolling
				break;

			case i_led_matrix.scroll_sprites(const unsigned sprite_idxs[n], const unsigned n):
				unsafe{
					for(int i = 0; i < n; i++) msg[i] = (unsigned char * unsafe)user_sprites[sprite_idxs[i]];
				}

				//Go sprite scrolling!
				sp = -1;
				step = 0;
				n_sprites = n;
				scrolling_flag = 1;
				t :> timeout;
				break;

			case i_led_matrix.scroll_text_msg(const char message[n], const unsigned n):
				char msg_cpy[64];
				memcpy(msg_cpy, message, n);
				unsigned len = make_msg_string(msg_cpy, n, scroll_data);
				unsafe {
					for (int i = 0; i < len; i++) {
						msg[i] = &scroll_data[i][0];	
					}
				}

				//Go sprite scrolling!
				sp = -1;
				step = 0;
				n_sprites = len;
				scrolling_flag = 1;
				t :> timeout;
				break;

			case scrolling_flag => t when timerafter(timeout + SCROLL_DELAY) :> timeout:
				unsafe {
					const unsigned char * unsafe curr;
					const unsigned char * unsafe next;
					unsigned char frame_buf[8];

					if (sp == -1) {
						curr = blank;
						next = msg[0];
					}
					else if (sp == (n_sprites - 1)) {
						curr = msg[sp];
						next = blank;
					}
					else if (sp == n_sprites) {
						curr = blank;
						next = blank;
					}
					else {
						curr = msg[sp];
						next = msg[sp + 1];
					}
					//Update all 8 rows
					for (int row = 0; row < 8; row++) {
						unsigned tmp_row;
						tmp_row = (*(curr + row) << 8) | (*(next + row));
						frame_buf[row] = tmp_row >> (8 - step);
					}
					show_sprite(i_i2c, frame_buf);
				}
				step++;	//increment horizontal idx
				if (step == 8) {
					step = 0;
					sp++;	//next sprite
					if (sp == n_sprites) scrolling_flag = 0; //finished
				}
				break; 
		}
	}
}



