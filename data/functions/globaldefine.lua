MonSiegeDef = {
	--战场状态
	bsIdle = 1, --空闲
	bsBeChallenge = 2, --被挑战中
	bsOccupied = 3, --占领
	bsWaitResurr = 4, --等待复活

	--副本类型
	ftCommon = 1, --普通怪副本类型
	ftBoss = 2, --boss怪副本类型
	ftImage = 3, --镜象副本类型
	ftDaily = 4, --每日副本类型

	--普通副本的玩家状态
	aafbtStar = 1, --玩家在副本里面的状态（star）
	aafbtEnd = 2, --玩家在副本里面的状态（end）

	--普通副本的状态
	canChallenge = 0, --可挑战
	waitRunAway = 1, --等待逃跑
	resurrection = 2, --复活

	--boss副本的状态
	bfbDefault = 0, --
	bfbChallenge = 1, --挑战中
	bfbOccupied = 2, --占领后
	bfbEnd = 3, --结束后
}
