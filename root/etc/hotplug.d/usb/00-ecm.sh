#!/bin/sh

[ "$ACTION" = "add" ] && [ "$DEVTYPE" = "usb_device" ] || exit 0

. /lib/me909s.sh
. /lib/functions.sh
. /lib/netifd/netifd-proto.sh

vid=$(cat /sys$DEVPATH/idVendor)
pid=$(cat /sys$DEVPATH/idProduct)
usb="/lib/network/wwan/$vid:$pid"
[ -f $usb ] || exit 0
__FIND_ECM_IFACE=0
iface=''
for device in /sys/bus/usb/devices/*; do
    [ -d "$device/net" ] && iface=$(ls "$device/net")
    if [ -f "$device/idVendor" ] && [ -f "$device/idProduct" ]; then
        vendor=$(cat "$device/idVendor")
        product=$(cat "$device/idProduct")
        conf="/lib/network/wwan/${vendor}:${product}"
        [ -f "$conf" ] && { usb="$conf"; devicename="$device"; break; }
    fi
done

modem_init() {
    local interface=$1
    local old_cb control data
    json_set_namespace ecm old_cb
    json_init
    json_load "$(cat $usb)"
    json_select
    json_get_vars desc type control atcom
    json_set_namespace $old_cb
    
    ctl_device=/dev/ttyUSB$control
    dat_device=/dev/ttyUSB$atcom
    
    timeout=0
    while [ ! -e "$ctl_device" ] ;do
        sleep 1
        timeout=$((timeout+1))
        if [ $timeout -gt 10 ];then
            logger "wait for the modem at com ready timeout, exit!"
            exit 1
        fi
    done
    modem_hw_info "$ctl_device" "$interface"
    
    if [ $? -eq 0 ];then
        uci_toggle_state network "$interface" driver "ndis"
        uci_toggle_state network "$interface" device "eth1"
        uci_toggle_state network "$interface" ctl_device "$ctl_device"
        uci_toggle_state network "$interface" dat_device "$dat_device"
    fi
}

find_ndis_iface() {
    local cfg="$1"
    local proto
    config_get proto "$cfg" proto
    [ "$proto" = ndis ] || return 0
    __FIND_NDIS_IFACE=1
    #关闭接口
    proto_set_available "$cfg" 0
    #初始化
    modem_init $cfg
    #打开接口
    proto_set_available "$cfg" 1
    ifup $cfg
    exit 0
}

config_load network
config_foreach find_ndis_iface interface

if [ $__FIND_ECM_IFACE -eq 0 ];then
    uci -q batch <<EOF
delete network.wwan
set network.wwan='interface'
set network.wwan.auto='0'
set network.wwan.pdpnum='2'
set network.wwan.apn='Auto'
set network.wwan.proto='ndis'
set network.wwan.simslot='1'
EOF
    uci commit network
    config_load network
    config_foreach find_ndis_iface interface
fi

