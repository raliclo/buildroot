################################################################################
#
# fakeroot
#
################################################################################

FAKEROOT_VERSION = 1.37.2
FAKEROOT_SOURCE = fakeroot_$(FAKEROOT_VERSION).orig.tar.gz
FAKEROOT_SITE = https://snapshot.debian.org/archive/debian/20260401T000000Z/pool/main/f/fakeroot

HOST_FAKEROOT_DEPENDENCIES = host-acl
# Force capabilities detection off
# For now these are process capabilities (faked) rather than file
# so they're of no real use
HOST_FAKEROOT_CONF_ENV = \
	ac_cv_header_sys_capability_h=no \
	ac_cv_func_capset=no

# macOS does not provide the Linux ACL/xattr API required by host-attr.
# macOS 沒有 host-attr 所需的 Linux ACL/xattr API。
ifeq ($(shell uname -s),Darwin)
HOST_FAKEROOT_DEPENDENCIES =
HOST_FAKEROOT_CONF_ENV += \
	ac_cv_header_sys_acl_h=no \
	ac_cv_header_acl_libacl_h=no \
	ac_cv_type_acl_t=no \
	ac_cv_func_acl_get_fd=no \
	ac_cv_func_acl_trivial=no \
	ac_cv_func_lgetxattr=no \
	ac_cv_func_lsetxattr=no \
	ac_cv_func_llistxattr=no \
	ac_cv_func_lremovexattr=no
endif
FAKEROOT_LICENSE = GPL-3.0+
FAKEROOT_LICENSE_FILES = COPYING

$(eval $(host-autotools-package))
