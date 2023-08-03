local skynet = require "skynet"
local snowflake = require "snowflake"
local CMD = {}
local all_room = {}

function CMD.create_a_room(level)
    local room_id = snowflake.snowflake()--房间唯一ID
    local one_room = {
        room_addr = skynet.newservice("room/room",level),
        num = 0,
        level = level,
        creat_time = os.time(),
        state = 0,--当前房间状态
        players = {},--玩家信息
        room_id = room_id,
    }
    all_room[level][room_id] = one_room
    return room_id
end

function  CMD.get_a_room(level)
    local rooms = all_room[level] or {}
    local choose_room_id = nil
    for room_id,v in pairs(rooms) do
        if v.num <= ROOM_PLAYER_MAX then
            choose_room_id = room_id
            break
        end
    end
    if not choose_room_id then
        choose_room_id = CMD.create_a_room(level)
    end
    return choose_room_id
end

function CMD.enter_room(playerinfo,room_id)
    local level = playerinfo.level
    room_id = room_id or CMD.get_a_room(level)
    local room_info = all_room[level][room_id]
    if not room_info then --进入房间失败    可以考虑新建房间强制进入
        return false
    end
    local room_addr = room_info.room_addr
    local new_info = skynet.call(room_addr,"lua","enter_room",playerinfo)
    --同步房间数据
    room_info.num = new_info.num
    room_info.state = new_info.state
    room_info.players = new_info.players
    -- return {level = level,room_addr=room_addr}
    --这里不用给agent同步，在房间服务同步数据即可
end

--每个房间等级默认创建一个房间
local function pre_load()
    for level = 1, ROOM_LEVEL_MAX do -- 4个房间等级 --
        all_room[level] = {}
        CMD.create_a_room(level)
    end
end

skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(session, source, command, ...)
        local args = { ... }
        if command == "lua" then
            command = args[1]
            table.remove(args, 1)
        end
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(table.unpack(args))))
    end)
    pre_load()
end)





