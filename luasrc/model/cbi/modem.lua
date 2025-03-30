require("luci.sys")

m = Map("ME909s", translate("鼎桥4G模块"))
m:append(Template("modem/status"))

s = m:section(TypedSection, "ec200a")
s.addremove = false
s.anonymous = true

SIM_SEL = s:option(ListValue, "sim_sel", translate("SIM卡选择"))
SIM_SEL.default = 0
SIM_SEL:value("0", translate("外置SIM卡"))
SIM_SEL:value("1", translate("内置SIM1"))
SIM_SEL:value("2", translate("内置SIM2"))
SIM_SEL.description = translate("切换使用的SIM卡")

-- SIM_SEL.write = function()
--     m.uci:set("ec200a", section, "sim_sel", value)
-- end

local modify_band = s:option(Flag, "modify_band", translate("锁频开关"))
modify_band.default = false
modify_band.description = translate("非专业人士请勿开启~!")

local bands = {
    { key = "FDD1", dec = "1" },
    { key = "FDD3", dec = "4" },
    { key = "FDD5", dec = "16" },
    { key = "FDD8", dec = "128" },
    { key = "TDD34", dec = "8589934592" },
    { key = "TDD38", dec = "137438953472" },
    { key = "TDD39", dec = "274877906944" },
    { key = "TDD40", dec = "549755813888" },
    { key = "TDD41", dec = "1099511627776" }
}
local lock_bands = s:option(MultiValue, "band", translate("锁频"))


for _, band in ipairs(bands) do
    lock_bands:value(band.key) 
end
lock_bands.write = function(self, section, value)
    local band_dec_table = {} 
    for _, band in ipairs(bands) do
        if value:find(band.key) then
            table.insert(band_dec_table, tonumber(band.dec))
        end
    end

    local sum = "0"
    for _, dec in ipairs(band_dec_table) do
        sum = sum + dec
    end

    local band_dec = tostring(sum)

    local function decToHex(dec)
        local hexChars = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
        local hex = ""
        local remainder
        while dec > 0 do
            remainder = dec % 16
            hex = hexChars[remainder + 1] .. hex
            dec = math.floor(dec / 16)
        end
        return hex
    end
    
	local band_hex = decToHex(tonumber(band_dec))
    m.uci:set("ec200a", section, "band", value)
    m.uci:set("ec200a", section, "band_dec", band_dec)
    m.uci:set("ec200a", section, "band_hex", band_hex)

end
lock_bands:depends("modify_band", "1")

local modify_imei = s:option(Flag, "modify_imei", translate("修改IMEI"))
modify_imei.default = false
modify_imei:depends("sim_sel", "0")
modify_imei.description = translate("警告！使用内置卡请勿改串！会锁卡！")

IMEI = s:option(Value, "IMEI", translate("IMEI"), "设备IMEI串号15位")
IMEI.default = luci.sys.exec("/usr/sbin/moat AT+CGSN | grep -oE '[0-9]+'")
IMEI:depends("modify_imei", "1")
IMEI.validate = function(self, value)
    if not value:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") then
        return nil, translate("IMEI必须是15位数字")
    end
    return value
end

local restart_btn = s:option(Button, "_restart", translate("重启模块"))
restart_btn.inputtitle = translate("重启")
restart_btn.description = translate("非必要勿重启! ")
restart_btn.inputstyle = "apply"
restart_btn.write = function()
    luci.sys.exec("/usr/sbin/moat 'AT+CFUN=1,1'")
end

local apply = luci.http.formvalue("cbi.apply")
if apply then
    -- m.uci:commit("ec200a")/
    io.popen("/usr/share/ec200a.sh &")
end

return m
