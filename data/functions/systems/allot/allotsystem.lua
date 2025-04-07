-- @version	1.0
-- @author	qianmeng
-- @date	2017-1-4 18:23:12.
-- @system	allot

module( "allotsystem", package.seeall )

require("allot.allotcommon")
require("allot.allotattr")
require("allot.allotjob")

function addAllotAttr(actor, roleId)
	local point = 0
	local allots = {0,0,0,0}
	point,allots[1],allots[2],allots[3],allots[4] = LActor.getAllotInfo(actor, roleId)
	for i=1, 4 do
		local tp = AllotAttrConfig[i].tp
		LActor.addAllotAttr(actor, roleId, tp, allots[i])
	end
end

function updateAttr(actor, roleId, calc)
	LActor.clearAllotAttr(actor, roleId) --清零
	addAllotAttr(actor, roleId)
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)--刷新角色属性
	end
end

function allotAttrInit(actor, roleId)
	LActor.clearAllotAttr(actor, roleId)
	addAllotAttr(actor, roleId)
end
_G.allotAttrInit = allotAttrInit

function autoAllotPoint(actor, roleId, jobId)
	local point = 0
	local allots = {0,0,0,0}
	point,allots[1],allots[2],allots[3],allots[4] = LActor.getAllotInfo(actor, roleId)
	if not point then
		print("Error get allot")
		return
	end
	local count = point --剩余
	local jobConfig = AllotJobConfig[jobId]
	for k, idx in ipairs(jobConfig.sequence) do --按重要性顺序加点
		if count <= 0 then
			break
		end
		local per = jobConfig.recommend[idx] --百分比
		local value = math.floor(point*per/100 + 0.5)
		value = value>count and count or value --分配点数不能超过剩余属性点
		LActor.setAllotPoint(actor, roleId, idx-1, value)
		count = count - value
	end
	utils.logCounter(actor, "allot auto", roleId)
	updateAttr(actor, roleId, false)
end

--该等级该拥有点数
function getPointByLevel(actor, roleId)
	local role = LActor.getRole(actor, roleId)
	local jobId = LActor.getJob(role)
	local level = LActor.getLevel(actor)
	local zhuanshengLevel = LActor.getZhuanShengLevel(actor)
	local zsPoint = 0
	for i = 1, zhuanshengLevel do
		zsPoint = zsPoint + ZhuanshengLevelConfig[i].point
	end
	local point = RoleConfig[jobId][level].point
	return point + zsPoint
end

--检测点数是否匹配，少了就加上，多了就重置
function checkRolePoint(actor, roleId)
	local a1, a2, a3, a4, a5 = LActor.getAllotInfo(actor, roleId)
	local sum = a1 + a2 + a3 + a4 + a5
	local point = getPointByLevel(actor, roleId)
	if sum < point then
		utils.printInfo("check allot point add error", sum, point)
		LActor.addAllotPoint(actor, roleId, point-sum)
	end
	if sum > point then
		LActor.resetAllotPoint(actor, roleId, point)
		utils.printInfo("check allot point reset error", sum, point)
	end
end

-----------------------------------------------------------------------------------------
function s2cAllotPoint(actor, roleId, isSet)
	local point = 0
	local allots = {0,0,0,0}
	point,allots[1],allots[2],allots[3],allots[4] = LActor.getAllotInfo(actor, roleId) --读角色加点数据
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Job, Protocol.sAllotCmd_Point)
	if pack == nil then return end
	LDataPack.writeShort(pack, roleId)
	LDataPack.writeInt(pack, point)
	for i=1, 4 do
		LDataPack.writeInt(pack, allots[i])
	end
	local total = getPointByLevel(actor, roleId)
	LDataPack.writeInt(pack, total) --总点数
	LDataPack.writeByte(pack, isSet and 1 or 0)
	LDataPack.flush(pack)
end

function c2sAllotPoint(actor, packet)
	local roleId = LDataPack.readShort(packet)
	if not utils.checkRoleId(actor, roleId) then return end
	local attrs = {}
	local sum = 0
	for i=1, 4 do
   		local value = LDataPack.readInt(packet)
   		attrs[i] = value
   		sum = value + sum
   	end

   	local point = 0
	local allots = {0,0,0,0}
	point,allots[1],allots[2],allots[3],allots[4] = LActor.getAllotInfo(actor, roleId) --读数据

	if point < sum then --分配点不足
		utils.printInfo("point < sum", point, sum)
		return
	end
	for k, v in pairs(attrs) do
		LActor.setAllotPoint(actor, roleId, k-1, v)
	end

	updateAttr(actor, roleId, true)

	utils.logCounter(actor, "allot point", roleId)

	--给前端回包
	s2cAllotPoint(actor, roleId, true)

	actorevent.onEvent(actor, aeAllotPoint)
end

function c2sAllotClean(actor, packet)
	local roleId = LDataPack.readShort(packet)
	local id = LDataPack.readShort(packet)
	local conf = AllotAttrConfig[id]
	if not conf then return end
	local po = 0
	local allots = {0,0,0,0}
	po, allots[1],allots[2],allots[3],allots[4] = LActor.getAllotInfo(actor, roleId)
	local cleanPoint = allots[id]
	if cleanPoint <= 0 then return end --无点可洗

	for k, item in pairs(conf.cleanCost) do
		if ItemConfig[item.id] and LActor.getLevel(actor) < ItemConfig[item.id].level then --洗点物品等级限制
			return
		end
	end

	if not actoritem.checkItems(actor, conf.cleanCost) then
		return
	end
	actoritem.reduceItems(actor, conf.cleanCost, "clean point")

	--重置点数后再把另外三个加上
	local point = getPointByLevel(actor, roleId)
	LActor.resetAllotPoint(actor, roleId, point)
	for k, v in pairs(allots) do
		if k ~= id then
			LActor.setAllotPoint(actor, roleId, k-1, v)
		end
	end

	updateAttr(actor, roleId, true)
	utils.logCounter(actor, "clean point", roleId, id)
	s2cAllotPoint(actor, roleId, true)
	LActor.sendTipmsg(actor, string.format(ScriptTips.actor001, cleanPoint), ttScreenCenter)
end

function onLogin(actor)
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		s2cAllotPoint(actor, roleId)
	end
end

function onNewDay(actor, login)
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		checkRolePoint(actor, roleId) --检查点数是否正确，因为转生与升级都会加点，所以不能放在onLevelUp或onZhuansheng里
	end
end

function onLevelUp(actor, level, oldLevel)
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		local role = LActor.getRole(actor,roleId)
		local jobId = LActor.getJob(role)
		if level > 1 and RoleConfig[jobId][level] then
			local point = RoleConfig[jobId][level].point - RoleConfig[jobId][oldLevel].point --两者差值为增加的点数
			LActor.addAllotPoint(actor, roleId, point)
		end

		if level < AllotCommonConfig[1].auto then
			autoAllotPoint(actor, roleId, jobId) --自动加点
		-- elseif level >= AllotCommonConfig[1].level and oldLevel < AllotCommonConfig[1].level then --300级时进行属性点重置
		-- 	LActor.resetAllotPoint(actor, roleId, RoleConfig[jobId][level].point) --属性点重置
		-- 	updateAttr(actor, roleId, false)
		end

		s2cAllotPoint(actor, roleId) --加点数据发送
	end
end

function onZhuansheng(actor, zhuanshengLevel)
	local config = ZhuanshengLevelConfig[zhuanshengLevel]
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		LActor.addAllotPoint(actor, roleId, config.point)
		s2cAllotPoint(actor, roleId)
	end
end

--新角色收获点数
function onOpenRole(actor, roleId)
	local point = getPointByLevel(actor, roleId) --该等级会有多少点
	LActor.resetAllotPoint(actor, roleId, point)
	local level = LActor.getLevel(actor)
	if level < AllotCommonConfig[1].auto then --如果小于300级，自动加点
		local role = LActor.getRole(actor,roleId)
		local jobId = LActor.getJob(role)
		autoAllotPoint(actor, roleId, jobId) 
		LActor.reCalcRoleAttr(actor, roleId)
	end
	utils.printInfo("reset allot point on open role", roleId)
	s2cAllotPoint(actor, roleId) --加点数据发送
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeZhuansheng, onZhuansheng)
actorevent.reg(aeOpenRole, onOpenRole)

netmsgdispatcher.reg(Protocol.CMD_Job, Protocol.cAllotCmd_Point, c2sAllotPoint)
netmsgdispatcher.reg(Protocol.CMD_Job, Protocol.cAllotCmd_Clean, c2sAllotClean)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.allotclean = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeShort(pack, args[1])
	LDataPack.writeShort(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sAllotClean(actor, pack)
end
