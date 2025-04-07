--数据管理还是在instance，只是把刷怪的接口提取封装了起来

module("refreshmonsterapi", package.seeall)

--刷怪类型
MonRefreshTypes = {
	tp1 = 1, --挂机刷怪，刷完一波再刷另一波，大于三波则可以挑战boss
	tp2 = 2, --把怪按顺序刷完
	tp3 = 3, --循环刷怪
	tp4 = 4, --血色刷怪
	tp5 = 5, --一波多怪
	tp6 = 6, --圣魂神殿刷怪
	tp7 = 7, --配置里的所有怪都刷新出来
}
MonRefreshTypes2 = {
	tp1 = 1, --定时刷一波怪
	tp2 = 2, --杀光一波马上刷一波
}


function init(ins, refresh)
	if FubenGroupAlias[ins.config.group] and FubenGroupAlias[ins.config.group].isAutoRefresh == 0 and not refresh then
		return 
	end
	--刷默认怪(针对 杀光一波马上刷一波 类型)
	local rmConfig = RefreshMonsters[ins.config.refreshMonster]
	if rmConfig and (rmConfig.type2 == 2 or rmConfig.type2 == 3) then
		if rmConfig.type == MonRefreshTypes.tp1 then
			refreshMonsters1(ins)
		elseif rmConfig.type == MonRefreshTypes.tp2 then
			refreshMonsters2(ins)
		elseif rmConfig.type == MonRefreshTypes.tp3 then
			refreshMonsters3(ins)
		elseif rmConfig.type == MonRefreshTypes.tp5 then
			refreshMonsters5(ins)
		elseif rmConfig.type == MonRefreshTypes.tp6 then
			refreshMonsters6(ins)
		elseif rmConfig.type == MonRefreshTypes.tp7 then
			refreshMonsters7(ins)
		end
	end
end

function runOne(ins, now_t)
	--刷怪处理
	if ins.is_end then return end 	
	local rmConfig = RefreshMonsters[ins.config.refreshMonster]	
	if not rmConfig or (rmConfig.type2 ~= 1 and rmConfig.type2 ~= 3) then return end
	if rmConfig.type == MonRefreshTypes.tp1 then
		-- if not ins.next_refresh_time[rmConfig.type] or ins.next_refresh_time[rmConfig.type] <= now_t then
		-- 	ins.next_refresh_time[rmConfig.type] = now_t + RefreshMonsters[ins.config.refreshMonster].refreshTime
		-- 	refreshMonsters1(ins)
		-- end
	elseif rmConfig.type == MonRefreshTypes.tp2 then
		if not ins.next_refresh_time[rmConfig.type] or ins.next_refresh_time[rmConfig.type] <= now_t then
			ins.next_refresh_time[rmConfig.type] = now_t + RefreshMonsters[ins.config.refreshMonster].refreshTime
			refreshMonsters2(ins)
		end
	elseif rmConfig.type == MonRefreshTypes.tp3 then
		if not ins.next_refresh_time[rmConfig.type] or ins.next_refresh_time[rmConfig.type] <= now_t then
			ins.next_refresh_time[rmConfig.type] = now_t + RefreshMonsters[ins.config.refreshMonster].refreshTime
			refreshMonsters3(ins)
		end
	elseif rmConfig.type == MonRefreshTypes.tp5 then
		if not ins.next_refresh_time[rmConfig.type] or ins.next_refresh_time[rmConfig.type] <= now_t then
			ins.next_refresh_time[rmConfig.type] = now_t + RefreshMonsters[ins.config.refreshMonster].refreshTime
			refreshMonsters5(ins)
		end
	elseif rmConfig.type == MonRefreshTypes.tp6 then
		if ins.next_refresh_time[rmConfig.type] and ins.next_refresh_time[rmConfig.type] <= now_t then
			--ins.next_refresh_time[rmConfig.type] = now_t + RefreshMonsters[ins.config.refreshMonster].refreshCheckTime
			refreshMonsters6(ins)
		end
	end	
end

function monsterAllKilled(ins)
	if ins.is_end then return end
	local rmConfig = RefreshMonsters[ins.config.refreshMonster]
	if not rmConfig or (rmConfig.type2 ~= 2 and rmConfig.type2 ~= 3) then return end
	if rmConfig.type == MonRefreshTypes.tp1 then
		refreshMonsters1(ins)
	elseif rmConfig.type == MonRefreshTypes.tp2 then
		refreshMonsters2(ins)
	elseif rmConfig.type == MonRefreshTypes.tp3 then
		refreshMonsters3(ins)
	elseif rmConfig.type == MonRefreshTypes.tp4 then
		refreshMonsters4(ins)
	elseif rmConfig.type == MonRefreshTypes.tp5 then
		refreshMonsters5(ins)
	end
end


function postponeStart(ins)
	if ins.is_end then return end
	ins.postponeOn = true
	local rmConfig = RefreshMonsters[ins.config.refreshMonster]
	if not rmConfig then return end

	if rmConfig and rmConfig.type == MonRefreshTypes.tp2 then
		refreshMonsters2(ins)
	elseif rmConfig.type == MonRefreshTypes.tp3 then
		refreshMonsters3(ins)
	elseif rmConfig.type == MonRefreshTypes.tp4 then
		refreshMonsters4(ins)
	elseif rmConfig.type == MonRefreshTypes.tp5 then
		refreshMonsters5(ins)
	end
end

function postponeStop(ins)
	if ins.is_end then return end
	ins.postponeOn = false
end


function getRandPos(sceneHandle, x, y, min, max)
	local tempx = x
	local tempy = y
	for i = 1, 5 do
		tempx = x + math.random(min, max)
		tempy = y + math.random(min, max)
		if Fuben.canMove(sceneHandle,tempx,tempy) then
			return tempx, tempy
		end
	end
	return x, y
end
function refreshExtraMonster(ins, fbid, monid, count)
	if not ins.scene_list or not ins.scene_list[1] then return end
	local sceneHandle = ins.scene_list[1]
	local conf = RefreshMonsters[fbid]
	local posIndex = math.random(1, #conf.position); --随机一个刷怪点刷怪
	for i=1, count do
		local maxgrid = math.min(math.floor(count/4), 3)
		local x, y = getRandPos(sceneHandle, conf.position[posIndex].x, conf.position[posIndex].y, -maxgrid, maxgrid)
		ins:insCreateMonster(sceneHandle, monid, x, y)
		ins.monster_cnt = ins.monster_cnt + 1
	end
end

--类型1的刷怪规则，一波一波的刷怪
function refreshMonsters1(ins)
	if ins.config.postpone == 1 and (not ins.postponeOn) then return end
	if not ins.scene_list or not ins.scene_list[1] then return end

	local refreshConf = RefreshMonsters[ins.config.refreshMonster]
	if ins.isFightCustomBoss then return end
	if ins.monster_cnt >= refreshConf.maxCount then --最多刷怪限制
		return
	end
	--ins:onRefreshWave(ins.refresh_monster_idx+1) --触发刷某波怪前的事件
	if ins.config.postpone == 1 and (not ins.postponeOn) then
		return
	end
	ins.refresh_monster_idx = ins.refresh_monster_idx + 1
	if ins.refresh_monster_idx + 1 > #refreshConf.monsters then
		ins.refresh_monster_idx = 1 --回到第一波小怪
	end
	
	if not refreshConf.monsters[ins.refresh_monster_idx] then
		print("refreshMonsters1:no pos or monster!")
		ins.next_refresh_time[refreshConf.type] = System.getNowTime() + 10000
		return
	end
	local sceneHandle = ins.scene_list[1]
	local monsterConf = refreshConf.monsters[ins.refresh_monster_idx]
	local position = refreshConf.position[System.getRandomNumber(#refreshConf.position) + 1]
	local avatarIndex = math.random(0, #MonstersConfig[monsterConf.monsterid].avatar - 1)
	for i = 1, monsterConf.count do  --{level = 10, monsterid = 10001, count = 10,},		
		local pos = position[1] and position[(i-1) % (#position) + 1] or position
		local x, y = pos.x, pos.y
		if i > 1 then
			x, y = getRandPos(sceneHandle, pos.x, pos.y,-1, 1)
		end
		ins:insCreateMonster(sceneHandle, monsterConf.monsterid, x, y, avatarIndex)
		ins.monster_cnt = ins.monster_cnt + 1
	end
end
	-- if not ins.scene_list or not ins.scene_list[1] then return end

	-- local refreshConf = RefreshMonsters[ins.config.refreshMonster]
	-- local minCount = refreshConf.minCount
	-- local maxCount = refreshConf.maxCount
	-- if ins.monster_cnt >= minCount then return end

	-- local refreshBossPro
	-- for _, bossConf in pairs(refreshConf.bossPro) do
	-- 	if ins.kill_monster_cnt > bossConf[1] then
	-- 		refreshBossPro = bossConf[2]
	-- 	else
	-- 		break
	-- 	end
	-- end
	-- if refreshBossPro and (System.getRandomNumber(10000) + 1) < refreshBossPro then
	-- 	local posIdx = System.getRandomNumber(#refreshConf.position) + 1
	-- 	ins:insCreateMonster(ins.scene_list[1], refreshConf.bossId, refreshConf.position[posIdx].x, refreshConf.position[posIdx].y)
	-- 	ins.kill_monster_cnt = 0
	-- 	return
	-- end

	-- local actor
	-- local actorList = ins:getActorList()
	-- if #actorList <= 0 then
	-- 	--没有玩家在线，就退出，不用检测刷怪了
	-- 	return
	-- else
	-- 	actor = actorList[1]
	-- end

	-- local level = LActor.getLevel(actor)
	-- if level < (refreshConf.monsters[1].level - refreshConf.levelLimit) then return end

	-- local totalGroupCount = #refreshConf.monsters --怪物组配置数量
	-- local refreshGroup = {} --刷新怪物信息
	-- if level > refreshConf.monsters[totalGroupCount].level then
	-- 	for i = 1, refreshConf.groupCount do --刷新多少组
	-- 		refreshGroup[i] = totalGroupCount - refreshConf.groupCount + i
	-- 	end
	-- else
	-- 	local minLevel = level - refreshConf.levelLimit
	-- 	local maxLevel = level + refreshConf.levelLimit
	-- 	for idx, conf in ipairs(refreshConf.monsters) do
	-- 		if conf.level >= minLevel and conf.level <= maxLevel then
	-- 			table.insert(refreshGroup, idx)
	-- 		end
	-- 	end
	-- end
	-- if #refreshGroup < 1 then refreshGroup[1] = totalGroupCount end

	-- local refresGroupIdx = 1
	-- if ins.refresh_monster_idx < refreshGroup[1] then
	-- 	ins.refresh_monster_idx = refreshGroup[1]
	-- 	ins.refresh_monster_count = 0
	-- 	refresGroupIdx = 1
	-- else
	-- 	for idx, value in ipairs(refreshGroup) do
	-- 		if ins.refresh_monster_idx == value then
	-- 			refresGroupIdx = idx
	-- 		end
	-- 	end
	-- end

	-- local nowCount = ins.monster_cnt
	-- local posIdx1 = System.getRandomNumber(#refreshConf.position) + 1
	-- local posIdx2 = System.getRandomNumber(#refreshConf.position) + 1
	-- local posX1 = refreshConf.position[posIdx1].x
	-- local posY1 = refreshConf.position[posIdx1].y

	-- local posX2 = refreshConf.position[posIdx2].x
	-- local posY2 = refreshConf.position[posIdx2].y
	-- local middle = math.floor((maxCount - nowCount) / 2)
	-- for i = nowCount+1, maxCount do
	-- 	if ins.refresh_monster_count < refreshConf.monsters[ins.refresh_monster_idx].count then
	-- 		ins.refresh_monster_count = ins.refresh_monster_count + 1
	-- 	else
	-- 		ins.refresh_monster_count = 0
	-- 		refresGroupIdx = refresGroupIdx % (#refreshGroup) + 1
	-- 		ins.refresh_monster_idx = refreshGroup[refresGroupIdx]
	-- 	end
	
	-- 	local monsterConf = refreshConf.monsters[ins.refresh_monster_idx]
	-- 	local randPos1 = 1 + System.getRandomNumber(3)
	-- 	local randPos2 = 1 + System.getRandomNumber(3)
	-- 	if i <= middle then
	-- 		ins:insCreateMonster(ins.scene_list[1], monsterConf.monsterid, posX1+randPos1, posY1+randPos2)
	-- 	else
	-- 		ins:insCreateMonster(ins.scene_list[1], monsterConf.monsterid, posX2+randPos1, posY2+randPos2)
	-- 	end

	-- 	ins.monster_cnt = ins.monster_cnt + 1
	-- end
--end

--类型2的刷怪规则，按monsters顺序创建在position
function refreshMonsters2(ins)
	if ins.config.postpone == 1 and (not ins.postponeOn) then return end
	if not ins.scene_list or not ins.scene_list[1] then return end

	if ins.refresh_monster_idx == -1 then return end
	local refreshConf = RefreshMonsters[ins.config.refreshMonster]
	if ins.monster_cnt >= refreshConf.maxCount then --最多刷怪限制
		return
	end
	ins:onRefreshWave(ins.refresh_monster_idx+1) --触发刷某波怪前的事件，要在两个postpone之间，以便截停刷怪
	if ins.config.postpone == 1 and (not ins.postponeOn) then
		return
	end
	ins.refresh_monster_idx = ins.refresh_monster_idx + 1
	if ins.refresh_monster_idx == #refreshConf.monsters+1 and refreshConf.bossId > 0 then
		local pos = refreshConf.position[#refreshConf.position]
		ins:insCreateMonster(ins.scene_list[1], refreshConf.bossId, pos.x, pos.y)
		ins.refresh_monster_idx = -1 	-- -1表示最后一个boss都已经刷了
		return
	end
	if not refreshConf.monsters[ins.refresh_monster_idx] or not refreshConf.position[ins.refresh_monster_idx] then
		ins.next_refresh_time[refreshConf.type] = System.getNowTime() + 10000
		return
	end
	local sceneHandle = ins.scene_list[1]
	local monsterConf = refreshConf.monsters[ins.refresh_monster_idx]
	for i = 1, monsterConf.count do  --{level = 10, monsterid = 10001, count = 10,},
		local position = refreshConf.position[ins.refresh_monster_idx]
		local pos = position[1] and position[(i-1) % (#position) + 1] or position
		local x, y = pos.x, pos.y
		if i > 1 then
			x, y = getRandPos(sceneHandle, pos.x, pos.y,-2, 2)
		end
		ins:insCreateMonster(sceneHandle, monsterConf.monsterid, x, y)
		ins.monster_cnt = ins.monster_cnt + 1
	end
end

--类型2的刷怪规则，把配置里的所有boss都刷新出来
function refreshMonsters7(ins)
	if ins.config.postpone == 1 and (not ins.postponeOn) then return end
	if not ins.scene_list or not ins.scene_list[1] then return end
	if ins.refresh_monster_idx == -1 then return end
	local refreshConf = RefreshMonsters[ins.config.refreshMonster]
	if ins.monster_cnt >= refreshConf.maxCount then --最多刷怪限制
		return
	end
	ins:onRefreshWave(ins.refresh_monster_idx+1) --触发刷某波怪前的事件，要在两个postpone之间，以便截停刷怪
	if ins.config.postpone == 1 and (not ins.postponeOn) then
		return
	end

	ins.refresh_monster_idx = ins.refresh_monster_idx + 1
	-- if ins.refresh_monster_idx == #refreshConf.monsters+1 and refreshConf.bossId > 0 then
	-- 	local pos = refreshConf.position[#refreshConf.position]
	-- 	ins:insCreateMonster(ins.scene_list[1], refreshConf.bossId, pos.x, pos.y)
	-- 	ins.refresh_monster_idx = -1 	-- -1表示最后一个boss都已经刷了
	-- 	return
	-- end

	-- if not refreshConf.monsters[ins.refresh_monster_idx] or not refreshConf.position[ins.refresh_monster_idx] then
	-- 	ins.next_refresh_time[refreshConf.type] = System.getNowTime() + 10000
	-- 	return
	-- end
	for refreshcount = 1, #refreshConf.monsters do
		local sceneHandle = ins.scene_list[1]
		local monsterConf = refreshConf.monsters[refreshcount]
		for i = 1, monsterConf.count do  --{level = 10, monsterid = 10001, count = 10,},
			local position = refreshConf.position[refreshcount]
			local pos = position[1] and position[(i-1) % (#position) + 1] or position
			local x, y = pos.x, pos.y
			if i > 1 then
				x, y = getRandPos(sceneHandle, pos.x, pos.y,-2, 2)
			end
			ins:insCreateMonster(sceneHandle, monsterConf.monsterid, x, y)
			ins.monster_cnt = ins.monster_cnt + 1
		end
	end
end

--类型3的刷怪规则，按monsters顺序循环刷
function refreshMonsters3(ins)
	if ins.config.postpone == 1 and (not ins.postponeOn) then return end
	if not ins.scene_list or not ins.scene_list[1] then return end

	local refreshConf = RefreshMonsters[ins.config.refreshMonster]
	if ins.config.group == fort.FORT_GROUP then --赤色要塞
		if not fort.g_fort_open then --普通赤色要塞刷怪
			refreshConf = RefreshMonsters[ins.config.monsterGroup]
		end
	end
	
	if ins.monster_cnt >= refreshConf.maxCount then --最多刷怪限制
		return
	end
	ins:onRefreshWave(ins.refresh_monster_idx+1) --触发刷某波怪前的事件
	if ins.config.postpone == 1 and (not ins.postponeOn) then
		return
	end
	ins.refresh_monster_idx = ins.refresh_monster_idx + 1

	if refreshConf.bossId > 0 then
		if ins.refresh_monster_idx == #refreshConf.monsters+1 then
			local pos = refreshConf.position[#refreshConf.position]
			ins:insCreateMonster(ins.scene_list[1], refreshConf.bossId, pos.x, pos.y)
			ins.refresh_monster_idx = 0 	--重回开头
			return
		end
	else
		if ins.refresh_monster_idx > #refreshConf.monsters then
			ins.refresh_monster_idx = 1 --回到第一波小怪
		end
	end
	
	if not refreshConf.monsters[ins.refresh_monster_idx] or not refreshConf.position[ins.refresh_monster_idx] then
		print("refreshMonsters3:no pos or monster!")
		print("ins.id:" .. ins.id)
		print("ins.config.refreshMonster:" .. ins.config.refreshMonster)
		print("ins.refresh_monster_idx:" .. ins.refresh_monster_idx)
		ins.next_refresh_time[refreshConf.type] = System.getNowTime() + 10000
		return
	end

	local sceneHandle = ins.scene_list[1]
	local monsterConf = refreshConf.monsters[ins.refresh_monster_idx]
	for i = 1, monsterConf.count do  --{level = 10, monsterid = 10001, count = 10,},
		local position = refreshConf.position[ins.refresh_monster_idx]
		local pos = position[1] and position[(i-1) % (#position) + 1] or position
		local x, y = pos.x, pos.y
		if i > 1 then
			x, y = getRandPos(sceneHandle, pos.x, pos.y,-1, 1)
		end
		ins:insCreateMonster(sceneHandle, monsterConf.monsterid, x, y)
		ins.monster_cnt = ins.monster_cnt + 1
	end
end

--类型4，血色刷怪专用
function refreshMonsters4(ins)
	if ins.config.postpone == 1 and (not ins.postponeOn) then return end
	if not ins.scene_list or not ins.scene_list[1] then return end
	local refreshConf = RefreshMonsters[ins.config.refreshMonster]
	if ins.monster_cnt >= refreshConf.maxCount then --最多刷怪限制
		return
	end
	ins:onRefreshWave(ins.refresh_monster_idx+1) --触发刷某波怪前的事件
	if ins.config.postpone == 1 and (not ins.postponeOn) then
		return
	end
	ins.refresh_monster_idx = ins.refresh_monster_idx + 1

	if not refreshConf.monsters[ins.refresh_monster_idx] or not refreshConf.position[ins.refresh_monster_idx] then
		print("refreshMonsters4:no pos or monster!")
		print("ins.id:" .. ins.id)
		print("ins.config.refreshMonster:" .. ins.config.refreshMonster)
		print("ins.refresh_monster_idx:" .. ins.refresh_monster_idx)
		return
	end

	local sceneHandle = ins.scene_list[1]
	local monsterConf = refreshConf.monsters[ins.refresh_monster_idx]
	for i = 1, refreshConf.monsters[ins.refresh_monster_idx].count do  --{level = 10, monsterid = 10001, count = 10,},
		local position = refreshConf.position[ins.refresh_monster_idx]
		local pos = position[1] and position[(i-1) % (#position) + 1] or position
		local x, y = pos.x, pos.y
		if i > 1 then
			x, y = getRandPos(sceneHandle, pos.x, pos.y,-1, 1)
		end
		ins:insCreateMonster(sceneHandle, monsterConf.monsterid, x, y)
		ins.monster_cnt = ins.monster_cnt + 1
	end
end

--类型5，一波刷出多种怪
function refreshMonsters5(ins)
	if ins.config.postpone == 1 and (not ins.postponeOn) then return end
	if not ins.scene_list or not ins.scene_list[1] then return end
	local refreshConf = RefreshMonsters[ins.config.refreshMonster]
	if ins.monster_cnt >= refreshConf.maxCount then --最多刷怪限制
		return
	end
	ins:onRefreshWave(ins.refresh_monster_idx+1) --触发刷某波怪前的事件
	if ins.config.postpone == 1 and (not ins.postponeOn) then
		return
	end
	ins.refresh_monster_idx = ins.refresh_monster_idx + 1
	if ins.refresh_monster_idx > #refreshConf.monsters1 then
		ins.refresh_monster_idx = 1 --回到第一波小怪
	end

	local monsters = refreshConf.monsters1[ins.refresh_monster_idx]
	local position = refreshConf.position[ins.refresh_monster_idx]
	if not monsters or not position then
		return
	end
	local sceneHandle = ins.scene_list[1]
	for k, monsterid in ipairs(monsters) do
		local pos = position[1] and position[(k-1) % (#position) + 1] or position
		ins:insCreateMonster(sceneHandle, monsterid, pos.x, pos.y)
		ins.monster_cnt = ins.monster_cnt + 1
	end
end

--类型6的刷怪规则，死亡立即刷新下一波，到时间也刷新一波,圣魂专用
function refreshMonsters6(ins)
	if ins.config.postpone == 1 and (not ins.postponeOn) then return end
	if not ins.scene_list or not ins.scene_list[1] then return end
	if ins.refresh_monster_idx == -1 then return end
	local refreshConf = RefreshMonsters[ins.config.refreshMonster]
	if ins.monster_cnt >= refreshConf.maxCount then --最多刷怪限制
		return
	end
	ins:onRefreshWave(ins.refresh_monster_idx+1) --触发刷某波怪前的事件，要在两个postpone之间，以便截停刷怪
	if ins.config.postpone == 1 and (not ins.postponeOn) then
		return
	end

	ins.refresh_monster_idx = ins.refresh_monster_idx + 1
	ins.next_refresh_time[refreshConf.type] = System.getNowTime() + refreshConf.refreshCheckTime
	if ins.refresh_monster_idx == #refreshConf.monsters+1 and refreshConf.bossId > 0 then
		local pos = refreshConf.position[#refreshConf.position]
		ins:insCreateMonster(ins.scene_list[1], refreshConf.bossId, pos.x, pos.y)
		ins.refresh_monster_idx = -1 	-- -1表示最后一个boss都已经刷了
		return
	end
	
	if not refreshConf.monsters[ins.refresh_monster_idx] or not refreshConf.position[ins.refresh_monster_idx] then
		--ins.next_refresh_time[refreshConf.type] = System.getNowTime() + 10000
		return
	end

	local sceneHandle = ins.scene_list[1]
	local monsterConf = refreshConf.monsters[ins.refresh_monster_idx]
	for i = 1, monsterConf.count do  --{level = 10, monsterid = 10001, count = 10,},
		local position = refreshConf.position[ins.refresh_monster_idx]
		local pos = position[1] and position[(i-1) % (#position) + 1] or position
		local x, y = pos.x, pos.y
		if i > 1 then
			x, y = getRandPos(sceneHandle, pos.x, pos.y,-2, 2)
		end
		ins:insCreateMonster(sceneHandle, monsterConf.monsterid, x, y)
		ins.monster_cnt = ins.monster_cnt + 1
	end
	shenghun.refreshMonster(ins)
end
