module("luci.controller.modem", package.seeall)

function index()
	local page
	page = entry({"admin", "network", "modem"}, cbi("me909s"), _("鼎桥模块"), 100)
	page.dependent = true
	-- entry({"admin", "network", "modem", "status"}, call("action_status"))
	-- entry({"admin", "network", "modem", "status"})
end
