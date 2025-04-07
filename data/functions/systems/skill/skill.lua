-- @version	1.0
-- @author	qianmeng
-- @date	2017-2-16 22:45:00
-- @system	skill

module("skill", package.seeall)
require("skill.skillopen")


function getMaxSkillCount(actor)
	local count = LActor.getRoleCount(actor)
	local sum = 0
	for roleId=0, count-1 do
		for index = 1, SkillsLen_Max do
			local level = LActor.getRoleSkillLevel(actor, roleId, index-1)
			if level > 0 then
				sum = sum + 1
			end
		end
	end
	return sum
end

function addSkillAttr(actor, roleId, calc)
	local role = LActor.getRole(actor, roleId)
	local jobId = LActor.getJob(role)
	local power = 0
	for index=1, 6 do
		local level = LActor.getRoleSkillLevel(actor, roleId, index-1)
		if level > 0 then
			local skillId = jobId*100 + index
			if SkillsConfig[skillId] and SkillsConfig[skillId][level] then
				power = power + SkillsConfig[skillId][level].score
			end
		end
	end
	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Skill)
	attr:Reset()
	attr:SetExtraPower(power)
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end
end

local function learnSkill(actor, roleId, index)
	-- 最多6个技能
	if index < 1 or index > 5 then return end
	local level = LActor.getRoleSkillLevel(actor, roleId, index-1) --技能等级，已学会为1
	if level > 0 then
		return
	end
	local actorLevel = LActor.getLevel(actor)

	if not SkillsOpenConfig[index] or SkillsOpenConfig[index].level > actorLevel then
		return
	end
	local role = LActor.getRole(actor, roleId)
	local jobId = LActor.getJob(role)

	local skillId = jobId*100 + index

	local conf = SkillsConfig[skillId][level]
	if not conf then return end
	if not actoritem.checkItems(actor, conf.cost) then
		return 
	end

	actoritem.reduceItems(actor, conf.cost, "skill learn") --客户端要求先发技能回包再发物品消耗
	LActor.learnSkill(actor, roleId, index-1)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_UpdateSkill)
	LDataPack.writeShort(npack, roleId)
	LDataPack.writeShort(npack, index)
	LDataPack.writeShort(npack, LActor.getRoleSkillLevel(actor, roleId, index-1))
	LDataPack.flush(npack)

	--LActor.setRoleSkillSkin(actor, roleId, index-1, level + 1)
	sendSkillSkin(actor, roleId, index, level + 1)

	addSkillAttr(actor, roleId, true)
	
	actorevent.onEvent(actor, aeSkillLevelup, roleId, index, skillId, level)
end

---------------------------------------------------------------------------------------------------
--学习技能
function c2sSkillLearn(actor, pack)
	local roleId = LDataPack.readShort(pack)
	local idx = LDataPack.readShort(pack)
	if not utils.checkRoleId(actor, roleId) then return end
	learnSkill(actor, roleId, idx) 
	utils.logCounter(actor, "skill learn", roleId, idx)
end
--技能进阶
function c2sUpgradeSkill(actor, pack)
	local roleId = LDataPack.readShort(pack)
	local index = LDataPack.readShort(pack)
	if not utils.checkRoleId(actor, roleId) then return end
	if index < 1 or index > 5 then return end
	local level = LActor.getRoleSkillLevel(actor, roleId, index-1)
	if level <= 0 then --如果是0级则学习技能
		learnSkill(actor, roleId, index)
		return
	end
	if not zhuanzhisystem.canUpgradeSkill(actor, roleId, index, level) then
		return 
	end
	local role = LActor.getRole(actor, roleId)
	local jobId = LActor.getJob(role)
	local skillId = jobId*100 + index
	local conf = SkillsConfig[skillId][level]
	if not conf or not SkillsConfig[skillId][level+1] then return end	
	if not actoritem.checkItems(actor, conf.cost) then
		return 
	end
	actoritem.reduceItems(actor, conf.cost, "skill upgrade")

	LActor.learnSkill(actor, roleId, index-1)

	-- LActor.setRoleSkillSkin(actor, roleId, index-1, level + 1)
	sendSkillSkin(actor, roleId, index, level + 1)

	addSkillAttr(actor, roleId, true)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_UpdateSkill)
	LDataPack.writeShort(npack, roleId)
	LDataPack.writeShort(npack, index)	
	LDataPack.writeShort(npack, LActor.getRoleSkillLevel(actor, roleId, index-1))
	LDataPack.flush(npack)	
end

--购买并且学习技能
function c2sBuyAndLern(actor, pack)
	local roleId = LDataPack.readShort(pack)
	local index = LDataPack.readShort(pack)
	local storeid = LDataPack.readShort(pack)
	
	local conf = StoreItemConfig[storeid]
	if not conf then
		return
	end
	if not actoritem.checkItem(actor, conf.itemId, 1) then
		if not actoritem.checkItem(actor, NumericType_YuanBao, conf.price) then
			return
		end
		actoritem.reduceItem(actor, NumericType_YuanBao, conf.price, "buy skill and learn")
		actoritem.addItem(actor, conf.itemId, 1, "buy skill and learn")
	end
	learnSkill(actor, roleId, index)
end

function c2sChangeSkin(actor, pack)
	local roleId = LDataPack.readChar(pack)
	local index = LDataPack.readChar(pack)
	local skinIndex = LDataPack.readChar(pack)

	local level = LActor.getRoleSkillLevel(actor, roleId, index-1)
	if level <= 0 then return end
	
	if level < skinIndex then return end

	LActor.setRoleSkillSkin(actor, roleId, index-1, skinIndex)
	sendSkillSkin(actor, roleId, index, skinIndex)
end

function sendSkillSkin(actor, roleId, index, skinIndex)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_ChangeSkin)
	LDataPack.writeChar(npack, roleId)
	LDataPack.writeChar(npack, index)	
	LDataPack.writeChar(npack, skinIndex)
	LDataPack.flush(npack)
end

function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		addSkillAttr(actor, roleId, false)
	end
end


-- function onLogin(actor)
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_ChangeSkinInfo)
--     if pack == nil then return end
-- 	local count = LActor.getRoleCount(actor)
-- 	LDataPack.writeChar(pack, count)
-- 	for roleId = 0, count-1 do
-- 		LDataPack.writeChar(pack, roleId)
-- 		LDataPack.writeChar(pack, SkillsLen_Max)
-- 		for i=1, SkillsLen_Max do
-- 			LDataPack.writeChar(pack, LActor.getRoleSkillSkin(actor, roleId, index-1))
-- 		end
-- 	end
-- 	LDataPack.flush(pack)
-- end

actorevent.reg(aeInit, onInit)
--netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_Learn, c2sSkillLearn)
netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_UpgradeSkill, c2sUpgradeSkill)
netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_SkillBuyLearn, c2sBuyAndLern)
netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_ChangeSkin, c2sChangeSkin)

--local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.learnSkill = function (actor, args)
	learnSkill(actor, 0, tonumber(args[1]))
	return true
end
