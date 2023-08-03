-- lua libs
-- add_includedirs("skynet/3rd/lua")
rule("lualib_flags")
	on_config(function (target)
		if is_plat("macosx") then
			target:add("shflags", "-dynamiclib", "-undefined dynamic_lookup")
		end
		target:add("includedirs", "skynet/3rd/lua")
	end)
rule_end()


target("cjson")
    set_kind("shared")
    add_rules("lualib_flags")
	set_filename("cjson.so")
    add_includedirs("3rd/lua-cjson")
    set_targetdir("luaclib")
	add_files("3rd/lua-cjson/lua_cjson.c",
		"3rd/lua-cjson/fpconv.c",
		"3rd/lua-cjson/strbuf.c")
target_end()

target("lfs")
    set_kind("shared")
    add_rules("lualib_flags")
    set_filename("lfs.so")
    add_includedirs("3rd/lua-lfs") --包含目录
    add_files("3rd/lua-lfs/src/lfs.c")
    set_targetdir("luaclib")
    set_prefixname("") --去除默认加的前缀
target_end()


target("openssl")
    set_kind("shared") --生成so目标
    set_filename("openssl.so")
    add_rules("lualib_flags")
    add_includedirs("3rd/lua-openssl") --包含目录
    add_includedirs("3rd/lua-openssl/deps") --包含目录
    add_includedirs("3rd/lua-openssl/deps/auxiliar") --包含目录
    add_files("3rd/lua-openssl/src/*.c") --包含所有c文件
    add_files("3rd/lua-openssl/deps/auxiliar/*.c") --包含所有c文件
    set_targetdir("luaclib") --生成so到指定目录里
    set_prefixname("") --去除默认加的前缀
target_end()

target("pb")
    set_kind("shared")
    add_rules("lualib_flags")
    set_filename("pb.so")
    add_files("3rd/lua-protobuf/*.c") --
    set_targetdir("luaclib")
    set_prefixname("") --去除默认加的前缀
target_end()

target("snapshot")
    set_kind("shared")
    add_rules("lualib_flags")
    set_filename("snapshot.so")
    add_includedirs("3rd/lua-snapshot") --包含目录
    add_files("3rd/lua-snapshot/snapshot.c")
    set_targetdir("luaclib")
    set_prefixname("") --去除默认加的前缀
target_end()


target("skiplist")
    set_kind("shared")
    add_rules("lualib_flags")
    set_filename("skiplist.so")
    add_includedirs("3rd/lua-zset") --包含目录
    add_files("3rd/lua-zset/lua-skiplist.c")
    add_files("3rd/lua-zset/skiplist.c")
    set_targetdir("luaclib")
    set_prefixname("") --去除默认加的前缀
target_end()


target("cfadmin_crypt")
    set_kind("shared")
    add_rules("lualib_flags")
    set_filename("cfadmin_crypt.so")
    add_includedirs("3rd/lua-crypt") --包含目录
    add_files("3rd/lua-crypt/*.c")
    set_targetdir("luaclib")
    set_prefixname("") --去除默认加的前缀
target_end()

target("ecs")
	set_kind("shared")
    set_filename("ecs.so")
    add_rules("lualib_flags")
    add_includedirs("3rd/luaecs")
    set_targetdir("luaclib")
	add_files("3rd/luaecs/luaecs.c",
		"3rd/luaecs/ecs_group.c",
		"3rd/luaecs/ecs_persistence.c",
		"3rd/luaecs/ecs_template.c",
		"3rd/luaecs/ecs_capi.c",
		"3rd/luaecs/ecs_entityid.c")
target_end()

target("yyjson")
    set_kind("shared")
    add_rules("lualib_flags")
	set_filename("yyjson.so")
    add_includedirs("3rd/lua-yyjson")
    set_targetdir("luaclib")
    add_files("3rd/lua-yyjson/yyjson/yyjson.c")
target_end()