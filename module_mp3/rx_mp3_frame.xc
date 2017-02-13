#include <xs1.h>
#include <print.h>
#include "rx_mp3_frame.h"

int RxNewFrame(unsigned char readBuf[], int size, streaming chanend rx_mp3)
{
    int frame_len = 0;
    select {
        case rx_mp3 :> frame_len:
        if (frame_len == 0xDEADBEEF) {
            return frame_len;
        }
        else {
            sin_char_array(rx_mp3, readBuf, frame_len);
        }
            break;
        default:
            break;
    }
    return frame_len;
}

void check_for_stop(int *outOfData, chanend c_mp3_stop){
    select {
        case c_mp3_stop :> int _:
            *outOfData = 1;
            break;
        default:
            break;
    }
}