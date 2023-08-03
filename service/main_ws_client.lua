local skynet = require "skynet"
require "skynet.manager"
local service = require "skynet.service"
local websocket = require "http.websocket"
local cjson = require "cjson"
local ws_id
local session = 1
local cmd = {}



local url = "ws://127.0.0.1:18888"

local header = {
    account = "skynet_client" .. math.random(1,99999),
    password = "skynet_client_pwd",
    channel = "test",
}

local deal_msg,reconnect

local function pack_msg(name,data)
    session = session + 1
    return skynet.call(".pb_mgr","lua","pack_message",name,data,session,"c2s_")
end
local function dispatch(bindata)
    local  name, nsession,args = skynet.call(".pb_mgr","lua","dispatch",bindata,#bindata,"s2c_")
    return name,args
end

local function send2server(name,data)
    if ws_id then
        websocket.write(ws_id,pack_msg(name,data or {}))
        return true
    end
end

local function heart_beat()
    while true do
        skynet.sleep(500)
        local ok = send2server("heartbeat",{})
        if ok then
            -- skynet.error("发送心跳包")
        end
    end
end
reconnect = function()
    local ok = false
    while true do
        skynet.sleep(500)
        ok,ws_id = pcall(websocket.connect,url,header)
        if ws_id then
            skynet.fork(deal_msg)
            skynet.fork(function ()
                skynet.sleep(200)
                send2server("enter_room",{room_level = 1})
            end)
            return
        end
    end
end
deal_msg = function()
    while true do
        local ok,resp,close_reason = pcall(websocket.read,ws_id)
        if not ok then
            ws_id = nil
            -- skynet.fork(reconnect)
            skynet.error("连接已断开")
            return
        end
        -- local resp, close_reason = websocket.read(ws_id)
        -- print("read",ok,resp,close_reason,#resp)
        local  name,args = dispatch(resp)
        if name ~= "heartbeat" then
            print("deal_msg",#resp,name)
            dump(args)
        end
        local f = cmd[name]
        if not f then
            skynet.error("找不到接口",name)
        else
            local ok,error = pcall(f,args)
            if not ok then
                skynet.error(error)
            end
        end
    end
end


function cmd:heartbeat()
    -- skynet.error("当前服务器时间：",self.time)
end
local my_info = {}
function cmd:baseinfo()
    skynet.error("baseinfo:",cjson.encode(self))
    my_info = self
end
function cmd:enter_room()
    self = self or {error = 0}
    skynet.error("enter_room:",self.error)
    skynet.error("进入房间")
end
--
function cmd:add_player()
    skynet.error("有玩家进入房间:",self.player.pid)
    if self.player.pid == my_info.pid then
        skynet.error("我的座位号",self.player.chair)
        my_info.roominfo = self.player
    end
end
function cmd:ready_start_game()
    skynet.error("游戏马上开始，还有:",self.start_time - os.time(),"秒")
end

function cmd:start_game()
    skynet.error("游戏正式开始",self.room_data.current_player_index,my_info.roominfo.chair)
    if self.room_data.current_player_index == my_info.roominfo.chair then
        skynet.error("该我第一次操作---------------------------")
        skynet.timeout(100,function ()
            skynet.error("我选择跟牌",self.follow_amount)
            send2server("op_action",{op=OP_FOLLOW,opdata=self.follow_amount})
        end)
    end
    for i,v in pairs(self.room_data.players) do
        skynet.error("是否自己：",v.pid==my_info.pid,"pid:",v.pid,"本回合下注：",v.turn_bet_amount)
    end
end

function cmd:deal_action()
    local isme = self.current_player_index == my_info.roominfo.chair
    skynet.error("现在该:",isme and "我自己操作" or "其他人","操作，等待时间:",self.time_out,"秒")
    print(self)
    if isme then
        if self.follow_amount == 0 then
            skynet.error("可以过牌")
            skynet.timeout(100,function ()
                skynet.error("我选择过牌",self.follow_amount)
                send2server("op_action",{op=OP_PASS})
            end)
        else
            skynet.timeout(100,function ()
                skynet.error("我选择跟牌",self.follow_amount)
                send2server("op_action",{op=OP_FOLLOW,opdata=self.follow_amount})
            end)
        end
        
    end
end

function cmd:broadcost_op_action()
    local strstruct = {
        [OP_GIVE_UP] = "弃牌",
        [OP_PASS] = "过牌",
        [OP_FOLLOW] = "跟注",
        [OP_BET] = "下注",
    }
    skynet.error("广播操作:",self.chair ,"操作:",self.op.op)
end

function cmd:op_action()
    self = self or {error=0}
    skynet.error("操作返回",self.error)
end

function cmd:Room_info()
    skynet.error("更新房间信息")
end

skynet.start(function()

    --协议共享
    skynet.name(".pb_share", skynet.newservice("protobuf3/pb_share"))

    skynet.name(".pb_mgr",skynet.newservice("protobuf3/pb_mgr"))

   
    ws_id = websocket.connect(url,header)
    -- skynet.fork(reconnect)
    -- local data = {
    --     uid = "userid"
    -- }
    -- local bin_data = skynet.call(".pb_mgr","lua","pack_message","testcmd",data,1,"c2s_")


    -- skynet.error("构造包大小：",#bin_data)
    -- local  name, session,args = skynet.call(".pb_mgr","lua","dispatch",bin_data,#bin_data,"c2s_",true)

    -- skynet.error("收到协议",name, session,args)


    -- print("发送包大小:",#bin_data)
    -- websocket.write(ws_id, bin_data)

    -- local resp, close_reason = websocket.read(ws_id)
    -- -- print("收到包大小:",#resp)
    -- local  name, session,args = skynet.call(".pb_mgr","lua","dispatch",resp,#resp,"s2c_")
    -- skynet.error("收到协议",name, session,args)
    -- print("收到服务器消息：",args.ret)
    skynet.fork(heart_beat)
    skynet.fork(deal_msg)
    skynet.fork(function ()
        skynet.sleep(200)
        send2server("enter_room",{room_level = 1})
    end)
    
end)
