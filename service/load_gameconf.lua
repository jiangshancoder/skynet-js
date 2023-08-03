local skynet = require "skynet"
local snax = require "skynet.snax"


local CMD = {}
local  SERVER_ID     =   1

local OPTION = {
    mongodb = {
        main = {
            host = "127.0.0.1",
            port = 27017,
            name = "test_main",
            count = 2,--连接数
            username="test_main",
            password="xxxxxxxxxxxxxxxx",
            authdb="test_main",
        },
        log = {

            host = "127.0.0.1",
            port = 27017,
            name = "test_rec",
            count = 2,--连接数
            username="test_rec",
            password="xxxxxxxxxxxxxxx",
            authdb="test_rec",
        },
    },
}


function CMD.set_env(gameconf)

	for k,v in pairs(gameconf) do
		if k == "mongodb" then
			for m,n in pairs(gameconf.mongodb.main) do
				skynet.setenv("mongodb_main_" .. m ,tostring(n))
			end
			for m,n in pairs(gameconf.mongodb.log) do
				skynet.setenv("mongodb_log_" .. m ,tostring(n))
			end
		else
			skynet.setenv(k,tostring(v))
		end
	end
end


function CMD.exit()
	skynet.exit()
end


function CMD.init()
	--200     {"ip":"118.116.110.180","err":0}        /root/server/youai-mahjong-h5-server/
    OPTION.websockettype = "ws"
    OPTION.dot_server = ""--打点服
    OPTION.env = "publish"--环境
    OPTION.pub_server_url = "127.0.0.1:" ..(16000 + SERVER_ID)
    OPTION.notify_url = ""--支付回调地址
    OPTION.server_env = "0"--0测试环境，1正式服环境
	OPTION.debug_console_port  = 8000 + SERVER_ID            -- 控制台端口
    OPTION.http_server_port  = 8100 + SERVER_ID            -- http服务端口
    OPTION.http_server2_port  = 8200 + SERVER_ID            -- http服务端口
	
    OPTION.notify_url = OPTION.notify_url .. OPTION.http_server_port
	CMD.set_env(OPTION)
end


skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    CMD.init()
    skynet.exit()
end)


