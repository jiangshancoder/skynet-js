local skynet = require "skynet"
require "skynet.manager"
local service = require "skynet.service"



skynet.start(function()
    -- skynet.error("Server start")
    -- skynet.error("=============================================")
	-- skynet.error(os.date("%Y/%m/%d %H:%M:%S ") .. " start")
	-- skynet.error("=============================================")

    local helper = require "game.texas_card.texas_card_helper_test"

    -- local holdCards = {0x1d,0x2d}--29 45
    -- local holdCards2 = {0x1c,0x2c}--28  44
    -- local publicCards =  {0x11,0x21,0x31,0x13,0x23}--17 33 49 19 35

    local holdCards = {}
    local holdCards2 = {}
    local publicCards =  {}
    --高牌
    -- holdCards = {0x11,0x13}--17  19
    -- publicCards = {0x25,0x36,0x49,0x4b,0x4d}--37  54  73  75 77
    --17,77,75,73,54


    --对子
    -- holdCards = {0x11,0x21}--17  33
    -- publicCards = {0x25,0x36,0x49,0x4b,0x4d}--37  54  73  75 77
    --17,33,77,75,73


    --两对
    -- holdCards = {0x11,0x12}--17  18
    -- publicCards = {0x21,0x22,0x49,0x4b,0x4d}--33  34  73  75 77
    --17,33,18,34,77

    --三条
    -- holdCards = {0x11,0x12}--17  18
    -- publicCards = {0x21,0x31,0x49,0x4b,0x4d}--33  49  73  75 77
    --17,33,49,77,75

    --顺子
    -- holdCards = {0x11,0x12}--17  18
    -- publicCards = {0x13,0x24,0x35,0x4b,0x4d}--19  36  53  75 77
    --17,18,19,36,53

    --同花
    -- holdCards = {0x11,0x12}--17  18
    -- publicCards = {0x14,0x16,0x19,0x4b,0x4d}--20  22  25  75 77
    --17,25,22,20,18

    --葫芦
    -- holdCards = {0x11,0x31}--17  49
    -- publicCards = {0x21,0x33,0x43,0x4b,0x4d}--33  51  67  75 77
    --17,49,33,51,67

    --四条
    -- holdCards = {0x11,0x31}--17  49
    -- publicCards = {0x21,0x41,0x43,0x4b,0x4d}--33  65  67  75 77
    --17,33,49,65,77

    --同花顺
    -- holdCards = {0x12,0x13}--18  19
    -- publicCards = {0x14,0x15,0x16,0x45,0x43}--20  21  22  69 67
    --22,21,20,19,18

    --皇家同花顺
    -- holdCards = {0x19,0x18}--29  28
    -- publicCards = {0x1b,0x1a,0x11,0x1d,0x1c,}--27  26  17  25 24
    --17,29,28,27,26


    -- local card_type = helper.getCardType(holdCards,publicCards)
    -- print(helper.getCardTypeText(card_type))
    -- print("=============================")

    -- local hand1 = {0x11,0x31}
    -- local hand2 = {0x19,0x1c,}
    -- local publicCards = {0x1b,0x1a,0x11,0x1d,0x18,}
    -- local ret = helper.compareCardType(hand1,hand2,publicCards)
    -- print("比牌结果:",ret)
    -- local ret = helper.get_max_five_cards(holdCards,publicCards)
    -- print(ret)
    skynet.exit()
end)
