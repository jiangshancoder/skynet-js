local skynet = require "skynet"
local Player = require "game.player_data"
local timer = require "timer"
local cjson = require "cjson"
local card_util = require "game.texas_card.card_util"
local texas_card_helper = require "game.texas_card.texas_card_helper"

-- 定义房间结构
local room = {
    state = ROOM_STATE_WAIT, -- 房间状态
    public_cards = {}, -- 系统五张牌--客户端展示用
    pre_public_cards = {}, -- 预设的五张牌
    prize_pool = 0, -- 当前奖池
    num = 0, -- 当前人数 
    players = {}, -- 存放玩家列表
    cmdList = {}, -- 操作命令列表
    start_time = 0, -- 本轮开始时间
    banker_chair = 0, -- 本轮庄家序号
    banker = 0, -- 本轮庄家
    current_player_chair = 0, -- 当前操作序号
    room_level = 1, -- 房间等级

    join_game_player_chair = {}, -- 本轮游戏玩家下标,最后一个为庄家

    -- 每回合需要清除的字段
    last_player_turn_bet_all = 0, -- 上个玩家本轮下注总金额
    add_bet_amount = 0, -- 加注金额 只有加注，并非加注后的总下注
    first_add_bet_player_idx = 0, -- 首次加注的玩家序号
    turn_bet_end = true, -- 本回合下注是否结束
    turn_now = 1, -- 当前是第几回合
    turn_pass_and_give_up_count = 0, -- 本回合过牌和弃牌人数
    follow_amount = 0 -- 跟注金额-客户端用

}





function room:get_playerByPid(pid)
    for i, v in pairs(self.players) do
        if v.pid == pid then
            return v, i
        end
    end
end
function room:get_playerByChair(chair)
    return self.players[chair]
end
-- 聊天
function room:req_chat(pid, msg)
    local p = self:get_playerByPid(pid)
    if p then
        self:broadcost("player_chat", {
            pid = pid,
            msg = msg
        })
    end
end



-- 广播本房间内所有玩家
function room:broadcost(cmd, ...)
    for i, v in pairs(self.players) do
        local ok, error = pcall(skynet.send, v.agent, "lua", "push_msg", cmd, ...)
        if not ok then
            skynet.error("广播消息失败", i, v.name, cmd, error)
        end
    end
end
-- excpt_ids = { pid=true}
function room:broadcost_excpt_ids(excpt_ids, cmd, ...)
    for i, v in pairs(self.players) do
        if not excpt_ids[v.pid] then
            local ok, error = pcall(skynet.send, v.agent, "lua", "push_msg", cmd, ...)
            if not ok then
                skynet.error("广播消息失败", i, v.name, cmd, error)
            end
        end
    end
end
-- 广播本房间内所有玩家
function room:send2client(chair, cmd, ...)
    local p = self.players[chair]
    skynet.send(p.agent, "lua", "push_msg", cmd, ...)
end

function room:pack_room_info()
    -- 打包玩家基础信息到房间管理服
    local pack = {
        prize_pool = self.prize_pool,
        banker_chair = self.banker_chair,
        start_time = self.start_time,
        current_player_chair = self.current_player_chair,
        players = self:pack_base_players(),
        state = self.state,
        public_cards = self.public_cards
    }
    return pack
end

function room:pack_base_players(pid)
    -- 打包玩家基础信息到房间管理服
    local pack = {}
    for i, v in pairs(self.players) do
        if not pid or (pid and v.pid == pid) then
            table.insert(pack, {
                agent = v.agent, -- agent地址
                pid = v.pid,
                nickname = v.nickname,
                chips = v.chips, -- 筹码
                hand_cards = v.hand_cards,
                turn_bet_amount = v.turn_bet_amount,
                rate = v.rate,
                state = v.state,
                chair = v.chair
            })
        end
    end
    -- print("pack_base_players",pack)
    return pack
end
------
-- 加入房间
function room:add_player(info)
    skynet.error("room_data add_player", cjson.encode(info))
    local join, real_num = false, 0
    if self.num >= ROOM_PLAYER_MAX then
        join = false
        skynet.error("加入房间失败，该房间人数已满")
        return {
            join = join,
            msg = "player count max"
        }
    end

    local chair = 0
    for i = 1, ROOM_PLAYER_MAX do
        if not self.players[i] then
            chair = i
            break
        end
    end
    if chair == 0 then
        skynet.error("加入房间失败，该房间人数已满------")
        return {
            join = join,
            msg = "player count error----"
        }
    end

    local player = Player:new(info, self, chair)
    self.players[chair] = player
    self.num = self.num + 1


end


-----
-- 处理玩家消息
function room:handleMessage(cmd, ...)
    if room[cmd] then
        local ret = room[cmd](room, ...)
        -- local ok,ret = pcall(room[cmd],room,...)
        -- if not ok then
        --     skynet.error("执行失败",ret)
        -- end
        return ret
    end
end

-- 解散房间
function room:DissolveRoom(errDiss)
    skynet.error("房间应当解散")
end

-- 玩家离线
function room:logout(pid, force_quit)
    -- TODO 保留数据到本局结束
    -- force_quit 为true，清除数据
    local p = self:get_playerByPid(pid)
    if p then
        p.logout = true
        self:del_player(pid)
    end
end

function room:CancelAutoDiss()
    if self.cancelAutoDiss_timer then
        self.cancelAutoDiss_timer()
        self.cancelAutoDiss_timer = nil
    end
end
-- 房间卡死时，自动解散房间
function room:AutoDissolve(cmd)
    -- if cmd and ignoreCmd[cmd] then--忽略的命令
    -- 	return
    -- end

    -- self:CancelAutoDiss()
    -- self.cancelAutoDiss_timer = timer.create(100 * 100,function()--100秒后自动卡死
    -- 	skynet.error("Error: auto dissolve room, room_id = ".. self.room_id .. " game_name = ")
    -- 	-- self:DumpRoom()
    -- 	self:DissolveRoom(true)
    -- end)
end
function room:print()
    if self.num > 0 then
        skynet.error("房间ID:" .. self.room_id .. " 房间人数:" .. self.num)
    end
end
function room:init(conf)
    self.room_id = conf.room_id
    self.room_level = conf.level
    self.state = ROOM_STATE_WAIT
    skynet.fork(function()
        -- 定时打印房间数据
        while true do
            skynet.sleep(1 * 60 * 100)
            self:print()
        end
    end)
end
return room
