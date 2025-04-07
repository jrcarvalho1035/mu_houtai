--圣物系统
module("aoyisystem", package.seeall)

function updateAttr(actor, calc)
    local addAttrs = {}
    local power = 0
    for k,v in pairs(AoyiConfig) do
        for kk,vv in pairs(v) do
            local conf = SkillPassiveConfig[kk][passiveskill.getSkillLv(actor, kk)]
            if conf.type == 1 then
                for __,attr in ipairs(conf.addattr) do
                    addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value                
                end			
            end
            power = power + conf.power
        end
    end
    
	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Aoyi)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
    end
    attr:SetExtraPower(power)
	if calc then
		LActor.reCalcAttr(actor)
	end
end


function onInit(actor)
    updateAttr(actor)
end

actorevent.reg(aeInit, onInit)
