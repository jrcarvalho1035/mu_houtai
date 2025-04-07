package.path = package.path .. ";./?.lua;./data/config/?.lua;./data/functions/?.lua"

thisNPC = nil

InitFnTable = {}
FinaFnTable = {}
MainFnTable = {}

print("load global function begin")
--配置
require "data.functions.gameconfig"
-- 系统
require "systems"
-- 每次读入全局脚本都输出下日志
print("load global function end")

math.randomseed(os.time())

function main(sysarg)

end

function openServerTime(sysarg, year, mon, day, hour, m)
	System.setOpenServerTime(year, mon, day, hour, m)
end

--[[初始化函数]]--
function initialization(npcobj)
	thisNPC = npcobj

	--只有真实的才load
	if not _G.lianfuLoaded and thisNPC == System.getGlobalNpc() then
		_G.lianfuLoaded = true
		-- loadLianfuConfig() ####
	end

	for i = 1, #InitFnTable do
		--print("initialization..table.getn="..table.getn(InitFnTable))
		InitFnTable[i]( npcobj )
	end

	InitFnTable = nil
end

--[[析构化函数]]--
function finalization(npcobj)
	for i = 1, table.getn(FinaFnTable) do
		FinaFnTable[i]( npcobj )
	end
	thisNPC = nil
end

if System.isWin() then
	table.insert(InitFnTable, function()
		require("systems.gm.luacheckfile").init()
	end)
end
