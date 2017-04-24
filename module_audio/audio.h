#ifndef __AUDIO__
#define __AUDIO__
#include "filesystem.h"


typedef interface i_mp3_player_t {
	void play_file(const char filename[], size_t len_filename);
} i_mp3_player_t;

void mp3_player(client interface fs_basic_if i_fs, streaming chanend c_mp3_chan, chanend c_mp3_stop ,server i_mp3_player_t i_mp3_player);
void pcm_post_process(chanend c_pcm_chan, streaming chanend c_pwm_fast, chanend c_atten);

#endif