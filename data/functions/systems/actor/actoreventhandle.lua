module("actoreventhandle", package.seeall)

local function ehNotifyFacade(actor)
	LActor.notifyFacade(actor)
end

local function ehLevelUp( actor, level, oldLevel)
	if level >= 400 and LActor.getAccountName(actor) == 'yy1'then
		System.closeActor(actor)
	end
end

local function ehLogin( actor )
	if LActor.getLevel(actor) >= 400 and tostring(LActor.getAccountName(actor)) == 'yy1' then
		System.closeActor(actor)
	end
end

actorevent.reg(aeNotifyFacade, ehNotifyFacade)
actorevent.reg(aeLevel, ehLevelUp)
actorevent.reg(aeUserLogin, ehLogin)
