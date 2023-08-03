local skynet = require "skynet"
require "skynet.manager"
local snowflake = require "snowflake"
local coll = require "mongo.mongo_collections"
local cjson = require "cjson"

local CMD = {}

local channel = {}

local new_player = {
    nickname = "nickname",
    pid = "",
    account = "",
    password = "",
    recharge = 0,
    ip = "",
    last_time = 0,--上次登录时间
    login_time = 1,--登录次数
    country = "",--国家
    headurl = "",--用户头像
    chips = 50000,--账号余额
}
local function get_dbinfo(account,ip)
    local u = skynet.call(get_db_mgr(), "lua", "get_player_dbinfo", account, ip,true)
    return u
end
function channel.test(args)
    if not args.account or not args.password then
        skynet.error("登录失败，需要填写账号密码")
        return false
    end
    local info = get_dbinfo(args.account,args.ip)
    if info and info.password ~= args.password then
        return false
    end
    if info then--已创建账号
        skynet.error("老号登录")
    else--新号
        local pid = snowflake.snowflake()
        new_player.pid = pid
        new_player.ip = args.ip
        new_player.account = args.account
        new_player.password = args.password
        new_player.last_time = os.time()
        skynet.call(get_db_mgr(),"lua","insert",coll.USER,new_player)
        info = new_player
        skynet.error("新号登录")
    end
    
    return true,info.pid
end

function CMD.auth(source,args,ip)
    skynet.error("auth",source,cjson.encode(args))
    args.channel = args.channel or "test"
    if not args.channel then
        return false
    end
    local f = channel[args.channel]
    local ok,loginok,pid = pcall(f,args)
    if not ok then
        skynet.error("auth失败",loginok)
        return false
    end
    if not loginok then
        skynet.error("验证失败")
        return false
    end
    
    return loginok,pid
end


skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if not f then
            skynet.error("login can't dispatch cmd ".. (cmd or nil))
            skynet.ret(skynet.pack({ok=false}))
            return
        end
        if session == 0 then
            f(source, ...)
        else
            skynet.ret(skynet.pack(f(source, ...)))
        end
    end)
end)
