module("actorexp", package.seeall)

local LDataPack = LDataPack
local LActor    = LActor
local System    = System


require("actor.exp")
local SysId = Protocol.CMD_Base
local protocol = Protocol


local function getGlobalData()
	local var = System.getStaticVar()
	if var.worldlevel == nil then
		var.worldlevel = {}
    end
	if not var.worldlevel.worldlevel then var.worldlevel.worldlevel = 0 end
	if not var.worldlevel.update_time then var.worldlevel.update_time = 0 end
	return var.worldlevel
end

local function sendWorldLevel(actor)
	local var = getGlobalData()
	local npack = LDataPack.allocPacket(actor, protocol.CMD_Other, protocol.sWorldLevel)
	LDataPack.writeInt(npack, var.worldlevel)
	LDataPack.flush(npack)
end

function getWLExpPer(actor)
	local var = getGlobalData()
	local level = LActor.getLevel(actor)
	local diff = var.worldlevel - level
	if diff <= 0 then return 0 end
	for k,v in ipairs(WorldLevelConfig) do
		if diff >= v.difflevel[1] and diff <= v.difflevel[2] then
			return v.expper/100
		end
	end
	return 0
end

--得到世界等级,前十名的平均等级
function calcWorldLevel()
	local rank = utils.rankfunc.getRankById(RankingType_Level)
	if not rank then return 0 end
	local level = 0
	local count = 0
	local rankTbl = Ranking.getRankingItemList(rank, 10)
	if rankTbl then
		for i=1, #rankTbl do
			local prank = rankTbl[i]
			local value = Ranking.getPoint(prank)
			level = level + value
			count = count + 1
		end
	end
	return math.floor(level / (count > 0 and count or 1) )
end

function UpdateWorldLevel()
	local var = getGlobalData()
	var.worldlevel = calcWorldLevel()
	var.update_time = System.getNowTime()
	local actors = System.getOnlineActorList() or {}
    for i=1, #actors do
        sendWorldLevel(actors[i])
    end
end

function gameStart()
	local var = getGlobalData()
	local now = System.getNowTime()
	if not System.isSameDay(var.update_time, now) then
		var.worldlevel = calcWorldLevel()
		var.update_time = System.getNowTime()
	end
end

_G.updateWorldLevel = UpdateWorldLevel


--是否能继续升级
local function checkLevelLimit(level, zsLevel)
	if not ExpConfig[level+1] then --等级到极限
		return false
	end
	return true
end

local function onAddExp(actor, level, exp, nadd, tp, addper)
	local oldLevel = level
	local conf = ExpConfig[level]
	if conf == nil then return end
	local actordata = LActor.getActorData(actor)
	while exp >= conf.exp do
		if not checkLevelLimit(level, actordata.zhuansheng_lv) then
			break
		end
		exp = exp - conf.exp
		level = level + 1
		conf = ExpConfig[level]
		LActor.setLevel(actor, level)
		LActor.setExp(actor, exp)
		utils.rankfunc.updateRankingList(actor, level, RankingType_Level)
	end
	LActor.setExp(actor, exp)
	confirmExp(actor, level, exp, nadd, tp, addper)
	if level > oldLevel then
		onLevelUpEvent(actor, level, oldLevel)
		LActor.reCalcAttr(actor) --升完级后要计算战斗属性
		confirmAttr(actor, 0, oldLevel, level)
	end
end

function onLevelUpEvent(actor, level, oldLevel)
	LActor.onLevelUp(actor)
	actorevent.onEvent(actor, aeLevel, level, oldLevel)
end

--经验系数
local function getExpCoe(actor, notDouble)
	if notDouble then return 0 end
	local coe = 0
	return coe
end

function addExp(actor, nadd, log, notShowLog, notDouble, tp, addper)
	--if true then return end
	if type(nadd) ~= "number" then return 0 end
	if nadd <= 0 then return 0 end

	local old = LActor.getExp(actor)
	nadd = math.ceil(nadd * (getExpCoe(actor, notDouble) + 1)) --经验值为整数
	local exp = old + nadd
	local level = LActor.getLevel(actor)
	onAddExp(actor, level, exp, nadd, tp, addper)

	--log
	if not notShowLog  then
		System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
			"add exp", tostring(nadd), tostring(old), "", log, "", "")
	end
	--print(string.format("actor:%d add exp:%d log:%s", LActor.getActorId(actor), nadd, tostring(log)))
end

function cppAddExp(actor, nadd, log, tp )
	addExp(actor, nadd, log, false, false, tp)
end

function confirmExp(actor, level, exp, nadd, tp, addper)
	local npack = LDataPack.allocPacket(actor,  SysId, protocol.sBaseCmd_UpdateExp)
	if npack == nil then return end
	--64字节，lua只能用readDouble()
	LDataPack.writeInt(npack, level)
	LDataPack.writeDouble(npack, exp)
	LDataPack.writeDouble(npack, nadd)
	LDataPack.writeDouble(npack, ExpConfig[level].exp)
	LDataPack.writeByte(npack, tp or 0)
	LDataPack.writeShort(npack, addper and addper * 100 or 100)
	LDataPack.flush(npack)
end

function confirmAttr(actor, roleId, oldLevel, level)
	local role = LActor.getRole(actor)
	local job = LActor.getJob(role)
	local conf1 = RoleConfig[job][oldLevel]
	local conf2 = RoleConfig[job][level]

	local npack = LDataPack.allocPacket(actor,  SysId, protocol.sBaseCmd_LevelAttr)
	if npack == nil then return end
	LDataPack.writeShort(npack, roleId)
	LDataPack.writeChar(npack, 4) --4个属性值
	LDataPack.writeChar(npack, Attribute.atHpMax)
	LDataPack.writeInt(npack, conf2.HpMax - conf1.HpMax)
	LDataPack.writeChar(npack, Attribute.atAtkMin)
	LDataPack.writeInt(npack, conf2.AtkMin - conf1.AtkMin)
	LDataPack.writeChar(npack, Attribute.atAtkMax)
	LDataPack.writeInt(npack, conf2.AtkMax - conf1.AtkMax)
	LDataPack.writeChar(npack, Attribute.atDef)
	LDataPack.writeInt(npack, conf2.Def - conf1.Def)
	LDataPack.flush(npack)
end

function onLogin(actor)
	local exp = LActor.getExp(actor)
	local level = LActor.getLevel(actor)
	sendWorldLevel(actor)
	utils.rankfunc.updateRankingList(actor, level, RankingType_Level)
	--confirmLevel(actor, level, exp)
end

LimitTp = {
	rank = 29, 		--排行榜系统
	friend = 33,	--好友
	welfare = 43,	--福利大厅
	active = 45,	--活动大厅
	announcement = 60,--公告
	guildsiege = 119,--战盟入侵
	cschat = 130, --跨服聊天
	agreement = 1,
	touxian = 201,	--每日任务
	zhuansheng = 202, --转生
	equip = 203,	--装备
	suit = 204,		--套装
	dragon = 205, --黄金圣龙
	grail = 206,	--无限手套
	starsoul = 207,	--魂戒
	fruit = 208, --果实
	element = 209,--符文
	shenqi = 210, --神器
	wing = 211,--翅膀
	shenzhuang = 212,--神装
	meilin = 213,--梅林之书
	skill = 214, --技能
	hunqi = 215,--各种内观图鉴
	damon = 216,--精灵
	yongbing = 217,--出战单位弓箭手
	shenmo = 218,--神魔
	enhance = 219,--强化
	stone = 220,--宝石
	dazao = 221, --打造--新增装备合成
	append = 222, --追加
	culture = 223, --培养
	smelt = 224,--熔炼
	shengwu = 225,--圣物
	lilian = 226,--上一版每日任务
	vip = 227,--vip
	guildskill = 229,--战盟技能
	aoyi = 230, --奥义
	zlxz = 231,--战力勋章
	shilianboss = 233, --装备boss
	boss = 234, --全民BOSS
	crossboss = 235,	--跨服boss
	home = 236,		--boss之家
	wanmo = 237, --万魔
	heian = 248, --黑暗副本
	devil = 250, --恶魔广场
	mine = 252,		--水晶矿洞
	tianti = 253, --天梯
	fort = 254,		--赤色要塞
	guild = 255,	--公会系统
	jjc = 256, 		--竞技场
	fast = 257, 	--快速战斗
	chong = 260,  --10倍首冲
	rankopen = 276, --开服冲榜
	xuese = 288, --血色城堡
	daomonmozhen = 290, --精灵魔阵
	yongbingmozhen = 293, --佣兵法阵
	adventure = 296, --奇遇
	shenmomozhen = 305, --神魔魔阵
	shenmobosscross = 307, -- 跨服神魔
	molong = 314, -- 魔龙之城
	yongzhe = 315, -- 勇者
	foot = 316, -- 足迹
	dart = 318,	--运镖
	yongzhefuben = 323, --极限祭坛
	shenghun = 324, --圣魂神殿
	shenyou = 325, -- 神佑系统
	shengling = 326, -- 圣灵系统
	hufu = 335, -- 护符
	shenpan = 336, -- 审判套装
	angelshield = 337, -- 天使圣盾
	tianmo = 338, -- 堕落神装
	kalima = 339, -- 卡利玛
	relic = 340, -- 黄金魔王
	brave = 341, --勇者战场
	guzhanchang = 344, --古战场
	wechat = 345, --微信分享邀请	
	smzl = 346, -- 神魔之灵
	dark = 347, --暗黑神殿
	szzb = 348, --神魔装备
	campbattle = 349, --神魔圣战
	monstersiege = 351, --怪物攻城
	miyu = 355, --怪物攻城
	molian = 356, --怪物攻城
	shenshou = 360, --神兽
	hfcup = 361, --合服巅峰赛
	shenyu = 362, --神羽系统
	holyland = 363, --洛克神殿
	neigua = 367, --内挂助手
	yuansufb = 370, --元素秘境
	zhsz = 371, --真红圣装
	zhxg = 372, --真红限购
	zhfb = 373, --真红boss
	contest = 377, --战区擂台赛
	lingqi = 380, --灵器系统
	langhun = 383, --狼魂要塞
	dashi = 388, --大师任务
	tianxuan = 393, --天选之战
	huanshou = 394, --幻兽系统
	huanshoufb = 395, --无尽岛
	huanshoucross = 399, --幻兽岛
	champion = 404, --战区冠军赛
}

function checkLevelCondition(actor, tp)
	--达到SVIP等级后，忽略后续的开启条件
	local Svip = LActor.getSVipLevel(actor)
	if LimitConfig[tp].svipLv > 0 and Svip >= LimitConfig[tp].svipLv then
		return true
	end

	local zslevel = zhuansheng.getZSLevel(actor)
	if zslevel < LimitConfig[tp].zslevel then
		return false
	end

	if guajifuben.getCustom(actor) < LimitConfig[tp].custom then
		return false
	end

	if LimitConfig[tp].day > 0 and System.getOpenServerDay() < LimitConfig[tp].day then
		return false
	end
	return true
end
--检查是否可开启某项功能，不用判断等级和任务的
function checkLevelCondition1(tp)
	if LimitConfig[tp].day > 0 and System.getOpenServerDay() < LimitConfig[tp].day then
		return false
	end
	return true
end

function getLimitLevel(actor, tp)
	return LimitConfig[tp].slevel
end

function getLimitCustom(actor, tp)
	return LimitConfig[tp].custom
end

function checkDayCondition(tp)
	return System.getOpenServerDay() >= LimitConfig[tp].day
end

--兼容接口
LActor.addExp        = addExp

--提供给C++
--C++使用新增加的CallFunc来进行调用
_G.cppAddExp        = cppAddExp

actorevent.reg(aeUserLogin, onLogin)
engineevent.regGameStartEvent(gameStart)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.setlevel = function (actor, args)
	local old = LActor.getLevel(actor)
	local level = tonumber(args[1])
	-- if level <= old then
	-- 	chatcommon.sendSystemTips(actor, 1, 2, "level set is too low")
	-- 	return
	-- end
	if not ExpConfig[level] then --等级到极限
		return false
	end
	LActor.setLevel(actor, level)
	utils.rankfunc.updateRankingList(actor, level, RankingType_Level)
	confirmExp(actor, level, LActor.getExp(actor), 1, 0)
	--confirmLevel(actor, level, LActor.getExp(actor))
	onLevelUpEvent(actor, level, old)
	LActor.reCalcAttr(actor)
	return true
end

gmCmdHandlers.setwl = function(actor, args)
	local var = getGlobalData()
	var.worldlevel = tonumber(args[1])
	sendWorldLevel(actor)
end

gmCmdHandlers.levelAll = function (actor, args)
	local maxlevel = #ExpConfig
	gmCmdHandlers.setlevel(actor, {maxlevel})
end
