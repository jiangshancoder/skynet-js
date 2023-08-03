local my_room = {}
local skynet = require "skynet"
local my_data = require "agent_module.my_data"

local request = {}
local cmd = {}


--下注等操作(弃牌，过牌，跟注，加注等操作)
function request:op_action()
    skynet.error("请求下注",self,my_data.room_addr)
    if my_data.room_addr then
        skynet.send(my_data.room_addr,"lua","req_op_action",my_data.pid,self)
    end
end

function request:chat()
    if my_data.room_addr then
        skynet.send(my_data.room_addr,"lua","req_chat",self.content)
    end
end


--房间内发过来的消息
function cmd.push_msg(name,args)
    -- print(name)
    -- print(args)
    --可能针对单个消息有特殊处理
    my_data.send_push(name,args)
end

function my_room.init(REQUEST,CMD)
    if request then
        table.merge(REQUEST,request)
    end
    if cmd then
        table.merge(CMD,cmd)
    end
end

return my_room