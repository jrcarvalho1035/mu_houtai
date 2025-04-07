--神魔Boss圣殿（本服）
--跨服BOSS之家
module("shenmoboss", package.seeall)
--[[
    [id] = {
        refreshtime = 0 -- 刷新时间点
        hfuben = 0
    }
]]
BOSS_DATA = BOSS_DATA or {} -- 跨服同步的数据

local function getData(actor)
    return shenmobosscross.getVar(actor)
end

local function s2cShenmoBossList(actor)
    if next(BOSS_DATA) == nil then
        return
    end

    local var = getData(actor)
    if var.remind_list == nil then
        var.remind_list = {}
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.cCsShenmoBoss_Info)
	if npack == nil then return end
	LDataPack.writeChar(npack, #ShenmoFubenConfig)
    for id, conf in pairs(ShenmoFubenConfig) do
        local info = BOSS_DATA[id]
        local mon_conf = MonstersConfig[conf.bossId]
		LDataPack.writeChar(npack, id)
		LDataPack.writeString(npack, mon_conf.name)
        LDataPack.writeString(npack, mon_conf.head)
        LDataPack.writeShort(npack, mon_conf.avatar[1])
        LDataPack.writeInt(npack, info and info.refreshtime or 0)
        LDataPack.writeChar(npack, var.remind_list[id] or 0)
	end
	LDataPack.flush(npack)
end

local function c2sShenmoBossList(actor, reader)
    return s2cShenmoBossList(actor)
end

local function s2cRemind(actor, id, v)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsShenmoBoss_SetRemind)
    if npack == nil then return end
    LDataPack.writeChar(npack, id)
    LDataPack.writeChar(npack, v)
    LDataPack.flush(npack)
end

local function c2sShenmoBossRemind(actor, reader)
    local id = LDataPack.readChar(reader)
    local v = LDataPack.readChar(reader)
    local var = getData(actor)
    var.remind_list[id] = v
    s2cRemind(actor, id, v)
end

local function fight(actor, id, stype)
    local conf = ShenmoFubenConfig[id]
    if conf == nil then
        print('shenmoboss.fight conf==nil id=' .. id)
        return
    end

    local info = BOSS_DATA[id]
    if info == nil then
        print('shenmoboss.fight info==nil id=' .. id)
        return
    end

    if LActor.getZhuansheng(actor) < conf.zslv then
        print('shenmoboss.fight conf.zslv=' .. conf.zslv .. ' id=' .. id)
        return
    end

    if LActor.getSVipLevel(actor) < conf.svip then
        if stype == 0 then
            print('shenmoboss.fight stype==0 conf.svip=' .. conf.svip .. ' id=' .. id)
            return
        else
            if not actoritem.checkItem(actor, NumericType_Diamond, conf.diamond) then
                print('shenmoboss.fight check diamond fail conf.svip=' .. conf.svip .. ' id=' .. id)
                return
            end
        end
    end

    if stype ~= 0 then -- 消耗点券
        actoritem.reduceItem(actor, NumericType_Diamond, conf.diamond, "shenmoboss fight")
    end
    --actorevent.onEvent(actor, aeEnterFuben, conf.fbId, false)
    local x, y = utils.getSceneEnterCoor(conf.fbId)
    LActor.loginOtherServer(actor, info.serverId, info.hfuben, 0, x, y, 'shenmoboss')
end

local function c2sShenmoBossFight(actor, reader)
    local id = LDataPack.readChar(reader)
    local stype = LDataPack.readChar(reader)

    if not actorlogin.checkCanEnterCross(actor) then return end
    if not staticfuben.canEnterFuben(actor) then return end
    fight(actor, id, stype)
end

local function broadcastBossInfo(id)
    local info = BOSS_DATA[id]
    if info == nil then
        return
    end

    local npack = LDataPack.allocPacket()
    if npack then
        LDataPack.writeByte(npack, Protocol.CMD_Cross)
        LDataPack.writeByte(npack, Protocol.sCsShenmoBoss_BossInfo)
        LDataPack.writeChar(npack, id)
        LDataPack.writeInt(npack, info.refreshtime)
        System.broadcastData(npack)
    end
end

local function onCrossBossInfo(sId, sType, pack)
    local count = LDataPack.readShort(pack)
    --print('shenmoboss.onCrossBossInfo sId=' .. sId .. ' sType=' .. sType .. ' count=' .. count)
    for i = 1, count do
        local id = LDataPack.readInt(pack)
        local refreshtime = LDataPack.readInt(pack)
        local hfuben = LDataPack.readInt64(pack)
        BOSS_DATA[id] = {
            refreshtime = refreshtime,
            hfuben = hfuben,
            serverId = sId,
        }

        if count == 1 then -- 启动时不会为1
            broadcastBossInfo(id)
        end

        --print('shenmoboss.onCrossBossInfo id=' .. id .. ' refreshtime=' .. refreshtime)
    end
end

local function onLogin(actor)
    s2cShenmoBossList(actor)
    shenmobosscross.s2cSvipUse(actor)
end

local function initGlobalData()
    if System.isLianFuSrv() then return end
    actorevent.reg(aeUserLogin, onLogin)

    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsShenmoBoss_Info, c2sShenmoBossList) -- 查看boss信息
	netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsShenmoBoss_SetRemind, c2sShenmoBossRemind) -- 设置提醒或自动挑战
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsShenmoBoss_Fight, c2sShenmoBossFight) -- 挑战boss

    csmsgdispatcher.Reg(CrossSrvCmd.SCShenMoCmd, CrossSrvSubCmd.SCShenMoBossCmd_SendServerBossInfo, onCrossBossInfo)
end
table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers
function gmCmdHandlers.shenmoFb(actor, args)
    local id = tonumber(args[1]) or 1
    LActor.setZhuansheng(actor, 10704)
    LActor.setSVipLevel(actor, 1)
    fight(actor, id, 0)
    -- LActor.setSVipLevel(actor, 0)
    return true
end

function gmCmdHandlers.shenmoOpenBox(actor, args)
    local id = tonumber(args[1]) or 1
    local stype = tonumber(args[2]) or 0
    local var = getData(actor)
    var[id] = System.getNowTime() + 10
    shenmobosscross.openBox(actor, id, stype)
    return true
end

function gmCmdHandlers.shenmoClear(actor, args)
    local var = getData(actor)
    var.svip_use = 0
    return true
end
