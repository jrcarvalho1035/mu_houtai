--配置总文件 @rancho 20170410
------------------------------------------------
require "data.config.lang"
require "data.config.lang3"
require "data.functions.globaldefine"
require "data.config.globalconfig"
require "data.dataconfig"
require "data.config.globalconfig"


--提示
require "scripttips"
require "scriptcontent"

--跨服
require "crossserver.crossserverconfig"

--聊天
require "chat.chatconst"
require "chat.chatlevel"
require "chat.mapchatlevel"

--商城
require "store.storeitem"
require "store.storehonor"
require "store.limitstore"
require "store.svipstore"
require "store.bossstore"
require "store.starstore"
require "store.crownstore"
require "store.dartstore"
require "store.yongzhetore"
require "store.storecamp"
require "store.storehfcup"
require "store.storezhanqu"

--公会
require "guild.guildlevel"
require "guild.guilddonate"
require "guild.guildcommonskill"
require "guild.guildpracticeskill"
require "guild.guildstore"
require "guild.guildstorelevel"
require "guild.guildcreate"

require "scene.fubengroupconfig"

--公会活动
--require "guild.guildactivity"

--月卡
require "monthcard.monthcardconfig"

--试炼
require("scene.shilianboss")
require("scene.shiliancommon")

--刷怪
require("scene.refreshmonsters")

--好友
require("friend.friendlimit")

require("guaji.guajifuben")
require("guaji.world_map")
require("guaji.guajicconst")

require("equip.equipconst")
require("equip.equipindex")

require("scene.fubengroupalias")

require("lilian.liliantask")
require("lilian.junxianlevel")
require("lilian.junxiandaily")
--特权卡
require("monthcard.privilegeconfig")

--每日签到
require("signin.dailysign")
require("signin.totalsign")
require("signin.dailyonline")
require ("signin.dailyonlineseven")

--精灵
require("damon.damonlevel")
require("damon.damonconst")
require("damon.damonmozhenbase")
require("damon.damonpill")
require("damon.damonstage")
require("damon.damonpillmax")

--守护
require("yongbing.yongbinglevel")
require("yongbing.yongbingconst")
require("yongbing.yongbingmozhenbase")
require("yongbing.yongbingpill")
require("yongbing.yongbingstage")
require("yongbing.yongbingpillmax")

--神魔
require("shenmo.shenmolevel")
require("shenmo.shenmoconst")
require("shenmo.shenmopill")
require("shenmo.shenmostage")
require("shenmo.shenmopillmax")

--战盟入侵
require("scene.guildsiegecommon")
require("scene.guildsiegefuben")
require("scene.guildsiegerefresh")

require("actor.worldlevel")

--天使圣盾
require("shengdun.shengdunlv")
require("shengdun.shengdunskill")
require("shengdun.upitem")
require("shengdun.shengdundan")
require("shengdun.shengdunstage")

require("server.servername")

--改名卡
require("changename.changenamecardconf")

require("scene.despairbossrobot")
require("scene.despairbossdrop")

--召集战盟
require("task.guildconvenetask")


--果实系统
require("fruit.fruitconfig")
require("fruit.fruittypeconfig")

--魔戒系统
require "starsoul.starsoul_common"
require "starsoul.starsoul_level"
require "starsoul.starsoul_stage"

--神器系统
require "feed.shenqipill"
require "feed.shenqipillmax"
require "feed.shenqiconst"
require "feed.shenqilevel"

--翅膀系统
require "feed.wingpill"
require "feed.wingpillmax"
require "feed.wingconst"
require "feed.winglevel"

--梅林系统
require "feed.meilinpill"
require "feed.meilinpillmax"
require "feed.meilinconst"
require "feed.meilinlevel"

--神装系统
require "feed.szpill"
require "feed.szpillmax"
require "feed.szconst"
require "feed.szlevel"

require "skill.skillpassive"

require "dazao.dazaofenjie"
require "dazao.dazaoringstar"
require "dazao.dazaoringstage"
require "dazao.dazaoysequipcost"

require "shengwu.shengwu"
require "shengwu.shengwufragment"

require "hunqi.hunqilevel"
require "hunqi.hunqiawake"
require "hunqi.hunqiid"
require "hunqi.hunqiquality"
require "item.lianjin"
require "item.smeltdata"
require 'item.fenjiedata'

--强化
require "equip.enhanceattr"
require "equip.enhancecost"
require "equip.enhanceadddaren"
require "equip.enhanceadddashi"

require "equip.suit"
--装备追加
require "equip.appendattr"
require "equip.appendyuanshi"
require "equip.appendcost"

require "zhuansheng.zhuanshenglevel"
require "zhuansheng.chongshenglevel"
require "task.zhuanshengtask"
require "task.touxiantask"
require "touxian.touxian"
require "scene.fubenconst"
require "task.agreement"
require "task.agreementtype"

require "element.elementbaseconfig"
require "element.elementlevelconfig"
require "element.elementlockposconfig"
require "element.elementlibraryconfig"
require "element.elementotherconfig"

require "rechargepower.zhaocailong"
require "rechargepower.zlxz"
require "rechargepower.grailstone"
require "rechargepower.rechargepowerconst"

require "skill.aoyi"

require "recharge.yyms"
require "recharge.yyms2"
require "recharge.svipms"

require "xunbao.xunbaoconst"
require "xunbao.xunbaoequip"
require "xunbao.xunbaohunqi"
require "xunbao.xunbaoElement"
require "xunbao.xunbaoDianfeng"
require "xunbao.xunbaoZhizhun"
require "xunbao.xunbaolingqi"
require "xunbao.xunbaoexchange"

require "shenmo.shenmohuanhuabase"
require "shenmo.shenmomozhenbase"
require "yongbing.yongbinghuanhuabase"
require "feed.winghuanhuabase"
require "feed.meilinhuanhuabase"
require "feed.shenqihuanhuabase"
require "feed.szhuanhuabase"
require "damon.damonhuanhuabase"

require "scene.dailyfuben"
require "scene.basedailyfuben"
require "jinzhuan.jinzhuanconst"
require "jinzhuan.jinzhuansecret"
require "jinzhuan.jinzhuanxunbao"
require "jinzhuan.jinzhuanzhufu"
require "recharge.logininvest"
require "recharge.custominvest"
require "recharge.levelinvest"
require "recharge.rechargeconst"

require "jinzhuan.zerobuy"
require "vip.limitgift"
require "vip.svip"
require "vip.vip"

require "loginrewards.logingift"

require "rank.worship"
require "rank.rankcommon"

require 'scene.shenmofuben'
require 'scene.smfbcommon'

require 'task.adventurecommon'
require 'task.adventureevent'
require 'task.adventuretask'
require 'task.adventureexchange'
require 'task.adventureboss'
require 'task.adventuremon'
require 'task.adventurerobot'
require 'task.adventureevent1'
require 'task.adventureevent6'

require 'scene.molongcommon'
require 'scene.molongfuben'
require 'scene.molonginspire'
require 'scene.molongrobot'

require 'feed.footconst'
require 'feed.footlevel'
require 'feed.footitem'
require 'feed.foothuanhuabase'
require 'feed.footdashi'
require 'feed.footsecret'
require 'feed.footfenjie'

require 'yongzhe.yongzhe'
require 'yongzhe.yongzhelevel'
require 'yongzhe.yongzhereward'
require 'yongzhe.yongzhesaiji'
require 'yongzhe.yongzheseasontask'
require 'yongzhe.yongzhetask'

require 'dart.dartconst'
require 'dart.dartcar'
require 'dart.dartguildrank'
require 'dart.dartpersonrank'
require 'dart.dartcarlevelreward'
require 'dart.dartrobot'
require 'dart.dartjifen'

require("scene.shenghuncommon")
require("scene.shenghunfuben")
require("scene.shenghunnpc")
require("scene.shenghuninspire")
require("scene.shenghunrobot")

require("shengling.shengling")
require("shengling.shenglinglevel")
require("shengling.shenglingstage")
require("shengling.shenglingdashi")
require("shengling.shenglingsuit")
require("shengling.shenglingtag")

require("shenyou.shenyoulevel")
require("shenyou.shenyoubase")
require("shenyou.shenyouhuanhua")
require("shenyou.shenyoustage")
require("shenyou.shenyoutag")
require("shenyou.shenyoutagexp")
require("shenyou.shenyouskill")

require("dropbox.dropboxconst")
require("dropbox.dropbox1")
require("dropbox.dropbox2")

require ("task.act15task")

require ("guild.gbconst")
require ("guild.gbmanorindex")
require ("guild.gbmanor")
require ("guild.gbguess")
require ("guild.gbinspire")
require ("guild.gbselfpower")
require ("guild.mutlikill")
require ("guild.gbeffect")
require ("guild.gbrefreshmonster")
require ("guild.gbrankreward")
require ("guild.gbdabiaoreward")

require ("item.talisman")

require("wechat.wechatconst")
require("wechat.wechategg")
require("wechat.wechattask")
require("wechat.wechatrank")

require("equip.purifyattr")
require("equip.purifydaren")
require("equip.purifydashi")

require("diablo.diabloconst")
require("diablo.smspiritstar")
require("diablo.smspiritstage")
require("diablo.smspiritpill")
require("diablo.smsecret")
require("diablo.smsecretbox")
require("diablo.shenmoequip")
require("diablo.shenmoequipadd")
require("diablo.shenmoequipattr")
require("diablo.diablowake")

require 'scene.darkfuben'
require 'scene.darkcommon'

require 'warcraft.wclevel'
require 'warcraft.wcdashi'
require 'warcraft.wcstage'
require 'warcraft.wcquality'

require 'monstersiege.mscommon'
require 'monstersiege.msscore'
require 'monstersiege.msrank'
require 'monstersiege.msmonster'
require 'monstersiege.mshurtrank'
require 'monstersiege.msdabiao'

require 'campbattle.campbattlecommon'
require 'campbattle.campbattlefuben'
require 'campbattle.campbattlescorereward'
require 'campbattle.campbattledailyreward'
require 'campbattle.campbattleselfrank'
require 'campbattle.campbattlegodrank'
require 'campbattle.campbattledevilrank'
require 'campbattle.campbattlerobot'
require 'campbattle.campbattleseason'


require 'scene.moliancommon'
require 'scene.molianfuben'

require 'secret.secret'
require 'secret.secretstar'
require 'secret.secretcommon'

require 'shenshou.shenshoudata'
require 'shenshou.shenshouattr'
require 'shenshou.shenshoulevel'
require 'shenshou.shenshouformation'
require 'shenshou.shenshoulottery'
require 'shenshou.shenshoushop'
require 'shenshou.shenshousignet'
require 'shenshou.shenshouworktimes'
require 'shenshou.shenshoucommon'

require "neigua.neiguaconst"
require "neigua.guajizhushou"

require 'hefucup.hefucupcommon'
require 'hefucup.hefucupfuben'
require 'hefucup.hefucupstage'
require 'hefucup.hefucuprankreward'
require 'hefucup.hefucuprank'
require 'hefucup.hefucupleseason'

require 'yuansu.yuansu'
require 'yuansu.yuansulevel'
require 'yuansu.yuansustage'
require 'yuansu.ysequip'
require 'yuansu.ysequipsuit'
require 'yuansu.ysfulingslot'
require 'yuansu.ysfuling'
require 'yuansu.ysskillgroup'

require 'scene.ysfbcommon'
require 'scene.yuansufuben'
require 'scene.yuansuboss'

require 'zhenhong.zhcommon'
require 'zhenhong.zhslot'
require 'zhenhong.zhlevel'
require 'zhenhong.zhstage'
require 'zhenhong.zhsuitlevel'
require 'zhenhong.zhsuitattr'
require 'zhenhong.zhyjsuit'
require 'zhenhong.zhbtsuit'
require 'zhenhong.zhlimitgift'

require "scene.zhfbcommon"
require "scene.zhsummon"
require "scene.zhboss"
require "scene.zhsummonrank"
require "scene.zhkillrank"
require "task.zhenhongtask"

require "contest.contestcommon"
require "contest.scorefuben"
require "contest.contestfuben"
require "contest.contestscorerank"
require "contest.contestchallengerrank"
require "contest.conteststage"

require "lingqi.lingqibase"
require "lingqi.lingqiconsume"
require "lingqi.lingqilevel"
require "lingqi.lingqipill"
require "lingqi.lingqipillmax"

require 'scene.lingqicommon'
require 'scene.lingqifuben'
require 'scene.lingqiinspire'
require 'scene.lingqirobot'

require "langhun.langhuncommon"
require "langhun.langhunfuben"
require "langhun.langhunkill"
require "langhun.langhundie"
require "langhun.langhunexchange"
require "langhun.langhunrank"
require "langhun.langhunmonster"
require "langhun.langhundbtask"
require "langhun.langhuncjtask"

require "task.act39task"

require "dashi.dashilevel"
require "dashi.dashitaskgroup"
require "dashi.dashistage"
require "dashi.dashifuben"
require "task.dashitask"

require "tianxuan.tianxuancommon"
require "tianxuan.tianxuanteam"
require "tianxuan.tianxuannotice"
require "tianxuan.tianxuanmonster"
require "tianxuan.tianxuandie"
require "tianxuan.tianxuanfuben"
require "tianxuan.tianxuandailyreward"
require "tianxuan.tianxuanrank"

require "dazao.dazaohuanshouequip"
require "huanshou.huanshouconst"
require "huanshou.huanshoubase"
require "huanshou.huanshouequip"
require "huanshou.huanshoucommonskill"
require "huanshou.huanshouwakeskill"

require "scene.huanshoubosscommon"
require "scene.huanshousinglefuben"
require "scene.huanshousingleboss"
require 'scene.huanshoucrossfuben'
require 'scene.huanshoucrossboss'
require 'scene.huanshoucrystalgather'
require 'scene.huanshoustonegather'

require "monthcard.haloconfig"

require "shenjizhihun.shenjizhihun"
require "shenjizhihun.sjzhstage"
require "shenjizhihun.sjzhslotcost"
require "shenjizhihun.sjzhexchangecost"
require "dazao.dazaosjzhequipcost"

require 'scene.sjfbcommon'
require 'scene.shenjifuben'
require 'scene.shenjiboss'

-- require "champion.championcommon"
-- require "champion.championdamgereward"
-- require "champion.championgame"
-- require "champion.championbet"
-- require "champion.championmonster"
-- require "champion.championbuff"
-- require "champion.championscorerank"
-- require "champion.championteamrank"
-- require "champion.championcjtask"
-- require "champion.championstage"
