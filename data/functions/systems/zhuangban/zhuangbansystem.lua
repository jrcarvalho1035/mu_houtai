module("zhuangbansystem", package.seeall)
local ZHUANGBAN_MAXPOS = 3
local ZHUANGBAN_MAXID = 0

local systemId = Protocol.CMD_ZhuangBan
 

















local function isOpenZhuangBan(actor)
    return true
end

local function initVar(var)
    var.nextTime = 0
    var.zhuangban = {}
    var.zhuangbanlevel = {}
    var.use = {}
    var.zhuangbantype = {}
    for i=0, 6 do
        var.use[i] = {}
        for pos = 1, ZHUANGBAN_MAXPOS do
            var.use[i][pos] = 0
        end
    end
end

function getStaticVar(actor)
    local actorVar = LActor.getStaticVar(actor)
    if actorVar.zhuangban == nil then
        actorVar.zhuangban = {}
        initVar(actorVar.zhuangban)
    end
    return actorVar.zhuangban
end

local function checkRoleIndexAndZhuangbanId(actor, roleindex, id)
     if roleindex < 0 or roleindex > LActor.getRoleCount(actor)-1 then
        print("zhuangban roleindex is err" .. tostring(roleindex))
        return
    end

    local conf = ZhuangBanId[id]
    if not conf then
        print("zhuangban conf is not found" .. tostring(id))
        return
    end

    local roledata = LActor.getRoleData(actor, roleindex)
    if roledata.job ~= conf.roletype then
        print("zhuangban job not match")
        return
    end

    return true
end

local function checkZhuangbanIdGetRoleIndex(actor, id,s)
    local conf = Classconfig(id,s)
    if not conf then
        print("zhuangban conf is not found " .. tostring(id) .. " stype "..s)
        return
    end

    local jobroleindex = nil
    local count = LActor.getRoleCount(actor)
    for roleindex = 0, count-1 do
        local roledata = LActor.getRoleData(actor, roleindex)
        if roledata.job == conf.roletype then
            jobroleindex = roleindex
            break
        end
    end

    return jobroleindex
end


local function getLevel(actor, id)
    local data = getStaticVar(actor)
    if not data.zhuangbanlevel then data.zhuangbanlevel = {} end
    return data.zhuangbanlevel[id] or 1
end

function handleQuery(actor, packet)
    local var = getStaticVar(actor)

    local tmp, count = {}, 0
    for i,v in pairs(ZhuangBanId) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(mozhuangconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(zodiacconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end

    for i,v in pairs(ajzxjhconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
	
    for i,v in pairs(bjzxjhconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end

    for i,v in pairs(cjzxjhconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end		
	
	for i,v in pairs(hunhuanconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end

	for i,v in pairs(ahunhuanconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end

	for i,v in pairs(bhunhuanconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end	

    for i,v in pairs(longshenaconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end

    for i,v in pairs(longshenbconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end

    for i,v in pairs(longshencconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end		
    
    for i,v in pairs(swallowconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(magicbodyconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(scmojieconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(heavenvaultedconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(tutengconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
	
    for i,v in pairs(aanewjhconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end	
	
    for i,v in pairs(abnewjhconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end

    for i,v in pairs(acnewjhconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end

    for i,v in pairs(adnewjhconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end		
    
    for i,v in pairs(dragonsoulconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(newrexueconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(xinggongconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(dunjiaconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(manghuangconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end

    for i,v in pairs(newshenzhuequiconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    for i,v in pairs(anewshenzhuequiconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end	
    
    for i,v in pairs(shenzhuequiconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    for i,v in pairs(qinglongequiconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
	
	for i,v in pairs(baihuequiconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
	
	for i,v in pairs(zhuqueequiconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
	
	for i,v in pairs(xuanwuequiconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
	
	for i,v in pairs(sixiangequiconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
	
	for i,v in pairs(longdiequiconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
	
	for i,v in pairs(junzhuangequiconfig) do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    
    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_QueryInfo)
    if not pack then return end
    
    LDataPack.writeInt(pack, count)
    for id, t in pairs(tmp) do
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, t)
        LDataPack.writeInt(pack, getLevel(actor, id))
    end
    
    local rolenum = LActor.getRoleCount(actor)
    LDataPack.writeByte(pack, rolenum)
    for roleindex = 0, rolenum-1 do
        local use = var.use[roleindex]
        for pos = 1, ZHUANGBAN_MAXPOS do
            LDataPack.writeInt(pack, use[pos] or 0)
        end
    end
    LDataPack.flush(pack)
end


local function updateAttr(actor)
    local var = getStaticVar(actor)
    if not var then return end

    for id,v in pairs(table_name) do
        print(k,v)
    end
end

function GEThandleActive(actor, id, name)
    local var = getStaticVar(actor)

    local invalidTime = 0
    var.zhuangban[id] = invalidTime
    LActor.log(actor, "zhuangbansystem.handleActive", "mark1", id, var.zhuangban[id])

    
    if not var.zhuangbanlevel then var.zhuangbanlevel = {} end
    var.zhuangbanlevel[id] = 1

    calcAttr(actor,"装备系统-激活装扮"..(name or ""))
end

function GEThandleUpLevel(actor, id, level)
    local var = getStaticVar(actor)
	var.zhuangbanlevel[id] = level
	calcAttr(actor,"装扮系统-升级装扮 ")
end

function Classconfig(s, f)
    if f == 2 then
        local list = mozhuangconfig[s]
        return list
    elseif f == 3 then
        local list = zodiacconfig[s]
        return list
    elseif f == 4 then
        local list = swallowconfig[s]
        return list
    elseif f == 5 then
        local list = magicbodyconfig[s]
        return list
    elseif f == 6 then
        local list = scmojieconfig[s]
        return list
    elseif f == 7 then
        local list = heavenvaultedconfig[s]
        return list
    elseif f == 8 then
        local list = tutengconfig[s]
        return list
    elseif f == 9 then
        local list = dragonsoulconfig[s]
        return list
    elseif f == 10 then
        local list = newrexueconfig[s]
        return list
    elseif f == 11 then
        local list = xinggongconfig[s]
        return list
    elseif f == 12 then
        local list = dunjiaconfig[s]
        return list
    elseif f == 13 then
        local list = manghuangconfig[s]
        return list
    elseif f == 14 then
        local list = shenzhuequiconfig[s]
        return list
    elseif f == 40 then
        local list = newshenzhuequiconfig[s]
        return list
    elseif f == 41 then
        local list = anewshenzhuequiconfig[s]
        return list		
    elseif f == 15 then
        local list = qinglongequiconfig[s]
        return list
    elseif f == 16 then
        local list = baihuequiconfig[s]
        return list
    elseif f == 17 then
        local list = zhuqueequiconfig[s]
        return list
    elseif f == 18 then
        local list = xuanwuequiconfig[s]
        return list
    elseif f == 19 then
        local list = sixiangequiconfig[s]
        return list
    elseif f == 20 then
        local list = longdiequiconfig[s]
        return list
    elseif f == 22 then
        local list = hunhuanconfig[s]
        return list
    elseif f == 42 then
        local list = ahunhuanconfig[s]
        return list
    elseif f == 43 then
        local list = bhunhuanconfig[s]
        return list		
    elseif f == 25 then
        local list = ajzxjhconfig[s]
        return list
    elseif f == 26 then
        local list = bjzxjhconfig[s]
        return list
    elseif f == 27 then
        local list = cjzxjhconfig[s]
        return list			
    elseif f == 28 then
        local list = longshenaconfig[s]
        return list
    elseif f == 29 then
        local list = longshenbconfig[s]
        return list
    elseif f == 30 then
        local list = longshencconfig[s]
        return list		
    elseif f == 31 then
        local list = aanewjhconfig[s]
        return list
    elseif f == 32 then
        local list = abnewjhconfig[s]
        return list
    elseif f == 33 then
        local list = acnewjhconfig[s]
        return list
    elseif f == 34 then
        local list = adnewjhconfig[s]
        return list		
    elseif f == 21 then
        local list = junzhuangequiconfig[s]
        return list
    else
        local list = ZhuangBanId[s]
        return list
    end
end

function handleActive(actor, packet)
    local id = LDataPack.readInt(packet)
    local sssid = LDataPack.readInt(packet)
    local roleindex = checkZhuangbanIdGetRoleIndex(actor, id,sssid)
    print("收到id："..id.." ,和type："..sssid)

    if not roleindex then
        print("zhuangban handleActive not found roletype " .. tostring(id) .. " - " .. sssid)
        return
    end
    
    local conf = Classconfig(id,sssid)
    local var = getStaticVar(actor)

    if var.zhuangban[id] then
        print("zhuangban handleActive already active" .. tostring(id))
        return
    end

    
    for _,v in pairs(conf.cost) do
        if not LActor.consumeItem(actor,v.itemId,v.num,false,"zhuangban active") then return false end
    end

    local invalidTime = 0
    if conf.invalidtime then
        invalidTime = conf.invalidtime + System.getNowTime()
    end
    var.zhuangban[id] = invalidTime
    LActor.log(actor, "zhuangbansystem.handleActive", "mark1", id, var.zhuangban[id])

    
    if not var.zhuangbanlevel then var.zhuangbanlevel = {} end
    if not var.zhuangbantype then var.zhuangbantype = {} end
    var.zhuangbanlevel[id] = 1
    
    var.zhuangbantype[id] = sssid

    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_Active)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, invalidTime)
    LDataPack.writeInt(pack, var.zhuangbanlevel[id])
    LDataPack.writeInt(pack, var.zhuangbantype[id])
    LDataPack.flush(pack)

    calcAttr(actor,"装备系统-激活装扮"..(conf.name or ""))

    if invalidTime ~= 0 then
        setInvalidTimer(actor, true, true)
    end

    
    local actorname = LActor.getActorName(LActor.getActorId(actor))
    local posname = ZhuangBanConfig.zhuangbanpos[conf.pos]
	local noticeids = conf.noticeid
	if not noticeids then return end
    noticemanager.broadCastNotice(noticeids, actorname, posname, conf.name)
end


function LoginhandleActive(actor, id)
    local roleindex = checkZhuangbanIdGetRoleIndex(actor, id) 
    if not roleindex then
        print("zhuangban handleActive not found roletype" .. tostring(id))
        return
    end
    
    local conf = ZhuangBanId[id]
    local var = getStaticVar(actor)

    if var.zhuangban[id] then
        print("zhuangban handleActive already active" .. tostring(id))
        return
    end

    for _,v in pairs(conf.cost) do
        if not LActor.consumeItem(actor,v.itemId,v.num,false,"zhuangban active") then return false end
    end


    local invalidTime = 0
    if conf.invalidtime then
        invalidTime = conf.invalidtime + System.getNowTime()
    end
    var.zhuangban[id] = invalidTime
    LActor.log(actor, "zhuangbansystem.handleActive", "mark1", id, var.zhuangban[id])
    print("激活成功了ma："..tostring(id))

    
    if not var.zhuangbanlevel then var.zhuangbanlevel = {} end
    var.zhuangbanlevel[id] = 1

    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_Active)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, invalidTime)
    LDataPack.writeInt(pack, var.zhuangbanlevel[id])
    LDataPack.flush(pack)

    calcAttr(actor,"")

    if invalidTime ~= 0 then
        setInvalidTimer(actor, true, true)
    end

    
    local actorname = LActor.getActorName(LActor.getActorId(actor))
    local posname = ZhuangBanConfig.zhuangbanpos[conf.pos]
	local noticeids = conf.noticeid
	if not noticeids then return end

    noticemanager.broadCastNotice(noticeids, actorname, posname, conf.name)
end

 








function activeAppearance(actor, roleIndex, appearanceId)
    local conf = ZhuangBanId[appearanceId]
    local var = getStaticVar(actor)
    if var.zhuangban[appearanceId] then
        print("zhuangban handleActive already active" .. tostring(appearanceId))
        return
    end
    local invalidTime = 0
    if conf.invalidtime then
        invalidTime = conf.invalidtime + System.getNowTime()
    end
    var.zhuangban[appearanceId] = invalidTime
    
    if not var.zhuangbanlevel then var.zhuangbanlevel = {} end
    var.zhuangbanlevel[appearanceId] = 1

    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_Active)
    if not pack then return end
    LDataPack.writeInt(pack, appearanceId)
    LDataPack.writeInt(pack, invalidTime)
    LDataPack.writeInt(pack, var.zhuangbanlevel[appearanceId])
    LDataPack.flush(pack)
    calcAttr(actor,"装扮系统-幻化装扮 "..(conf.name or ""))
    if invalidTime ~= 0 then
        setInvalidTimer(actor, true, true)
    end
end

 








function changeAppearance(actor, roleIndex, appearanceId)
    local conf = ZhuangBanId[appearanceId]
    local var = getStaticVar(actor)
 





    zhuangbansystem.activeAppearance(actor, roleIndex, appearanceId) 
    var.use[roleIndex][conf.pos] = appearanceId

    

    local v = var.use[roleIndex]
    local pos1, pos2, pos3 = (v[1] or 0), (v[2] or 0), (v[3] or 0)
    LActor.setZhuangBan(actor, roleIndex, pos1, pos2, pos3)

    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_Use)
    if not pack then return end
    LDataPack.writeByte(pack, roleIndex)
    LDataPack.writeByte(pack, conf.pos)
    LDataPack.writeInt(pack, appearanceId)
    LDataPack.flush(pack)
end


 








function restoreAppearance(actor, roleIndex, appearanceId)
    local conf = ZhuangBanId[appearanceId]
    local var = getStaticVar(actor)

    if not var.zhuangban[appearanceId] then 
        print("zhuangban handleUse, not active" .. tostring(appearanceId))
        return
    end
    var.use[roleIndex][conf.pos] = 0

    local v = var.use[roleIndex]
    local pos1, pos2, pos3, pos4, pos5, pos6, pos7 = (v[1] or 0), (v[2] or 0), (v[3] or 0), (v[4] or 0), (v[5] or 0), (v[6] or 0), (v[7] or 0)
    LActor.setZhuangBan(actor, roleIndex, pos1, pos2, pos3, pos4, pos5, pos6, pos7)

    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_UnUse)
    if not pack then return end
    LDataPack.writeByte(pack, roleIndex)
    LDataPack.writeByte(pack, conf.pos)
    LDataPack.writeInt(pack, 0)
    LDataPack.flush(pack)
end

function handleUse(actor, packet)
    local roleindex = LDataPack.readByte(packet) 
    local id = LDataPack.readInt(packet) 
    local stype = LDataPack.readInt(packet) 
    if not checkRoleIndexAndZhuangbanId(actor, roleindex, id) then
        return
    end

    local conf = ZhuangBanId[id]
    local var = getStaticVar(actor)

    if not var.zhuangban[id] then 
        print("zhuangban handleUse, not active" .. tostring(id))
        return
    end

    
    local updatePosTab = {} 
    local oldZhuangbanId = var.use[roleindex][conf.pos] or 0
    if(ZhuangBanId[oldZhuangbanId] and ZhuangBanId[oldZhuangbanId].zhuangbangroup) then
        local groupId = ZhuangBanId[oldZhuangbanId].zhuangbangroup 
        for posTmp = 1, ZHUANGBAN_MAXPOS do 
            local zbId = var.use[roleindex][posTmp]
            if(ZhuangBanId[zbId] and ZhuangBanId[zbId].zhuangbangroup == groupId) then
                var.use[roleindex][posTmp] = 0
                table.insert(updatePosTab,posTmp)
            end
        end
    end

    var.use[roleindex][conf.pos] = id

    LActor.log(actor, "zhuangbansystem.handleUse", "mark1", roleindex, conf.pos, id)

    local v = var.use[roleindex]
    local pos1, pos2, pos3 = (v[1] or 0), (v[2] or 0), (v[3] or 0)
    LActor.setZhuangBan(actor, roleindex, pos1, pos2, pos3)

    if(#updatePosTab == 0) then
        table.insert(updatePosTab,conf.pos)
    end

    for _,posTmp in pairs(updatePosTab) do
        local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_Use) 
        if not pack then return end
        LDataPack.writeByte(pack, roleindex)
        LDataPack.writeByte(pack, posTmp)
        LDataPack.writeInt(pack, var.use[roleindex][posTmp])
        LDataPack.flush(pack)
    end
end

function LoginhandleUse(actor,roleindex, id)
    print("recv handleUse client" .. roleindex .. ", " .. id)
    if not checkRoleIndexAndZhuangbanId(actor, roleindex, id) then
        return
    end

    local conf = ZhuangBanId[id]
    local var = getStaticVar(actor)

    if not var.zhuangban[id] then 
        print("zhuangban handleUse, not active" .. tostring(id))
        return
    end

    
    local updatePosTab = {} 
    local oldZhuangbanId = var.use[roleindex][conf.pos] or 0
    if(ZhuangBanId[oldZhuangbanId] and ZhuangBanId[oldZhuangbanId].zhuangbangroup) then
        local groupId = ZhuangBanId[oldZhuangbanId].zhuangbangroup 
        for posTmp = 1, ZHUANGBAN_MAXPOS do 
            local zbId = var.use[roleindex][posTmp]
            if(ZhuangBanId[zbId] and ZhuangBanId[zbId].zhuangbangroup == groupId) then
                var.use[roleindex][posTmp] = 0
                table.insert(updatePosTab,posTmp)
            end
        end
    end

    var.use[roleindex][conf.pos] = id

    LActor.log(actor, "zhuangbansystem.handleUse", "mark1", roleindex, conf.pos, id)

    local v = var.use[roleindex]
    local pos1, pos2, pos3, pos4, pos5, pos6, pos7 = (v[1] or 0), (v[2] or 0), (v[3] or 0), (v[4] or 0), (v[5] or 0), (v[6] or 0), (v[7] or 0)
    LActor.setZhuangBan(actor, roleindex, pos1, pos2, pos3, pos4, pos5, pos6, pos7)

    if(#updatePosTab == 0) then
        table.insert(updatePosTab,conf.pos)
    end

    for _,posTmp in pairs(updatePosTab) do
        local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_Use) 
        if not pack then return end
        LDataPack.writeByte(pack, roleindex)
        LDataPack.writeByte(pack, posTmp)
        LDataPack.writeInt(pack, var.use[roleindex][posTmp])
        LDataPack.flush(pack)
    end
end

function handleUnUse(actor, packet)
    local roleindex = LDataPack.readByte(packet)
    local id = LDataPack.readInt(packet)
    if not checkRoleIndexAndZhuangbanId(actor, roleindex, id) then
        return
    end

    local conf = ZhuangBanId[id]
    local var = getStaticVar(actor)

    local oldid = var.use[roleindex][conf.pos] or 0
    if oldid ~= id then
        print("zhuangban handleUnUse oldid~=id" .. tostring(oldid) .. "~=" .. tostring(id))
        return
    end
    if oldid == 0 then
        print("zhuangban handleUnUse not use" .. tostring(oldid))
        return
    end
    
    var.use[roleindex][conf.pos] = 0
    LActor.log(actor, "zhuangbansystem.handleUnUse", "mark1", roleindex, conf.pos)

    local v = var.use[roleindex]
    
    local pos1, pos2, pos3 = (v[1] or 0), (v[2] or 0), (v[3] or 0)
    LActor.setZhuangBan(actor, roleindex, pos1, pos2, pos3)

    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_UnUse)
    if not pack then return end
    LDataPack.writeByte(pack, roleindex)
    LDataPack.writeByte(pack, conf.pos)
    LDataPack.writeInt(pack, 0)
    LDataPack.flush(pack)
end

function Classupconfig(s, f)
    if f == 2 then
        local list = mozhuangconfig[s]
        return list
    elseif f == 3 then
        local list = zodiacconfig[s]
        return list
    elseif f == 4 then
        local list = swallowupconfig[s]
        return list
    elseif f == 5 then
        local list = magicbodyupconfig[s]
        return list
    elseif f == 6 then
        local list = scmojieupconfig[s]
        return list
    elseif f == 7 then
        local list = heavenvaultedupconfig[s]
        return list
    elseif f == 8 then
        local list = tutengupconfig[s]
        return list
    elseif f == 9 then
        local list = dragonsoulupconfig[s]
        return list
    elseif f == 10 then
        local list = newrexueupconfig[s]
        return list
    elseif f == 11 then
        local list = xinggongupconfig[s]
        return list
    elseif f == 12 then
        local list = dunjiaupconfig[s]
        return list
    elseif f == 13 then
        local list = manghuangupconfig[s]
        return list
    elseif f == 14 then
        local list = shengzhuequiupconfig[s]
        return list
    elseif f == 25 then
        local list = ajzxsjconfig[s]
        return list
    elseif f == 26 then
        local list = bjzxsjconfig[s]
        return list
    elseif f == 27 then
        local list = cjzxsjconfig[s]
        return list			
    elseif f == 40 then
        local list = newshenzhuequiupconfig[s]
        return list
    elseif f == 41 then
        local list = anewshenzhuequiupconfig[s]
        return list			
    elseif f == 15 then
        local list = qinglongequiupconfig[s]
        return list
    elseif f == 16 then
        local list = baihuequiupconfig[s]
        return list
    elseif f == 17 then
        local list = zhuqueequiupconfig[s]
        return list
    elseif f == 18 then
        local list = xuanwuequiupconfig[s]
        return list
    elseif f == 19 then
        local list = sixiangequiupconfig[s]
        return list
    elseif f == 20 then
        local list = longdiequiupconfig[s]
        return list
    elseif f == 22 then
        local list = hunhuanupconfig[s]
        return list
    elseif f == 42 then
        local list = ahunhuanupconfig[s]
        return list
    elseif f == 43 then
        local list = bhunhuanupconfig[s]
        return list		
    elseif f == 28 then
        local list = longshenaupconfig[s]
        return list	
    elseif f == 29 then
        local list = longshenbupconfig[s]
        return list	
    elseif f == 30 then
        local list = longshencupconfig[s]
        return list		
    elseif f == 31 then
        local list = aanewjhupconfig[s]
        return list
    elseif f == 32 then
        local list = abnewjhupconfig[s]
        return list
    elseif f == 33 then
        local list = acnewjhupconfig[s]
        return list
    elseif f == 34 then
        local list = adnewjhupconfig[s]
        return list		
    elseif f == 21 then
        local list = junzhuangequiupconfig[s]
        return list
    else
        local list = ZhuangBanId[s]
        return list
    end
end

function Classupsconfig(s, f,m)
    if f == 2 then
        local list = mozhuangupconfig[s][m+1]
        return list
    elseif f == 3 then
        local list = zodiacupconfig[s][m+1]
        return list
    elseif f == 4 then
        local list = swallowupconfig[s][m+1]
        return list
    elseif f == 5 then
        local list = magicbodyupconfig[s][m+1]
        return list
    elseif f == 6 then
        local list = scmojieupconfig[s][m+1]
        return list
    elseif f == 7 then
        local list = heavenvaultedupconfig[s][m+1]
        return list
    elseif f == 8 then
        local list = tutengupconfig[s][m+1]
        return list
    elseif f == 9 then
        local list = dragonsoulupconfig[s][m+1]
        return list
    elseif f == 10 then
        local list = newrexueupconfig[s][m+1]
        return list
    elseif f == 11 then
        local list = xinggongupconfig[s][m+1]
        return list
    elseif f == 12 then
        local list = dunjiaupconfig[s][m+1]
        return list
    elseif f == 13 then
        local list = manghuangupconfig[s][m+1]
        return list
    elseif f == 14 then
        local list = shengzhuequiupconfig[s][m+1]
        return list
    elseif f == 25 then
        local list = ajzxsjconfig[s][m+1]
        return list
    elseif f == 26 then
        local list = bjzxsjconfig[s][m+1]
        return list
    elseif f == 27 then
        local list = cjzxsjconfig[s][m+1]
        return list		
    elseif f == 40 then
        local list = newshenzhuequiupconfig[s][m+1]
        return list
    elseif f == 41 then
        local list = anewshenzhuequiupconfig[s][m+1]
        return list			
    elseif f == 15 then
        local list = qinglongequiupconfig[s][m+1]
        return list
    elseif f == 16 then
        local list = baihuequiupconfig[s][m+1]
        return list
    elseif f == 17 then
        local list = zhuqueequiupconfig[s][m+1]
        return list
    elseif f == 18 then
        local list = xuanwuequiupconfig[s][m+1]
        return list
    elseif f == 19 then
        local list = sixiangequiupconfig[s][m+1]
        return list
    elseif f == 20 then
        local list = longdiequiupconfig[s][m+1]
        return list
    elseif f == 22 then
        local list = hunhuanupconfig[s][m+1]
        return list
    elseif f == 42 then
        local list = ahunhuanupconfig[s][m+1]
        return list
    elseif f == 43 then
        local list = bhunhuanupconfig[s][m+1]
        return list		
    elseif f == 28 then
        local list = longshenaupconfig[s][m+1]
        return list
    elseif f == 29 then
        local list = longshenbupconfig[s][m+1]
        return list
    elseif f == 30 then
        local list = longshencupconfig[s][m+1]
        return list		
    elseif f == 31 then
        local list = aanewjhupconfig[s][m+1]
        return list
    elseif f == 32 then
        local list = abnewjhupconfig[s][m+1]
        return list
    elseif f == 33 then
        local list = acnewjhupconfig[s][m+1]
        return list
    elseif f == 34 then
        local list = adnewjhupconfig[s][m+1]
        return list		
    elseif f == 21 then
        local list = junzhuangequiupconfig[s][m+1]
        return list
    else
        local list = ZhuangBanLevelUp[s][m+1]
        return list
    end
end

local function handleUpLevel(actor, packet)
    local actorId = LActor.getActorId(actor)
    local id = LDataPack.readInt(packet)
    local var = getStaticVar(actor)
    local stype = var.zhuangbantype[id]
    
    local sconf = Classconfig(id,stype)
    

    if not sconf then print("zhuangbansystem.handleUpLevel: conf is nil, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end

    
    local var = getStaticVar(actor)
    if not var.zhuangban[id] then print("zhuangbansystem.handleUpLevel: not active, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end

    local level = getLevel(actor, id)
    
    local supnf = Classupconfig(id,stype)
    local gupnf = Classupsconfig(id,stype,level)

    if not supnf or not gupnf then
        print("zhuangbansystem.handleUpLevel: level conf nil, id:"..tostring(id)..", level:"..tostring(level)..", actorId:"..tostring(actorId))
        return
    end

    local conf = gupnf

    
    if conf.cost then
        
        for _,v in pairs(conf.cost) do
            if not LActor.consumeItem(actor,v.itemId,v.num,false,"zhuangbanUpLevel") then return end
        end

        var.zhuangbanlevel[id] = level + 1
        calcAttr(actor,"装扮系统-升级装扮 "..(sconf and sconf.name or ""))

        print("zhuangbansystem.handleUpLevel: success, id:"..tostring(id)..", level:"..tostring(level + 1)..", actorId:"..tostring(actorId))

        local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_UpLevel)
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, var.zhuangban[id])
        LDataPack.writeInt(pack, level+1)
        LDataPack.flush(pack)
    end
end

local function doZhuangbanInvalid(actor, id)
    local var = getStaticVar(actor)
    var.zhuangban[id] = nil

    local _roleindex, _pos = nil, nil
    for roleindex = 0, 6 do
        for pos = 1, ZHUANGBAN_MAXPOS do
            if var.use[roleindex][pos] == id then
                var.use[roleindex][pos] = 0
                _roleindex, _pos = roleindex, pos
            end
        end
    end
 
    
    local title = ZhuangBanConfig.mailinvalidtitle
    local posname = ZhuangBanConfig.zhuangbanpos[ZhuangBanId[id].pos]
    local content = string.format(ZhuangBanConfig.mailinvalidcontext, posname, ZhuangBanId[id].name)
    local mailData = { head=title, context = content, tAwardList={} }
    LActor.log(actor, "zhuangbansystem.doZhuangbanInvalid", "sendMail")
    mailsystem.sendMailById(LActor.getActorId(actor), mailData)

    return _roleindex, _pos
end

local function noticeZhuangbanInvalid(actor, id)
    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_Invalid)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.flush(pack)
end

function calcAttr(actor,reason)
    local var = getStaticVar(actor)

    local function tableAddMulit(t, attrs, n)
        for _, v in ipairs(attrs or {}) do
            t[v.type] = (t[v.type] or 0) + (v.value * n)
        end
    end

    local function tableAddPre(t, attrs)
        for _, v in ipairs(attrs or {}) do
            t[v.pos] = (t[v.pos] or 0) + (v.pre or 0)
        end
    end

    local expower = {}  
    local roleAttrs = {}
    local posAttrPre = {}
    local wingAttrPre = {}
    for id, v in pairs(ZhuangBanId) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if ZhuangBanLevelUp[id] and ZhuangBanLevelUp[id][level] then
                tableAddMulit(roleAttrs[v.roletype], ZhuangBanLevelUp[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], ZhuangBanLevelUp[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (ZhuangBanLevelUp[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(longfengconfig) do
        if var.zhuangban[id] then
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            local level = getLevel(actor, id)
			local equid = longfengconfig[id].equipment
            if longfengupconfig[equid] and longfengupconfig[equid][level] then
                tableAddMulit(roleAttrs[v.roletype], longfengupconfig[equid][level].attr, 1)
            end
            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(longfbaoshiconfig) do
        if var.zhuangban[id] then
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            local level = getLevel(actor, id)
			local equid = longfbaoshiconfig[id].equipment
            if longfbaoshiupconfig[equid] and longfbaoshiupconfig[equid][level] then
                tableAddMulit(roleAttrs[v.roletype], longfbaoshiupconfig[equid][level].attr, 1)
            end
            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(longffuhunconfig) do
        if var.zhuangban[id] then
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            local level = getLevel(actor, id)
			local equid = longffuhunconfig[id].equipment
            if longffuhunupconfig[equid] and longffuhunupconfig[equid][level] then
                tableAddMulit(roleAttrs[v.roletype], longffuhunupconfig[equid][level].attr, 1)
            end
            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(mozhuangconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if mozhuangupconfig[id] and mozhuangupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], mozhuangupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], mozhuangupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (mozhuangupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
	
	for id, v in pairs(hunhuanconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if hunhuanupconfig[id] and hunhuanupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], hunhuanupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], hunhuanupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (hunhuanupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end	
	
	for id, v in pairs(ahunhuanconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if ahunhuanupconfig[id] and ahunhuanupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], ahunhuanupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], ahunhuanupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (ahunhuanupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end	

	for id, v in pairs(bhunhuanconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if bhunhuanupconfig[id] and bhunhuanupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], bhunhuanupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], bhunhuanupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (bhunhuanupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end		

	
    for id, v in pairs(ajzxjhconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if ajzxsjconfig[id] and ajzxsjconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], ajzxsjconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], ajzxsjconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (ajzxsjconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end

    for id, v in pairs(bjzxjhconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if bjzxsjconfig[id] and bjzxsjconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], bjzxsjconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], bjzxsjconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (bjzxsjconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end

    for id, v in pairs(cjzxjhconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if cjzxsjconfig[id] and cjzxsjconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], cjzxsjconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], cjzxsjconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (cjzxsjconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end	

	
	for id, v in pairs(aanewjhconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if aanewjhupconfig[id] and aanewjhupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], aanewjhupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], aanewjhupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (aanewjhupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end	
	
	for id, v in pairs(abnewjhconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if abnewjhupconfig[id] and abnewjhupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], abnewjhupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], abnewjhupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (abnewjhupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end

	for id, v in pairs(acnewjhconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if acnewjhupconfig[id] and acnewjhupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], acnewjhupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], acnewjhupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (acnewjhupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end	

	for id, v in pairs(adnewjhconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if adnewjhupconfig[id] and adnewjhupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], adnewjhupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], adnewjhupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (adnewjhupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end		

    for id, v in pairs(zodiacconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if zodiacupconfig[id] and zodiacupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], zodiacupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], zodiacupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (zodiacupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(swallowconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if swallowupconfig[id] and swallowupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], swallowupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], swallowupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (swallowupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(magicbodyconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if magicbodyupconfig[id] and magicbodyupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], magicbodyupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], magicbodyupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (magicbodyupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
	
    for id, v in pairs(longshenaconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if longshenaupconfig[id] and longshenaupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], longshenaupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], longshenaupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (longshenaupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end	
	
    for id, v in pairs(longshenbconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if longshenbupconfig[id] and longshenbupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], longshenbupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], longshenbupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (longshenbupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end	

    for id, v in pairs(longshencconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if longshencupconfig[id] and longshencupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], longshencupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], longshencupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (longshencupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end			
    
    for id, v in pairs(scmojieconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if scmojieupconfig[id] and scmojieupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], scmojieupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], scmojieupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (scmojieupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(heavenvaultedconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if heavenvaultedupconfig[id] and heavenvaultedupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], heavenvaultedupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], heavenvaultedupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (heavenvaultedupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(tutengconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if tutengupconfig[id] and tutengupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], tutengupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], tutengupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (tutengupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(dragonsoulconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if dragonsoulupconfig[id] and dragonsoulupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], dragonsoulupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], dragonsoulupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (dragonsoulupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(newrexueconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if newrexueupconfig[id] and newrexueupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], newrexueupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], newrexueupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (newrexueupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(xinggongconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if xinggongupconfig[id] and xinggongupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], xinggongupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], xinggongupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (xinggongupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(dunjiaconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if dunjiaupconfig[id] and dunjiaupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], dunjiaupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], dunjiaupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (dunjiaupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(manghuangconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if manghuangupconfig[id] and manghuangupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], manghuangupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], manghuangupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (manghuangupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
    
    for id, v in pairs(shenzhuequiconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if shengzhuequiupconfig[id] and shengzhuequiupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], shengzhuequiupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], shengzhuequiupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (shengzhuequiupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
	
    for id, v in pairs(newshenzhuequiconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if newshenzhuequiupconfig[id] and newshenzhuequiupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], newshenzhuequiupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], newshenzhuequiupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (newshenzhuequiupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end

    for id, v in pairs(anewshenzhuequiconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if anewshenzhuequiupconfig[id] and anewshenzhuequiupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], anewshenzhuequiupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], anewshenzhuequiupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (anewshenzhuequiupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end		
    
    for id, v in pairs(qinglongequiconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if qinglongequiupconfig[id] and qinglongequiupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], qinglongequiupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], qinglongequiupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (qinglongequiupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
	
	for id, v in pairs(baihuequiconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if baihuequiupconfig[id] and baihuequiupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], baihuequiupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], baihuequiupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (baihuequiupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
	
	for id, v in pairs(zhuqueequiconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if zhuqueequiupconfig[id] and zhuqueequiupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], zhuqueequiupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], zhuqueequiupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (zhuqueequiupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
	
	for id, v in pairs(xuanwuequiconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if xuanwuequiupconfig[id] and xuanwuequiupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], xuanwuequiupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], xuanwuequiupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (xuanwuequiupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
	
	for id, v in pairs(sixiangequiconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if sixiangequiupconfig[id] and sixiangequiupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], sixiangequiupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], sixiangequiupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (sixiangequiupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
	
	for id, v in pairs(longdiequiconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if longdiequiupconfig[id] and longdiequiupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], longdiequiupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], longdiequiupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (longdiequiupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end
	
	for id, v in pairs(junzhuangequiconfig) do
        if var.zhuangban[id] then
            
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr or {}, 1)

            
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            
            local level = getLevel(actor, id)
            if junzhuangequiupconfig[id] and junzhuangequiupconfig[id][level] then
                tableAddMulit(roleAttrs[v.roletype], junzhuangequiupconfig[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], junzhuangequiupconfig[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (junzhuangequiupconfig[id][level].wing_attr_per or 0)
            end

            expower[v.roletype] = (expower[v.roletype] or 0) + (v.exPower or 0)
        end
    end

    local count = LActor.getRoleCount(actor)
    for roleindex = 0, count-1 do
        local attr = LActor.getRoleZhuangBanAttr(actor, roleindex)
        attr:Reset()
        local roledata = LActor.getRoleData(actor, roleindex)
        local zhuangbanAttr = roleAttrs[roledata.job]
        if zhuangbanAttr then
            for k, v in pairs(zhuangbanAttr) do
                attr:Set(k, v)
            end

            
            for pos, pre in pairs(posAttrPre[roledata.job] or {}) do
                local equipAttr = LActor.getEquipAttr(actor, roleindex, pos)
                for attrType = Attribute.atHpMax, Attribute.atTough do
                    if 0 < (equipAttr[attrType] or 0) then
                        attr:Add(attrType, math.floor(equipAttr[attrType]*pre/10000))
                    end
                end
            end
        end
        
        local per = wingAttrPre[roledata.job] or 0
        if per > 0 then
            local level, _, status = LActor.getWingInfo(actor, roleindex)
            if status == 1 then
                local wingCfg = WingLevelConfig[level]
                if wingCfg then
                    for _,att in ipairs(wingCfg.attr or {}) do
                        attr:Add(att.type, math.floor(att.value*per/10000))
                    end
                end
            end
        end
        
        attr:SetExtraPower(expower[roleindex+1] or 0)
    end

    LActor.reCalcAttr(actor,reason)
end

function setInvalidTimer(actor, needSend, needSetTimer)
    local var = getStaticVar(actor)

    
    local invalidIds = {}
    local nowtime = System.getNowTime()
    local nextTime = nil
    for id, v in pairs(ZhuangBanId) do
        local invalidTime = var.zhuangban[id] or 0
        if invalidTime and invalidTime > 0 then
            if nowtime >= invalidTime then
                table.insert(invalidIds, id)
            elseif nextTime == nil or invalidTime < nextTime then
                nextTime = invalidTime
            end
        end
    end

    local updateRoles = {}
    for _, id in ipairs(invalidIds) do
        local roleindex, pos = doZhuangbanInvalid(actor, id)
        if roleindex then
            updateRoles[roleindex] = pos
        end
    end

    for roleindex, _ in pairs(updateRoles) do
        local v = var.use[roleindex]
        local pos1, pos2, pos3 = (v[1] or 0), (v[2] or 0), (v[3] or 0)
        LActor.setZhuangBan(actor, roleindex, pos1, pos2, pos3)
    end

    if needSend then
        for _, id in ipairs(invalidIds) do
            noticeZhuangbanInvalid(actor, id)
        end
    end

    if needSetTimer and nextTime then
        local nextTime = nextTime - nowtime
        if nextTime < 0 then nextTime = 0 end
        LActor.postScriptEventLite(actor, nextTime * 1000, function() setInvalidTimer(actor, true, true) end)
    end
    
	
    if invalidTime and invalidTime > nowtime then
       calcAttr(actor,"装扮过期")
	else
       calcAttr(actor,"")
	end   
end

function printVar(actor)
    local var = getStaticVar(actor)
    
    for id, v in pairs(ZhuangBanId) do
        if var.zhuangban[id] then
            
            LActor.log(actor, "zhuangbansystem.printVar", "mark1", var.zhuangban[id])
        end
    end
    
    for roleindex = 0, 2 do
        local v = var.use[roleindex]
        
        LActor.log(actor, "zhuangbansystem.printVar", "mark2", v[1], v[2], v[3])
    end
end

local function onInit(actor)
    
    setInvalidTimer(actor, false, false)

    local var = getStaticVar(actor)
    for roleindex = 0, 2 do
        local v = var.use[roleindex]


        local pos1, pos2, pos3 = (v[1] or 0), (v[2] or 0), (v[3] or 0)
        LActor.setZhuangBan(actor, roleindex, pos1, pos2, pos3)
    end
end
 
local function onWingLevelUp(actor, roleId, level)
    calcAttr(actor,"装备系统-翅膀升级")
end

local function onLogin(actor)
    setInvalidTimer(actor, false, true)
    handleQuery(actor, nil)
end

netmsgdispatcher.reg(systemId, Protocol.cZhuangBanCmd_QueryInfo, handleQuery)
netmsgdispatcher.reg(systemId, Protocol.cZhuangBanCmd_Active, handleActive)
netmsgdispatcher.reg(systemId, Protocol.cZhuangBanCmd_Use, handleUse)
netmsgdispatcher.reg(systemId, Protocol.cZhuangBanCmd_UnUse, handleUnUse)
netmsgdispatcher.reg(systemId, Protocol.cZhuangBanCmd_UpLevel, handleUpLevel)

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeWingLevelUp, onWingLevelUp)