---protobuf模块

--一个完整的protobuf包格式如下
-- -----------------
-- |len|header|body|
-- -----------------
-- len为2字节大端,表示header的长度
-- header是消息头,是一个protobuf消息,一般包含消息ID,会话ID等数据
-- body是消息体,是一个protobuf消息(消息ID在header中指定)

--[[
    message Package {
        int32 type = 1;         // 消息类型ID
        int32 session = 2;  // rpc会话ID,无需对方回复时可以发0,否则,保证唯一
        bool req = 3;   // true--请求,false--回复
}

--]]

local pb = require "pb"
local protoc = require "protoc"

local protobuf = setmetatable({},{__index=pb})

function protobuf.new(conf)
    local pbfiles = assert(conf.pbfiles)
    local self = {
        pbfiles = pbfiles,
        packagename = "gameProtos.",
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

local function gen_response(self,message_name,header)
    return function(args,ud)
        header_tmp.type = message_name--header.type + 1
        header_tmp.session = header.session
        header_tmp.ud = ud
        header_tmp.req = false
        local MessageHeader = self.MessageHeader
        header = protobuf.encode(MessageHeader,header_tmp)
        
        if args then
              message_name = "s2c_" .. message_name

            local res,content = pcall(protobuf.encode,self.packagename..message_name,args)
            assert(res,message_name .. " encode error in protobuf!" .. content)
            return string.pack(">s2",header) .. content
        else
            return string.pack(">s2",header)
        end
    end
end

function protobuf:dispatch(msg)

    local MessageHeader = self.MessageHeader
    local header_bin,size = string.unpack(">s2",msg)
    local header,err = protobuf.decode(MessageHeader,header_bin)
    assert(err == nil,err)

    local c2s_msg_name = "c2s_" .. header.type
    local args
    if #msg >= size then
        local args_bin = string.sub(msg,size,#msg)
        args,err = protobuf.decode(self.packagename .. c2s_msg_name,args_bin)
        assert(err == nil,err)
    end
    if header.req then
        local response
        return "REQUEST", header.type, args, response, header.ud
    else
        return "RESPONSE", header.session, args, header.ud
    end
end

function protobuf:pack_message(name,args,session,ud)
    return self:pack_request(name,args,session,ud)
end

function protobuf:pack_request(message_name,request,session,ud)
    if session == 0 then
        session = nil
    end
    header_tmp.type = message_name--message_id
    header_tmp.session = session
    header_tmp.ud = ud
    header_tmp.req = true
    message_name = "s2c_" .. message_name
    local MessageHeader = self.MessageHeader

    local header = protobuf.encode(MessageHeader,header_tmp)
    if request then
        local body = protobuf.encode(self.packagename .. message_name,request)
        return string.pack(">s2",header) .. body
    else
        return string.pack(">s2",header)
    end
end

function protobuf:proto_exit(message_name)
    message_name = "s2c_" .. message_name
    local name = protobuf.type(self.packagename .. message_name)
    return nil ~= name
end

return protobuf
