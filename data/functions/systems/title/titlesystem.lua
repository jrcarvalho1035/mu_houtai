--称号系统
module("titlesystem", package.seeall)
require("title.title")

local conf = TitleConfig
local function getVar(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return end

	if var.titleData == nil then var.titleData = {} end
	local titleData = var.titleData
	if titleData.titles == nil then titleData.titles = {} end
	if titleData.choose == nil then titleData.choose = 0 end
	
	return titleData
end

--更新属性
local function updateAttr(actor, calc)
	local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Title)
	if attrs == nil then
		print("get title attr error.."..LActor.getActorId(actor))
		return
	end

	attrs:Reset()
	local var = getVar(actor)
	local titles = var.titles
	for k,v in pairs(conf) do
		if titles[k] then
			for _, attr in pairs(v.attrs) do
				attrs:Add(attr.type, attr.value)
			end
		end
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

--称号过期
local function checkTimeOut(actor)
	--print("titlesystem.checkTimeOut")
	if actor == nil then
		print("titlesystem.checkTimeOut actor is nil")
		return
	end
	local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Title)
	if attrs == nil then
		print("get title attr error.."..LActor.getActorId(actor))
		return
	end
	local var = getVar(actor)
	local titles = var.titles

	local recalc = false
	local now_t = System.getNowTime()
	for k,v in pairs(conf) do
		if titles[k] and titles[k].endTime ~= 0 and  now_t >= titles[k].endTime then
			recalc = true
			for _, attr in pairs(v.attrs) do
				attrs:Add(attr.type, -attr.value)
			end
			delitle(actor, k)
		end
	end
	if recalc then
		updateAttr(actor, true)
	end
end

--添加称号
function addTitle(actor, tId, isInit)
	local tConf = conf[tId]
	if tConf == nil then return end

	local var = getVar(actor)
	local titles = var.titles

	local isChange = false
	if tConf.keepTime == 0 then
		if titles[tId] == nil then
			titles[tId] = {}
			titles[tId].endTime = 0
			isChange = true
		end
	else
		if titles[tId] == nil then
			titles[tId] = {}
			titles[tId].endTime = System.getNowTime()
			isChange = true
		end
		titles[tId].endTime = titles[tId].endTime + tConf.keepTime
	end
	if isChange then
		updateAttr(actor, true)
	end
	if isInit then
		local pack = LDataPack.allocPacket(actor, Protocol.CMD_Title, Protocol.sTitleCmd_Add)
		if pack == nil then return end
		LDataPack.writeInt(pack, tId)
		LDataPack.writeInt(pack, titles[tId].endTime)
		LDataPack.flush(pack)
	end

	if isChange then
		autoWear(actor, tId)
	end
end

--删除称号
function delitle(actor, tId, isUpdateAttr, isInit)
	if actor == nil then return end
	local tConf = conf[tId]
	if tConf == nil then return end

	local var = getVar(actor)
	if var.titles[tId] == nil then return end
	
	var.titles[tId] = nil
	if isUpdateAttr and not isInit then
		updateAttr(actor, true)
	end

	if var.choose == tId then
		setTitle(actor, 0)
	end
	if not isInit then
		local pack = LDataPack.allocPacket(actor, Protocol.CMD_Title, Protocol.sTitleCmd_Del)
		if pack == nil then return end
		LDataPack.writeInt(pack, tId)
		LDataPack.flush(pack)
	end
end

--自动穿戴
function autoWear(actor, tId)
	local tConf = conf[tId]
	if tConf == nil then return end

	 local var = getVar(actor)
	if var.titles[tId] == nil then return end

	local tConf2 = conf[var.choose]
	if tConf2 and tConf.priority <= tConf2.priority then return end	

	setTitle(actor, tId)
end

--获取称号信息
function getTitlesInfo(actor, pack)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Title, Protocol.sTitleCmd_Info)
	if npack == nil then return end
	local count = 0
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeInt(npack, count)    --临时个数

	local var = getVar(actor)
	local titles = var.titles
	for k,v in pairs(conf) do
		if titles[k] then
			LDataPack.writeInt(npack, k)
			LDataPack.writeInt(npack, titles[k].endTime or 0)
			count = count + 1
		end
	end

	local newpos = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeInt(npack, count)
	LDataPack.setPosition(npack, newpos)

	LDataPack.writeInt(npack, var.choose)

	LDataPack.flush(npack)
end

--设置称号
function setTitle(actor, titleId)
	if titleId == 0 then
		local var = getVar(actor)
		var.choose = titleId

		updateRoleTitle(actor, titleId)
		actorevent.onEvent(actor, aeNotifyFacade, 0)
		return 
	end

	if conf[titleId] == nil then return end

	local var = getVar(actor)
	local titles = var.titles

	if not titles[titleId] then return end
	var.choose = titleId

	updateRoleTitle(actor, titleId)
	actorevent.onEvent(actor, aeNotifyFacade, 0)
end

--设置临时称号
--以防万一,登录会清除临时称号
function setTempTitle(actor, titleId)
	local var = getVar(actor)
	var.tempChoose = titleId
	actorevent.onEvent(actor, aeNotifyFacade, 0)
end

--清除临时称号
function clearTempTitle(actor)
	setTempTitle(actor)
end

--设置角色的称号
function setRoleTitle(actor, pack)
	local titleId = LDataPack.readInt(pack)
	setTitle(actor, titleId)
end

--获取角色称号
function getRoleTitle(actor)
	local var = getVar(actor)
	return var.tempChoose or var.choose
end

--更新角色称号
function updateRoleTitle(actor, titleId)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Title, Protocol.sTitleCmd_Update)
	if pack == nil then return end
	LDataPack.writeInt(pack, titleId)
	LDataPack.flush(pack)
end

_G.getRoleTitle  = getRoleTitle

function ehInit( actor )
	updateAttr(actor, false)
end

function ehLogin(actor)
	clearTempTitle(actor)
	getTitlesInfo(actor, nil)
	LActor.postScriptEventEx(actor, 0,  function (actor) checkTimeOut(actor) end,
		60 * 1000,
		-1,
		actor
	)
end

local function ehMainTaskAccept(actor, taskid)
	local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Title)
	for k,v in pairs(conf) do
		if v.taskid == taskid then
			delitle(actor, k, true)
		end
	end
end

actorevent.reg(aeInit, ehInit)
actorevent.reg(aeUserLogin, ehLogin)
actorevent.reg(aeMainTaskAccept, ehMainTaskAccept) --主线任务接受

netmsgdispatcher.reg(Protocol.CMD_Title, Protocol.cTitleCmd_Info, getTitlesInfo)
netmsgdispatcher.reg(Protocol.CMD_Title, Protocol.cTitleCmd_SetTitle, setRoleTitle)

--GM
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.addtitle = function (actor, arg)
	local titleId = tonumber(arg[1])
	if titleId == nil then return end
	addTitle(actor, titleId)
	return true
end

gmCmdHandlers.ptitle = function (actor, arg)
	local var = getVar(actor)
	local titles = var.titles
	for i = 1, #TitleConfig do
		if titles[i] then
			print(i .. " titles[i].endTime:" .. titles[i].endTime)
		end
	end
	return true
end

