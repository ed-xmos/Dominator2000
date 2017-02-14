#!/usr/bin/env python
import sys, binascii
from shutil import copyfile
from os import remove

block_size = 1024	#Must be big enough to contain mp3 headers
mp3_v1_l3_hdr = (0b11111111, 0b11111010) #Layer 3 v1 header for MP3
mp3_v1_l3_mask = (0b11111111, 0b11111110) #mask for detecting above bit pattern
DEBUG = 1

def byte_to_val(byte):
	hexadecimal = binascii.hexlify(byte)
	val = int(hexadecimal, 16)
	return val

def extract_bits(word, idx, n):
	tmp = word >> idx
	mask = (1<<n) - 1
	#print idx, n, bin(mask)
	return tmp & mask

def find_mp3_data_index(block):
	data_index = 0
	fifo = []
	for byte in block:
		fifo.append(byte)
		if data_index > 2:
			b0 = byte_to_val(fifo[data_index])
			b1 = byte_to_val(fifo[data_index - 1])
			b2 = byte_to_val(fifo[data_index - 2])
			b3 = byte_to_val(fifo[data_index - 3])
			if (
				((b2 & mp3_v1_l3_mask[1]) == mp3_v1_l3_hdr[1])
				and
				((b3 & mp3_v1_l3_mask[0]) == mp3_v1_l3_hdr[0])
				):
				mp3_frame_hdr = (byte_to_val(fifo[-1]) 
					+ (byte_to_val(fifo[-2]) << 8)
					+ (byte_to_val(fifo[-3]) << 16)
					+ (byte_to_val(fifo[-4]) << 24))
				next_data_index = analyse_header(mp3_frame_hdr)
				return data_index - 3
		data_index += 1
	print "Error - end of wav file header not found"
	sys.exit 

def analyse_header(mp3_frame_hdr):
	ver = ("2.5", "reserved", "2", "1")
	layer = ("reserved",  "III", "II", "I")
	protection = ("protected by CRC", "Not protected")
	bitrate = ("free", "32", "40", "48", "56", "64", "80", "96", "112", "128", "160", "192", "224", "256", "320", "bad")
	sample_rate = ("44100", "48000", "32000", "reserved")
	padding = ("not padded", "padded")
	private = ("0", "1")
	chan_mode = ("stereo", "joint stereo", "dual channel", "single channel")
	#mode_ext =
	copyright = ("not copyrighted", "copyrighted")
	original = ("copy of original", "original")
	emphasis = ("none", "50/15ms", "reserved", "CCIT J.17")

	bitrate_KHz_str = bitrate[extract_bits(mp3_frame_hdr, 12, 4) ]
	sample_rate_str = sample_rate[extract_bits(mp3_frame_hdr, 10, 2)]
	padding_str = padding[extract_bits(mp3_frame_hdr, 9, 1) ]
	try:
		frame_len = (144 * (int(bitrate_KHz_str) * 1000)) / int(sample_rate_str) + (1 if padding_str == "padded" else 0)
	except ValueError:
		frame_len = 0
		print "INVALID RATE %s %s" % (bitrate_KHz_str, sample_rate_str)

	if DEBUG:
		print "  AAAAAAAAAAABBCCDEEEEFFGHIIJJKLMM"
		print bin(mp3_frame_hdr)

		print "frame header info"            
		print "ver:", ver[extract_bits(mp3_frame_hdr, 19, 2)]
		print "layer:", layer[extract_bits(mp3_frame_hdr, 17, 2)]
		print "has CRC:", protection[extract_bits(mp3_frame_hdr, 16, 1)]
		print "bitrate(kps) assuming v1, LIII:", bitrate_KHz_str
		print "sample rate:", sample_rate_str
		print "padding:", padding_str       
		print "private:", private[extract_bits(mp3_frame_hdr, 8, 1) ]
		print "channel mode:", chan_mode [extract_bits(mp3_frame_hdr, 6, 2) ]
		print "mode extention:", bin(extract_bits(mp3_frame_hdr, 4, 2) )
		print "copyrighted:", copyright[extract_bits(mp3_frame_hdr, 3, 1) ]  
		print "original copy:", original[extract_bits(mp3_frame_hdr, 2, 1) ]     
		print "emphasis:", emphasis[extract_bits(mp3_frame_hdr, 0, 2) ]
		print "frame length assuming LIII:", frame_len

	return frame_len


try:
  infile = sys.argv[1]
except:
  print "Please pass filename of wav to have it's header chopped.\nEg. python mp3strip.py <filename>"
  sys.exit(1)
outfile = infile.split(".")[:-1]
outfile = "".join(outfile) + "_stripped.mp3"
print outfile

with open(infile, "rb") as mp3file:
	block = mp3file.read(block_size)
	mp3_data_index = find_mp3_data_index(block)
	print "MP3 data starts at file index: %d" % mp3_data_index
	mp3file.seek(mp3_data_index)
	with open(outfile, "wb") as mp3_stripped_file:
		while True:
			block = mp3file.read(block_size)
			mp3_stripped_file.write(block)
			if len(block) == 0:
				copyfile(outfile, infile)
				remove(outfile)
				sys.exit(0)
	
