################################################################################
#
# mscc-modular-firmware
#
################################################################################

#MSCC_MODULAR_FIRMWARE_SITE_METHOD=local
#MSCC_MODULAR_FIRMWARE_SITE = /ABSOLUTE/PATH/TO/mscc-modular-firmware-image
MSCC_MODULAR_FIRMWARE_VERSION = bfe7bd6
MSCC_MODULAR_FIRMWARE_SITE_METHOD = git
MSCC_MODULAR_FIRMWARE_SITE = git@git-ent.microsemi.net:sw/modular-firmware-image.git
MSCC_MODULAR_FIRMWARE_DEPENDENCIES = zlib mbedtls
MSCC_MODULAR_FIRMWARE_INSTALL_STAGING = YES

MSCC_MODULAR_FIRMWARE_LICENSE = MIT
MSCC_MODULAR_FIRMWARE_LICENSE_FILES = COPYING
MSCC_MODULAR_FIRMWARE_ACTUAL_SOURCE_SITE = no upstream

define MSCC_MODULAR_FIRMWARE_INSTALL_HOST_TOOLS
	sed -ie 's/version = ".*"/version = "git-$(MSCC_MODULAR_FIRMWARE_VERSION)"/' $(@D)/scripts/mfi.rb
        $(INSTALL) -m 755 $(@D)/scripts/mfi.rb $(HOST_DIR)/usr/bin
endef
MSCC_MODULAR_FIRMWARE_POST_INSTALL_STAGING_HOOKS += MSCC_MODULAR_FIRMWARE_INSTALL_HOST_TOOLS


$(eval $(cmake-package))
