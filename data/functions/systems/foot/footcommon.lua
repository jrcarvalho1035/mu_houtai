module("footcommon", package.seeall)

local ONEDAYSEC = 24 * 3600   -- 一天有多少秒
local BASEPERCENTNUM = 10000  -- 权重配置的基数

function isOpenFoot(actor)
	actorVar = LActor.getStaticVar(actor)
	return actorVar.footactive
end

function setOpenFoot(actor)
	actorVar = LActor.getStaticVar(actor)
	actorVar.footactive = 1
end

function getStaticVar(actor, init)
	local actorVar = LActor.getStaticVar(actor)
	if init then
		if actorVar.foot == nil then
			actorVar.foot = {}
			initVar(actorVar.foot)
		end
	end
	return actorVar.foot
end


function getStar(actor)
	local var = getStaticVar(actor,true)
	return var.star
end

function getStage(actor)
	local var = getStaticVar(actor,true)
	return var.stage
end

function initVar(var)
	var.level = 1  -- 1级
	var.levelexp = 0
	var.trainTime = 0  -- 开始计算恢复的时间起点
	var.trainCount = FootConfig.maxtraincount  -- 默认次数

	var.stage = 1  -- 1阶
	var.star = 0
	var.starexp = 0
	var.tuPo = 0
	var.showStage = 1
end

function footLog(actor, type, str, val)
	local s = string.format("actor:%d type:%d str:%s val:%d", LActor.getActorId(actor), type, str, val)
	print(s)
end

-- 是否能够训练(是否还未到训练的最高等级)
function canTrain(var)
	local maxConf = FootLevel[#FootLevel]
	local isMax = (var.level >= maxConf.level and var.levelexp >= maxConf.count)
	return not isMax
end

-- 添加等级经验(训练后加的经验)
function addLevelExp(var, exp)
	var.levelexp = var.levelexp + exp
	local maxLevel = #FootLevel
	while true do
		local conf = FootLevel[var.level]
		if var.levelexp < conf.count then
			return
		end

		local newLevel = var.level + 1
		if newLevel <= maxLevel then
			var.levelexp = var.levelexp - conf.count
			var.level = newLevel
		else
			var.level = maxLevel
			var.levelexp = conf.count
			return
		end
	end
end

-- 能否升星
function canUpStar(var)
	local conf = FootStage[var.stage]
	return (var.star < conf.star)
end

-- 加进阶经验
function addStageExp(var, exp)
	var.starexp = var.starexp + exp
	while true do
		local conf = FootStage[var.stage]
		local needExp = conf.starexp[var.star+1]
		if not needExp then return end
		if var.starexp < needExp then
			return
		end

		local newStar = var.star + 1
		if newStar <= conf.star then
			var.starexp = var.starexp - needExp
			var.star = newStar
		else
			return
		end
	end
end

-- 能否突破
function canTuPo(var)
	local conf = FootStage[var.stage]
	local maxStage = #FootStage
	return (var.star >= conf.star and var.stage < maxStage)
end


-- 根据权重随机
function randOne(arr)
	local n = math.random(1, BASEPERCENTNUM)
	local sum = 0
	for index, v in ipairs(arr) do
		sum = sum + v.rate
		if n <= sum then
			return index, v
		end
	end
end

function randOneWithN(arr)
	return randOne(arr)
end

-- 数组中随机出一个
function randOneNormal(arr)
	local len = #arr
	local index = math.random(1, len)
	return index, arr[index]
end


