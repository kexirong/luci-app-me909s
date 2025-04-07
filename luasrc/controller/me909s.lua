module("luci.controller.me909s", package.seeall)

local hidebtn = {
    hideapplybtn = true,
    hidesavebtn = true,
    hideresetbtn = true
}

function index()
    entry({"admin", "me909s"}, firstchild(), _("鼎桥"), 25).dependent = true
    entry({"admin", "me909s", "status"}, cbi("me909s/status", hidebtn), _("状态"), 10)
    entry({"admin", "me909s", "setting"}, cbi("me909s/setting"), _("设置"), 20)
    entry({"admin", "me909s", "advance"}, cbi("me909s/advance", hidebtn), _("高级"), 30)
end
