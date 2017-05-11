#include <xs1.h>
#include <platform.h>

out port p_overlays_xscope = XS1_PORT_8D; //D36..43 xscope is 40..43

int main(void){
	p_overlays_xscope <: 0;
	return 0;
}