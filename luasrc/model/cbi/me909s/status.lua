local uci = require"uci".cursor(nil, "/var/state")
local sys = require "luci.sys"

m = Map("me909s")

s = m:section(SimpleSection)
s.template = "me909s/status"

local target_interface
local sim_val = sys.exec("cat /sys/class/gpio/sim_select/value 2>/dev/null")
uci:foreach("network", "interface", function(section)
    local model = uci:get("network", section[".name"], "model")
    if model ~= nil then
        target_interface = section[".name"]
        return false
    end
end)
local status_data

if target_interface ~= nil then
    status_data = {
        manufacturer = uci:get("network", target_interface, "manufacturer") or "-",
        model = uci:get("network", target_interface, "model") or "-",
        revision = uci:get("network", target_interface, "revision") or "-",
        simslot = string.gsub(sim_val or "1", "%s+", ""),
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
