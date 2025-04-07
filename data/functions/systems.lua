-- @version	1.0
-- @author	rancho
-- @date	2019-03-18
-- @system	systems

require "protocol"
require "csproto"
require("version")
require("debug")

require("actorevent.actorevent")

require("base.engineevent.engineevent")
require("base.engineevent.gametimer")
require("base.engineevent.gamestartevent")
require("base.scripttimer.supertimer")

require("actordata.offlinedatamgr")

require("crossserver.csmsgdispatcher")
require("crossserver.crossnet")
require("crossserver.csbase")
--require("crossserver.cscheck")

require("utils.log")
require("utils.utils")
require("utils.net.netmsgdispatcher")
require("utils.serverroute")
require("utils.net.dbretdispatcher")
require("utils.net.httpclient")
require("utils.thread.asyncworkerfunc")

require("utils.net.datapack")
--require("utils.net.execsql")
require("utils.plus.export_G")
require("utils.actorfunc")
require("utils.systemfunc")
require("utils.luaex")
require("utils.rankfunc")
require("utils.JSON")

require("systems.hefu.hefuevent")
require "systems.hefu.hefutime"

require("systems.instance.instancesystem")
require "systems.msg.msgsystem"
require "systems.ai.ai_action"

require "systems.gm.gmsystem"
require "systems.gm.gmdccmdhandler"
require "systems.actor.actorlogin"
require "systems.actor.actorlogout"
require "systems.actor.actoritem"
require "systems.actor.actorcommon"
require "systems.actor.actoreventhandle"
require "systems.actor.item"
require "systems.actor.actorexp"
require "systems.actor.actorrole"
require "systems.actor.asynevent"
require "systems.actor.compatmoney"

require "systems.vip.actorvip"
require "systems.vip.sviplimitgift"

require "systems.sdkapi.sdkapi"
require "systems.platform.weixiguanzhu"
require "systems.platform.identitycertification"
require "systems.platform.fangchenmi"

require "systems.miscs.clientconfig"

require "systems.drop.drop"
require "systems.notice.noticesystem"

require "systems.mail.mailsystem"
require "systems.mail.offlinemail"
require "systems.recharge.rechargesystem"
require "systems.recharge.firstchargeactive"
require "systems.recharge.monthcard"
require "systems.recharge.chongzhi1"
require "systems.recharge.privilege"

require "systems.fuben.staticfuben.guajifuben"
require "systems.fuben.staticfuben.crosshelpcustom"
require "systems.fuben.staticfuben.mainscenefuben"
require "systems.fuben.staticfuben.lianfumainfuben"
require "systems.fuben.staticfuben.staticfuben"
require "systems.monster.monsterdrop"
require "systems.starsoul.starsoul"
require "systems.equip.equipsystem"
require "systems.equip.enhancesystem"
require "systems.equip.appendsystem"
require "systems.equip.culturesystem"
require "systems.equip.suitsystem"
require "systems.equip.stonesystem"


require "systems.fuben.wanmofuben"
require "systems.fuben.heianpata"
require "systems.fuben.despairboss"
require "systems.fuben.despairguide"
require "systems.fuben.devilsquare"
require "systems.fuben.xuese"
require "systems.fuben.shilianboss"
require "systems.fuben.dailyfuben"
require "systems.fuben.bosshome"
require "systems.fuben.fort"
require "systems.task.taskevent"
require "systems.task.taskcommon"
require "systems.task.taskacceptaction"
require "systems.task.maintask"
require "systems.task.liliansystem"
--require "systems.task.looptask"
require "systems.task.agreementtask"
require 'systems.task.adventure'
require "systems.fuben.adventurepk"
require "systems.chat.chatcommon"
require "systems.chat.worldchat"
require "systems.chat.scenechat"
require "systems.chat.crosschat"
require "systems.damon.damonsystem"
require "systems.yongbing.yongbingsystem"
require "systems.shenmo.shenmosystem"
require "systems.element.elementsystem"
require "systems.fruit.fruitsystem"
require "systems.store.storesystem"
require "systems.yongzhe.yongzhesystem"

require "systems.guild.guildsystem"
require "systems.guild.guildcross"

require "systems.activity.activitylogin"
require "systems.activity.subactivitymgr"
require "systems.activity.subactivity1"
require "systems.activity.subactivity2"
require "systems.activity.subactivity3"
require "systems.activity.subactivity4"
require "systems.activity.subactivity5"
require "systems.activity.subactivity6"
-- require "systems.activity.subactivity7"
-- require "systems.activity.subactivity8"
require "systems.activity.subactivity9"
require "systems.activity.subactivity10"
require "systems.activity.subactivity11"
require "systems.activity.subactivity12"
require "systems.activity.subactivity13"
require "systems.activity.subactivity14"
require "systems.activity.subactivity15"
require "systems.activity.subactivity16"
require "systems.activity.subactivity17"
require "systems.activity.subactivity18"
require "systems.activity.subactivity19"
require "systems.activity.subactivity20"
require "systems.activity.subactivity21"
require "systems.activity.subactivity22"
require "systems.activity.subactivity23"
require "systems.activity.subactivity24"
require "systems.activity.subactivity25"
require "systems.activity.subactivity26"
require "systems.activity.subactivity27"
require "systems.activity.subactivity28"
require "systems.activity.subactivity30"
require "systems.activity.subactivity31"
require "systems.activity.subactivity32"
require "systems.activity.subactivity33"
require "systems.activity.subactivity34"
require "systems.activity.subactivity35"
require "systems.activity.subactivity36"
require "systems.activity.subactivity37"
require "systems.activity.subactivity38"
require "systems.activity.subactivity39"
require "systems.activity.subactivity40"
require "systems.activity.subactivity41"
require "systems.activity.activitymgr"
require "systems.title.titlesystem"
require "systems.title.addtitlelogic"

require "systems.worship.worship"

require "systems.giftcode.giftcode"

require("systems.friend.friendmgr")
require("systems.friend.friendsystem")

require "systems.changename.changename"
require "systems.new.newsystem"
require "systems.new.waysystem"
require "systems.new.remindsystem"
require "systems.new.nextdaysystem"

require "systems.jjc.jjc"
require "systems.jjc.jjcrank"

require "systems.archangel.archangel"
require "systems.slim.slim"

require "systems.actor.actorversion"

require "systems.mine.minesystem"
require "systems.mine.minecross"
require "systems.tianti.tianti"
require "systems.tianti.tiantirank"
require "systems.tianti.tianticross"

require 'systems.fuben.cross.shenmoboss'
require 'systems.fuben.cross.shenmobosscross'

require 'systems.fuben.cross.molong'

require "systems.csbosshome.crossbosshomefb"
require "systems.csbosshome.crossbosshomesys"

require "systems.signin.dailysignin"
require "systems.signin.dailyonline"
require "systems.signin.dailylogin"
require "systems.guild.guildsiege"

require "systems.zhuangban.touxiansystem"
require "systems.fuben.fubencommon"

require "systems.skill.passiveskill"
require "systems.feed.shenqisystem"
require "systems.feed.wingsystem"
require "systems.feed.meilinsystem"
require "systems.feed.shenzhuangsystem"
require "systems.skill.aoyisystem"

require "systems.equip.dazaosystem"
require "systems.actor.shengwusystem"
require "systems.skill.hunqisystem"
require "systems.zhuansheng.zhuansheng"

require "systems.rechargepower.dragonsystem"
require "systems.rechargepower.zlxzsystem"
require "systems.rechargepower.grailsystem"

require "systems.recharge.yymssystem"
require "systems.recharge.yyms2system"
require "systems.recharge.svipmssystem"

require "systems.xunbao.xunbaosystem"
require "systems.jinzhuan.jinzhuansystem"

require "systems.recharge.invest"
require "systems.jinzhuan.zerobuy"
require "systems.recharge.yyqgsystem"

require "systems.foot.footsystem"

require "systems.dart.dartcross"
require "systems.dart.dartsystem"
require "systems.dart.dartrank"
require "systems.dart.dartfight"

require 'systems.fuben.cross.shenghun'

require 'systems.fuben.yongzhefuben'
require "systems.shengling.shenglingsystem"
require "systems.shenyou.shenyousystem"

require "systems.guild.guildbattlesystem"
require "systems.guild.guildbattlecross"
require "systems.guild.guildbattleapply"
require "systems.guild.guildbattle"

require "systems.equip.tianmosystem"
require "systems.equip.angelshieldsystem"

require "systems.equip.shenpansystem"
require "systems.equip.enchantsystem"
require "systems.equip.purifysystem"

require "systems.fuben.relic"

require "systems.fuben.cross.guzhanchang"
require "systems.fuben.cross.guzhanchangrefresh"
require "systems.fuben.cross.kalima"
require "systems.fuben.cross.quainton"
require "systems.fuben.cross.zhuzai"
require "systems.fuben.cross.brave"

require "systems.wechat.wechatsystem"
require "systems.wechat.wechatshare"
require "systems.wechat.wechatcollect"
require "systems.wechat.wechategg"
require "systems.wechat.wechattask"
require "systems.wechat.wechatrank"

require "systems.shenmo.smequipsystem"
require "systems.shenmo.smzlsystem"

require "systems.fuben.cross.dark"
require "systems.fuben.cross.darkcross"

require "systems.warcraft.warcraftsystem"
require "systems.fuben.cross.monstersiege"

require "systems.fuben.campbattle.campbattle"
require "systems.fuben.campbattle.campbattleteam"
require "systems.fuben.campbattle.campbattlefuben"
require "systems.fuben.campbattle.campbattlerank"
require "systems.fuben.campbattle.campbattlesystem"
require "systems.fuben.molian"
require "systems.old.secretsystem"

require "systems.shenshou.shenshousystem"
require "systems.shenshou.shenshouwork"

require "systems.old.shenyusystem"
require "systems.fuben.cross.holyland"

require "systems.old.neigua"

require "systems.fuben.hefucup.hefucuprank"
require "systems.fuben.hefucup.hefucupsystem"

require "systems.equip.godequipsystem"
require "systems.equip.godwakesystem"

require "systems.yuansu.yuansusystem"
require "systems.fuben.cross.yuansufuben"

require "systems.zhenhong.zhenhongsystem"
require "systems.zhenhong.zhenhongfuben"
require "systems.zhenhong.zhenhongrank"
require "systems.zhenhong.zhenhongtask"

require "systems.zhanqu.contest.contest"
require "systems.zhanqu.contest.contestfuben"
require "systems.zhanqu.contest.contestrank"
require "systems.zhanqu.contest.scorefuben"

require "systems.lingqi.lingqisystem"
require "systems.fuben.cross.lingqi"

require "systems.zhanqu.langhun.langhun"
require "systems.zhanqu.langhun.langhuntask"
require "systems.zhanqu.langhun.langhunrank"

require "systems.dashi.dashisystem"

require "systems.zhanqu.tianxuan.tianxuan"
require "systems.zhanqu.tianxuan.tianxuanfuben"
require "systems.zhanqu.tianxuan.tianxuanrank"

require "systems.huanshou.huanshousystem"
require "systems.fuben.huanshoufuben"
require "systems.recharge.halosystem"

require "systems.fuben.cross.huanshoucrossfuben"

require "systems.shenjizhihun.sjzhsystem"
require "systems.fuben.cross.shenjifuben"
require "systems.actor.report"



--Teste
--require "systems.zhuangban.zhuangbansystem"




-- require "systems.zhanqu.champion.champion"
-- require "systems.zhanqu.champion.championfuben"
-- require "systems.zhanqu.champion.championrank"
-- require "systems.zhanqu.champion.championtask"
