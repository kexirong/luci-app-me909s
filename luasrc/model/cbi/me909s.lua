local uci = require "uci".cursor(nil, "/var/state")
local fs = require "nixio.fs"
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
function table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end
if  target_interface ~= nil then
    log_debug("开始收集数据：" .. target_interface)
   status_data = {
        manufacturer = uci:get("network", target_interface, "manufacturer") or "N/A",
        model = uci:get("network", target_interface, "model") or "N/A",
        simslot = uci:get("network", target_interface, "simslot") or "N/A",
        imei = uci:get("network", target_interface, "imei") or "N/A",
        imsi = uci:get("network", target_interface, "imsi") or "N/A",
        iccid = uci:get("network", target_interface, "iccid") or "N/A",
        operator = uci:get("network", target_interface, "operator") or "N/A",
        rxlev = uci:get("network", target_interface, "rxlev") or "N/A",
        temp = uci:get("network", target_interface, "temp") or "N/A",
        mode = uci:get("network", target_interface, "mode") or "N/A",
        lac = uci:get("network", target_interface, "lac") or "N/A",
        sim = uci:get("network", target_interface, "sim") or "N/A",
        band = uci:get("network", target_interface, "band") or "N/A",
        arfcn = uci:get("network", target_interface, "arfcn") or "N/A",
        cellid = uci:get("network", target_interface, "cellid") or "N/A",
        pci = uci:get("network", target_interface, "pci") or "N/A",
        tac = uci:get("network", target_interface, "tac") or "N/A",
        rsrp = uci:get("network", target_interface, "rsrp") or "N/A",
        rsrq = uci:get("network", target_interface, "rsrq") or "N/A"
    }

end
log_debug("收集数据完成，字段数量：" .. tostring(table_size(status_data)))
for k, v in pairs(status_data) do
    log_debug(string.format("%s = %s", k, v))
end
s.status_data = status_data or {}
return m
