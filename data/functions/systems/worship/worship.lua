--膜拜系统
module("worship", package.seeall)

--[[
    worshipData = {
		{
			record
		}
    }
--]]

--膜拜数据包缓存

local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then return nil end

    if var.worshipData == nil then
        var.worshipData = {}
    end
    return var.worshipData
end

local function initData(actor)
	local var = getStaticData(actor)
	local i = 0
	while (i < RankingType_Count) do 
		if var[i] == nil then 
			var[i] = 
			{
				record = 0,
			}
		end
		i = i + 1
	end
end

local function sendReqWorshipData(actor,type)
	local var = getStaticData(actor)
	if var[type] == nil  then 
		return
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResWorshipData)
	if npack == nil then 
		return
	end
	LDataPack.writeChar(npack, type)	
	local len, cache = Ranking.getRankingFirstCacheByType(type)
	if cache ~= nil and len ~= 4 then 
		LDataPack.writeChar(npack, 1)
		LDataPack.writeChar(npack, var[type].record)
		LDataPack.writePacket(npack, cache)
	else
		LDataPack.writeChar(npack, 0) 
		LDataPack.writeChar(npack, var[type].record)
		LDataPack.writeInt(npack,0)		
	end
	LDataPack.flush(npack)
end

local function sendWorshipData(actor,type)
	local var = getStaticData(actor)
	if var[type] == nil then 
		return
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_UpdateWorship)
	if npack == nil then 
		return
	end
	LDataPack.writeShort(npack,type)
	LDataPack.writeShort(npack,var[type].record)
	LDataPack.flush(npack)
end

local function worship(actor,type)
	local var = getStaticData(actor)
	if var[type] == nil then 
		return
	end
	local level = LActor.getLevel(actor)

	local typeConf =  WorshipConfig[type]
	if typeConf == nil then
		print("not config type " .. type)
		return
	end
	
	local index = 1
	if level == typeConf[#typeConf].level then
		index = #typeConf
	else
		for i = 1, #typeConf do
			local one = typeConf[i]
			if level < one.level then
				index = i - 1 
				break
			end
		end
	end
	local conf = typeConf[index]
	if conf == nil then 
		print("no has config " .. type .. " " .. level)
		return
	end
	if conf.count <= var[type].record then
		log_print(LActor.getActorId(actor) .. "worship: record " .. conf.count .. ":" .. var[type].record)
		return
	end

	var[type].record = var[type].record + 1
	actoritem.addItems(actor,conf.awards,"worship award")
	log_print(LActor.getActorId(actor) .. " worship " .. var[type].record .. " " .. conf.count)
	sendWorshipData(actor,type)
	actorevent.onEvent(actor, aeWorship, index)
end

local function ReqAllWorship(actor)
	local var = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_Ranking,Protocol.sRankingCmd_ResAllWorshipData)
	if npack == nil then 
		return
	end 

	LDataPack.writeShort(npack,RankingType_Count)
	for i = 0, RankingType_Count do 
		if not var[i] then
			break
		end
		LDataPack.writeShort(npack,i)
		LDataPack.writeShort(npack,var[i].record)
		
	end
	LDataPack.flush(npack)
end



local function onInit(actor)
	initData(actor)
end

local function onLogin( actor )
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.rank) then return end
	ReqAllWorship(actor)
end

local function onNewDay(actor, login)
	local var = getStaticData(actor)
	local i = 0
	while (i < RankingType_Count) do 
		var[i].record = 0
		i = i + 1
	end
	if not login then
		ReqAllWorship(actor)
	end
end

local function onLevelUp(actor, level, oldLevel)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.rank) then return end
	ReqAllWorship(actor)
end

local function onReqWorshipData(actor,pack)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.rank) then return end
	local type = LDataPack.readShort(pack)
	sendReqWorshipData(actor,type)
end

local function onReqWorship(actor,pack)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.rank) then return end
	local type = LDataPack.readShort(pack)
	worship(actor,type)
end

local function onReqAllWorship(actor,pack)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.rank) then return end
	ReqAllWorship(actor)
end


function updateDynamicFirstCache(actor_id,type)
	Ranking.updateDynamicFirstCache(actor_id,type)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeLevel, onLevelUp)

local function fuBenInit()
    if System.isCrossWarSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Ranking, Protocol.cRankingCmd_ReqWorshipData, onReqWorshipData)
	netmsgdispatcher.reg(Protocol.CMD_Ranking, Protocol.cRankingCmd_ReqWorship, onReqWorship)
end

table.insert(InitFnTable, fuBenInit)


--netmsgdispatcher.reg(Protocol.CMD_Ranking, Protocol.cRankingCmd_ReqAllWorshipData, onReqAllWorship)

--_G.updateWorshipData = updateWorshipData

