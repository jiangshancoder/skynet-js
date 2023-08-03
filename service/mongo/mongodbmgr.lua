local skynet = require "skynet"
local COLL_INDEXES = require "mongo.mongo_coll_indexes"
local colllection = require "mongo.mongo_collections"
local Mongolib = require "mongo.Mongolib"
local CMD,ServerData = {},{}

-- 设置一个db_mgr 初始化时检测索引
local check_db_index = ...

ServerData.POOL = {} 		-- 处理游戏逻辑的数据库链接(如 用户表)
ServerData.POOL_REC = {}	-- 处理数据记录的数据链接 (如金币消耗记录,道具记录)
ServerData.INDEX = 0
ServerData.INDEX_REC = 0


ServerData.yetIndx = {} -- 已经检测过的索引

-- local func
function CMD.index_inc( )
	ServerData.INDEX = ServerData.INDEX + 1
	if ServerData.INDEX >= #ServerData.POOL + 1 then
		ServerData.INDEX = 1
	end
end

function CMD.index_rec_inc()
	ServerData.INDEX_REC = ServerData.INDEX_REC + 1
	if ServerData.INDEX_REC >= #ServerData.POOL_REC + 1 then
		ServerData.INDEX_REC = 1
	end
end


----------------------------------------------------------------------------
-- mongo 增删查改
----------------------------------------------------------------------------
function CMD.insert(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:insert(...)
end

function CMD.delete(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:delete(...)
end

function CMD.find_one(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_one(...)
end

function CMD.find_all(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_all(...)
end

function CMD.find_all_skip(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_all_skip(...)
end

function CMD.update(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:set_update(...)
end

function CMD.update_insert( ... )
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:update_insert(...)
end

-- 替换(全量更新)
function CMD.replace(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:update(...)
end

function CMD.max(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:get_max(...)
end

function CMD.count(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:get_count(...)
end
function CMD.count_selector(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:get_filtrate_count(...)
end

function CMD.push(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:push(...)
end

function CMD.push_insert(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:push_insert(...)
end

function CMD.sum( ... )
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:sum(...)
end

function CMD.pull(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:pull(...)
end

local pass_db = {

}

-------------------------------------------------------------------
function CMD.load_all(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:load_all(...)
end
-----------------------------------------------------------------------------

function CMD.create_index(db,name,oname)
	if ServerData.yetIndx[name] then
		return
	end
	local coll = COLL_INDEXES[oname]
	db:createIndexes(name,table.unpack(coll.indexes))
	ServerData.yetIndx[name] = true
end

function CMD.get_player_dbinfo(account, ip, on_login)
	CMD.index_inc()
	local tbl_match = {account = account}--, sdk = base.sdk, disabled = {['$ne'] = true}}

	local u = ServerData.POOL[ServerData.INDEX]:find_one(colllection.USER, tbl_match)
	local last_time = u and u.last_time

	if u then
		if on_login then
			u.last_ip = ip
			u.login_time = u.login_time + 1
			ServerData.POOL[ServerData.INDEX]:set_update(colllection.USER, {account = u.account}, {last_ip = ip, login_time = u.login_time})
		else
			u.last_time = os.time()
			ServerData.POOL[ServerData.INDEX]:set_update(colllection.USER, {account = u.account}, {last_time = u.last_time})
		end

	else
		skynet.error("找不到玩家数据",account)
	end
	return u, last_time
end
-- 根据索引表获取 索引名
function CMD.get_index_name(idxs)
	local inxtbl = {}
	for _,inx in ipairs(idxs) do
		local n = ''
		for _,tmp in pairs(inx) do
			for k,v in pairs(tmp) do
				if n == '' then
					n = n .. k .. "_" .. v 
				else
					n = n .. "_" .. k .. "_" .. v
				end
			end
		end
		inxtbl[n] = inx
	end
	return inxtbl
end

-- 检查索引
function CMD.check_indexes()
	skynet.error("start check_indexes now =" .. skynet.time())
	local time = os.date("%Y%m")
	local daytime = os.date("%Y%m%d")
	for name,coll in pairs(COLL_INDEXES) do
		if coll.split then
			name = name.."_"..time
		elseif coll.split_day then
			name = name .. "_" .. daytime
		end
		local db = ServerData[coll.dbpoolname][1]
		local indexes = db:getIndexes(name)

		if not indexes then
			-- 直接创建 全部索引
			db:createIndexes(name,table.unpack(coll.indexes))
			-- print("创建索引",name,table.tostr(coll.indexes))
			local ok = db:getIndexes(name)
			if not ok then
				print("创建索引失败")
			end
		else
			-- print("find Index",name,table.tostr(indexes))
			-- 查找差值 创建索引
			local needIdxs = CMD.get_index_name(coll.indexes)
			local ownIdxs = {}
			for _,inx in ipairs(indexes) do
				if inx.name ~= '_id_' then  -- 该索引为mongo 创建表时默认 索引
					ownIdxs[inx.name] = true
				end
			end
			local addInxs = {}
			for k,v in pairs(needIdxs) do
				if not ownIdxs[k] then
					table.insert(addInxs,v)
				end
			end
			if #addInxs > 0 then
				-- 查看数据长度,大于 一定值后不创建
				local count = CMD.count(name)
				if count < 1000 then
					-- 创建索引
					db:createIndexes(name,table.unpack(addInxs))
					print("创建索引2",name,table.tostr(addInxs))
				else
					skynet.error("error :",name .. "表创建索引失败-数据过大 .. 【" .. count .. "】")
				end
			end
		end

		ServerData.yetIndx[name] = true
	end
	skynet.error("end check_indexes now =" .. skynet.time())
end

-- 同步创建过的索引
function CMD.sync_yet_indexes()
	return ServerData.yetIndx
end


function CMD.init(checkindex, count, dbconfs)
	ServerData.INDEX = 1
	ServerData.INDEX_REC = 1
	local dbcfg = {
		count = skynet.getenv("mongodb_main_count"),
		host = skynet.getenv("mongodb_main_host"),
		port = skynet.getenv("mongodb_main_port"),
		name = skynet.getenv("mongodb_main_name"),
		username= skynet.getenv("mongodb_main_username"),
		password= skynet.getenv("mongodb_main_password"),
		authdb = skynet.getenv("mongodb_main_authdb"),
	}
	
	for i=1,skynet.getenv("mongodb_main_count") do
		local m = Mongolib.new()
	    m:connect(dbcfg)
	    m:use(dbcfg.name)
	    table.insert(ServerData.POOL,m)
	end
	
	dbcfg = {
		count = skynet.getenv("mongodb_log_count"),
		host = skynet.getenv("mongodb_log_host"),
		port = skynet.getenv("mongodb_log_port"),
		name = skynet.getenv("mongodb_log_name"),
		username= skynet.getenv("mongodb_log_username"),
		password= skynet.getenv("mongodb_log_password"),
		authdb = skynet.getenv("mongodb_log_authdb"),
	}
	for i = 1,skynet.getenv("mongodb_log_count") do
		local m = Mongolib.new()
		m:connect(dbcfg)
	    m:use(dbcfg.name)
	    table.insert(ServerData.POOL_REC,m)
	end


	if check_db_index then
		-- skynet.fork(function()
			skynet.error("-----正在检验数据库-----请稍等....")
			CMD.check_indexes() -- 同步索引
			skynet.error("-----检验数据库完毕-----")
		-- end)
	else
		-- 同步创建过的索引记录
		ServerData.yetIndx = skynet.call(".db_mgr","lua","sync_yet_indexes")
	end
	
end

skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(_, _, command, ...)
		local start = skynet.now()
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))

		local time_ms = skynet.now()-start
		if time_ms > 5 then
			local r1,r2,r3 = table.unpack({...})
			print("dbmgr time_wast=",time_ms, ",command=",command, ",param=",table.tostr(r1),table.tostr(r2),table.tostr(r3))
		end
    end)
    CMD.init()
end)