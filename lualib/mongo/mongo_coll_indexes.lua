local COLL = require "mongo.mongo_collections"


-- dbpoolname  db_mgr中存储 数据库链接 池名
	-- POOL 游戏数据
	-- POOL_REC 记录数据
-- indexes 	   索引 -- hashed 现只支持单索引,不支持复合索引
				   -- 复合索引 等于类型在前,排序类型在后,范围类型最后
	-- 例
		-- 单索引
		-- indexes = {{{id = "hashed"},{{time = -1}}}
		-- 复合索引
		-- indexes = {{{id = 1},{time = -1}}}
-- split   -- 分表模式,已年月份拆开
local INDEXES = {
	[COLL.USER] = { dbpoolname = "POOL",indexes = {{{uid = "hashed"}},{{pid = "hashed"}},{{account = "hashed"}},{{unionid = "hashed"}},{{reg_time = -1}},{{last_time = 1}}}},
}

return INDEXES