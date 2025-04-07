-- @version	1.0
-- @author	qianmeng
-- @date	2017-1-5 17:02:59.
-- @system	zhuanshengsystem

module( "zhuanshengsystem", package.seeall )

require("zhuansheng.zhuanshenglevel")
require("zhuansheng.dashilevelconfig")

function onLogin(actor)
	s2cDashiStarInfo(actor)
end

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var.zhuanshengData then var.zhuanshengData = {} end
	local zhuanshengData = var.zhuanshengData
	if not zhuanshengData.star then zhuanshengData.star = 0 end
	if not zhuanshengData.upCount then zhuanshengData.upCount = 0 end
	return zhuanshengData
end

local function zhuanshengName(zs)
	if zs > 9 then
		return tostring(zs-9)
	elseif zs > 4 then
		return ZhuanshengLevelConfig[zs].name
	end
	return tostring(zs)
end

function getZhuanSheng(level)
	for k,v in ipairs(ZhuanshengLevelConfig) do
		if level <= v.level then
			if k-1 > 0 then
				return level - ZhuanshengLevelConfig[k-1].level, ZhuanshengLevelConfig[k-1].name
			else
				return level, ""
			end
		end
	end
end

----------------------------------------------------------------------------------------------
--转生
function c2sZhuanShengUp(actor, packet)
	local actordata = LActor.getActorData(actor)
	if actordata == nil then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhuansheng) then return end
	local config = ZhuanshengLevelConfig[actordata.zhuansheng_lv + 1]
	if config == nil then return end
	if actordata.level < config.level then
		utils.printInfo("zhuan fail level", actordata.level, config.level)
		return
	end

	local var = getActorVar(actor)
	if var.star < config.star then --星级不足
		print("zhuan fail star")
		return 
	end

	if not actoritem.checkItems(actor, config.items) then --物品不足
		print("zhuan fail item")
		return 
	end

	if config.power > 0 and LActor.getActorData(actor).total_power < config.power then --战力不足
		return
	end
	if config.enhance > 0 and enhancesystem.roleAllEnhanceLevel(actor) < config.enhance then --全身强化不足
		return
	end
	if config.wing > 0 and wingsystem.roleWingLevel(actor) < config.wing then --角色翅膀等阶不足
		return
	end
	if config.achieve > 0 and achieve.getTotalPoint(actor) < config.achieve then --成就点不足
		return
	end

	actoritem.reduceItems(actor, config.items, "zhuansheng up")
	actordata.zhuansheng_lv = actordata.zhuansheng_lv + 1
	var.star = 0
	var.upCount = 0

	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		" ", tostring(config.level), tostring(actordata.zhuansheng_lv), "", "upgrade zs level", "", "")
	--给前端回包
	actorevent.onEvent(actor, aeZhuansheng, actordata.zhuansheng_lv) --客户端要求等级变化在前
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Job, Protocol.sZhuanShengCmd_Up)
	if pack == nil then return end
	LDataPack.writeInt(pack, actordata.zhuansheng_lv)
	LDataPack.flush(pack)

	s2cDashiStarInfo(actor)
	noticesystem.broadCastNotice(config.notice, actordata.actor_name, zhuanshengName(actordata.zhuansheng_lv))
end

--大师升星
function c2sDashiUpStar(actor, packet)
	local tp = LDataPack.readInt(packet)
	local zsLevel = LActor.getZhuanShengLevel(actor)
	local var = getActorVar(actor)
	local conf = DashiLevelConfig[zsLevel+1] and DashiLevelConfig[zsLevel+1][var.star+1]
	if not conf then return end

	if tp == 1 then --消耗经验
		local exp = LActor.getExp(actor)
		if exp < conf.upConsuExp then 
			return 
		end
		exp = exp - conf.upConsuExp
		LActor.setExp(actor, exp)
		local level = LActor.getLevel(actor)
		actorexp.confirmExp(actor, level, exp, -conf.upConsuExp)
	else			--消耗钻石
		if not actoritem.checkItem(actor, NumericType_YuanBao, conf.upConsuYb) then
			return
		end
		actoritem.reduceItem(actor, NumericType_YuanBao, conf.upConsuYb, "dashi up star")
	end
	local suc = true --是否成功
	if var.upCount < conf.sucessCount then --在特定次数内，升星是有概率成功的
		suc = math.random(1, 10000) <= conf.pro 
	end
	var.upCount = var.upCount + 1
	if suc then
		var.star = var.star + 1
		var.upCount = 0
	end

	--回包
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Job, Protocol.sDaShiCmd_Upstar)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.star)
	LDataPack.writeInt(pack, var.upCount)
	LDataPack.writeByte(pack, suc and 1 or 0)
	LDataPack.flush(pack)
end

--大师星级信息
function s2cDashiStarInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Job, Protocol.sDaShiCmd_Star)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.star)
	LDataPack.writeInt(pack, var.upCount)
	LDataPack.flush(pack)
end

netmsgdispatcher.reg(Protocol.CMD_Job, Protocol.cZhuanShengCmd_Up, c2sZhuanShengUp)
netmsgdispatcher.reg(Protocol.CMD_Job, Protocol.cDaShiCmd_Upstar, c2sDashiUpStar)
actorevent.reg(aeUserLogin, onLogin)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.setdashistar = function (actor, args)
	local star = tonumber(args[1])
	local var = getActorVar(actor)
	var.star = star
	s2cDashiStarInfo(actor)
	return true
end

gmCmdHandlers.zhuansheng = function (actor, args)
	c2sZhuanShengUp(actor)
	return true
end
