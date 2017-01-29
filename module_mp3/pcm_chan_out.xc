#include <platform.h>
#include <print.h>
#include "pcm_chan_out.h"

void OutputToPCMBuf(short pcmSample, short index, chanend pcmChan)
{
	int word = (pcmSample << 16) | index;
	pcmChan <: word;
}
