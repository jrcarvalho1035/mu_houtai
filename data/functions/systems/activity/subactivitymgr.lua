--活动子类型函数定义
--如果扩展太多类型,再考虑分文件
module("subactivitymgr", package.seeall)
require("activity.type1")
require("activity.type2")
require("activity.type3")
require("activity.type3ex")
require("activity.type4")
require("activity.type5")
require("activity.type6")
require("activity.type9")
require("activity.type10")
require("activity.type11")
require("activity.type12")
require("activity.type13")
require("activity.type14")
require("activity.type15")
require("activity.type16")
require("activity.type17")
require("activity.type18")
require("activity.type19")
require("activity.type20")
require("activity.type20ex")
require("activity.type21")
require("activity.type22")
require("activity.type23")
require("activity.type24")
require("activity.type25")
require("activity.type26")
require("activity.type27")
require("activity.type28")
require("activity.type30")
require("activity.type31")
require("activity.type32")
require("activity.type33")
require("activity.type34")
require("activity.type35")
require("activity.type36")
require("activity.type37")
require("activity.type38")
require("activity.type39")
require("activity.type39task")
require("activity.type39ex")
require("activity.type40")
require("activity.type41")
require("activity.type42")
require("activity.activitycommon")

--处理函数列表
writeRecordFuncs = {}
getRewardFuncs = {}
getRewardTimeOut = {}
reqInfoFuncs = {}
reqInfoTimeOut = {}
initFuncs = {}
actorLoginFuncs = {}
confList = {}
newDayFuncs = {}
newDayAfterFuncs = {}
timeOut = {}
activityFinish = {}


local p = Protocol


-- 子类型初始化函数注册
--func(id, conf)
function regInitFunc(tp, func)
	initFuncs[tp] = func
end

function regNewDayFunc(tp, func)
	newDayFuncs[tp] = func
end

function regNewDayAfterFunc(tp, func)
	newDayAfterFuncs[tp] = func
end

-- 更新数据回包函数注册
--func(npack, record, config)
function regWriteRecordFunc(tp, func)
	writeRecordFuncs[tp] = func
end

function regLoginFunc(tp, func)
	actorLoginFuncs[tp] = func
end

-- 领取奖励回调函数注册
--func(id, typeconfig, actor, record, packet)
function regGetRewardFunc(tp, func)
	getRewardFuncs[tp] = func
end

-- 请求信息回调函数注册
--func(id, typeconfig, actor, record, packet)
function regReqInfoFunc(tp, func)
	reqInfoFuncs[tp] = func
end

-- 注册配置
function regConf(tp, conf)
	if confList[tp] ~= nil then
		assert(false)
		return
	end
	confList[tp] = conf
end

-- 玩家登录时活动已结束
function regTimeOut(tp, func)
	if timeOut[tp] ~= nil then
		assert(false)
		return
	end
	timeOut[tp] = func
end

-- 玩家在线时活动结束
function regActivityFinish(tp, func)
	if activityFinish[tp] ~= nil then
		assert(false)
		return
	end
	activityFinish[tp] = func
end

----------------------------------------------------
--获取类型配置
function getConfig(tp)
	if tp == 1 then
		return ActivityType1Config
	elseif tp == 2 then
		return ActivityType2Config
	elseif tp == 3 then
		return ActivityType3Config
	elseif tp == 4 then
		return ActivityType4Config
	elseif tp == 5 then
		return ActivityType5Config
	elseif tp == 6 then
		return ActivityType6Config
	elseif tp == 7 then
		return ActivityType7Config
	elseif tp == 9 then
		return ActivityType9Config
	elseif tp == 10 then
		return ActivityType10Config
	elseif tp == 11 then
		return ActivityType11Config
	elseif tp == 12 then
		return ActivityType12Config
	elseif tp == 13 then
		return ActivityType13Config
	elseif tp == 14 then
		return ActivityType14Config
	elseif tp == 15 then
		return ActivityType15Config
	elseif tp == 16 then
		return ActivityType16Config
	elseif tp == 17 then
		return ActivityType17Config
	elseif tp == 18 then
		return ActivityType18Config
	elseif tp == 19 then
		return ActivityType19Config
	elseif tp == 20 then
		return ActivityType20Config
	elseif tp == 21 then
		return ActivityType21Config
	elseif tp == 22 then
		return ActivityType22Config
	elseif tp == 23 then
		return ActivityType23Config
	elseif tp == 24 then
		return ActivityType24Config
	elseif tp == 25 then
		return ActivityType25Config
	elseif tp == 26 then
		return ActivityType26Config
	elseif tp == 27 then
		return ActivityType27Config
	elseif tp == 28 then
		return ActivityType28Config
	elseif tp == 30 then
		return ActivityType30Config
	elseif tp == 31 then
		return ActivityType31Config
	elseif tp == 32 then
		return ActivityType32Config
	elseif tp == 33 then
		return ActivityType33Config
	elseif tp == 34 then
		return ActivityType34Config
	elseif tp == 35 then
		return ActivityType35Config
	elseif tp == 36 then
		return ActivityType36Config
	elseif tp == 37 then
		return ActivityType37Config
	elseif tp == 38 then
		return ActivityType38Config
	elseif tp == 39 then
		return ActivityType39Config
	elseif tp == 40 then
		return ActivityType40Config
	elseif tp == 41 then
		return ActivityType41Config
	elseif tp == 42 then
		return ActivityType42Config
	else
		return confList[tp]
	end
end


function init(tp, id, data)
	if initFuncs[tp] then
		local conf = getConfig(tp)
		initFuncs[tp](id, conf and conf[id], data)
	end
end

function onNewDay(actor, tp, id, record, login)
	if newDayFuncs[tp] then
		local config = getConfig(tp)
		newDayFuncs[tp](actor, record, config, id, login)
	end
end

function onNewDayAfter(actor, tp, id)
	if newDayAfterFuncs[tp] then
		newDayAfterFuncs[tp](actor, id)
	end
end

--下发数据处理
function writeRecord(id, tp, npack, record, actor)
	if writeRecordFuncs[tp] then
		local config = getConfig(tp)
		writeRecordFuncs[tp](npack, record, config[id], id, actor)
	end
end

function onLogin(actor, tp)
	if actorLoginFuncs[tp] then
		actorLoginFuncs[tp](actor)
	end
end

function onGetReward(actor, tp, id, idx, record, packet)
	if getRewardFuncs[tp] then
		local config = getConfig(tp)
		getRewardFuncs[tp](actor, config, id, idx, record, packet)
	end
end

function onReqInfo(tp, id, actor, record, packet)
	if reqInfoFuncs[tp] then
		local config = getConfig(tp)
		reqInfoFuncs[tp](id, config, actor, record, packet)
	end
end

function onTimeOut(tp, id, actor, record)
	local config = getConfig(tp)
	if config == nil then return end
	if timeOut[tp] then
		timeOut[tp](id, config, actor, record)
	end
end

function onActivityFinish(tp, id)
	if activityFinish[tp] then
		activityFinish[tp](id)
	end
end

-- 策划要求活动时间过了，还要求可以领取奖励
function onGetRewardTimeOut(id,actor,packet)
	--读取配置，获得类型
	local tp = ActivityConfig[id].activityType
	if getConfig(tp) == nil then
		return
	end
	local record = activitymgr.getSubVar(actor, id)

	if getRewardTimeOut[tp] then
		local config = getConfig(tp)
		getRewardTimeOut[tp](id, config, actor, record, packet)
	end
end

-- 策划要求活动时间过了，还要求可以领取奖励
function onReqInfoTimeOut(id,actor,packet)
	--读取配置，获得类型
	local tp = ActivityConfig[id].activityType
	if getConfig(tp) == nil then
		return
	end
	local record = activitymgr.getSubVar(actor, id)

	if reqInfoTimeOut[tp] then
		local config = getConfig(tp)
		reqInfoTimeOut[tp](id, config, actor, record, packet)
	end
end
