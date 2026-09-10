################################################################################
#
# git
#
################################################################################

GIT_VERSION = 2.54.0
GIT_SOURCE = git-$(GIT_VERSION).tar.xz
GIT_SITE = $(BR2_KERNEL_MIRROR)/software/scm/git
GIT_LICENSE = GPL-2.0, LGPL-2.1+
GIT_LICENSE_FILES = COPYING LGPL-2.1
GIT_CPE_ID_VENDOR = git-scm
GIT_SELINUX_MODULES = apache git xdg
GIT_DEPENDENCIES = zlib $(TARGET_NLS_DEPENDENCIES)

ifeq ($(BR2_PACKAGE_OPENSSL),y)
GIT_DEPENDENCIES += host-pkgconf openssl
GIT_CONF_OPTS += --with-openssl
GIT_MAKE_OPTS += LIB_4_CRYPTO="`$(PKG_CONFIG_HOST_BINARY) --libs libssl libcrypto`"
else
GIT_CONF_OPTS += --without-openssl
endif

ifeq ($(BR2_PACKAGE_PCRE2),y)
GIT_DEPENDENCIES += pcre2
GIT_CONF_OPTS += --with-libpcre2
else
GIT_CONF_OPTS += --without-libpcre2
endif

ifeq ($(BR2_PACKAGE_LIBCURL),y)
GIT_DEPENDENCIES += libcurl
GIT_CONF_OPTS += --with-curl
GIT_CONF_ENV += \
	ac_cv_prog_CURL_CONFIG=$(STAGING_DIR)/usr/bin/$(LIBCURL_CONFIG_SCRIPTS)
else
GIT_CONF_OPTS += --without-curl
endif

ifeq ($(BR2_PACKAGE_EXPAT),y)
GIT_DEPENDENCIES += expat
GIT_CONF_OPTS += --with-expat
else
GIT_CONF_OPTS += --without-expat
endif

ifeq ($(BR2_PACKAGE_LIBICONV),y)
GIT_DEPENDENCIES += libiconv
GIT_CONF_ENV_LIBS += -liconv
GIT_CONF_OPTS += --with-iconv=$(STAGING_DIR)/usr
GIT_CONF_ENV += ac_cv_iconv_omits_bom=no
else
GIT_CONF_OPTS += --without-iconv
endif

ifeq ($(BR2_PACKAGE_TCL),y)
GIT_DEPENDENCIES += tcl
GIT_CONF_OPTS += --with-tcltk
else
GIT_CONF_OPTS += --without-tcltk
endif

ifeq ($(BR2_SYSTEM_ENABLE_NLS),)
GIT_MAKE_OPTS += NO_GETTEXT=1
endif

# Regenerate configure from configure.ac.
#
# The release tarball ships a pre-generated ./configure; a git checkout does
# not, and this tree is built from one (GIT_OVERRIDE_SRCDIR points at the
# dependencies/git submodule). Without this the configure step dies with
# "./configure: No such file or directory" -- exit 127, which reads as a
# missing tool rather than a missing generated file.
#
# 由 configure.ac 重新產生 configure。release tarball 內含預先產生的 ./configure，
# git checkout 則沒有，而本樹是由 checkout 建置的（GIT_OVERRIDE_SRCDIR 指向
# dependencies/git submodule）。缺少此設定時，configure 階段會以
# 「./configure: No such file or directory」失敗，回傳 127——看起來像缺少工具，
# 實際上是缺少產生出來的檔案。
GIT_AUTORECONF = YES

# Build the C git only.
#
# Recent git carries a Rust component (Cargo.toml, build.rs, src/) linked in as
# target/release/libgitcore.a. Cargo builds it for the HOST unless RUST_TARGETS
# names the cross target, so the aarch64 link fails with
#
#   libgitcore.a: error adding symbols: archive has no index; run ranlib
#
# which reads like a corrupt archive rather than an archive for the wrong
# machine. Making it work would mean adding a Rust cross toolchain for
# aarch64-unknown-linux-gnu to the host side; NO_RUST drops the optional
# subsystems instead, and the C build is complete without them.
#
# 只建置 C 版本的 git。近期的 git 帶有 Rust 元件，會以 target/release/libgitcore.a
# 連入；除非以 RUST_TARGETS 指定交叉目標，否則 cargo 會為 host 建置它，aarch64
# 連結因而失敗，訊息看起來像「壞掉的封存」而非「屬於錯誤機器的封存」。要讓它可用
# 需在 host 端加入 aarch64-unknown-linux-gnu 的 Rust 交叉工具鏈；此處改以 NO_RUST
# 捨棄那些選用子系統，C 的建置本身即為完整。
GIT_MAKE_OPTS += NO_RUST=1

# Pin the OS git builds FOR, not the OS it is built ON.
#
# git's config.mak.uname starts with
#
#   uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo not')
#
# and its Darwin branch sets USE_ST_TIMESPEC, which makes compat/posix.h use
# BSD's st_mtimespec. Cross-compiling from macOS to a glibc target therefore
# builds target code against a struct stat member glibc does not have, and
# read-cache.c fails with "'struct stat' has no member named 'st_mtimespec'".
# The host's identity has no business selecting the target's libc layout.
#
# Same class as the UNAME_TARGET_SYSTEM pin already carried for zstd.
#
# 釘住 git「為哪個 OS 建置」，而非「在哪個 OS 上建置」。git 的 config.mak.uname
# 以 build host 的 uname -s 起始，其 Darwin 分支會設定 USE_ST_TIMESPEC，使
# compat/posix.h 改用 BSD 的 st_mtimespec；從 macOS 交叉編譯到 glibc target 時，
# 便會以 glibc 不存在的 struct stat 成員來編譯 target 程式碼，read-cache.c 因而
# 以「'struct stat' has no member named 'st_mtimespec'」失敗。host 的身分不該決定
# target 的 libc 佈局。與 zstd 既有的 UNAME_TARGET_SYSTEM 釘選屬同一類。
GIT_MAKE_OPTS += uname_S=Linux

GIT_CFLAGS = $(TARGET_CFLAGS)

ifneq ($(BR2_TOOLCHAIN_HAS_GCC_BUG_85180),)
GIT_CFLAGS += -O0
endif

GIT_CONF_OPTS += CFLAGS="$(GIT_CFLAGS)"

GIT_INSTALL_TARGET_OPTS = $(GIT_MAKE_OPTS) DESTDIR=$(TARGET_DIR) install

# Keep a client that can clone/fetch/pull/push; drop the rest.
#
# git installs ~20 MiB into the target, but almost all of the useful surface is
# ONE 4 MiB binary: /usr/bin/git carries 150 hardlinks, so every builtin --
# fetch, pull, push, clone, ls-files -- costs nothing extra. What follows are
# the separately linked programs, each a full ~2.4 MiB copy of its own.
#
# Removed, with the reason each is unreachable or unwanted here:
#   git-daemon           git:// server
#   git-http-backend     server-side CGI
#   git-imap-send        mails patches
#   git-http-fetch       dumb-HTTP walker. Smart HTTP goes through
#                        git-remote-https, and dumb-HTTP PUSH is already
#                        impossible because git is built --without-expat, so
#                        dropping the fetch half matches what is already true.
#   git-shell            restricted login shell, for serving over ssh
#   git-cvsserver, git-svn, git-p4, git-send-email, git-cvsimport,
#   git-archimport, git-instaweb
#                        all Perl, and there is NO perl in this rootfs, so they
#                        could never have run
#
# Deliberately KEPT:
#   git-remote-http/https  required for https:// remotes. The ftp/ftps names
#                          are hardlinks to the same inode, so removing them
#                          would free nothing.
#   git-sh-i18n--envsubst  looks like i18n-only dead weight under NO_GETTEXT,
#                          but git-sh-i18n's no-gettext FALLBACK branch still
#                          calls it from eval_gettext. Removing it breaks the
#                          shell-based commands in exactly the configuration
#                          this rootfs uses.
#
# 保留能 clone/fetch/pull/push 的用戶端，其餘移除。git 安裝約 20 MiB，但有用的
# 表面幾乎都在單一的 4 MiB 執行檔內：/usr/bin/git 有 150 個 hardlink，所有 builtin
# 都不額外佔空間；真正佔體積的是各自獨立連結、每支約 2.4 MiB 的程式。
# 移除的都是伺服器端、郵件、或需要 perl（本 rootfs 沒有 perl）的工具。
# 刻意保留兩項：git-remote-http/https 是 https 遠端的必要品（ftp/ftps 與其共用
# 同一 inode，移除不會省下任何空間）；git-sh-i18n--envsubst 在 NO_GETTEXT 下看似
# 無用，實際上 git-sh-i18n 的「無 gettext」fallback 分支仍會從 eval_gettext 呼叫
# 它，移除會恰好在本 rootfs 採用的組態下弄壞以 shell 實作的指令。
define GIT_KEEP_CLIENT_ONLY
	rm -f $(TARGET_DIR)/usr/libexec/git-core/git-daemon \
	      $(TARGET_DIR)/usr/libexec/git-core/git-http-backend \
	      $(TARGET_DIR)/usr/libexec/git-core/git-imap-send \
	      $(TARGET_DIR)/usr/libexec/git-core/git-http-fetch \
	      $(TARGET_DIR)/usr/libexec/git-core/git-shell \
	      $(TARGET_DIR)/usr/bin/git-shell \
	      $(TARGET_DIR)/usr/libexec/git-core/git-cvsserver \
	      $(TARGET_DIR)/usr/bin/git-cvsserver \
	      $(TARGET_DIR)/usr/libexec/git-core/git-svn \
	      $(TARGET_DIR)/usr/libexec/git-core/git-p4 \
	      $(TARGET_DIR)/usr/libexec/git-core/git-send-email \
	      $(TARGET_DIR)/usr/libexec/git-core/git-cvsimport \
	      $(TARGET_DIR)/usr/libexec/git-core/git-archimport \
	      $(TARGET_DIR)/usr/libexec/git-core/git-instaweb
endef
GIT_POST_INSTALL_TARGET_HOOKS += GIT_KEEP_CLIENT_ONLY

# assume yes for these tests, configure will bail out otherwise
# saying error: cannot run test program while cross compiling
GIT_CONF_ENV += \
	ac_cv_fread_reads_directories=yes \
	ac_cv_snprintf_returns_bogus=yes LIBS='$(GIT_CONF_ENV_LIBS)'

$(eval $(autotools-package))
