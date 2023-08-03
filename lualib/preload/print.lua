-- debugPrint.lua
-- a print implementation suitable for debug purpose
--[[
# Detailed info about this script

## Features
* Prioritized msg level
* Print all lua types including table (support recursive table)
* Print to multiple loggers (console, log table, etc. You can add your own)
* Toggle position info (line number, file name, etc.) of print statement with global switch

Compared with individual implmentation of print, info, warn or error, the advantage of this implementation is code-reuse.

## Usage
* `require("debugPrint")` and you can use `print`.
* set `PRINT_SOURCE` to `true` to print position info

## E.g

```lua
require("debugPrint")

print("hello")

print("hello", "world")
PRINT_SOURCE = false
print("a simple table", {10, 20})

testTable = {}
testTable[#testTable + 1] = {1, 2, 3}
testTable[#testTable + 1] = testTable
testTable[#testTable + 1] = function () oldprint("hello") end
testTable[#testTable + 1] = true
print("a complicated table", testTable)

```


## Compatibility
Tested with Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio

## Major Reference
Lua source of Don't Starve Together by Klei Entertainment (https://www.klei.com/)
Lua source of Garry's Mod by Facepunch Studios LTD (http://www.facepunchstudios.com/)
Lua source of Penlight (https://github.com/stevedonovan/Penlight)

## TODO
[] print large table more effectively
[] have some hierarchy in print to show table hierarchy
[] get more detailed message for function
[] focus mode. just print info of interest
[] Print to print. maybe a special first key?

## Legal Notice
This file is licensed under The MIT License (MIT)
Copyright (c) 2018 HustLion <hustlion-dev@outlook.com>
--]]
local skynet = require "skynet"

old_print = print
PRINT_SOURCE = true
CWD = "" -- you can set a global value CWD to current working directory and the log will include it
DEBUG_PRINT_MAX_DEPTH = 3 -- set this to a proper value to avoid out of memory issue since a table can get very large

local print_loggers = {}
local dir = CWD
dir = string.gsub(dir, "\\", "/") .. "/"
local oldprint = print

-- string ops from https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/includes/extensions/string.lua
function string.Explode(separator, str, withpattern)
  if ( separator == "" ) then return totable( str ) end
  if ( withpattern == nil ) then withpattern = false end

  local ret = {}
  local current_pos = 1

  for i = 1, string.len( str ) do
    local start_pos, end_pos = string.find( str, separator, current_pos, not withpattern )
    if ( not start_pos ) then break end
    ret[ i ] = string.sub( str, current_pos, start_pos - 1 )
    current_pos = end_pos + 1
  end

  ret[ #ret + 1 ] = string.sub( str, current_pos )

  return ret
end

function string.split( str, delimiter )
  return string.Explode( delimiter, str )
end

function AddPrintLogger( fn )
  table.insert(print_loggers, fn)
end

-- https://stackoverflow.com/a/7574047/4394850
local function toarray(...)
  return {...}
end

local function _packTable (t, tableRecorder)
  tableRecorder[t] = true
  local str = ""
  -- for small table
  for i,v in ipairs(t) do
    if v then
      if type(v) == "table" then
        if tableRecorder[v] ~= true then
          tableRecorder[v] = true
          str = str.._packTable(v, tableRecorder).."\n"
        else
          str = str.."recursive "..tostring(v).."\n"
        end
        
      elseif type(v) == "function" then
        -- TODO: get function name or code?
        str = str.."function".."\n"
      else
        str = str..tostring(v).."\n"
      end
      
    end
  end
  -- TODO for large one use stack
  return str
end

local function quote_string(s)
  return "\""..s.."\""
end

local function quote_if_necessary (v)
    if not v then return ''
    else
        --AAS
        if v:find ' ' then v = quote_string(v) end
    end
    return v
end

--- Create a string representation of a Lua table.
-- This function never fails, but may complain by returning an
-- extra value. Normally puts out one item per line, using
-- the provided indent; set the second parameter to an empty string
-- if you want output on one line.
-- @tab tbl Table to serialize to a string.
-- @string[opt] space The indent to use.
-- Defaults to two spaces; pass an empty string for no indentation.
-- @bool[opt] not_clever Pass `true` for plain output, e.g `{['key']=1}`.
-- Defaults to `false`.
-- @return a string
-- @return an optional error message
function _write (tbl,space,not_clever, depthLimit)
  if type(tbl) ~= 'table' then
    local res = tostring(tbl)
    if type(tbl) == 'string' then return quote(tbl) end
    return res, 'not a table'
  end
  --    if not keywords then
  --        keywords = lexer.get_keywords()
  --    end
  local set = ' = '
  if space == '' then set = '=' end
  space = space or '  '
  local lines = {}
  local line = ''
  local tables = {}


  local function put(s)
    if #s > 0 then
      line = line..s
    end
  end

  local function putln (s)
    if #line > 0 then
      line = line..s
      --            append(lines,line)
      table.insert(lines, line)
      line = ''
    else
      --            append(lines,s)
      table.insert(lines, s)
    end
  end

  local function eat_last_comma ()
    local n,lastch = #lines
    local lastch = lines[n]:sub(-1,-1)
    if lastch == ',' then
      lines[n] = lines[n]:sub(1,-2)
    end
  end


  local writeit
  -- depth is used to control depth
  local depthLimit = depthLimit or 3

  writeit = function (t,oldindent,indent, depth)
    local nextDepth = depth + 1
    local tp = type(t)
    if tp ~= 'string' and  tp ~= 'table' then
      putln(quote_if_necessary(tostring(t))..',')
    elseif tp == 'string' then
      -- if t:find('\n') then
      --     putln('[[\n'..t..']],')
      -- else
      --     putln(quote(t)..',')
      -- end
      --AAS
      putln(quote_string(t) ..",")

    elseif tp == 'table' then
      if tables[t] then
        putln('<cycle>,')
        return
      end
      tables[t] = true
      local newindent = indent..space
      putln('{')
      local used = {}
      if not not_clever then
        for i,val in ipairs(t) do
          put(indent)
          if nextDepth > depthLimit then
            putln(oldindent..'<exceeds max depth>,')
          else
            writeit(val,indent,newindent, nextDepth)
          end
          --writeit(val,indent,newindent)
          used[i] = true
        end
      end
      for key,val in pairs(t) do
        local tkey = type(key)
        local numkey = tkey == 'number'
        if not_clever then
          key = tostring(key)
          put(indent..index(numkey,key)..set)
          if nextDepth > depthLimit then
            putln(oldindent..'<exceeds max depth>,')
          else
            writeit(val,indent,newindent, nextDepth)
          end
          --writeit(val,indent,newindent)
        else
          if not numkey or not used[key] then -- non-array indices
            if tkey ~= 'string' then
              key = tostring(key)
            end
            --                        if numkey or not is_identifier(key) then
            --                            key = index(numkey,key)
            --                        end
            put(indent..key..set)
            if nextDepth > depthLimit then
              putln(oldindent..'<exceeds max depth>,')
            else
              writeit(val,indent,newindent, nextDepth)
            end
            --writeit(val,indent,newindent)
          end
        end
      end
      tables[t] = nil
      eat_last_comma()
      putln(oldindent..'},')
    else
      putln(tostring(t)..',')
    end
  end
  writeit(tbl,'',space, 1)
  eat_last_comma()
  return table.concat(lines,#space > 0 and '\n' or '')
end


-- e.g. oldprint(packTable(debugstr))
local function packTable(t)
  local rec = {}
  --  return "\n".._packTable(t, rec)
  return "\n".._write(t,'  ', false, DEBUG_PRINT_MAX_DEPTH)
end

local function pack(v)
  if type(v) == "table" then
    return packTable(v).." "
  elseif type(v) == "function" then
    return "function".." "
  elseif type(v) == "userdata" then
    if getmetatable ~= nil then
      return "userdata:\n"..packTable(getmetatable(v))
    else
      return "userdata:\n"..v
    end
    
    
  else
    return tostring(v).." "
  end
  
end


local function packArg(...)
  local str = ""
  local n = select('#', ...)
--  oldprint("n is", n, "for", ...)
  if n > 1 then
    local args = toarray(...)
    for i=1, n do
--          str = str..tostring(arg[i]).."\t"
      str = str..pack(args[i])
    end
    return str
  else
    return pack(...)
  end
end

--this wraps print in code that shows what line number it is coming from, and pushes it out to all of the print loggers
print = function(...)

  local str = ""
  if PRINT_SOURCE then
    local info = debug.getinfo(2, "Sl") -- print function is call stack 1, and the caller is 2
    local source = info and info.source
    if source then
      str = string.format("[%s:%d] %s", source, info.currentline, packArg(...))
    else
      str = packArg(...)
    end
  else
    str = packArg(...)
  end
--  oldprint("str for loggers:", str)
    str = string.format("[%s] [:%08x] %s", os.date("%Y-%m-%d %H:%M:%S",os.time()),skynet.self(),str)

  for i,v in ipairs(print_loggers) do
    v(str)
  end

end

-- TODO: This is for times when you want to print without showing your line number (such as in the interactive console)
local nolineprint = function(...)
  for i,v in ipairs(print_loggers) do
    v(...)
  end
end

---- This keeps a record of the last n print lines, so that we can feed it into the debug console when it is visible
local debugstr = {}
local MAX_CONSOLE_LINES = 20

local consolelog = function(...)

  local str = packArg(...)
  str = string.gsub(str, dir, "")

  for idx,line in ipairs(string.split(str, "\r\n")) do
    table.insert(debugstr, line)
  end

  while #debugstr > MAX_CONSOLE_LINES do
    table.remove(debugstr,1)
  end
end

local textlog = function (...)
  oldprint(...)
end

function GetConsoleOutputList()
  return debugstr
end

-- add our print loggers
AddPrintLogger(consolelog)
AddPrintLogger(textlog)

-- Prioritized logger
VERBOSITY =
{
  ERROR = 0,
  WARNING = 1,
  INFO = 2,
  DEBUG = 3,
}

--VERBOSITY_LEVEL = VERBOSITY.WARNING
VERBOSITY_LEVEL = VERBOSITY.DEBUG
function Print( msg_verbosity, ... )
  if msg_verbosity <= VERBOSITY_LEVEL then
    print( ... )
  end
end


---- Testing

-- Print(VERBOSITY.DEBUG, 'This is a debug level message: ', "hello")

-- print("hello")
-- PRINT_SOURCE = false
-- print("hello", "world")
-- print("table", {10, 20})

-- debugstr[#debugstr + 1] = {1, 2, 3}
-- debugstr[#debugstr + 1] = debugstr
-- debugstr[#debugstr + 1] = function () oldprint("hello") end
-- debugstr[#debugstr + 1] = true
-- oldprint("Printing the recursive debugstr table")
-- print(debugstr)