local skynet = require "skynet"
require "skynet.manager"


local lfs = require "lfs"


local maxsize = 50 *1024*1024 --文件最大M，超过会分割



local daemon = skynet.getenv("daemon")
local logger = {}



function logger:getDate( ... )
	return os.date("%Y_%m_%d",os.time())
end

function logger:init()
	self.file = nil --文件句柄
	self.server_name = "game"
	self.suffix = ".log" --文件后缀
    self.date = self:getDate()
	self.file_name = self.server_name.."_"..self.date --文件名
	self.path = "logs/"
    self.date_path = self.path .. self.date .."/"
    lfs.mkdir(self.path)
    lfs.mkdir(self.date_path)
end

logger:init()


--打开一个文件， 但不关闭
function logger:checkFile()
    local date = self:getDate()
    if self.date ~= date then 
        self.date = date
        self.date_path = self.path .. self.date .."/"
        lfs.mkdir(self.date_path)
        if self.file then 
            self.file:close()
            self.file = nil
        end
    end
    if self.file then 
        return
    end
    local file_name = self.date_path .. self.file_name .. self.suffix   
    self.file = io.open(file_name, "a+")
end

--保存到文件
function logger:SaveData(msg)
    if not msg and not next(msg) then
    	return 
    end    
    self:checkFile()

	local data = msg.."\n"
	self.file:write(data)
	self.file:flush()
	local file_size = self.file:seek("end")
	if file_size >= maxsize then
		--分割文件			
		local sub_time = os.date("%H_%M_%S",os.time())	
        local file_name = self.date_path .. self.file_name .. self.suffix   
		local rename = self.date_path .. self.file_name .."_"..sub_time .. self.suffix
		self.file:close()
		self.file = nil			
		os.rename(file_name, rename)
	end						
end

-- register protocol text before skynet.start would be better.
skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	unpack = skynet.tostring,
	dispatch = function(_, address, msg)
		-- local info = debug.getinfo(2)
		-- print(info)
		if not daemon then
			print(msg)
		else
			local text = string.format("[:%08x %s] %s", address, os.date("%Y_%m_%d %H:%M:%S"), msg)
			logger:SaveData(text)
		end
	end
}

skynet.register_protocol {
	name = "SYSTEM",
	id = skynet.PTYPE_SYSTEM,
	unpack = function(...) return ... end,
	dispatch = function()
		print("SIGHUP")
	end
}

skynet.start(function()

end)