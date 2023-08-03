local mongo = require "skynet.db.mongo"
local coll_indexs = require "mongo.mongo_coll_indexes"
local _ID_FALSE = {_id = false}

local M = {}

M.__index = M

function M.new()
    local o = {
        db = nil
    }
    setmetatable(o, M)
    return o
end

function M:connect(dbconf)
    self.conn = mongo.client(dbconf)
end

function M:disconnect( )
    self.conn:disconnect()
end

function M:use(db_name)
    self.conn:getDB(db_name)
    self.db = self.conn[db_name]
end

-- 获取表的条数
function M:get_count( coll_name )
    local it = self:find(coll_name,{},{_id = false})
    return it:count()
end

function M:get_filtrate_count(coll_name,selector)
    local it = self:find(coll_name,selector,{_id = false})
    return it:count()
end

function M:get_max( coll_name, key )
    local max = 0
    local it = self:find(coll_name, selector, {_id = false})
    if not it then
        return max
    end

    while it:hasNext() do
        local obj = it:next()
        -- for k,v in pairs(obj) do
        --     print(k,v)
        -- end
        if tonumber(obj[key]) > max then
            max = obj[key]
        end
    end

    return max
end
local skynet = require "skynet"
local _temp_cache_db_index = {}
local function CheckIndex(coll_name,selector,sorter)
    local function check(target)
        if not target then return end
        local check_data = target
        if check_data[1]==nil then
            check_data = {target}
        end
        -- print("DB_CheckIndex",coll_name,table.tostr(check_data))
        if not coll_indexs[coll_name] then
            skynet.error("ERROR-----------------Mongolib_Check Database [" .. coll_name .. "]not exist!!!")
            skynet.error("ERROR-----------------Mongolib_Check Database [" .. coll_name .. "]not exist!!!")
            skynet.error("ERROR-----------------Mongolib_Check Database [" .. coll_name .. "]not exist!!!")
            return
        end
        _temp_cache_db_index[coll_name] = _temp_cache_db_index[coll_name] or {}
        for _,keys in pairs(check_data) do
            local isfind = false
            for key in pairs(keys) do
                if not _temp_cache_db_index[coll_name][key] then
                    -- print("Mongolib_Check",coll_name,key)
                    for _,v in pairs(coll_indexs[coll_name].indexes) do
                        for _,v1 in pairs(v) do
                            if v1[key]~=nil then
                                isfind = true
                                break
                            end
                            -- print("比较",table.tostr(v1),key)
                        end
                        if isfind then
                            break
                        end
                    end
                else
                    isfind = true
                end
                if not isfind then
                    skynet.error("ERROR--------------Mongolib_Check Database_index [" .. coll_name  .. "] index = [" .. key .. "] not exist!!!")
                    skynet.error("ERROR--------------Mongolib_Check Database_index [" .. coll_name  .. "] index = [" .. key .. "] not exist!!!")
                    skynet.error("ERROR--------------Mongolib_Check Database_index [" .. coll_name  .. "] index = [" .. key .. "] not exist!!!")
                    return
                end
                _temp_cache_db_index[coll_name][key] = true 
            end
        end
    end
    
    check({selector})
    check(sorter)
end
function M:load_all(coll_name, selector, fields, sort_conf, page_index, data_per_page)
    CheckIndex(coll_name,selector,sort_conf)
    -- fields = fields or {_id = false}
    if fields then fields._id = false else fields = {_id = false} end

    local t = {}
    local it = self:find(coll_name, selector, fields)
    if not it then
        return t
    end
    local count = it:count()
    sort_conf = sort_conf or {}
    it = it:sort(sort_conf)
    if page_index and data_per_page then
        local skip_count = (page_index - 1)*data_per_page
        it = it:skip(skip_count):limit(data_per_page)
    elseif data_per_page and not page_index then
        it = it:limit(data_per_page)
    end

    while it:hasNext() do
        local obj = it:next()
        table.insert(t, obj)
    end
    return t, count
end

-- function M:sum( coll_name, selector, key )
--     local sum = 0

--     local it = self:find(coll_name, selector)
--     if not it then
--         return 0
--     end

--     while it:hasNext() do
--         local obj = it:next()
--         local value = obj[key]
--         if obj and value then
--             sum = sum + value
--         end
--     end

--     return sum
-- end

-- 查
function M:find(coll_name, selector, fields,limitnum)
    CheckIndex(coll_name,selector)
    if not limitnum then
        return self.db[coll_name]:find(selector, fields)
    else
        return self.db[coll_name]:find(selector,fields):limit(limitnum)
    end
end

function M:find_one(coll_name, cond_tbl, fields)
    CheckIndex(coll_name,cond_tbl)
    return self.db[coll_name]:findOne(cond_tbl, fields)
end



function M:find_all(coll_name, selector, fields, sorter, limit, skip)
    CheckIndex(coll_name,selector,sorter)
    local t = {}
    local it = self.db[coll_name]:find(selector, fields)
    if not it then
        return t
    end
    if sorter then
        if #sorter > 0 then
            it = it:sort(table.unpack(sorter))
        else
            it = it:sort(sorter)
        end
    end

    if limit then
        it:limit(limit)
        if skip then
            it:skip(skip)
        end
    end

    while it:hasNext() do
        local obj = it:next()
        table.insert(t, obj)
    end

    return t
end

function M:find_all_skip(coll_name, selector, fields, sorter, skip)
    CheckIndex(coll_name,selector,sorter)
    local t = {}
    local it = self.db[coll_name]:find(selector, fields)
    if not it then
        return t
    end
    if sorter then
        if #sorter > 0 then
            it = it:sort(table.unpack(sorter))
        else
            it = it:sort(sorter)
        end
    end

    if skip then
        it:skip(skip)
    end

    while it:hasNext() do
        local obj = it:next()
        table.insert(t, obj)
    end

    return t
end

--改
function M:update(coll_name,cond_tbl,update_tbl)
    CheckIndex(coll_name,cond_tbl)
	self.db[coll_name]:update(cond_tbl,update_tbl)
end
-- 修改多条记录
function M:update_multi(coll_name,query_tbl,set_tbl)
    CheckIndex(coll_name,query_tbl)
    set_tbl = {['$set'] = set_tbl}
    self.db[coll_name]:update(query_tbl,set_tbl,false,true)
end


--修改插入
function M:update_insert(coll_name, query_tbl, set_tbl)
    set_tbl = {['$set'] = set_tbl}
    self.db[coll_name]:update(query_tbl,set_tbl,true,false)
end

--推送插入数组
function M:push_insert(coll_name, query_tbl, push_tbl_name, element)
    --print("coll_name")
    --table.print(query_tbl)
    --print(push_tbl_name)
    --table.print(element)
    set_tbl = {['$push'] = {[push_tbl_name] = element}}
    local x = self.db[coll_name]:update(query_tbl,set_tbl,true,false)
    --print(x)
    --table.print(x,type(x))
end

-- collection:findAndModify({query = {name = "userid"}, update = {["$inc"] = {nextid = 1}}, })
function M:set_update( coll_name, query_tbl, set_tbl  )
    local doc = {}
    doc.query = query_tbl
    doc.update = {
        ["$set"] = set_tbl
    }
    return self.db[coll_name]:findAndModify(doc)
end

function M:findAndModify(coll_name, doc )
    self.db[coll_name]:findAndModify(doc)
end

-- 删
function M:delete(coll_name, cond_tbl, ...)
    CheckIndex(coll_name,cond_tbl)
    --print("delete")
    --print(cond_tbl)
    --table.print(cond_tbl)
	self.db[coll_name]:delete(cond_tbl, ...)
end

-- 删多条
function M:delete_many(coll_name, selector)
    CheckIndex(coll_name,selector)
	self.db[coll_name]:delete(selector, false)
end

-- 增
function M:insert(coll_name, obj)
    self.db[coll_name]:insert(obj)
    return obj._id
end

function M:createIndex(coll_name,arg1,arg2)
    self.db[coll_name]:createIndex(arg1,arg2)
end

function M:createIndexes(coll_name,...)
    self.db[coll_name]:createIndexes(...)
end

function M:getIndexes(coll_name)
    return self.db[coll_name]:getIndexes()
end

-- db.order.aggregate(
--     [{$group : {_id : '$p_id',time_end : {$min : '$time_end'}}}, 找出每个人最小的一条订单
--     {$match : {time_end : {$gte : 1547481600}}},                 必修是今天
--     {$group : {_id : 'null',count : {$sum : 1}}}                 求集合的条数
--     ]
--     )

--求数量
function M:ordersum(coll_name,query_tbl,key,value)
    if not key or not coll_name then return 0 end
    local pipeline = {}
 
    table.insert(pipeline,{["$group"] = {_id = '$p_id', [key] = {["$min"] = "$" .. key}}})
    if query_tbl then
        table.insert(pipeline,{["$match"] = query_tbl})
    end

    table.insert(pipeline,{["$group"] = {_id = 'null', ["count"] = {["$sum"] =  value}}})
   
    local result = self.db:runCommand("aggregate",coll_name,"pipeline",pipeline, "cursor", {}, "allowDiskUse",true)

    if result and result.ok == 1 then
        if result.cursor and result.cursor.firstBatch then
            local r = result.cursor.firstBatch[1]
            return r and r.count or 0
        end
    end
    return 0
end

-- 求今日首充人数
-- 


function M:sum(coll_name,query_tbl,key)
    if not key or not coll_name then return 0 end
    local pipeline = {}
    if query_tbl then
        table.insert(pipeline,{["$match"] = query_tbl})
    end

    local step
    if key == nil then
        step = {["$group"] = {_id = false,["count"] = {["$sum"] = 1}}}
    else
        step = {["$group"] = {_id = false,[key] = {["$sum"] = "$" .. key}}}
    end
    key = key or "count"
    table.insert(pipeline,step)
    local result = self.db:runCommand("aggregate", coll_name, "pipeline", pipeline, "cursor", {}, "allowDiskUse", true)

    if result and result.ok and result.ok == 1 then
        if result.cursor and result.cursor.firstBatch then
            local r = result.cursor.firstBatch[1]
            return r and r[key]
        end
    end
    return 0    
end

--
--key 去重的字段名 空则不去重
--sumkey 求和的字段，比如订单总价，不配置返回数据条数
function M:get_order_num(coll_name,query_tbl,sumkey,key)
    if not coll_name then return  end
    if sumkey then
        sumkey = "$" .. sumkey
    else
        sumkey = 1
    end
    local pipeline = {}
    table.insert(pipeline,{["$match"] = query_tbl})
    local step
    if key then
        step = {["$group"] = {
            _id = "$" .. key,
            all = {
                ["$push"] = "$" .. key ,--把pid放到同一组，再统计数量，以达到去重
            }
        }}
        table.insert(pipeline,step)
    end
    step = {["$group"] = {_id = false,["count"] = {["$sum"] = sumkey}}}
    table.insert(pipeline,step)
    local result = self.db:runCommand("aggregate", coll_name, "pipeline", pipeline, "cursor", {}, "allowDiskUse", true)
    if result and result.ok and result.ok == 1 then
        if result.cursor and result.cursor.firstBatch then
            local r = result.cursor.firstBatch[1]
            return r and r.count
        end
    end
    return 0 
end

-- 向某个collection的某条记录里的某个数组插入一个元素
function M:push(coll_name, query_tbl, push_tbl_name, element)
    local doc = {}
    doc.query = query_tbl
    doc.update = {
            ["$push"] = {[push_tbl_name] = element}
        }
    self.db[coll_name]:findAndModify(doc)
end

function M:pull(coll_name, query_tbl, push_tbl_name, element)
    local doc = {}
    doc.query = query_tbl
    doc.update = {
            ["$pull"] = {[push_tbl_name] = element}
        }
    self.db[coll_name]:findAndModify(doc)
end

return M
