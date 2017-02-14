#include <stdio.h>
#include <string.h>
#include <print.h>
//#include "debug_print.h"
#include <xassert.h>
//#include <xscope.h>
#include "mp3dec.h"
#include "decode_main.h"
#include "pcm_chan_out.h"
#include "rx_mp3_frame.h"

#define READBUF_SIZE (MAX_NGRAN * MAX_NSAMP * 2 * 8) // 2 * 576 * 2 * 8 = 18.432 KB

int decoderMain(chanend pcmChan, streaming_chanend_t rxChan, chanend c_mp3_stop)
{
	int bytesLeft, nRead, err, offset, outOfData, eofReached, nFrames;
	unsigned char readBuf[READBUF_SIZE], *readPtr;
	int tot_bytes = 0;

	MP3FrameInfo mp3FrameInfo;
	HMP3Decoder hMP3Decoder;
	
	if ( (hMP3Decoder = MP3InitDecoder()) == 0 )
	{
		return -2;
	}
	
	bytesLeft = 0;
	outOfData = 0;
	eofReached = 0;
	readPtr = readBuf;
	nRead = 0;
	offset = 0;

	nFrames = 0;

	int cont = 0;
	int end_of_stream = 1;
	int end_of_stream_seen = 0;
		
	do
	{
		if (!cont) memmove(readBuf, readPtr, bytesLeft);
		else cont = 0;

		do {
			if (bytesLeft < 16384 && !end_of_stream_seen) {
				//Non blocking using select
				nRead = RxNewFrame(&readBuf[bytesLeft], READBUF_SIZE, rxChan);
				if (nRead == 0xDEADBEEF) { // The other end indicated the end of stream
					end_of_stream_seen = 1;
					break;
				}
				//printf("nRead=%d\n", nRead);
				xassert((nRead + bytesLeft) < (READBUF_SIZE));
				bytesLeft += nRead;
				tot_bytes += nRead;
				//printf("bytesLeft: %d\n", bytesLeft);
				int stop;
				check_for_stop(&stop, c_mp3_stop);
				if (stop) break;
			}
		} while (end_of_stream && bytesLeft < 16384);
		end_of_stream = 0;
		if (bytesLeft < 144)
		{
			if (end_of_stream_seen) {
				end_of_stream = 1;
				end_of_stream_seen = 0;
			}
			cont = 1;
			continue;
		}
		readPtr = readBuf;

		//xscope_int(MP3_BYTES_LEFT, bytesLeft);
		//printf("TOT: %d, frames: %d\n", tot_bytes, nFrames);
		
		/* decode one MP3 frame - if offset < 0 then bytesLeft was less than a full frame */
		
		int ret;
		do {
			offset = MP3FindSyncWord(readPtr, bytesLeft);
			//printf("offset = %d\n", offset);
			ret = MP3GetNextFrameInfo(hMP3Decoder, &mp3FrameInfo, &readPtr[offset]);
			if (ret != ERR_MP3_NONE) {
				bytesLeft -= 2;
				readPtr += 2;
			}
		} while (ret != ERR_MP3_NONE);


		xassert(offset >= 0);
		bytesLeft -= offset;
		readPtr += offset;
		//xscope_int(MP3_DECODE_START, 1);
		//printf("Decode bytesLeft: %d\n", bytesLeft);

		err = MP3Decode(hMP3Decoder, &readPtr, &bytesLeft, NULL, 0, pcmChan);
		//xscope_int(MP3_DECODE_STOP, 1);
		//printf("Read: %d, left: %d\n", nRead, bytesLeft);
		
		nFrames++;
		
		if (err)
		{
			/* error occurred */
			switch (err)
			{
			case ERR_MP3_INDATA_UNDERFLOW:
				printstrln("ERR_MP3_INDATA_UNDERFLOW");
				outOfData = 1;
				break;
			case ERR_MP3_MAINDATA_UNDERFLOW:
				/* do nothing - next call to decode will provide more mainData */
				continue;
			case ERR_MP3_FREE_BITRATE_SYNC:
			default:
				outOfData = 1;
				printf("Decode failed with error %d\n", err);
				while (1);
				break;
			}
		}
		else 
		{
			/* no error */
			// MP3GetLastFrameInfo(hMP3Decoder, &mp3FrameInfo);
		}
	check_for_stop(&outOfData, c_mp3_stop); //will set outofdata to 1 if token received

	} while (!outOfData);
	
	MP3FreeDecoder(hMP3Decoder);
	
	return 0;
}
