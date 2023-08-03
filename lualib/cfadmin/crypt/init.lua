local CRYPT = require "cfadmin_crypt"

local crypt = {
  -- HEX编码/解码
  hexencode = CRYPT.hexencode,
  hexdecode = CRYPT.hexdecode,
  -- URL编码/解码
  urlencode = CRYPT.urlencode,
  urldecode = CRYPT.urldecode,
}

-- UUID与GUID
require "cfadmin.crypt.id"(crypt)

-- 安全哈希与摘要算法
require "cfadmin.crypt.sha"(crypt)

-- 哈希消息认证码算法
require "cfadmin.crypt.hmac"(crypt)

-- 冗余校验算法
require "cfadmin.crypt.checksum"(crypt)

-- Base64编码/解码算法
require "cfadmin.crypt.b64"(crypt)

-- RC4算法
require "cfadmin.crypt.rc4"(crypt)

-- AES对称加密算法
require "cfadmin.crypt.aes"(crypt)

-- DES对称加密算法
require "cfadmin.crypt.des"(crypt)

-- 密钥交换算法
require "cfadmin.crypt.dh"(crypt)

-- 商用国密算法
require "cfadmin.crypt.sm"(crypt)

-- 非对称加密算法
require "cfadmin.crypt.rsa"(crypt)

-- 一些特殊算法
require "cfadmin.crypt.utils"(crypt)

return crypt