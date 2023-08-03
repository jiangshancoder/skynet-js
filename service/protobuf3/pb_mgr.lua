local skynet = require "skynet"
local sharetable = require "skynet.sharetable"
local CMD = {}
local protoloader = require "proto.protobuf3_helper"
local host

function CMD.init()
    -- print("pb_mgr")
    -- print(sharetable.query("pbprotos"))
    host = protoloader.new({
            pbfiles = sharetable.query("pbprotos"),
        })

end

function CMD.dispatch(msg,sz,prefix)
    return host:dispatch(msg, sz,prefix)
end

function CMD.pack_message(...)
    return host:pack_message(...)
end

function CMD.proto_exit(msg)
    return not host:proto_exit(msg)
end

skynet.start(function()
    CMD.init()
    skynet.dispatch("lua", function(_, _, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)