# The TARGET variable determines what target system the application is 
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling.

TARGET = XCORE-200-EXPLORER.xn

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to 
# the project name
APP_NAME = 

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
#
#    XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
#
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to 
# xcc for the final link (mapping) stage.

XCC_FLAGS = -Os -g -report -lquadflash
#-DUNSAFE_LIBC

# The USED_MODULES variable lists other module used by the application. 
USED_MODULES = module_buttons module_pwm_wide module_quadrature_encoder module_resistor_read module_led_matrix \
							module_pwm_fast module_mp3 lib_filesystem module_src lib_dsp module_7_seg module_audio lib_i2c


sim: bin/app_dominator2000.xe
		xsim bin/app_dominator2000.xe --max-cycles 1000000 --trace-plugin VcdPlugin.dll '-tile tile[0] -o trace.vcd -xe bin/app_dominator2000.xe -ports -cores'

#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common

