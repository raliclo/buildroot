################################################################################
#
# mkpasswd
#
################################################################################

# source included in buildroot, taken from
# https://github.com/rfc1036/whois/blob/master/
# at revision 5a0f08500fa51608b6d3b73ee338be38c692eadb
HOST_MKPASSWD_LICENSE = GPL-2.0+

HOST_MKPASSWD_DEPENDENCIES = host-libxcrypt

define HOST_MKPASSWD_EXTRACT_CMDS
	cp $(HOST_MKPASSWD_PKGDIR)/*.c $(HOST_MKPASSWD_PKGDIR)/*.h $(@D)
endef

# -DHAVE_SHA_CRYPT: the SHA-crypt methods are gated in config.h on
# `#if defined __GLIBC__`, i.e. on the platform rather than on the crypt
# library actually being linked. host-libxcrypt is a hard dependency of this
# package precisely so SHA-crypt is available, so on a non-glibc host the
# gate excludes the very capability the dependency was added to provide:
# mkpasswd builds and runs, but offers only des and md5, and
# `mkpasswd -m sha-256` fails with "Invalid method".
#
# That surfaces far from its cause. BR2_TARGET_GENERIC_PASSWD_METHOD defaults
# to sha-256, so on macOS the root password silently ends up EMPTY in
# /etc/shadow -- the build succeeds, the image boots, and the account has no
# password at all.
#
# 加上 -DHAVE_SHA_CRYPT：config.h 以 `#if defined __GLIBC__` 為條件開啟
# SHA-crypt，也就是依「平台」而非依「實際連結的 crypt 函式庫」判斷。而
# host-libxcrypt 正是本套件的硬相依，目的就是提供 SHA-crypt；因此在非 glibc
# 主機上，該條件恰好排除了加入此相依所要提供的能力：mkpasswd 建得起來也跑得動，
# 卻只提供 des 與 md5，`mkpasswd -m sha-256` 會以 "Invalid method" 失敗。
# 其後果離成因很遠：BR2_TARGET_GENERIC_PASSWD_METHOD 預設為 sha-256，於是在
# macOS 上 root 密碼會靜默地變成 /etc/shadow 中的「空值」——建置成功、image
# 開得起來，而該帳號根本沒有密碼。
define HOST_MKPASSWD_BUILD_CMDS
	$(HOSTCC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -DHAVE_SHA_CRYPT \
		$(@D)/mkpasswd.c $(@D)/utils.c \
		-o $(@D)/mkpasswd -lcrypt
endef

define HOST_MKPASSWD_INSTALL_CMDS
	$(INSTALL) -D -m 755 $(@D)/mkpasswd $(HOST_DIR)/bin/mkpasswd
endef

$(eval $(host-generic-package))

MKPASSWD = $(HOST_DIR)/bin/mkpasswd
