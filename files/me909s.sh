#!/bin/sh

. /lib/config/uci.sh

lock_modem_at() {
    local __pid=$1
    local __dev=$2
    
    [ -n "$__pid" ] || return 1
    if [ -f /tmp/.lock_${__dev}_modem ];then
        pid=$(cat /tmp/.lock_${__dev}_modem)
        [ -d /proc/$pid ] && return 1
    fi
    
    echo "$__pid" > /tmp/.lock_${__dev}_modem
    return 0
}

unlock_modem_at() {
    local __dev=$1
    [ -f /tmp/.lock_${__dev}_modem ] && rm /tmp/.lock_${__dev}_modem
    return 0
}

send_at() {
    local ctl_device="$1"
    [ -z "$ctl_device" ] && return 1
    
    local __at_rsp
    __at_rsp=$(/usr/bin/sendat "$@")
    
    [ -z "$__at_rsp" ] && return 1
    [ -n "${__at_rsp##*OK*}" ] && return 1
    
    echo "$__at_rsp"
}

mrd_imei() {
    [ -f "/var/state/network" ] || exit 1
    local ctl_device interface
    local imei=$1
    [ ${#imei} -eq 15 ] || exit 1
    interface=$(grep ".model=" /var/state/network | awk -F'.' '{print $2}')
    [ -z "$interface" ] && exit 1
    ctl_device=$(uci_get_state network "$interface" ctl_device)
    [ -z "$ctl_device" ] && exit 1
    
    local timeout=0
    while true;do
        [ -e "$ctl_device" ] || exit 1
        lock_modem_at $$ "me909s"
        [ $? -eq 0 ] || {
            [ $timeout -gt 5 ] && exit 1
            timeout=$((timeout+1))
            sleep 1
            continue
        }
        send_at "$ctl_device" "AT*PROD=1"
        [ $? -eq 0 ] || exit 1
        send_at "$ctl_device" "AT*MRD_IMEI=D"
        if [ $? -ne 0 ];then
            send_at "$ctl_device" "AT*PROD=0"
            exit 1
        fi
        send_at "$ctl_device" "AT*MRD_IMEI=W,$imei"
        if [ $? -ne 0 ];then
            send_at "$ctl_device" "AT*PROD=0"
            return 1
        fi
        send_at "$ctl_device" "AT*PROD=0"
        unlock_modem_at "me909s"
        return 0
    done
}

modem_hw_info() {
    local ctl_device="$1"
    [ -z "$ctl_device" ] && exit 1
    local interface="$2"
    local __output __res
    
    local timeout=0
    while true;do
        [ -e "$ctl_device" ] || exit 1
        lock_modem_at $$ "me909s"
        [ $? -eq 0 ] || {
            [ $timeout -gt 5 ] && exit 1
            timeout=$((timeout+1))
            sleep 1
            continue
        }
        send_at "$ctl_device" "ATE1"
        [ $? -eq 0 ] || sleep 1
        __output=$(send_at "$ctl_device" "ATI")
        if [ $? -eq 0 ];then
            local manufacturer model revision imei
            manufacturer=$(echo "$__output" | awk -F': ' '/^Manufacturer: / {print $2}' | tr -d '\r\n')
            model=$(echo "$__output" | awk -F': ' '/^Model: / {print $2}' | tr -d '\r\n')
            revision=$(echo "$__output" | awk -F': ' '/^Revision: / {print $2}' | tr -d '\r\n')
            imei=$(echo "$__output" | awk -F': ' '/^IMEI: / {print $2}' | tr -d '\r\n')
            uci_toggle_state network "$interface" manufacturer "$manufacturer"
            uci_toggle_state network "$interface" model "$model"
            uci_toggle_state network "$interface" revision "$revision"
            uci_toggle_state network "$interface" imei "$imei"
        fi
        
        __output=$(send_at "$ctl_device" "AT^CHIPTEMP?")
        if [ $? -eq 0 ];then
            __res=$(echo "$__output" | awk -F':' '/\^CHIPTEMP:/ {print $2}' | tr -d '\r\n')
            [ -n "$__res" ] && uci_toggle_state network "$interface" temp "${__res}"
        fi
        
        __output=$(send_at "$ctl_device" "AT+CPIN?")
        if [ $? -eq 0 ];then
            __res=$(echo "$__output" | awk -F': ' '/\+CPIN: / {print $2}' | tr -d '\r\n')
            [ -n "$__res" ] && uci_toggle_state network "$interface" sim_state "${__res}"
        else
            uci_toggle_state network "$interface" sim_state "ERROR"
        fi
        [ "$__res" = "READY" ] || {
            unlock_modem_at "me909s"
            return 1
        }
        
        __output=$(send_at "$ctl_device" "AT+CIMI")
        if [ $? -eq 0 ];then
            __res=$(echo "$__output" | grep -oE '[0-9]+')
            [ -n "$__res" ] && uci_toggle_state network "$interface" imsi "${__res}"
        fi
        
        __output=$(send_at "$ctl_device" "AT^ICCID?")
        if [ $? -eq 0 ];then
            __res=$(echo "$__output" | awk -F': ' '/\^ICCID?: / {print $2}' | tr -d '\r\n')
            [ -n "$__res" ] && uci_toggle_state network "$interface" iccid "${__res}"
        fi
        break
    done
    unlock_modem_at "me909s"
}

cellular(){
    local ctl_device="$1" interface="$2"
    [ -z "$ctl_device" ] && return 1
    local __output __res __sys_mode __rssi __rscp __ecno __rsrp __sinr
    while true;do
        [ -e "$ctl_device" ] || return 1
        lock_modem_at $$ "me909s"
        [ $? -eq 0 ] || {
            sleep 5
            continue
        }
        __output=$(send_at "$ctl_device" "AT^CHIPTEMP?")
        if [ $? -eq 0 ];then
            __res=$(echo "$__output" | awk -F':' '/\^CHIPTEMP:/ {print $2}' | tr -d '\r\n')
            [ -n "$__res" ] && uci_toggle_state network "$interface" temp "${__res}"
        fi
        
        __output=$(send_at "$ctl_device" "AT+CPIN?")
        if [ $? -eq 0 ];then
            __res=$(echo "$__output" | awk -F': ' '/\+CPIN: / {print $2}'  | tr -d '\r\n')
            [ -n "$__res" ] && uci_toggle_state network "$interface" sim_state "${__res}"
        else
            uci_toggle_state network "$interface" sim_state "ERROR"
            sleep 5
            continue
        fi
        
        __output=$(send_at "$ctl_device" "AT*BANDIND?")
        if [ $? -eq 0 ];then
            __res=$(echo "$__output" | awk -F':' '/\*BANDIND:/ {print $2}')
            __band=$(echo "$__res" |cut -d',' -f2 | tr -d ' ')
            [ -n "$__band" ] && uci_toggle_state network "$interface" band "${__band}"
        fi
        
        __output=$(send_at "$ctl_device" "AT^MONSC")
        if [ $? -eq 0 ];then
            __res=$(echo "$__output" |awk -F': ' '/\^MONSC: / {print $2}' | tr -d '\r\n')
            
            __sys_mode=$(echo "$__res" |cut -d',' -f1)
            case "$__sys_mode" in
                "GSM")
                    __band=$(echo "$__res" |cut -d',' -f4)
                    case $__band in
                        0) __band="GSM850" ;;
                        1) __band="GSM900" ;;
                        2) __band="GSM1800" ;;
                        3) __band="GSM1900" ;;
                    esac
                    __lac=$(echo "$__res" |cut -d',' -f6)
                    __rxlev=$(echo "$__res" |cut -d',' -f7)
                ;;
                "WCDMA")
                    __arfcn=$(echo "$__res" |cut -d',' -f4)
                    __cellid=$(echo "$__res" |cut -d',' -f6)
                    __lac=$(echo "$__res" |cut -d',' -f7)
                    __rsrp=$(echo "$__res" |cut -d',' -f8)
                    __rxlev=$(echo "$__res" |cut -d',' -f9)
                ;;
                "LTE")
                    __arfcn=$(echo "$__res" |cut -d',' -f4)
                    __cellid=$(echo "$__res" |cut -d',' -f5)
                    __pci=$(echo "$__res" |cut -d',' -f6)
                    __tac=$(echo "$__res" |cut -d',' -f7)
                    __rsrp=$(echo "$__res" |cut -d',' -f8)
                    __rsrq=$(echo "$__res" |cut -d',' -f9)
                    __rxlev=$(echo "$__res" |cut -d',' -f10)
                ;;
            esac
            [ -n "$__sys_mode" ] && uci_toggle_state network "$interface" "mode" "${__sys_mode}"
            [ -n "$__arfcn" ] && uci_toggle_state network "$interface" arfcn "${__arfcn}"
            [ -n "$__cellid" ] && uci_toggle_state network "$interface" cellid "${__cellid}"
            [ -n "$__pci" ] && uci_toggle_state network "$interface" pci "${__pci}"
            [ -n "$__lac" ] && uci_toggle_state network "$interface" lac "${__lac}"
            [ -n "$__tac" ] && uci_toggle_state network "$interface" tac "${__tac}"
            [ -n "$__rsrp" ] && uci_toggle_state network "$interface" rsrp "${__rsrp}"
            [ -n "$__rsrq" ] && uci_toggle_state network "$interface" rsrq "${__rsrq}"
            [ -n "$__rxlev" ] && uci_toggle_state network "$interface" rxlev "${__rxlev}"
            [ -n "$__band" ] && uci_toggle_state network "$interface" band "${__band}"
        fi
        unlock_modem_at "me909s"
        sleep 5
    done
}

__CMD=$1

case "$__CMD" in
    "cellular")
        shift
        cellular $@
    ;;
    "mrd_imei")
        shift
        mrd_imei $@
    ;;
    
esac