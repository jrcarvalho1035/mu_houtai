-- @version 1.0
-- @author  qianmeng
-- @date    2017-7-17 14:41:48.
-- @system  配置瘦身

module("slim",package.seeall)


function fbMonsterConfig(actor, fubenId)
	local id = FubenConfig[fubenId].refreshMonster
	local conf = RefreshMonsters[id]
	local list = {}
	if conf then
		for k, v in pairs(conf.monsters) do
			table.insert(list, v.monsterid)
		end
		-- for k, v in pairs(conf.monsters1) do
		-- 	for k1, v1 in pairs(v) do
		-- 		table.insert(list, v1)
		-- 	end
		-- end
		if conf.bossId > 0 then
			table.insert(list, conf.bossId)
		end
	end
	s2cMonsterConfig(actor, list)
end

function wanmoFuben(actor, idx, next)
	local list = {}
	if next then
		if ChallengefbConfig[idx] then
			table.insert(list, idx)
		end
	else
		if ChallengefbConfig[idx-1] then
			table.insert(list, idx-1)
		end
		if ChallengefbConfig[idx] then
			table.insert(list, idx)
		else
			table.insert(list, idx - 2)
		end
		if ChallengefbConfig[idx+1] then
			table.insert(list, idx+1)
		end
	end
	s2cWanmoConfig(actor, list)
end

function heianFuben(actor, idx, next)
	local list = {}
	if next then
		if HeianfbConfig[idx] then
			table.insert(list, idx)
		end
	else
		if HeianfbConfig[idx-1] then
			table.insert(list, idx-1)
		end
		if HeianfbConfig[idx] then
			table.insert(list, idx)
		end
		if HeianfbConfig[idx+1] then
			table.insert(list, idx+1)
		end
	end
	s2cHeianConfig(actor, list)
end

-----------------------------------------------------------------------------------------------------------------------
function s2cMonsterConfig(actor, list)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Config, Protocol.sConfig_Monster)
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeShort(pack, count)
	local tmp = {}
	for k, id in pairs(list) do
		local conf = MonstersConfig[id]
		if conf and not tmp[id] then
			tmp[id] = 1
			LDataPack.writeInt(pack, conf.id)
			LDataPack.writeString(pack, conf.name)
			LDataPack.writeDouble(pack, conf.HpMax)
			LDataPack.writeInt(pack, conf.AtkMin)
			LDataPack.writeInt(pack, conf.AtkMax)
			LDataPack.writeInt(pack, conf.Def)
			LDataPack.writeInt(pack, conf.AtkSuc)
			LDataPack.writeInt(pack, conf.DefSuc)
			LDataPack.writeInt(pack, conf.MvSpeed)
			LDataPack.writeInt(pack, conf.AtkSpeed)
			LDataPack.writeChar(pack, #conf.avatar)
			for k,v in ipairs(conf.avatar) do
				LDataPack.writeShort(pack, v)
			end
			LDataPack.writeString(pack, conf.head)
			LDataPack.writeInt(pack, conf.ai)
			LDataPack.writeChar(pack, conf.type)
			LDataPack.writeChar(pack, conf.hpViewType)
			count = count + 1
		end
	end
	if count > 0 then
		local npos = LDataPack.getPosition(pack)
		LDataPack.setPosition(pack, pos)
		LDataPack.writeShort(pack, count)
		LDataPack.setPosition(pack, npos)
	end
	LDataPack.flush(pack)
end

function c2sConfigMonster(actor, packet)
	local count = LDataPack.readShort(packet)
	local list = {}
	for i=1, count do
		local id = LDataPack.readInt(packet)
		table.insert(list, id)
	end
	s2cMonsterConfig(actor, list)
end

function s2cWanmoConfig(actor, list)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Config, Protocol.sConfig_Wanmo)
	LDataPack.writeShort(pack, #list)
	for _, id in pairs(list) do
		local conf = ChallengefbConfig[id]
		LDataPack.writeInt(pack, conf.idx)
		LDataPack.writeShort(pack, #conf.normalAwards)
		for k, v in ipairs(conf.normalAwards) do
			LDataPack.writeInt(pack, v.type)
			LDataPack.writeInt(pack, v.id)
			LDataPack.writeInt(pack, v.count)
		end
		LDataPack.writeShort(pack, #conf.saodangAwards)
		for k, v in ipairs(conf.saodangAwards) do
			LDataPack.writeInt(pack, v.type)
			LDataPack.writeInt(pack, v.id)
			LDataPack.writeInt(pack, v.count)
		end
		LDataPack.writeString(pack, conf.name)
		LDataPack.writeShort(pack, MonstersConfig[conf.monsterid].avatar[math.random(1, #MonstersConfig[conf.monsterid].avatar)])
		LDataPack.writeInt(pack, conf.power)
	end
	LDataPack.flush(pack)
end

function s2cHeianConfig(actor, list)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Config, Protocol.sConfig_Heian)
	LDataPack.writeShort(pack, #list)
	for _, id in pairs(list) do
		local conf = HeianfbConfig[id]
		LDataPack.writeInt(pack, conf.idx)
		LDataPack.writeShort(pack, #conf.normalAwards)
		for k, v in ipairs(conf.normalAwards) do
			LDataPack.writeInt(pack, v.type)
			LDataPack.writeInt(pack, v.id)
			LDataPack.writeInt(pack, v.count)
		end
		LDataPack.writeShort(pack, #conf.saodangAwards)
		for k, v in ipairs(conf.saodangAwards) do
			LDataPack.writeInt(pack, v.type)
			LDataPack.writeInt(pack, v.id)
			LDataPack.writeInt(pack, v.count)
		end
		LDataPack.writeString(pack, conf.name)
		LDataPack.writeShort(pack, MonstersConfig[conf.monsterid].avatar[math.random(1, #MonstersConfig[conf.monsterid].avatar)])
		LDataPack.writeInt(pack, conf.power)
	end
	LDataPack.flush(pack)
end

function s2cRefreshConfig(actor, id)
	local conf = RefreshMonsters[id]
	if not conf then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Config, Protocol.sConfig_Refresh)
	LDataPack.writeInt(pack, conf.idx)
	LDataPack.writeShort(pack, conf.maxCount)
	LDataPack.writeShort(pack, conf.minCount)
	LDataPack.writeShort(pack, conf.refreshTime)
	LDataPack.writeShort(pack, #conf.position)
	for k, v in ipairs(conf.position) do
		LDataPack.writeShort(pack, v.x)
		LDataPack.writeShort(pack, v.y)
	end
	LDataPack.flush(pack)
end

function c2sConfigMonsterUI(actor, packet)
	local count = LDataPack.readShort(packet)
	local list = {}
	for i=1, count do
		local id = LDataPack.readInt(packet)
		table.insert(list, id)
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Config, Protocol.sConfig_MonsterUi)
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeShort(pack, count)
	local tmp = {}
	for k, id in pairs(list) do
		local conf = MonstersConfig[id]
		if conf and not tmp[id] then
			tmp[id] = 1
			LDataPack.writeInt(pack, conf.id)
			LDataPack.writeString(pack, conf.name)
			LDataPack.writeString(pack, conf.head)
			LDataPack.writeChar(pack, #conf.avatar)
			for k,v in ipairs(conf.avatar) do
				LDataPack.writeShort(pack, v)
			end
			LDataPack.writeChar(pack, conf.type)
			count = count + 1
		end
	end
	if count > 0 then
		local npos = LDataPack.getPosition(pack)
		LDataPack.setPosition(pack, pos)
		LDataPack.writeShort(pack, count)
		LDataPack.setPosition(pack, npos)
	end
	LDataPack.flush(pack)
end





netmsgdispatcher.reg(Protocol.CMD_Config, Protocol.cConfig_Monster, c2sConfigMonster)
netmsgdispatcher.reg(Protocol.CMD_Config, Protocol.cConfig_MonsterUi, c2sConfigMonsterUI)
