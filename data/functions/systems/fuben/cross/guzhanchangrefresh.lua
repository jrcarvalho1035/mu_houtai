
--古战场刷怪
module("guzhanchangrefresh", package.seeall)
require("scene.guzhanchangmonster")

function init(ins)
	local sceneHandle = ins.scene_list[1]
	for mon_id, conf in pairs(GuzhanchangMonsterConfig) do
		for k, pos in pairs(conf.position) do
			ins:insCreateMonster(sceneHandle, conf.monster, pos.x, pos.y)
		end
	end
end

function refreshMonsters(_, ins, mon_id)
	local conf = GuzhanchangMonsterConfig[mon_id]
	if not conf then return end
	local sceneHandle = ins.scene_list[1]
	for k, pos in pairs(conf.position) do
		ins:insCreateMonster(sceneHandle, conf.monster, pos.x, pos.y)
	end
end

function onMonsterDie(ins, mon, killer_hdl)
	local mon_id = Fuben.getMonsterId(mon)
	local conf = GuzhanchangMonsterConfig[mon_id]
	if not conf then return end
	local sceneHdl = LActor.getSceneHandle(mon)
	local remaincount = Fuben.isKillAllMonster(sceneHdl, mon_id)
	if remaincount == 0 then --这团怪被灭，刷下一团怪
		LActor.postScriptEventLite(nil, conf.refreshTime * 1000, refreshMonsters, ins, mon_id)
	end
end
