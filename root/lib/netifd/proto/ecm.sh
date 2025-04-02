#!/bin/sh
. /lib/me909s.sh

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

# proto_mbim_setup() { echo "wwan[$$] mbim proto is missing"; }
# proto_qmi_setup() { echo "wwan[$$] qmi proto is missing"; }
# proto_ncm_setup() { echo "wwan[$$] ncm proto is missing"; }
# proto_3g_setup() { echo "wwan[$$] 3g proto is missing"; }
# proto_directip_setup() { echo "wwan[$$] directip proto is missing"; }

# [ -f ./mbim.sh ] && . ./mbim.sh
# [ -f ./ncm.sh ] && . ./ncm.sh
# [ -f ./qmi.sh ] && . ./qmi.sh
# [ -f ./3g.sh ] && { . ./ppp.sh; . ./3g.sh; }
# [ -f ./directip.sh ] && . ./directip.sh

proto_ndis_init_config() {
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

interface_dhcp_setup() {
    echo "Starting DHCP"
    proto_init_update "$1" 1
    proto_send_update "$2"
    json_set_namespace dhcp_setup old_cb
    json_init
    json_add_string name "${2}_4"
    json_add_string ifname "@$2"
    json_add_string proto "dhcp"
    json_close_object
    ubus call network add_dynamic "$(json_dump)"
    json_set_namespace $old_cb
    
    return 0
}

proto_ecm_setup() {
    local interface=$1
    local simnum model driver device ctl_device dat_device manufacturer
    local apn auth pdpnum pincode mode pdptype username password
    local __output __res
    
    simnum="$(uci -q get network.$interface.simslot)"
    model=$(uci_get_state network "$interface" model)
    driver=$(uci_get_state network "$interface" driver)
    device=$(uci_get_state network "$interface" device)
    ctl_device=$(uci_get_state network "$interface" ctl_device)
    dat_device=$(uci_get_state network "$interface" dat_device)
    manufacturer=$(uci_get_state network "$interface" manufacturer)
    
    [ -n "$model" ] && [ -n "$ctl_device" ] || {
        echo "No control device specified"
        proto_notify_error "$interface" "NO_DEVICE"
        proto_set_available "$interface" 0
        return 1
    }
    
    json_get_vars apn auth pdpnum pincode mode pdptype username password
    
    [ -n "$pdpnum" ] || pdpnum=2
    
    local timeout=0
    while true;do
        lock_modem_at $$ "me909s"
        if [  $? -eq 0 ];then
            break
        else
            if [ $timeout -gt 5 ];then
                proto_notify_error "$interface" "LOCK_AT_ERROR"
            fi
            timeout=$((timeout+1))
            sleep 1
            continue
        fi
    done
    
    __sim="$(uci_get_state network "$interface" sim)"
    if [ "$__sim" = "SIM PIN" ]; then
        if [[ ${#pincode} -eq 4 && -z "${pincode//[0-9]/}" ]]; then
            __output=$(send_at "$ctl_device" "AT+CPIN=${pincode}")
            if [ $? -ne 0 ] && [ -z "$__output" ]; then
                proto_notify_error "$interface" "PINCODE_ERROR"
                return 1
            fi
        fi
        elif [ "$__sim" = "SIM PUK" ]; then
        proto_notify_error "$interface" "SIM_PUK"
        return 1
        elif [ "$__sim" = "ERROR" ]; then
        proto_notify_error "$interface" "SIM_ERROR"
        return 1
    fi
    
    local timeout=0
    local operator=""
    while [[ -z "$operator" || -n "${operator//[0-9]/}" ]];do
        __output=$(send_at "$ctl_device" "AT+COPS?")
        if [ $? -eq 0  ];then
            __res=$(echo "$__output" | awk -F': ' '/\+COPS: / {print $2}')
            operator=$(echo "$__res" |cut -d',' -f3 | tr -d '"')
            if [ ${#operator} -eq 5 ];then
                uci_toggle_state network $interface "operator" "$operator"
            fi
        fi
        
        if [ $timeout -gt 5 ];then
            proto_notify_error "$interface" "COPS_TIMEOUT"
            return 1
        fi
        sleep 1
        timeout=$((timeout+1))
    done
    
    if [ -n "${pdptype}" ];then
        __output=$(send_at "$ctl_device" "AT+CGDCONT?")
        if [ $? -eq 0 ];then
            local __pdpval
            __res=$(echo "$__output" | awk -F': ' -v pdp="$pdpnum" '$0 ~ "\\+CGDCONT: " pdp {print $2}')
            __pdpval=$(echo "$__res" |cut -d',' -f2 | tr -d '"')
            if [ "${__pdpval}"X != "${pdptype}"X ];then
                send_at "$ctl_device" "AT+CGDCONT=${pdpnum},\"${pdptype}\""
                [ $? -eq 0 ] || {
                    proto_notify_error "$interface" "SET_PDPTYPE_ERROR"
                    return 1
                }
            fi
        fi
    fi
    
    timeout=0
    while true;do
        __output=$(send_at "$ctl_device" "AT+CGREG?")
        if [ $? -eq 0 ];then
            __res=$(echo "$__output" | awk -F': ' '/\+CGREG: / {print $2}')
            local __stat
            __stat=$(echo "$__res" |cut -d',' -f2)
            [ "$__stat"X = "1"X -o "$__stat"X = "5"X ] && break
        fi
        
        if [ $timeout -gt 120 ];then
            proto_notify_error "$interface" "NET_REG_TIMEOUT"
            return 1
        fi
        sleep 1
        timeout=$((timeout+1))
    done
    # [ -n "$pdptype" ] || pdptype="IPV4V6"
    local apn_val=""
    if [ -n "$apn" ];then
        [ "$apn" = "Auto" ] || apn_val="$apn"
    fi
    
    if [ -n "${apn_val}" ];then
        case "$auth" in
            "pap") auth=1 ;;
            "chap") auth=2 ;;
            *) auth=0 ;;
        esac
        if [ ${#username} -gt 0 -a ${#password} -gt 0 ];then
            __cmd="AT^NDISDUP=${pdpnum},1,\"${apn_val}\",\"${username}\",\"${password}\",$auth"
        else
            __cmd="AT^NDISDUP=${pdpnum},1,\"${apn_val}\""
        fi
    else
        __cmd="AT^NDISDUP=${pdpnum},1"
    fi
    # __output=$(send_at "$ctl_device" "$__cmd")
    send_at "$ctl_device" "$__cmd"
    [ $? -eq 0 ] || {
        proto_notify_error "$interface" "NDISDUP_ERROR"
        return 1
    }
    # [ $? -eq 0 -a -n "$__output" ] && uci_toggle_state network "$interface" "apn_val_${__sim_num}" "${apn_val}"
    
    # wait for getting ip address, tiemout 60s
    timeout=0
    while true;do
        __output=$(send_at "$ctl_device" "AT^NDISSTATQRY?")
        if [ $? -eq 0 ];then
            __res=$(echo "$__output" | awk -F': ' '/\^NDISSTATQRY: / {print $2}')
            __stat=$(echo "$__res" |cut -d',' -f1)
            [ "${__stat}"X = "1"X ] && return 0
        fi
        [ $timeout -gt 60 ] && {
            proto_notify_error "$interface" "GET_ADDR_TIMEOUT"
            return 1
        }
        sleep 1
        timeout=$((timeout+1))
    done
    interface_dhcp_setup "$device" "$interface"
    unlock_modem_at "me909s"
    /lib/me909s.sh cellular "$ctl_device" "$interface" &
}


proto_ecm_teardown() {
    local interface=$1
    local ctl_device
    ctl_device=$(uci_get_state network "$interface" ctl_device)
    
    json_get_var pdpnum pdpnum
    [ -n "$pdpnum" ] || pdpnum=2
    
    [ -n "$ctl_device" ] &&  send_at "$ctl_device" "AT\^NDISDUP=${pdpnum},0"
    
    proto_init_update "*" 0
    proto_send_update "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
    add_protocol ecm
}