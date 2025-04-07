
module("report" , package.seeall)



function getActorVar(actor)
	if not actor then return end

	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.report then var.report = {} end
    if not var.report.str then var.report.str = "" end
	return var.report	
end

function randomStr(len)
    math.randomseed(os.time())
    local rankStr = ""
    for i=1,len do
        local randNum = math.random(1,3)
        if randNum==1  then
            randNum=string.char(math.random(0,26)+65)
        elseif randNum==2 then
            randNum=string.char(math.random(0,26)+97)
        else
            randNum=math.random(0,9)
        end
        rankStr=rankStr..randNum
    end
    return rankStr  
end

function getActorIdCount(actorid)
    local total = 0
    for digit in string.gmatch(actorid, "%d") do
        total = total + 1
    end
    return total
end

function getStr(str)
    str = str..""
    local ret = ""
    for i=1,string.len(str) do
        ret = ret ..string.char(tonumber(string.sub(str,i,i))+65)
    end
    return ret
end

function onLogout(actor)
    local var = getActorVar(actor)    
    local webhost, webport = System.getWebServer()
    local pf = LActor.getPf(actor)
    local appid = LActor.getAppId(actor)
    local opendid = LActor.getAccountName(actor)
    local actorid = LActor.getActorId(actor)

	local temStr = "http://%s/%s/api/report?passId=%s&si=%s&bt=%s&openId=%s"
	local url = string.format(temStr, webhost, pf, appid, var.str, 0, opendid)
    print("xxxxxxxxxx", url)
	sendMsgToWeb(url)
end

function onLogin(actor)
    local var = getActorVar(actor)    
    local webhost, webport = System.getWebServer()
    local pf = LActor.getPf(actor)
    local appid = LActor.getAppId(actor)
    local opendid = LActor.getAccountName(actor)
    local actorid = LActor.getActorId(actor)

    var.str = getStr(System.getNowTime()) ..getStr(actorid)..randomStr(22-getActorIdCount(actorid)+1)
	local temStr = "http://%s/%s/api/report?passId=%s&si=%s&bt=%s&openId=%s"
	local url = string.format(temStr, webhost, pf, appid, var.str, 1, opendid)
    print("kkkkkkkkk", url)
	sendMsgToWeb(url)
end


actorevent.reg(aeUserLogin,onLogin)
actorevent.reg(aeUserLogout, onLogout)





