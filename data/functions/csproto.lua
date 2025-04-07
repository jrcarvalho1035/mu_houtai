
CrossSrvCmd =
{
	SFuncCmd = 255, --

	SFubenCmd = 1,		--跨服副本
	SCMineCmd = 2,		--跨服挖矿
	SCrossNetCmd = 3,	--跨服传输
	SCrossInfoCmd = 4,	--跨服状态传输
	SCrossFightCmd = 5,	--跨服战斗

	SCGuildWar = 6,	--跨服公会战斗

	SCDotaCmd = 7, --跨服5v5

	SCQueryCmd = 8, --跨服查询角色

	SCCheckCmd = 9, --匹配版本号检查

	SCActiivityCmd = 10, --跨服活动

	SCTianTiCmd = 11, --天梯

	SCComsumeCmd = 12,	--跨服消费

	SCHeFuCmd = 13, --专门开个协议做合服处理

	SCLotteryCmd = 14, --跨服幸运转盘

	SCChatCmd = 15, --跨服聊天
	SCAbyssCmd = 16, --跨服混乱之渊
	SCAsyncCmd = 17, --异步调用
	SCCustomCmd = 18, --跨服闯关帮助
	SCYuanbaoDrawCmd = 19, --钻石抽奖
	SCFortCmd = 20, --赤色要塞
	SCShenMoCmd = 21, -- 跨服神魔
	SCAcitivity13Cmd = 22, --飞升抢购
	SCAcitivity34Cmd = 23, --飞升排行

	SCGuildCmd = 24, --帮会系统，不可更改，C++使用

	SCMolongCmd = 25, --魔龙之城

	SCGuildDartCmd = 26, --跨服运镖

	SCGuildFight = 27,  --公会争夺战
	SCActivity20Cmd = 28,	-- 活动20，清明祭典
	SCShenghunCmd = 29, --圣魂神殿

	SCZhuzaiCmd = 30, --世界boss
	SCKalimaCmd = 31, --神庙boss
	SCBraveCmd = 32, --勇者战场
	SCGuzhan = 33, --古战场

	SCDarkCmd = 34, --暗黑神殿
	SCMonsterSiege = 35, --魔物围城
	SCCampBattle = 36, --阵营战
	SCHeFu = 37, --合服巅峰赛
	SCHolylandCmd = 38, --洛克神殿
	SCAct36 = 39, --送礼物活动
	SCYuanSuCmd = 40, --元素幻境
	SCZhenHongCmd = 41, --真红boss
	SCContestCmd = 42, --战区擂台赛
	SCLingQiCmd = 43, --灵器界域
	SCLangHunCmd = 44, --狼魂要塞
	SCTianXuanCmd = 45, --天选之战
	SCHuanShouCrossCmd = 46, --幻兽岛(多人)
	SCShenJiCmd = 47, --神迹秘境
}


CrossSrvSubCmd =
{
	SFuncCmd_Test = 255,

	--SFubenCmd
	SFubenCmd_SendMainSceneFuben = 1, --发送主城handle

	SCrossNetCmd_TransferToServer = 1,	-- 转发给其它服
	SCrossNetCmd_TransferToActor = 2,	-- 转发给其他玩家
	SCrossNetCmd_TransferToFightServer = 3,	-- 转发给战斗服
	SCrossNetCmd_Route = 4,			-- 发送路由数据

	SCrossNetCmd_Test = 5,
	SCrossNetCmd_TransferMail = 6,	-- 转发邮件
	SCrossNetCmd_AnnoTips = 7, --公告提示
	SCrossNetCmd_TransferGM = 8, --发送gm命令到战斗服
	SCrossNetCmd_TransferEvent = 9, --发送事件到普通服

	--SCMineCmd
	SCMineCmd_SendMineInfo = 1, --向普通服发送挖矿信息
	SCMineCmd_ReqMineIndex = 2, --请求副本handle
	SCMineCmd_SendMineHandle = 3, --发送副本handle
	SCMineCmd_ReqCloneInfo = 4, --请求玩家信息
	SCMineCmd_SendCloneInfo = 5, --发送玩家信息
	SCMineCmd_GetCurPower = 6, --请求玩家当前战力
	SCMineCmd_SendCurPower = 7, --发送玩家当前战力

	--SCGuildWarCmd
	SCGuildWar_SyncPlayerInfo = 1, --发送到普通服,要求普通服同步公会数据
	SCGuildWar_ActivityInfo = 2, -- 发送跨服公会信息到普通服
	SCGuildWar_ActivityRank = 3, -- 同步排行榜
	SCGuildWar_ReqEnroll = 4, -- 报名请求
	SCGuildWar_RetEnroll = 5, -- 报名返回
	SCGuildWar_ReqEnrollList = 6, -- 当前报名列表请求
	SCGuildWar_RetEnrollList = 7, -- 当前报名列表返回
	SCGuildWar_UpdateSingleEnroll = 8, -- 广播某个公会报名到普通服
	SCGuildWar_FixHeFuServerId = 9, -- 同步合服导致的serverId改变
	SCGuildWar_UpdateOneGuildPlayers = 10, -- 发送某个公会报名可参赛选手到普通服
	SCGuildWar_ReqHallInfo = 11, -- 请求名人堂信息
	SCGuildWar_RetHallInfo = 12, -- 返回名人堂信息
	SCGuildWar_BroadcastHallInfo = 13, -- 广播名人堂信息
	SCGuildWar_ActivityRankReq = 14, -- 请求同步排行榜
	SCGuildWar_FixGuildActorId = 15, -- 同步退出公会导致的玩家变成非参赛选手
	SCGuildWar_ReqFixGuildActorId = 16, -- 要求普通服同步退出公会导致的玩家变成非参赛选手
	SCGuildWar_Betting = 17, --押注
	-- SCGuildWar_SendSettlement = 18, --结算 --改成手动领取奖励，不需要结算

	SCGuildWar_ReqBetSysInfo = 19, --请求系统的押注信息
	-- SCGuildWar_ReqBetSelfInfo = 20, --请求自己的的押注信息, 记录在玩家身上, 不需要请求跨服

	-- SCDotaCmd
	SCDotaCmd_MatchPlayer = 1, -- 玩家匹配
	SCDotaCmd_MatchResult = 2, -- 匹配结果返回
	SCDotaCmd_CancelMatch = 3, -- 取消匹配
	SCDotaCmd_SyncWeekRank = 4, -- 同步跨服55周排行榜
	SCDotaCmd_SyncFbOver = 5, -- 同步副本结束信息到普通服
	SCDotaCmd_SyncIsBusy = 6, -- 广播到普通服当前是否可匹配


	--SCQueryCmd
	SCQueryCmd_SrcToCross = 1, -- 普通服发到跨服查询
	SCQueryCmd_CrossToTar = 2, -- 跨服发到目标服查询
	SCQueryCmd_TarToCross = 3, -- 目标服返回数据到跨服
	SCQueryCmd_CrossToSrc = 4, -- 跨服返回数据到普通服

	--SCCheckCmd
	SCCheckCmd_CheckVersion = 1,

	--SCActiivityCmd --跨服抢购
	SCActiivityCmd_AddXunbaoRecord = 1,
	SCActiivityCmd_GetXunbaoRecord = 2,
	SCActiivityCmd_SendXunbaoRecord = 3,
	SCActiivityCmd_Act1DaBiao = 4,

	SCFlashSaleCmd_SyncSysInfo = 1, --同步系统信息
	SCFlashSaleCmd_BuyItem = 2, --购买道具

	SCFlashSaleCmd_SyncBuyInfo = 3, --同步购买次数

	--SCComsumeCmd  跨服消费
	SCComsumeCmd_RankDataRequest = 1, 	--排行榜数据请求
	SCComsumeCmd_RankDataSync = 2, 		--排行榜数据回包
	SCComsumeCmd_Comsume = 3, 	--消费
	SCComsumeCmd_ActivityFinish = 4,
	SCComsumeCmd_UpdateRankInfo = 5,	--更新排行榜

	--SCHeFuCmd
	SCHeFuCmd_HeFuEvents = 1, --普通服上传合服数据

	--SCLotteryCmd
	SCLotteryCmd_UpdateInfo = 1, -- 开始
	SCLotteryCmd_UpdatePool = 2, -- 奖池金额变化
	SCLotteryCmd_ClientDraw = 3, -- 玩家抽奖 server->cs server
	SCLotteryCmd_CostPoolYb = 4, -- 玩家抽到奖池

	--SCChatCmd
	SCChatCmd_SyncChatInfo = 1, --同步到普通服
	SCChatCmd_UpdateChat = 2,  --更新聊天到普通服
	SCChatCmd_SendChat = 3,  --普通服发送聊天
	SCChatCmd_SendServerBroadcast = 4, -- 发送本服公告内容
	SCChatCmd_UpdateLoginBroadcast = 5, --发送登录公告
	SCChatCmd_SendLoginBroadcast = 6, --发送登录公告

	--SCAbyssCmd
	SCAbyssCmd_SyncAllFbInfo = 1,	--同步BOSS副本信息
	SCAbyssCmd_UpdateSingleFbInfo = 2,	--同步单个BOSS副本信息
	SCAbyssCmd_SyncAbyssPoint = 3,	--同步繁荣度
	SCAbyssCmd_SyncAbyssIsOpen = 4,	--同步是否开启标记
	SCAbyssCmd_Notice	= 5, 	--公告

	--SCAsyncCmd
	SCAsyncCmd_Call = 1,
	SCAsyncCmd_Resp = 2,
	SCAsyncCmd_Return = 3,

	--SCCustomCmd
	SCCustomCmd_SeekHelp = 1, --请求帮助
	SCCustomCmd_HelpActor = 2, --帮助玩家
	SCCustomCmd_HelpResult = 3, --帮助结果
	SCCustomCmd_HelpBro = 4, --帮助成功广播

	--SCTianTiCmd
	SCTianTiCmd_MatchActor = 1, --匹配玩家
	SCTianTiCmd_FindActorResult = 2, --匹配玩家返回
	SCTianTiCmd_ReqCloneInfo = 3, --请求跨服玩家数据
	SCTianTiCmd_ResCloneInfo = 4, --返回跨服玩家数据
	SCTianTiCmd_UpdateRank = 5, --更新天梯信息
	SCTianTiCmd_GetRankList = 6, --请求排行榜数据
	SCTianTiCmd_GetRankListReturn = 7, --请求排行榜返回
	SCTianTiCmd_GetFirstName = 8,	--获取上周第一名
	SCTianTiCmd_GetFirstNameReturn = 9,--获取上周第一名返回

	--SCYuanbaoDrawCmd 钻石夺宝
	SCYuanbaoDrawCmd_UpdateCrossInfo = 1, --同步数据到跨服
	SCYuanbaoDrawCmd_UpdateCommonInfo = 2, --同步数据到普通服
	SCYuanbaoDrawCmd_GetSelfRank = 3, --获取排行
	SCYuanbaoDrawCmd_SendSelfRank = 4, --获取排行返回
	SCYuanbaoDrawCmd_GetServerRank = 5, --获取全服排行
	SCYuanbaoDrawCmd_SendServerRank = 6, --获取全服排行返回
	SCYuanbaoDrawCmd_ActivitySelfFinish = 7, --个人活动结算
	SCYuanbaoDrawCmd_ActivityServerFinish = 8, --全服活动结算

	--SCFortCmd 赤色要塞
	SCFortCmd_SyncAllFbInfo = 1, --同步数据到普通服
	SCFortCmd_SyncFloorFbInfo = 2,--同步层数到普通服
	SCFortCmd_SyncRankInfo= 3,--同步排行榜到普通服
	SCFortCmd_SyncRankRewards = 4,--同步结算信息到普通服
	SCFortCmd_SyncRankTopFewList = 5,--同步结算信息到普通服
	SCFortCmd_FortNotice = 6, --广播公告到普通服
	SCFortCmd_FortReady = 7, --广播活动准备到普通服
	SCFortCmd_FortStart = 8, --广播活动开启到普通服
	SCFortCmd_FortStop = 9, --广播活动结束到普通服

	-- 跨服Boss圣殿
	SCShenMoBossCmd_SendServerBossInfo = 1, -- 发送本服boss信息

	--SCAcitivity13Cmd 飞升抢购
	SCAcitivity13Cmd_SendGetCount = 1,
	SCAcitivity13Cmd_UpdateGetCount = 2,

	--SCAcitivity34Cmd 飞升排行
	SCAcitivity34Cmd_UpdateScore = 1,
	SCAcitivity34Cmd_ReqRank = 2,
	SCAcitivity34Cmd_SendRank = 3,
	SCAcitivity34Cmd_ReqFinishInfo = 4,
	SCAcitivity34Cmd_SendFinishInfo = 5,
	SCAcitivity34Cmd_SendServerNeedRank1 = 6,
	SCAcitivity34Cmd_SendCrossRank1 = 7,
	SCAcitivity34Cmd_SendServerRank1 = 8,
	SCAcitivity34Cmd_SendServerRank3 = 9,
	SCAcitivity34Cmd_SendFinishInfoAll = 10,

	SCActivity20Cmd_SendCrossAddCv = 1,
	SCActivity20Cmd_SendServerCv = 2,
	SCActivity20Cmd_SendCrossPv = 3,
	SCActivity20Cmd_SendServerPvNo1 = 4,
	SCActivity20Cmd_SendServerCvNum = 5,
	SCActivity20Cmd_SendCrossReset = 6,
	SCActivity20Cmd_SendServerPvNo1Point = 7,
	SCActivity20Cmd_SendServerCvNext = 8,
	SCActivity20Cmd_CrossAddPv = 9,

	--SCGuildCmd 帮会跨服占用
	SCGuildCmd_GetGuildList = 1,
	SCGuildCmd_SendGuildList = 2,--不可更改，C++也使用
	SCGuildCmd_GetMemberList = 3,
	SCGuildCmd_SendMemberList = 4,--不可更改，C++也使用
	SCGuildCmd_GetApplyInfo = 5,
	SCGuildCmd_SendApplyInfo = 6,--不可更改，C++也使用
	SCGuildCmd_GetGuildLogList = 7,
	SCGuildCmd_SenGuildLogList = 8,--不可更改，C++也使用
	SCGuildCmd_GetSearchist = 9,
	SCGuildCmd_SendSearchList = 10,--不可更改，C++也使用

	SCGuildCmd_GetGuildInfo = 11,
	SCGuildCmd_SendGuildInfo = 12,
	SCGuildCmd_GetGuildCreate = 13,
	SCGuildCmd_SendGuildCreate = 14,
	SCGuildCmd_SendGuildTip = 15,
	SCGuildCmd_GetAutoApprove = 16,
	SCGuildCmd_SendAutoApprove = 17,
	SCGuildCmd_GetApplyJoin = 18,
	SCGuildCmd_SendApplyJoin = 19,
	SCGuildCmd_GetGuildChat = 20,
	SCGuildCmd_SendGuildChat = 21,
	SCGuildCmd_GetGuildChatLog = 22,
	SCGuildCmd_SendGuildChatLog = 23,
	SCGuildCmd_GetImpeach = 24,
	SCGuildCmd_SendImpeach = 25,
	SCGuildCmd_GetChangePos = 26,
	SCGuildCmd_SendChangePos = 27,
	SCGuildCmd_GetKick = 28,
	SCGuildCmd_SendKick = 29,
	SCGuildCmd_GetExit = 30,
	SCGuildCmd_SendExit = 31,
	SCGuildCmd_GetDonate = 32,
	SCGuildCmd_GetUpgradeBuilding = 33,
	SCGuildCmd_SendUpgradeBuilding = 34,
	SCGuildCmd_ChangeMemo = 35,
	SCGuildCmd_SendBasicInfo = 36,
	SCGuildCmd_ChangeMemberName = 37,
	SCGuildCmd_SendJoinGuild = 38,
	SCGuildCmd_ActorLogin = 39,
	SCGuildCmd_ActorLogout = 40,
	SCGuildCmd_ChangeGuildPos = 41,
	SCGuildCmd_UpdateStoreLog = 42,
	SCGuildCmd_SendStoreLog = 43,
	SCGuildCmd_GetStoreLog = 44,
	SCGuildCmd_GetGiftInfo = 45,
	SCGuildCmd_SendGiftInfo = 46,
	SCGuildCmd_SendGiftCharge = 47,
	SCGuildCmd_SendGiftData = 48,
	SCGuildCmd_UpdateGift = 49,
	SCGuildCmd_GuildRecharge = 50,
	SCGuildCmd_SendMemberBasicInfo = 52,
	SCGuildCmd_ChangeMemberGx = 53,
	SCGuildCmd_ChangeGuildFund = 54,
	SCGuildCmd_UpdateSiegeInfo = 55,
	SCGuildCmd_UpdateSiegeStatus = 56,
	SCGuildCmd_SendSiegeStatus = 57,

	SCGuildCmd_GetTeamInvite = 58,
	SCGuildCmd_SendTeamInvite = 59,
	SCGuildCmd_GetTeamApply = 60,
	SCGuildCmd_SendTeamApply = 61,
	SCGuildCmd_GetTeamSpurn = 62,
	SCGuildCmd_SendTeamSpurn = 63,
	SCGuildCmd_GetTeamBreak = 64,
	SCGuildCmd_SendTeamBreak = 65,
	SCGuildCmd_SendTeamTipMsg = 68,
	SCGuildCmd_UpdateBossInfo = 69,
	SCGuildCmd_GetReadyEnter = 70,
	SCGuildCmd_SendReadyEnter = 71,

	SCGuildCmd_GetOtherActor = 72,
	SCGuildCmd_SendOtherActor = 73,

	SCGuildCmd_GetRespondJoin = 74,
	SCGuildCmd_SendRespondJoin = 75,

	--SCMolongCmd
	SCMolongCmd_GetFubenHdl = 1,
	SCMolongCmd_SendFubenHdl = 2,
	SCMolongCmd_SendErrorTip = 3,
	SCMolongCmd_CheckCanEnter = 4,
	SCMolongCmd_InviteActor = 5,
	SCMolongCmd_ReqActorInfo = 6,
	SCMolongCmd_SendActorInfo = 7,


	--SCGuildDartCmd, --跨服运镖
	SCGuildDartCmd_ChooseCar = 1,
	SCGuildDartCmd_ChooseCarRet = 2,
	SCGuildDartCmd_GetCarList = 3,
	SCGuildDartCmd_SendCarList = 4,
	SCGuildDartCmd_GetSelfRankList = 5,
	SCGuildDartCmd_SendSelfRankList = 6,
	SCGuildDartCmd_GetGuildRankList = 7,
	SCGuildDartCmd_SendGuildRankList = 8,
	SCGuildDartCmd_GetSelfRecordList = 9,
	SCGuildDartCmd_SendSelfRecordList = 10,
	SCGuildDartCmd_GetGuildRecordList = 11,
	SCGuildDartCmd_SendGuildRecordList = 12,
	SCGuildDartCmd_RefreshPlunerList = 13,
	SCGuildDartCmd_RefreshPlunerListRet = 14,
	SCGuildDartCmd_GetPlunerList = 15,
	SCGuildDartCmd_SendPlunerList = 16,
	SCGuildDartCmd_ReqPlunder = 17,
	SCGuildDartCmd_CanPlunder = 18,
	SCGuildDartCmd_ReqActor = 19,
	SCGuildDartCmd_SendActor = 20,
	SCGuildDartCmd_GetRankActor = 21,
	SCGuildDartCmd_SendRankActor = 22,
	SCGuildDartCmd_GMOpenDart = 23,
	SCGuildDartCmd_GMOpenEnd = 24,
	SCGuildDartCmd_GMCarLevel = 25,

	--SCGuildFight --公会争夺战
	SCGuildFightCmd_UpdateActorsPower = 1,
	SCGuildFightCmd_ApplyBattle = 2,
	SCGuildFightCmd_ApplyResult = 3,
	SCGuildFightCmd_SendManorList = 4, --发送领地信息
	SCGuildFightCmd_Guess = 5, --竞猜
	SCGuildFightCmd_SendGuess = 6, --竞猜结果
	SCGuildFightCmd_GetDailyReward = 7,--领取每日奖励
	SCGuildFightCmd_SendDailyReward = 8,--领取每日奖励
	SCGuildFightCmd_GetApplyList = 9,
	SCGuildFightCmd_GetHongbao = 10,
	SCGuildFightCmd_GetHongbaoRet = 11,
	SCGuildFightCmd_SetHongbao = 12,
	SCGuildFightCmd_SetHongbaoRet = 13,
	SCGuildFightCmd_GetFightList = 14,
	SCGuildFightCmd_SendFightList = 15,
	SCGuildFightCmd_GetFightInfo = 16,
	SCGuildFightCmd_SendFightInfo = 17,
	SCGuildFightCmd_GetLeaderInfo = 18,
	SCGuildFightCmd_SendLeaderInfo = 19,  --C++调用，不可更改
	SCGuildFightCmd_EnterFuben = 20,
	SCGuildFightCmd_SendFuben = 21,
	SCGuildFightCmd_SendBaseInfo = 22,
	SCGuildFightCmd_SendWorship = 23,
	SCGuildFightCmd_UpdateStage = 24,
	SCGuildFightCmd_GetFirstGuildLeaderInfo = 25,
	SCGuildFightCmd_SendFirstGuildLeaderInfo = 26,
	SCGuildFightCmd_SendRankInfo = 27,
	SCGuildFightCmd_SendHongbaoInfo = 28,
	SCGuildFightCmd_SendJoinInfo = 29,
	SCGuildFightCmd_SendGuildRankInfo = 30,
	SCGuildFightCmd_GetGuildSelfRank = 31,
	SCGuildFightCmd_SendGuildSelfRank = 32,
	SCGuildFightCmd_UpdateGuildSemiWin = 33,


	--SCShenghunCmdCmd
	SCShenghunCmd_GetFubenHdl = 1,
	SCShenghunCmd_SendFubenHdl = 2,
	SCShenghunCmd_SendErrorTip = 3,
	SCShenghunCmd_CheckCanEnter = 4,
	SCShenghunCmd_InviteActor = 5,
	SCShenghunCmd_ReqActorInfo = 6,
	SCShenghunCmd_SendActorInfo = 7,

	--SCZhuzaiCmd 世界boss
	SCZhuzaiCmd_SyncAllFbInfo = 1,
	SCZhuzaiCmd_SyncRankInfo = 2,
	SCZhuzaiCmd_SyncZhuzaiStatus = 3,

	--SCKalimaCmd 神庙boss
	SCKalimaCmd_SyncAllFbInfo = 1,
	SCKalimaCmd_SyncUpdateFbInfo = 2,
	SCKalimaCmd_SyncUpdateBlood = 3,
	--昆顿副本
	SCKalimaCmd_QuaintonfbInfo = 4,
	SCKalimaCmd_QuaintonInfo = 5,

	--SCBraveCmd 勇者战场
	SCBraveCmd_SyncAllFbInfo = 1,
	SCBraveCmd_SyncUpdateFbInfo = 2,
	SCBraveCmd_SyncUpdateBlood = 3,

	--SCGuzhan 古战场
	SCGuzhan_SyncUpdateFbInfo = 1,
	SCGuzhan_GMStart = 2,
	SCGuzhan_GetRank = 3,
	SCGuzhan_SendRank = 4,
	SCGuzhan_SettleRank = 5,

	--暗黑神殿
	SCdarkCmd_SendDarkBossInfo = 1, --发送本服boss信息
	SCdarkCmd_UpdateDarkBlood = 2, --更新血量

	--魔物围城
	SCMSCmd_ReqRankInfo = 1,
	SCMSCmd_SendRankInfo = 2,
	SCMSCmd_AddScore = 3,

	--阵营战
	SCCBCmd_ReqRankInfo = 1,
	SCCBCmd_SendRankInfo = 2,
	SCCBCmd_GetRankFirstCache = 3,
	SCCBCmd_SendRankFirstCache = 4,
	SCCBCmd_UpdateActorInfo = 5,
	SCCBCmd_InitActorCampInfo = 6,
	SCCBCmd_UpdateCampScore = 7,
	SCCBCmd_ReqUpdateRankPower = 8,
	SCCBCmd_ResUpdateRankPower = 9,

	--合服巅峰赛
	SCHFCupCmd_Enroll = 1, --报名
	SCHFCupCmd_Worship = 2, --请求膜拜
	SCHFCupCmd_BetGame = 3, --请求投注
	SCHFCupCmd_WorshipData = 4, --请求雕像数据
	SCHFCupCmd_Info = 5, --基础信息
	SCHFCupCmd_GameInfo = 6, --请求对局信息
	SCHFCupCmd_BetInfo = 7, --请求投注信息
	SCHFCupCmd_PowerRank = 8, --请求战力排行
	SCHFCupCmd_FansRank = 9, --请求人气排行榜
	SCHFCupCmd_MyGameInfo = 10, --请求我的战绩
	SCHFCupCmd_MyBetInfo = 11, --请求我的投注
	SCHFCupCmd_WorshipInfo = 12, --请求雕像信息
	SCHFCupCmd_NoticeInfo = 13, --同步前X名公告信息
	SCHFCupCmd_getFirstCache = 14, --同步第一名形象
	SCHFCupCmd_SyncGameInfo = 15, --同步对局信息
	SCHFCupCmd_SyncDataInfo = 16, --同步赛季信息
	SCHFCupCmd_SyncActorInfo = 17, --同步比赛玩家信息
	SCHFCupCmd_ActorCache = 18, --同步玩家形象
	SCHFCupCmd_SyncActorPower = 19, --获取玩家战斗力
	SCHFCupCmd_UpdateActorPower = 20, --同步玩家战斗力
	SCHFCupCmd_broadInfo = 21, --广播玩家更新信息
	SCHFCupCmd_broadStageFinish = 22, --广播每轮比赛结束

	--SCBraveCmd 洛克神殿
	SCHolylandCmd_SyncAllFbInfo = 1,
	SCHolylandCmd_SyncUpdateFbInfo = 2,
	SCHolylandCmd_SyncUpdateBlood = 3,


	--SCAct36 送礼物
	SCAct36Cmd_BroSelf = 1, --广播自己
	SCAct36Cmd_RecvBroSelf = 2, --普通服收到广播
	SCAct36Cmd_GetRank = 3, --查看收到礼物排名
	SCAct36Cmd_SendRank = 4, --发送收到礼物排名		
	SCAct36Cmd_SendGift = 5, --送礼
	SCAct36Cmd_SendGiftRet = 6, --送礼结果
	SCAct36Cmd_GetRecord = 7,--请求记录
	SCAct36Cmd_SendRecord = 8,--返回记录
	SCAct36Cmd_ReqActors = 9, --请求玩家列表
	SCAct36Cmd_SendActors = 10, --发送玩家列表
	SCAct36Cmd_GetFirstInfo = 11, --请求第一名形象数据
	SCAct36Cmd_SendFirstInfo = 12, --返回第一名数据
	SCAct36Cmd_GetRankInfo = 13, --请求排行榜中单个玩家数据
	SCAct36Cmd_SendRankInfo = 14, --返回排行榜中单个玩家数据

	--SCYuanSuCmd 元素幻境
	SCYuanSuCmd_SyncAllFbInfo = 1,
	SCYuanSuCmd_SyncUpdateFbInfo = 2,

	--SCZhenHongCmd 真红boss
	SCZhenHongCmd_CreateFb = 1,
	SCZhenHongCmd_SyncAllFbInfo = 2,
	SCZhenHongCmd_SyncUpdateFbInfo = 3,
	SCZhenHongCmd_SyncDeleteFbInfo = 4,
	SCZhenHongCmd_SyncUpdatePeople = 5,
	SCZhenHongCmd_SyncUpdateHp = 6,
	SCCBCmd_ReqZHRankInfo = 7,
	SCCBCmd_SendZHRankInfo = 8,
	SCCBCmd_SendZHEvent = 9,

	--SCContestCmd 战区擂台赛 
	SCContestCmd_Enroll = 1,
	SCContestCmd_SyncContestInfo = 2,
	SCContestCmd_SyncRankInfo = 3,
	SCContestCmd_ContestFight = 4,

	--SCLingQiCmd
	SCLingQiCmd_GetFubenHdl = 1,
	SCLingQiCmd_SendFubenHdl = 2,
	SCLingQiCmd_CheckCanEnter = 3,
	SCLingQiCmd_SendErrorTip = 4,
	SCLingQiCmd_InviteActor = 5,
	SCLingQiCmd_ReqActorInfo = 6,
	SCLingQiCmd_SendActorInfo = 7,

	--SCLangHunCmd 狼魂要塞
	SCLangHunCmd_SyncInfo = 1,
	SCLangHunCmd_SyncRankInfo = 2,

	--SCTianXuanCmd 天选之战
	SCTianXuanCmd_SyncInfo = 1,
	SCTianXuanCmd_SyncRankInfo = 2,

	--SCHuanShouCrossCmd 幻兽岛(多人)
	SCHuanShouCrossCmd_SyncAllFbInfo = 1,
	SCHuanShouCrossCmd_SyncUpdateFbInfo = 2,

	--SCShenJiCmd 元素幻境
	SCShenJiCmd_SyncAllFbInfo = 1,
	SCShenJiCmd_SyncUpdateFbInfo = 2,
}

