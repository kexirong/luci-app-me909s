#
# Copyright (C) 2025
#

include $(TOPDIR)/rules.mk
PKG_NAME:=luci-app-me909s
LUCI_BASENAME:=me909s
PKG_VERSION:=1.0.0
LUCI_TITLE:=ME909s - web config for the ME909s modem
LUCI_DEPENDS:=+libpthread +libuci-lua +luci-compat

PKG_LICENSE:=GPLv2
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
