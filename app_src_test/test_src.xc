#include <xs1.h>
#include <stdio.h>
#include <s1k_0db_44.dat>
#include "us8_src.h"

#define N_ITERATIONS	64

int output[N_ITERATIONS * 8];

int main(void){
	src_ctrl_t src_ctl;
	src_init(&src_ctl);

	for (int i=0; i<N_ITERATIONS; i++) {
		int sample_in;
		sample_in = sine_44k[i];
		//if (i == 0) sample_in = 0x7FFFFFFF;
		//else sample_in = 0;
		//printf("%d\n", sample_in);
		src_process(sample_in, &output[i * 8], &src_ctl);
	}

	for (int i=0; i<N_ITERATIONS*8; i++) {
		printf("%d\n", output[i]);
	}

	return 0;
}