################################################################################
#
# libzlib
#
################################################################################

# When updating the version here, please also update the minizip-zlib package
LIBZLIB_VERSION = 1.3.2
LIBZLIB_SOURCE = zlib-$(LIBZLIB_VERSION).tar.xz
LIBZLIB_SITE = https://www.zlib.net
LIBZLIB_LICENSE = Zlib
LIBZLIB_LICENSE_FILES = LICENSE
LIBZLIB_INSTALL_STAGING = YES
LIBZLIB_PROVIDES = zlib
LIBZLIB_CPE_ID_VENDOR = zlib
LIBZLIB_CPE_ID_PRODUCT = zlib

# It is not possible to build only a shared version of zlib, so we build both
# shared and static, unless we only want the static libs, and we eventually
# selectively remove what we do not want
ifeq ($(BR2_STATIC_LIBS),y)
LIBZLIB_PIC =
LIBZLIB_SHARED = --static
else
LIBZLIB_PIC = -fPIC
LIBZLIB_SHARED = --shared
endif

# NOTE: a "$(shell uname -s) = Darwin -> --static" override used to live here.
# It was a workaround for zlib's configure hardcoding Apple libtool as AR on a
# Darwin host, which produced a broken 8-byte libz.a and could not link a shared
# library at all. That root cause is now fixed in the zlib submodule itself
# (dependencies/zlib commit 99381d6: only use the Darwin libtool default when
# the caller has not already set AR), so forcing --static is no longer needed.
#
# It is also actively harmful: it keys off the BUILD host, so cross-compiling
# from macOS produced no libz.so.1 at all, and the Swift toolchain's clang fails
# to start in the guest with
#   "libz.so.1: cannot open shared object file: No such file or directory".
#
# 此處原本有一段「build host 是 Darwin 就強制 --static」的覆寫，用來繞開 zlib
# configure 在 Darwin 上硬指定 Apple libtool 為 AR、產生 8 bytes 壞掉的 libz.a
# 的問題。該根因已在 zlib submodule 內修正（commit 99381d6：僅在呼叫端未設定
# AR 時才採用 Darwin 的 libtool 預設），因此不再需要強制靜態。
# 且此覆寫依「建置主機」判斷，從 macOS 交叉編譯時會完全不產生 libz.so.1，
# 導致 guest 內 Swift toolchain 的 clang 無法啟動。

define LIBZLIB_CONFIGURE_CMDS
	(cd $(@D); rm -rf config.cache; \
		$(TARGET_CONFIGURE_ARGS) \
		$(TARGET_CONFIGURE_OPTS) \
		AR="$(TARGET_AR)" \
		RANLIB="$(TARGET_RANLIB)" \
		CFLAGS="$(TARGET_CFLAGS) $(LIBZLIB_PIC)" \
		./configure \
		$(LIBZLIB_SHARED) \
		--prefix=/usr \
	)
endef

define HOST_LIBZLIB_CONFIGURE_CMDS
	(cd $(@D); rm -rf config.cache; \
		$(HOST_CONFIGURE_ARGS) \
		$(HOST_CONFIGURE_OPTS) \
		./configure \
		--prefix="$(HOST_DIR)" \
		--sysconfdir="$(HOST_DIR)/etc" \
	)
endef

define LIBZLIB_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D)
endef

define HOST_LIBZLIB_BUILD_CMDS
	$(HOST_MAKE_ENV) $(MAKE1) -C $(@D)
endef

define LIBZLIB_INSTALL_STAGING_CMDS
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D) DESTDIR=$(STAGING_DIR) LDCONFIG=true install
endef

define LIBZLIB_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D) DESTDIR=$(TARGET_DIR) LDCONFIG=true install
endef

# We don't care removing the .a from target, since it not used at link
# time to build other packages, and it is anyway removed later before
# assembling the filesystem images anyway.
ifeq ($(BR2_SHARED_LIBS),y)
ifneq ($(shell uname -s),Darwin)
define LIBZLIB_RM_STATIC_STAGING
	rm -f $(STAGING_DIR)/usr/lib/libz.a
endef
LIBZLIB_POST_INSTALL_STAGING_HOOKS += LIBZLIB_RM_STATIC_STAGING
endif
endif

define HOST_LIBZLIB_INSTALL_CMDS
	$(HOST_MAKE_ENV) $(MAKE1) -C $(@D) LDCONFIG=true install
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
