CC=arm-linux-gnueabihf-gcc
prefix=/home/yi-hack/
libdir=/home/yi-hack/lib
sysconfdir=/home/yi-hack/etc
USER_CFLAGS=-mcpu=cortex-a7 -mfpu=neon-vfpv4 -I$TOOLCHAIN_PATH/arm-linux-gnueabihf/libc/usr/include -L$TOOLCHAIN_PATH/arm-linux-gnueabihf/libc/lib/arm-linux-gnueabihf
USER_LDFLAGS=
AR=arm-linux-gnueabihf-ar
RANLIB=arm-linux-gnueabihf-ranlib
