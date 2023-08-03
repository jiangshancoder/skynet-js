local skynet = require "skynet"
local service = require "skynet.service"

local max_client = 64


local debug_console_inject = require "debug_console_inject"
skynet.start(function()
    skynet.error("Server start")
    if not skynet.getenv "daemon" then
        skynet.newservice("console")
    end
    local address = skynet.newservice("debug_console",8000)
    debug_console_inject(address)

    local web_watchdog = skynet.newservice("http/web_watchdog")
    local web_port = 8889
    skynet.call(web_watchdog, "lua", "start", {
        port = web_port,
        agent_cnt = 10,
        protocol = "http",
    })
    skynet.error("web watchdog listen on", web_port)


    print({"这是一个table","print也可以打印table","并且显示文件和行号"})


    -- simple_echo_client_service(protocol)
    
    -- local logger = require "logger"
    -- logger:init()
    -- logger:SaveData("这是一条测试日志")
    -- logger:SaveData("这是一条测试日志")
    -- logger:SaveData("这是一条测试日志")
    -- logger:SaveData("这是一条测试日志")
    -- logger:SaveData("这是一条测试日志")
    -- logger:SaveData("这是一条测试日志")
    -- logger:SaveData("这是一条测试日志")
    -- logger:SaveData("这是一条测试日志")
    -- logger:SaveData("这是一条测试日志")
    -- logger:SaveData("这是一条测试日志")
    -- logger:SaveData("这是一条测试日志")

    local daemon = skynet.getenv("daemon")

    print(daemon,"daemon")

    skynet.exit()
end)
