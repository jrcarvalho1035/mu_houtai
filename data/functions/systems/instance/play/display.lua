module("insdisplay", package.seeall)
setfenv(1, insdisplay)
setfunc = {}
notifyfunc = {}
packfunc = {}

require("protocol")
--local systemId = SystemId.fubenSystemId
local systemId = Protocol.CMD_Fuben
local protocol = nil --待定

--*********************************外部接口************************************--
--[[
table display{
	dtype:1-2(display type: 1:数字，2：倒计时)
	value:number
	ctype: 1-n(10-n?)(client type:与客户端显示配置对应，只要保证要统计的类型在客户端配置里都有定义，
				在服务端里和统计数据的类型配置不重复即可，服务端用来区分数据并分开保存)
}
]]
--设置显示信息
function setDisplay(ins, display)
	--[[if display == nil or display.dtype == nil or display.ctype == nil then return end
	local type = display.dtype
	if setfunc[type] then setfunc[type](ins, display) end

	if ins.display_info[type] == nil then
		ins.display_info[type] = {}
	end
	ins.display_info[type][display.ctype] = display

	--如果是倒计时类型
	if type == 2 then
		display.endtime = System.getNowTime() + tonumber(display.value)
	end
	notify(ins, display)
	--]]
end

--发送显示信息
function notifyDisplay(ins, actor)
	if FubenGroupAlias[FubenConfig[ins.id].group] and FubenGroupAlias[FubenConfig[ins.id].group].isshowtime == 0 then
		return
	end
	if actor ~= nil then
		--副本时间
		local tpack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_InsLeftTime)
		if tpack == nil then return end
		LDataPack.writeInt(tpack, ins.id)
		local leftTime = 0
		if ins.end_time > 0 then
			leftTime = ins.end_time - System.getNowTime()
			if leftTime < 0 then
				leftTime = 0
			end
		end
		LDataPack.writeInt(tpack, leftTime)
		LDataPack.flush(tpack)
	else
		for actorid,_ in pairs(ins.actor_list) do
			local actor = LActor.getActorById(actorid)
			if actor ~= nil then
				notifyDisplay(ins, actor)
			end
		end
	end
end

--独立发送倒计时
function fubenDaotime(actor, id, leftTime)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_InsLeftTime)
	LDataPack.writeInt(npack, id)
	LDataPack.writeInt(npack, leftTime)
	LDataPack.flush(npack)
end

--********************************************显示处理******************************************
--数值型
local notifynumber = function(ins, actor, display)
	local npack = LDataPack.allocPacket(actor, systemId, protocol)
	if npack == nil then return end
	local value = display.value
	if display.param ~= nil then
		if ins[display.param] == nil then print("ins display can't find param:"..display.param.."in fb:"..ins.id) return end
		value = tonumber(ins[display.param])
	end	
	LDataPack.writeShort(npack, ins.id)
	LDataPack.writeByte(npack, 1) --array count
	LDataPack.writeByte(npack, display.ctype)	
	LDataPack.writeInt(npack, value)
	LDataPack.flush(npack)
	print(string.format("event 5 notify: dtype(%d) value(%d) ctype(%d).", display.dtype, value, display.ctype))
end

--倒计时型
local notifytimer = function(ins, actor, display)
	local npack = LDataPack.allocPacket(actor, systemId, protocol)
	if npack == nil then return end
	LDataPack.writeShort(npack, ins.id)
	LDataPack.writeByte(npack, 1) --array count
	LDataPack.writeByte(npack, display.ctype)
	LDataPack.writeInt(npack, display.endtime - System.getNowTime())
	LDataPack.flush(npack)
	print(string.format("event 5 notify: dtype(%d) value(%d) ctype(%d).", display.dtype, display.endtime - System.getNowTime(), display.ctype))
end

notifyfunc[1] = notifynumber
notifyfunc[2] = notifytimer

function notify(ins, display)
	local type = display.dtype
	for actorid,_ in pairs(ins.actor_list) do
		local actor = LActor.getActorById(actorid)
		if actor ~= nil and notifyfunc[type] ~= nil then
			notifyfunc[type](ins, actor, display)
		end
	end
end

--********************************************包处理******************************************
--数值型
local packnumber = function(ins, actor, display, npack)
	local value = display.value
	if display.param ~= nil then
		if ins[display.param] == nil then print("ins display can't find param:"..display.param.."in fb:"..ins.id) return end
		value = tonumber(ins[display.param])
	end	
	LDataPack.writeByte(npack, display.ctype)	
	LDataPack.writeInt(npack, value)
end

--倒计时型
local packtimer = function(ins, actor, display, npack)
	LDataPack.writeByte(npack, display.ctype)
	LDataPack.writeInt(npack, display.endtime - System.getNowTime())
end

packfunc[1] = packnumber
packfunc[2] = packtimer
