#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/motorola/devonf

# Virtual A/B (compressed), same as stock
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression.mk)
ENABLE_VIRTUAL_AB := true

# Dynamic partitions + fastbootd inside recovery
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

# Shipping API level (the device launched with Android 13)
PRODUCT_SHIPPING_API_LEVEL := 33

# Copied into the recovery ramdisk by TWRP's twrp_ramdisk step, but only
# pulled in automatically when crypto is enabled (it is not, see BoardConfig).
PRODUCT_PACKAGES += \
    mke2fs.conf \
    plat_keystore2_key_contexts \
    task_profiles.json

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# NOTE: MediaTek uses its own boot-control HAL (slot metadata handled by the
# MTK bootloader). It is proprietary and not included here, so slot switching
# from inside this recovery is not supported; use `fastboot set_active a|b`.
