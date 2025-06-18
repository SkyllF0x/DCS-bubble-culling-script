local deactivateGroups = true --if true will deactivate group back when range > activationRange + deactivateMargin
local deactivateMargin = 18520 --10nm 
local stepTime = 30 --time between checks in seconds

local groupsList = {}
local aliveGroupList = {}
local weaponsList = {}

BubbleSystem = {
    debugOn = false
}

function BubbleSystem:countKeyVals(tbl)
    local counter = 0
    for _, item in pairs(tbl) do 
        counter = counter + 1
    end
    return counter
end

function BubbleSystem:printDebug(msg)
    env.info("Bubble script: " .. msg)

    if not self.debugOn then 
        return
    end

    trigger.action.outText(msg, 30)
end

function BubbleSystem:enableDebug(value)
    self.debugOn = value
end

function BubbleSystem:_addGroup(group, prefix, range, iads, callbackA, callbackB, onlyForPlayers)
    if not string.find(group:getName(), prefix) and not group:getName() == prefix then return end
    if not mist.getGroupTable(group:getName()) or not mist.getGroupTable(group:getName()).lateActivation then
        --group not use late activation
        BubbleSystem:printDebug("Group not use lateActivation, add to alive: " .. group:getName())
        if not aliveGroupList[prefix] then 
        aliveGroupList[prefix] = {}
        end
        aliveGroupList[prefix][group:getID()] = group
     end

    if not groupsList[prefix] then
        groupsList[prefix] = {
        groups = {}, 
        activationRange = range, 
        addToIADS = iads, 
        callbackA = callbackA, 
        callbackB = callbackB, 
        onlyForPlayers = onlyForPlayers}
        if not aliveGroupList[prefix] then 
            aliveGroupList[prefix] = {}
        end
    end 
    BubbleSystem:printDebug("Group added, prefix: " .. prefix .. " group: " .. group:getName())
    groupsList[prefix].groups[group:getID()] = group
end

function BubbleSystem:findRange(group) 
    local maxRange = 20000
    for _, unit in pairs(group:getUnits()) do
        if unit:getAmmo() then
            for _, ammo in pairs(unit:getAmmo()) do 
                if ammo.desc and (ammo.desc.rangeMaxAltMax or 20000) > maxRange then 
                    maxRange = ammo.desc.rangeMaxAltMax or 20000
                end
            end
        end
    end
    return maxRange
end

function BubbleSystem:isEW(group) 
    for _, unit in pairs(group:getUnits()) do 
        if unit:hasAttribute("EWR") then 
            return true
        end
    end
    
    return false
end

function BubbleSystem:addGroups(coal) 

    for _, group in pairs(coalition.getGroups(coal, Group.Category.GROUND)) do 
        
        if not BubbleSystem:isEW(group) then
            local res, range  = pcall(function() return BubbleSystem:findRange(group) end)
            if not res then 
                range = 20000
            end
            
            BubbleSystem:printDebug(group:getName() .. " range " .. tostring(range))
            BubbleSystem:_addGroup(group, group:getName(), range, iads)
        end
    end
end

function BubbleSystem:checkActivateGroup(group, range, forPlayers)
    
    --check aircraft/helos
    for _, coal in pairs({coalition.side.RED, coalition.side.BLUE}) do 

        for _, groupType in pairs({Group.Category.AIRPLANE, Group.Category.HELICOPTER}) do 
           
            for _, threatGroup in pairs(coalition.getGroups(coal, groupType)) do 

                if group:getCoalition() ~= coal then

                    for _, unit in pairs(threatGroup:getUnits()) do 

                        if (not forPlayers or unit:getPlayerName()) and
                            mist.utils.get2DDist(unit:getPoint(), group:getUnit(1):getPoint()) < range 
                            then 
                            return true
                        end
                    end
                end
            end
        end

    end
    
    
    if forPlayers then 
        return
    end
    --check weapons
    local wpn = {}
    for _, weapon in pairs(weaponsList) do 

        if weapon:isExist() then 

            wpn[#wpn+1] = weapon
            if group:getCoalition() ~= weapon:getCoalition() 
                and mist.utils.get2DDist(weapon:getPoint(), group:getUnit(1):getPoint()) < range then
                    return true
            end
        end
    end
    weaponsList = wpn

    return false
end

function BubbleSystem:checkDeactivateGroup(group, range, forPlayers)
    return not BubbleSystem:checkActivateGroup(group, range + deactivateMargin, forPlayers)
end

function BubbleSystem:addGroupsByPrefix(prefix, activateRange, iads, callbackActivate, callbackDeactivate, onlyPlayers)

    for _, coal in pairs({coalition.side.RED, coalition.side.BLUE}) do
        for _, group in pairs(coalition.getGroups(coal, Group.Category.GROUND)) do 

            BubbleSystem:_addGroup(group, prefix, activateRange, iads, callbackActivate, callbackDeactivate, onlyPlayers)
        end
    end

    if groupsList[prefix] then 
        BubbleSystem:printDebug("Added groups with prefix: " .. " '" .. prefix .. "' count: " .. tostring(BubbleSystem:countKeyVals(groupsList[prefix].groups)))
    end
end


function BubbleSystem:start()
    timer.scheduleFunction(BubbleSystem.mainloop, BubbleSystem, timer.getTime() + 1)
end

function BubbleSystem:mainloop()
    
    local protectedWrapper = function ()
        
        --check groups not active groups
        for prefix, groupData in pairs(groupsList) do 
            for id, polledGroup in pairs(groupData.groups) do 
                
                if not polledGroup or not polledGroup:isExist() then 
                    BubbleSystem:printDebug("Group already dead(id): " .. tostring(id))
                    groupData.groups[id] = nil

                elseif BubbleSystem:checkActivateGroup(polledGroup, groupData.activationRange, groupData.onlyForPlayers) then 
                    BubbleSystem:printDebug("Activate group: " .. polledGroup:getName())
                    polledGroup:activate()
                    
                    local IADS_SAM = nil
                    --add to iads
                    if groupData.addToIADS then 
                        BubbleSystem:printDebug("Add to iads: " .. polledGroup:getName())
                        IADS_SAM = groupData.addToIADS:addSAMSite(polledGroup:getName())
                    end

                    groupData.groups[polledGroup:getID()] = nil
                    aliveGroupList[prefix][polledGroup:getID()] = polledGroup

                    if groupData.callbackA then 
                        groupData.callbackA({group = polledGroup, iads = groupData.addToIADS, iadsSam = IADS_SAM})
                    end
                end
            end
                        
            if deactivateGroups then
                
                --check for deactivation
                for id, polledGroup in pairs(aliveGroupList[prefix]) do 
                    
                    if not polledGroup or not polledGroup:isExist() then 
                        BubbleSystem:printDebug("Alive group dead(id): " .. tostring(id))
                        aliveGroupList[prefix][id] = nil
                    elseif BubbleSystem:checkDeactivateGroup(polledGroup, groupData.activationRange, groupData.onlyForPlayers) then 
                        
                        aliveGroupList[prefix][id] = nil
                        local name = polledGroup:getName()
                        local groupTable = mist.getCurrentGroupData(name)

                        if groupData.addToIADS then 
                            --delete from iads
                            local sites = groupData.addToIADS.samSites
                            for i = 1, #sites do 

                                if sites[i]:getDCSRepresentation() == polledGroup then 
                                    table.remove(sites, i)
                                    break
                                end
                            end
                        end
                        polledGroup:destroy()--delete original

                        --enable late activation 
                        groupTable.lateActivation = true
                        groupTable.visible = true

                        --spawn again
                        mist.dynAdd(groupTable)
                        local newGroup = Group.getByName(name)
                        groupData.groups[newGroup:getID()] = newGroup

                        if groupData.callbackB then 
                            groupData.callbackB({group = polledGroup, newGroup = newGroup})
                        end
                        BubbleSystem:printDebug("Deactivate group: " .. name)
                    end
                end
            end
        end
    end

    local result, error = xpcall(protectedWrapper, debug.traceback)
    if not result then 
        local msg = "Buble script: error in mainloop: " .. tostring(error)
        env.warning(msg)
        BubbleSystem:printDebug(msg )
    end
    return timer.getTime() + stepTime
end

local eventHandler = {}

function  eventHandler:protectedHandler(e)
        
    if e.id == 1 and e.weapon and e.weapon:getDesc().category == Weapon.Category.MISSILE then 
        weaponsList[#weaponsList+1] = e.weapon
    end

    if e.id == 12 then 
        world.removeEventHandler(eventHandler)
    end 

end

function eventHandler:onEvent(e)
    local result, error = pcall(eventHandler.protectedHandler, self, e)
    if not result then 
        local msg = "Bubble script: error in event handler: " .. tostring(error)
        BubbleSystem:printDebug(msg)
        env.warning(msg)
    end
end


world.addEventHandler(eventHandler)