-- room.lua (房间服务)

local skynet = require "skynet"
local room_data = require "game/room_data"
local queue = require "skynet.queue"
local timer = require "timer"

math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

-- 房间服务入口函数
local function start()
    local lock = queue()
    timer.set_lock(lock)
    skynet.dispatch("lua", function(session, source, cmd, ...)
        -- local func = room_data[cmd]
        local args = {...}
        lock(function ()
            table.insert(room_data.cmdList,{cmd = cmd,time = os.date("%H:%M:%S"),args = args})
            room_data:AutoDissolve(cmd)--卡死自动解散
            skynet.retpack(room_data:handleMessage(cmd, table.unpack(args)))
        end)
    end)
end

-- 初始化房间并启动房间服务
skynet.start(function()
    -- 初始化房间数据
    -- room.players = {
    --     { name = "Player 1", chips = 1000 },
    --     { name = "Player 2", chips = 1000 },
    --     { name = "Player 3", chips = 1000 },
    -- }
    -- room.currentPlayerIndex = 1
    -- room.currentState = "PREFLOP"

    -- 启动房间服务
    start()
end)