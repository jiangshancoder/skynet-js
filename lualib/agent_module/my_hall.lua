local my_hall = {}
local skynet = require "skynet"
local my_data = require "agent_module.my_data"
local coll = require "mongo.mongo_collections"

local request = {}
local cmd = {}

function request:get_room_detail()
    local player_count = {}
    local room_level = {}
    for i=1,4 do
        table.insert(player_count,math.random(100))
        table.insert(room_level,i)
    end
    return {player_count = player_count,room_level = room_level}
end


function request:gm_cmd()
    local key = self.prop_name
    local value = self.prop_value
    if my_data.db_info[key] then
        if type(my_data.db_info[key]) == "number" then
            value = tonumber(value)
        end
        my_data.db_info[key] = value
        skynet.call(get_db_mgr(), "lua", "update",coll.USER,{pid=my_data.pid},{[key] = value})
    end
    return {prop_name=key,prop_value = tostring(my_data.db_info[key])}
end
function my_hall.init(REQUEST,CMD)
    if request then
        table.merge(REQUEST,request)
    end
    if cmd then
        table.merge(CMD,cmd)
    end

end

return my_hall