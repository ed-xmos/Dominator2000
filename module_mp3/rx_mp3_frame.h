#ifndef RX_MP3_FRAME_H_
#define RX_MP3_FRAME_H_

#include <xccompat.h>

int RxNewFrame(unsigned char readBuf[], int size, streaming_chanend_t rx_mp3);

#endif /*RX_MP3_FRAME_H_*/
