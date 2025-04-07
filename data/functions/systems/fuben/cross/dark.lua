--暗黑神殿（本服）

module("dark", package.seeall)
--[[
    [id] = {
        refreshtime = 0 -- 刷新时间点
        hfuben = 0
    }
]]
DARK_DATA = DARK_DATA or {} -- 跨服同步的数据

local function getData(actor)
    return darkcross.getVar(actor)
end

local function s2cDarkBossList(actor)
    if next(DARK_DATA) == nil then
        return
    end
    
    local var = getData(actor)
    if var.remind_list == nil then
        var.remind_list = {}
    end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsDarkBoss_Info)
    if npack == nil then return end
    LDataPack.writeChar(npack, #DarkFubenConfig)
    for id, conf in pairs(DarkFubenConfig) do
        local info = DARK_DATA[id]
        local mon_conf = MonstersConfig[conf.bossId]
        LDataPack.writeChar(npack, id)
        LDataPack.writeString(npack, mon_conf.name)
        LDataPack.writeString(npack, mon_conf.head)
        LDataPack.writeShort(npack, mon_conf.avatar[1])
        LDataPack.writeInt(npack, info and info.refreshtime or 0)
        LDataPack.writeChar(npack, info and info.hpPercent or 0)
        LDataPack.writeChar(npack, var.remind_list[id] or 0)
    end
    LDataPack.writeShort(npack, math.max(var.challengeCd - System.getNowTime(), 0))
    LDataPack.flush(npack)
end

local function c2sDarkBossList(actor, reader)
    return s2cDarkBossList(actor)
end

local function s2cRemind(actor, id, v)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsDarkBoss_SetRemind)
    if npack == nil then return end
    LDataPack.writeChar(npack, id)
    LDataPack.writeChar(npack, v)
    LDataPack.flush(npack)
end

local function c2sDarkBossRemind(actor, reader)
    local id = LDataPack.readChar(reader)
    local v = LDataPack.readChar(reader)
    local var = getData(actor)
    var.remind_list[id] = v
    s2cRemind(actor, id, v)
end

local function fight(actor, id)
    local conf = DarkFubenConfig[id]
    if conf == nil then
        print('DarkBoss.fight conf==nil id=' .. id)
        return
    end
    
    local info = DARK_DATA[id]
    if info == nil then
        print('DarkBoss.fight info==nil id=' .. id)
        return
    end
    
    local var = getData(actor)
    if System.getNowTime() < (var.challengeCd or 0) then --检查cd
        return
    end
    
    if smzlsystem.getSMZLLevel(actor) < conf.stage then
        print('DarkBoss.fight check SMZLLevel fail SMZLLevel=', smzlsystem.getSMZLLevel(actor), ' conf.stage =', conf.stage)
        return
    end
    
    local x, y = utils.getSceneEnterCoor(conf.fbId)
    LActor.loginOtherServer(actor, info.serverId, info.hfuben, 0, x, y, 'DarkBoss')
end

local function c2sDarkBossFight(actor, reader)
    local id = LDataPack.readChar(reader)
    
    if not actorlogin.checkCanEnterCross(actor) then return end
    if not staticfuben.canEnterFuben(actor) then return end
    fight(actor, id)
end

local function broadcastBossInfo(id)
    local info = DARK_DATA[id]
    if info == nil then
        return
    end
    
    local npack = LDataPack.allocPacket()
    if npack then
        LDataPack.writeByte(npack, Protocol.CMD_Cross)
        LDataPack.writeByte(npack, Protocol.sCsDarkBoss_BossInfo)
        LDataPack.writeChar(npack, id)
        LDataPack.writeChar(npack, info.hpPercent)
        LDataPack.writeInt(npack, info.refreshtime)
        System.broadcastData(npack)
    end
end

local function onCrossBossInfo(sId, sType, pack)
    local count = LDataPack.readShort(pack)
    --print('DarkBoss.onCrossBossInfo sId=' .. sId .. ' sType=' .. sType .. ' count=' .. count)
    for i = 1, count do
        local id = LDataPack.readInt(pack)
        local refreshtime = LDataPack.readInt(pack)
        local hfuben = LDataPack.readInt64(pack)
        local hpPercent = LDataPack.readChar(pack)
        DARK_DATA[id] = {
            refreshtime = refreshtime,
            hfuben = hfuben,
            serverId = sId,
            hpPercent = hpPercent,
        }
        
        if count == 1 then -- 启动时不会为1
            broadcastBossInfo(id)
        end
        
        --print('DarkBoss.onCrossBossInfo id =', id, 'refreshtime =', refreshtime, "hpPercent =", hpPercent)
    end
end

function onSMZLStageUp(actor, old, new)
    local ischange = false
    local tbl = {}
    for idx, conf in ipairs(DarkFubenConfig) do
        if old < conf.stage and new >= conf.stage then
            table.insert(tbl, idx)
            ischange = true
        end
    end
    if ischange then
        local var = getData(actor)
        var.remind_list = {}
        for _, id in ipairs(tbl) do
            var.remind_list[id] = 1
        end
        s2cDarkBossList(actor)
    end
end

function onUpdateDarkBlood(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local id = LDataPack.readByte(dp)
    local hpPercent = LDataPack.readByte(dp)
    if DARK_DATA[id] and DARK_DATA[id].hpPercent then
        DARK_DATA[id].hpPercent = hpPercent
    end
end

local function onLogin(actor)
    s2cDarkBossList(actor)
    darkcross.s2cBelongTimes(actor)
end

local function initGlobalData()
    if System.isLianFuSrv() then return end
    actorevent.reg(aeUserLogin, onLogin)
    
    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsDarkBoss_Info, c2sDarkBossList) -- 查看boss信息
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsDarkBoss_SetRemind, c2sDarkBossRemind) -- 设置提醒或自动挑战
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsDarkBoss_Fight, c2sDarkBossFight) -- 挑战boss
    
    csmsgdispatcher.Reg(CrossSrvCmd.SCDarkCmd, CrossSrvSubCmd.SCdarkCmd_SendDarkBossInfo, onCrossBossInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCDarkCmd, CrossSrvSubCmd.SCdarkCmd_UpdateDarkBlood, onUpdateDarkBlood)
end
table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers
function gmCmdHandlers.DarkFb(actor, args)
    local id = tonumber(args[1]) or 1
    LActor.setZhuansheng(actor, 10704)
    LActor.setSVipLevel(actor, 1)
    fight(actor, id, 0)
    -- LActor.setSVipLevel(actor, 0)
    return true
end

function gmCmdHandlers.DarkOpenBox(actor, args)
    local id = tonumber(args[1]) or 1
    local stype = tonumber(args[2]) or 0
    local var = getData(actor)
    var[id] = System.getNowTime() + 10
    darkcross.openBox(actor, id, stype)
    return true
end

function gmCmdHandlers.DarkClear(actor, args)
    local var = getData(actor)
    var.svip_use = 0
    return true
end
