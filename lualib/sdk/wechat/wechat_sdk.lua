local skynet = require "skynet"
local crypt = require "skynet.crypt"
local COLL = _ENV.COLL
require "BaseFunc"
require "table_util"
-- local clusterdatacenter = require "clusterdatacenter"
local M = {}


M.app_id = "wx44bxxxxxxxxef6"
M.app_secret = "2f8d582xxxxxxxxxx986e8b4e36"
M.offer_id = "145xxxxxxxx8"
M.host = "https://api.weixin.qq.com"
M.publish_host = "http://118.190.206.114:13009"

function M.login_params(code)
	local fmt = "/sns/jscode2session?appid=%s&secret=%s&js_code=%s&grant_type=authorization_code"
	local str = string.format(fmt, M.app_id, M.app_secret, code)
	return str
end

function M.wd_get_user(openid,token)
	local fmt = "/sns/userinfo?access_token=%s&openid=%s"
	local str = string.format(fmt, token, openid)
	return str
end


function M.access_token_param()
	-- local env = skynet.getenv("env")
	-- if env == "publish" then
		local fmt = "/cgi-bin/token?grant_type=client_credential&appid=%s&secret=%s"
		local str = string.format(fmt, M.app_id, M.app_secret)
		return str
	-- else
	-- 	return "/get_access_token?sdk=wechat"
	-- end
end

function M.update_access_token(channel, token, expires_in)
	local expire_time = expires_in - 10 * 60

    skynet.call(".db_mgr", "lua", "update_insert", COLL.ACCESS_TOKEN, {channel = channel}, {
        time=os.time(), expires_in=expire_time, token = token,channel=channel})

	-- clusterdatacenter.set("wechat_sdk", "access_token", token)
	-- clusterdatacenter.set("wechat_sdk", "expires_in", expire_time) --提前10分钟去刷新
	print("update_access_token access_token =>", token, "; expire_time =>", os.date("%c", expire_time))
end

function M.get_host()
	return M.host
end

function M.get_publish_host()
	return M.publish_host
end

function M.access_token_vaild()
     local channel = "dazui_wechat"
     local curTime = os.time()
    local tokenInfo = skynet.call(".db_mgr", "lua", "find_one", COLL.ACCESS_TOKEN, {channel = channel}, {channel = true, time=true, expires_in = true})
    
    if not tokenInfo or ((curTime - tokenInfo.time) > tokenInfo.expires_in) then
        return false
    end
    return true
end

function M.check_resp(args)
	if tonumber(args.resultCode) == 200 then
		return true, args
	else
		return false, args.resultMsg
	end
end

local function get_sign_str(args)
    local sign_body = {}
    for k,v in pairs(args) do
        if k ~= "sig" and v ~= "" then
            table.insert(sign_body, {k = k, v = v})
        end
    end
    table.sort(sign_body, function (a, b)
        return a.k < b.k
    end)
    local sign_body_tbl = {}
    for _, item in ipairs(sign_body) do
        table.insert(sign_body_tbl, string.format('%s=%s', item.k, item.v))
    end
    local sign_body_str = table.concat(sign_body_tbl, "&")
    return sign_body_str
end

function M.sign(args, url, key)

    -- local tmpargs = {openid="odkx20ENSNa2w5y3g_qOkOvBNM1g",appid="wx1234567",offer_id="12345678",ts=1507530737,zone_id="1",pf="android"}

    -- local tmpurl = "/cgi-bin/midas/getbalance"
    -- local tmpkey = "zNLgAGgqsEWJOg1nFVaO5r7fAlIQxr1u"
    -- local tmpstr2sign = get_sign_str(tmpargs)
    -- tmpstr2sign = string.format("%s&org_loc=%s&method=POST&secret=%s", tmpstr2sign, tmpurl,tmpkey)
    -- print("tmpstr2sign=", tmpstr2sign)
    -- print(crypt.hexencode(crypt.hmac_sha256(tmpkey, tmpstr2sign)))
    local str2sign =  get_sign_str(args)
    str2sign = string.format("%s&org_loc=%s&method=POST&secret=%s", str2sign, url,key)
    print("str2sign=", str2sign)
    return crypt.hexencode(crypt.hmac_sha256(key, str2sign))
end

function M.get_app_key()
	local env = skynet.getenv("env")
	if env == "publish" then
		return "eF6vwPF1GQiOYtTtkntLJytMfnwagUoO"
	else
		return "TDPVBunU3uxw1diVcDhSBv9bqt3Y2YNZ"
	end
end

function M.get_blance_url()
	local env = skynet.getenv("env")
	if env == "publish" then
		return "/cgi-bin/midas/getbalance"
	else
		return "/cgi-bin/midas/sandbox/getbalance"
	end
end

function M.get_pay_url()
	local env = skynet.getenv("env")
	if env == "publish" then
		return "/cgi-bin/midas/pay"
	else
		return "/cgi-bin/midas/sandbox/pay"
	end
end

function M.get_sandbox()
   local env = skynet.getenv("env")
   if env == "publish" then
        return nil
   end
   return "sandbox"
end

function M.get_access_token()
    local channel = "dazui_wechat"
    local curTime = os.time()
    print(COLL.ACCESS_TOKEN,channel)
    local tokenInfo = skynet.call(".db_mgr", "lua", "find_one", COLL.ACCESS_TOKEN, {channel = channel}, {channel = true, time=true, token=true, expires_in = true})
    table.print(tokenInfo)
    if not tokenInfo or ((curTime - tokenInfo.time) > tokenInfo.expires_in) then
        return ""
    end
    return tokenInfo.token
end

function M.get_subscribe_host()
    return "https://api.weixin.qq.com"

end

function M.get_subscribe_url()
    return "https://api.weixin.qq.com/cgi-bin/message/subscribe/send"

end

function M.append_access_token(url)
	local access_token = M.get_access_token()
	print("append_access_token =", access_token)
	return string.format("%s?access_token=%s", url, access_token),access_token
end

function M.decrypt(encrypt_data, session_key, iv)
	local cipher 				= require "lcipher.c"
	local b64de_encrypt_data 	= crypt.base64decode(encrypt_data)
	local b64de_session_key 	= crypt.base64decode(session_key)
	local b64de_iv 				= crypt.base64decode(iv)
	local enc 					= cipher.new("aes-128-cbc")
	local unencrypt_data 			= enc:decrypt(b64de_session_key, b64de_iv, b64de_encrypt_data)
	return { unencrypt_data = unencrypt_data }
end


return M