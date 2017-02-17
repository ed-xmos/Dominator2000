#include "i2c.h"
#include <xs1.h>
#include <stdio.h>
#include <xclib.h>
#include <stdlib.h>
#include <print.h>

#define I2C_ADDR	0x70

port p_scl = XS1_PORT_1G; //22
port p_sda = XS1_PORT_1H; //23

const unsigned char blank[8] = {0};
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
	0b01111110,
	0b11111111,
	0b11111111,
	0b01111110,
	0b00111100,
	0b00011000
};

void init_display(client interface i2c_master_if i_i2c, unsigned duty){
	i2c_res_t result;
	unsigned char buf[1];
	size_t bytes_sent;

	//Enable clk
	buf[0] = 0b00100001;	//enable osc
	result = i_i2c.write(I2C_ADDR, buf, 1, bytes_sent, 0);
	//Row output set
	buf[0] = 0b10100000; //Row driver output
	result = i_i2c.write(I2C_ADDR, buf, 1, bytes_sent, 0);
	//Dimming set
	buf[0] = 0b11100000; //duty up to 16
	buf[0] |= (duty & 0xf);
	result = i_i2c.write(I2C_ADDR, buf, 1, bytes_sent, 0);
	//Blinking off, display on
	buf[0] = 0b10000001;
	result = i_i2c.write(I2C_ADDR, buf, 1, bytes_sent, 0);
	//Write to pixels (address set, RAM write, display on)
}

void show_sprite(client interface i2c_master_if i_i2c, const unsigned char sprite[]){
	i2c_res_t result;
	for (unsigned char row = 0; row < 8; row++){
		unsigned char write_val;
		unsigned int intermediate = sprite[row];
		intermediate = (unsigned char)(bitrev(intermediate) >> 24);
		if (intermediate & 0x1) intermediate |= 0x100;
		intermediate >>= 1;
		write_val = (unsigned char)intermediate;
		result = i_i2c.write_reg(I2C_ADDR, row * 2, write_val);
	}
}

unsafe void scroll_msg(client interface i2c_master_if i_i2c, const unsigned char * unsafe sprite_array[n], const unsigned n) {
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


void test(client interface i2c_master_if i_i2c){

	init_display(i_i2c, 5);
	for(int i=0; i<4; i++) {
		show_sprite(i_i2c, invader_top);
		delay_milliseconds(100);
		show_sprite(i_i2c, ed);
		delay_milliseconds(100);
	}
	show_sprite(i_i2c, pacman);

	unsafe {
		const unsigned char * unsafe msg[2] = {invader0, invader1};
		printf("starting scroll\n");
		while(1){
			scroll_msg(i_i2c, msg, 2);
		}
	}
	_Exit(0);	
}

int main(void){
	i2c_master_if i_i2c[1];
	par {
		i2c_master(i_i2c, 1, p_scl, p_sda, 400);
		test(i_i2c[0]);
	}
	return 0;
}