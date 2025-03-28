#!/bin/sh

. /lib/functions.sh
. ../netifd-proto.sh
init_proto "$@"

INCLUDE_ONLY=1

ctl_device=""
dat_device=""

proto_mbim_setup() { echo "wwan[$$] mbim proto is missing"; }
proto_qmi_setup() { echo "wwan[$$] qmi proto is missing"; }
proto_ncm_setup() { echo "wwan[$$] ncm proto is missing"; }
proto_3g_setup() { echo "wwan[$$] 3g proto is missing"; }
proto_directip_setup() { echo "wwan[$$] directip proto is missing"; }

[ -f ./mbim.sh ] && . ./mbim.sh
[ -f ./ncm.sh ] && . ./ncm.sh
[ -f ./qmi.sh ] && . ./qmi.sh
[ -f ./3g.sh ] && { . ./ppp.sh; . ./3g.sh; }
[ -f ./directip.sh ] && . ./directip.sh

proto_wwan_init_config() {
    available=1
    no_device=1
    
    proto_config_add_string apn
    proto_config_add_string auth
    proto_config_add_string username
    proto_config_add_string password
    proto_config_add_string pincode
    proto_config_add_string pdpnum
    proto_config_add_string pdptype
    proto_config_add_string delay
    proto_config_add_string mode
    proto_config_add_string simslot
}

proto_wwan_setup() {
    local interface=$1
    local simnum model driver device manufacturer
    
    simnum="$(uci -q get network.$interface.simslot)"
    model=$(uci_get_state network $interface model)
    driver=$(uci_get_state network $interface driver)
    device=$(uci_get_state network $interface device)
    ctl_device=$(uci_get_state network $interface ctl_device)
    dat_device=$(uci_get_state network $interface dat_device)
    manufacturer=$(uci_get_state network $interface manufacturer)
    
    [ -n "$model" ] && [ -n "$ctl_device" ] || {
        echo "No control device specified"
        proto_notify_error "$interface" NO_DEVICE
        proto_set_available "$interface" 0
        return 1
    }

    json_get_var apn apn
    json_get_var auth auth
    json_get_var pdpnum pdpnum
    json_get_var pincode pincode
    json_get_var mode mode
    json_get_var pdptype pdptype
    json_get_var username username
    json_get_var password password
}


proto_wwan_teardown() {
    local interface=$1
    local driver=$(uci_get_state network $interface driver)
    ctl_device=$(uci_get_state network $interface ctl_device)
    dat_device=$(uci_get_state network $interface dat_device)
    
    case $driver in
        qmi_wwan)		proto_qmi_teardown $@ ;;
        cdc_mbim)		proto_mbim_teardown $@ ;;
        sierra_net)		proto_directip_teardown $@ ;;
        comgt)			proto_3g_teardown $@ ;;
        cdc_ether|*cdc_ncm)	proto_ncm_teardown $@ ;;
    esac
}

add_protocol wwan
