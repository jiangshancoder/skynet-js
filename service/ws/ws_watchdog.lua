local skynet = require "skynet"

local CMD = {}
local SOCKET = {}
local master_gate
local agent = {}--实时
local usermap = {}--玩家id对应agent，如果agent还在就断线重连
local protocol
local fd2gate = {}
local fd2userid = {}

function SOCKET.open(fd, addr, gate,userinfo)
    skynet.error("New client from : " .. addr)
    fd2gate[fd] = gate
    fd2userid[fd] = userinfo.pid
    if usermap[userinfo.pid] then--断线重连
        agent[fd] = usermap[userinfo.pid]
        skynet.call(agent[fd], "lua", "reconnect", {
            gate = gate,
            client = fd,
            watchdog = skynet.self(),
            protocol = protocol,
            addr = addr,
        })
    else--新登录
        usermap[userinfo.pid] = skynet.call(".gen_agent_" .. math.random(skynet.getenv("gen_agent_num")),"lua","get_a_agent")
        skynet.error("创建agent",usermap[userinfo.pid])
        agent[fd] = usermap[userinfo.pid]
        skynet.call(agent[fd], "lua", "start", {
            gate = gate,
            client = fd,
            watchdog = skynet.self(),
            protocol = protocol,
            addr = addr,
            userinfo = userinfo,
        })
    end
    
end

local function close_agent(fd)
    local a = agent[fd]
    agent[fd] = nil
    if a then
        local gate = fd2gate[fd]
        if gate then
            skynet.call(gate, "lua", "kick", fd)
            fd2gate[fd] = nil
        end
        -- disconnect never return
        skynet.send(a, "lua", "disconnect")
    end
    local userid = fd2userid[fd]
    if usermap[userid] then
        usermap[userid] = nil
    end
end

function SOCKET.close(fd)
    print("socket close",fd)
    close_agent(fd)
end

function SOCKET.error(fd, msg)
    print("socket error",fd, msg)
    close_agent(fd)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    print("socket warning", fd, size)
end

function SOCKET.data(fd, msg)
    print("socket data", fd, msg)
end

function CMD.start(conf)
    protocol = conf.protocol
    skynet.call(master_gate, "lua", "open" , conf)
end

function CMD.close(fd)
    close_agent(fd)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
            -- socket api don't need return
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)

    master_gate = skynet.newservice("ws/ws_gate")
end)

