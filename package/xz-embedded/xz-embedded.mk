################################################################################
#
# xz-embedded
#
################################################################################

XZ_EMBEDDED_VERSION = 20130513
XZ_EMBEDDED_SOURCE = xz-embedded-$(XZ_EMBEDDED_VERSION).tar.gz
XZ_EMBEDDED_SITE = http://tukaani.org/xz
XZ_EMBEDDED_INSTALL_STAGING = YES
XZ_EMBEDDED_LICENSE = Public Domain
XZ_EMBEDDED_LICENSE_FILES = COPYING

$(eval $(cmake-package))
