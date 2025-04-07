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

local apply = luci.http.formvalue("cbi.apply")
if apply then
    sys.exec("/etc/init.d/me909s reload")
end

return m
