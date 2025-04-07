--副本内boss信息
module("bossinfo", package.seeall)

--[[
boss_info = {
notifylist = {
    [actorid] = actor
}
damagelist = {
[actorid] = {name, damage}
 },
 damagerank = {
{id, name,damage}[]
 }
 id,
 hp,
 src_hdl,
 tar_hdl,
 need_update,
 }
--]]
local p = Protocol
local INTERVAL = 1

function getDdamageRank(ins)
    onTimer(ins, System.getNowTime(), true)
    return ins.boss_info.damagerank
end

function getBossDamage(actor, ins)
    --local info = ins and ins.boss_info and ins.boss_info.damagelist and ins.boss_info.damagelist[LActor.getActorId(actor)]
    local damage = 0
    if not (ins and ins.boss_info) then return damage end
    for _, bossInfo in pairs(ins.boss_info) do
        if not bossInfo.damagelist then break end
        local info = bossInfo.damagelist[LActor.getActorId(actor)]
        damage = info and info.damage or 0
        break
    end
    return damage
end

local function onDamage(ins, selfid, curhp, maxhp, damage, attacker, boss, isInShield)
    local config = FubenGroupAlias[ins.config.group]
    if config and config.isNotifyDamage == 0 then return end
    local actorid = LActor.getEntityActorId(attacker)
    if actorid == -1 then return end
    
    if ins.boss_info == nil then ins.boss_info = {} end
    if ins.boss_info[selfid] == nil then ins.boss_info[selfid] = {} end
    local bossinfo = ins.boss_info[selfid]
    if bossinfo.notifylist == nil then bossinfo.notifylist = {} end
    if bossinfo.damagelist == nil then bossinfo.damagelist = {} end
    
    if not bossinfo.notifylist[actorid] then
        bossinfo.notifylist[actorid] = LActor.getActorById(actorid)
    end
    
    local info = bossinfo.damagelist[actorid]
    if info == nil then
        bossinfo.damagelist[actorid] = {name = LActor.getName(attacker), damage = damage}
    else
        info.damage = info.damage + damage
    end
    
    bossinfo.hp = curhp
    bossinfo.hpMax = maxhp
    bossinfo.id = selfid
    bossinfo.need_update = true
    
    if not isInShield then
        bossinfo.hp = curhp - damage
    end
    if curhp <= 0 or ins.config.isPublic == 0 then
        onTimer(ins, System.getNowTime(), true)
    end
end

function bossHpReset(ins, monster)
    if not ins.boss_info then return end
    local monsterid = Fuben.getMonsterId(monster)
    local bossinfo = ins.boss_info[monsterid]
    if not bossinfo then return end
    if bossinfo.hp then
        bossinfo.hp = LActor.getHp(monster)
        for _, actor in pairs(bossinfo.notifylist) do
            notify(ins, actor, bossinfo)
        end
    end
end

function createBossInfo(ins, selfid, monster)
    local config = FubenGroupAlias[ins.config.group]
    if config and config.isNotifyDamage == 0 then return end
    if ins.boss_info == nil then ins.boss_info = {} end
    if ins.boss_info[selfid] == nil then ins.boss_info[selfid] = {} end
    local bossinfo = ins.boss_info[selfid]
    bossinfo.damagelist = {}
    bossinfo.notifylist = {}
    
    bossinfo.hp = LActor.getHp(monster)
    bossinfo.hpMax = LActor.getHpMax(monster)
    bossinfo.id = selfid
    bossinfo.need_update = false
    return bossinfo
end

function onShieldOutput(ins, monster, value, attacker)
    local monid = Fuben.getMonsterId(monster)
    local curhp = LActor.getHp(monster)
    local maxhp = LActor.getHpMax(monster)
    onDamage(ins, monid, curhp, maxhp, value, attacker, monster, true)
end

local function sortDamage(boss_info)
    if boss_info == nil then return end
    if boss_info.damagelist == nil then return end
    boss_info.damagerank = {}
    for aid, v in pairs(boss_info.damagelist) do
        table.insert(boss_info.damagerank, {id = aid, name = v.name, damage = v.damage})
    end
    table.sort(boss_info.damagerank, function(a, b)
        return a.damage > b.damage
    end)
    
end

local function onChangeTarget(ins, src_hdl, tarHdl, boss)
    if ins.boss_info == nil then return end
    local bossId = Fuben.getMonsterId(boss)
    local bossinfo = ins.boss_info[bossId]
    if not bossinfo then return end
    bossinfo.hp = LActor.getHp(boss)
    bossinfo.hpMax = LActor.getHpMax(boss)
    bossinfo.need_update = true
end

--c++回调接口

_G.onBossDamage = function(fbhdl, selfid, curhp, maxhp, damage, attacker, boss)
    local ins = instancesystem.getInsByHdl(fbhdl)
    if ins then
        onDamage(ins, selfid, curhp, maxhp, damage, attacker, boss)
    end
end

_G.onBossChangeTarget = function(fbhdl, src_hdl, tarHdl, boss)
    local ins = instancesystem.getInsByHdl(fbhdl)
    if ins then
        onChangeTarget(ins, src_hdl, tarHdl, boss)
    end
end

--instance回调接口
function notify(ins, actor, bossinfo)
    if not ins or not actor or not bossinfo then return end
    if not bossinfo.id then return end
    local npack = LDataPack.allocPacket(actor, p.CMD_AllFuben, p.sFubenCmd_InsBossHp)
    if npack == nil then return end
    
    local bossId = bossinfo.id
    LDataPack.writeInt(npack, bossId)
    LDataPack.writeDouble(npack, bossinfo.hp)
    if bossinfo.damagerank == nil then
        LDataPack.writeShort(npack, 0)
    else
        LDataPack.writeShort(npack, #bossinfo.damagerank)
        for i = 1, #bossinfo.damagerank do
            LDataPack.writeInt(npack, bossinfo.damagerank[i].id)
            LDataPack.writeString(npack, bossinfo.damagerank[i].name)
            LDataPack.writeDouble(npack, bossinfo.damagerank[i].damage)
        end
    end
    LDataPack.writeInt(npack, ins.id)
    local conf = MonstersConfig[bossId]
    LDataPack.writeString(npack, conf.name)
    LDataPack.writeString(npack, conf.head)
    LDataPack.writeInt(npack, conf.level)
    LDataPack.writeDouble(npack, bossinfo.hpMax or conf.HpMax)
    LDataPack.flush(npack)
end

function onEnter(ins, actor)
    if ins.boss_info == nil then return end
    if Fuben.checkFubenSign(ins.handle, FubenSign_BossArea) then return end
    local actorid = LActor.getActorId(actor)
    for _, bossinfo in pairs(ins.boss_info) do
        bossinfo.notifylist[actorid] = actor
        --notify(ins, actor, bossinfo)
    end
end

function onExit(ins, actor)
    if ins.boss_info == nil then return end
    local actorid = LActor.getActorId(actor)
    for _, bossinfo in pairs(ins.boss_info) do
        if bossinfo.notifylist[actorid] then
            bossinfo.notifylist[actorid] = nil
        end
    end
end

function onEnerBossArea(ins, actor, bossId)
    local config = FubenGroupAlias[ins.config.group]
    if config and config.isNotifyDamage == 0 then return end
    if ins.boss_info == nil then ins.boss_info = {} end
    local bossinfo = ins.boss_info[bossId]
    if not bossinfo then
        local handle = ins.scene_list[1]
        local scene = Fuben.getScenePtr(handle)
        local monster = Fuben.getSceneMonsterById(scene, bossId)
        bossinfo = createBossInfo(ins, bossId, monster)
    end
    local actorid = LActor.getActorId(actor)
    bossinfo.notifylist[actorid] = actor
    notify(ins, actor, bossinfo)
end

function onExitBossArea(ins, actor, bossId)
    if ins.boss_info == nil then return end
    local bossinfo = ins.boss_info[bossId]
    if not bossinfo then return end
    
    local actorid = LActor.getActorId(actor)
    bossinfo.notifylist[actorid] = nil
    notify(ins, actor, {id = bossId, hp = 0})
end

function onTimer(ins, now_t, force)
    if ins.boss_info == nil then return end
    for _, bossinfo in pairs(ins.boss_info) do
        repeat
            if bossinfo.id == nil then break end
            if bossinfo.need_update == false then break end
            if not force and ((bossinfo.timer or 0) > now_t) then break end
            bossinfo.timer = now_t + INTERVAL
            sortDamage(bossinfo)
            for _, actor in pairs(bossinfo.notifylist) do
                notify(ins, actor, bossinfo)
            end
            bossinfo.need_update = false
        until true
    end
end

--boss死亡
function bossDieNotify(ins, mon)
    local mon_id = Fuben.getMonsterId(mon)
    if ins.boss_info == nil then return end
    local bossinfo = ins.boss_info[mon_id]
    if not bossinfo then return end
    bossinfo.hp = 0
    onTimer(ins, System.getNowTime(), true)
end

