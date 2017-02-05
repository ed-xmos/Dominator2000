#include <xs1.h>
#include <stdio.h>
#include <s1k_0db_44.dat>

#define N_ITERATIONS	256

int output[N_ITERATIONS * 8];

int main(void){
	src_ctrl_t src_ctl;
	src_init(src_ctl);

	for (int i=0; i<N_ITERATIONS; i++) {
		int sample_in = sine_44k[i];
		ssrc_process(&sample_in, &output[i * 8], src_ctl);
	}

	for (int i=0; i<128; i++) {
		printf("%d\n", output[i]);
	}

	return 0;
}