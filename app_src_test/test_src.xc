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
		timer t;
		int t0, t1;
		int sample_in;
		sample_in = sine_44k[i];
		//if (i == 0) sample_in = 0x7FFFFFFF;
		//else sample_in = 0;
		//printf("%d\n", sample_in);
		t :> t0;
		src_process(sample_in, &output[i * 8], &src_ctl);
		t :> t1;
		//printf("Time in ticks = %d\n", t1 - t0);
	}

	for (int i=0; i<N_ITERATIONS*8; i++) {
		printf("%d\n", output[i]);
	}

	return 0;
}