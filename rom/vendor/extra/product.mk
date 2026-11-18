#
# SPDX-License-Identifier: Apache-2.0
#
# "G73 Open" flavor for LineageOS on the moto g73 5G (devonf).
#
# LineageOS includes vendor/extra/product.mk before its own configuration
# (vendor/lineage/config/common.mk), so everything here is applied on top of
# a stock LineageOS build without forking any LineageOS or device repository.
#

G73OPEN_VERSION := 1.0

# Version string: lineage-24.0-<date>-UNOFFICIAL-g73open-devonf
TARGET_UNOFFICIAL_BUILD_ID := g73open

PRODUCT_SYSTEM_EXT_PROPERTIES += \
    ro.g73open.version=$(G73OPEN_VERSION)

# Privacy-friendly defaults (see overlay/G73OpenFrameworksOverlay)
PRODUCT_PACKAGES += \
    G73OpenFrameworksOverlay
