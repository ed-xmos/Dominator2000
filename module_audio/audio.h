#ifndef __AUDIO__
#define __AUDIO__
#include "filesystem.h"
#define MAX_VOL 0x7fffffff	//int max (no volume attenuation)
#define INIT_VOL (MAX_VOL >> 2) //About 12db down at startup

typedef interface i_mp3_player_t {
	void play_file(const char filename[], size_t len_filename);
	unsigned is_playing(void);
} i_mp3_player_t;

void mp3_player(client interface fs_basic_if i_fs, streaming chanend c_mp3_chan, chanend c_mp3_stop ,server i_mp3_player_t i_mp3_player);
void pcm_post_process(chanend c_pcm_chan, streaming chanend c_pwm_fast, chanend c_atten);

#endif