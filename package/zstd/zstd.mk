################################################################################
#
# zstd
#
################################################################################

ZSTD_VERSION = 1.5.7
ZSTD_SITE = https://github.com/facebook/zstd/releases/download/v$(ZSTD_VERSION)
ZSTD_INSTALL_STAGING = YES
ZSTD_LICENSE = BSD-3-Clause or GPL-2.0
ZSTD_LICENSE_FILES = LICENSE COPYING
ZSTD_CPE_ID_VENDOR = facebook
ZSTD_CPE_ID_PRODUCT = zstandard

# The package is a dependency to ccache so ccache cannot be a dependency
HOST_ZSTD_ADD_CCACHE_DEPENDENCY = NO

ZSTD_OPTS += PREFIX=/usr
ZSTD_OPTS += ZSTD_LEGACY_SUPPORT=0
ifeq ($(BR2_PACKAGE_ZLIB),y)
ZSTD_DEPENDENCIES += zlib
ZSTD_OPTS += HAVE_ZLIB=1
else
ZSTD_OPTS += HAVE_ZLIB=0
endif

ifeq ($(BR2_PACKAGE_XZ),y)
ZSTD_DEPENDENCIES += xz
ZSTD_OPTS += HAVE_LZMA=1
else
ZSTD_OPTS += HAVE_LZMA=0
endif

ifeq ($(BR2_PACKAGE_LZ4),y)
ZSTD_DEPENDENCIES += lz4
ZSTD_OPTS += HAVE_LZ4=1
else
ZSTD_OPTS += HAVE_LZ4=0
endif

# zstd will append -O3 after $(CFLAGS), use MOREFLAGS to override again
ZSTD_OPTS += MOREFLAGS="$(TARGET_OPTIMIZATION)"

ZSTD_BUILD_LIBS_BASENAMES = libzstd.pc
ifeq ($(BR2_STATIC_LIBS),y)
ZSTD_BUILD_LIBS_BASENAMES += libzstd.a
ZSTD_INSTALL_LIBS = install-static
else ifeq ($(BR2_SHARED_LIBS),y)
ZSTD_BUILD_LIBS_BASENAMES += lib
ZSTD_INSTALL_LIBS = install-shared
else
ZSTD_BUILD_LIBS_BASENAMES += lib
ZSTD_INSTALL_LIBS = install-static install-shared
endif

# prefer zstd-dll unless no library is available
ifeq ($(BR2_STATIC_LIBS),y)
ZSTD_BUILD_PROG_TARGET = zstd-release
else
ZSTD_BUILD_PROG_TARGET = zstd-dll
endif

# The HAVE_THREAD flag is read by the 'programs' makefile but not by  the 'lib'
# one. Building a multi-threaded binary with a static library (which defaults
# to single-threaded) gives a runtime error when compressing files.
# The 'lib' makefile provides specific '%-mt' and '%-nomt' targets for this
# purpose.
ifeq ($(BR2_TOOLCHAIN_HAS_THREADS),y)
ZSTD_OPTS += HAVE_THREAD=1
ZSTD_BUILD_LIBS_THREAD_SUFFIX = -mt
else
ZSTD_OPTS += HAVE_THREAD=0
ZSTD_BUILD_LIBS_THREAD_SUFFIX = -nomt
endif

# zstd's lib/Makefile picks the shared-library flavour from
# UNAME_TARGET_SYSTEM, which defaults to $(UNAME) -- the BUILD machine. Cross
# compiling from macOS it therefore decides the target is Darwin, builds
# libzstd.1.5.7.dylib, and passes macOS linker flags to the Linux cross gcc:
#
#   aarch64-buildroot-linux-gnu-gcc: error: unrecognized command-line option
#   '-install_name'
#
# Upstream declares UNAME_TARGET_SYSTEM with ?= specifically as the
# cross-compilation override hook, so setting it is the intended fix rather
# than a workaround. Target-side only: HOST_ZSTD_OPTS is separate and the host
# build genuinely does target the host OS.
#
# zstd 的 lib/Makefile 依 UNAME_TARGET_SYSTEM 決定共享庫形式，其預設值是
# $(UNAME)，也就是「建置主機」。在 macOS 上交叉編譯到 Linux 時會誤判目標為
# Darwin，產生 libzstd.1.5.7.dylib 並把 macOS 連結旗標傳給 Linux 交叉 gcc。
# 上游以 ?= 宣告 UNAME_TARGET_SYSTEM，本就是預留給交叉編譯的覆寫掛鉤，
# 因此設定它是上游預期的正解而非權宜之計。僅影響 target 端：HOST_ZSTD_OPTS
# 是獨立的，host 版本來就該以 host OS 為目標。
ZSTD_OPTS += UNAME_TARGET_SYSTEM=Linux

ZSTD_BUILD_LIBS = \
	$(addsuffix -release, \
		$(addsuffix $(ZSTD_BUILD_LIBS_THREAD_SUFFIX), \
			$(ZSTD_BUILD_LIBS_BASENAMES)))

define ZSTD_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) $(ZSTD_OPTS) \
		-C $(@D)/lib $(ZSTD_BUILD_LIBS)
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) $(ZSTD_OPTS) \
		-C $(@D)/programs $(ZSTD_BUILD_PROG_TARGET)
endef

define ZSTD_INSTALL_STAGING_CMDS
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) $(ZSTD_OPTS) \
		DESTDIR=$(STAGING_DIR) PREFIX=/usr -C $(@D)/lib \
		install-pc install-includes $(ZSTD_INSTALL_LIBS)
endef

define ZSTD_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) $(ZSTD_OPTS) \
		DESTDIR=$(TARGET_DIR) -C $(@D)/programs install
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) $(ZSTD_OPTS) \
		DESTDIR=$(TARGET_DIR) -C $(@D)/lib $(ZSTD_INSTALL_LIBS)
endef

HOST_ZSTD_OPTS += PREFIX=$(HOST_DIR)

# Disable the optional pass-through codecs in the host zstd CLI.
#
# ZSTD_OPTS above pins HAVE_ZLIB/HAVE_LZMA/HAVE_LZ4 for the target, but
# HOST_ZSTD_OPTS set only PREFIX, so the host build fell through to zstd's own
# autodetection. On macOS that finds <lzma.h> from the SDK, defines HAVE_LZMA,
# and then links without -llzma, so the CLI fails at CCLD with undefined
# _lzma_easy_buffer_encode, _lzma_stream_decoder and friends.
#
# Turning them off rather than adding link flags is the right call: buildroot
# uses the host zstd purely to compress its own artifacts, and the gzip/xz/lz4
# pass-through modes of the zstd CLI are never exercised.
#
# 關閉 host 版 zstd CLI 的選用轉接 codec。上方的 ZSTD_OPTS 已為 target 固定
# HAVE_ZLIB/HAVE_LZMA/HAVE_LZ4，但 HOST_ZSTD_OPTS 僅設了 PREFIX，host 端因而
# 落回 zstd 自身的偵測：在 macOS 上會找到 SDK 的 <lzma.h> 而定義 HAVE_LZMA，
# 卻未帶 -llzma，於是 CLI 在 CCLD 階段因 _lzma_* 未定義而失敗。
# 選擇關閉而非補上連結旗標才正確：buildroot 使用 host zstd 只為壓縮自身產物，
# 從未用到 zstd CLI 的 gzip/xz/lz4 轉接模式。
HOST_ZSTD_OPTS += HAVE_ZLIB=0 HAVE_LZMA=0 HAVE_LZ4=0
HOST_ZSTD_ENV = $(HOST_MAKE_ENV) $(HOST_CONFIGURE_OPTS)

# We are a ccache dependency, so we can't use ccache
HOST_ZSTD_ENV += CC="$(HOSTCC_NOCCACHE)" CXX="$(HOSTCXX_NOCCACHE)"

define HOST_ZSTD_BUILD_CMDS
	$(HOST_ZSTD_ENV) $(MAKE) $(HOST_ZSTD_OPTS) \
		-C $(@D) zstd-release lib-release
endef

define HOST_ZSTD_INSTALL_CMDS
	$(HOST_ZSTD_ENV) $(MAKE) $(HOST_ZSTD_OPTS) \
		-C $(@D) install
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
