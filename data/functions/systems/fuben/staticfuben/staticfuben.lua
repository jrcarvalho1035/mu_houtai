module("staticfuben", package.seeall)
--主城和挂机副本的出入信息都在这里处理

local LDataPack = LDataPack
local LActor    = LActor
local System    = System
local FubenConfig = FubenConfig

--默认值
local defaultFubenID = 10001 --首次登陆进入副本ID
local defaultSceneIdx = -1 --首次登陆场景索引

--判断是否主城或者挂机副本
function isStaticFuben(fbid)
	local fbconf = FubenConfig[fbid]
	if fbconf and (fbconf.type == 0 or fbconf.type == 1) then   
		return  true
	end
	return false
end

function canEnterFuben(actor)
    local fbId = LActor.getFubenId(actor)
    if staticfuben.isStaticFuben(fbId) then return true end
    LActor.sendTipmsg(actor, ScriptTips.staticFuben02)
    return false
end

--获取上次主城或者挂机副本的信息
-- local function getLastStaticFubenInfo(actor)
-- 	local asvar = LActor.getStaticVar(actor)
-- 	if not asvar then return end

-- 	if not asvar.lsFubenInfo then asvar.lsFubenInfo = {} end
-- 	local lsFubenInfo = asvar.lsFubenInfo
-- 	if not lsFubenInfo.fbid then lsFubenInfo.fbid = defaultFubenID end
-- 	if not lsFubenInfo.sceneid then lsFubenInfo.sceneid = defaultSceneIdx end
-- 	if not lsFubenInfo.posx then lsFubenInfo.posx = 0 end
-- 	if not lsFubenInfo.posy then lsFubenInfo.posy = 0 end

-- 	return lsFubenInfo
-- end

-- --设置上次主城或者挂机副本的信息
-- function procLastStaticFubenInfo(fbid, actor)
-- 	if not isStaticFuben(fbid) then return end 
--  	local lsFubenInfo = getLastStaticFubenInfo(actor)
--  	lsFubenInfo.fbid = fbid
--  	lsFubenInfo.sceneid = LActor.getSceneId(actor)
--  	lsFubenInfo.posx, lsFubenInfo.posy = LActor.getEntityScenePos(actor)
-- end

local function returnToLastStaticFuben(actor, isBackMain)
	local pFuben = LActor.getFubenPrt(actor)
	if pFuben ~= nil then
		local fbid = LActor.getFubenId(actor)
		--如果原来就是在静态副本中，则不做处理
		if isStaticFuben(fbid) then return end
		if fbid == MineCommonConfig.pkfbId then
			if minesystem.enterMineFuben(actor) then return end
		elseif fbid == 88101 or fbid == 88102 or fbid == 88103 or fbid == CampBattleCommonConfig.fightFbId then
			return enterMainFuben(actor)
		end
	end

	-- local lsFubenInfo = getLastStaticFubenInfo(actor)
	-- local canEnter = true
	-- if lsFubenInfo.fbid == 0 then
	-- 	if not mainscenefuben.enterMainScene(actor, lsFubenInfo.sceneid, lsFubenInfo.posx, lsFubenInfo.posy) then
	-- 		canEnter = false
	-- 	end
	-- else
	-- 	if not guajifuben.enterGuajiFuben(actor) then
	-- 		canEnter = false
	-- 	end
	-- end

	-- if not canEnter then
	--确保玩家必须能进入某个副本
	if System.isBattleSrv() then
		enterMainFuben(actor)
	elseif System.isLianFuSrv() then
		enterLianfuMain(actor)
	else
		guajifuben.enterGuajiFuben(actor)
	end
	--end
end

--这个函数在登录时会触发，但在顶号登录时玩家如果已身在挂机副本，那这函数就不会被触发
function returnToGuajiFuben(actor)
	if not actor then return end

	local fbId = LActor.getFubenId(actor)
	if not FubenConfig[fbId] or FubenConfig[fbId].type == 1 then return end

	--if not guajifuben.enterGuajiFuben(actor) then
		--确保玩家必须能进入某个副本
		guajifuben.enterGuajiFuben(actor)
	--end
end

-- function ehExitFuben(ins, actor)
-- 	procLastStaticFubenInfo(ins.id, actor)
-- end

-- function ehActorLogout(actor)
-- 	local guajiFuben = guajifuben.getActorVar(actor)
-- 	procLastStaticFubenInfo(guajiFuben.fbid,actor)
-- end


--进入主城和挂机副本都是通过这个接口
function ReqEnterFuben(actor, packet)
	if not actor or not packet then return end
	
	local fbid = LDataPack.readInt(packet)
	
	
	--重复进入副本
	--print("ReqEnterFuben fbid:" .. fbid .. " aid:".. LActor.getActorId(actor))
	local canenter = 1
	if fbid == LActor.getFubenId(actor) then
		LActor.sendTipmsg(actor, ScriptTips.staticFuben01)
		canenter = 0
	end

	if not actorlogin.checkCanEnterCross(actor) then
		canenter = 0
	end

	if canenter == 1 then
		if fbid == 0 then
			if not mainscenefuben.reqEnterMainScene(actor) then
				canenter = 0
			end
		elseif fbid == 3 then
			if not lianfumainfuben.reqEnterMainScene(actor) then
				canenter = 0
			end
		else
			LActor.exitFuben(actor)
		end
	end
	
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_EnterSceneReturn)
    LDataPack.writeChar(npack, canenter)
    LDataPack.flush(npack)
end


_G.returnToLastStaticFuben = returnToLastStaticFuben
_G.returnToGuajiFuben = returnToGuajiFuben


--主城
--insevent.registerInstanceOffline(0, onOffline)
--insevent.registerInstanceExit(0, ehExitFuben)
--挂机副本
-- function InitGuajiFubenEvent()
-- 	if System.isBattleSrv() then return end
-- 	for _, conf in pairs(FubenConfig) do
-- 		if conf.type == 1 then
-- 			insevent.registerInstanceExit(conf.fbid, ehExitFuben)
-- 		end
-- 	end
-- end
-- table.insert(InitFnTable, InitGuajiFubenEvent)

--actorevent.reg(aeUserLogout, ehActorLogout)

--网络协议
netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_EnterFuben, ReqEnterFuben)

