require "data.config.globalconfig"


local NOERR				= 0			--正确
local ERR_SQL			= -1		--sql错误
local ERR_SESS			= -2		--用户没登陆
local ERR_GAMESER		= -3		--游戏服务没准备好
local ERR_DATASAVE		= -4		--角色上一次保存数据是否出现异常
local ERR_SELACTOR		= -5		--客户端选择角色的常规错误
local ERR_SAMENAME		= -6		--角色名称重复
local ERR_NOUSER		= -7		--角色不存在
local ERR_SEX			= -8		--错误的性别
local ERR_NORANDOMNAME	= -9		--随机生成的名字已经分配完
local ERR_ZY			= -10		--客户端上传的角色阵营参数错误
local ERR_JOB			= -11		--客户端上传的角色职业参数错误
local ERR_NAME			= -12		--名称无效，名称中包含非法字符或长度不合法
local ERR_GUID			= -13     	--如果玩家是帮主，不能删除该角色，需要玩家退帮
local ERR_CROSSWAR		= -14		-- 已经登陆到其他服务器
local ERR_MAXACTOR		= -15		--已经超过最大可建角色数量
local ERR_FANGCHEMI		= -16		--防沉迷到期
local ERR_HAVEACOTR		= -17		--已创角

local cLoginKey = 1
local sLoginKey = 1

local cCreateActor = 2 --创建角色
local sCreateActor = 2 --创建角色
local cDelete = 3
local sDelete = 3
local cQueryList = 4
local sQueryList = 4
local cEnterGame = 5
local sEnterGame = 5
local cRandName = 6	--自动生成名
local sRandName = 6
local cLessJob = 7		--查询最少人使用的职
local sLessJob = 7
local cLessCamp = 8		--查询最少人使用的阵
local sLessCamp = 8
local cCreateActorEx = 10	--创建角色（自生成名字）

require("data.config.server.servername")


function getServerNameBySId(serverid)
	return ServerNameConf[serverid] and "S"..ServerNameConf[serverid].name or ""
end

-- 当用户查询角色列表的时候触发
function onQueryActorList(accountname, sid, loginip, pfid, isNewAccount)
	local updateactorlogin = "call updateactorlogin('%s', %d)";

	if accountname == nil then return end
	local db = LActorMgr.getDbConn()
	if db == nil then return end
	local sql = string.format(updateactorlogin, accountname, sid)
	local err = System.dbQuery(db, sql)
	if err ~= 0 then
		print("sql query error:"..sql)
		return
	end
	local row = System.dbCurrentRow(db)
	row = System.dbGetRow(row, 0)
	local ret = tonumber(row)	
	System.dbResetQuery(db)
	if ret == 0 then
		System.logInstall(accountname, "", " ", pfid, "pre_role_choice", isNewAccount)
		System.logDau(accountname, "", "", "", "", "", loginip or "")
	elseif ret == 2 then
		System.logDau(accountname, "", "", "", "", "", loginip or "")
	end
end

function queryLessJobDb(serverid)
	-- local getlessjob = "call getlessjob(%d)"
	-- local db = LActorMgr.getDbConn()
	-- local sql = string.format(getlessjob, serverid)
	-- local err = System.dbQuery(db, sql)
	-- if err ~= 0 then
	-- 	return -1
	-- end 
	-- local row = System.dbCurrentRow(db)
	-- local job = 0
	-- if row == nil then
	-- 	job = 2
	-- else
	-- 	job = tonumber(System.dbGetRow(row, 0))
	-- end
	-- System.dbResetQuery(db)

	-- return 0, job
	return 0, 0
end

function queryActorCount( accountid, serverid )
	local ret = 0
	local db = LActorMgr.getDbConn()
	local sql = string.format("select count(*) from actors where accountid=%d and serverindex=%d", accountid, serverid)
	local err = System.dbQuery(db, sql)
	if err ~= 0 then
		return 0
	end 

	local row = System.dbCurrentRow(db)
	if row == nil then
		ret = 2
	else
		ret = tonumber(System.dbGetRow(row, 0))
	end
	System.dbResetQuery(db)
	return ret
end

function queryZyList(serverid)
	local ret = 7
	local db = LActorMgr.getDbConn()
	local sql = string.format("call queryzylist(%d)", serverid)
	local err = System.dbQuery(db, sql)
	if err ~= 0 then
		return ret
	end
	local row = System.dbCurrentRow(db)
	if row ~= nil then
		for i=0,2 do
			local t = tonumber(System.dbGetRow(row, i))
			if t == 0 then
				local tmp = System.bitOpRig(1, i)
				tmp = System.bitOpNot(tmp)
				ret = System.bitOpAnd(ret, tmp)
			end
		end
	end
	System.dbResetQuery(db)
	return ret
end

function queryDbZY(serverid)
	local camp = 1
	local db = LActorMgr.getDbConn()
	local sql = string.format("select zy from zycount where serverindex=%d order by usercount asc limit 1", serverid)
	local err = System.dbQuery(db, sql)
	if err ~= 0 then
		return -1, 0
	end
	local row = System.dbCurrentRow(db)
	if row ~= nil then
		camp = tonumber(System.dbGetRow(row, 0))
	end
	System.dbResetQuery(db)
	return 0,camp
end

function queryActorList(dp, serverid, accountid, accountname, actorid, netid, loginip)
	if (accountid == 0) then
		print("user has not login, recv a query request")
		return
	end

	-- 后面的status不是特别清楚做什么，旧代码里还调用了查询角色数量的语句没有判断status的
	local selectActorSql = "select `actorid`,`actorname`,`job`,`level`,`totalpower`,`vip_level`,`createtime` from actors where accountname='%s' and serverindex=%d;"--and (status & 2)=2;" 
	local sql = string.format(selectActorSql, accountname, serverid)
	local db = LActorMgr.getDbConn()
	local err = System.dbQuery(db, sql)
	local senddp = LActorMgr.getDataPacket()
	LDataPack.writeByte(senddp, 255)
	LDataPack.writeByte(senddp, sQueryList)
	LDataPack.writeInt(senddp, accountid)

	if err ~= 0 then
		LDataPack.writeChar(senddp, -1)
		LDataPack.writeChar(senddp, 0)
		LActorMgr.SendToGate(netid, senddp)
		return
	end


	local count = System.dbGetRowCount(db)
	local row = System.dbCurrentRow(db)
	LDataPack.writeChar(senddp, 0)
	LDataPack.writeChar(senddp, count)
	print("actormgr.queryActorList: count:" .. count)
	for i=1, count do
		LDataPack.writeInt(senddp, tonumber(System.dbGetRow(row, 0)))
		LDataPack.writeString(senddp, System.dbGetRow(row, 1))
		LDataPack.writeInt(senddp, tonumber(System.dbGetRow(row, 2)))
		LDataPack.writeInt(senddp, tonumber(System.dbGetRow(row, 3)))
		LDataPack.writeDouble(senddp, tonumber(System.dbGetRow(row, 4)))
		LDataPack.writeInt(senddp, tonumber(System.dbGetRow(row, 5)))
		LDataPack.writeString(senddp, System.dbGetRow(row, 6))
		row = System.dbNextRow(db)
	end

	System.dbResetQuery(db)
	LActorMgr.SendToGate(netid, senddp)

	local pf = LDataPack.readString(dp) or "ccc"
	local pfid = LDataPack.readString(dp) or "aa"
	local appid = LDataPack.readString(dp) or "bb"
	local isNewAccount = LDataPack.readByte(dp) or 10
	print(string.format("queryActorList:accountname:%s, pf:%s, pfid:%s, appid:%s, isNewAccount:%d", 
		accountname, pf, pfid, appid, isNewAccount))
	onQueryActorList(accountname, serverid, loginip, pfid, isNewAccount)
end

--创建角色
function createActor(dp, serverid, accountid, accountname, actorid, netid, gateuser, gateIp) --####
	local ret = 0
	local sex, job, icon, camp, pf, pfid, appid, loginIP, isNewAccount
	local name = LDataPack.readString(dp)
	local nameLen = System.getStrLenUtf8(name)
	
	if getServerNameBySId(serverid) == "" then
		print("error create actor serverid = "..serverid)
		assert(false)
	end
	local servername = getServerNameBySId(serverid)..'.'..name

	if nameLen < 4 or nameLen > 12 or not LActorMgr.checkNameStr(name) then
		ret = ERR_NAME
	elseif LActorMgr.nameHasUser(servername) then
		ret = ERR_SAMENAME
	else
		sex = LDataPack.readChar(dp)
		job = LDataPack.readChar(dp)
		icon = LDataPack.readChar(dp)
		LDataPack.readChar(dp) --读取阵营(x6没有，所以读空)
		camp = 0
		pf = LDataPack.readString(dp) or ""
		pfid = LDataPack.readString(dp) or ""
		appid = LDataPack.readString(dp) or ""
		isNewAccount = LDataPack.readByte(dp) or 0

		print("createActor_tx_install_report:" .. (pfid or "") .. "," .. (appid or ""))

		--阵营取消
		-- if (camp == 0) then	--如果是选了随机，则给个最少人选的阵营
		-- 	ret, camp = queryDbZY(serverid)
		-- 	if camp <= 0 or camp >= 4 then
		-- 		camp = System.getRandomNumber(zyMax-1) + 1
		-- 	end
		-- end

		--enVocNone为初始职业(无职业)
		if (job <= JobType_None or job >= JobType_Max) then
			ret = ERR_JOB
		end

		if (sex ~= 0 and sex ~= 1) then
			ret = ERR_SEX
		end
	end
	
	local pfidNum = tonumber(pfid) or 0
	local aid = 0
	if ret == NOERR then
		ret, aid = LActorMgr.createActor(accountid, accountname, name, sex, job, icon, camp, aid, pfidNum, gateuser, servername)
		System.logInstall(accountname, "", " ", pfid, "role_choice", isNewAccount)
	end

	local senddp = LActorMgr.getDataPacket()
	LDataPack.writeByte(senddp, 255)
	LDataPack.writeByte(senddp, sCreateActor)
	LDataPack.writeByte(senddp, ret)
	LDataPack.writeInt(senddp, aid)
	LDataPack.writeString(senddp, name)
	LDataPack.writeUInt(senddp, System.getNowTime())
	LActorMgr.SendToGate(netid, senddp)

	--创角通知php，用来特殊处理测试服玩家
	-- local temStr = "http://%s/%s/cdk?type=2&chid=%s&cdkey=%s"
	-- local url = string.format(temStr, webhost, pf, appid, code)
	-- sendMsgToWeb(url, onResultCheck, {aid, id, code})

	if loginIP == nil then loginIP = "0.0.0.0" end
end


--创建角色(自生成名字)
function createActorEx(dp, serverid, accountid, accountname, actorid, netid, gateuser, gateIp)
	local ret = 0
	local flag = false
	local sex, job, icon, camp, pf, pfid, appid, loginIP, isNewAccount
	local name = LDataPack.readString(dp)
	
	if getServerNameBySId(serverid) == "" then
		print("error create actor serverid = "..serverid)
		assert(false)
	end
	local servername = getServerNameBySId(serverid)..'.'..name

	local nameLen = System.getStrLenUtf8(name)
	if nameLen <= 2 or nameLen > 12 or not LActorMgr.checkNameStr(name) then
		flag = true
	elseif LActorMgr.nameHasUser(servername) then
		flag = true
	end
	
	--如果名字不正确，随机匹配一个正确的名字
	if flag then
		local times = 0
		while times < 10000 do
			name = LActorMgr.getRandomName(1)
			if name == nil then
				ret = ERR_NORANDOMNAME
				break
			end
			local used = LActorMgr.nameHasUser(name)
			if not used then
				local len = System.getStrLenUtf8(name)
				if len <= 0 or len > 6 then-- or not LActorMgr.checkNameStr(name) then
					--continue
				else
					break
				end
			end
			times = times + 1
		end
		if times >= 10000 then
			ret = ERR_NORANDOMNAME
		end
	end
	
	sex = LDataPack.readChar(dp)
	job = LDataPack.readChar(dp)
	icon = LDataPack.readChar(dp)
	LDataPack.readChar(dp) --读取阵营(x6没有，所以读空)
	camp = 0
	pf = LDataPack.readString(dp) or ""
	pfid = LDataPack.readString(dp) or ""
	appid = LDataPack.readString(dp) or ""
	isNewAccount = LDataPack.readByte(dp) or 0

	-- 腾讯开平注册上报
	print("createActor_tx_install_report:" .. (pfid or "") .. "," .. (appid or ""))

	--enVocNone为初始职业(无职业)
	if (job <= JobType_None or job >= JobType_Max) then
		ret = ERR_JOB
	end

	local pfidNum = tonumber(pfid) or 0
	if getServerNameBySId(serverid) == "" then
		print("error create actor serverid = "..serverid)
		assert(false)
	end
	servername = getServerNameBySId(serverid)..'.'..name
	--local pfidNum = tonumber(pfid) or 0
	local aid = 0
	if ret == NOERR then
		ret, aid = LActorMgr.createActor(accountid, accountname, name, sex, job, icon, camp, aid, pfidNum, gateuser, servername)
		System.logInstall(accountname, "", " ", pfid, "role_choice", isNewAccount)
	end
	
	local senddp = LActorMgr.getDataPacket()
	LDataPack.writeByte(senddp, 255)
	LDataPack.writeByte(senddp, sCreateActor)
	LDataPack.writeByte(senddp, ret)
	LDataPack.writeInt(senddp, aid)
	LDataPack.writeString(senddp, name)
	LDataPack.writeUInt(senddp, System.getNowTime())
	LActorMgr.SendToGate(netid, senddp)

	if loginIP == nil then loginIP = "0.0.0.0" end
end

-- 删除角色
function deleteActor(dp, serverid, accountid, accountname, actorid, netid)
	local senddp = LActorMgr.getDataPacket()
	LDataPack.writeByte(senddp, 255)
	LDataPack.writeByte(senddp, sDelete)
	if accountid == 0 then
		LDataPack.writeInt(senddp, 0)
		LDataPack.writeChar(senddp, ERR_SESS)
		LActorMgr.SendToGate(netid, senddp)
		return
	end

	local aid = LDataPack.readInt(dp)
	LDataPack.writeInt(senddp, aid)
	local db = LActorMgr.getDbConn()
	local social_sql = string.format("call getactorssocial(%d)", aid)
	local err = System.dbQuery(db, social_sql)
	if err ~= 0 then
		return -1
	end 
	local row = System.dbCurrentRow(db)
	local social = 0
	if row ~= nil then
		social = tonumber(System.dbGetRow(row, 0))
	end
	System.dbResetQuery(db)
	if  social == smGuildLeader then
		LDataPack.writeChar(senddp, ERR_GUID)
	    LActorMgr.SendToGate(netid, senddp)
		return
	end

	--删除竞技台信息
	local fight_sql = string.format("call delfightinfo(%d)", aid)
	local err = System.dbQuery(db, fight_sql)
	if err ~= 0 then
		return -1
	end

	System.dbResetQuery(db)
	--FightFun.deleteActorData(aid)

	local sql = string.format("call clientdeletecharactor(%d,'%s')", aid, accountname)
	local err = System.dbExe(db, sql)
	if err ~= 0 then
		LDataPack.writeChar(senddp, ERR_SQL)
	else
		LDataPack.writeChar(senddp, 0)
	end
	LActorMgr.SendToGate(netid, senddp)
end

function userSelCharEntryGame(serverid, aid, accountname, accountid, ipstring)
	local db = LActorMgr.getDbConn()
	local sql = string.format("call clientstartplay(%d,%d,'%s',%d,0);",
        serverid, aid, accountname, accountid, ipstring)
	local err = System.dbQuery(db, sql)
	if err == 0 then
		local row = System.dbCurrentRow(db)
		if row ~= nil and tonumber(System.dbGetRow(row, 0)) ~= 0 then
			err = NOERR
		else
			err = ERR_NOUSER
		end
		System.dbResetQuery(db)
	else
		return ERR_SELACTOR
	end
	return err
end

local function updatePfidAndAppIid(serverid, actorid, pfid, appid)
	local db = LActorMgr.getDbConn()
	local sql = string.format("update actors set `appid`='%s',`pfid`='%s' where `actorid`=%d and `serverindex`=%d;",
        appid, pfid, actorid, serverid)
	local err = System.dbQuery(db, sql)
	print(sql)
	if err == 0 then
		System.dbResetQuery(db)
	end
end

function enterGame(cmd, dp, serverid, accountid, accountname, actorid, netid, gateuser, loginip)
	print("actor enterGame:" .. actorid .. " account:" .. accountname)
	local senddp = LActorMgr.getDataPacket()
	LDataPack.writeByte(senddp, 255)
	LDataPack.writeByte(senddp, sEnterGame)
	if accountid == 0 then
		LDataPack.writeByte(senddp, ERR_SESS)
		LActorMgr.SendToGate(netid, senddp)
		return
	end

	actorid = LDataPack.readInt(dp)

	local pf = LDataPack.readString(dp) or ""
	local pfid = LDataPack.readString(dp) or ""
	local appid = LDataPack.readString(dp) or ""
	local isNewAccount = LDataPack.readByte(dp) or 0
	local payid = LDataPack.readString(dp) or ""
	local err = userSelCharEntryGame(serverid, actorid, accountname, accountid)
	LDataPack.writeByte(senddp, err)
	if err ~= 0 then --只在失败时发送协议
		LActorMgr.SendToGate(netid, senddp)
	end

	print("actor enterGame, err:" .. err .. " account:" .. accountname)
	updatePfidAndAppIid(serverid, actorid, pfid or "", appid or "")
	if err == NOERR then
		if System.isBattleSrv() then
			print(string.format("[Lua]enterGame:battle server should never call this (accountid[%d], actorid[%d])", accountid, actorid))
        end
		print("LActorMgr enterGame:" .. actorid .. " account:" .. accountname)
		LActorMgr.enterGame(gateuser, actorid, pf, pfid, appid, serverid, 0, 0, payid)
	end

	if pfid ~= nil then
		if string.sub(pfid, 1, 5) == "union" then
			System.logInstall(accountname, "union", "", pfid, "enter_game", isNewAccount)
		else
			System.logInstall(accountname, pf, "", pfid, "enter_game", isNewAccount)
		end
	else
		System.logInstall(accountname, "", "", pfid, "enter_game", isNewAccount)
	end
	print("enterGame_tx_login_report:" .. pf)
end

function randNameReq(cmd, dp, serverid, accountid, accountname, actorid, netid, gateuser)
	local senddp = LActorMgr.getDataPacket()
	LDataPack.writeByte(senddp, 255)
	LDataPack.writeByte(senddp, sRandName)

	local symbol = LDataPack.readByte(dp) --
	local err = NOERR
	local actorname = ""
	local times = 0
	if accountid == 0 then
		err = ERR_SESS
	else
		while times < 10000 do
			actorname = LActorMgr.getRandomName(1)
			if actorname == nil then
				err = ERR_NORANDOMNAME
				break
			end
			local used = LActorMgr.nameHasUser(actorname)
			if not used then
				local len = System.getStrLenUtf8(actorname)
				if len <= 0 or len > 6 then -- or not LActorMgr.checkNameStr(actorname) then
					--continue
				else
					break
				end
			end
			times = times + 1
		end
	end
	if times >= 10000 then
		err = ERR_NORANDOMNAME
	end

	LDataPack.writeByte(senddp, err)
	if err == NOERR then
		LDataPack.writeByte(senddp, symbol)
		LDataPack.writeString(senddp, actorname)
	end
	LActorMgr.SendToGate(netid, senddp)
end

function queryLessJobReq(cmd, dp, serverid, accountid, accountname, actorid, netid, gateuser)
	local senddp = LActorMgr.getDataPacket()
	LDataPack.writeByte(senddp, 255)
	LDataPack.writeByte(senddp, sLessJob)
	if accountid == 0 then
		LDataPack.writeByte(senddp, ERR_SESS)
	else
		local ret, job = queryLessJobDb(serverid)
		LDataPack.writeByte(senddp, ret)
		LDataPack.writeByte(senddp, job)
	end
	LActorMgr.SendToGate(netid, senddp)
end

function queryZYReq(cmd, dp, serverid, accountid, accountname, actorid, netid, gateuser)
	local senddp = LActorMgr.getDataPacket()
	LDataPack.writeByte(senddp, 255)
	LDataPack.writeByte(senddp, sLessCamp)
	if accountid == 0 then
		LDataPack.writeByte(senddp, ERR_SESS)
	else
		local ret, camp = queryDbZY(serverid)
		LDataPack.writeByte(senddp, ret)
		LDataPack.writeByte(senddp, camp)
	end
	LActorMgr.SendToGate(netid, senddp)
end

-- 处理actormgr的网络数据
function actorMgrEvent(cmd, dp, serverid, accountid, accountname, actorid, netid, gateuser, loginip)
	if cmd == cQueryList then 
		queryActorList(dp, serverid, accountid, accountname, actorid, netid, loginip)
	elseif cmd == cCreateActor then
		createActor(dp, serverid, accountid, accountname, actorid, netid, gateuser, loginip)
	elseif cmd == cDelete then
		--deleteActor(dp, serverid, accountid, accountname, actorid, netid)
	elseif cmd == cEnterGame then
		enterGame(cmd, dp, serverid, accountid, accountname, actorid, netid, gateuser, loginip)
	elseif cmd == cRandName then
		randNameReq(cmd, dp, serverid, accountid, accountname, actorid, netid, gateuser)
	elseif cmd == cLessJob then
		--queryLessJobReq(cmd, dp, serverid, accountid, accountname, actorid, netid, gateuser)
	elseif cmd == cLessCamp then
		--queryZYReq(cmd, dp, serverid, accountid, accountname, actorid, netid, gateuser)
	elseif cmd == cCreateActorEx then
		createActorEx(dp, serverid, accountid, accountname, actorid, netid, gateuser, loginip)
	end
end


