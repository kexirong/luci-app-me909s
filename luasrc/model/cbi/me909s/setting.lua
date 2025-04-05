local sys = require "luci.sys"

m = Map("me909s", translate("设置"))

ts = m:section(TypedSection, "setting")
ts.addremove = false
ts.anonymous = true
sys.exec("logger -t ME909s DEBUG")
local sim_val = sys.exec("cat /sys/class/gpio/sim_select/value")
sys.exec("logger -t ME909s-setting-DEBUG '" .. sim_val .. "'")
sim_slot = ts:option(ListValue, "sim_slot", translate("SIM卡切换"))
sim_slot.default = sim_val
sim_slot:value("1", translate("SIM"))
sim_slot:value("0", translate("eSIM"))

local usb_val = sys.exec("cat /sys/class/gpio/usb_power/value")
sys.exec("logger -t ME909s-setting-DEBUG '" .. usb_val .. "'")
usb_power = ts:option(ListValue, "usb_power", translate("USB开关"))
usb_power.default = usb_val
usb_power:value("1", translate("开"))
usb_power:value("0", translate("关"))

 

function tableToString(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
    if type(k) == "string" then
    k = string.format("%q", k)
    end
    if type(v) == "table" then
    v = tableToString(v)
    else
    v = string.format("%q", v)
    end
    result = result .. "[" .. k .. "]=" .. v .. ","
    end
    return result .. "}"
    end

local apply = luci.http.formvalue()
if apply then
 
    sys.exec("logger -t ME909s apply DEBUG")
    -- 执行配置生效逻辑
    sys.exec("logger -t ME909s apply setting DEBUG " .. tableToString(apply))
end

return m
