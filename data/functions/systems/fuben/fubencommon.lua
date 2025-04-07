module("fubencommon",package.seeall)

--副本组
xuese = 10007
devilsquare = 10004
despireboss = 10008
jjc = 10013
shenghun = 10038
molong = 10039

-- =0--主城
-- =10001--古战场
-- =10002--经验副本
gold =10003--金币副本
devilsquare = 10004--恶魔广场
-- =10005--万魔爬塔
-- =10006--黑暗爬塔
xuese = 10007--血色城堡
despireboss = 10008--全民BOSS
-- =10010--试炼BOSS
-- =10011--黄金部队
-- =10012--魔晶副本
jjc = 10013--竞技场
-- =10015--魔阵副本
-- =10017--装备副本
-- =10018--守关BOSS
-- =10019--战盟BOSS
-- =10020--赤色要塞
-- =10021--怪物攻城
-- =10022--怪物攻城
bosshome = 10023--BOSS之家
kalima = 10024--卡利玛神庙
quaintonboss = 10025--灵王神殿
molian =10026--魔炼之地
zhuzai =10028--世界BOSS
mine =10029--水晶魔谷
-- =10030--水晶魔谷
-- =10031--王者争霸
-- =10032--天使圣域
-- =10033--勇者大陆
-- =10034--恶魔岛
-- =10035--铸造副本
-- =10036--跨服BOSS
-- =10050--峡谷大门
-- =10051--罗兰争霸可pk图
-- =10040--勇气试炼
shenghun=10038--圣魂神殿
molong=10039--魔龙之城
-- =10041--跨服竞技场
-- =10042--神魔圣殿
talent =10043 --天赋副本
damon =10044 --精灵副本
yongbing = 10045 --佣兵副本
shenmo = 10046 --神魔副本
shenqi = 10047 --神魔副本
wing = 10048    --翅膀副本
shenzhuang = 10049 --神装副本
meilin = 10052 --梅林副本
adventure = 10055 --奇遇 的上古遗迹

--每日副本在时间到时显示胜利
function isShowWin(group)
    return group == gold or group == talent or
    group == damon or
    group == yongbing or
    group == shenmo or
    group == shenqi or
    group == shenzhuang or
    group == meilin or
    group == adventure
end

