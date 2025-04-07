module("speclogin", package.seeall)


--测试期间充值用户更可在不删档测试时获得300%的钻石返还【尊享特权】，公测领跑，快人一步，

FILENAME="../../tuhao"
TUHAO_DATA = TUHAO_DATA or {}

-- 加载数据
local function loadDataByName(fileName)
	local file = io.open(fileName, "r")
	if file ~= nil then
		local s = file:read("*a")
		local data, err = utils.unserialize(s)
		file:close()
		print(string.format("load %s over", fileName))
		return data, err
	end
	print(string.format("file %s not exist", fileName))
	return {}
end

-- 保存数据
local function saveData(fileName, data)
	if not data then
		print(string.format("save %s err data is nil", fileName))
		return
	end
	local bt = 0	
	local et = 0
	bt = os.clock()
	local s = utils.serialize(data)
	local file = io.open(fileName, "w")
	file:write(s)
	file:close()
	et = os.clock()

	print(string.format("save %s over, cost time:%f", fileName, (et-bt)))
end

function loadData()
	if true then return end
	TUHAO_DATA, err = loadDataByName(FILENAME)
	if TUHAO_DATA == nil or err then
		print("load tuhao fileName:" .. FILENAME .. " err:" .. err)
		assert(false)
	end
end

function onLogin(actor)
	if true then return end
	local accountname = LActor.getAccountName(actor)
	if not TUHAO_DATA[accountname] then
		return
	end
	if TUHAO_DATA[accountname].isuse and TUHAO_DATA[accountname].isuse == 1 then
		return
	end
	loadData()
	if TUHAO_DATA[accountname].isuse and TUHAO_DATA[accountname].isuse == 1 then
		return
	end
	TUHAO_DATA[accountname].isuse = 1
	saveData(FILENAME, TUHAO_DATA)
	sendmail(actor, TUHAO_DATA[accountname].yuanbao)
end

function sendmail(actor, yuanbao)
	local actorid = LActor.getActorId(actor)
	local mail_data = {}
	mail_data.head       = "尊享特权"
	mail_data.context    = "恭喜您在测试服参与充值，三倍返还钻石给您"
	mail_data.tAwardList = {{id = NumericType_YuanBao, count = yuanbao * 3}}
	mailsystem.sendMailById(actorid, mail_data)
end


actorevent.reg(aeUserLogin, onLogin)


engineevent.regGameStartEvent(loadData)
