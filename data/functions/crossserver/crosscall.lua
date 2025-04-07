module("crosscall" , package.seeall)

CallId = 
{
	CreateClone = 1,
}



CallFunc = 
{
	CreateClone,
}

CallFuncResp = 
{
	CreateCloneResp,
}

CallFuncReturn = 
{
	CreateCloneReturn,
}

uid = uid or 0
CrossAsynCallList = {}

function call(callId, ... )
	CallFunc[callId](...)
	uid = uid + 1
	CrossAsynCallList[uid] = {time = 0, func = CallFuncReturn[CallFunc], funcArg = arg}
end

function OnReturn()
end

-- function reg(funcCall, funcResp, funcCallBack)
-- 	table.insert(crossCallFunc, {time = 0, funcs = {funcCall, funcResp, funcCallBack}})
--     if asynEvents[tarid] == nil then
--         asynEvents[tarid] = {}
--         table.insert(asynEvents[tarid], {func, arg})
--         LActor.regAsynEvent(tarid)
--     else
-- 	    table.insert(asynEvents[tarid], {func, arg})
--     end
-- 	print( tarid .. " asynevent.reg: ok")
-- end


--[[异步处理函数格式
 -function (tarActor, ...)
    tarActor 要处理的角色
    args
 -end
--]]


--actor调用者
--tarId需要处理的玩家id
--func回调函数
--...自定义参数
function reg(tarid, func, ...)
    if asynEvents[tarid] == nil then
        asynEvents[tarid] = {}
        table.insert(asynEvents[tarid], {func, arg})
        LActor.regAsynEvent(tarid)
    else
	    table.insert(asynEvents[tarid], {func, arg})
    end
	print( tarid .. " asynevent.reg: ok")
end

--actor 触发者
local function onEvent(actor)
	local aid = LActor.getActorId(actor)
    if asynEvents[aid] == nil then return end
    for _, v in ipairs(asynEvents[aid]) do
        v[1](actor, unpack(v[2]))
    end
    asynEvents[aid] = nil
	print( aid .. " asynevent.onEvent: ok")
end


_G.onAsynEvent = onEvent
