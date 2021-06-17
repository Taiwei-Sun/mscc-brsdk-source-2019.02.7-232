################################################################################
#
# if_mux
#
################################################################################

IF_MUX_VERSION = 8d22107840bf9d954ca8a1d1a89c998c137392e3
IF_MUX_SITE = git@git-ent.microsemi.net:sw/if_mux.git
IF_MUX_ACTUAL_SOURCE_SITE = no upstream
IF_MUX_SITE_METHOD = git
IF_MUX_LICENSE = MIT
IF_MUX_LICENSE_FILES = COPYING

ifeq ($(BR2_PACKAGE_IF_MUX_TYPE_CARACAL),y)
SWITCH_TYPE=CARACAL
else ifeq ($(BR2_PACKAGE_IF_MUX_TYPE_SERVAL1),y)
SWITCH_TYPE=SERVAL1
else ifeq ($(BR2_PACKAGE_IF_MUX_TYPE_OCELOT),y)
SWITCH_TYPE=OCELOT
else ifeq ($(BR2_PACKAGE_IF_MUX_TYPE_JAGUAR2C),y)
SWITCH_TYPE=JAGUAR2
else ifeq ($(BR2_PACKAGE_IF_MUX_TYPE_SERVALT),y)
SWITCH_TYPE=SERVALT
endif

IF_MUX_MODULE_MAKE_OPTS = CONFIG_IF_MUX_TYPE_$(SWITCH_TYPE)=y

$(eval $(kernel-module))
$(eval $(generic-package))
