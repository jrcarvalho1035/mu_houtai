TimerConfig =
{
    
    {week = 1, hour = 10, minute = 0, func = "OpenTianti"}, -- 开启天梯
    {week = 0, hour = 10, minute = 30, func = "CloseTianti"}, -- 结束天梯
    {week = 0, hour = 10, minute = 00, func = "StopTianti"}, -- 停止天梯匹配
    
    {hour = 21, minute = 0, func = "flushGrantJjcReward"}, --每天21点发放竞技场奖励
    {hour = 22, minute = 0, func = "kickFanchenmi"}, --每天20点踢掉防沉迷玩家
    {hour = 0, minute = 0, func = "updateGuildData"}, --每天0点更新帮派数据
    {hour = 6, minute = 0, func = "updateAllGuildPos"}, --每天6点更新帮派职位
    
    {hour = 0, minute = 0, func = "updateActivity"}, --周活动，月活动重新计算时间,检查活动是否开始
    
    {hour = 0, minute = 0, func = "angelEquipFinish"}, --天使圣装结算
    
    {hour = 5, minute = 0, func = "friendmgrSaveData"}, --保存好友数据
    
    {week = 1, hour = 0, minute = 1, func = "flushGuildBoss"}, -- 重置战盟BOSS
    
    --赤色要塞
    {hour = 12, minute = 25, func = "flushReadyFort1"},
    {hour = 12, minute = 30, func = "flushStartFort1"},
    {hour = 12, minute = 40, func = "flushStopFort1"},
    {hour = 19, minute = 25, func = "flushReadyFort2"},
    {hour = 19, minute = 30, func = "flushStartFort2"},
    {hour = 19, minute = 40, func = "flushStopFort2"},
    
    {hour = {0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22}, minute = 0, func = "flushBossHome"}, --BOSS之家刷新时间
    
    {hour = {2, 4, 8, 16}, minute = 25, func = "systemGC"}, --清内存

    {hour = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23}, minute = 0, func = "flushSetTitle"}, --排行榜重新设置称号
    
    --战盟入侵
    {hour = 9, minute = 30, func = "guildsiegeStart"},
    {hour = 22, minute = 00, func = "guildsiegeEnd"},
    
    --世界等级更新
    {hour = 0, minute = 01, func = "updateWorldLevel"},
    
    --23点全服更新领奖状态
    {hour = 23, minute = 00, func = "updateActivityInfo"},
    
    --23点50-52将玩家踢出副本
    {hour = 23, minute = {50, 52}, func = "kickAllActor"},
    
    --23:54-58 Se o jogador ainda estiver na instância, force o jogador a ficar offline
    {hour = 23, minute = {54, 56, 58}, func = "offlineAllActor"},
    
    {hour = 12, minute = 00, func = "dropBoxStart"},
    {hour = 12, minute = 30, func = "dropBoxEnd"},
    
    --发公告
    {hour = 23, minute = {40, 42, 44, 46, 48}, func = "broCrossClose"},
    
    {hour = {10, 17}, minute = 55, func = "dartReady"},
    {hour = 21, minute = 25, func = "dartReady"},
    
    {hour = {11, 18}, minute = 00, func = "dartStart"},
    {hour = 21, minute = 30, func = "dartStart"},
    
    {hour = {12, 19}, minute = 00, func = "dartEnd"},
    {hour = 22, minute = 30, func = "dartEnd"},
    
    {week = 0, hour = 22, minute = 40, func = "dartSettlement"},
    
    --主宰BOSS
    {hour = 12, minute = 35, func = "ZhuZaiReady"},
    {hour = 12, minute = 40, func = "ZhuZaiStart"},
    {hour = 12, minute = 50, func = "ZhuZaiStop"},
    {hour = 18, minute = 55, func = "ZhuZaiReady"},
    {hour = 19, minute = 00, func = "ZhuZaiStart"},
    {hour = 19, minute = 10, func = "ZhuZaiStop"},
    
    {hour = 19, minute = 10, func = "startGuzhanchang"}, -- 古战场开启时间
    {hour = 19, minute = 30, func = "stopGuzhanchang"}, -- 古战场结束时间
    
    --领地争夺战
    {hour = 10, minute = 00, func = "updateGuildPower1"}, -- 领地争夺战报名阶段刷新战力时间
    {hour = 22, minute = 00, func = "updateGuildPower2"}, -- 领地争夺战报名阶段刷新战力时间
    {hour = 0, minute = 00, func = "guildPowerApplyStart"}, -- 新的报名开始
    {hour = 18, minute = 30, func = "updateGuildPower"}, -- 领地争夺战刷新战力时间
    {hour = 19, minute = 30, func = "guildBattleGuess"}, -- 领地争夺战竞猜副本时间
    {hour = 20, minute = 00, func = "enterGuildBattle1"}, -- 领地争夺战第一场进副本时间
    {hour = 20, minute = 05, func = "openGuildBattle1"}, -- 领地争夺战第一场战斗
    {hour = 20, minute = 16, func = "enterGuildBattle2"}, -- 领地争夺战第二场进副本时间
    {hour = 20, minute = 20, func = "openGuildBattle2"}, -- 领地争夺战第二场战斗
    {hour = 20, minute = 30, func = "guildBattleFinish"}, -- 领地争夺战踢出副本
    {hour = 20, minute = 31, func = "guildBattleStop"}, -- 领地争夺战决出胜负
    
    {hour = 10, minute = 00, func = "startMonsterSiege"}, -- 怪物攻城开启时间
    {hour = 22, minute = 00, func = "stopMonsterSiege"}, -- 怪物攻城结束时间
    {week = 0, hour = 22, minute = 05, func = "settlementMonsterSiege"}, -- 怪物攻城结算时间
    {week = 1, hour = 00, minute = 00, func = "monsterSiegeClear"}, -- 怪物攻城结束时间
    
    {hour = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23}, minute = 0, func = "flushDarkBoss"}, --暗黑神殿BOSS整点刷新
    
    {week = 1, hour = 00, minute = 00, func = "loadCBTime"}, --A batalha de facções ganha o horário de atividade da temporada toda segunda-feira
    {week = 1, hour = 00, minute = 00, func = "reSetCBSeason"}, --A batalha de facções reinicia a temporada toda segunda-feira
    {week = 1, hour = 03, minute = 00, func = "checkCampTime"}, --batalha de facções
    {week = 1, hour = 05, minute = 00, func = "seasonCBBegin"}, --Começa a temporada de guerras de facções
    {week = 0, hour = 21, minute = 30, func = "seasonCBFinish"}, --A temporada de Guerras de Facções termina
    {week = {0, 1, 2, 3, 4, 5}, hour = 20, minute = 00, func = "dayCBStart"}, --Começa a temporada de guerras de facções
    {week = {0, 1, 2, 3, 4, 5}, hour = 20, minute = 30, func = "dayCBEnd"}, --A temporada de Guerras de Facções termina

    --#{ minute = 59, func = "updateHFCup" }, --每个小时59分刷新合服巅峰赛战斗力

    {week = 1, hour = 0, minute = 0, func = "ZHBOSSOpen"}, --开启真红boss活动
    {week = 0, hour = 22, minute = 0, func = "ZHBOSSClose"}, --结束真红boss活动
    {week = 0, hour = 22, minute = 30, func = "flushZHRankReward"}, --真红榜单结算

    {week = 0, hour = 0, minute = 0, func = "ResetContest"}, --O evento da arena começa
    {week = 0, hour = 9, minute = 0, func = "UpdateContestStage"}, --As inscrições para o concurso estão abertas
    {week = 0, hour = 20, minute = 30, func = "UpdateContestStage"}, --Fim do registro
    {week = 0, hour = 20, minute = 30, func = "UpdateContestStage"}, --Corrida de pontos começa
    {week = 0, hour = 20, minute = 42, func = "UpdateContestStage"}, --Fim da corrida por pontos
    {week = 0, hour = 20, minute = 43, func = "UpdateContestStage"}, --A arena começa
    {week = 0, hour = 20, minute = 43, func = "UpdateContestRound"}, --A primeira rodada de apostas na arena
    {week = 0, hour = 20, minute = 44, func = "FightContestRound"}, --A primeira rodada da arena do grupo
    {week = 0, hour = 20, minute = 45, func = "UpdateContestRound"}, --Apostas na Segunda Rodada de Ring Match
    {week = 0, hour = 20, minute = 46, func = "FightContestRound"}, --A segunda rodada da arena do grupo
    {week = 0, hour = 20, minute = 47, func = "UpdateContestRound"}, --Apostas na Terceira Rodada de Ring Match
    {week = 0, hour = 20, minute = 48, func = "FightContestRound"}, --A terceira rodada da arena do grupo
    {week = 0, hour = 20, minute = 49, func = "UpdateContestRound"}, --Apostas na rodada 4 na arena
    {week = 0, hour = 20, minute = 50, func = "FightContestRound"}, --A quarta rodada da arena do grupo
    {week = 0, hour = 20, minute = 51, func = "UpdateContestRound"}, --Apostas na Quinta Rodada do Ring Match
    {week = 0, hour = 20, minute = 52, func = "FightContestRound"}, --A quinta rodada da arena do grupo
    {week = 0, hour = 20, minute = 53, func = "UpdateContestRound"}, --Apostas na sexta rodada
    {week = 0, hour = 20, minute = 54, func = "FightContestRound"}, --A sexta rodada da arena do grupo
    {week = 0, hour = 20, minute = 55, func = "UpdateContestRound"}, --Apostas da Sete Rodada
    {week = 0, hour = 20, minute = 56, func = "FightContestRound"}, --A sétima rodada da arena do grupo
    {week = 0, hour = 21, minute = 00, func = "UpdateContestStage"}, --A competição acabou

    {week = {2, 4, 6}, hour = 0, minute = 0, func = "ResetLanghun"}, --Reinicialização do evento Wolf Soul Fortress
    {week = {2, 4, 6}, hour = 20, minute = 30, func = "LanghunStart"}, --Começa a atividade da Fortaleza da Alma do Lobo
    {week = {2, 4, 6}, hour = 21, minute = 00, func = "LanghunStop"}, --Fim do evento Wolf Soul Fortress

    {week = {3}, hour = 0, minute = 0, func = "ResetTianxuan"}, --Reinicialização do evento Batalha do Escolhido
    {week = {3}, hour = 20, minute = 30, func = "TianxuanStart"}, --O evento Batalha dos Escolhidos começa
    {week = {3}, hour = 20, minute = 57, func = "TianxuanStop"}, --Batalha dos Escolhidos termina
    {week = {3}, hour = 21, minute = 00, func = "TianxuanClose"}, --Recompensas para o evento Batalha dos Escolhidos

    {hour = {0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22}, minute = 0, func = "RefreshStone"}, --A pedra sagrada é atualizada a cada 2 horas na Ilha de Huanjue
}
