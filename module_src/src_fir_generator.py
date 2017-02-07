import numpy as np
from scipy import signal
import matplotlib.pyplot as plt


def plot_response(fs, w, h, title):
    plt.figure()
    plt.plot(0.5*fs*w/np.pi, 20*np.log10(np.abs(h)))

    plt.xlim(0, 0.5*fs)
    plt.grid(True)
    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Gain (dB)')
    plt.title(title)
    plt.show()

def plot_response_passband(fs, w, h, title):
    plt.figure()
    plt.plot(0.5*fs*w/np.pi, 20*np.log10(np.abs(h)))
    plt.ylim(-1, 1)
    plt.xlim(0, 0.5*fs)
    plt.grid(True)
    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Gain (dB)')
    plt.title(title)


def make_filter(fs, transition_low, transition_high, numtaps, name, weight):
    interpolation_factor = 2
    taps = signal.remez(numtaps, [0, transition_low, transition_high, 0.5*fs], [1, 0], weight=weight, Hz=fs)
    w, h = signal.freqz(taps)
    plot_response(fs, w, h, "Low-pass Filter")
    #plot_response_passband(fs, w, h, "Low-pass Filter")

    pass_band_atten = sum(abs(taps))

    taps = taps / pass_band_atten    # Guarantee no overflow

    q = 31 -int(np.log2(pass_band_atten) + 0.5)
    content = '#define ' + name.upper() + "_LENGTH  " + str(numtaps) + '\n'
    content += 'const unsigned ' + name + '_comp_q = ' + str(q) + ';\n'
    content += 'const int ' + name + '_comp = ' + str(int(((2**q)-1) * pass_band_atten)) + ';\n'

    content += 'int ' + name + '_coefs_debug[' + str(numtaps) + '] = {\n'
    for c in taps:
        c = int(c*(2**31 - 1))
        content += str(c) + ',\n '
    content += '};\n'

    content +=  'const int ' + name + '_coefs[' + str(interpolation_factor) + '][' + str(numtaps/interpolation_factor)+ '] = {\n'
    for step in range(interpolation_factor - 1, -1, -1):
        content +=  '\t{\n'
        for i in range(step, len(taps), interpolation_factor):
            c = int(taps[i]*(2**31 - 1))
            content +=  '\t' + str(c) + ',\n'
        content +=  '\t},\n'
    content +=  '};\n\n'
    return content


include_file = open("src/coeffs.h", "w")

# Low-pass filter design parameters
fs = 96000.0        # Sample rate, Hz
numtaps = 32 * 2    # Size of the FIR filter.
transition_low = fs / 2 * 0.41
transition_high = fs / 2 * 0.51
name = "stage_0_fir"
weight=[.2, .8]
content = make_filter(fs, transition_low, transition_high, numtaps, name, weight)

# Low-pass filter design parameters
fs = 192000.0        # Sample rate, Hz
numtaps = 16 * 2    # Size of the FIR filter.
transition_low = fs / 4 * 0.41
transition_high = fs / 4 * 0.51
name = "stage_1_fir"
weight=[.2, 8]
content += make_filter(fs, transition_low, transition_high, numtaps, name, weight)

# Low-pass filter design parameters
fs = 384000.0        # Sample rate, Hz
numtaps = 16 * 2    # Size of the FIR filter.
transition_low = fs / 4 * 0.41
transition_high = fs / 4 * 0.51
name = "stage_2_fir"
weight=[.4, .6]
content += make_filter(fs, transition_low, transition_high, numtaps, name, weight)

include_file.write(content)
include_file.close()