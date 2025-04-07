module("msbossdamageinfo", package.seeall)


function initBossCache(cache, id, hp, interval)
	cache.bossInfo = {}
	local tbl = cache.bossInfo
	tbl.id = id
	tbl.hp = hp

	tbl.damageRank = {}
	tbl.damageList = {}
	tbl.needUpdate = false
	tbl.timer = 0
	tbl.tInterval = interval
end

local function broadcastBossHp(bIdx)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if not bVar then return end

	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
	LDataPack.writeByte(npack, Protocol.sFubenCmd_InsBossHp)

	local bossInfo = bVar.bossData.bossInfo
	LDataPack.writeInt(npack, bossInfo.id)
	LDataPack.writeDouble(npack, bossInfo.hp)
	LDataPack.writeInt64(npack, bossInfo.src_hdl or 0)
	LDataPack.writeInt64(npack, bossInfo.tar_hdl or 0)
	if bossInfo.damageRank == nil then
		LDataPack.writeShort(npack, 0)
	else
		LDataPack.writeShort(npack, #bossInfo.damageRank)
		for i=1,#bossInfo.damageRank do
			LDataPack.writeInt(npack, bossInfo.damageRank[i].id)
			LDataPack.writeString(npack, bossInfo.damageRank[i].aName)
			LDataPack.writeDouble(npack, bossInfo.damageRank[i].damage)
		end
	end
	LDataPack.writeInt(npack, 0)
	local conf = MonstersConfig[bossInfo.id]
	LDataPack.writeString(npack, conf.name)
	LDataPack.writeString(npack, conf.head)
	LDataPack.writeInt(npack, conf.level)
	LDataPack.writeDouble(npack, bVar.maxHp)

	for i=1, #bVar.hfbList do
		local hfb = bVar.hfbList[i]
		local ins = instancesystem.getInsByHdl(hfb)
		if ins then
			Fuben.sendData(hfb, npack)
		end
	end
end

function onDamage(bIdx, damage, attacker)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if not bVar then return end
	local bossInfo = bVar.bossData.bossInfo
	if not bossInfo then
		System.log("msbossdamageinfo", "onDamage", "bossInfo not init")
		return
	end

	local actor = LActor.getActor(attacker)
	if actor == nil then return end

	local roleId = 0
	local actordata = LActor.getActorData(actor)
	local roleData = LActor.getRoleData(actor, roleId)
	local slotdata = roleData.equips_data.slot_data
	local wingData = roleData.wings.wdatas[0]

	local aId = actordata.actor_id
	local role = LActor.getRole(actor,0)
	local info = bossInfo.damageList[aId]
	if info == nil then
		bossInfo.damageList[aId] = {
			aName = actordata.actor_name,
			job = roleData.job,
			level = actordata.level,
			clothesId = slotdata[EquipSlotType_Coat].equip_data.id, 
			weaponId = slotdata[EquipSlotType_Weapon].equip_data.id,
			illusionWeaponId = archangel.getRoleArchangelEquipId(actor, roleId) or 0,
			wingLevel = wingData.level,
			wingOpenState = wingData.openStatus,
			title = titlesystem.getRoleTitle(actor, roleId) or 0,
			guildId = actordata.guild_id_,
			guildName = LGuild.getGuilNameById(actordata.guild_id_),
			footShowStage = footsystem.getFootShowStage(actor, roleId) or 0,
			shineWeapon = LActor.getRoleShineWeapon(actor, roleId),
			shineArmor = LActor.getRoleShineArmor(actor, roleId),
			teamId = getTeamId(actor),
			guildPos = LActor.getGuildPos(actor),
			
			damage = damage,
		}
	else
		info.damage = info.damage + damage
	end
	bossInfo.hp = bVar.publicHP
	bossInfo.needUpdate = true

	if bVar.publicHP <= 0 or timerCheckAndSet(bossInfo, System.getNowTime()) then
		sortDamage(bossInfo)
		broadcastBossHp(bIdx)
	end
end

function getActorHurt(cache, actorId)
	if not cache.bossInfo then
		-- print("getActorHurt, cache bossInfo not init")
		System.log("msbossdamageinfo", "getActorHurt", "cache bossInfo not init")
		return 0
	end
	local info = cache.bossInfo.damageList[actorId]
	if info then
		return info.damage
	end
	return 0
end

function sortDamage(bossInfo)
    if bossInfo == nil then return end
    if bossInfo.damageList == nil then return end
    bossInfo.damageRank = {}
    for aid, v in pairs(bossInfo.damageList) do
    	local info = utils.table_clone(v)
    	info.id = aid
        table.insert(bossInfo.damageRank, info)
    end
    
    table.sort(bossInfo.damageRank, function(a,b)
        return a.damage > b.damage
    end)
end

function clear(cache)
	if cache then
		cache.bossInfo = nil
	end
end


--instance回调接口
function getInfoPack(cache, npack, maxCount)
	if not cache then
		LDataPack.writeShort(npack, 0)
		return
	end
	local info = cache.bossInfo
	LDataPack.writeInt(npack, info.id)
	LDataPack.writeDouble(npack, info.hp)
	if info.damageRank == nil then
		LDataPack.writeShort(npack, 0)
	else
		local num = #info.damageRank
		num = num > maxCount and maxCount or num
		LDataPack.writeShort(npack, num)
		for i=1, num do
			LDataPack.writeInt(npack, info.damageRank[i].id)
			LDataPack.writeString(npack, info.damageRank[i].aName)
			LDataPack.writeDouble(npack, info.damageRank[i].damage)
		end
	end
end

function getRankPack(cache, npack, maxCount)
	if not cache then
		LDataPack.writeShort(npack, 0)
		return
	end 
	local info = cache.bossInfo
	if info == nil or info.damageRank == nil then
		LDataPack.writeShort(npack, 0)
	else
		local num = #info.damageRank
		num = num > maxCount and maxCount or num
		LDataPack.writeShort(npack, num)
		for i=1, num do
			LDataPack.writeInt(npack, info.damageRank[i].id)
			LDataPack.writeString(npack, info.damageRank[i].aName)
			LDataPack.writeDouble(npack, info.damageRank[i].damage)
		end
	end
end

function getFirstRankPlayer(cache)
	if not cache then return {} end
	local info = cache.bossInfo or {}
	local tbl = info.damageRank or {}
	return tbl[1] or {}
end

--只处理一个计时器的逻辑，不做任何逻辑
function timerCheckAndSet(bossInfo, now_t)
	if bossInfo == nil then return false end
	if not bossInfo.needUpdate then return false end
	if bossInfo.timer > now_t then return false end
	bossInfo.timer = now_t + bossInfo.tInterval --tInterval秒执行一次

	bossInfo.needUpdate = false
	return true
end

