local uci = require "uci".cursor(nil, "/var/state")
local sys = require "luci.sys"

m = Map("ME909s", translate("鼎桥ME909S"))

s = m:section(SimpleSection, nil, translate("模块状态"))
s.template = "me909s/status"
local function log_debug(msg)
    sys.exec("logger -t ME909s-DEBUG '" .. msg .. "'")
end
local target_interface

uci:foreach("network", "interface", function(section)
    local model = uci:get("network", section[".name"], "model")
    log_debug("开始搜索 ME909s 接口配置" .. section[".name"])
    if model ~= nil then
        log_debug(section[".name"] .. "接口配置model" .. model)
        target_interface = section[".name"]
        log_debug("找到接口：" .. target_interface)
        return false
    end
end)
local status_data

if  target_interface ~= nil then
    log_debug("开始收集数据：" .. target_interface)
   status_data = {
        manufacturer = uci:get("network", target_interface, "manufacturer") or "-",
        model = uci:get("network", target_interface, "model") or "-",
        revision = uci:get("network", target_interface, "revision") or "-",
        simslot = uci:get("network", target_interface, "simslot") or "-",
        imei = uci:get("network", target_interface, "imei") or "-",
        imsi = uci:get("network", target_interface, "imsi") or "-",
        iccid = uci:get("network", target_interface, "iccid") or "-",
        operator = uci:get("network", target_interface, "operator") or "-",
        rxlev = uci:get("network", target_interface, "rxlev") or "-",
        temp = uci:get("network", target_interface, "temp") or "-",
        mode = uci:get("network", target_interface, "mode") or "-",
        lac = uci:get("network", target_interface, "lac") or "-",
        sim_state = uci:get("network", target_interface, "sim_state") or "-",
        band = uci:get("network", target_interface, "band") or "-",
        arfcn = uci:get("network", target_interface, "arfcn") or "-",
        cellid = uci:get("network", target_interface, "cellid") or "-",
        pci = uci:get("network", target_interface, "pci") or "-",
        tac = uci:get("network", target_interface, "tac") or "-",
        rsrp = uci:get("network", target_interface, "rsrp") or "-",
        rsrq = uci:get("network", target_interface, "rsrq") or "-"
    }

end

s.status_data = status_data or {}
return m
