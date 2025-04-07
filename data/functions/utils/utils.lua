module("utils", package.seeall)
setfenv(1, utils)

function table_clone( table_obj )
	if table_obj == nil then return {} end
	if type(table_obj) ~= "table" then return {} end
	local table_clone = {}
	for key, element in pairs(table_obj) do
		if type(element) == "table" then
			table_clone[ key ] = utils.table_clone( element )
		else
			table_clone[ key ] = element
		end
	end
	return table_clone
end

--按顺序拷贝数组
function table_arr_clone( table_obj )
	if table_obj == nil then return {} end
	if type(table_obj) ~= "table" then return {} end
	local table_clone = {}
	for key, element in ipairs(table_obj) do
		if type(element) == "table" then
			table_clone[ key ] = utils.table_arr_clone( element )
		else
			table_clone[ key ] = element
		end
	end
	return table_clone
end

--table转字符串(只取标准写法，以防止因系统的遍历次序导致ID乱序)
function t2s(t, blank)
	if t == nil then return "nil" end
	local ret = "{\n"
	local b = (blank or 0) + 1
	local function tabs(n)
		local s = ""
		for i=1,n do
			s = s..'\t'
		end
		return s
	end

	for k, v in pairs(t) do
		if type(k) == "string" then
			ret = ret .. tabs(b) .. k .. "="
		else
			ret = ret ..tabs(b) .."[" .. k .. "] = "
		end

		if type(v) == "table" then
			ret = ret ..t2s(v, b) .. ",\n"
		elseif type(v) == "string" then
			ret = ret ..'"' ..v .. '",\n'
		else
			ret = ret .. tostring(v) ..",\n"
		end
	end

	ret = ret .. tabs(b-1).. "}"
	return ret
end

--保存数据用转换方式
function serialize(obj)
	return System.table2string(obj)
end

function unserialize(lua)
	local t = type(lua)
	if t == "nil" or lua == "" then
		return nil, "args is nil"
	elseif t == "number" or t == "string" or t == "boolean" then
		lua = tostring(lua)
	else
		print("can not unserialize a " .. t .. " type.")
		return nil, "type error"
	end
	lua = "return " .. lua
	local func = loadstring(lua)
	if func == nil then
		return nil, "loadstring return nil"
	end
	return func(), nil
end



--
--

min_sec   = 60
hours_sec = min_sec * 60
day_sec   = hours_sec * 24
week_sec  = 7 * day_sec


function getDay(t)
	return math.floor((t + System.getTimeZone()) /  day_sec)
end

function getWeeks(t)
	return math.floor((getDay(t) + 3) / 7)
end
function getDaySec(t)
	return math.floor((t + System.getTimeZone()) % day_sec) + 1
end



function getHours(t) --得到今天是整点
	return math.floor(getDaySec(t) / hours_sec)
end

function getMin(t) --得到这是每几分钟
	return math.floor((getDaySec(t) % hours_sec) / min_sec)
end

function getWeek(t)
	return math.floor((getDay(t) +3) % 7) + 1
end

function getAmSec(t)
	return (getDay(t)  * day_sec) - System.getTimeZone()
end

function getNextTimeByInterval(interval)--获取每X小时,距离下次的时间戳
	local now = System.getNowTime()
    local _, _, _, h, m, s = System.timeDecode(now)
    return now + (interval - (h % interval + 1)) * hours_sec + (59 - m) * min_sec + (60 - s)
end

--打印一个表的详细信息
function printTable(luaTable, indent, tablePag)
	local lookupTable = tablePag or {};
	if luaTable == nil or type(luaTable) ~= "table" then
		return
	end
	if lookupTable[luaTable] then
		print("[table] is already " .. lookupTable[luaTable]);
		return
	end
	lookupTable[luaTable] = indent

	local function printFunc(str)
		print("[table] " .. tostring(str))
	end
	indent = indent or 0
	for k, v in pairs(luaTable) do
		if type(k) == "string" then
			k = string.format("%q", k)
		end
		local szSuffix = ""
		if type(v) == "table" then
			szSuffix = "{"
		end
		local szPrefix = string.rep("    ", indent)
		local formatting = szPrefix.."["..k.."]".." = "..szSuffix
		if type(v) == "table" then
			printFunc(formatting)
			printTable(v, indent + 1, lookupTable)
			printFunc(szPrefix.."},")
		else
			local szValue = ""
			if type(v) == "string" then
				szValue = string.format("%q", v)
			else
				szValue = tostring(v)
			end
			printFunc(formatting..szValue..",")
		end
	end
end

--打印输入
function printInfo(fmt, ...)
	local str = ""
	if fmt then
		for i=1, select("#", ...) do
			local arg = select(i, ...);
			str = str.."  "..tostring(arg)
		end
		print(fmt.."  "..str)
	end;
end

--根据副本ID求场景进入坐标
function getSceneEnterCoor(fbId)
	if not FubenConfig[fbId] then return end
	local k, sceneId = next(FubenConfig[fbId].scenes)
	local conf = ScenesConfig[sceneId]
	if not conf then return end
	if next(conf.enters) then
		local pos = getRandomValByTab(conf.enters)
		return pos[1], pos[2]
	end
	return conf.enterX, conf.enterY
end

function getSceneEnterByIndex(fbId, index)
	if not FubenConfig[fbId] then return end
	local k, sceneId = next(FubenConfig[fbId].scenes)
	local conf = ScenesConfig[sceneId]
	if not conf then return end
	return conf.enters[index][1], conf.enters[index][2]
end

--随机取得表中一个元素
function getRandomValByTab(tab)
	local count = 0
	for k,v in pairs(tab) do
		count = count + 1
	end
	local rank = math.random(1,count)
	local i = 1
	for k,v in pairs(tab) do
		if rank == i then
			return v,k
		end
		i = i + 1
	end
	return false
end

--不重复随机数算法(sNum, eNum随机数范围,indexNum=随机数个数)
function getRandomIndexs(sNum, eNum, indexNum, bat)
	if indexNum > (eNum - sNum + 1) then return end
	local map = {}
	local rets = {}
	while true do
		local tmp = math.random(sNum, eNum)
		local ret = tmp
		while map[ret] do --如果随机数重复，以待机数赋值
			ret = map[ret]
		end

		map[tmp] = eNum --把使用过的随机数记录，挖下最大值为待机数
		eNum = eNum - 1
		if ret ~= bat then --这个值被禁止加入
			table.insert(rets, ret)
		end
		if #rets >= indexNum or eNum < sNum then
			break
		end
	end
	return rets
end

--判断某元素是否在表中
function checkTableValue(tab, value)
	for k, v in pairs(tab) do
		if v == value then
			return true
		end
	end
	return false
end

--计算表内元素数量
function getTableCount(tab)
	local count = 0
	for k, v in pairs(tab) do
		count = count + 1
	end
	return count
end

--判断是否boss
function isBoss(monsterId)
	return MonstersConfig[monsterId].type == 1
end

--进入副本检测
function checkFuben(actor, fubenId)
	local conf = FubenConfig[fubenId]
	if not conf then
		LActor.sendTipmsg(actor, ScriptTips.fuben01..fubenId, ttTipmsgWindow)
		return false
	end
	-- if conf.condition.level and conf.condition.level > LActor.getLevel(actor) then
	-- 	LActor.sendTipmsg(actor, ScriptTips.fuben02..conf.condition.level, ttTipmsgWindow)
	-- 	return false
	-- end
	-- local actorid = LActor.getActorId(actor)
	-- if conf.condition.power and conf.condition.power > LActor.getActorPower(actorid) then
	-- 	LActor.sendTipmsg(actor, ScriptTips.fuben03..conf.condition.power, ttTipmsgWindow)
	-- 	return false
	-- end
	return true
end

--返回最适合自己等级的id
function matchingLevel(actor, tab)
	local level = LActor.getLevel(actor)
	local id = 0
	for k, v in pairs(tab) do
		if level >= k and id < k then
			id = k
		end
	end
	return id
end

function getAttrPower(attr)
	local power = 0
	for k, v in pairs(attr) do
		power = power + AttrPowerConfig[v.type].power * v.value
		if v.type == Attribute.atAtk then --攻击力附加属性，要特殊结算战力
			power = power + (AttrPowerConfig[Attribute.atAtkMin].power + AttrPowerConfig[Attribute.atAtkMax].power) * v.value
		end
	end
	return math.floor(power/100)
end

function getAttrPower0(attr0)
	local power = 0
	for k, v in pairs(attr0) do
		power = power + AttrPowerConfig[k].power * v
		if k == Attribute.atAtk then --攻击力附加属性，要特殊结算战力
			power = power + (AttrPowerConfig[Attribute.atAtkMin].power + AttrPowerConfig[Attribute.atAtkMax].power) * v
		end
	end
	return math.floor(power/100)
end

--包含幻兽属性的用这个
function getAttrPower1(attr1)
	local power = 0
	for k, v in pairs(attr1) do
		power = power + AttrPowerConfig[k].power * v
		if k == Attribute.atAtk then
			power = power + (AttrPowerConfig[Attribute.atAtkMin].power + AttrPowerConfig[Attribute.atAtkMax].power) * v
		elseif k == Attribute.atHSHpMax then
			power = power + AttrPowerConfig[Attribute.atHpMax].power * v
		elseif k == Attribute.atHSAtk then
			power = power + (AttrPowerConfig[Attribute.atAtkMin].power + AttrPowerConfig[Attribute.atAtkMax].power) * v
		elseif k == Attribute.atHSDef then
			power = power + AttrPowerConfig[Attribute.atDef].power * v
		elseif k == Attribute.atHSAtkSuc then
			power = power + AttrPowerConfig[Attribute.atAtkSuc].power * v
		elseif k == Attribute.atHSDefSuc then
			power = power + AttrPowerConfig[Attribute.atDefSuc].power * v
		elseif k == Attribute.atHSZMYJ then
			power = power + AttrPowerConfig[Attribute.atZMYJ].power * v
		elseif k == Attribute.atHSResZMYJ then
			power = power + AttrPowerConfig[Attribute.atResZMYJ].power * v
		elseif k == Attribute.atHSIgnoreDef then
			power = power + AttrPowerConfig[Attribute.atIgnoreDef].power * v
		end
	end
	return math.floor(power/100)
end

--记录日志
--counter系统固定值
--value单值记录
--extra多值记录
--kingdom系统区分
--phylum无效
--classfield系统内操作类型
function logCounter(actor, counter, value, extra, kingdom, classfield)
	if not value then value = "" end
	if not extra then extra = "" end
	if not kingdom then kingdom = "" end
	if not classfield then classfield = "" end
	local phylum = ""
	System.logCounter(LActor.getActorId(actor),
		LActor.getAccountName(actor),
		tostring(LActor.getLevel(actor)),
		counter,
		tostring(value),
		tostring(extra),
		tostring(kingdom),
		tostring(phylum),
		tostring(classfield))
end

function logEnconomy(actor, currency, amount, value, kingdom, phylum, extra2)
	local classfield = ""
	local family = ""
	local genus = ""
	local extra = tostring(LActor.getLevel(actor))
	local pf = LActor.getPf(actor)
	local flag = lfNormal
	local ispay = false
	local openkey = ""
	local pfkey = ""
	local pfid = LActor.getPfId(actor)
	local appid = LActor.getAppId(actor)
	System.logEnconomy(LActor.getActorId(actor),
		LActor.getAccountName(actor),
		tostring(currency),
		tostring(amount),
		tostring(value),
		tostring(kingdom),
		tostring(phylum),
		classfield, family, genus,
		extra,
		tostring(extra2),
		pf,
		flag,
		ispay,
		openkey,
		pfkey,
		pfid,
		appid)
end

--对物品的排序要求，要求货币在前，装备在前，品质高的在前，相同id的排一起
local function sortFunc(a, b)
	if a.type == b.type then
		if a.itemType == b.itemType then
			if a.quality == b.quality then
				return a.id > b.id
			else
				return a.quality > b.quality
			end
		else
			return a.itemType < b.itemType
		end
	else
		return a.type < b.type
	end
end

--把物品排序
function sortItem(items)
	local ret = {}
	for k, v in pairs(items) do
		local itemType = ItemConfig[v.id] and ItemConfig[v.id].type or 0
		local quality = ItemConfig[v.id] and ItemConfig[v.id].quality or 0
		table.insert(ret, {id=v.id, count=v.count, type=v.type, itemType=itemType, quality=quality})
	end
	table.sort(ret, sortFunc)
	return ret
end

function mergeItem(items)--将物品中相同的道具数量叠加到一起
	local items0 = {}
	for _, item in ipairs(items) do
		if not items0[item.id] then
			items0[item.id] = {}
			items0[item.id].id = item.id
			items0[item.id].type = item.type
			items0[item.id].count = item.count
		else
			items0[item.id].count = items0[item.id].count + item.count
		end
	end
	local items1 = {}
	for k,v in pairs(items0) do
		table.insert(items1,v)
	end
	return items1
end

--缓存化函数，缓存此函数相同参数所获得的数值，不适用于读取动态数据
function memoize(f)
    local mem = {} -- 缓存化表
    setmetatable(mem, {__mode = "kv"}) -- 设为弱表
    return function (x) -- ‘f’缓存化后的新版本
        local r = mem[x]
        if r == nil then --没有之前记录的结果？
            r = f(x) --调用原函数
            mem[x] = r --储存结果以备重用
        end
        return r
    end
end

function getMonsterName(id)
	if MonstersConfig[id] then
		return tostring(MonstersConfig[id].name)
	end
	return "nil"
end

function getItemName(id)
	if ItemConfig[id] and ItemConfig[id].name[1] then
		return tostring(ItemConfig[id].name[1])
	elseif CurrencyConfig[id] and CurrencyConfig[id].name[1] then
		return tostring(CurrencyConfig[id].name[1])
	end
	return "nil"
end

function getEquipSlotName(slot)
	return EquipIndexConfig[slot + 1].name
end

function showTip(actor, context)
	LActor.sendTipmsg(actor, context, ttScreenCenter)
end

-- 格式化短时间值为时间字符串表示
function formatTime(tm)
	local year, month, day, hour, minute, sec = System.timeDecode(tm)
	return string.format("%d-%d-%d %d:%d:%d", year, month, day, hour, minute, sec)
end

-- string trim
function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function roundTable(list, number)
  local temp = 0
  for i = 1, #list do
    temp = temp + list[i]
    if number <= temp then
      return i
    end
  end

  return 1
end

-- Input: {1000, 2000, ...}
function getRound10000(list)
  local num = System.getRandomNumber(10000) + 1
  return roundTable(list, num)
end
