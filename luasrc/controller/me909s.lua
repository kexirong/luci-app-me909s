module("luci.controller.me909s", package.seeall)
local http = require("luci.http")
function index()
    entry({"admin", "me909s"}, firstchild(), _("鼎桥"), 25).dependent = true
    entry({"admin", "me909s", "status"}, cbi("me909s/status", {
        hideapplybtn = true,
        hidesavebtn = true,
        hideresetbtn = true
    }), _("状态"), 10)
    entry({"admin", "me909s", "setting"}, cbi("me909s/setting"), _("设置"), 20)
    entry({"admin", "me909s", "advance"}, cbi("me909s/advance", {
        hideapplybtn = true,
        hidesavebtn = true,
        hideresetbtn = true
    }), _("高级"), 30)
end
