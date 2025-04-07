--勇气试炼
module("trial", package.seeall )



local rankingListName      = "trialrank"
local rankingListFile      = "trialrank.rank"
local rankingListMaxSize   = 100
local rankingListBoardSize = 10
local rankingListColumns   = {"name", "touxian"}

--第一次创建排行榜表
local function updateDynamicFirstCache(actor_id)
	local rank = Ranking.getRanking(rankingListName)
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then 
		rankTbl = {} 
	end
	if #rankTbl ~= 0 then 
		local prank = rankTbl[1]
		if actor_id == nil or actor_id == Ranking.getId(prank) then  
			worship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_TRIAL)
		end
	end
end

--初始化排行榜
function initRankingList()
	local rank = utils.rankfunc.InitRank(rankingListName, rankingListFile, rankingListMaxSize, rankingListColumns, true)
	Ranking.addRef(rank)
	updateDynamicFirstCache()
end

--更新排行榜比分数值
function updateRankingList(actor, floor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local actorId = LActor.getActorId(actor)
	local item = Ranking.getItemPtrFromId(rank, actorId)
	if item ~= nil then
		local p = Ranking.getPoint(item)
		if p < floor then
			Ranking.setItem(rank, actorId, floor)
		end
	else
		--只增不降的用tryAddItem
		--会降的用addItem
		item = Ranking.tryAddItem(rank, actorId, floor)
		if item == nil then return end
	end
	--创建榜单
	Ranking.setSub(item, 0, LActor.getName(actor))
    Ranking.setSub(item, 1, touxiansystem.getTouxian(actor))
    updateDynamicFirstCache(LActor.getActorId(actor))
end

function getrank(actor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return 0 end

	return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end

function onReqRanking(actor)
    local rank = Ranking.getRanking(rankingListName)
	if rank == nil then 
		return 
    end
	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResRankingData)
	if npack == nil then 
		return 
	end
	if rankTbl == nil then rankTbl = {} end
	LDataPack.writeShort(npack, RankingType_TRIAL)
	LDataPack.writeShort(npack, #rankTbl)

	if rankTbl and #rankTbl > 0 then
		for i = 1, #rankTbl do
			local prank = rankTbl[i]
			local floor = Ranking.getPoint(prank)
            LDataPack.writeShort(npack, i)
            LDataPack.writeInt(npack, Ranking.getId(prank))
			LDataPack.writeString(npack, Ranking.getSub(prank, 0))            
            LDataPack.writeShort(npack, floor)
            LDataPack.writeShort(npack, Ranking.getSub(prank,1))
		end
    end
	LDataPack.writeShort(npack, Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1)
	LDataPack.flush(npack)
end

_G.onReqTrialRanking = onReqRanking

engineevent.regGameStartEvent(initRankingList)

--------------------------------排行榜end--------------------------------

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.trial then var.trial = {} end
    if not var.trial.floor then var.trial.floor = 0 end

    return var.trial
end

function getTrialFloor(actor)
    local var = getActorVar(actor)
    return var.floor
end

function c2sEnterTrial(actor)
    local var = getActorVar(actor)
    local conf = TrialfbConfig[var.floor + 1]
    if not conf then return end
    if LActor.getLevel(actor) < conf.level then return end
    if not utils.checkFuben(actor, conf.fbid) then return end
    local hfuben = instancesystem.createFuBen(conf.fbid)
	if hfuben == 0 then return end
	local x, y = utils.getSceneEnterCoor(conf.fbid)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
end

function onEnterBefore(ins, actor, islogin)
    if islogin then
        sendInfo(actor)
    end
end

function onEnterFb(ins, actor, islogin)
    sendFbInfo(ins)
    sendRemainTime(ins, actor)
end

function onMonsterDie(ins, mon, killHdl)
    if ins.is_end then return end
    sendFbInfo(ins)
    local actor = ins:getActorList()[1]
    local var = getActorVar(actor)
    local conf = TrialfbConfig[var.floor + 1]
    if conf.needcount <= ins.kill_monster_cnt then
        ins:win()
    end
end

function onActorDie(ins, actor)
    ins:lose()
end

function sendInfo(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_TrialInfo)
    local conf = TrialfbConfig[var.floor]
    if TrialfbConfig[var.floor+1] then
        conf = TrialfbConfig[var.floor+1]
    end
    LDataPack.writeInt(pack, conf.fbid)
    LDataPack.writeShort(pack, var.floor)    
    LDataPack.writeInt(pack, MonstersConfig[conf.monsterid].avatar)
    LDataPack.flush(pack)
end

function sendFbInfo(ins)
    local actor = ins:getActorList()[1]
	if not actor then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_TrialFBInfo)
    LDataPack.writeShort(pack, ins.kill_monster_cnt or 0)
    LDataPack.flush(pack)
end

function sendRemainTime(ins, actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_TrialFBTime)
    local remaintime = FubenConfig[ins.id].totalTime + ins.start_time[0] - System.getNowTime()
    LDataPack.writeShort(pack, remaintime > 0 and remaintime or -1)
    LDataPack.flush(pack)
end


local function onWin(ins)
    local actor = ins:getActorList()[1]
	if not actor then return end
    local var = getActorVar(actor)
    var.floor = var.floor + 1        
    sendInfo(actor)
    updateRankingList(actor, var.floor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_TrialResult)
    LDataPack.writeChar(pack, 1)
    LDataPack.writeShort(pack, var.floor)
    LDataPack.writeChar(pack, #TrialfbConfig[var.floor + 1].normalAwards)
    for k,v in ipairs(TrialfbConfig[var.floor + 1].normalAwards) do
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count)
    end
    LDataPack.flush(pack)
    actoritem.addItems(actor, TrialfbConfig[var.floor + 1].normalAwards, "trial fuben reward")
end

local function onLose(ins)
    local actor = ins:getActorList()[1]
    if not actor then return end
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_TrialResult)
    LDataPack.writeShort(pack, var.floor)
    LDataPack.writeChar(pack, 0)
    LDataPack.writeChar(pack, 0)
    LDataPack.flush(pack)
end

local function onLogin(actor)
    sendInfo(actor)
end

local function onTouxianLevelUp(actor)
    local var = getActorVar(actor)
    updateRankingList(actor, var.floor)
end

local function init()
	if System.isBattleSrv() then return end
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeTouxianLevel, onTouxianLevelUp)    
	
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_EnterTrial, c2sEnterTrial)
    

	--注册相关回调
    for _, conf in pairs(TrialfbConfig) do
        insevent.registerInstanceWin(conf.fbid, onWin)
        insevent.registerInstanceLose(conf.fbid, onLose)
        insevent.registerInstanceMonsterDie(conf.fbid, onMonsterDie)
        insevent.registerInstanceEnter(conf.fbid, onEnterFb)
        insevent.registerInstanceEnterBefore(conf.fbid, onEnterBefore)
        insevent.registerInstanceActorDie(conf.fbid, onActorDie)
	end
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.trial = function (actor, args)
    local var = getActorVar(actor)
    var.floor = tonumber(args[1])
    sendInfo(actor)
	return true
end
