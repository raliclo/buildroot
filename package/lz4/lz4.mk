################################################################################
#
# lz4
#
################################################################################

LZ4_VERSION = 1.10.0
LZ4_SITE = $(call github,lz4,lz4,v$(LZ4_VERSION))
LZ4_INSTALL_STAGING = YES
LZ4_LICENSE = BSD-2-Clause (library), GPL-2.0+ (programs)
LZ4_LICENSE_FILES = lib/LICENSE programs/COPYING
LZ4_CPE_ID_VALID = YES

ifeq ($(BR2_STATIC_LIBS),y)
LZ4_MAKE_OPTS += BUILD_SHARED=no
else ifeq ($(BR2_SHARED_LIBS),y)
LZ4_MAKE_OPTS += BUILD_STATIC=no
endif

# lz4's Makefile.inc does "TARGET_OS ?= $(shell $(UNAME))", i.e. it keys off the
# BUILD machine rather than the cross-compilation target. On a macOS host that
# yields TARGET_OS=Darwin, so the target build tries to produce a Mach-O
# liblz4.*.dylib and hands -install_name / -compatibility_version /
# -current_version to the Linux cross gcc, which rejects them:
#
#   aarch64-buildroot-linux-gnu-gcc: error: unrecognized command-line option
#   '-install_name'
#
# The buildroot target is always Linux, so pin TARGET_OS. Upstream declares it
# with ?=, so passing it on the make command line overrides cleanly and no
# source patch is needed. HOST_LZ4_* deliberately does not use LZ4_MAKE_OPTS --
# the host build really is for the host OS and must keep the uname detection.
#
# lz4 的 Makefile.inc 使用 "TARGET_OS ?= $(shell $(UNAME))"，依「建置主機」而非
# 交叉編譯目標判斷。在 macOS host 上會得到 TARGET_OS=Darwin，於是 target 建置
# 會嘗試產生 Mach-O 的 liblz4.*.dylib，並把 -install_name 等 macOS 連結器旗標
# 傳給 Linux 交叉 gcc 而失敗。buildroot 的 target 一律是 Linux，故固定 TARGET_OS；
# 上游是 ?= 預設值，用 make 命令列覆寫即可，無需修改原始碼。
# HOST_LZ4_* 刻意不使用 LZ4_MAKE_OPTS——host 版本來就該沿用 host OS 的偵測。
LZ4_MAKE_OPTS += TARGET_OS=Linux

define HOST_LZ4_BUILD_CMDS
	$(HOST_MAKE_ENV) $(HOST_CONFIGURE_OPTS) $(MAKE) -C $(@D) lib
	$(HOST_MAKE_ENV) $(HOST_CONFIGURE_OPTS) $(MAKE) -C $(@D) lz4
endef

define HOST_LZ4_INSTALL_CMDS
	$(HOST_MAKE_ENV) $(HOST_CONFIGURE_OPTS) $(MAKE) PREFIX=$(HOST_DIR) \
		install -C $(@D)
endef

LZ4_DIRS = lib

ifeq ($(BR2_PACKAGE_LZ4_PROGS),y)
LZ4_DIRS += programs
endif

define LZ4_BUILD_CMDS
	$(foreach dir,$(LZ4_DIRS),\
		$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) $(LZ4_MAKE_OPTS) \
			-C $(@D)/$(dir)
	)
endef

define LZ4_INSTALL_STAGING_CMDS
	$(foreach dir,$(LZ4_DIRS),\
		$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) DESTDIR=$(STAGING_DIR) \
			PREFIX=/usr $(LZ4_MAKE_OPTS) -C $(@D)/$(dir) install
	)
endef

define LZ4_INSTALL_TARGET_CMDS
	$(foreach dir,$(LZ4_DIRS),\
		$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) DESTDIR=$(TARGET_DIR) \
			PREFIX=/usr $(LZ4_MAKE_OPTS) -C $(@D)/$(dir) install
	)
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
