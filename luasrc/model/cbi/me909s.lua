local uci = require"luci.model.uci".cursor(nil, "/var/state")
local sys = require "luci.sys"

m = Map("ME909s", translate("鼎桥ME909S"))

s = m:section(SimpleSection, nil, translate("模块状态"))
s.template = "me909s/status"

local target_interface
uci:foreach("network", "interface", function(section)
    if section.model then
        target_interface = section[".name"]
        return false
    end
end)

if not target_interface then
    m:get("template").status_data = {}
else
    -- 传递状态数据到模板
    m:get("template").status_data = {
        manufacturer = uci:get("network", target_interface, "manufacturer") or "N/A",
        model = uci:get("network", target_interface, "model") or "N/A",
        simslot = uci:get("network", target_interface, "simslot") or "N/A",
        imei = uci:get("network", target_interface, "imei") or "N/A",
        imsi = uci:get("network", target_interface, "imsi") or "N/A",
        iccid = uci:get("network", target_interface, "iccid") or "N/A",
        ifname = uci:get("network", target_interface, "ifname") or "N/A",
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

return m
