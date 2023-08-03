---protobuf模块

--一个完整的protobuf包格式如下
-- -----------------
-- |len|header|body|
-- -----------------
-- len为2字节大端,表示header的长度
-- header是消息头,是一个protobuf消息,里面包含body长度，session，cmd等等
-- body是消息体,是一个protobuf消息(消息ID在header中指定)

--[[

	message Package{
		string type = 1; //消息名 
		int32 msg_len = 2; //真实消息包长度
		int32 session = 3; //每条消息唯一
	}

--]]

local pb = require "pb"
local protoc = require "proto.protoc"

local protobuf = setmetatable({},{__index=pb})

function protobuf.new(conf)
    local pbfiles = assert(conf.pbfiles)
    local self = {
        pbfiles = pbfiles,
        packagename = "GameProto.",
    }
    self.MessageHeader = conf.MessageHeader or self.packagename .. "Package"
    setmetatable(self,{__index=protobuf})
    self:load()
    return self
end

function protobuf:load()
    for _,v in ipairs(self.pbfiles) do
        protoc:load(v)
    end
end

local header_tmp = {}


function protobuf:dispatch(msg,sz,prefix)
	if not prefix then
		prefix = "c2s_"
	end

    local MessageHeader = self.MessageHeader
    local header_bin,size = string.unpack(">s2",msg)
    local header,err = protobuf.decode(MessageHeader,header_bin)
    assert(err == nil,err)

    local c2s_msg_name = prefix .. header.type
    local args
    if #msg >= size then
        local args_bin = string.sub(msg,size,#msg)
        args,err = protobuf.decode(self.packagename .. c2s_msg_name,args_bin)
        assert(err == nil,err)
    end
	return header.type, header.session,args
end

function protobuf:pack_message(cmd,data,session,prefix)
    return self:pack_request(cmd,data,session,prefix)
end

function protobuf:pack_request(cmd,data,session,prefix)
	if not prefix then
		prefix = "s2c_"
	end
    if session == 0 then
        session = nil
    end
    local complete_cmd = prefix .. cmd
	data = data or {}
	local body = protobuf.encode(self.packagename .. complete_cmd,data)
    header_tmp.type = cmd--message_id
    header_tmp.session = session
    header_tmp.msg_len = #body
    cmd = prefix .. cmd
	
    local MessageHeader = self.MessageHeader
    local header = protobuf.encode(MessageHeader,header_tmp)
	return string.pack(">s2",header) .. body
end

function protobuf:proto_exit(message_name)
    message_name = "s2c_" .. message_name
    local name = protobuf.type(self.packagename .. message_name)
    return nil ~= name
end

return protobuf
