#!/bin/sh

[ "$ACTION" = "add" ] && [ "$DEVTYPE" = "usb_device" ] || exit 0

. /lib/functions.sh
. /lib/netifd/netifd-proto.sh

vid=$(cat /sys$DEVPATH/idVendor)
pid=$(cat /sys$DEVPATH/idProduct)
usb="/lib/network/wwan/$vid:$pid"
[ -f $usb ] || exit 0

find_wwan_iface() {
    local cfg="$1"
    local proto
    config_get proto "$cfg" proto
    [ "$proto" = wwan ] || return 0
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
config_foreach find_wwan_iface interface

modem_init(){
    interface=$1
    local old_cb control data
    json_set_namespace wwan old_cb
    json_init
    json_load "$(cat $usb)"
    json_select
    json_get_vars desc type control atcom
    
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
    
    __at_rsp=$(/usr/bin/sendat "$ctl_device" "ATI")
    
    # 检查响应是否为空或不包含 "OK"
    [ -z "$__at_rsp" ] && exit 1
    [ -n "${__at_rsp##*OK*}" ] && exit 1
    
    manufacturer=$(echo "$__at_rsp" | awk -F': ' '/^Manufacturer: / {print $2}')
    model=$(echo "$__at_rsp" | awk -F': ' '/^Model: / {print $2}')
    revision=$(echo "$__at_rsp" | awk -F': ' '/^Revision: / {print $2}')
    imei=$(echo "$__at_rsp" | awk -F': ' '/^IMEI: / {print $2}')

    uci_toggle_state network "$interface" manufacturer "$manufacturer"
    uci_toggle_state network "$interface" model "$model"
    uci_toggle_state network "$interface" revision "$revision"
    uci_toggle_state network "$interface" imei "$imei"
    uci_toggle_state network "$interface" driver "rndis_host"
    uci_toggle_state network "$interface" device "eth1"
    uci_toggle_state network "$interface" ctl_device "$ctl_device"
    uci_toggle_state network "$interface" dat_device "$dat_device"
}
