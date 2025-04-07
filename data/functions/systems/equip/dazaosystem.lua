module( "dazaosystem", package.seeall)

DAZAO_NEED_EQUIP_LENGTH = 5 --打造装备需要几件装备
DAZAO_FENJIE_EQUIP_MAX = 8 --最多分解几件装备
--打造装备
function dazaoEquip(actor, pack)
    local tarid = LDataPack.readInt(pack)
    local len = LDataPack.readChar(pack)

    if len ~= DAZAO_NEED_EQUIP_LENGTH then return end
    local equipuids = {}
    for i=1, len do
        equipuids[i] = LDataPack.readDouble(pack)
        local equipid = LActor.getItemIdByUid(actor, equipuids[i], BagType_Equip)
        for j=1, #equipuids - 1 do --预防五件装备发一样的
            if equipuids[i] == equipuids[j] then
                return
            end
        end
        if not ItemConfig[equipid] then return end
        if ItemConfig[equipid].rank ~= ItemConfig[tarid].rank and ItemConfig[equipid].star + 1 ~= ItemConfig[tarid].star then return end
    end

    for k, fuid in ipairs(equipuids) do --删除被吞噬饰品
		LActor.costItemByUid(actor, fuid, 1, BagType_Equip, "dazao equip")
    end
    
    actoritem.addItem(actor, tarid, 1, "dazao equip")

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_DazaoEquip)
    if npack == nil then return end
    LDataPack.writeInt(npack, tarid)
    LDataPack.flush(npack)
end

--戒指升星
function ringStarUp(actor, pack)
    local slot = LDataPack.readChar(pack)
    if slot ~= EquipSlotType_Ring1 and slot ~= EquipSlotType_Ring2 then return end
    local var = equipsystem.getActorVar(actor)
    if var[slot] == 0 then return end
    local conf = DazaoRingStarConfig[var[slot]]
    if not conf then return end

    if not actoritem.checkItems(actor, conf.needitem) then return end

    actoritem.reduceItems(actor, conf.needitem,  "dazao ring star")
    var[slot] = conf.tarid

    equipsystem.updateAttr(actor, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_RingStarUp)
    if npack == nil then return end
    LDataPack.writeInt(npack, conf.tarid)
    LDataPack.flush(npack)    
end

--戒指升阶
function ringStageUp(actor, pack)
    local slot = LDataPack.readChar(pack)
    if slot ~= EquipSlotType_Ring1 and slot ~= EquipSlotType_Ring2 then return end
    local var = equipsystem.getActorVar(actor)
    if var[slot] == 0 then return end
    local conf = DazaoRingStageConfig[var[slot]]
    if not conf then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
    actoritem.reduceItems(actor, conf.needitem,  "dazao ring stage")
    var[slot] = conf.tarid

    equipsystem.updateAttr(actor, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.cEquipCmd_RingStageUp)
    if npack == nil then return end
    LDataPack.writeInt(npack, conf.tarid)
    LDataPack.flush(npack)
end

function addFenjieItem(additems, additem)
    for i=1, #additem do
        local ishave = false
        for k,v in ipairs(additems) do
            if v.id == additem[i].id then
                v.count = v.count + additem[i].count
                ishave = true
                break
            end
        end
        if not ishave then
            additems[#additems + 1] = {}
            additems[#additems].id = additem[i].id
            additems[#additems].count = additem[i].count
        end
    end    
end

--装备分解
function equipFenjie(actor, pack)
    local len = LDataPack.readChar(pack)
    if len > DAZAO_FENJIE_EQUIP_MAX then return end
    local additems = {}
    local equips = {}
    for i=1, len do
        local equipuid = LDataPack.readDouble(pack)
        local equipid = LActor.getItemIdByUid(actor, equipuid, BagType_Equip)
        local conf = ItemConfig[equipid]
        if not conf then return end
        if not actoritem.checkItem(actor, equipid, 1) then return end
        if not DazaoFenjieConfig[conf.rank] or not DazaoFenjieConfig[conf.rank][conf.star] then return end
        equips[#equips + 1] = {id = equipid, count = 1}
        addFenjieItem(additems, DazaoFenjieConfig[conf.rank][conf.star].additem)
    end
    actoritem.reduceItems(actor, equips)
    actoritem.addItems(actor, additems, "equip fenjie")

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_EquipFenjie)
    LDataPack.writeChar(npack, #additems)
    for k, v in ipairs(additems) do
        LDataPack.writeInt(npack, v.id)
        LDataPack.writeInt(npack, v.count)
    end
    LDataPack.flush(npack)
end

local function init()
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_DazaoEquip, dazaoEquip)
    netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_RingStarUp, ringStarUp)
    netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_RingStageUp, ringStageUp)
    netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_EquipFenjie, equipFenjie)
end
table.insert(InitFnTable, init)





