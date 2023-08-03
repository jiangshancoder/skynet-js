local skynet = require "skynet"
local cjson = require "cjson"
require "skynet.manager"

local timer = require "timer"
local queue = require "skynet.queue"

local REQUEST = {}
local CMD = {}

local msg_queue = {}  -- 发送队列
local pb_mgr_index = math.random(skynet.getenv("pb_mgr_num"))


local my_data 				= require "agent_module.my_data"
local my_hall 				= require "agent_module.my_hall"               -- 游戏大厅相关请求
local my_room 				= require "agent_module.my_room"               -- 


local client_msg_session = 0

my_data.heartcount = 5


local cs


local host, send_request,unpack_msg

local WATCHDOG

local CMD = {}
local client_fd
local gate

-- skynet.register_protocol {
--     name = "client",
--     id = skynet.PTYPE_CLIENT,
--     unpack = skynet.tostring,
--     dispatch = function(fd, address, msg)
--         assert(fd == client_fd) -- You can use fd to reply message
--         skynet.ignoreret()  -- session is fd, don't call skynet.ret
--         --skynet.trace()
--         -- echo simple
--         skynet.send(gate, "lua", "response", fd, msg)
--         skynet.error(address, msg)
--     end
-- }

function REQUEST:testcmd()
	print(self.pid)
	return {ret = true}
end
function REQUEST:heartbeat()
	my_data.heartcount = 5
	return { ok = true,time=os.time()}
end
function REQUEST:enter_room()
	local room_level = self.room_level
	local pack = {
		agent = skynet.self(),
		level = room_level,
		pid = my_data.pid,
		nickname = my_data.db_info.nickname,
		chips = my_data.db_info.chips,
	}
	local error,room_addr = skynet.call(".room_mgr","lua","enter_room",pack)
	print("玩家申请加入房间",self.room_level,error)
	if error == 0 then
		my_data.room_addr = room_addr
	else
		return { error = error,room_level = room_level}
	end
end
local function request(name, args, response)
	local f = assert(REQUEST[name], name)
	if not f then
		skynet.error("request not find",name)
	end
	return f(args)
end

------------------------------房间回调-----------------------------------------
--加入房间回调
function CMD.add_player(info,playerid)
	print("add_player",info)
end
--同步房间信息
-- function CMD.room_add_player(info)
	
-- end

skynet.register_protocol {
	name = "client",	
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return skynet.tostring(msg, sz)
	end,
	dispatch = function (_, _, msg, sz)--ttype, name, args, response)
		skynet.ignoreret()

		local  name, session,args = skynet.call(".pb_mgr_" .. pb_mgr_index,"lua","dispatch",msg)
		-- skynet.error("收到协议",name, session,args)
		cs(function ()
			-- print(name, args)
			if name~="heartbeat" then
				print(name, args)
			end
			local ok, result  = pcall(request, name, args)
			
			if ok then
				if result then
					if name~="heartbeat" then
						print("回复消息",name,result)
					end
					my_data.send_push(name,result)
				end
			else
				skynet.error(result,name .. ' error ')
			end
		end)
	end
}


local function create_sender()
	

	local self = {}
	function self.send(name,pack, need_reqpeat)
		local t = os.time()
		if need_reqpeat then
			table.insert(msg_queue, {name=name,pack=pack,t=0})
		else
			if my_data.online then
				if name ~= "heartbeat" then 
					print("send2client",name,#pack)
				end
				skynet.send(my_data.gate, "lua", "response", my_data.fd, pack)
			end
		end
		for i = 1,#msg_queue do
			if my_data.online then
				if t - msg_queue[i].t > 2 then
					--2秒内没有移除重新发送
					msg_queue[i].t = t
					local pack = msg_queue[i].pack
					-- print("send2",name)
					skynet.send(my_data.gate, "lua", "response", my_data.fd, pack)
				end
			end
		end 
	end
	return self
end

local function init_module()
	my_data.sender = create_sender()
	function my_data.send_push(name, args)
		-- print('=========================玩家收到的消息',name)
		client_msg_session = client_msg_session + 1
		my_data.sender.send(name,send_request(name, args,client_msg_session))
	end

	my_hall.init(REQUEST,CMD)
	my_room.init(REQUEST,CMD)

end


function CMD.start(conf)
    local fd = conf.client
	gate = conf.gate
    my_data.gate = conf.gate
    WATCHDOG = conf.watchdog
    client_fd = fd
	my_data.fd = fd
    skynet.call(gate, "lua", "forward", fd)
	local ip = conf.addr:match("(.+):(.+)")
	CMD.login(conf.userinfo)
end

function CMD.reconnect(conf)
    local fd = conf.client
	gate = conf.gate
    my_data.gate = conf.gate
    WATCHDOG = conf.watchdog
    client_fd = fd
    skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
    -- todo: do something before exit
	skynet.error("玩家断开连接")
	--TODO 心跳失联和连接真正断开，调用了两次下面的函数，会导致玩家计数错误
	CMD.LogoutComplete()

    skynet.exit()
end


function CMD.reload_proto()
	
    unpack_msg = function(msg,sz)
        return msg,sz
    end

    send_request = function(...)
		return skynet.call(".pb_mgr_" .. pb_mgr_index,"lua","pack_message",...)
    end
end
function CMD.init_args()
	my_data.reconnect_time = 0
	my_data.heartcount = 5
end
--玩家下线处理
function CMD.LogoutComplete()

	my_data.hearbeat_invoke()

	-- maybe kick out 顶号
	if my_data.room_addr then
		skynet.send(my_data.room_addr, "lua", "logout", my_data.pid)
	end

	skynet.send(".agent_mgr", "lua", "logout", my_data.pid)
	if WATCHDOG then
		skynet.call(WATCHDOG, "lua", "close", my_data.fd)--my_data.userid, my_data.subid)
	end
end
--5秒检测一次
local function timer_5_check()
	skynet.fork(function ()
		-- check_online_time()
	end)
	
end
--2秒检测一次
local function timer_2_check()
end
--1秒检测一次
local function timer_1_check()
	my_data.heartcount = my_data.heartcount - 1

	--一分半没有心跳 断开链接
	if my_data.heartcount < -90 and  not my_data.my_room then
		print("pid = ", my_data.pid, " heartbeat out time.")
		my_data.hearbeat_invoke()
		CMD.LogoutComplete()
	end
end
--心跳
function CMD.start_check_heartbeat()
	my_data.heartcount = 5
	local _temp_timer_check_count = 1
	my_data.hearbeat_invoke = timer.create(100,function ()
		

		_temp_timer_check_count = _temp_timer_check_count + 1
		if _temp_timer_check_count % 5 == 0 then
			timer_5_check()
			_temp_timer_check_count = 1--在最大timercount清零，避免太大
		end
		if _temp_timer_check_count % 2 == 0 then
			timer_2_check()
		end
		timer_1_check()
	end,-1)
end
-- 玩家登陆
function CMD.login(info)
	CMD.init_args()
	CMD.start_check_heartbeat()
	my_data.ip = info.ip
	my_data.pid = info.pid
	my_data.online = true--在线
	print("玩家登录",info)
	local last_login_time = 0
	
	my_data.db_info, last_login_time = skynet.call(get_db_mgr(), "lua", "get_player_dbinfo", info.account)
	print("my_data.db_info",my_data.db_info)
	if not my_data.db_info then
		--TODO 重新获取数据
	end
	init_module()


	skynet.send(".agent_mgr", "lua", "login", my_data.pid)

	local room_list = {}
    for i=1,4 do
        table.insert(room_list,{
            room_level = i,
            room_type = i,
            small_blind = DEFINE_SMALL_BLIND_AMOUNT,
            big_blind = DEFINE_BIG_BLIND_AMOUNT,
            max_score = i*2000,
            min_score = i*1000,
        })
    end
	local pack = {
		pid = my_data.pid,
		chips = my_data.db_info.chips,
		country = my_data.db_info.country,
		headurl = my_data.db_info.headurl,
		roomlist = room_list,
		nickname = my_data.db_info.nickname,
		server_time = os.time(),
	}
	my_data.send_push("baseinfo",pack)
	-- if not my_data.sameday then
	-- 	collect_login()
		
	-- end
	

	-- log_login(my_data.db_info, ip)

end


local function mem_check()
	local kb, bytes = collectgarbage "count"
	if kb > 2000 then
		collectgarbage "collect"
	end
	skynet.timeout(math.random(1000,1500),mem_check)
end

skynet.start(function()

    math.randomseed(os.time())
    cs = queue()

    my_data.my_agent = skynet.self()

    CMD.reload_proto()

    skynet.dispatch("lua", function(session, source, command, ...)
        --skynet.trace()
        local f = CMD[command]
		-- print(session, source, command)
		if not f then
			skynet.error("找不到命令",session, source, command)
			skynet.ret(skynet.pack(nil))
		else
			if session == 0 then
				f(...)
			else
				skynet.ret(skynet.pack(f( ...)))
			end
		end
    end)
end)
