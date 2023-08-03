--matching_mgr
--匹配服务
local skynet = require "skynet"
-- local clusterdatacenter = require "clusterdatacenter"
local skynet_queue = require "skynet.queue"
local robot_info = require 'cfg.cfg_robot'
local COLL = require "config/collections"
local timer = require "timer"
require "pub_util"
require "table_util"
require 'define'
local datacenter = require "skynet.datacenter"
local mc = require "skynet.multicast"
-- local patterns  = require "patterns"

local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

ServerData.cfg_place_config = require "cfg/cfg_place_config"
ServerData.fm_players = {}
ServerData.join_players = {} -- 正在加入房間中的玩家
ServerData.interval = 1 -- 模糊匹配检查间隔
ServerData.clear_interval = 10  -- 清除 【正在加入房間中的玩家】 记录
ServerData.match_invoke = nil -- 模糊匹配调度器
ServerData.clear_invoke  = nil -- 清楚 【正在加入房間中的玩家】 记录 定时器
ServerData.reset_room_count_invoke  = nil -- 重置真人数量  定时器
ServerData.timeout = 200 -- 匹配超时,直接加入机器人
ServerData.blacklist = {}
ServerData.make_card_users = {}
local robot_pInfos = {}

local game_type_config  = {
	[1] = {
		[1] = {
			max_player_count = 6,
		},
	}
}
--获取房间配置 101 102 103 104
function CMD.get_roomconf(gameType)
	local gameId = gameType // 100
	local placeId = gameType % 100
	return game_type_config[gameId][placeId],gameId,placeId
end

local function get_timeout(game_type)
	local placeId = game_type % 100
	return match_conf.match_timeout[placeId]
end

--初始化离线10天以上玩家的数据表
function CMD.init_robot_pInfo()
	local selector = {last_time={['$lte']=(os.time()-ONE_DAY*10)},
	-- ['playinfo.total']={['$gte']=300},
	['reg_time']={['$lte']=1665578210}}
	local env = skynet.getenv("env")
	-- if env ~= "publish" and env ~= "debug" then 
	-- 	selector = {}
	-- end
	local temp_players = skynet.call(get_db_mgr(),'lua','find_all',COLL.USER,selector,
		{_id = false,id=true,nickname=true,headimgurl=true,ip=true,hall_frame=true,sex=true,
		headframe=true,half_photo=true,playinfo=true},{{last_time = -1}},2000)
	for _,p_info in ipairs(temp_players) do
		local randInfo = robot_info[math.random(#robot_info)]
		local onePInfo = {
							id 				= p_info.id,
							nickname		= p_info.nickname,
							headimgurl		= p_info.headimgurl,
							ip 				= p_info.ip,
							hall_frame  	= p_info.headframe or 300001,
							sex 			= randInfo.sex or 1,
							half_photo 		= p_info.half_photo,
							human_drees 	= randInfo.human_drees,
							pet_info 		= randInfo.pet_info,
							prestige 		= p_info.prestige or 0,
							seg_prestige 	= p_info.seg_prestige or 1000,
							win_gamec       = math.random(50,200),--p_info.playinfo.winc or 0,
							play_gamec      = math.random(300,500),--p_info.playinfo.total or 0,
						}
		table.insert(robot_pInfos,onePInfo)
	end
end
--初始化各配置table
function CMD.init_place_tbl()

	ServerData.search_order = {
		{101,102,103,104}
	}
end


function CMD.GetRandomIndex(lastIndexs,isMark)
	local maxIndex = 100
	if isMark and #robot_pInfos > 1 then
		maxIndex = #robot_pInfos
	end
	local index = math.random(1,maxIndex)

	local checkExist = function(idx,lastidxs)
		for _,v in ipairs(lastidxs) do
			if v == idx then
				return true
			end
		end
	end
	while checkExist(index,lastIndexs) do
		index = math.random(1,maxIndex)
	end
	return index
end


function CMD.GetRandomRoBotInfo(count,gameType,players)
	local lastIndexs = {}
	local randIndex
	local infos = {}
	local tempInfo = robot_info
	local isMark =  true
	local placeid = gameType % 100
	local gameid = math.floor(gameType / 100)
	local conf = ServerData.cfg_place_config[gameid][placeid]
	conf.real_user_info_rate = 100 -- conf.real_user_info_rate or 0
	local randnum = math.random(100)

	local has_user = function(tbl,pid)
		for k, v in pairs(tbl) do
			if v.id == pid then
				return k
			end
		end
	end

	--删除robot中上线的真人数据
	if players and #players > 0 then
		for _,v in pairs(players) do
			local k = has_user(robot_pInfos,v.id)
			if k then
				print("ai列表中真人上线,id=",v.id)
				table.remove(robot_pInfos,k)
	
			end

			local robot = has_user(tempInfo,v.id)
			if robot then
				print("ai匹配,重复机器人,id=",v.id)
				table.insert(lastIndexs,robot)
	
			end
		end
	end
	

	local use_real_user_info = isMark and #robot_pInfos > count and randnum <= conf.real_user_info_rate
	if use_real_user_info then
		tempInfo = robot_pInfos
	end
	for i=1,count do
		randIndex = CMD.GetRandomIndex(lastIndexs,use_real_user_info)
		--print('==============加入等值===',randIndex)
		table.insert(lastIndexs,randIndex)
		table.insert(infos,tempInfo[randIndex])
	end
	return infos
end

local function get_max_gold(players)
	local gold
	for _, p in ipairs(players) do
		if gold then
			gold = gold < p.dbinfo.gold and p.dbinfo.gold or gold
		else
			gold = p.dbinfo.gold
		end
	end
	return gold
end
local function reset_room_type(players)
	for _, p in ipairs(players) do
		if p.zuobi_type and p.zuobi_type>1 then
			return 4
		end
	end
	return 0
end

local function get_recharge_info(players)
	local info  = {}
	for _, p in ipairs(players) do
		info[p.id] = p.dbinfo.all_fee or 0
	end
	return info
end

local function get_info(players)
	local info  = {}
	local total = {}
	for _, p in ipairs(players) do
		total[p.id] = p.dbinfo.isNew or 0
	end
	info.total = total
	return info
end


function CMD.create_room(players,gameType,AI_type,args)
	local humans = table.clone(players)
	local room_type = reset_room_type(players)
	args = args or {}--默认普通模式
	if not args.room_type then
		args.room_type = room_type
	end
	skynet.fork(function ()
		local pack = CMD.get_roomconf(gameType)

		local conf = {
			playerCount = pack.playerCount,
			gameType = gameType,
			cap = pack.cap,
			gang_pay = pack.gang_pay,
			ticket = pack.ticket,
			base_score = pack.base_score,
			gameName = pack.game_name,
			prestige = pack.prestige,
			args = args,
		}
		local diff = pack.playerCount - #players
		if diff>0 then
			AI_type = AI_type or "ai_hzmj_blood"
			local player_max_gold = get_max_gold(players)
			local player_recharge = get_recharge_info(players)
			local player_info = get_info(players)
			
			local robots = CMD.GetRandomRoBotInfo(diff,gameType,players)
			for i=1,diff do
				local ai = skynet.newservice(AI_type)
				-- skynet.error('==============创建AI====',robots[i],gameType,AI_type)
				local result,p = pcall(skynet.call,ai,'lua','init',robots[i],gameType, player_max_gold, humans,args.room_type,player_recharge,player_info)
				if not result then
					print("get ai error")
				end
				table.insert(players,p)
			end
		end
		local _, room_server = skynet.call(".agent_mgr", "lua", "create_room", conf)
		pack = {}
		for _, p in ipairs(players) do
			--print('================玩家信息============')
			table.insert(pack,{
				id = p.id,
				agent = p.agent,
				dbinfo = p.dbinfo,
				address = p.address,
				pet_skills = p.pet_skills,
				prestige = p.prestige,
				pet_info = p.pet_info,
				robot = p.robot,
				buffs = p.buffs,
				zuobi_type = p.zuobi_type,
			})
		end

		skynet.send(room_server,'lua','all_join',pack)
	end)
end


function CMD.remove_player_in_match(id)
	local isRemove = false
	for _,packs in pairs(ServerData.fm_players) do
		for j= #packs,1,-1 do
			if packs[j].id == id then
				table.remove(packs,j)
				isRemove = true
				break
			end
		end
	end

	--移除下做牌玩家
	for conf, players in pairs(ServerData.make_card_users) do
		for pos, p in ipairs(players) do
			if p.id == id then
				table.remove(players, pos)
				isRemove = true
				break
			end
		end
		if #players == 0 and conf and conf.owner_id then
			ServerData.make_card_users[conf.owner_id] = nil
			break
		end
	end
	return isRemove
end

-- 移除玩家在匹配结束
function CMD.remove_in_match_end(players)
	local current_time = os.time()
	for _,p in ipairs(players) do
		if not p.robot then
			local place_ids = p.place_ids
			for _,key in ipairs(place_ids) do
				for j= #ServerData.fm_players[key],1,-1 do
					if ServerData.fm_players[key][j].id == p.id then
						table.remove(ServerData.fm_players[key],j)
						break
					end
				end
			end
		end
		ServerData.join_players[p.id] = current_time
	end
end

--检测是否能加入这个匹配
function CMD.checkMatchMark(packMatchMark,playerMatchMark)
	for _,plMarkId in ipairs(playerMatchMark) do
		for _,packMarkId in ipairs(packMatchMark) do
			if plMarkId == packMarkId then
				return false
			end
		end
	end
	return true
end

function CMD.gen_match_group(p,packs,need_count,noCreate)
	local in_blacklist = CMD.player_in_blacklist(p.id)
	local pack
	local joined = false
	if #packs == 0 and not noCreate then
		pack = {players = {p},have_black = in_blacklist,MatchMarkTbl = {}}
		for _,markId in ipairs(p.dbinfo.matchMark) do
			table.insert(pack.MatchMarkTbl,markId)
		end
		table.insert(packs,pack)
		joined = true
	else
		for j=1,#packs do
			pack = packs[j]
			-- 匹配中没有黑名单玩家,或要加入的玩家不是黑名单玩家;
			if #pack.players < need_count and (not pack.have_black or not in_blacklist)
				and CMD.checkMatchMark(pack.MatchMarkTbl,p.dbinfo.matchMark) then
				table.insert(pack.players,p)
				for _,markId in ipairs(p.dbinfo.matchMark) do
					table.insert(pack.MatchMarkTbl,markId)
				end
				pack.have_black = pack.have_black or in_blacklist
				joined = true
				break
			end
		end

		if not joined and not noCreate then
			pack = {players = {p},have_black = in_blacklist,MatchMarkTbl = {}}
			table.insert(packs,pack)
			joined = true
		end
	end
end

function CMD.process_match()
	for _,key in ipairs(ServerData.search_order) do
		local count = ServerData.fm_players[key] and #ServerData.fm_players[key] or 0
		local roomConf,gameId,placeId = CMD.get_roomconf(key)
		local need_count = roomConf.max_player_count
		-- print(need_count,"本游戏需要真人",key)
		if count > 0 then
			-- 满足游戏需要人数
			if count >= need_count then
				-- 存储游戏中需要数量玩家一组
				local packs = {}
				for i = count,1,-1 do
					local p = ServerData.fm_players[key][i]
					if p then
						p.place_id = key
						CMD.gen_match_group(p,packs,need_count)
					end
				end
				local end_count = 0
				for _,pack in ipairs(packs) do
					if #pack.players >= need_count then
						CMD.create_room(pack.players,key)
						-- 移除创建房间的玩家
						CMD.remove_in_match_end(pack.players)
						end_count = end_count + need_count
					end
				end
				count = count - end_count
			end
			if count > 0 then  -- 如果有玩家超时，则直接匹配机器人
				local packs = {}
				local curr_time = skynet.now()
				for i=count,1,-1 do
					local p = ServerData.fm_players[key][i]
					if p then
						p.place_id = key
						-- 玩家匹配超时
						if curr_time - p.match_time >= get_timeout(key) then
							CMD.gen_match_group(p,packs,need_count)
						end

					end
				end
				if #packs > 0 then -- 有超时的玩家
					for i=count,1,-1 do -- 先添加正常用户
						local p = ServerData.fm_players[key][i]
						p.place_id = key
						if p and curr_time - p.match_time < get_timeout(key) then
							CMD.gen_match_group(p,packs,need_count,true)
						end
					end
					local pCount = 0
					for _,pack in ipairs(packs) do
						if #pack.players >= need_count then
							CMD.create_room(pack.players,key)
							-- 移除创建房间的玩家
							CMD.remove_in_match_end(pack.players)
						elseif pCount and pCount < 20 then
							CMD.create_room(pack.players,key,"ai_hzmj_blood")
							CMD.remove_in_match_end(pack.players)
						end
					end
				end
			end
		end
	end
end

function CMD.create_check_match()
	ServerData.match_invoke = timer.create(100 * ServerData.interval,function()
		CMD.process_match()
	end,-1)
end

function CMD.clear_timeout_joined()
	local current_time = os.time()
	for id,joined_time in pairs(ServerData.join_players) do
		if current_time - joined_time >= ServerData.clear_interval then
			ServerData.join_players[id] = nil
		end
	end
end

function CMD.create_check_timeout_joined()
	ServerData.clear_invoke = timer.create(100 * ServerData.clear_interval,function()
		CMD.clear_timeout_joined()
	end,-1)
end

-- 检查玩家是否已经参与匹配
function CMD.check_in_match(pid)
	for _,players in pairs(ServerData.fm_players) do
		for _,p in ipairs(players) do
			if p.id == pid then
				return true
			end
		end
	end

	for _, players in pairs(ServerData.make_card_users) do
		for _, p in ipairs(players) do
			if p.id == pid then
				return true
			end
		end
	end

	-- 防止玩家匹配完成，加入房间时重入匹配
	local joined_time = ServerData.join_players[pid]
	if joined_time and os.time() - joined_time <= 5 then
		return true
	end

	return false
end

-- 获取玩家可以参与的匹配类型
function CMD.get_match_type(gameId,gold)
	local place_ids = {}
	for i = 5, 1, -1 do
		local gType = gameId * 100 + i
		local limit = CMD.get_roomconf(gType)
		if limit then
			-- 玩家金币大于下限，小于上限
			if gold >= limit.need_min and
				(limit.need_max == 0 or gold <= limit.need_max) then
				table.insert(place_ids,gType)
			end
		end
	end
	if #place_ids == 0 then
		return false
	end

	return place_ids
end



-- 模糊匹配/精准匹配
function CMD.fuzzy_matching(player)
	-- 玩家已经在匹配中
	if CMD.check_in_match(player.id) then
		return false
	end

	local room_type = DEAL_ACTION_MODE.NONE
	local placeId = player.place_id % 100
	--保护且菜鸟场，1个真人配三个机器人
	if  player.zuobi_type==DEAL_ACTION_MODE.LEVEL_1 then
		room_type = DEAL_ACTION_MODE.LEVEL_1
	end
	if  player.zuobi_type>=DEAL_ACTION_MODE.LEVEL_2 then
		room_type = DEAL_ACTION_MODE.LEVEL_4
	end
	skynet.error("加入匹配 join_game",player.place_id,player.zuobi_type,room_type,player.dbinfo.gold)
	if player.dbinfo.isNew == 0 then
		---- 1玩家匹配3个机器人
		print(player.zuobi_type,"1玩家匹配3个机器人")
		skynet.timeout( match_conf.new_player, function()
			local need_ai = "ai_hzmj_blood"
			if player.zuobi_type == DEAL_ACTION_MODE.LEVEL_1 and placeId ==1 then
				need_ai = "ai_hzmj_blood_1"
			end
			CMD.create_room({player},player.place_id,need_ai,{room_type = player.zuobi_type})
		end)
		return
	end
	


	
	local gold = player.dbinfo.gold
	local place_ids

	-- 精准匹配
	if player.place_id then
		place_ids = {player.place_id}
	end
	player.match_time = skynet.now() -- 玩家开始匹配时间
	print("开始匹配",player.id,player.match_time)
	player.place_ids = place_ids
	for _,place_id in ipairs(place_ids) do
		if not ServerData.fm_players[place_id] then
			ServerData.fm_players[place_id] = {}
			ServerData.fm_players[place_id].players = {}
		end

		-- 根据金币数量决定插入顺序
		local is_insert = false
		for i,p in ipairs(ServerData.fm_players[place_id]) do
			if p.dbinfo.gold > gold then
				table.insert(ServerData.fm_players[place_id],i,player)
				is_insert = true
				break
			end
		end
		if not is_insert then
			table.insert(ServerData.fm_players[place_id],player)
		end
	end
end

--玩家退出时 移除匹配
function CMD.userafk(id)
	return CMD.remove_player_in_match(id)
end

--移除匹配队列
function CMD.remove_matching(id)
	return CMD.remove_player_in_match(id)
end



function CMD.init()
	CMD.init_place_tbl()
	CMD.init_config()
	CMD.init_robot_pInfo()
	CMD.create_check_match()
	CMD.create_check_timeout_joined()

end

skynet.start(function()
	skynet.dispatch("lua", function(_, _, command, ...)
		local args = { ... }
		if command == "lua" then
			command = args[1]
			table.remove(args, 1)
		end
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(table.unpack(args))))
	end)
	CMD.init()
end)
