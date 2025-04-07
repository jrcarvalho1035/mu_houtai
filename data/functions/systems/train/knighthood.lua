module("knighthood", package.seeall)
require("knighthood.knighthoodbasic")
require("knighthood.knighthood")
require("knighthood.knighthoodstage")

local function isOpen(actor)
	return LActor.getLevel(actor) >= KnighthoodBasicConfig.openLevel;
end

local function getKnighthoodData(actor)
	if not isOpen(actor) then
		return nil
	end

	local var = LActor.getStaticVar(actor) 

	if var == nil then 
		return nil
	end

	if var.knighthood == nil then
		var.knighthood       = {}
		var.knighthood.level = 0
		var.knighthood.exp = 0
	end
	return var.knighthood

end

-- local function isLevelUp(actor)
-- 	local var = getKnighthoodData(actor)
-- 	if var == nil then 
-- 		--print("not open")
-- 		return false
-- 	end
-- 	if KnighthoodConfig[var.level] == nil or KnighthoodConfig[var.level].achievementIds == nil then 
-- 		--print("not config")
-- 		return false
-- 	end
-- 	if not next(KnighthoodConfig[var.level].achievementIds) then
-- 		--print("not achievementIds")
-- 		return false
-- 	end

-- 	local achievementIds = KnighthoodConfig[var.level].achievementIds
-- 	for i,v in pairs(achievementIds) do 
-- 		if not achievetask.isFinish(actor,v.achieveId,v.taskId)then 
-- 			--print("not finish " .. utils.t2s(v))
-- 			return false
-- 		end
-- 	end
-- 	--print("ok LevelUp")
-- 	return true
-- end

local function SendKnighthoodData(actor)
	local data = getKnighthoodData(actor)
	local is_open = isOpen(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Train, Protocol.sTrainCmd_KnighthoodData)
	if npack == nil then 
		return 
	end
	-- print("=============SendKnighthoodData==========")
	-- print("=============SendKnighthoodData==========")
	-- print("=============SendKnighthoodData==========")
	-- print("=============SendKnighthoodData==========")
	LDataPack.writeByte(npack,is_open and 1 or 0) 
	if not is_open then
		LDataPack.flush(npack)
	else 
		-- LDataPack.writeByte(npack,isLevelUp(actor) and 1 or 0)
		LDataPack.writeInt(npack,data.level)
		LDataPack.writeInt(npack,data.exp)
		LDataPack.flush(npack)
	end
end

local function loadAttrs(actor) 
	--print("LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL")
	local attr = LActor.getKnighthoodAttr(actor)
	attr:Reset()
	if not isOpen(actor) then 
		--print("not open")
		return 
	end
	local var = getKnighthoodData(actor)
	if var == nil then 
		--print("not var")
		return 	
	end
	if KnighthoodConfig[var.level] == nil or KnighthoodConfig[var.level].attrs == nil then 
		--print("not config")
		return 
	end
	if not next(KnighthoodConfig[var.level].attrs) then 
		--print("not attr")
		return
	end
	
	local tmp = KnighthoodConfig[var.level].attrs

	for i,v in pairs(tmp) do 
		attr:Set(v.type,v.value)
		--print(utils.t2s(v))
	end
	--print("load attr ok")
	LActor.reCalcAttr(actor)
	--print("LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL")
end


function updateknighthoodData(actor,addexp)
	local data = getKnighthoodData(actor)
	if (nil == data) then
		return
	end
	
	data.exp   = data.exp + addexp
	SendKnighthoodData(actor)
end

local function onLevelUpKnighthood(actor,packet)
	local data = getKnighthoodData(actor)
	local level = data.level

	local conf = KnighthoodConfig[level]
	if not conf then
		print("KnighthoodConfig is error!!!!!!")
		return
	end

	local exp = data.exp
	if exp < conf.costScore then

		return
	end

	data.level = data.level + 1
	print("LevelUpKnighthood:"..data.level)

	SendKnighthoodData(actor)
	loadAttrs(actor)	
end




--net
-- local function onLevelUpKnighthood(actor, packet)
-- 	--print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
-- 	-- if isLevelUp(actor) then 
-- 	-- 	local var = getKnighthoodData(actor) 
-- 	-- 	local achievementIds = KnighthoodConfig[var.level].achievementIds
-- 	-- 	for i,v in pairs(achievementIds) do 
-- 	-- 		achievetask.finishAchieveTask(actor,v.achieveId,v.taskId)
-- 	-- 	end
-- 	-- 	var.level = var.level + 1
-- 	-- 	SendKnighthoodData(actor)
-- 	-- 	loadAttrs(actor)
-- 	-- end
-- 	--print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")

-- end
--net end
local function onBeforeLogin( actor )
	--print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
	loadAttrs(actor)
end
local function onLogin(actor)
	--print("BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
	--print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
	SendKnighthoodData(actor)
	--print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
end

local function onLevelUp(actor)
	if LActor.getLevel(actor) ==   KnighthoodBasicConfig.openLevel then
		SendKnighthoodData(actor)
	end
end

local function onAchievetaskFinish(actor,achieveId,taskId)
	-- if isLevelUp(actor) then
	-- 	SendKnighthoodData(actor)
	-- end
	-- local conf = AchievementTaskConfig[]


end


local function init() 
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeLevel, onLevelUp)
	actorevent.reg(aeAchievetaskFinish, onAchievetaskFinish)
	actorevent.reg(aeInit,onBeforeLogin)
	netmsgdispatcher.reg(Protocol.CMD_Train, Protocol.cTrainCmd_LevelUpKnighthood, onLevelUpKnighthood)
	
end
table.insert(InitFnTable, init)

