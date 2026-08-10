################################################################################
#
# libxcrypt
#
################################################################################

LIBXCRYPT_VERSION = 4.5.2
LIBXCRYPT_SITE = https://github.com/besser82/libxcrypt/releases/download/v$(LIBXCRYPT_VERSION)
LIBXCRYPT_SOURCE = libxcrypt-$(LIBXCRYPT_VERSION).tar.xz
LIBXCRYPT_LICENSE = LGPL-2.1+
LIBXCRYPT_LICENSE_FILES = LICENSING COPYING.LIB
LIBXCRYPT_INSTALL_STAGING = YES

# Some warnings turn into errors with some sensitive compilers
LIBXCRYPT_CONF_OPTS = --disable-werror
HOST_LIBXCRYPT_CONF_OPTS = --disable-werror

# Disable obsolete and insecure API
LIBXCRYPT_CONF_OPTS += --disable-obsolete_api
HOST_LIBXCRYPT_CONF_OPTS += --disable-obsolete_api

# macOS hosts: tell configure which endianness macros to use.
#
# libxcrypt does not use AC_C_BIGENDIAN. It probes for a pair of macros in
# <endian.h>, <sys/endian.h> and <sys/param.h>, and macOS provides none of
# them -- it puts BYTE_ORDER in <machine/endian.h>. The probe therefore
# returns "unknown" and configure aborts with
#   error: unable to determine byte order at compile time
#
# The value chosen uses only compiler built-ins, so it depends on no header at
# all: clang and gcc both define __BYTE_ORDER__ together with
# __ORDER_LITTLE_ENDIAN__ / __ORDER_BIG_ENDIAN__. Note the neighbouring
# "__BYTE_ORDER__ and __xxx_ENDIAN__" case would NOT work here, because macOS
# clang defines __LITTLE_ENDIAN__ but not __BIG_ENDIAN__.
#
# This is set rather than hardcoding little-endian: the macros still resolve
# at compile time, so a big-endian host would still be handled correctly.
#
# macOS 主機：告訴 configure 該使用哪一組位元組序巨集。libxcrypt 並非使用
# AC_C_BIGENDIAN，而是在 <endian.h>、<sys/endian.h>、<sys/param.h> 中尋找特定
# 巨集組合，而 macOS 三者皆無（它把 BYTE_ORDER 放在 <machine/endian.h>），
# 偵測因此得到 "unknown" 並中止。
# 此處選用的值只依賴編譯器內建巨集，完全不需要任何 header：clang 與 gcc 皆會
# 同時定義 __BYTE_ORDER__ 與 __ORDER_LITTLE_ENDIAN__ / __ORDER_BIG_ENDIAN__。
# 注意相鄰的 "__BYTE_ORDER__ and __xxx_ENDIAN__" 在此不可行，因為 macOS 的
# clang 有定義 __LITTLE_ENDIAN__ 卻沒有 __BIG_ENDIAN__。
# 採用設定 cache 變數而非寫死小端序：巨集仍於編譯時求值，大端序主機依然正確。
ifeq ($(shell uname -s),Darwin)
HOST_LIBXCRYPT_CONF_ENV += \
	ac_cv_c_byte_order_macros="__BYTE_ORDER__ and __ORDER_xxx_ENDIAN__"
endif

$(eval $(autotools-package))
$(eval $(host-autotools-package))
