#define STAGE_0_FIR_LENGTH  64
const unsigned stage_0_fir_comp_q = 30;
const int stage_0_fir_comp = 2121380175;
int stage_0_fir_coefs_debug[64] = {
172803,
 -1025088,
 -1469005,
 103051,
 1885689,
 427858,
 -2650353,
 -1572500,
 3235302,
 3340358,
 -3343583,
 -5706891,
 2627049,
 8531859,
 -707436,
 -11520713,
 -2783686,
 14220790,
 8186010,
 -16003798,
 -15823492,
 16030225,
 26091256,
 -13122154,
 -39770439,
 5280940,
 59043114,
 12243622,
 -91943203,
 -58423706,
 192127167,
 454328667,
 454328667,
 192127167,
 -58423706,
 -91943203,
 12243622,
 59043114,
 5280940,
 -39770439,
 -13122154,
 26091256,
 16030225,
 -15823492,
 -16003798,
 8186010,
 14220790,
 -2783686,
 -11520713,
 -707436,
 8531859,
 2627049,
 -5706891,
 -3343583,
 3340358,
 3235302,
 -1572500,
 -2650353,
 427858,
 1885689,
 103051,
 -1469005,
 -1025088,
 172803,
 };
const int stage_0_fir_coefs[2][32] = {
	{
	-1025088,
	103051,
	427858,
	-1572500,
	3340358,
	-5706891,
	8531859,
	-11520713,
	14220790,
	-16003798,
	16030225,
	-13122154,
	5280940,
	12243622,
	-58423706,
	454328667,
	192127167,
	-91943203,
	59043114,
	-39770439,
	26091256,
	-15823492,
	8186010,
	-2783686,
	-707436,
	2627049,
	-3343583,
	3235302,
	-2650353,
	1885689,
	-1469005,
	172803,
	},
	{
	172803,
	-1469005,
	1885689,
	-2650353,
	3235302,
	-3343583,
	2627049,
	-707436,
	-2783686,
	8186010,
	-15823492,
	26091256,
	-39770439,
	59043114,
	-91943203,
	192127167,
	454328667,
	-58423706,
	12243622,
	5280940,
	-13122154,
	16030225,
	-16003798,
	14220790,
	-11520713,
	8531859,
	-5706891,
	3340358,
	-1572500,
	427858,
	103051,
	-1025088,
	},
};

#define STAGE_1_FIR_LENGTH  32
const unsigned stage_1_fir_comp_q = 30;
const int stage_1_fir_comp = 2029764992;
int stage_1_fir_coefs_debug[32] = {
15317309,
 25194252,
 37064527,
 43198671,
 38310649,
 19558643,
 -11291687,
 -47088926,
 -76543829,
 -87397369,
 -70661391,
 -24404114,
 44443683,
 121150791,
 187047990,
 225067984,
 225067984,
 187047990,
 121150791,
 44443683,
 -24404114,
 -70661391,
 -87397369,
 -76543829,
 -47088926,
 -11291687,
 19558643,
 38310649,
 43198671,
 37064527,
 25194252,
 15317309,
 };
const int stage_1_fir_coefs[2][16] = {
	{
	25194252,
	43198671,
	19558643,
	-47088926,
	-87397369,
	-24404114,
	121150791,
	225067984,
	187047990,
	44443683,
	-70661391,
	-76543829,
	-11291687,
	38310649,
	37064527,
	15317309,
	},
	{
	15317309,
	37064527,
	38310649,
	-11291687,
	-76543829,
	-70661391,
	44443683,
	187047990,
	225067984,
	121150791,
	-24404114,
	-87397369,
	-47088926,
	19558643,
	43198671,
	25194252,
	},
};

#define STAGE_2_FIR_LENGTH  32
const unsigned stage_2_fir_comp_q = 30;
const int stage_2_fir_comp = 1857971624;
int stage_2_fir_coefs_debug[32] = {
-54049509,
 -12229250,
 1131005,
 20384154,
 36810116,
 41225459,
 28252047,
 457575,
 -31534965,
 -51622396,
 -44559977,
 -2337466,
 70664401,
 158342033,
 236904726,
 283236738,
 283236738,
 236904726,
 158342033,
 70664401,
 -2337466,
 -44559977,
 -51622396,
 -31534965,
 457575,
 28252047,
 41225459,
 36810116,
 20384154,
 1131005,
 -12229250,
 -54049509,
 };
const int stage_2_fir_coefs[2][16] = {
	{
	-12229250,
	20384154,
	41225459,
	457575,
	-51622396,
	-2337466,
	158342033,
	283236738,
	236904726,
	70664401,
	-44559977,
	-31534965,
	28252047,
	36810116,
	1131005,
	-54049509,
	},
	{
	-54049509,
	1131005,
	36810116,
	28252047,
	-31534965,
	-44559977,
	70664401,
	236904726,
	283236738,
	158342033,
	-2337466,
	-51622396,
	457575,
	41225459,
	20384154,
	-12229250,
	},
};

