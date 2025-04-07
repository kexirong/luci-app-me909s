local uci = require"uci".cursor(nil, "/var/state")
local sys = require "luci.sys"
function ToStringEx(value)
    if type(value) == 'table' then
        return TableToStr(value)
    elseif type(value) == 'string' then
        return "\'" .. value .. "\'"
    else
        return tostring(value)
    end
end
function TableToStr(t)
    if t == nil then
        return ""
    end
    local retstr = "{"

    local i = 1
    for key, value in pairs(t) do
        local signal = ","
        if i == 1 then
            signal = ""
        end

        if key == i then
            retstr = retstr .. signal .. ToStringEx(value)
        else
            if type(key) == 'number' or type(key) == 'string' then
                retstr = retstr .. signal .. '[' .. ToStringEx(key) .. "]=" .. ToStringEx(value)
            else
                if type(key) == 'userdata' then
                    retstr = retstr .. signal .. "*s" .. TableToStr(getmetatable(key)) .. "*e" .. "=" ..
                                 ToStringEx(value)
                else
                    retstr = retstr .. signal .. key .. "=" .. ToStringEx(value)
                end
            end
        end

        i = i + 1
    end

    retstr = retstr .. "}"
    return retstr
end
local target_interface = sys.exec("grep \".model=\" /var/state/network | awk -F'.' '{print $2}'")
sys.exec("logger -t ME909s advance DEBUG " .. target_interface)

local cur_imei
if target_interface then
    cur_imei = uci:get("network", string.gsub(target_interface, "%s+", ""), "imei")
end

m = Map("me909s")
ss = m:section(SimpleSection, "IMEI", "修改IMEI模块会重启")
function ss.parse(self, section, novld)
    sys.exec("logger -t ME909s advance ss.parse  DEBUG " .. TableToStr(luci.http.formvalue() or {}))
    local new_imei = luci.http.formvalue("cbid.me909s.1.imei")
    if cur_imei and new_imei ~= cur_imei then
        sys.exec("logger -t ME909s advance ss.parse DEBUG " .. new_imei) 
    end
    sys.exec("logger -t ME909s advance ss.parse DEBUG " .. (luci.http.formvalue("cbid.me909s.1.imei1") == cur_imei and "true" or 'false'))
end

imei = ss:option(Value, "imei", translate("IMEI"))
imei.default = cur_imei
imei.datatype = "rangelength(15,15)"
imei.validate = function(self, value)
    if not value:match("^%d{15}$") then
        return nil, "IMEI 必须为纯数字"
    end
    return value
end

local set_imei_btn = ss:option(Button, "set_imei", translate("设置IMEI"))
set_imei_btn.inputtitle = translate("确定")
set_imei_btn.inputstyle = "apply"

local hex_to_bits = {["0"]="0000",["1"]="0001",["2"]="0010",["3"]="0011",["4"]="0100", ["5"]="0101",["6"]="0110",["7"]="0111",["8"]="1000",["9"]="1001",["a"]="1010",["b"]="1011",["c"]="1100",["d"]="1101",["e"]="1110",["f"]="1111"}

local bits_to_hex = {}
for k, v in pairs(hex_to_bits) do
    bits_to_hex[v] = k:upper()
end

local function hex_bitwise_op(a, b, op)
    local max_len = math.max(#a, #b)
    -- 补零到左侧使长度相同，并转为小写
    a = string.rep("0", max_len - #a) .. a:lower()
    b = string.rep("0", max_len - #b) .. b:lower()
    
    local result = {}
    for i = 1, max_len do
        local c_a = a:sub(i, i)
        local c_b = b:sub(i, i)
        local bits_a = hex_to_bits[c_a]
        local bits_b = hex_to_bits[c_b]
        if not bits_a or not bits_b then
            return nil, "invalid hex character"
        end
        local res_bits = ""
        for j = 1, 4 do
            local a_bit = bits_a:sub(j, j)
            local b_bit = bits_b:sub(j, j)
            local bit_result
            if op == "AND" then
                bit_result = (a_bit == "1" and b_bit == "1") and "1" or "0"
            elseif op == "OR" then
                bit_result = (a_bit == "1" or b_bit == "1") and "1" or "0"
            else
                return nil, "invalid operation"
            end
            res_bits = res_bits .. bit_result
        end
        local hex_char = bits_to_hex[res_bits]
        if not hex_char then
            return nil, "invalid resulting bits"
        end
        table.insert(result, hex_char)
    end
    -- 合并结果并去除前导零
    local result_str = table.concat(result)
    result_str = result_str:gsub("^0+", "")
    if result_str == "" then
        result_str = "0"
    end
    return result_str
end

function hex_and(a, b)
    return hex_bitwise_op(a, b, "AND")
end

function hex_or(a, b)
    return hex_bitwise_op(a, b, "OR")
end

ss = m:section(SimpleSection, "BAND", "设置BAND模块会重启")
function ss.parse(self, section, novld)
end

local mode = ts:option(ListValue, "mode", translate("网络模式"))
mode:value("030201", translate("preferLTE"))
mode:value("0201", translate("preferUMTS"))
mode:value("03", translate("LTE"))
mode:value("02", translate("UMTS"))
mode:value("01", translate("GSM"))
mode:value("00", translate("AUTO"))

local gms_umts_bands = {
    { key = "GSM_DCS_1800", hex = "80" },
    { key = "GSM_EGSM_900", hex = "100" },
    { key = "GSM_PGSM_900", hex = "200" },
    { key = "Band_1", hex = "400000" },
    { key = "Band_8", hex = "2000000000000"}
}
local gms_umts_band = ss:option(MultiValue, "gms_umts_band", translate("GMS/UMTS频段"))
for _, band in ipairs(gms_umts_bands) do
    gms_umts_band:value(band.key, band.hex) 
end

local lte_bands = {
    { key = "FDD1", hex = "1" },
    { key = "FDD3", hex = "4" },
    { key = "FDD5", hex = "10" },
    { key = "FDD8", hex = "80" },
    { key = "TDD34", hex = "200000000" },
    { key = "TDD38", hex = "2000000000" },
    { key = "TDD39", hex = "4000000000" },
    { key = "TDD40", hex = "8000000000" },
    { key = "TDD41", hex = "10000000000" }
}
local let_band = ss:option(MultiValue, "let_band", translate("LET频段"))
for _, band in ipairs(lte_bands) do
    let_band:value(band.key, band.hex) 
end

local set_band_btn = ss:option(Button, "set_band", translate("设置BAND"))
set_band_btn.inputtitle = translate("确定")
set_band_btn.inputstyle = "apply"

return m
