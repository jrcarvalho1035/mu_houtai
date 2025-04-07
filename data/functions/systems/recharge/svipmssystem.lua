module("svipmssystem", package.seeall)---------配置表关联的要改

local function getActorVar(actor)-----获得人物属性
    if not actor then return end----没有获取到就返回
    local var = LActor.getStaticVar(actor)----人物信息保存在var里面
    if not var.svipmsData then var.svipmsData = {} end----命名空间
    if not var.svipmsData.isbuy then
        var.svipmsData.isbuy = {}
        for i = 1, #SVIPMSConfig - 1 do
            var.svipmsData.isbuy[i] = 0
        end
    end----更换成数组了
    return var.svipmsData
end

function GetReward(actor, pack) ----这个就是点了哪里去拿奖励
    local var = getActorVar(actor)
    local type = LDataPack.readChar(pack)
    --首先判断是否是一键购买对应的按钮的那个如果是就全部置2
    if type ~= #SVIPMSConfig then--如果不是的话就单个置2
        if var.isbuy[type] == 1 then
            var.isbuy[type] = 2
            actoritem.addItems(actor, SVIPMSConfig[type].rewards, "svipms get rewards")---获得奖励
        else
            return
        end
    else--如果是的话
        for i = 1, #SVIPMSConfig - 1 do----通过for循环全部置2
            if var.isbuy[i] == 1 then
                actoritem.addItems(actor, SVIPMSConfig[i].rewards, "svipms get rewards")
            end
        end
    end
    sendInfo(actor)
end

function killbuy(actor, count)----这个函数是写逻辑的
    local var = getActorVar(actor)
    local index----通过这个索引来判断是否这个东西
    local panduan = false
    for i = 1, #SVIPMSConfig do-------------------这里的for是获得索引
        if count == SVIPMSConfig[i].cash then
            index = i
            break
        end
    end
    
    if index == nil then----如果越值就返回
        return
    end
    
    if count ~= SVIPMSConfig[#SVIPMSConfig].cash then --------是买小件的情况下，如果买了就退出s
        if var.isbuy[index] ~= 0 then
            return false
        end
    else
        for i = 1, #SVIPMSConfig - 1 do------------------------------这段是写个判断，如果打包买了的话还发现所有的都买完了就直接返回
            if var.isbuy[i] == 0 then
                panduan = true
                break
            end
        end
        
        if panduan == false then
            return false
        end
    end
    
    if count ~= SVIPMSConfig[#SVIPMSConfig].cash then
        var.isbuy[index] = 1----设置成已购买的样子
        rechargesystem.addVipExp(actor, SVIPMSConfig[index].cash) 
    else
        for i = 1, #SVIPMSConfig - 1 do
            if var.isbuy[i] == 0 then
                var.isbuy[i] = 1
            end
        end
        rechargesystem.addVipExp(actor, SVIPMSConfig[#SVIPMSConfig].cash)
    end
    sendInfo(actor)

    local isAllBuy = true
    for i = 1, #SVIPMSConfig - 1 do
        if var.isbuy[i] ~= 1 and var.isbuy[i] ~= 2 then
            isAllBuy = false
        end
    end
    if isAllBuy then
        actorevent.onEvent(actor, aeSvipMSBuy)
    end
end

function sendInfo(actor)----------------这个是发送购买信息
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_svipkillBuyInfo)
    LDataPack.writeChar(pack, #SVIPMSConfig - 1)---这个发送长度
    for i = 1, #SVIPMSConfig - 1 do
        LDataPack.writeChar(pack, var.isbuy[i])
    end
    LDataPack.flush(pack)
end

function sviponeisbuy(count)----传入一个元宝数    这个是判断是不是买我这个一元秒杀的
    --local var = getActorVar(actor)----获取人物的属性
    --local index----通过这个索引来判断是否这个东西
    for i = 1, #SVIPMSConfig do
        if count == SVIPMSConfig[i].cash then
            return true
        end
    end
    return false
end

function OffMsgsvipmiaosha(actor, offmsg)
    local count = LDataPack.readInt(offmsg)
    print(string.format("OffMsgsvipmiaosha actorid:%d ", LActor.getActorId(actor)))
    killbuy(actor, count)
end

function buy(actorid, count) ----这个是把人物ID参数传进去判断是否人物对应
    local actor = LActor.getActorById(actorid)
    if actor then
        killbuy(actor, count)----如果对应则进入这个逻辑函数
    else -----如果不对应就触发事件
        local npack = LDataPack.allocPacket()
        LDataPack.writeInt(npack, count)
        System.sendOffMsg(actorid, 0, OffMsgType_svipmiaosha, npack)
    end
end

function onLogin(actor)----登录的时候发送一遍信息
    sendInfo(actor)
end

function onNewDay(actor, login)-----新的一天要重置
    local var = getActorVar(actor)
    for i = 1, #SVIPMSConfig - 1 do
        if var.isbuy[i] == 1 then
            local mailData = {head = SVIPMSConfig[i].mailTitle, context = SVIPMSConfig[i].mailContent, tAwardList = SVIPMSConfig[i].rewards}
            mailsystem.sendMailById(LActor.getActorId(actor), mailData)--发送邮件
        end
    end
    for i = 1, #SVIPMSConfig - 1 do
        var.isbuy[i] = 0
    end
    if not login then
        sendInfo(actor)
    end
end

-----事件信号注册
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
msgsystem.regHandle(OffMsgType_svipmiaosha, OffMsgsvipmiaosha)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_svipGetReward, GetReward)

----------------------------------------------------------------------------------------------------------------------------
