module("msimagerankaward", package.seeall)
--镜象伤害排行奖励
local msImageRateConf = MSImageRateConf
local msImageAwardConf = MSImageAwardConf
local globalConf = MonSiegeConf

local function getSystemVar()
	local var = System.getStaticVar()
	if var.msImageRank == nil then
		var.msImageRank = {}
		var.msImageRank.rewardLog = {}
	end
	return var.msImageRank
end

function clearSys()
	local var = System.getStaticVar()
	var.msImageRank = nil
end

function getRandomTask(list)
     local result = 0
     if list == nil or type(list) ~= "table" then return result end

     local num = 0
     for i=1, #list do
          num = num + list[i].weights
     end
     if num < 1 then return result end
     local rand = System.getRandomNumber(num-1) + 1
     local result = 0
     for i=1, #list do
          rand = rand - list[i].weights
          if rand <= 0 then
               result = i
               break
          end
     end
     return result
end

function imageHurtAward(aName, percent)
	local totalAward = {}
	local conf
	for k,v in ipairs(msImageRateConf) do
		if percent >= v.starHp and percent <= v.endHp then
			conf = v
			break
		end
	end
	if not conf then return totalAward end

	local hasWinAwards = false
	local totalRate = 100
	local randNum = System.getRandomNumber(totalRate-1) + 1
	if randNum <= conf.rate then
		--中了
		local var = getSystemVar()
		local wList = {}
		for k,v in ipairs(msImageAwardConf) do
			if not var.rewardLog[k] then
				--以前无的才加入到随机列表
				wList[#wList+1] = {id=k, weights=v.weights}
			end
		end

		--这个保底不需要留给镜象玩家了
		if #wList > 0 and #wList <= #msImageAwardConf then
			local idx = getRandomTask(wList)
			local wTbl = wList[idx]
			if wTbl then
				local tbl = msImageAwardConf[wTbl.id]
				var.rewardLog[wTbl.id] = aName
				totalAward = utils.table_clone(tbl.item)
				hasWinAwards = true
			end
		end
	end

	local baseAwardClone = utils.table_clone(globalConf.baseAward)
	for i = 1, #baseAwardClone do
		totalAward[#totalAward + 1] = baseAwardClone[i]
	end

	return hasWinAwards, totalAward 
end

function imageAwardSettlement(actorId)
	local var = getSystemVar()
	local awards = {}
	for k,v in ipairs(msImageAwardConf) do
		if not var.rewardLog[k] then
			--未被抢的再给镜象玩家
			-- LActor.giveAward(actor, v.item, "msiSettlementAward:", v.id)
			table.insert(awards, v.item)
		end
	end

	local mailData = { head=globalConf.imageGiftTitle, context=globalConf.imageGiftCont, tAwardList=globalConf.imageGiftItem }
	--mailsystem.sendMailById(actorId, mailData)
end

function onGetAwardInfo(actor, pack)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_ReqImageAwardInfo)
	if npack == nil then return end

	local var = getSystemVar()
	local count = 0
	local pos1 = LDataPack.getPosition(npack)
	LDataPack.writeByte(npack, count)
	for k,v in pairs(var.rewardLog) do
		count = count + 1
		LDataPack.writeByte(npack, k)
		LDataPack.writeString(npack, v)
	end
	local pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos1)
	LDataPack.writeByte(npack, count)
	LDataPack.setPosition(npack, pos2)
	LDataPack.flush(npack)
end

netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_ReqImageAwardInfo, onGetAwardInfo)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.mscilog = function (actor, args)
	clearSys()
	return true
end
