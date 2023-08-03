
local skynet = require "skynet"
local codecache = require "skynet.codecache"
local CMD = {}


local protos = {
	"hall.proto",				--公共结构等
	"game.proto",				--
}

local function initpbs()
	local pbs = ""
	-- 加载协议
	local path = "./proto/protobuf3/"
	for _,name in ipairs(protos) do
		local f = assert(io.open(path .. name , "rb"))
		local buffer = f:read "*a"
		pbs = pbs .. buffer
		f:close()
		print("加载协议文件",path .. name)
	end
	return { pbs }--, pbids, pbmaps
end


local function load_pbproto()
    local sharetable = require "skynet.sharetable"
    local pbprotos, pbids, pbmaps = initpbs()
    sharetable.loadtable("pbprotos",pbprotos)
    -- sharetable.loadtable("pbids",pbids)
    -- sharetable.loadtable("pbmaps",pbmaps)
end

local function load_sproto()
    -- local sprotoloader = require "sprotoloader"
    -- local proto = (require "xycard_proto")("./")
    -- sprotoloader.save(proto.c2s, 1)
    -- sprotoloader.save(proto.s2c, 2)
end

function CMD.reload()
    skynet.error("reload proto ...............")
    load_sproto()
    load_pbproto()
    skynet.send(".agent_mgr", "lua", "notice2agent", "reload_proto")
end

function CMD.init()
    load_pbproto()
    load_sproto()
    print("init xy_protoloader finish")
end

skynet.start(function()
    codecache.mode("OFF")
    CMD.init()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)