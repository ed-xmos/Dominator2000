#include <xs1.h>
#include <stdio.h>
#include <xclib.h>
#include <stdlib.h>
#include <print.h>
#include <string.h>

#define KICKOFF 500000 // 10us
#define SEQ_PERIOD 10000

#define NUM_PROGS					2
#define MAX_PROG_LENGTH		128

//Instuction fromat
//BYTE3 BYTE2 BYTE1 BYTE0
//instr val   delay	delay (seq periods)

typedef enum instructions {
	NOP = 0x00000000,
	LED = 0x01000000,
	PLAY = 0x02000000,
	END = 0x030000000,
} instructions;

typedef enum operands {
	OFF = 0x00000000,
	ON = 0x00010000,
	FUNK = 0x00020000,
	LIGHTSBR = 0x00030000

} operands;

const unsigned program[NUM_PROGS][MAX_PROG_LENGTH] = {
{
	PLAY | FUNK | 0,
	LED | ON | 4,
	LED | OFF| 4,
	LED | ON | 4,
	LED | OFF| 4,
	LED | ON | 4,
	LED | OFF| 0,
	END |      0
},
{
	PLAY | LIGHTSBR | 0,
	END |      0
}

};

interface dostuff_if {
	void led(unsigned val);
	void play(const char track[], size_t track_size);
	[[notification]] slave void button_press(void);
  [[clears_notification]] unsigned button_pressed_ack(void);
};

void my_slave(server interface dostuff_if i_dostuff){
	timer t;
	unsigned time;
	t :> time;
	time += KICKOFF;
	while(1){
		select{
			case i_dostuff.led(unsigned val):
				printf("LED: %s\n", val ? "ON" : "OFF");
				break;

			case i_dostuff.play(const char track[], size_t track_size):
				char track_cpy[64];
				memcpy(track_cpy, track, track_size);
				printf("Playing %s\n", track_cpy);
				break;

			case i_dostuff.button_pressed_ack(void) -> unsigned but_idx:
				printf("Button press ACK\n");
				but_idx = 0;
				break;

			case t when timerafter(time) :> void:
				i_dostuff.button_press();
				time += KICKOFF; //Long time in the future
				break;
		}
	}
}

void sequencer(client interface dostuff_if i_dostuff)
{
	timer t;
	unsigned trig_time;
	unsigned running[NUM_PROGS] = {0};
	unsigned intstr_idx[NUM_PROGS] = {0};
	unsigned delay_counter[NUM_PROGS] = {0};

	while(1){
		select{
			case t when timerafter(trig_time + SEQ_PERIOD) :> trig_time:
				for (int i = 0; i < NUM_PROGS; i++)
				{
					if (running[i] != 0)
					{
						if (delay_counter[i] == 0)
						{
							unsigned instruction = program[i][intstr_idx[i]] & 0xff000000;
							unsigned operand = program[i][intstr_idx[i]] & 0x00ff0000;
							delay_counter[i] = program[i][intstr_idx[i]] & 0x0000ffff;
							switch (instruction){
								case NOP:
									break;

								case LED:
									i_dostuff.led(operand >> 16);
									break;

		 						case PLAY:
		 							char track[64];
			 						switch (operand){
			 							case FUNK:
			 								strcpy(track, "FUNK.MP3");
			 								i_dostuff.play(track, strlen(track) + 1);
			 								break;

			 							case LIGHTSBR:
			 								strcpy(track, "LIGHTSBR.MP3");
			 								i_dostuff.play(track, strlen(track) + 1);
			 								break;

			 							default:
			 								printf("Error invalid track index\n");
			 								break;
		 							}
									break;

								case END:
									running[i] = 0;
									printf("END\n");
									break;

								default:
									printf("invalid instruction\n");
									__builtin_trap();
									break;
							}
							intstr_idx[i]++;
						} 
						else //delay_counter is non-zero
						{
							printf("waiting - %d\n", delay_counter[i]);
							delay_counter[i]--; //skip instruction for once cycle
						}
					}
					else //if not running, do nothing
					{
						//printf(".\n");
					}
				}
				break;

			case i_dostuff.button_press():
				unsigned but_idx = i_dostuff.button_pressed_ack();
				running[but_idx] = 1;
				intstr_idx[but_idx] = 0;
				delay_counter[but_idx] = 0;
				break;
		}
	}
}

int main(void){
	interface dostuff_if i_dostuff;
	par {
		my_slave(i_dostuff);
		sequencer(i_dostuff);
	}
	return 0;
}