local skynet = require "skynet"
require "skynet.manager"
local service = require "skynet.service"

local max_client = 80000

-- local lfs = require "lfs"



local debug_console_inject = require "debug_console_inject"
skynet.start(function()
    skynet.error("Server start")
    if not skynet.getenv "daemon" then
        skynet.newservice("console")
    end

    skynet.error("=============================================")
	skynet.error(os.date("%Y/%m/%d %H:%M:%S ") .. " start")
	skynet.error("=============================================")
	skynet.name(".load_gameconf",skynet.newservice("load_gameconf"))


    --数据库服务
    skynet.name(".db_mgr", skynet.newservice("mongo/mongodbmgr","true"))
	skynet.name(".db_mgr1", skynet.newservice("mongo/mongodbmgr"))
	skynet.name(".db_mgr2", skynet.newservice("mongo/mongodbmgr"))
	skynet.name(".db_mgr3", skynet.newservice("mongo/mongodbmgr"))
	skynet.name(".db_mgr_del",skynet.newservice("mongo/mongodbmgr"))
	skynet.name(".db_mgr_rec",skynet.newservice("mongo/mongodbmgr"))

    --协议共享
    skynet.name(".pb_share", skynet.newservice("protobuf3/pb_share"))

    --协议服务
    for i=1,skynet.getenv("pb_mgr_num") do
		skynet.name(".pb_mgr_" .. i,skynet.newservice("protobuf3/pb_mgr"))
	end


    --gen_agent
    for i=1,skynet.getenv("gen_agent_num") do
		skynet.name(".gen_agent_" .. i,skynet.newservice("gen_agent"))
	end
    

    --登录服
    for i=1,skynet.getenv("loginserver_num") do
		skynet.name(".login_" .. i,skynet.newservice("login/loginserver"))
	end

    --所有玩家管理服
    skynet.name(".agent_mgr" ,skynet.newservice("agent_mgr"))

    --房间管理服
    skynet.name(".room_mgr" ,skynet.newservice("room/room_mgr"))


    -- skynet.name(".test" ,skynet.newservice("test_proto3"))

    local address = skynet.newservice("debug_console",18887)
    debug_console_inject(address)


    --网关
    local ws_watchdog = skynet.newservice("ws/ws_watchdog")
    local protocol = "ws"
    local ws_port = 18888
    skynet.call(ws_watchdog, "lua", "start", {
        port = ws_port,
        maxclient = max_client,
        nodelay = true,
        protocol = protocol,
    })
    skynet.error("websocket watchdog listen on", ws_port)


    -- skynet.newservice("test_card_helper")

    skynet.exit()
end)
