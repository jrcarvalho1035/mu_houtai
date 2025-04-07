module("mailsystem", package.seeall)

--常量定义，如有修改请同步修改c++
local timeOut = 24 * 3600 * 15 --15天
local maxMailNum = 50 --
offCrossMail = offCrossMail or {}

function getMailVar(actor)
    local var = LActor.getStaticVar(actor)
    if (var == nil) then
        return
    end
    
    if (var.mail == nil) then
        var.mail = {}
        var.mail.id = 0
        var.mail.max_global_uid = System.getGlobalMailMaxUid()
    end
    
    return var.mail
end

function getGlobalMailMaxUid(actor)
    local var = getMailVar(actor)
    
    if var == nil then
        return 0
    end
    
    if var.max_global_uid == nil then
        return 0
    end
    return var.max_global_uid
end
_G.getGlobalMailMaxUid = getGlobalMailMaxUid

function setGlobalMailMaxUid(actor, uid)
    local var = getMailVar(actor)
    if var == nil then
        return
    end
    var.max_global_uid = uid
end
_G.setGlobalMailMaxUid = setGlobalMailMaxUid
function getNextMailId(actor)
    local mailVar = getMailVar(actor)
    if (not mailVar) then
        return 0
    end
    
    local id = mailVar.id
    mailVar.id = mailVar.id + 1
    return id
end
_G.getNextMailId = getNextMailId

function readMail(actor, uid)
    local awardStatus, readStatus, time, head, context, tAwardList = LActor.getMailInfo(actor, uid)
    if (not awardStatus) then
        return
    end
    
    if (readStatus == 0) then
        LActor.changeMailReadStatus(actor, uid)
        readStatus = 1
    end
    
    mailInfoSync(actor, uid, awardStatus, readStatus, time, head, context, tAwardList)
end

function mailInfoSync(actor, uid, awardStatus, readStatus, time, head, context, tAwardList)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mail, Protocol.sMailCmd_ReqRead)
    if pack == nil then return end
    
    LDataPack.writeData(pack, 7,
        dtInt, uid,
        dtString, head,
        dtInt, time,
        dtInt, readStatus,
        dtInt, awardStatus,
        dtString, context,
    dtInt, #tAwardList)
    for _, tb in ipairs(tAwardList) do
        local id = tb[1]
        local nType = tb[2]
        local count = tb[3]
        LDataPack.writeData(pack, 3, dtInt, nType, dtInt, id, dtInt, count)
    end
    LDataPack.flush(pack)
end

function mailListSync(actor)
    local tMailList = LActor.getMailList(actor)
    if (not tMailList) then
        return
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mail, Protocol.sMailCmd_MailListSync)
    if pack == nil then return end
    
    LDataPack.writeData(pack, 1, dtInt, #tMailList)
    for index, tb in ipairs(tMailList) do
        local uid = tb[1]
        local head = tb[2]
        local sendtime = tb[3]
        local readStatus = tb[4]
        local awardStatus = tb[5]
        LDataPack.writeData(pack, 5, dtInt, uid, dtString, head,
        dtInt, sendtime, dtInt, readStatus, dtInt, awardStatus)
    end
    LDataPack.flush(pack)
end

--发送邮件的接口
--tMailData = {}
--tMailData.head 邮件标题，字符串
--tMailData.context 邮件正文，字符串
--tMailData.tAwardList 附件(不能超过10个)，表，{{type = xx,id = xx,count = xx},...}
function sendMailById(actorId, tMailData, serverId)
    serverId = tonumber(serverId)
    local isCross = serverId and serverId ~= System.getServerId()
    if isCross then
        if serverId ~= 0 and not csbase.isConnected(serverId) then
            print("sendMailById not connected serverId = ", serverId)
            if not offCrossMail[serverId] then
                offCrossMail[serverId] = {}
            end
            if not offCrossMail[serverId][actorId] then
                offCrossMail[serverId][actorId] = {}
            end
            table.insert(offCrossMail[serverId][actorId], utils.table_clone(tMailData))
            return
        end
    end
    local actordata = LActor.getActorDataById(actorId)
    if actordata then
        local awardSize = 0
        if type(tMailData.tAwardList) == "table" then
            awardSize = #tMailData.tAwardList
        end
        System.logCounter(actorId, actordata.account_name, actordata.level,
        "sendmailbyid", tostring(tMailData.head), tostring(tMailData.context), "", awardSize, "", "")
    end
    
    if (not actorId or not tMailData) then
        print("send mail fail, actorid, tMailData", actorId, tMailData)
        return
    end
    
    if (not tMailData.head or type(tMailData.head) ~= "string") then
        tMailData.head = ""
    end
    
    if (not tMailData.context or type(tMailData.context) ~= "string") then
        tMailData.context = ""
    end
    
    if (not tMailData.tAwardList or type(tMailData.tAwardList) ~= "table") then
        tMailData.tAwardList = {}
    end
    
    local mailCount = math.ceil(#tMailData.tAwardList / 10)
    if mailCount == 0 then mailCount = 1 end
    for num = 1, mailCount do
        local tAwardInfo = {}
        for i = 10 * (num - 1) + 1, 10 * num do
            if (tMailData.tAwardList[i]) then
                table.insert(tAwardInfo, tMailData.tAwardList[i].type or 0)
                table.insert(tAwardInfo, tMailData.tAwardList[i].id or 0)
                table.insert(tAwardInfo, tMailData.tAwardList[i].count or 0)
            end
        end
        
        local head = tMailData.head
        if (mailCount > 1) then
            head = head .. string.format("(%d)", num)
        end
        
        local time = os.time()
        if isCross then
            local pack = LDataPack.allocPacket()
            if pack == nil then return end
            LDataPack.writeByte(pack, CrossSrvCmd.SCrossNetCmd)
            LDataPack.writeByte(pack, CrossSrvSubCmd.SCrossNetCmd_TransferMail)
            local awardNum = #tAwardInfo
            if awardNum > 0 then
                awardNum = math.floor(awardNum / 3)
            end
            LDataPack.writeData(pack, 5, dtInt, actorId, dtString, head, dtString, tMailData.context, dtInt, time, dtInt, awardNum)
            local bVal = 0
            for i = 1, awardNum do
                bVal = (i - 1) * 3
                LDataPack.writeData(pack, 3, dtInt, tAwardInfo[bVal + 1], dtInt, tAwardInfo[bVal + 2], dtInt, tAwardInfo[bVal + 3])
            end
            System.sendPacketToAllGameClient(pack, serverId)
            
        else
            System.sendMail(actorId, head, tMailData.context, time, #tAwardInfo, unpack(tAwardInfo))
        end
    end
end

local function TransferMail(sId, sType, dp)
    local actorId = LDataPack.readInt(dp)
    local basicData = LActor.getActorDataById(actorId)
    if not basicData then return end
    LActor.log(actorId, "mailsystem", "TransferMail", sId, sType)
    local head = LDataPack.readString(dp)
    local context = LDataPack.readString(dp)
    local time = LDataPack.readInt(dp)
    local count = LDataPack.readInt(dp)
    local tAwardInfo = {}
    for i = 1, count do
        table.insert(tAwardInfo, LDataPack.readInt(dp))
        table.insert(tAwardInfo, LDataPack.readInt(dp))
        table.insert(tAwardInfo, LDataPack.readInt(dp))
    end
    System.sendMail(actorId, head, context, time, #tAwardInfo, unpack(tAwardInfo))
end

local function onConnected(serverId, serverType)
    if System.isCommSrv() then return end
    if not offCrossMail[serverId] then return end
    for actorid, mails in pairs(offCrossMail[serverId]) do
        print("onConnected sendMailById serverId = ", serverId, "actorid =", actorid, "mailNum =", #mails)
        for i = #mails, 1, -1 do
            sendMailById(actorid, mails[i], serverId)
            table.remove(mails, i)
        end
    end
    offCrossMail[serverId] = nil
end

function mailAward(actor, uidList)
    local mailStatusList = {}
    local sendTips = false
    for _, uid in ipairs(uidList) do
        local awardStatus, readStatus, time, head, context, tAwardList = LActor.getMailInfo(actor, uid)
        if awardStatus == 0 then
            local giveSucc = giveAward(actor, uid, tAwardList)
            if giveSucc then
                awardStatus = 1
            end
            
            if not giveSucc and not sendTips then
                sendTips = true
            end
            
            if (readStatus == 0) then
                LActor.changeMailReadStatus(actor, uid)
                readStatus = 1
            end
            table.insert(mailStatusList, {uid = uid, readStatus = readStatus, awardStatus = awardStatus})
        elseif readStatus == 0 then
            LActor.changeMailReadStatus(actor, uid)
            readStatus = 1
            table.insert(mailStatusList, {uid = uid, readStatus = readStatus, awardStatus = awardStatus})
        end
    end
    
    if sendTips then
        LActor.sendTipmsg(actor, ScriptTips.mail01)
    end
    
    ReAwardSync(actor, mailStatusList)
end

function giveAward(actor, uid, tAwardList)
    local needSpace = 0
    local needElement = 0
    local needJewel = 0
    local needMount = 0
    local needFootEq = 0
    local needHuanShouEq = 0
    for _, tb in pairs(tAwardList) do
        local nType = tb[2]
        if (nType == AwardType_Item) then
            local itemId = tb[1]
            local config = ItemConfig[itemId]
            if config then
                if actoritem.isEquip(config) then
                    needSpace = needSpace + tb[3]
                elseif config.type == ItemType_FootEquip then
                    needFootEq = needFootEq + tb[3]
                elseif config.type == ItemType_Element then
                    needElement = needElement + tb[3]
                elseif config.type == ItemType_Jewel then
                    needJewel = needJewel + tb[3]
                elseif config.type == ItemType_Mount then
                    needMount = needMount + tb[3]
                elseif config.type == ItemType_HuanshouEquip then
                    needHuanShouEq = needHuanShouEq + tb[3]
                end
            end
        end
    end
    
    if (needSpace ~= 0 and (LActor.getEquipBagSpace(actor) < needSpace)) or
        (needFootEq ~= 0 and (LActor.getFootEquipBagSpace(actor) < needFootEq)) or
        (needHuanShouEq ~= 0 and (LActor.getHanshouEquipBagSpace(actor) < needHuanShouEq)) or
        (needElement ~= 0 and (LActor.getElementBagSpace(actor) < needElement)) then
        return false
    end
    
    LActor.changeMailAwardStatus(actor, uid)
    
    for _, tb in ipairs(tAwardList) do
        local id = tb[1]
        local nType = tb[2]
        local count = tb[3]
        actoritem.addItem(actor, id, count, "mail award")
    end

    return true
end

function ReAwardSync(actor, mailStatusList)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mail, Protocol.sMailCmd_ReAward)
    if pack == nil then return end
    
    LDataPack.writeData(pack, 1, dtInt, #mailStatusList)
    for _, tb in ipairs(mailStatusList) do
        LDataPack.writeData(pack, 3,
            dtInt, tb.uid,
            dtInt, tb.readStatus,
        dtInt, tb.awardStatus)
    end
    LDataPack.flush(pack)
end

function deleteMailSync(actor, uid)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mail, Protocol.sMailCmd_DeleteMail)
    if pack == nil then return end
    
    LDataPack.writeData(pack, 1, dtInt, uid)
    
    LDataPack.flush(pack)
end

function recvMail(actor, uid)
    local awardStatus, readStatus, time, head, context, tAwardList = LActor.getMailInfo(actor, uid)
    if (not awardStatus) then
        return
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mail, Protocol.sMailCmd_AddMail)
    if pack == nil then
        return
    end
    
    LDataPack.writeData(pack, 5, dtInt, uid, dtString, head, dtInt, time, dtInt, readStatus, dtInt, awardStatus)
    
    LDataPack.flush(pack)
end

function readMail_c2s(actor, packet)
    if System.isCrossWarSrv() then return end
    local uid = LDataPack.readInt(packet)
    readMail(actor, uid)
end

function mailAward_c2s(actor, packet)
    if System.isCrossWarSrv() then return end
    local count = LDataPack.readInt(packet)
    if count > maxMailNum then return end
    local uidList = {}
    for i = 1, count do
        local uid = LDataPack.readInt(packet)
        table.insert(uidList, uid)
    end
    mailAward(actor, uidList)
end

_G.deleteMailSync = deleteMailSync
_G.recvMail = recvMail

csbase.RegConnected(onConnected)
csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_TransferMail, TransferMail)

netmsgdispatcher.reg(Protocol.CMD_Mail, Protocol.cMailCmd_Read, readMail_c2s)
netmsgdispatcher.reg(Protocol.CMD_Mail, Protocol.cMailCmd_Award, mailAward_c2s)

--发送全服邮件的接口
--tMailData = {}
--tMailData.head 邮件标题，字符串
--tMailData.context 邮件正文，字符串
--tMailData.tAwardList 附件(不能超过10个)，表，{{type = xx,id = xx,count = xx},...}
function gmSendMailToAll(tMailData)
    if (not tMailData) then
        return
    end
    
    if (not tMailData.head or type(tMailData.head) ~= "string") then
        tMailData.head = ""
    end
    
    if (not tMailData.context or type(tMailData.context) ~= "string") then
        tMailData.context = ""
    end
    
    if (not tMailData.tAwardList or type(tMailData.tAwardList) ~= "table") then
        tMailData.tAwardList = {}
    end
    
    --ly:暂时先这么做, 会导致大量假玩家同时登陆,上线前要改
    --所有玩家
    local actorDatas = System.getAllActorData()
    for _, data in ipairs(actorDatas) do
        local actorData = toActorBasicData(data)
        
        sendMailById(actorData.actor_id, tMailData)
    end
end

local gmCmdHandlers = gmsystem.gmCmdHandlers

local testofflinemail = 1
gmCmdHandlers.offmail = function (actor, args)
    local actorid = tonumber(args[1])
    if actorid == nil then
        actorid = LActor.getActorId(actor)
    end
    
    --发送邮件的接口
    --tMailData = {}
    --tMailData.head 邮件标题，字符串
    --tMailData.context 邮件正文，字符串
    --tMailData.tAwardList 附件(不能超过10个)，表，{{type = xx,id = xx,count = xx},...}
    local tMailData = {}
    tMailData.head = "offline" .. testofflinemail
    tMailData.context = "offline test" .. testofflinemail
    testofflinemail = testofflinemail + 1
    tMailData.tAwardList = {}
    local tAwardList = tMailData.tAwardList
    
    for i = 1, 10 do
        tAwardList[#tAwardList + 1] = {type = 1, id = 100000, count = 1}
    end
    
    for i = 1, 1 do
        sendMailById(actorid, tMailData)
    end
    return true
end

gmCmdHandlers.gmMail = function (actor, args)
    local actorid = LActor.getActorId(actor)
    local itemId = tonumber(args[1])
    if not itemId then return end
    
    local tMailData = {}
    tMailData.head = "测试邮件标题"
    tMailData.context = "测试邮件内容"
    tMailData.tAwardList = {{type = 1, id = itemId, count = 1}}
    sendMailById(actorid, tMailData, LActor.getServerId(actor))
    return true
end

gmCmdHandlers.gmOffMail = function (actor, args)
    local actorid = tonumber(args[1])
    local itemId = tonumber(args[2])
    if not actorid or not itemId then return end
    
    local tMailData = {}
    tMailData.head = "测试邮件标题"
    tMailData.context = "测试邮件内容"
    tMailData.tAwardList = {{type = 1, id = itemId, count = 1}}
    sendMailById(actorid, tMailData, LActor.getServerId(actor))
    return true
end

