#include <platform.h>
#include <print.h>
#include <xs1.h>
#include <string.h>
#include <xscope.h>
#include <stdlib.h> //_Exit()
#include <stdio.h>
#include "quadrature.h"
#include "led_7_seg.h"

on tile[0]: in port p_quadrature[2] = {XS1_PORT_1G, XS1_PORT_1H}; //X0D22, 33
on tile[1]: out port p_7_seg = XS1_PORT_8B;	//X1D14..X1D21
on tile[1]: out port p_7_seg_com[LED_N_DIGITS] = {XS1_PORT_1L, XS1_PORT_1O};	//X1D35, X1D38
on tile[1]: out port p_phy_rst = XS1_PORT_1N;	//X1D37




void app(client i_quadrature_t i_quadrature, client i_7_seg_t i_7_seg) {


	printf("App started\n");

	while(1) {
		select {
			case i_quadrature.rotate_event():
				int rotation = i_quadrature.get_count();
				if (rotation > 0) {
					i_7_seg.inc_val();
					//printstrln("+");
				}
				else if (rotation < 0) {
					i_7_seg.dec_val();
					//printstrln("-");
				}
				else printintln(rotation);
				break;
		}
	}
}

//nice slow combinable task. Odd number for timer so doesn't collide with quadrature
//[[combinable]]
void null_comb_task(void){
	timer t;
	int time;
	t :> time;
	while(1){
	select{
		case t when timerafter(time + 123456789) :> time:
			//printstrln("null");
			break;
		}
	}
}

int main(void) {
	i_quadrature_t i_quadrature;
  i_7_seg_t i_7_seg;

	par {
  	on tile[0]: {
 
		  for (int i = 0; i < 2; i++) set_port_pull_down(p_quadrature[i]); //Inputs are active high so pull down in chip

			par {			
				  par {
					null_comb_task();
					quadrature(p_quadrature, i_quadrature);	//This doesn't like being non-combined (exception)
				}
				app(i_quadrature, i_7_seg);
			}
		}
		on tile[1]: {
			p_phy_rst <: 0; //Hold eth phy in reset to keep it off the bus and save power - we want to use those pins
			set_port_drive_low(p_7_seg); //These are pulled high to 5V so open drain drive best
			for (int i = 0; i < LED_N_DIGITS; i++) set_port_drive_low(p_7_seg_com[i]); //as above

		  delay_milliseconds(500);	//Allow amp to power up

			par{
					led_7_seg(i_7_seg, p_7_seg, p_7_seg_com);
				}
			}
		}
	return 0;
}
