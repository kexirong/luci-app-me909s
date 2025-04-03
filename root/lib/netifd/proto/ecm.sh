#!/bin/sh
. /lib/me909s.sh

[ -n "$INCLUDE_ONLY" ] || {
    . /lib/functions.sh
    . ../netifd-proto.sh
    init_proto "$@"
}


proto_ecm_init_config() {
    no_device=1
    available=1
    proto_config_add_string "device:device"
    # proto_config_add_string simslot
    proto_config_add_string apn
    proto_config_add_string auth
    proto_config_add_string username
    proto_config_add_string password
    proto_config_add_string pincode
    proto_config_add_string delay
    proto_config_add_string pdptype
    proto_config_add_int profile
    proto_config_add_defaults
}


proto_ecm_setup() {
    local interface=$1
    
    local ctl_device dat_device devname devpath ifname operator
    
    local device apn auth username password pincode delay pdptype profile $PROTO_DEFAULT_OPTIONS
    
    local __output __res __sim_state
    json_get_vars device apn auth username password pincode delay pdptype profile $PROTO_DEFAULT_OPTIONS
    
    [ "$metric" = "" ] && metric="0"
    
    [ -n "$profile" ] || profile=2
    # simnum="$(uci -q get network.$interface.simslot)"
    # model=$(uci_get_state network "$interface" model)
    # driver=$(uci_get_state network "$interface" driver)
    # device=$(uci_get_state network "$interface" device)
    ctl_device=$(uci_get_state network "$interface" ctl_device)
    dat_device=$(uci_get_state network "$interface" dat_device)
    # manufacturer=$(uci_get_state network "$interface" manufacturer)
    
    : ${device:=$ctl_device}
    [ -n "$device" ] || {
        echo "No control device specified"
        proto_notify_error "$interface" NO_DEVICE
        proto_set_available "$interface" 0
        return 1
    }
    
    [ -e "$device" ] || {
        echo "Control device not valid"
        proto_set_available "$interface" 0
        return 1
    }
    
    devname="$(basename "$device")"
    devpath="$(readlink -f /sys/class/tty/$devname/device)"
    ifname="$( ls "$devpath"/../../*/net )"
    
    [ -n "$delay" ] && sleep "$delay"
    
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
    
    __sim_state="$(uci_get_state network "$interface" sim)"
    
    case "$__sim_state" in
        "SIM PIN")
            __output=''
            if [[ ${#pincode} -eq 4 && -z "${pincode//[0-9]/}" ]]; then
                __output=$(send_at "$device" "AT+CPIN=${pincode}")
            fi
            if [ $? -ne 0 ] && [ -z "$__output" ]; then
                proto_notify_error "$interface" "PIN_FAILED"
                return 1
            fi
        ;;
        "SIM PUK")
            proto_notify_error "$interface" "SIM_PUK"
            return 1
        ;;
        "ERROR")
            proto_notify_error "$interface" "SIM_ERROR"
            return 1
        ;;
        *)
            proto_notify_error "$interface" "UNKNOWN_SIM_STATUS"
            return 1
    esac
    
    local timeout=0
    while [[ -z "$operator" || -n "${operator//[0-9]/}" ]];do
        __output=$(send_at "$device" "AT+COPS?")
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
        __output=$(send_at "$device" "AT+CGDCONT?")
        if [ $? -eq 0 ];then
            local __pdpval
            __res=$(echo "$__output" | awk -F': ' -v pdp="$profile" '$0 ~ "\\+CGDCONT: " pdp {print $2}')
            __pdpval=$(echo "$__res" |cut -d',' -f2 | tr -d '"')
            if [ "${__pdpval}"X != "${pdptype}"X ];then
                send_at "$device" "AT+CGDCONT=${profile},\"${pdptype}\""
                [ $? -eq 0 ] || {
                    proto_notify_error "$interface" "SET_PDPTYPE_ERROR"
                    return 1
                }
            fi
        fi
    fi
    
    timeout=0
    while true;do
        __output=$(send_at "$device" "AT+CGREG?")
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
        [ "$apn" = "auto" ] || apn_val="$apn"
    fi
    
    if [ -n "${apn_val}" ];then
        case "$auth" in
            "pap") auth=1 ;;
            "chap") auth=2 ;;
            *) auth=0 ;;
        esac
        if [ ${#username} -gt 0 -a ${#password} -gt 0 ];then
            __cmd="AT^NDISDUP=${profile},1,\"${apn_val}\",\"${username}\",\"${password}\",$auth"
        else
            __cmd="AT^NDISDUP=${profile},1,\"${apn_val}\""
        fi
    else
        __cmd="AT^NDISDUP=${profile},1"
    fi
    
    send_at "$device" "$__cmd"
    [ $? -eq 0 ] || {
        proto_notify_error "$interface" "NDISDUP_ERROR"
        return 1
    }
    
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
    unlock_modem_at "me909s"

    echo "Setting up $ifname"
	proto_init_update "$ifname" 1
	proto_add_data
	json_add_string "manufacturer" "$manufacturer"
	proto_close_data
	proto_send_update "$interface"
    
    [ "$pdptype" = "IP" -o "$pdptype" = "IPV6" -o "$pdptype" = "IPV4V6" ] || pdptype="IP"
    local zone="$(fw3 -q network "$interface" 2>/dev/null)"
    [ "$pdptype" = "IP" -o "$pdptype" = "IPV4V6" ] && {
        json_init
        json_add_string name "${interface}_4"
        json_add_string ifname "@$interface"
        json_add_string proto "dhcp"
        proto_add_dynamic_defaults
        [ -n "$zone" ] && {
            json_add_string zone "$zone"
        }
        json_close_object
        ubus call network add_dynamic "$(json_dump)"
    }
    
    [ "$pdptype" = "IPV6" -o "$pdptype" = "IPV4V6" ] && {
        json_init
        json_add_string name "${interface}_6"
        json_add_string ifname "@$interface"
        json_add_string proto "dhcpv6"
        json_add_string extendprefix 1
        proto_add_dynamic_defaults
        [ -n "$zone" ] && {
            json_add_string zone "$zone"
        }
        json_close_object
        ubus call network add_dynamic "$(json_dump)"
    }
    
    /lib/me909s.sh cellular "$ctl_device" "$interface" &
}


proto_ecm_teardown() {
    local interface=$1
    
    local device profile
    
    json_get_vars device profile

    [ -n "$device" ] || device=$(uci_get_state network "$interface" ctl_device)
    
    [ -n "$profile" ] || profile=2
    [ -n "$device" ] &&  send_at "$device" "AT\^NDISDUP=${pdpnum},0" || {
        echo "Failed to disconnect"
        proto_notify_error "$interface" DISCONNECT_FAILED
        return 1
    }
    
    proto_init_update "*" 0
    proto_send_update "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
    add_protocol ecm
}