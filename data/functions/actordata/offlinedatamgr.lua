--玩家离线数据
--@rancho 20170619
module("offlinedatamgr", package.seeall)

local SAVE_TIME = 3600 * 1000 * 2 + (30 * 100)

offlineDataSet = offlineDataSet or {}

EOffLineDataType =
{
	EBasic = 1,
	EPack = 2,
	EPackVer = 3,
	EMisc = 4,
	EOperable = 5 --可操作的数据
}
_G.EOffLineDataType = EOffLineDataType

function GetDataSet( ... )
	return offlineDataSet
end

function GetData(actorId, notJustGet)
	local aData = offlineDataSet[actorId]
	if aData == nil and notJustGet then
		offlineDataSet[actorId] = {}
		aData = offlineDataSet[actorId]
	end
	return aData
end

function ClearData(actorId)
	if offlineDataSet[actorId] == nil then return end
	offlineDataSet[actorId] = {}
end

function GetDataByOffLineDataType(actorId, dataType, notJustGet)
	if System.isBattleSrv() then return end
	local aData = GetData(actorId, notJustGet)
	if aData == nil then return end
	local tData = aData[dataType]
	if tData == nil and notJustGet then
		aData[dataType] = {}
		tData = aData[dataType]
	end
	return tData
end

function SetDataByOffLineDataType(actorId, dataType, tData, notJustGet)
	local aData = GetData(actorId, notJustGet)
	if aData == nil then return end
	aData[dataType] = tData
end

function GetPackByOffLinePackType(actorId, packType, notJustGet)
	if System.isBattleSrv() then return end
	local dataType = EOffLineDataType.EPack

	local tData = GetDataByOffLineDataType(actorId, dataType, notJustGet)
	if tData == nil then return end
	local pData = tData[packType]
	return pData
end

function SetPackByOffLinePackType(actorId, packType, pData)
	local dataType = EOffLineDataType.EPack

	local tData = GetDataByOffLineDataType(actorId, dataType)
	if tData == nil then return end
	tData[packType] = pData
end

function IsDirty(actorId)
	local EMiscData = GetDataByOffLineDataType(actorId, EOffLineDataType.EMisc)
	if EMiscData == nil then return false end
	return EMiscData.isDirty
end

function SetDirty(actorId, isDirty)
	local EMiscData = GetDataByOffLineDataType(actorId, EOffLineDataType.EMisc, true)
	if EMiscData == nil then return false end
	EMiscData.isDirty = isDirty
end

--是否是显示所有外观的排行榜
local function isShowAllInfo(type)
	return type == RankingType_Power or
	type == RankingType_Level or
	type == RankingType_Guild or
	type == RankingType_Lilian or
	type == RankingType_Touxian or
	type == RankingType_Equip or
	type == RankingType_Hunqi
end

function setNullRankPack(pack)
	LDataPack.writeByte(pack, 0)
	LDataPack.writeInt(pack, 0)
	LDataPack.writeInt(pack, 0)
	LDataPack.writeInt(pack, 0)
	LDataPack.writeInt(pack, 0)
	LDataPack.writeInt(pack, 0)
	LDataPack.writeInt(pack, 0)
	LDataPack.writeInt(pack, 0)
	LDataPack.writeInt(pack, -1)
	LDataPack.writeInt(pack, 0)
	LDataPack.writeInt(pack, 0)
end

function PackRankDataHandle(actorId, pack, type)
	if System.isCrossWarSrv() then return end
	if actorId == 0 then
		setNullRankPack(pack)
		return
	end
	local roleCloneData,actorCloneData = actorcommon.getCloneData(actorId)
	if not roleCloneData or not actorCloneData then
		setNullRankPack(pack)
		return
	end
	if isShowAllInfo(type) then
		LDataPack.writeByte(pack, roleCloneData.job)
		LDataPack.writeInt(pack, roleCloneData.shenzhuangchoose)
		LDataPack.writeInt(pack, roleCloneData.shenqichoose)
		LDataPack.writeInt(pack, roleCloneData.wingchoose)
		LDataPack.writeInt(pack, roleCloneData.touxian)
		LDataPack.writeInt(pack, roleCloneData.title)
		LDataPack.writeInt(pack, 0) --人物法阵id
		LDataPack.writeInt(pack, actorCloneData.damonchoose)
		LDataPack.writeInt(pack, actorCloneData.meilinchoose)
		local actor = LActor.getActorById(actorId)
		if actor then
			LDataPack.writeInt(pack, liliansystem.getJunxianLevel(actor))
			LDataPack.writeInt(pack, hunqisystem.getHunqiLevel(actor))
		else
			local EBasicData = GetDataByOffLineDataType(actorId, EOffLineDataType.EBasic)
			if not EBasicData then 
				LDataPack.writeInt(pack, 0)
				LDataPack.writeInt(pack, 0)
			else
				LDataPack.writeInt(pack, EBasicData.junxianlevel)
				LDataPack.writeInt(pack, EBasicData.hunqistage)
			end
		end
		LDataPack.writeInt(pack, 0)
	elseif type == RankingType_Damon then
		LDataPack.writeInt(pack, actorCloneData.damonchoose)
		LDataPack.writeInt(pack, actorCloneData.damonfazhen)
	elseif type == RankingType_Yongbing then
		LDataPack.writeInt(pack, actorCloneData.yongbingchoose)
		LDataPack.writeInt(pack, actorCloneData.yonbingfazhen)
	elseif type == RankingType_Shenqi then
		LDataPack.writeByte(pack, roleCloneData.job)
		LDataPack.writeInt(pack, roleCloneData.shenqichoose)
	elseif type == RankingType_Wing then
		LDataPack.writeByte(pack, roleCloneData.job)
		LDataPack.writeInt(pack, roleCloneData.wingchoose)
	elseif type == RankingType_Shenzhuang then
		LDataPack.writeByte(pack, roleCloneData.job)
		LDataPack.writeInt(pack, roleCloneData.shenzhuangchoose)
	elseif type == RankingType_Meilin then
		LDataPack.writeByte(pack, roleCloneData.job)
		LDataPack.writeInt(pack, actorCloneData.meilinchoose)
	elseif type == RankingType_Shenmo then
		local actor = LActor.getActorById(actorId)
		if actor then
			LDataPack.writeByte(pack, LActor.getJob(actor))
			LDataPack.writeInt(pack, shenmosystem.getShenmoId(actor))
		else
			local EBasicData = GetDataByOffLineDataType(actorId, EOffLineDataType.EBasic)
			if EBasicData then
				LDataPack.writeByte(pack, EBasicData.job)
				LDataPack.writeInt(pack, EBasicData.shenmochoose)
			else
				LDataPack.writeByte(pack, 0)
				LDataPack.writeInt(pack, 0)
			end
		end
	end
end

function PackViewDataHandle(actorId, pack)
	--if System.isCrossWarSrv() then return end
	local roleCloneData,actorCloneData = actorcommon.getCloneData(actorId)
	if not roleCloneData or not actorCloneData then
		LDataPack.writeByte(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeString(pack, "")
		LDataPack.writeShort(pack, 0)
		LDataPack.writeDouble(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeByte(pack, 0)
		return
	end
	LDataPack.writeByte(pack, roleCloneData.job)
	LDataPack.writeInt(pack, actorId)
	LDataPack.writeInt(pack, actorCloneData.serverId)
	LDataPack.writeString(pack, roleCloneData.name or "")
	LDataPack.writeShort(pack, roleCloneData.level)
	LDataPack.writeDouble(pack, roleCloneData.total_power)
	LDataPack.writeInt(pack, roleCloneData.shenzhuangchoose)
	LDataPack.writeInt(pack, roleCloneData.shenqichoose)
	LDataPack.writeInt(pack, roleCloneData.wingchoose)
	LDataPack.writeInt(pack, actorCloneData.meilinchoose)
	LDataPack.writeInt(pack, actorCloneData.damonchoose)
	LDataPack.writeInt(pack, roleCloneData.shengling_id)
	LDataPack.writeByte(pack, EquipType_Max)
	local actor = LActor.getActorById(actorId)
	if actor then
		local var = equipsystem.getActorVar(actor)
		for i=0, EquipType_Max-1 do
			LDataPack.writeInt(pack, var[i] or 0)
		end
	else
		local EBasicData = GetDataByOffLineDataType(actorId, EOffLineDataType.EBasic)
		for i=0, EquipType_Max-1 do
			LDataPack.writeInt(pack, EBasicData and EBasicData.equips[i] or 0)
		end
	end
end

function bson2txt()
	if System.isBattleSrv() then return end
	print("offlinedatamgr bson2txt")
	local queryStr = "call loadofflinedata()"
	local db = System.createActorsDbConn()
	if db == nil then return end
	local err = System.dbQuery(db, queryStr)
	if err ~= 0 then
		System.dbClose(db)
		System.delActorsDbConn(db)
		print("bson2txt sql query error:".. queryStr)
		return
	end

	offlineDataSet = {}
	local row = System.dbCurrentRow(db)
	while row do
		local actorId = tonumber(System.dbGetRow(row, 0))
		-- print('offlinedatamgr bson2txt actorId=' .. tostring(actorId))
		local len = System.dbGetLen(db, 1)
		local dbud = System.dbCopyRowToUserData(row, 1, len)
		local udtable = bson.decode(dbud)
		offlineDataSet[actorId] = udtable
		local tData = udtable[EOffLineDataType.EBasic]
		SetDataByOffLineDataType(actorId, EOffLineDataType.EBasic, tData, true)
		row = System.dbNextRow(db)
	end

	System.dbResetQuery(db)
	System.dbClose(db)
	System.delActorsDbConn(db)

	for actor_id in pairs(offlineDataSet) do
		local t = GetDataByOffLineDataType(actor_id, EOffLineDataType.EBasic, true)
		System.saveOfflineData(actor_id, t)
	end
	print("offlinedatamgr bson2txt end")
end

-- 只转换vardata!=null strdata==null
function bson2txt2()
	if System.isBattleSrv() then return end
	print("offlinedatamgr bson2txt2")
	local queryStr = "call loadofflinedata()"
	local db = System.createActorsDbConn()
	if db == nil then return end
	local err = System.dbQuery(db, queryStr)
	if err ~= 0 then
		System.dbClose(db)
		System.delActorsDbConn(db)
		print("bson2txt sql query error:", queryStr)
		return
	end

	offlineDataSet = {}
	local row = System.dbCurrentRow(db)
	while row do
		local actorId = tonumber(System.dbGetRow(row, 0))
		-- print('offlinedatamgr bson2txt2 actorId=' .. tostring(actorId))
		local len = System.dbGetLen(db, 1)
		local dbud = System.dbCopyRowToUserData(row, 1, len)
		local strdata = System.dbGetRow(row, 2)
		if dbud and strdata == nil then
			print('offlinedatamgr bson2txt2 actorId=', actorId)
			local udtable = bson.decode(dbud)
			offlineDataSet[actorId] = udtable
			local tData = udtable[EOffLineDataType.EBasic]
			SetDataByOffLineDataType(actorId, EOffLineDataType.EBasic, tData, true)
		end
		row = System.dbNextRow(db)
	end

	System.dbResetQuery(db)
	System.dbClose(db)
	System.delActorsDbConn(db)

	for actor_id in pairs(offlineDataSet) do
		local t = GetDataByOffLineDataType(actor_id, EOffLineDataType.EBasic, true)
		System.saveOfflineData(actor_id, t)
	end
	print("offlinedatamgr bson2txt2 end")
end

function LoadData()
	if System.isBattleSrv() then return end
	print("offlinedatamgr LoadData")
	local queryStr = "SELECT actorid,strdata FROM offlinedata;"
	local db = System.createActorsDbConn()
	if db == nil then return end
	local err = System.dbQuery(db, queryStr)
	if err ~= 0 then
		System.dbClose(db)
		System.delActorsDbConn(db)
		print("sql query error:".. queryStr)
		return
	end

	offlineDataSet = {}
	local row = System.dbCurrentRow(db)
	while row do
		local actorId = tonumber(System.dbGetRow(row, 0))
		if actorId then
			local s = System.dbGetRow(row, 1)
			if s then
				s = 'return ' .. s
				local chunk = loadstring(s)
				local ok, t = pcall(chunk)
				if ok then
					SetDataByOffLineDataType(actorId, EOffLineDataType.EBasic, t, true)
				else
					print('offlinedatamgr LoadData err=' .. t .. ' actorId=' .. actorId)
				end
			-- else
			-- 	print('offlinedatamgr LoadData s==nil actorId=' .. actorId)
			end
		else
			print('offlinedatamgr LoadData actorId==nil')
		end

		row = System.dbNextRow(db)
	end

	System.dbResetQuery(db)
	System.dbClose(db)
	System.delActorsDbConn(db)
	print("offlinedatamgr LoadData end")
end


function SaveData()
	if System.isBattleSrv() then return end
	--在线玩家保存离线数据
	local actors = System.getOnlineActorList()
	if actors then
		for i = 1, #actors do
			local actor = actors[i]
			if actor then
				EhLogout(actor)
			end
		end
	end

	print("offlinedatamgr SaveData")
	local bt = os.clock()
	if offlineDataSet == nil then
		print("offlinedatamgr SaveData error: offlineDataSet is nil")
		return
	end
	local db = System.createActorsDbConn()
	if db == nil then return end
	System.dbSetLog(db, false)

	for actorId, data in pairs(offlineDataSet) do
		repeat
			local EMiscData = data[EOffLineDataType.EMisc]
			if EMiscData == nil or not EMiscData.isDirty then
				break
			end

			local t = GetDataByOffLineDataType(actorId, EOffLineDataType.EBasic, true)
			System.saveOfflineData(actorId, t)
			EMiscData.isDirty = false
		until(true)
	end

	System.dbResetQuery(db)
	System.dbClose(db)
	System.delActorsDbConn(db)
	local et = os.clock()
	print("offlinedatamgr SaveData: cost time:" .. (et - bt))
	print("offlinedatamgr SaveData end")
end


function PackData(actor)
	local actorId = LActor.getActorId(actor)
	local packTable = {LActor.getOffLinePack(actor)}
	SetDataByOffLineDataType(actorId, EOffLineDataType.EPack, packTable)
end


--玩家登出保存离线数据
function EhLogout(actor, args)
	if System.isBattleSrv() then return end
	local actorId = LActor.getActorId(actor)
	--ClearData(actorId)
	local var = LActor.getStaticVar(actor)
	local actorBasicData = LActor.getActorData(actor)

	local tData = GetDataByOffLineDataType(actorId, EOffLineDataType.EBasic, true)
	tData.account_id = actorBasicData.account_id
	tData.actor_id = actorBasicData.actor_id
	tData.actor_name = actorBasicData.actor_name
	tData.job = actorBasicData.job
	tData.sex = actorBasicData.sex
	tData.level = actorBasicData.level
	tData.total_power = actorBasicData.total_power
	tData.total_rank_power = actorBasicData.total_rank_power
	tData.vip = actorBasicData.vip --vip
	tData.vip_level = actorBasicData.vip_level --svip
	tData.monthcard = actorBasicData.monthcard
	tData.guild_id_ = actorBasicData.guild_id_
	tData.guild_name_ = LGuild.getGuilNameById(actorBasicData.guild_id_) or ''
	tData.guild_pos = actorBasicData.guild_pos or 0
	tData.last_online_time = actorBasicData.last_online_time
	tData.touxian = touxiansystem.getTouxianStage(actor)
	tData.junxian = liliansystem.getJunxianStage(actor)
	tData.junxianlevel = liliansystem.getJunxianLevel(actor)
	tData.serverId = actorBasicData.server_index
	tData.isguildbattlewin = 0 --所在的罗兰城战是否胜利
	--被动技能
	tData.passive_count = actorBasicData.passive_count
	tData.passiveskills = {}
	for i=0, actorBasicData.passive_count - 1 do
		tData.passiveskills[i] = {}
		tData.passiveskills[i].id = actorBasicData.passiveskills[i].id
		tData.passiveskills[i].level = actorBasicData.passiveskills[i].level
	end

	--技能
	tData.skills = {}
	for i=0, SkillsLen_Max - 1 do
		tData.skills[i] = actorBasicData.skills[i].skill_level
	end

	--装备
	tData.equips = {}
	for i = 0, 20-1 do
		tData.equips[i] = equipsystem.getActorVar(actor)[i]
	end

	tData.shenqichoose = shenqisystem.getActorVar(actor).choose
	tData.shenzhuangchoose = shenzhuangsystem.getActorVar(actor).choose
	tData.wingchoose = wingsystem.getWingId(actor)
	tData.meilinchoose = meilinsystem.getActorVar(actor).choose
	local yonbingvar = yongbingsystem.getActorVar(actor)
	tData.yongbingchoose = yonbingvar.yongbingchoose
	tData.yonbingfazhen = yonbingvar.mozhenchoose
	local yongbingskilllv = passiveskill.getSkillLv(actor, YongbingConstConfig.levelskills[1])
	tData.yongbingskill = SkillPassiveConfig[YongbingConstConfig.levelskills[1]][yongbingskilllv].other
	local damonvar = damonsystem.getActorVar(actor)
	tData.damonchoose = damonvar.damonchoose
	tData.damonfazhen = damonvar.mozhenchoose
	tData.shenmochoose = shenmosystem.getShenmoId(actor)
	tData.mozhen = shenmosystem.getShenmoFazhen(actor)
	tData.hunqistage = hunqisystem.getHunqiLevel(actor)
	tData.title = titlesystem.getRoleTitle(actor) or 0
	tData.shengling_id = getShengLingId(actor)
	tData.shield_id = getShenYouShieldId(actor) -- 神佑幻化id
	tData.shield_skill_id = LActor.getShenyouShieldSkillId(actor) -- 护盾技能
	tData.shield_use_skill_id = shenyousystem.getShieldUseSkill(actor) -- 盾爆技能
	tData.shield_tag_skill_id = LActor.getShenyouTagSkillId(actor) -- 印记技能

	--属性
	tData.attrs = {}
	local attrsData = LActor.getRoleAttrsBasic(actor)
	for j = Attribute.atHp, Attribute.atCount - 1 do
		tData.attrs[j] = attrsData[j]
	end
	tData.attrs[Attribute.atShenYouShield] = 0 -- 护盾值清0
	tData.attrs[Attribute.atShenYouShieldTag] = 0 -- 印记值清0

	-- --称号
	-- offRoleData.title = titlesystem.getRoleTitle(actor, 0) or 0

	PackData(actor)

	local EMiscData = GetDataByOffLineDataType(actorId, EOffLineDataType.EMisc, true)
	EMiscData.isDirty = true

	System.saveOfflineData(actorId, tData)
end

function CallEhLogout(actor, ...)
	if System.isBattleSrv() then return end
	EhLogout(actor, ...)
end

local function OnGameStart( ... )
	if System.isBattleSrv() then return end
	LoadData()
	--LActor.postScriptEventEx(nil, SAVE_TIME, function(...) SaveData() end, SAVE_TIME, -1)
end

_G.PackRankDataHandle = PackRankDataHandle
_G.PackViewDataHandle = PackViewDataHandle

actorevent.reg(aeUserLogout, EhLogout)

--起服加载数据
engineevent.regGameStartEvent(OnGameStart)
--停服保存数据
engineevent.regGameStopEvent(SaveData)
