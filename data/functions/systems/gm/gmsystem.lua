--处理GM相关的操作
module("gmsystem", package.seeall)

--GM指令是以@开头的命令,使用空格分隔，比如@additem 102 1
gmCmdHandlers = {}

local LActor = LActor

function setGmeventHander(cmd, hander)
    if gmCmdHandlers == nil then
        gmCmdHandlers = {}
    end
    
    gmCmdHandlers[cmd] = hander
end

function onGmCmd(actor, packet)
    if LActor.getGmLevel(actor) == 0 then
        return
    end
    local msg = LDataPack.readString(packet)
    ProcessGmCommand(actor, msg)
end

function ProcessGmCommand(actor, msg, args)
    if args then
        -- 替换参数
        for i, v in ipairs(args) do
            msg = string.gsub(msg, string.format(" {%d} ", i), string.format(" %s ", v))
        end
    end
    -- print("ProcessGmCommand:" .. msg)
    
    msg = msg:match("^%s*(.*)%s*$")
    if #msg < 2 then return end
    
    if "@" ~= string.sub(msg, 1, 1) then return end
    
    msg = string.sub(msg, 2)
    
    msg = msg:match("^%s*(.*)%s*$")
    local cmd, strArgs = msg:match("^(%S+)%s*(.*)%s*$")
    if nil == cmd or "" == cmd then return end
    
    local args = {}
    
    for arg in string.gmatch(strArgs, "%s*(%S+)") do
        table.insert(args, arg)
    end
    
    if nil == gmCmdHandlers then return end
    
    local handle = gmCmdHandlers[cmd]
    if nil == handle then
        print("No such gm command")
        LActor.sendTipmsg(actor, "No such gm command")
        return
    end
    
    local ret = handle(actor, args)
    local s = "|C:0xffa631&T:gm cmd| |C:0xffffff&T:%s| |C:0xffa631&T:successful!|"
    if not ret then
        s = "|C:0xffa631&T:gm cmd| |C:0xffffff&T:%s| |C:0xffa631&T:fail!|"
    end
    LActor.sendTipmsg(actor, string.format(s, cmd))
end

--转发gm命令给跨服
_G.SCTransferGM = function (name_func, table_args, isLianFu)
    if System.isCrossWarSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCrossNetCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCrossNetCmd_TransferGM)
    LDataPack.writeString(pack, name_func)
    table_args = table_args or {}
    LDataPack.writeByte(pack, #table_args)
    for i = 1, #table_args do
        LDataPack.writeString(pack, table_args[i])
    end
    System.sendPacketToAllGameClient(pack, isLianFu and csbase.getLianfuServerId() or 0)
end

local function onSCTransferGM(sId, sType, dp)
    if System.isCommSrv() then return end
    local name_func = LDataPack.readString(dp)
    local args = {}
    local count = LDataPack.readByte(dp)
    for i = 1, count do
        args[i] = LDataPack.readString(dp)
    end
    local func = gmCmdHandlers[name_func]
    if type(func) ~= "function" then
        print("not find func: ", name_func)
        return
    end
    func(nil, args)
end

csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_TransferGM, onSCTransferGM)
netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_GmCmd, onGmCmd)

---------------------------------------------------------------------------------
--重新载入全局npc的脚本
gmCmdHandlers.rsf = function(actor, args)
    return System.reloadGlobalNpc(actor, 0)
end

gmCmdHandlers.reloadlang = function()
    if not System.reloadLang() then return end
    return true
end

gmCmdHandlers.gmMemoryLog = function()
    System.memoryLog()
    return true
end

_G.testshow = function(t, id)
    utils.printInfo(t, id)
end

_G.systemTestVar = _G.systemTestVar or {}
local systemTestVar = _G.systemTestVar
gmCmdHandlers.test = function (actor, args)
    --print("%d", 28)
    local code = '8afdf3fbbbbif2hf'
    
    local len = string.byte(string.sub(code, -1)) - 97
    local pos = string.byte(string.sub(code, -2, -2)) - 97
    
    local str = string.sub(code, pos + 1, pos + len)
    local id = 0
    for i = 1, string.len(str) do
        id = id * 10 + (math.abs(string.byte(string.sub(str, i, i)) - 97))
    end
    print("...............", id)
    
    -- local var = LActor.getStaticVar(actor)
    -- if not var then return end
    -- if not var.test1 then
    --     var.test1 = {}
    --     var.test1.a = {}
    --     var.test1.a.b = 0
    -- end
    -- print("a=", var.test1.a)
    -- var.test1 = LActor.getEmptyStaticVar()
    -- print("a1 = ", var.test1.a)
    --utils.printInfo("#### test")
    --local var =
    -- local exp, sexp, items = guajifuben.getMonsterRewardByTime(actor, tonumber(args[1]))
    -- print(exp, sexp)
    -- utils.printTable(items)
    return true
end

gmCmdHandlers.test1 = function (actor, args)
    returnToLastStaticFuben(actor)
end

gmCmdHandlers.addexp = function(actor, arg)
    local exp = tonumber(arg[1])
    actorexp.addExp(actor, exp)
    return true
end

gmCmdHandlers.additem = function(actor, args)
    local itemId = tonumber(args[1])
    local count = tonumber(args[2])
    if itemId ~= nil then
        if (count or 0) > 0 then
            if ElementBaseConfig[id] then
                itemId = ElementBaseConfig[id].soleid
            end
            actoritem.addItem(actor, itemId, count, "gmhandler")
        elseif (count or 0) < 0 then
            actoritem.reduceItem(actor, itemId, -count, "gmhandler")
        end
    end
    return true
end

gmCmdHandlers.additems = function(actor, args)
    local num = tonumber(args[1]) or 1000
    for k, v in pairs(CurrencyConfig) do
        actoritem.addItem(actor, v.id, num, "gmhandler")
    end
    
    for k, v in pairs(ItemConfig) do
        if (not actoritem.isEquip(v)) and
            v.type ~= ItemType_Element and
            v.type ~= ItemType_Damon and
            v.type ~= ItemType_Jewel and
            v.type ~= ItemType_Mount and
            v.type ~= ItemType_FootEquip and
            v.keep_time == 0
            then
            actoritem.addItem(actor, v.id, num, "gmhandler")
        end
    end
    return true
end

gmCmdHandlers.addgold = function(actor, args)
    local gold = tonumber(args[1])
    LActor.changeGold(actor, gold, "gmhandler")
    return true
end

gmCmdHandlers.addyuanbao = function(actor, args)
    local yuanbao = tonumber(args[1])
    LActor.changeYuanBao(actor, yuanbao, "gmhandler")
    return true
end

gmCmdHandlers.setvip = function(actor, arg)
    local vip = tonumber(arg[1])
    LActor.setVipLevel(actor, vip)
    return true
end

gmCmdHandlers.clearbag = function(actor, arg)
    local bagtype = tonumber(arg[1])
    if not bagtype then
        for i = 0, 10 do
            LActor.gmClearBag(actor, i)
        end
    else
        LActor.gmClearBag(actor, bagtype)
    end
    return true
end

gmCmdHandlers.newday = function(actor, arg)
    OnActorEvent(actor, aeNewDayArrive, false)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_LoginFinish)
    LDataPack.flush(pack)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_DayFirstLogin)
    LDataPack.flush(pack)
    return true
end

gmCmdHandlers.monpos = function(actor, arg)
    local pScene = LActor.getScenePtr(actor)
    if not pScene then return end
    
    local posTabel = Fuben.getSceneMonsterPos(pScene)
    print("#posTabel:" .. #posTabel)
    local msg = ""
    for i = 1, #posTabel do
        local pos = posTabel[i]
        msg = msg .. "怪物ID：" .. pos[1]
        .. "  怪物名字：" .. MonstersConfig[pos[1]].name
        .. string.format("  坐标：(%d,%d) \n", pos[2], pos[3])
    end
    LActor.sendTipmsg(actor, msg, ttDialog)
    return true
end

gmCmdHandlers.recharge = function(actor, arg)
    LActor.addRecharge(actor, tonumber(arg[1]))
    return true
end

gmCmdHandlers.curpos = function (actor, args)
    local posx, posy = LActor.getEntityScenePos(actor)
    local msg = string.format("主角色坐标(%d,%d)", posx, posy)
    LActor.sendTipmsg(actor, msg, ttDialog)
    return true
end

gmCmdHandlers.reMon = function (actor, args)
    local monid = tonumber(args[1])
    local posx, posy = LActor.getEntityScenePos(actor)
    local ins = instancesystem.getActorIns(actor)
    local sceneHandle = ins.scene_list[1]
    ins:insCreateMonster(sceneHandle, monid, posx, posy)
    return true
end

gmCmdHandlers.sendmail = function(actor, args)
    local account = args[1]
    local id = tonumber(args[2] or 1)
    
    mailsystem.sendConfigMail(LActor.getActorIdByAccountName(account), id)
    return true
end

gmCmdHandlers.readmail = function(actor)
    local tMailList = LActor.getMailList(actor)
    if (not tMailList) then
        return
    end
    
    for index, tb in ipairs(tMailList) do
        local uid = tb[1]
        local status = tb[4]
        if (status == 0) then
            mailsystem.readMail(actor, uid)
            break;
        end
    end
    return true
end

gmCmdHandlers.mailaward = function(actor)
    local tMailList = LActor.getMailList(actor)
    if (not tMailList) then
        return
    end
    
    for index, tb in ipairs(tMailList) do
        local uid = tb[1]
        local status = tb[5]
        if (status == 0) then
            mailsystem.mailAward(actor, uid)
            break;
        end
    end
    return true
end

gmCmdHandlers.dropgroup = function(actor, args)
    local dropId = tonumber(args[1])
    local count = tonumber(args[2] or 1)
    local tem = {}
    local tem1 = {}
    local temp = {"白色装备", "绿色装备", "蓝色装备", "紫色装备", "橙色装备", "红色0星装备", "红色1星装备", "红色2星装备", "红色3星装备", "红色4星装备"}
    for i = 1, count do
        local reward = drop.dropGroup(dropId)
        actoritem.addItems(actor, reward, "gm drop "..dropId)
        for k, v in pairs(reward) do
            local itemConf = ItemConfig[v.id]
            if itemConf then
                if itemConf.type == 0 then
                    local quality = itemConf.quality + itemConf.star
                    tem[quality] = (tem[quality] or 0) + v.count
                    local rank = itemConf.rank
                    local name = rank.."阶装备"
                    tem[name] = (tem[name] or 0) + v.count
                elseif itemConf.type == 17 then
                    local name = itemConf.name[1]
                    local level = string.sub(name, 1, 1) .. "级宝石"
                    tem1[level] = (tem1[level] or 0) + v.count
                else
                    local name = itemConf.name[1]
                    tem1[name] = (tem1[name] or 0) + v.count
                end
            else
                local name = CurrencyConfig[v.id].name[1]
                tem1[name] = (tem1[name] or 0) + v.count
            end
        end
    end
    for i, v in ipairs(temp) do
        -- if tem[i - 1] and tem[i - 1] > 0 then
        -- print (v.." 总计: "..tem[i - 1])
        -- end
        print (v.." 总计: " .. (tem[i - 1] or "nil"))
    end
    for k, v in pairs(tem) do
        if type(k) == "string" then
            print (k.." 总计: "..v)
        end
    end
    print ("------------------")
    for k, v in pairs(tem1) do
        print (k.." 总计: "..v)
    end
end

gmCmdHandlers.kill = function(actor, args)
    local role = LActor.getRole(actor)
    if not role then return end
    local maxhp = LActor.getHpMax(role)
    LActor.changeHp(role, -maxhp)
    return true
end

gmCmdHandlers.changeHp = function(actor, args)
    local role = LActor.getRole(actor)
    if not role then return end
    local v = tonumber(args[1]) or 0
    LActor.setHp(role, v)
    return true
end

gmCmdHandlers.kickactor = function(actor, args)
    local actorid = tonumber(args[1])
    local actor = System.getEntityPtrByActorID(actorid)
    System.closeActor(actor)
    return true
end

gmCmdHandlers.revive = function(actor, args)
    LActor.recover(actor)
    return true
end

gmCmdHandlers.createmonster = function (actor, args)
    local monId = tonumber(args[1])
    local count = args[2] and tonumber(args[2]) or 1
    local fuben = LActor.getFubenPrt(actor)
    local hf = Fuben.getFubenHandle(fuben)
    local ins = instancesystem.getInsByHdl(hf)
    local posX, posY = LActor.getEntityScenePoint(actor)
    for i = 1, count do
        ins:createFubenMonster(monId, posX, posY)
    end
    return true
end

local msg_attackId = 0
local msg_targetId = 0
gmCmdHandlers.setAttackMsg = function (actor, args)
    msg_attackId = tonumber(args[1])
    msg_targetId = tonumber(args[2])
    local sId = tonumber(args[3])
    System.setSkillAttackMsg(true) --开启打印
    
    local roleId, monsterId
    if msg_attackId > 3 then
        monsterId = msg_attackId
        roleId = msg_targetId
    else
        roleId = msg_attackId
        monsterId = msg_targetId
    end
    
    --创建怪物
    local fuben = LActor.getFubenPrt(actor)
    local hf = Fuben.getFubenHandle(fuben)
    local ins = instancesystem.getInsByHdl(hf)
    local posX, posY = LActor.getEntityScenePoint(actor)
    local monster = ins:createFubenMonster(monsterId, posX, posY)
    
    local attacker, target
    local role = LActor.getRole(actor)
    
    if msg_attackId > 3 then
        attacker = monster
        target = role
    else
        attacker = role
        target = monster
    end
    LActor.castSkillToMonster(attacker, sId, target)
    return true
end

local hitTypes = {"命中", "无视一击", "miss", "会心一击", "卓越一击", "致命一击", "反伤"}
function showAttackMsg(attackId, skill, targetId, tp, damage, atkAttr)
    if not (attackId == msg_attackId and targetId == msg_targetId) then
        return
    end
    local name = hitTypes[tp] or "无"
    log_print("攻击者(%d)以攻击力(%d)对(%d)使用了技能(%d)，%s造成%d伤害", attackId, atkAttr, targetId, skill, name, damage)
end
_G.showAttackMsg = showAttackMsg

function showReboundMsg(attackId, targetId, damage)
    if not (attackId == msg_attackId and targetId == msg_targetId) then
        return
    end
    print(string.format("攻击者(%d)受到(%d)的反弹伤害%d", attackId, targetId, damage))
end
_G.showReboundMsg = showReboundMsg

gmCmdHandlers.clearmonster = function (actor)
    local fuben = LActor.getFubenPrt(actor)
    local hf = Fuben.getFubenHandle(fuben)
    local ins = instancesystem.getInsByHdl(hf)
    for _, sceneHdl in pairs(ins.scene_list) do
        Fuben.clearAllMonster(sceneHdl)
    end
    return true
end

gmCmdHandlers.checkAttr = function (actor, args)
    local role = LActor.getRole(actor)
    for k, v in pairs(AttrPowerConfig) do
        utils.printInfo("attr", k, LActor.getAttr(role, k))
    end
    
    --LActor.addSkillEffect(actor, tonumber(args[1]))
    return true
end

gmCmdHandlers.addbuf = function (actor, args)
    local bufID = tonumber(args[1])
    local time = tonumber(args[2]) or - 1
    LActor.addSkillEffect(actor, bufID, time)
    return true
end

gmCmdHandlers.fubenattr = function (actor, args)
    local attrType = tonumber(args[1])
    local attrValue = tonumber(args[2])
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Fuben)
    attr:Set(attrType, attrValue)
    LActor.reCalcAttr(actor)
    return true
end

local serActorid = 1
gmCmdHandlers.serstr = function (actor, args)
    -- local ttable = {}
    -- for i = 1, 10 do
    -- ttable[i] = {}
    -- local subtable = ttable[i]
    -- for i = 1, 10 do
    -- subtable[i] = i .. 1
    -- end
    -- end
    -- ttable.extra1 = "extra1"
    -- ttable.extra2 = "extra2"
    -- local ud = bson.encode(ttable)
    -- -- print("type(ud):" .. type(ud))
    -- -- local dud = bson.decode(ud)
    -- -- utils.printTable(dud)
    -- --if 1 then return end
    -- --print("sstr:" .. sstr)
    -- local estr = System.EscapeUserData(ud)
    -- print("estr:" .. estr)
    
    -- local queryStr = "call clearofflinedata()"
    -- local db = System.createActorsDbConn()
    -- if db == nil then return end
    -- local err = System.dbExe(db, queryStr)
    -- if err ~= 0 then
    -- print("sql query error:".. queryStr)
    -- return
    -- end
    -- System.dbResetQuery(db)
    
    -- local queryStr1 = string.format("call saveofflinedata(%d, '%s')", serActorid, estr)
    -- local db1 = db
    -- if db1 == nil then return end
    -- local err1 = System.dbExe(db1, queryStr1)
    -- if err1 ~= 0 then
    -- print("sql query error:".. queryStr1)
    -- return
    -- end
    
    -- local queryStr2 = "call loadofflinedata()"
    -- local db2 = db
    -- if db2 == nil then return end
    -- local err2 = System.dbQuery(db2, queryStr2)
    -- if err2 ~= 0 then
    -- print("sql query error:".. queryStr2)
    -- return
    -- end
    
    -- local row = System.dbCurrentRow(db)
    -- while row do
    -- local actorid = tonumber(System.dbGetRow(row, 0))
    -- local len = System.dbGetLen(db, 1)
    -- local dbud = System.dbCopyRowToUserData(row, 1, len)
    -- local usstr = bson.decode(dbud)
    -- utils.printTable(usstr)
    -- row = System.dbNextRow(db)
    -- end
    
    -- System.dbResetQuery(db2)
    -- System.dbClose(db2)
    -- System.delActorsDbConn(db2)
    
    -- serActorid = serActorid + 1
    
    local ttable = {}
    local ud = bson.encode(ttable)
    local estr = System.EscapeUserData(ud)
    print("estr:" .. estr)
    local queryStr = string.format("test '%s'", estr)
    print("queryStr:" .. queryStr)
    return true
end

gmCmdHandlers.saveoff = function (actor, args)
    offlinedatamgr.SaveData()
    return true
end

gmCmdHandlers.loadoff = function (actor, args)
    offlinedatamgr.LoadData()
    return true
end

gmCmdHandlers.pview = function (actor, args)
    return true
end

gmCmdHandlers.poffset = function (actor, args)
    utils.printTable(offlinedatamgr.offlineDataSet)
    return true
end

gmCmdHandlers.updatesr = function (actor, arg)
    utils.rankfunc.flushSetTitle()
    return true
end

gmCmdHandlers.dptest = function (actor, args)
    local count = tonumber(args[1])
    for i = 1, count do
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_UpdateMoney)
        if pack == nil then return end
        LDataPack.writeShort(pack, 1)
        LDataPack.writeDouble(pack, 1)
        LDataPack.writeChar(pack, 1)
        LDataPack.flush(pack)
        --print("send dptest count:" .. i)
    end
    return true
end

gmCmdHandlers.savesys = function (actor, args)
    systemfunc.saveAll()
    return true
end

gmCmdHandlers.setsys = function (actor, args)
    local ssvar = System.getStaticVar()
    ssvar.testData = {}
    local testData = ssvar.testData
    local count = tonumber(args[1])
    local dataCount = tonumber(args[2])
    for i = 1, count do
        testData[i] = {}
        for j = 1, dataCount do
            testData[i][j] = 1
        end
    end
    return true
end

gmCmdHandlers.globalscriptlen = function (actor, args)
    local len = System.getGlobalScriptLen()
    print("System.getGlobalScriptLen:" .. len / 1024 / 1024 .. "MB")
    return true
end

gmCmdHandlers.attrs = function (actor, args)
    print("================普通角色===============")
    local role = LActor.getRole(actor)
    local text = "%s(%d):%.0f"
    if role then
        local attrs = LActor.getBattleAttrs(role)
        if not attrs then
            print("gmCmdHandlers.attrs attrs is nil")
            return
        end
        
        for i = Attribute.atHp, Attribute.atCount - 1 do
            if attrs[i] ~= 0 then
                print(string.format(text, AttrPowerConfig[i].name, i, attrs[i]))
            end
        end
    end
    print("--------------------------------------")
    
    print("================变身角色===============")
    local scene = LActor.getScenePtr(actor)
    local roleSuperTable = Fuben.getSceneEntityPtr(scene, EntityType_RoleSuper)
    if roleSuperTable ~= nil then
        for i = 1, #roleSuperTable do
            local role = roleSuperTable[i]
            if role then
                local attrs = LActor.getBattleAttrs(role)
                if not attrs then
                    print("gmCmdHandlers.attrs attrs is nil")
                    return
                end
                
                for i = Attribute.atHp, Attribute.atCount - 1 do
                    if attrs[i] ~= 0 then
                        print(string.format(text, AttrPowerConfig[i].name, i, attrs[i]))
                    end
                end
            end
            print("--------------------------------------")
        end
    end
    
    print("================角色克隆===============")
    local scene = LActor.getScenePtr(actor)
    local roleCloneTable = Fuben.getSceneEntityPtr(scene, EntityType_RoleClone)
    if roleCloneTable ~= nil then
        for i = 1, #roleCloneTable do
            local role = roleCloneTable[i]
            if role then
                local attrs = LActor.getBattleAttrs(role)
                if not attrs then
                    print("gmCmdHandlers.attrs attrs is nil")
                    return
                end
                
                for i = Attribute.atHp, Attribute.atCount - 1 do
                    if attrs[i] ~= 0 then
                        print(string.format(text, AttrPowerConfig[i].name, i, attrs[i]))
                    end
                end
            end
            print("--------------------------------------")
        end
    end
    
    print("================变身角色克隆===============")
    local scene = LActor.getScenePtr(actor)
    local roleSuperCloneTable = Fuben.getSceneEntityPtr(scene, EntityType_RoleSuperClone)
    if roleSuperCloneTable ~= nil then
        for i = 1, #roleSuperCloneTable do
            local role = roleSuperCloneTable[i]
            if role then
                local attrs = LActor.getBattleAttrs(role)
                if not attrs then
                    print("gmCmdHandlers.attrs attrs is nil")
                    return
                end
                
                for i = Attribute.atHp, Attribute.atCount - 1 do
                    if attrs[i] ~= 0 then
                        print(string.format(text, AttrPowerConfig[i].name, i, attrs[i]))
                    end
                end
            end
            print("--------------------------------------")
        end
    end
    
    return true
end

gmCmdHandlers.testvar = function (actor, args)
    local testNumber = tonumber(args[1])
    if testNumber then
        local var1 = LActor.getStaticVar(actor)
        var1.testNumberValue = testNumber
        print("var1.testNumberValue:" .. var1.testNumberValue)
        
        local var2 = LActor.getStaticVar(actor)
        print("var2.testNumberValue:" .. var2.testNumberValue)
    else
        local var1 = LActor.getStaticVar(actor)
        print("var1.testNumberValue:" .. var1.testNumberValue)
    end
    return true
end

gmCmdHandlers.loginotherserver = function (actor, args)
    local serverId = tonumber(args[1])
    if not serverId then return end
    LActor.loginOtherServer(actor, serverId, 0, 0, 0, 0, "cross")
    return true
end

gmCmdHandlers.testcrossvar = function (actor, args)
    local testNumber = tonumber(args[1])
    if testNumber then
        local var1 = LActor.getCrossVar(actor)
        var1.testNumberValue = testNumber
        print("var1.testNumberValue:" .. var1.testNumberValue)
        
        local var2 = LActor.getCrossVar(actor)
        print("var2.testNumberValue:" .. var2.testNumberValue)
    else
        local var1 = LActor.getCrossVar(actor)
        print("var1.testNumberValue:" .. var1.testNumberValue)
    end
    return true
end

gmCmdHandlers.gotocs = function (actor, args)
    if not args[1] then
        LActor.loginOtherServer(actor, csbase.getLianfuServerId(), 1, 0, 0, 0, "cross")
    else
        LActor.loginOtherServer(actor, tonumber(args[1]), 0, 0, 0, 0, "cross")
    end
    return true
end

gmCmdHandlers.checkallpowers = function (actor, args)
    local powers = {}
    for id = AttrRoleSysId_Start, AttrRoleSysId_Max - 1 do
        local power = 0
        local attr = LActor.getRoleSystemAttrs(actor, id)
        for i = Attribute.atHp, Attribute.atCount - 1 do
            power = power + AttrPowerConfig[i].power * attr[i]
            if i == Attribute.atAtk then --攻击力附加属性，要特殊结算战力
                power = power + (AttrPowerConfig[Attribute.atAtkMin].power + AttrPowerConfig[Attribute.atAtkMax].power) * attr[i]
            end
        end
        --utils.printInfo("actor power", id, power)
        table.insert(powers,{id=id,power=power/100})
    end
    table.sort( powers ,function (a,b)  return a.power > b.power end)
    for i,v in ipairs(powers) do
        print(v.id,"  ",v.power)
    end
end

gmCmdHandlers.random = function (actor, args)
    for i = 1, 10 do
        print("gmCmdHandlers.random number:" .. System.getRandomNumber(3))
    end
    return true
end

gmCmdHandlers.angelEquipFinish = function (actor)
    utils.rankfunc.angelRankFinish()
    return true
end

gmCmdHandlers.getoff = function(actor, args)
    local tmp = offlinedatamgr.GetDataByOffLineDataType(tonumber(args[1]), offlinedatamgr.EOffLineDataType.EBasic)
    return true
end

gmCmdHandlers.debug = function(actor, args)
    LActor.debug()
    return true
end

gmCmdHandlers.lose = function(actor, args)
    local ins = instancesystem.getActorIns(actor)
    ins:lose()
    return true
end

gmCmdHandlers.win = function(actor, args)
    local ins = instancesystem.getActorIns(actor)
    ins:win()
    return true
end

gmCmdHandlers.savedb = function (actor, args)
    --在线玩家保存离线数据
    local actors = System.getOnlineActorList()
    if actors then
        for i = 1, #actors do
            local actor = actors[i]
            if actor then
                LActor.saveDb(actor)
                --System.setActorDbSaveTime(10) --设置玩家保存时间为10秒
            end
        end
    end
    systemfunc.saveAll()
    offlinedatamgr.SaveData()
end

gmCmdHandlers.whoseyourdady = function (actor, args)
    gmCmdHandlers.chongzhiAll(actor, {})--充值
    gmCmdHandlers.customAll(actor, {})--跳关卡
    gmCmdHandlers.maintaskAll(actor, {})--跳主线
    gmCmdHandlers.levelAll(actor, {})--调等级
    gmCmdHandlers.shenqiAll(actor, {})--神器
    gmCmdHandlers.wingAll(actor, {})--翅膀
    gmCmdHandlers.shenzhuangAll(actor, {})--神装
    gmCmdHandlers.meilinAll(actor, {})--梅林
    gmCmdHandlers.damonAll(actor, {})--精灵
    gmCmdHandlers.yongbingAll(actor, {})--佣兵
    gmCmdHandlers.shenmoAll(actor, {})--神魔
    gmCmdHandlers.hunqiAll(actor, {})--魂器
    gmCmdHandlers.skillAll(actor, {})--技能
    gmCmdHandlers.equipAll(actor, {})--装备
    gmCmdHandlers.suitAll(actor, {})--套装
    gmCmdHandlers.enhanceAll(actor, {})--强化
    gmCmdHandlers.stoneAll(actor, {})--宝石
    gmCmdHandlers.appendAll(actor, {})--追加
    gmCmdHandlers.cultureAll(actor, {})--培养
    gmCmdHandlers.fruitAll(actor, {})--果实
    gmCmdHandlers.elementAll(actor, {})--符文
    gmCmdHandlers.starsoulAll(actor, {})--圣戒
    gmCmdHandlers.shengwulAll(actor, {})--圣物
    gmCmdHandlers.lianjinAll(actor, {})--炼金
    gmCmdHandlers.touxianAll(actor, {})--天使头衔
    gmCmdHandlers.zhuangshengAll(actor, {})--转生
    gmCmdHandlers.lilianAll(actor, {})--历练军衔
    gmCmdHandlers.guildskillAll(actor, {})--公会技能
    gmCmdHandlers.grailAll(actor, {})--不朽圣杯
    gmCmdHandlers.zlxzAll(actor, {})--战力勋章
    gmCmdHandlers.footAll(actor, {})--足迹
    gmCmdHandlers.shenyouAll(actor, {}) -- 神佑
    gmCmdHandlers.shenglingAll(actor, {}) -- 圣灵
    gmCmdHandlers.hufuAll(actor, {})-- 护符
    gmCmdHandlers.tianmoAll(actor, {})-- 堕落神装
    gmCmdHandlers.shengdunAll(actor, {})-- 天使圣盾
    gmCmdHandlers.secretAll(actor, {})-- 密语
    gmCmdHandlers.shenshouAll(actor, {})-- 神兽
    gmCmdHandlers.shenpanAll(actor, {})-- 审判套装
    gmCmdHandlers.enchantAll(actor, {})-- 审判附魔
    gmCmdHandlers.smzlAll(actor, {})-- 暗黑之灵
    gmCmdHandlers.smequipAll(actor, {})-- 暗黑装备
    gmCmdHandlers.shenyuAll(actor, {})-- 神羽
    gmCmdHandlers.purifyAll(actor, {})-- 精炼
    gmCmdHandlers.warcraftAll(actor, {})-- 魔兽宝典
    gmCmdHandlers.yuansuAll(actor, {})-- 元素系统
    gmCmdHandlers.zhenhongAll(actor, {})-- 元素系统
    gmCmdHandlers.lingqiAll(actor, {})-- 灵器系统
    return true
end

gmCmdHandlers.additemEquip = function (actor, args)
    local job = 1
    local rank = tonumber(args[1])
    local quality = tonumber(args[2])
    local subType = tonumber(args[3])
    local rewards = {}
    local ItemConfig = ItemConfig
    if rank and rank < 0 then return false end
    if quality and quality < 0 then return false end
    if subType and (subType == 8 or subType < 0) then return false end
    local id_job = 100000
    id_job = id_job + job * 1000
    for i_quality = 0, 8 do --品质
        local id_quality = id_job
        if quality and quality <= 8 then i_quality = quality end
        id_quality = id_quality + i_quality * 100
        for i_rank = 1, 13 do --阶级
            local id_rank = id_quality
            if rank and rank <= 13 then i_rank = rank end
            id_rank = id_rank + i_rank
            for i_subType = 0, 9 do --部位
                local id_subType = id_rank
                if subType and subType <= 9 then i_subType = subType end
                id_subType = id_subType + i_subType * 10000
                --id计算完成,根据部位给予装备
                if ItemConfig[id_subType] then
                    table.insert(rewards, {type = 1, id = id_subType, count = 1})
                end
                --actoritem.addItem(actor, id_subType, 1, "gmhandler")
                if subType and subType <= 9 then break end --指定部位时
            end
            if rank and rank <= 13 then break end --指定阶级时
        end
        if quality and quality <= 8 then break end --指定品质时
    end
    actoritem.addItems(actor, rewards, "gmhandler")
    return true
end

gmCmdHandlers.GmPick = function (actor, args)
    local id = tonumber(args[1])
    local count = tonumber(args[2]) or 1
    local conf = ItemConfig[id] or {}
    local rewards = {}
    if actoritem.isCurrency(id) or actoritem.isSpeCurrency(id) then
        conf.type = 0
    else
        if not conf.type then return false end
        conf.type = 1
    end
    local reward = {}
    reward.type = conf.type
    reward.id = id
    reward.count = count
    table.insert(rewards, reward)
    local ins = instancesystem.getActorIns(actor)
    local PosX, PosY = LActor.getEntityScenePoint(actor)
    PosX = math.floor(PosX + 64)
    PosY = math.floor(PosY + 64)
    ins:addDropBagItem(actor, rewards, 3600, PosX, PosY)
    return true
end

gmCmdHandlers.printdropgroup = function (actor, args)
    local id = tonumber(args[1])
    local conf = ItemConfig[id]
    if not conf then return end
    local dropId = conf.useArg.dropId
    local dropgroup = DropGroupConfig[dropId]
    if not dropgroup then return end
    local job = LActor.getJob(actor)
    print (string.format("[%d]: type = %d", dropId, dropgroup.type))
    for i, group in ipairs(dropgroup.group) do
        local dropTable = DropTableConfig[group.id]
        print (string.format("  [第%d组]: type = %d id = %d rate = %f  {", i, dropTable.type, group.id, group.rate))
        for _, v in ipairs(dropTable.rewards) do
            print (string.format("    [%d]: type = %d rate = %f count = %d", v.id, v.type, v.rate, v.count))
        end
        print ("}")
    end
end

gmCmdHandlers.chongzhiAll = function (actor, args)
    local Svip = LActor.getSVipLevel(actor)
    if Svip >= 20 then return end
    for pay in pairs(PayMoneyConfig) do
        gmCmdHandlers.chongzhi(actor, {pay})
    end
    gmCmdHandlers.chongzhi(actor, {10000000})
    return true
end

gmCmdHandlers.wudi = function (actor, args)
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Fuben)
    local attrValue = tonumber(args[1]) or 0
    attr:Set(Attribute.atHpMax, attrValue * 20)
    attr:Set(Attribute.atAtkMin, attrValue)
    attr:Set(Attribute.atAtkMax, attrValue)
    attr:Set(Attribute.atDef, attrValue)
    attr:Set(Attribute.atAtkSuc, attrValue)
    attr:Set(Attribute.atDefSuc, attrValue)
    attr:Set(Attribute.atZYYJ, attrValue)
    attr:Set(Attribute.atHXYJ, attrValue)
    attr:Set(Attribute.atZMYJ, attrValue)
    attr:Set(Attribute.atWSYJ, attrValue)
    LActor.reCalcAttr(actor)
end

gmCmdHandlers.GmPosTest = function (actor, args)
    local t_ins = {}
    for fbId, Fconf in pairs(FubenConfig) do
        if fbId > 1000 then
            local hfuben = instancesystem.createFuBen(fbId)
            local ins = instancesystem.getInsByHdl(hfuben)
            local hscene = ins.scene_list[1]
            --local scene = Fuben.getScenePtr(handle)
            local k, sceneId = next(Fconf.scenes)
            local Sconf = ScenesConfig[sceneId]
            for _, pos in pairs(Sconf.enters) do
                --print ("~~~~~~~~~~~~",fbId,handle)
                if not Fuben.canMove(hscene, pos[1], pos[2]) then
                    utils.printInfo("[Err]    fbId", fbId, "sceneId", sceneId, "x", pos[1], "y", pos[2])
                    --return false
                end
            end
            ins:release()
        end
    end
    return true
end

gmCmdHandlers.testmail = function (actor, args)
    local head = "测试邮件一封"
    local context = "一封测试邮件"
    local appid = tonumber(args[1]) or ""
    local item_str = "0,2,500"
    System.addGlobalMail(head, context, appid, item_str)
end

gmCmdHandlers.exitActor = function (actor, args)
    LActor.exitFuben(actor)
    -- local hfuben = LActor.getFubenHandle(actor)
    -- local ins = instancesystem.getInsByHdl(hfuben)
    -- ins:release() --结束副本
    local hfuben = LActor.getFubenHandle(actor)
    local ins = instancesystem.getInsByHdl(hfuben)
    ins:release() --结束副本
    return true
end

gmCmdHandlers.addSkill = function(actor, args)
    local skill_id = tonumber(args[1])
    if skill_id == nil then
        print('skill_id==nil')
        return
    end
    
    local level = tonumber(args[2]) or 1
    
    local role = LActor.getRole(actor)
    LActor.addSkill(role, skill_id, level)
    
    return true
end

gmCmdHandlers.useSkill = function(actor, args)
    local skill_id = tonumber(args[1])
    if skill_id == nil then
        print('skill_id==nil')
        return
    end
    
    LActor.ClearCD(actor)
    
    local role = LActor.getRole(actor)
    LActor.useSkill(role, skill_id)
    return true
end

gmCmdHandlers.setAttr = function(actor, args)
    local tp = tonumber(args[1])
    if tp == nil then
        print('tp==nil')
        return
    end
    
    local val = tonumber(args[2])
    if val == nil then
        print('val==nil')
        return
    end
    
    local role = LActor.getMainRole(actor)
    LActor.setAttr(role, tp, val)
    return true
end

gmCmdHandlers.addEff = function(actor, args)
    local effid = tonumber(args[1]) or 0
    LActor.addSkillEffect(actor, effid)
    return true
end

actorCloneHandle = actorCloneHandle or 0
gmCmdHandlers.creatRobot = function(actor, args)
    local x, y = LActor.getEntityScenePoint(actor)
    local ins = instancesystem.getActorIns(actor)
    
    local roleCloneData = nil
    local actorData = nil
    local roleSuperData = nil
    local rivalId = 1
    roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(JjcRobotConfig, rivalId)
    
    if roleSuperData then
        roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
        roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end
    
    local actorid = rivalId
    local sceneHandle = ins.scene_list[1]
    local actorClone = LActor.createActorCloneWithData(actorid, sceneHandle, x, y, actorData, roleCloneData, roleSuperData)
    
    local roleClone = LActor.getRole(actorClone)
    if roleClone then
        LActor.setEntityScenePos(roleClone, x, y)
    end
    local yongbing = LActor.getYongbing(actorClone)
    if yongbing then
        LActor.setEntityScenePos(yongbing, x, y)
    end
    --定身
    --LActor.addSkillEffect(actorClone, JjcConstConfig.bindEffectId)
    LActor.setCamp(actorClone, CampType_Attack)
    print ("on create robot actorclone = ", actorClone)
    actorCloneHandle = LActor.getRealHandle(actorClone)
    print ("on create robot handle = ", actorCloneHandle)
    LActor.setSuperCloneChangeCD(actorClone, 99999)
    return true
end

gmCmdHandlers.getRobot = function(actor, args)
    local actorClone = LActor.getEntity(actorCloneHandle)
    print ("on getRobot actorCloneHandle = ", actorCloneHandle)
    print ("on getRobot actorclone = ", actorClone)
end

gmCmdHandlers.reBornRobot = function(actor, args)
    local actorClone = LActor.getEntity(actorCloneHandle)
    print("on reBornRobot isDeath", LActor.isDeath(actorClone))
    LActor.reborn(actorClone)
end

gmCmdHandlers.moveRobot = function(actor, args)
    local x, y = LActor.getEntityScenePos(actor)
    local actorClone = LActor.getEntity(actorCloneHandle)
    local role = LActor.getRole(actorClone)
    LActor.setEntityScenePos(role, x, y)
end

gmCmdHandlers.clearRobot = function(actor, args)
    local actorClone = LActor.getEntity(actorCloneHandle)
    local role = LActor.getRole(actorClone)
    LActor.clearAITarget(role)
end

gmCmdHandlers.moveSelf = function(actor, args)
    local x, y = LActor.getEntityScenePos(actor)
    local role = LActor.getRole(actor)
    LActor.setEntityScenePos(role, x + 5, y + 5)
end

gmCmdHandlers.enterFuben = function(actor, args)
    local x = tonumber(args[1]) or 26
    local y = tonumber(args[1]) or 25
    local fbHandle = instancesystem.createFuBen(TianXuanCommonConfig.fightFbId)
    if not fbHandle or fbHandle == 0 then
        print("enterFuben can not enter fbHandle =", fbHandle)
        return
    end
    LActor.enterFuBen(actor, fbHandle, 0, x, y)
end

gmCmdHandlers.killAllMonster = function(actor, args)
    local ins = instancesystem.getActorIns(actor)
    Fuben.killAllMonster(ins.scene_list[1])
end

gmCmdHandlers.actorAllLogin = function(actor, args)
    local maxCount = tonumber(args[1]) or 1
    print("actorAllLogin start ----------------")
    
    local db = System.createActorsDbConn()
    local ret = System.dbConnect(db)
    if not ret then
        print('actor allLogin error dbConnect fail ret=', ret)
        return
    end
    
    local err = System.dbQuery(db, 'SELECT `actorid`,`serverindex`,`pfid`,`appid` FROM actors')
    local count = System.dbGetRowCount(db)
    if count > 0 then
        local delay = 1000
        local row = System.dbCurrentRow(db)
        for i = 1, count do
            local actorid = tonumber(System.dbGetRow(row, 0))
            local serverid = tonumber(System.dbGetRow(row, 1))
            local pfid = System.dbGetRow(row, 2)
            local appid = System.dbGetRow(row, 3)
            if not LActor.getActorById(actorid) and System.getServerId() == serverid then
                print("index =",i,"actorid =", actorid, "serverid =", serverid)
                LActor.postScriptEventLite(nil, delay, function() System.ActorGMLogin(actorid, 0, serverid, "", pfid, appid) end)
                delay = delay + 1000
            end
            row = System.dbNextRow(db)
            if i >= maxCount then break end
        end
    end
    print("actorAllLogin end ----------------")
    return true
end

gmCmdHandlers.actorAllCross = function(actor, args)
    if System.isCommSrv() then
        local actors = System.getOnlineActorList()
        if actors then
            for _, nactor in ipairs(actors) do
                if actor ~= nactor then
                    local args = {
                        LActor.getActorId(nactor),
                        LActor.getServerId(nactor),
                        LActor.getPfId(nactor),
                        LActor.getAppId(nactor),
                    }
                    if mainscenefuben.reqEnterMainScene(nactor) then
                        SCTransferGM("actorAllCross", args)
                    end
                end
            end
            gmCmdHandlers.actorAllLogout()
        end
    elseif System.isBattleSrv() then
        local actorid = tonumber(args[1])
        local serverid = tonumber(args[2])
        local pfid = tonumber(args[3])
        local appid = tonumber(args[4])
        print("actorid =", actorid, "serverid =", serverid)
        LActor.postScriptEventLite(nil, 3000, function() System.ActorGMLogin(actorid, 0, serverid, "", pfid, appid) end)
    end
    return true
end

gmCmdHandlers.actorAllLianfu = function(actor, args)
    if System.isCommSrv() then
        local actors = System.getOnlineActorList()
        if actors then
            for _, nactor in ipairs(actors) do
                if actor ~= nactor then
                    local args = {
                        LActor.getActorId(nactor),
                        LActor.getServerId(nactor),
                        LActor.getPfId(nactor),
                        LActor.getAppId(nactor),
                    }
                    if lianfumainfuben.reqEnterMainScene(nactor) then
                        SCTransferGM("actorAllLianfu", args, true)
                    end
                end
            end
            gmCmdHandlers.actorAllLogout()
        end
    elseif System.isLianFuSrv() then
        local actorid = tonumber(args[1])
        local serverid = tonumber(args[2])
        local pfid = tonumber(args[3])
        local appid = tonumber(args[4])
        print("actorid =", actorid, "serverid =", serverid)
        LActor.postScriptEventLite(nil, 8000, function() System.ActorGMLogin(actorid, 0, serverid, "", pfid, appid) end)
    end
    return true
end

gmCmdHandlers.actorAllLogout = function(actor, args)
    print("actorAllLogout start ----------------")
    LActor.postScriptEventLite(nil, 3000, function() System.ActorGMLogout() end)
    print("actorAllLogout end   ----------------")
end

gmCmdHandlers.printbossinfo = function(actor, args)
    local ins = instancesystem.getActorIns(actor)
    print("*******boss_info*******")
    utils.printTable(ins.boss_info)
    print("***********************")
end

gmCmdHandlers.printYZTime = function(actor, args)
    local startTime = '2020.3.20-0:0'
    local Y, M, d, h, m = string.match(startTime, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
    local st = System.timeEncode(Y, M, d, h, m, 0)
    for season = 1, 40 do
        local seasonTime = {}
        seasonTime[1] = string.format("%d.%d.%d-%d:%d", System.timeDecode(st + (season - 1) * 3600 * 24 * 7 * 4))
        seasonTime[2] = string.format("%d.%d.%d-%d:%d", System.timeDecode(st + (season) * 3600 * 24 * 7 * 4))
        print("season =", season, "st =", seasonTime[1], "et=", seasonTime[2])
    end
end

gmCmdHandlers.actorClear = function(actor, args)
    gmCmdHandlers.lqclear(actor,{})
    gmCmdHandlers.purifyclean(actor,{})
    gmCmdHandlers.shenyuclear(actor,{})
    gmCmdHandlers.elementclear(actor,{})
    gmCmdHandlers.xunbaoclear(actor,{})
    gmCmdHandlers.skillclear(actor,{})
    gmCmdHandlers.clearbag(actor,{})
end

