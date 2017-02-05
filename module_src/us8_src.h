// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#ifndef _SRC_H_
#define _SRC_H_

#if defined(__cplusplus) || defined(__XC__)
extern "C" {
#endif

/** Upsample by 2 control structure */
typedef struct src_ctrl_t
{
    int*         delay_base[3];   //!< Pointer to delay line base
    unsigned int delay_len[3];    //!< Total length of delay line
    unsigned int delay_idx[3];    //!< Delay line offset for second write (for circular buffer simulation)
    unsigned int inner_loops[3];  //!< Number of inner loop iterations
    unsigned int num_coeffs[3];   //!< Number of coefficients
    int*         coeffs[3];       //!< Pointer to coefficients
    unsigned int phase[3];        //!< Current phase of polyphase filters
} src_ctrl_t;


/** Initialises synchronous sample rate conversion instance.
 *  \param   sr_in                    Nominal sample rate code of input stream
 *  \param   sr_out                   Nominal sample rate code of output stream
 *  \param   ssrc_ctrl                Reference to array of SSRC control stuctures
 *  \param   n_channels_per_instance  Number of channels handled by this instance of SSRC
 *  \param   n_in_samples             Number of input samples per SSRC call
 *  \param   dither_on_off            Dither to 24b on/off
 */
void src_init(src_ctrl_t src_ctrl[]);

/** Perform synchronous sample rate conversion processing on block of input samples using previously initialized settings.
 *
 *  \param   in_buff          Reference to input sample buffer array
 *  \param   out_buff         Reference to output sample buffer array
 *  \param   ssrc_ctrl        Reference to array of SSRC control stuctures
 *  \returns The number of output samples produced by the SRC operation
 */
unsigned src_process(int in_samp, int out_buff[], src_ctrl_t src_ctrl[]);

#endif // _SRC_H_
