THEOS_MAKE_PATH = /tmp/theos/makefiles

include $(THEOS_MAKE_PATH)/common.mk

ARCHS = arm64 armv7
TARGET = iphone:clang:latest:10.3

TWEAK_NAME = YouTubeFix
YouTubeFix_FILES = Tweak.xm
YouTubeFix_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	@echo "Installed! Respring needed"
