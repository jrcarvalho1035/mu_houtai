--领地争夺战报名
module("guildbattleapply", package.seeall)

GUILD_FLAG = GUILD_FLAG or {}

function checkCanApply()
    local curtime = System.getNowTime()
    if curtime < guildbattlesystem.BATTLE_STAGE_TIME[1] then
        return true
    end
    return false
end

function c2sApply(actor, pack)
    local manorindex = LDataPack.readChar(pack)
    if not GBManorIndexConfig[manorindex] then return end
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then
        return
    end
    local pos = LActor.getGuildPos(actor)
    if pos < smGuildAssistLeader then
        return
    end
    if not checkCanApply() then
        return
    end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_ApplyBattle)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, guildId)
    LDataPack.writeChar(npack, manorindex)
    System.sendPacketToAllGameClient(npack, 0)
end

function onApplyBattle(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local guildId = LDataPack.readInt(cpack)
    local manorindex = LDataPack.readChar(cpack)
    local gvar = guildbattlesystem.getGlobalData()
    if not gvar.applyssorts[manorindex] then
        return
    end
    for k,v in ipairs(gvar.applyssorts) do
        for kk,vv in ipairs(v) do
            if vv.guildId == guildId and manorindex ~= k then --只能报名一个领地
                return
            end
        end
    end

    local ishave = false
    for i=1, #gvar.applyssorts[manorindex] do
        if gvar.applyssorts[manorindex][i].guildId == guildId then
            table.remove(gvar.applyssorts[manorindex], i)
            ishave = true
            break
        end
    end
    local guild = LGuild.getGuildById(guildId)
    if not ishave then        
        table.insert(gvar.applyssorts[manorindex], {guildId = guildId, power = LGuild.getGuildTotalPower(guildId), membercount = LGuild.getGuildMemberCount(guild), 
        level = guildcommon.getGuildLevel(guild), guildName = LGuild.getGuilNameById(guildId)})
    end

    sortGuildBattleList(manorindex)
    guildbattlesystem.sendManorList(sId, actorid, guildId, gvar)

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_ApplyResult)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, manorindex)
    LDataPack.writeChar(npack, ishave and 0 or 1)
    System.sendPacketToAllGameClient(npack, 0)		
    print(" onApplyBattle apply", actorid, guildId, ishave and 0 or 1)
end

local function onApplyResult(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_Apply)
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.flush(npack)
end

--对报名公会进行排序，如果在第一个进入了前四名，则后面的就不在前四名
function sortGuildBattleList(manorindex)
    GUILD_FLAG = {}
    local gvar = guildbattlesystem.getGlobalData()
    table.sort(gvar.applyssorts[manorindex], function(a, b) return a.power > b.power end)
    -- for i=#gvar.applyssorts[manorindex], 4 do
    --     gvar.applyssorts[manorindex][i] = {guildId = 0, guildName = "", membercount = 0, level = 0, power = 0}
    -- end
end

function deleteGuild(guildId)
    local gvar = guildbattlesystem.getGlobalData()
    for i=1, #GBManorIndexConfig do
        if gvar.applyssorts[i] then
            for j=1, #gvar.applyssorts[i] do
                if gvar.applyssorts[i][j] and gvar.applyssorts[i][j].guildId == guildId then
                    table.remove(gvar.applyssorts[i], j)
                    return
                end
            end
        end
    end    
end

--更新战盟总战力
function updateGuildPower()
    local powers = {}
    local actors = System.getOnlineActorList()
    if not actors then return end
    local len = 0
    for i=1, #actors do
        local actor = actors[i]
        local guildId = LActor.getGuildId(actor)        
        if guildId ~= 0 then
            len = len + 1
            powers[len] = {}
            powers[len].guildId = guildId
            powers[len].actorid = LActor.getActorId(actor)
            powers[len].power = LActor.getActorData(actor).total_power
        end
    end

    local powerDataUd = bson.encode(powers)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_UpdateActorsPower)
    LDataPack.writeUserData(npack, powerDataUd)
    System.sendPacketToAllGameClient(npack, 0)		
end

--跨服汇总战盟总战力
function onUpdateGuildPower(sId, sType, cpack)
    local powerDataUd = LDataPack.readUserData(cpack)
    local powerdata = bson.decode(powerDataUd)
    for i=1, #powerdata do
        if powerdata[i] then
            LGuild.changeActorPower(powerdata[i].actorid, powerdata[i].guildId, powerdata[i].power)
        end
    end
    local gvar = guildbattlesystem.getGlobalData()
    for i=1, #GBManorIndexConfig do        
        if gvar.applyssorts[i] then
            for k,v in ipairs(gvar.applyssorts[i]) do
                if v.guildId ~= 0 then
                    local guild = LGuild.getGuildById(v.guildId)
                    v.power = LGuild.getGuildTotalPower(v.guildId)
                    v.membercount = LGuild.getGuildMemberCount(guild)
                    v.level = guildcommon.getGuildLevel(guild)
                end
            end
            sortGuildBattleList(i)
        end        
    end    
end


local function onInit()
    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_Apply, c2sApply) --报名参加领地争夺战
end
table.insert(InitFnTable, onInit)


csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_UpdateActorsPower, onUpdateGuildPower)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_ApplyBattle, onApplyBattle)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_ApplyResult, onApplyResult)







