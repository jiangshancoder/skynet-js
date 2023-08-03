local skynet = require 'skynet'


local CMD = {}
local online_agent = {}
local online_num = 0

--登录
function CMD.login(agent,userid)
    online_agent[agent] = true
    online_num = online_num + 1
    skynet.error("玩家上线，当前在线人数",online_num)
end

--登出
function CMD.logout(agent,userid)
    online_agent[agent] = nil
    online_num = online_num - 1
    skynet.error("玩家离线，当前在线人数",online_num)
end



skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    -- CMD.init();
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command],command)

        if session == 0 then
            f(source,...)
        else
            skynet.ret(skynet.pack(f(source, ...)))
        end

    end)
end)
