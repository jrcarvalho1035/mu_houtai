--领地争夺战
module("guildbattlesystem", package.seeall)

--领地争夺战时间段1报名，2竞猜，3初赛准备，4初赛，5决赛准备，6决赛，7结束
BATTLE_STAGE_TIME = BATTLE_STAGE_TIME or {}
BATTLE_RANK_INFO = BATTLE_RANK_INFO or {}
GUILD_BATTLE_BUFFERS = GUILD_BATTLE_BUFFERS or {}

function getActorVar(actor)
	if not actor then return end

	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.guildbattle then
        var.guildbattle = {}
        var.guildbattle.dailyget = 0
        var.guildbattle.worshiptimes = 0 --膜拜次数
        var.guildbattle.getmails = 0 --是否已收到邮件,通知进入战盟成功
        var.guildbattle.getmailstime = 0 --获取邮件时间
	end
	return var.guildbattle	
end

function getGlobalData()
	local data = System.getStaticGuildBattleVar()
	if not data then return end
	if not data.guildbattle then data.guildbattle = {} end
    if not data.guildbattle.applyssorts then  --申请列表
        data.guildbattle.fbinfo = {} --副本战盟对战信息        
        data.guildbattle.sorttime = 0 --个人排行刷新时间，两秒刷新一次
        data.guildbattle.selfrank = {} --个人积分排行
        data.guildbattle.applyssorts = {} --排序后的战盟列表
        data.guildbattle.guesss = {}  --竞猜信息
        data.guildbattle.winguidlids = {} --获胜第一名公会id
        data.guildbattle.semifinal = {} --半决赛[1]=index, [2]=index},[3]=index, [4]=index}, 1和2对战，3和4对战
        data.guildbattle.final = {} --决赛{[1]=index, [2]=index}}
        data.guildbattle.fightinfo = {} --对战信息
        for i=1, GBConstConfig.manorcount do
			data.guildbattle.applyssorts[i] = {} --排序后的战盟列表
			data.guildbattle.guesss[i] = {}  --竞猜信息
			data.guildbattle.winguidlids[i] = {} --获胜第一名公会id
			data.guildbattle.semifinal[i] = {} --半决赛[1]=index, [2]=index},[3]=index, [4]=index}, 1和2对战，3和4对战
            data.guildbattle.final[i] = {} --决赛{[1]=index, [2]=index}}            
        end
    end
	if not data.guildbattle.guildResult then data.guildbattle.guildResult = {} end --领地战结果，[guildId] = {manorindex = 0, rank=1, hongbaoflag = 0}
    if not data.guildbattle.hongbao then data.guildbattle.hongbao = {} end --红包信息[guildId] = {count = 0, remaincount=0, remainmoney=0, record = {name = "", count = 1, actorid = 0}}
    if not data.guildbattle.worship then
        data.guildbattle.worship = {}
        data.guildbattle.worship.name = ""
        data.guildbattle.worship.times = 0
        data.guildbattle.worship.job = 0
        data.guildbattle.worship.shenzhuang = 0
        data.guildbattle.worship.shenqi = 0
        data.guildbattle.worship.wing = 0
        data.guildbattle.worship.shengling = 0
        data.guildbattle.worship.meilin = 0
    end    
	return data.guildbattle
end

--请求领地申请列表
function handleGetApplyList(actor, pack)
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_GetApplyList)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, guildId)
    System.sendPacketToAllGameClient(npack, 0)	
end

function onGetApplyList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local guildId = LDataPack.readInt(cpack)
    sendManorList(sId, actorid, guildId)
end

function sendManorList(sId, actorid, guildId, gvar)
    gvar = gvar or getGlobalData()
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendManorList)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, #gvar.applyssorts)
    for i=1, GBConstConfig.manorcount do        
        local applyssorts = gvar.applyssorts[i]
        LDataPack.writeChar(npack, #applyssorts)
        for j=1, #applyssorts do
            LDataPack.writeInt(npack, applyssorts[j].guildId)
            LDataPack.writeString(npack, applyssorts[j].guildName)
            LDataPack.writeString(npack, LGuild.getLeaderNameById(applyssorts[j].guildId))
            LDataPack.writeDouble(npack, applyssorts[j].power)
            LDataPack.writeChar(npack, applyssorts[j].level)
            LDataPack.writeChar(npack, applyssorts[j].membercount)
        end
    end
    System.sendPacketToAllGameClient(npack, sId)
end

function onActorLogin(sId, actorid, guildId, iscross)
    local gvar = getGlobalData()
    sendManorList(sId, actorid, guildId, gvar)
    sendBaseInfo(sId, actorid, guildId, iscross, gvar)
    sendHongbaoInfo(sId, actorid, guildId, gvar)
    sendFightList(sId, actorid)
end

--膜拜信息
function sendWorshipInfo(sId, actorid)
    broWorshipActor(sId, actorid)
end

function broWorshipActor(sId, actorid)
    gvar = gvar or getGlobalData()
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendWorship)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, GBConstConfig.manorcount)
    for i=1, GBConstConfig.manorcount do
        if gvar.winguidlids[i] then
            LDataPack.writeChar(npack, #gvar.winguidlids[i])
            for k,v in ipairs(gvar.winguidlids[i]) do
                LDataPack.writeChar(npack, k)
                LDataPack.writeInt(npack, v)
                LDataPack.writeString(npack, LGuild.getGuilNameById(v))
                LDataPack.writeString(npack, LGuild.getLeaderNameById(v))
            end
        else
            LDataPack.writeChar(npack, 0)
        end
    end
    LDataPack.writeInt(npack, gvar.worship.times)    
    LDataPack.writeChar(npack, gvar.worship.job)
    LDataPack.writeInt(npack, gvar.worship.shenzhuang)
    LDataPack.writeInt(npack, gvar.worship.shenqi)
    LDataPack.writeInt(npack, gvar.worship.wing)
    LDataPack.writeInt(npack, gvar.worship.shengling)
    LDataPack.writeInt(npack, gvar.worship.meilin)
    System.sendPacketToAllGameClient(npack, sId)
end

--进入主城
function onEnterMainFb(ins, actor)
    sendWorshipPack(actor)
end

--发送基础信息
function sendBaseInfo(sId, actorid, guildId, iscross, gvar)
    gvar = gvar or getGlobalData()
    local guildResult = gvar.guildResult[guildId]
    local guild = LGuild.getGuildById(guildId)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendBaseInfo)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt(npack, guildId)
    LDataPack.writeShort(npack, guildcommon.getGuildLevel(guild))
    LDataPack.writeDouble(npack, LGuild.getGuildTotalPower(guildId))
    LDataPack.writeString(npack, LGuild.getGuildName(guild))
    LDataPack.writeString(npack, LGuild.getLeaderName(guild))    
    LDataPack.writeChar(npack, LGuild.getGuildMemberCount(guild))
    LDataPack.writeChar(npack, guildResult and guildResult.manorindex or 0)
    LDataPack.writeChar(npack, guildResult and guildResult.rank or 0)
    LDataPack.writeChar(npack, guildResult and guildResult.hongbaoflag or 0)
    LDataPack.writeChar(npack, iscross or 0)
    System.sendPacketToAllGameClient(npack, sId)
end

--发送红包信息
function sendHongbaoInfo(sId, actorid, guildId, gvar)
    gvar = gvar or getGlobalData()
    local guildResult = gvar.guildResult[guildId]
    local guild = LGuild.getGuildById(guildId)

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendHongbaoInfo)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt(npack, guildId)
    local hongbaodata = gvar.hongbao[guildId]
    LDataPack.writeInt(npack, hongbaodata and hongbaodata.remainmoney or 0)
    LDataPack.writeChar(npack, guildResult and guildResult.hongbaoflag or 0)
    LDataPack.writeInt(npack, hongbaodata and hongbaodata.remainmoney or 0)
    LDataPack.writeChar(npack, hongbaodata and hongbaodata.count or 0)
    LDataPack.writeChar(npack, hongbaodata and hongbaodata.remaincount or 0)
    LDataPack.writeChar(npack, hongbaodata and hongbaodata.record and #hongbaodata.record or 0)
    for k,v in ipairs(hongbaodata and hongbaodata.record or {}) do
        LDataPack.writeInt(npack, v.count)
        LDataPack.writeString(npack, v.name)
        LDataPack.writeInt(npack, v.actorid)
    end

    System.sendPacketToAllGameClient(npack, sId)
end

function onSendManorList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ApplyList)
    local manorcount = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, manorcount)
    for i=1, manorcount do
        local count = LDataPack.readChar(cpack)
        LDataPack.writeChar(npack, i)
        LDataPack.writeChar(npack, count)
        for j=1, count do
            LDataPack.writeInt(npack, LDataPack.readInt(cpack))
            LDataPack.writeString(npack, LDataPack.readString(cpack))
            LDataPack.writeString(npack, LDataPack.readString(cpack))
            LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        end
    end
 
    LDataPack.flush(npack)
end

local function onSendBaseInfo(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local pos = LActor.getGuildPos(actor)
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_BaseInfo)
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeChar(npack, pos)
    LDataPack.writeShort(npack, LDataPack.readShort(cpack))
    LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
    LDataPack.writeString(npack, LDataPack.readString(cpack))
    LDataPack.writeString(npack, LDataPack.readString(cpack))
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    local manorindex = LDataPack.readChar(cpack)
    local rank = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, manorindex)
    LDataPack.writeChar(npack, rank)
    local hongbaoflag = LDataPack.readChar(cpack) 
    local iscross = LDataPack.readChar(cpack)
    if hongbaoflag >= 1 and manorindex > 0 and rank > 0 then
        LDataPack.writeChar(npack, var.dailyget > 0 and var.dailyget or 1)
    else
        LDataPack.writeChar(npack, 0)
    end
    LDataPack.flush(npack)
    --发送盟主上线公告
    if pos == smGuildLeader and iscross == 0 then
        onLeaderLogin(actor, manorindex, rank)
    end
end

--上线公告
function onLeaderLogin(actor, manorindex, rank)
    if manorindex > 0 and rank > 0 then        
        local manorlevel = GBManorIndexConfig[manorindex].level
        local id = GBManorConfig[manorlevel][rank].loginnotice
        if id ~= 0 then
            noticesystem.broadLoginNotice(actor, id)
        end        
    end
end


local function onSendHongbaoInfo(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local guildId = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    local npack
    if actorid == 0 then
        npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
        LDataPack.writeByte(npack, Protocol.sGuildBattleCmd_HongbaoInfo)
    else
        if not actor then
            return
        end
        npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_HongbaoInfo)
    end
    if not npack then return end
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))    
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))    
    
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    end
    if actorid == 0 then
        LGuild.broadcastData(guildId, npack)
    else
        LDataPack.flush(npack)
    end
end

local function onSendWorship(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    if actorid ~= 0 then
        local actor = LActor.getActorById(actorid)
        if not actor then return end
        local var = getActorVar(actor)
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_Worship)
        LDataPack.writeChar(npack, GBConstConfig.worshiptimes - var.worshiptimes)
        local manorcount = LDataPack.readChar(cpack)
        LDataPack.writeChar(npack, manorcount)
        for i=1, manorcount do
            local count = LDataPack.readChar(cpack)
            LDataPack.writeChar(npack, count)
            for i=1, count do
                LDataPack.writeChar(npack, LDataPack.readChar(cpack))
                LDataPack.writeInt(npack, LDataPack.readInt(cpack))
                LDataPack.writeString(npack, LDataPack.readString(cpack))
                LDataPack.writeString(npack, LDataPack.readString(cpack))
            end    
        end
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack)) --职业
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.flush(npack)
    else
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
        LDataPack.writeByte(npack, Protocol.sGuildBattleCmd_WorshipBro)
        local manorcount = LDataPack.readChar(cpack)
        LDataPack.writeChar(npack, manorcount)
        for i=1, manorcount do
            local count = LDataPack.readChar(cpack)
            LDataPack.writeChar(npack, count)
            for i=1, count do
                LDataPack.writeChar(npack, LDataPack.readChar(cpack))
                LDataPack.writeInt(npack, LDataPack.readInt(cpack))
                LDataPack.writeString(npack, LDataPack.readString(cpack))
                LDataPack.writeString(npack, LDataPack.readString(cpack))
            end    
        end
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack)) --职业
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        System.broadcastData(npack)
    end
end

--膜拜
local function handleWorship(actor, pack)
    if not System.isBattleSrv() then return end
    local var = getActorVar(actor)
    if var.worshiptimes >= GBConstConfig.worshiptimes then
        return
    end
    local gvar = getGlobalData()
    if not next(gvar.guildResult) then
        return
    end
    
    var.worshiptimes = var.worshiptimes + 1
    actoritem.addItem(actor, NumericType_YuanBao, GBConstConfig.worshipyuanbao, "guild battle worship")
    
    gvar.worship.times = gvar.worship.times + 1
    sendWorshipPack(actor, gvar, var)    
end

function sendWorshipPack(actor, gvar, var)
    local var = var or getActorVar(actor)
    local gvar = gvar or getGlobalData()
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_Worship)
    LDataPack.writeChar(npack, GBConstConfig.worshiptimes - var.worshiptimes)
    LDataPack.writeChar(npack, GBConstConfig.manorcount)
    for i=1, GBConstConfig.manorcount do
        if gvar.winguidlids then
            LDataPack.writeChar(npack, #gvar.winguidlids[i])
            for k,v in ipairs(gvar.winguidlids[i]) do
                LDataPack.writeChar(npack, k)     
                LDataPack.writeInt(npack, v)
                LDataPack.writeString(npack, LGuild.getGuilNameById(v))
                LDataPack.writeString(npack, LGuild.getLeaderNameById(v))
            end
        else
            LDataPack.writeChar(npack, 0)
        end
    end
    LDataPack.writeInt(npack, gvar.worship.times)
    LDataPack.writeChar(npack, gvar.worship.job) --职业
    LDataPack.writeInt(npack, gvar.worship.shenzhuang)
    LDataPack.writeInt(npack, gvar.worship.shenqi)
    LDataPack.writeInt(npack, gvar.worship.wing)
    LDataPack.writeInt(npack, gvar.worship.shengling)
    LDataPack.writeInt(npack, gvar.worship.meilin)
    LDataPack.flush(npack)
end

--竞猜
function handleGuildGuess(actor, pack)
    local now = System.getNowTime()
    if now < BATTLE_STAGE_TIME[1] or now > BATTLE_STAGE_TIME[2] then return end
    
    local manorindex = LDataPack.readChar(pack)
    if manorindex < 0 or manorindex > GBConstConfig.manorcount then return end
    local guildindex = LDataPack.readChar(pack)
    if guildindex <= 0 or guildindex > 4 then
        print("handleGuildGuess guildindex index is :", guildindex)
        return 
    end
    local config = GBGuessConfig[GBManorIndexConfig[manorindex].level]
    if not actoritem.checkItem(actor, NumericType_YuanBao, config.needyuanbao) then
        return
    end
    actoritem.reduceItem(actor, NumericType_YuanBao, config.needyuanbao, "guild battle guess")

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_Guess)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeChar(npack, manorindex)
    LDataPack.writeChar(npack, guildindex)
    System.sendPacketToAllGameClient(npack, 0)	
end

function sendGuessResult(sId, actorid, result, manorindex, guildId)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendGuess)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, result)
    LDataPack.writeChar(npack, manorindex or 0)
    LDataPack.writeInt(npack, guildId or 0)
    System.sendPacketToAllGameClient(npack, sId)	
end

local function onGuess(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local manorindex = LDataPack.readChar(cpack)
    local guildindex = LDataPack.readChar(cpack)

    local gvar = getGlobalData()
    if not gvar.applyssorts[manorindex] then
        sendGuessResult(sId, actorid, 0, manorindex)
        return
    end
    if not gvar.guesss[manorindex] then gvar.guesss[manorindex] = {} end
    if not gvar.guesss[manorindex][actorid] then gvar.guesss[manorindex][actorid] = {} end
    if (gvar.guesss[manorindex][actorid].choose or 0) ~= 0 then
        sendGuessResult(sId, actorid, 0, manorindex)
        return
    end
    local semifinalindex = gvar.semifinal[manorindex][guildindex]
    if not gvar.semifinal[manorindex][guildindex] or gvar.applyssorts[manorindex][semifinalindex].guildId == 0 then
        sendGuessResult(sId, actorid, 0, manorindex)
        return
    end
    local guildId = gvar.applyssorts[manorindex][gvar.semifinal[manorindex][guildindex]].guildId
    gvar.guesss[manorindex][actorid] = {}
    gvar.guesss[manorindex][actorid].choose = guildId
    gvar.guesss[manorindex][actorid].sId = sId
    sendGuessResult(sId, actorid, 1, manorindex, guildId)
end

local function onSendGuess(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local result = LDataPack.readChar(cpack)
    local manorindex = LDataPack.readChar(cpack)
    if result == 0 then
        local config = GBGuessConfig[GBManorIndexConfig[manorindex].level]
        actoritem.addItem(actor, NumericType_YuanBao, config.needyuanbao, "guild battle guess")
        return
    end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_Guess)
    if not npack then return end
    LDataPack.writeChar(npack, manorindex)
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.flush(npack)
end

--发送竞猜奖励
function sendGuessReward(manorindex)
    local gvar = getGlobalData()
    for k,v in pairs(gvar.guesss[manorindex]) do
        local manorlevel = GBManorIndexConfig[manorindex].level
        local config = GBGuessConfig[manorlevel]
        local first = gvar.winguidlids[manorindex] and gvar.winguidlids[manorindex][1] or 0
        if v.choose == first then
            local mail_data = {}
            mail_data.head = config.sucHead
            mail_data.context = string.format(config.sucContext, GBManorIndexConfig[manorindex].name)
            mail_data.tAwardList = config.reward
            mailsystem.sendMailById(k, mail_data, v.sId)
        elseif v.choose and v.choose ~= 0 then
            local mail_data = {}
            mail_data.head = config.failHead
            mail_data.context = string.format(config.failContext, GBManorIndexConfig[manorindex].name)
            mail_data.tAwardList = {{type = 0, id = NumericType_YuanBao, count = config.needyuanbao}}
            mailsystem.sendMailById(k, mail_data, v.sId)
        end
    end
end

--领取每日奖励
function handleGetDailyReward(actor, pack)
    local var = getActorVar(actor)
    if var.dailyget == 2 then return end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_GetDailyReward)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, LActor.getGuildId(actor))
    System.sendPacketToAllGameClient(npack, 0)	
end

local function onGetDailyReward(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local guildId = LDataPack.readInt(cpack)
    local gvar = getGlobalData()
    if not gvar.guildResult[guildId] or not gvar.guildResult[guildId].hongbaoflag then return end
    if gvar.guildResult[guildId].hongbaoflag == 0 then return end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendDailyReward)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, gvar.guildResult[guildId].manorindex)
    LDataPack.writeChar(npack, gvar.guildResult[guildId].rank)
    System.sendPacketToAllGameClient(npack, sId)	
end

local function onSendDailyReward(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local manorindex = LDataPack.readChar(cpack)
    local rank = LDataPack.readChar(cpack)
    local rewards = GBManorConfig[GBManorIndexConfig[manorindex].level][rank].rewardDaily
    if not rewards then return end
    if not actoritem.checkEquipBagSpaceJob(actor, rewards) then
        return
    end
    local var = getActorVar(actor)
    var.dailyget = 2
    
    actoritem.addItems(actor, rewards, "guildbattle dailyrewards")

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendDailyReward)
    if not npack then return end
    LDataPack.writeChar(npack, var.dailyget)
    LDataPack.flush(npack)
end

function getRanndomMoney(data)
    if data.remaincount == 1 then
        data.remaincount = 0
        return data.remainmoney
    end
    local max = math.floor(data.remainmoney/data.remaincount * 2)
    local money = math.random(1, max)
    data.remaincount = data.remaincount - 1
    data.remainmoney = data.remainmoney - money
    return money
end

--领取红包
function handleGetHongbao(actor, pack)
    local actorid = LActor.getActorId(actor)
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_GetHongbao)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeString(npack, LActor.getName(actor))
    LDataPack.writeInt(npack, LActor.getGuildId(actor))
    System.sendPacketToAllGameClient(npack, 0)	
end

local function onGetHongbao(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local name = LDataPack.readString(cpack)
    local guildId = LDataPack.readInt(cpack)

    local gvar = getGlobalData()
    if not gvar.guildResult[guildId] or gvar.guildResult[guildId].hongbaoflag ~= 2 then return end
    local hongbaodata = gvar.hongbao[guildId]
    local getYuanbao = 0
    if hongbaodata.remaincount == 0 then
        getYuanbao = 0 
    else
        if not hongbaodata.record then hongbaodata.record = {} end
        for i=1, #hongbaodata.record do        
            if hongbaodata.record[i].actorid == actorid then
                return
            end
        end

        getYuanbao = getRanndomMoney(hongbaodata)    
        table.insert(hongbaodata.record, {actorid = actorid, count = getYuanbao, name = name})
    end

    sendHongbaoInfo(0, 0, guildId, gvar)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_GetHongbaoRet)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt(npack, getYuanbao)
    System.sendPacketToAllGameClient(npack, sId)
end

local function onGetHongbaoRet(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local getYuanbao = LDataPack.readInt(cpack)
    actoritem.addItem(actor, NumericType_YuanBao, getYuanbao, "guild battle gethongbao")
      
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendHongbao)
    if not npack then return end
    LDataPack.writeChar(npack, 1)
    LDataPack.flush(npack)
end

--设置红包
function handleSetHongbao(actor, pack)
    local count = LDataPack.readChar(pack)
    --if count < GBConstConfig.hongbaocount[1] or count > GBConstConfig.hongbaocount[2] then return end

    local pos = LActor.getGuildPos(actor)
    if pos < smGuildAssistLeader then
        return
    end

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SetHongbao)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, LActor.getGuildId(actor))
    LDataPack.writeChar(npack, count)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onSetHongbao(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local guildId = LDataPack.readInt(cpack)
    local count = LDataPack.readChar(cpack)
    local gvar = getGlobalData()
    local guildResult = gvar.guildResult[guildId]
    if not guildResult or guildResult.hongbaoflag ~= 1 then return end
    guildResult.hongbaoflag = 2
    local hongbaodata = gvar.hongbao[guildId]
    hongbaodata.count = count --红包个数
    hongbaodata.remaincount = count
    hongbaodata.record = {}

    sendHongbaoInfo(0, 0, guildId, gvar)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SetHongbaoRet)
    LDataPack.writeInt(npack, actorid)
    System.sendPacketToAllGameClient(npack, sId)
    local guild = LGuild.getGuildById(guildId)
    if guild then
        guildchat.sendNotice(guild, GBConstConfig.gbtip7, enGuildChatNew)
    end
end

local function onSetHongbaoRet(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SetHongbaoRet)
    if not npack then return end
    LDataPack.writeChar(npack, 1)
    LDataPack.flush(npack)
end

--请求单个领地对战信息
local function handleReqFightList(actor, pack)
    local now = System.getNowTime()
    --if now < BATTLE_STAGE_TIME[1] or now > BATTLE_STAGE_TIME[2] then return end
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_GetFightList)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

function sendFightList(sId, actorid, gvar)
    local gvar = gvar or getGlobalData()
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendFightList)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, GBConstConfig.manorcount)
    local now = System.getNowTime()
    for i=1, GBConstConfig.manorcount do
        if now > BATTLE_STAGE_TIME[4] and now <= BATTLE_STAGE_TIME[6] then
            for j=1, 4 do
                local index = gvar.final[i][j]            
                LDataPack.writeInt(npack, gvar.applyssorts[i][index] and gvar.applyssorts[i][index].guildId or 0)
                LDataPack.writeString(npack, gvar.applyssorts[i][index] and gvar.applyssorts[i][index].guildName or "")
            end                        
        else
            for j=1, 4 do
                local index = gvar.semifinal[i][j]            
                LDataPack.writeInt(npack, gvar.applyssorts[i][index] and gvar.applyssorts[i][index].guildId or 0)
                LDataPack.writeString(npack, gvar.applyssorts[i][index] and gvar.applyssorts[i][index].guildName or "")
            end
        end
        if not gvar.guesss[i][actorid] then gvar.guesss[i][actorid] = {} end
        LDataPack.writeInt(npack, gvar.guesss[i][actorid].choose or 0)
    end
    System.sendPacketToAllGameClient(npack, sId)
end

local function onGetFightList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    sendFightList(sId, actorid)
end

local function onSendFightList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_FightList)
    if not npack then return end
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeChar(npack, i)
        for j=1, 4 do
            LDataPack.writeInt(npack, LDataPack.readInt(cpack))
            LDataPack.writeString(npack, LDataPack.readString(cpack))
        end
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    end
    LDataPack.flush(npack)
end

--请求对战列表
local function handleReqFightInfo(actor, pack)
    local now = System.getNowTime()
    --if now < BATTLE_STAGE_TIME[1] then return end

    local index = LDataPack.readChar(pack)
    if index < 1 or index > GBConstConfig.manorcount then return end

    local type = LDataPack.readChar(pack)
    if type ~= 1 and type ~= 2 then return end
    -- if type == 1 and now > BATTLE_STAGE_TIME[2] then
    --     return
    -- elseif type == 2 and now > BATTLE_STAGE_TIME[5] then
    --     return
    -- end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_GetFightInfo)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeChar(npack, index)
    LDataPack.writeChar(npack, type)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onGetFightInfo(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local index = LDataPack.readChar(cpack)
    local type = LDataPack.readChar(cpack)

    local gvar = getGlobalData()
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendFightInfo)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, index)
    if type == 1 then
        if not gvar.semifinal[index][1] then
            LDataPack.writeChar(npack, 0)            
        else
            LDataPack.writeChar(npack, 2)
            for i=1, 4 do
                local guildindex = gvar.semifinal[index][i]
                if not guildindex then break end   
                local guildinfo = gvar.applyssorts[index][guildindex]
                if not guildinfo then break end
                local guildId = guildinfo.guildId
                LDataPack.writeInt(npack, guildId)
                LDataPack.writeString(npack, guildinfo.guildName)
                if guildId ~= 0 then
                    LDataPack.writeString(npack, LGuild.getLeaderNameById(guildId))
                else
                    LDataPack.writeString(npack, "")
                end
                LDataPack.writeChar(npack, guildinfo.membercount)
                LDataPack.writeChar(npack, guildinfo.level)
                if i%2 == 0 then
                    local ginfo = gvar.applyssorts[index][gvar.semifinal[index][i-1]]
                    if guildinfo.iswin == 1 or ginfo.iswin == 0 then
                        LDataPack.writeChar(npack, 2)
                    elseif guildinfo.iswin == 0 or ginfo.iswin == 1 then
                        LDataPack.writeChar(npack, 1)
                    else
                        LDataPack.writeChar(npack, 0)
                    end                
                end
            end
        end
    else
        if not gvar.final[index][1] then
            LDataPack.writeChar(npack, 0)    
        else
            LDataPack.writeChar(npack, 2)
            for i=1, 4 do
                local guildindex = gvar.final[index][i]
                if not guildindex then break end
                local guildinfo = gvar.applyssorts[index][guildindex]
                if not guildinfo then break end
                local guildId = guildinfo.guildId
                LDataPack.writeInt(npack, guildId)
                LDataPack.writeString(npack, guildinfo.guildName)
                if guildId ~= 0 then
                    LDataPack.writeString(npack, LGuild.getLeaderNameById(guildId))
                else
                    LDataPack.writeString(npack, "")
                end
                LDataPack.writeChar(npack, guildinfo.membercount)
                LDataPack.writeChar(npack, guildinfo.level)   
                if i%2 == 0 then
                    if not guildId or guildId == 0 or not gvar.guildResult[guildId] then
                        LDataPack.writeChar(npack, 0)
                    elseif gvar.guildResult[guildId].rank % 2 == 1 then
                        LDataPack.writeChar(npack, 1)
                    else
                        LDataPack.writeChar(npack, 2)
                    end             
                end      
            end
        end
    end

    System.sendPacketToAllGameClient(npack, sId)
end

local function onSendFightInfo(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)    
    if not actor then return end    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_FightInfo)
    if not npack then return end
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i=1, count do        
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    end    
    LDataPack.flush(npack)
end

local function handleReqFightLeader(actor, pack)
    local now = System.getNowTime()
    --1报名，2竞猜，3初赛准备，4初赛，5决赛准备，6决赛，7结束
    --if not((now > BATTLE_STAGE_TIME[2] and now <= BATTLE_STAGE_TIME[4]) or (now > BATTLE_STAGE_TIME[4] + 3000 and now <= BATTLE_STAGE_TIME[6])) then return end
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then
        return
    end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_GetLeaderInfo)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, guildId)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onGetLeaderInfo(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local guildId = LDataPack.readInt(cpack)

    local gvar = getGlobalData()
    local now = System.getNowTime()    
    if gvar.guildResult[guildId] then return end
    if now >= BATTLE_STAGE_TIME[2] and now <= BATTLE_STAGE_TIME[4] then --初赛        
        print("onGetLeaderInfo  semifinal ", guildId)
        for k,v in ipairs(gvar.applyssorts) do
            local semifinal = gvar.semifinal[k]
            for j=1, #semifinal do         
                if v[semifinal[j]] then
                    if v[semifinal[j]].guildId == guildId then
                        if gvar.applyssorts[k][semifinal[j]].iswin then return end                       
                        if j%2 == 0 then
                            LGuild.getGuildLeaderList(actorid, guildId, semifinal[j+1] and v[semifinal[j+1]] and v[semifinal[j-1]].guildId or 0, sId)
                            return
                        else
                            LGuild.getGuildLeaderList(actorid, guildId, semifinal[j+1] and v[semifinal[j+1]] and v[semifinal[j+1]].guildId or 0, sId)
                            return
                        end
                    end
                end
            end
        end        
    elseif now > BATTLE_STAGE_TIME[4] and now <= BATTLE_STAGE_TIME[6]  then --决赛
        for k,v in ipairs(gvar.applyssorts) do
            print("onGetLeaderInfo  final ", guildId)
            local final = gvar.final[k]
            for j=1, #final do
                if v[final[j]] and v[final[j]].guildId == guildId then
                    if j%2 == 0 then
                        LGuild.getGuildLeaderList(actorid, guildId, final[j-1] and v[final[j-1]] and v[final[j-1]].guildId or 0, sId)
                        return
                    else
                        LGuild.getGuildLeaderList(actorid, guildId, final[j+1] and v[final[j+1]] and v[final[j+1]].guildId or 0, sId)
                        return
                    end
                end
            end
        end
    end
end

local function onSendLeaderInfo(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)    
    if not actor then return end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_FightLeaderInfo)
    if not npack then return end
    LDataPack.writeString(npack, LDataPack.readString(cpack))
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    end

    LDataPack.writeString(npack, LDataPack.readString(cpack))
    count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    end
    LDataPack.flush(npack)    
end

--开始战斗
function handleFight(actor, pack)    
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then
        return
    end
    if not guildbattlecross.GUILD_FUBEN_HANDLE[guildId] then
        local now = System.getNowTime()
        if now > BATTLE_STAGE_TIME[2] and now < BATTLE_STAGE_TIME[4] then
            LActor.sendTipmsg(actor, GBConstConfig.createfbtips, ttScreenCenter)
        else
            LActor.sendTipmsg(actor, GBConstConfig.finishfbtips, ttScreenCenter)
        end
        return
    end

    local crossId = csbase.getCrossServerId()
    local x, y = utils.getSceneEnterByIndex(guildbattlecross.GUILD_FUBEN_HANDLE[guildId].fbId, guildbattlecross.GUILD_FUBEN_HANDLE[guildId].index)
    print("handleFight enter fb handle:", guildbattlecross.GUILD_FUBEN_HANDLE[guildId].hfuben)
    LActor.loginOtherServer(actor, crossId, guildbattlecross.GUILD_FUBEN_HANDLE[guildId].hfuben, 0, x, y, "cross")
end

function onLogin(actor)
    --由于旧的bufferid和称号改为道具获得，所以治理要清掉旧buffer和道具。称号和buffer需要用新的
    for k in pairs(GUILD_BATTLE_BUFFERS) do
        LActor.delSkillEffect(actor, k)
    end
    titlesystem.delitle(actor, GBConstConfig.mtitleid, true)
    titlesystem.delitle(actor, GBConstConfig.ltitleid, true)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ActTime)
    if not npack then return end
    LDataPack.writeChar(npack, 7)
    for i=1, 7 do
        LDataPack.writeInt(npack, BATTLE_STAGE_TIME[i])
    end
    LDataPack.flush(npack)
    local now = System.getNowTime()
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ActStage)
    if not npack then return end
    local ishave = false
    for i=0, 6 do
        if now >= BATTLE_STAGE_TIME[i] and now < BATTLE_STAGE_TIME[i + 1] then
            LDataPack.writeChar(npack, i+1)
            ishave = true
            break
        end
    end
    if not ishave then
        LDataPack.writeChar(npack, 1)
    end
    LDataPack.flush(npack)
end

--得到第一名盟主的显示信息
function getFirstGuildLeaderInfo(guildId)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_GetFirstGuildLeaderInfo)
    LDataPack.writeInt(npack, LGuild.getLeaderIdById(guildId))
    LDataPack.writeInt(npack, 1)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onGetFirstLeaderInfo(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actorData = offlinedatamgr.GetDataByOffLineDataType(actorid, offlinedatamgr.EOffLineDataType.EBasic)
	if actorData==nil then
		return
    end
    local type = LDataPack.readChar(cpack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendFirstGuildLeaderInfo)
    LDataPack.writeChar(npack, type)
    LDataPack.writeChar(npack, actorData.job)
    LDataPack.writeString(npack, actorData.actor_name)
    LDataPack.writeInt(npack, actorData.shenzhuangchoose)
    LDataPack.writeInt(npack, actorData.shenqichoose)
    LDataPack.writeInt(npack, actorData.wingchoose)
    LDataPack.writeInt(npack, actorData.shengling_id)
    LDataPack.writeInt(npack, actorData.meilinchoose)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onSendFirstLeaderInfo(sId, sType, cpack)
    if not System.isBattleSrv() then return end
    local type = LDataPack.readChar(cpack)
    if type == 1 then
        local gvar = getGlobalData()
        gvar.worship.job = LDataPack.readChar(cpack)
        gvar.worship.name = LDataPack.readString(cpack)    
        gvar.worship.shenzhuang = LDataPack.readInt(cpack)
        gvar.worship.shenqi = LDataPack.readInt(cpack)
        gvar.worship.wing = LDataPack.readInt(cpack)
        gvar.worship.shengling = LDataPack.readInt(cpack)
        gvar.worship.meilin = LDataPack.readInt(cpack)
    else
        guildbattlecross.setFirstRankInfo(cpack)
    end
end

function sendBattleStageTime()
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
    LDataPack.writeByte(npack, Protocol.sGuildBattleCmd_ActTime)
    if not npack then return end
    LDataPack.writeChar(npack, 7)
    for i=1, 7 do
        LDataPack.writeInt(npack, BATTLE_STAGE_TIME[i])
    end
    System.broadcastData(npack)
end

function sendBattleStageInfo()
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
    LDataPack.writeByte(npack, Protocol.sGuildBattleCmd_ActStage)
    if not npack then return end
    local now = System.getNowTime()
    local ishave = false
    for i=0, 6 do
        if now >= BATTLE_STAGE_TIME[i] and now < BATTLE_STAGE_TIME[i + 1] then
            LDataPack.writeChar(npack, i+1)
            ishave = true
            break
        end
    end
    if not ishave then
        LDataPack.writeChar(npack, 1)
    end
    System.broadcastData(npack)
end

--领取个人达标积分
function handleGetScoreReward(actor, pack)
    if not System.isBattleSrv() then
        return
    end    
    local index = LDataPack.readChar(pack)
    local config = GBDabiaoRewardConfig[index]
    if not config then
        return
    end
    
    local gvar = getGlobalData()
    local actorid = LActor.getActorId(actor)
    local sindex = 0
    for i=1, #gvar.selfrank do
        if gvar.selfrank[i].actorid == actorid then
            sindex = i
            break
        end
    end
    if sindex == 0 then
        return
    end
    if System.bitOPMask(gvar.selfrank[sindex].scorestatus, index) then
		return
    end
    if gvar.selfrank[sindex].score < config.score then
        return
    end
    if not actoritem.checkEquipBagSpaceJob(actor, config.reward) then
        return
    end
    gvar.selfrank[sindex].scorestatus = System.bitOpSetMask(gvar.selfrank[sindex].scorestatus, index, true)
    actoritem.addItems(actor, config.reward, "guildbattle score rewards")
    sendSelfScore(actor, gvar.selfrank[sindex].score)
end

function sendSelfScore(actor, score)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendSelfScore)
    if not npack then return end
    local gvar = getGlobalData()
    local sindex = 0 
    for k,v in ipairs(gvar.selfrank) do
        if v.actorid == LActor.getActorId(actor) then
            LDataPack.writeInt(npack, v.scorestatus)
            LDataPack.writeInt(npack, v.score)
            sindex = k
            break
        end
    end
    if sindex == 0 then
        LDataPack.writeInt(npack, 0)
        LDataPack.writeInt(npack, 0)
    end    
    LDataPack.flush(npack)    
end

function calcBattleStageTime()
    BATTLE_STAGE_TIME = {}
    local openDay = System.getOpenServerDay()
    local config = GBConstConfig
    --启动时计算各个时间段时间（领地争夺战时间段1报名，2竞猜，3初赛准备，4初赛，5决赛准备，6决赛，7结束）
    if openDay <= 6 then
        local st = System.getOpenServerStartDateTime()
        BATTLE_STAGE_TIME[0] = 0
        BATTLE_STAGE_TIME[1] = st + 24 * 3600 * 2 + config.guesstime[1][1] * 3600 + config.guesstime[1][2] * 60
        BATTLE_STAGE_TIME[2] = st + 24 * 3600 * 2 + config.guesstime[2][1] * 3600 + config.guesstime[2][2] * 60
        BATTLE_STAGE_TIME[3] = st + 24 * 3600 * 2 + config.firstpktime[1][1] * 3600 + config.firstpktime[1][2] * 60
        BATTLE_STAGE_TIME[4] = st + 24 * 3600 * 2 + config.firstpktime[2][1] * 3600 + config.firstpktime[2][2] * 60
        BATTLE_STAGE_TIME[5] = st + 24 * 3600 * 2 + config.secondpktime[1][1] * 3600 + config.secondpktime[1][2] * 60
        BATTLE_STAGE_TIME[6] = st + 24 * 3600 * 2 + config.secondpktime[2][1] * 3600 + config.secondpktime[2][2] * 60
        BATTLE_STAGE_TIME[7] = st + 24 * 3600 * 7
    else
        local week1time = System.getWeekFistTime()
        BATTLE_STAGE_TIME[0] = 0
        BATTLE_STAGE_TIME[1] = week1time + 5 * 24 * 3600 + config.guesstime[1][1] * 3600 + config.guesstime[1][2] * 60
        BATTLE_STAGE_TIME[2] = week1time + 5 * 24 * 3600 + config.guesstime[2][1] * 3600 + config.guesstime[2][2] * 60
        BATTLE_STAGE_TIME[3] = week1time + 5 * 24 * 3600 + config.firstpktime[1][1] * 3600 + config.firstpktime[1][2] * 60
        BATTLE_STAGE_TIME[4] = week1time + 5 * 24 * 3600 + config.firstpktime[2][1] * 3600 + config.firstpktime[2][2] * 60
        BATTLE_STAGE_TIME[5] = week1time + 5 * 24 * 3600 + config.secondpktime[1][1] * 3600 + config.secondpktime[1][2] * 60
        BATTLE_STAGE_TIME[6] = week1time + 5 * 24 * 3600 + config.secondpktime[2][1] * 3600 + config.secondpktime[2][2] * 60
        BATTLE_STAGE_TIME[7] = week1time + 7 * 24 * 3600
	end
end

--战斗时间，不能退出战盟
function isBattleTime()
    local now = System.getNowTime()
    return now >= BATTLE_STAGE_TIME[2] and now <= BATTLE_STAGE_TIME[6]
end

function sendRankInfo(sId)
    local gvar = getGlobalData()
    local npack = LDataPack.allocPacket()    
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendRankInfo)
    LDataPack.writeChar(npack, sId and 0 or 1)
    local count = 0
    for k,v in pairs(gvar.guildResult) do
        count = count + 1
    end
    LDataPack.writeShort(npack, count)
    for k,v in pairs(gvar.guildResult) do
        LDataPack.writeInt(npack, k)
        LDataPack.writeChar(npack, v.manorindex)
        LDataPack.writeChar(npack, v.rank)
    end
    System.sendPacketToAllGameClient(npack, sId or 0)

    for i=1, GBConstConfig.manorcount do
        if #gvar.winguidlids[i] > 0 then
            local npack1 = LDataPack.allocPacket()
            LDataPack.writeByte(npack1, CrossSrvCmd.SCGuildFight)
            LDataPack.writeByte(npack1, CrossSrvSubCmd.SCGuildFightCmd_SendGuildRankInfo)
            LDataPack.writeChar(npack1, i)
            LDataPack.writeChar(npack1, #gvar.winguidlids[i])
            for j=1, #gvar.winguidlids[i] do
                local guildId = gvar.winguidlids[i][j]   
                LDataPack.writeInt(npack1, guildId)
                LDataPack.writeString(npack1, LGuild.getGuilNameById(guildId))
                LDataPack.writeString(npack1, LGuild.getLeaderNameById(guildId))                
            end
            System.sendPacketToAllGameClient(npack1, 0)
        end
    end
    --战盟聊天发送排名信息
    for k,v in pairs(gvar.guildResult) do
        local guild = LGuild.getGuildById(k)
        if guild then
            guildchat.sendNotice(guild, string.format(GBConstConfig.gbtip6, GBManorIndexConfig[v.manorindex].name, v.rank), enGuildChatNew)
        end
    end
    broWorshipActor(0, 0)
end

local function onSendGuildRankInfo(sId, sType, cpack)
    local manorindex = LDataPack.readChar(cpack)
    local count = LDataPack.readChar(cpack)
    local tmp = {}
    for i=1, count do
        tmp[i] = {}
        tmp[i].guildId = LDataPack.readInt(cpack)
        tmp[i].guildname = LDataPack.readString(cpack)
        tmp[i].leadername = LDataPack.readString(cpack)
    end
    for i=1, #tmp do
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
        LDataPack.writeByte(npack, Protocol.sGuildBattleCmd_FinishFight)
        LDataPack.writeChar(npack, manorindex)
        LDataPack.writeChar(npack, #tmp)
        for j=1, #tmp do
            LDataPack.writeInt(npack, tmp[j].guildId)
            LDataPack.writeString(npack, tmp[j].guildname)
            LDataPack.writeString(npack, tmp[j].leadername)
        end
        LGuild.broadcastData(tmp[i].guildId, npack)
    end

    local actors = System.getOnlineActorList()
    if not actors then return end
    for i=1, #actors do
        local actor = actors[i]
        local guildId = LActor.getGuildId(actor)
        if guildId ~= 0 then
            local var = guildbattlesystem.getActorVar(actor)
            local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendDailyReward)
            if not npack then return end
            LDataPack.writeChar(npack, var.dailyget >= 1 and var.dailyget or 1)
            LDataPack.flush(npack)
        end
    end
end

local function onSendRankInfo(sId, sType, cpack)
    local needUpdate = LDataPack.readChar(cpack)
    BATTLE_RANK_INFO = {}
    local count = LDataPack.readShort(cpack)
    for i=1, count do
        local guildId = LDataPack.readInt(cpack)
        BATTLE_RANK_INFO[guildId] = {}
        BATTLE_RANK_INFO[guildId].manorindex = LDataPack.readChar(cpack)
        BATTLE_RANK_INFO[guildId].rank = LDataPack.readChar(cpack)
    end
end

function sendRankReward(guildId, manorindex, rank)
    local manorlevel = GBManorIndexConfig[manorindex].level
    local guild = LGuild.getGuildById(guildId)
    print("guildbattlesystem sendRankReward :", guildId, manorindex, rank)
    local actoridList = LGuild.getMemberIdList(guild)
    local config = GBManorConfig[manorlevel][rank]
    if actoridList and config then
        local reward1 = {}
        local reward2 = {}
        for k,v in ipairs(config.rewardRank) do
            table.insert(reward1, v)
            table.insert(reward2, v)
        end
        if #config.titleReward > 0 then
            table.insert(reward1, config.titleReward[1])
        end
        if #config.titleReward > 0 then
            table.insert(reward2, config.titleReward[2])
        end
        for j=1, #actoridList do            
            local context = string.format(GBConstConfig.resultcontext,  GBManorIndexConfig[manorindex].name, rank)
            local mailData = {}
            if LGuild.getGuildPos(guild, actoridList[j]) == smGuildLeader then
                mailData = {head = GBConstConfig.resulthead, context = context, tAwardList=reward1}
            else
                mailData = {head = GBConstConfig.resulthead, context = context, tAwardList=reward2}
            end
            mailsystem.sendMailById(actoridList[j], mailData, 0)
        end
    end
    sendHongbaoInfo(0, 0, guildId)
end

local function onConnected(sId, sType)
    if not System.isBattleSrv() then return end
    sendRankInfo(sId)
end

--启动时计算各个时间段时间（领地争夺战时间段1报名，2竞猜，3初赛准备，4初赛，5决赛准备，6决赛，7结束）
local function onGameStart()
    calcBattleStageTime()
end

function onNewDay(actor, login)
    local var = getActorVar(actor)
    var.dailyget = 0
    var.worshiptimes = 0
    if not login then
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendDailyReward)
        if not npack then return end
        LDataPack.writeChar(npack, var.dailyget)
        LDataPack.flush(npack)
    end
end

actorevent.reg(aeNewDayArrive, onNewDay)

local function init()
    GUILD_BATTLE_BUFFERS = {}
    for k,v in ipairs(GBManorConfig) do
        for kk, vv in ipairs(v) do
            for kkk,vvv in ipairs(vv.buffer) do
                GUILD_BATTLE_BUFFERS[vvv] = true
            end            
        end
    end
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetSelfRank, guildbattlecross.handleSelfRank)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_Worship, handleWorship)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetScoreReward, handleGetScoreReward)
	if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetApplyList, handleGetApplyList)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_Guess, handleGuildGuess)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetDailyReward, handleGetDailyReward)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetHongbao, handleGetHongbao)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SetHongbao, handleSetHongbao)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_ReqFightInfo, handleReqFightInfo)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_ReqFightList, handleReqFightList)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_ReqFightLeader, handleReqFightLeader)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_Fight, handleFight)
end
table.insert(InitFnTable, init)

actorevent.reg(aeUserLogin, onLogin)
csbase.RegConnected(onConnected)
engineevent.regGameStartEvent(onGameStart)
insevent.registerInstanceEnter(0, onEnterMainFb)

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendManorList, onSendManorList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_Guess, onGuess)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendGuess, onSendGuess)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_GetDailyReward, onGetDailyReward)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendDailyReward, onSendDailyReward)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_GetApplyList, onGetApplyList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_GetHongbao, onGetHongbao)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_GetHongbaoRet, onGetHongbaoRet)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SetHongbao, onSetHongbao)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SetHongbaoRet, onSetHongbaoRet)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_GetFightList, onGetFightList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendFightList, onSendFightList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_GetFightInfo, onGetFightInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendFightInfo, onSendFightInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_GetLeaderInfo, onGetLeaderInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendLeaderInfo, onSendLeaderInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendBaseInfo, onSendBaseInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendWorship, onSendWorship)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendHongbaoInfo, onSendHongbaoInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_GetFirstGuildLeaderInfo, onGetFirstLeaderInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendFirstGuildLeaderInfo, onSendFirstLeaderInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendRankInfo, onSendRankInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendGuildRankInfo, onSendGuildRankInfo)



local gmCmdHandlers = gmsystem.gmCmdHandlers
function gmCmdHandlers.gbupdate(actor, args)
    local stage = tonumber(args[1])
    print("gmCmdHandlers.gbupdate", stage)
    for i=1, 7 do
        BATTLE_STAGE_TIME[i] = 0
    end
    -- BATTLE_STAGE_TIME[1] = st + 24 * 3600 + config.guesstime[1][1] * 3600 + config.guesstime[1][2] * 60
    -- BATTLE_STAGE_TIME[2] = st + 24 * 3600 + config.guesstime[2][1] * 3600 + config.guesstime[2][2] * 60
    -- BATTLE_STAGE_TIME[3] = st + 24 * 3600 + config.firstpktime[1][1] * 3600 + config.firstpktime[1][2] * 60
    -- BATTLE_STAGE_TIME[4] = st + 24 * 3600 + config.firstpktime[2][1] * 3600 + config.firstpktime[2][2] * 60
    -- BATTLE_STAGE_TIME[5] = st + 24 * 3600 + config.secondpktime[1][1] * 3600 + config.secondpktime[1][2] * 60
    -- BATTLE_STAGE_TIME[6] = st + 24 * 3600 + config.secondpktime[2][1] * 3600 + config.secondpktime[2][2] * 60
    -- BATTLE_STAGE_TIME[7] = st + 24 * 3600 * 2
    BATTLE_STAGE_TIME[stage - 1] = System.getNowTime() - 1800
    BATTLE_STAGE_TIME[stage] = System.getNowTime() +1800
    BATTLE_STAGE_TIME[stage + 1] = System.getNowTime() + 3600
    sendBattleStageInfo()
    sendBattleStageTime()

    if System.isBattleSrv() then
        if stage == 4 or stage == 6 then
            guildbattlecross.openGuildBattle1(true)
        end
    else
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
        LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_UpdateStage)
        LDataPack.writeByte(npack, stage)
        System.sendPacketToAllGameClient(npack, 0)
    end
    print(" gmCmdHandlers.gbupdate end")
    return true
end

local function onGMUpdateStage(sId, sType, cpack)
    if not System.isBattleSrv() then return end
    local stage = LDataPack.readChar(cpack)
    for i=1, 7 do
        BATTLE_STAGE_TIME[i] = 0
    end
    BATTLE_STAGE_TIME[stage - 1] = System.getNowTime() - 1800
    BATTLE_STAGE_TIME[stage] = System.getNowTime() + 1800
    BATTLE_STAGE_TIME[stage + 1] = System.getNowTime() + 3600
    --（领地争夺战时间段1报名，2竞猜，3初赛准备，4初赛，5决赛准备，6决赛，7结束）
    if stage == 1 then
        local gvar = getGlobalData()
        for i=1, 6 do
            gvar.applyssorts[i] = {} --排序后的战盟列表
            gvar.guesss[i] = {}  --竞猜信息
            gvar.semifinal[i] = {}
            gvar.final[i] = {}
        end
        calcBattleStageTime()
        sendBattleStageInfo()
    elseif stage == 2 then
        guildbattlecross.guildBattleGuess(true)
    elseif stage == 3 then
        guildbattlecross.enterGuildBattle1(true)
    elseif stage == 4 then
        guildbattlecross.openGuildBattle1(true)
    elseif stage == 5 then
        guildbattlecross.enterGuildBattle2(true)
    elseif stage == 6 then
        guildbattlecross.openGuildBattle2(true)
    elseif stage == 7 then
        guildbattlecross.guildBattleStop(true)
    end
    sendBattleStageTime()
end

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_UpdateStage, onGMUpdateStage)

