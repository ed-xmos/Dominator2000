#include "i2c.h"
#include <xs1.h>
#include <stdio.h>
#include <xclib.h>

#define I2C_ADDR	0x70

port p_scl = XS1_PORT_1G; //22
port p_sda = XS1_PORT_1H; //23

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

void show_sprite(client interface i2c_master_if i_i2c, unsigned char sprite[]){
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

void test(client interface i2c_master_if i_i2c){

	unsigned char invader[8] = {
		0b00011000,
		0b00111100,
		0b01111110,
		0b11011011,
		0b11111111,
		0b00100100,
		0b01011010,
		0b10100101
	};
	unsigned char ed[8] = {
		0b11100110,
		0b10000101,
		0b11100101,
		0b10000101,
		0b11100110,
		0b00000000,
		0b11111111,
		0b00000000
	};



	init_display(i_i2c, 5);
	while(1){
		show_sprite(i_i2c, invader);
		delay_milliseconds(200);
		show_sprite(i_i2c, ed);
		delay_milliseconds(200);
	}
}

int main(void){
	i2c_master_if i_i2c[1];
	par {
		i2c_master(i_i2c, 1, p_scl, p_sda, 400);
		test(i_i2c[0]);
	}
	return 0;
}