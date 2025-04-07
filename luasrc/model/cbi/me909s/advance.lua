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
    sys.exec("logger -t ME909s advance DEBUG " .. (cur_imei or "N/A"))
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

local save_btn = ss:option(Button, "save", translate("设置IMEI"))
save_btn.inputtitle = translate("确定")
save_btn.inputstyle = "apply"
save_btn.write = function()
    sys.exec("logger -t ME909s advance save_btn.write DEBUG " .. print_r(luci.http.formvalue()))
end
return m
