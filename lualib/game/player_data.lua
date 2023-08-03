
local skynet = require "skynet"

local Player = {
    room_data = nil,
    chair = 0,--座椅号
    nickname = "",
    chips = 0,--手上现有筹码
    bet_amount_all = 0,--已押注金额
    last_bet_amount = 0,--上次操作押注金额  看有没有用，暂时没清
    turn_bet_amount = 0,--本回合押注金额  每回合清除
    hand_cards = nil,--手牌
    agent = nil,--agent地址
    pid = "",
    -- pre_operation_list = {},--可操作列表
    operation_all = nil,--历史操作列表
    last_op_action = nil,--上次操作
    max_five_cards = nil,--最大的五张牌
    rate = 0,--胜率
    card_type = nil,--牌型
    all_in = nil,--全押
}

function Player:set_hand_cards(_hand_cards)
    self.hand_cards = _hand_cards
end
function Player:new(info,room_data,chair)--座位号
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    --初始化其他属性
    table.merge(obj,info)
    obj.state = PLAYER_STATE_WAIT
    obj.room_data = room_data
    obj.chair = chair
    obj.hand_cards = {}
    obj.last_op_action = {}
    obj.max_five_cards = {}
    obj.operation_all = {}
    return obj
    
end

function Player:add_oerration(op)
    table.insert(self.operation_all,op)
end

function Player:set_rate(_rate)
    print("玩家胜率",self.pid,_rate,type(_rate),math.tointeger(_rate))
    self.rate = math.tointeger(_rate)
end

function Player:set_card_type(_card_type)
    self.card_type = _card_type
end
function Player:set_max_five_cards(_max_five_cards)
    self.max_five_cards = _max_five_cards

end

function Player:start_game()
    self.state = PLAYER_STATE_GAMING
end
function Player:end_game()
    self.state = PLAYER_STATE_WAIT
end

--弃牌
function Player:handle_give_up()
    skynet.error("弃牌")
    self.state = PLAYER_STATE_GIVE_UP
    self.last_op_action ={op = OP_GIVE_UP}
end

--过牌
function Player:handle_pass(args)
    skynet.error("过牌")
    self.last_op_action ={op = OP_PASS}
end
--跟注
function Player:handle_follow(args)
    local gold = args
    skynet.error("跟注")
    self.last_op_action ={op = OP_FOLLOW,amount = args.data}
    return true
end
--加注
function Player:handle_bet(args)
    skynet.error("加注")
end
function Player:get_pre_operation_list()
    return self.pre_operation_list
end
--增加操作选项
function Player:add_op(op,opdata)
    opdata = opdata or {}
    for i,v in pairs(self.pre_operation_list) do
        if v.op == op then
            return
        end
    end
    table.insert(self.pre_operation_list,{op=op,data = opdata})
end
--获取默认操作
function Player:get_defualt_op()

    return {op = OP_GIVE_UP}--必须有弃牌
end
--超时自动处理
function Player:bet_defualt(op)
    
end
--重置新一轮下注
function Player:clean_turn_data()
    self.turn_bet_amount = 0
end



return Player
