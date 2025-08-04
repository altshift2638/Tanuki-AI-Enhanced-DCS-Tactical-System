-- Tanuki AI Lifelike Defense System v3.0
-- Advanced Tactical AI System
-- FIXED FOR DCS 2.9

-- ========== AI ENHANCEMENT SYSTEM ========== --
-- Configuration Options
local AGGRESSION_LEVELS = {
    ACE = {reaction = 3, maneuver = 3, roe = 0},
    VETERAN = {reaction = 3, maneuver = 3, roe = 0},
    REGULAR = {reaction = 2, maneuver = 2, roe = 0},
    ROOKIE = {reaction = 1, maneuver = 1, roe = 0}
}

local FATIGUE_FACTORS = {
    COMBAT = 0.15,
    PATROL = 0.03,
    RECOVERY = 0.20
}

local PILOT_SKILLS = {
    FIGHTER = {min = 0.65, max = 0.98},
    BOMBER = {min = 0.45, max = 0.88},
    HELICOPTER = {min = 0.55, max = 0.92},
    ATTACK = {min = 0.60, max = 0.90}
}

local TACTICAL_PROFILES = {
    INTERCEPTOR = {
        attack = {minRange = 15000, maxRange = 80000, preference = "BVR"},
        defense = {evade = "BEAM", countermeasure = "FLARE_CHAFF"}
    },
    AIR_SUPERIORITY = {
        attack = {minRange = 5000, maxRange = 50000, preference = "BVR"},
        defense = {evade = "NOTCH", countermeasure = "CHAFF"}
    },
    STRIKE = {
        attack = {minRange = 5000, maxRange = 30000, preference = "PRECISION"},
        defense = {evade = "TERRAIN", countermeasure = "FLARE"}
    },
    CAS = {
        attack = {minRange = 1000, maxRange = 10000, preference = "GUNS_ROCKETS"},
        defense = {evade = "TERRAIN", countermeasure = "FLARE"}
    },
    SEAD = {
        attack = {minRange = 15000, maxRange = 60000, preference = "STANDOFF"},
        defense = {evade = "BEAM", countermeasure = "CHAFF"}
    }
}

local aiState = {}
local pilotSkills = {}

-- ========== CORE FUNCTIONS ========== --
function InitializeAIGroup(group)
    if not group or not group:isExist() then return end
    
    local groupName = group:getName()
    local unit = group:getUnit(1)
    if not unit then return end
    
    local unitType = unit:getTypeName()
    local skillLevel
    
    -- Determine pilot skill based on aircraft type
    if string.find(unitType, "fighter") or string.find(unitType, "interceptor") then
        skillLevel = math.random() * (PILOT_SKILLS.FIGHTER.max - PILOT_SKILLS.FIGHTER.min) + PILOT_SKILLS.FIGHTER.min
    elseif string.find(unitType, "bomber") then
        skillLevel = math.random() * (PILOT_SKILLS.BOMBER.max - PILOT_SKILLS.BOMBER.min) + PILOT_SKILLS.BOMBER.min
    elseif string.find(unitType, "helicopter") then
        skillLevel = math.random() * (PILOT_SKILLS.HELICOPTER.max - PILOT_SKILLS.HELICOPTER.min) + PILOT_SKILLS.HELICOPTER.min
    else
        skillLevel = math.random() * (PILOT_SKILLS.ATTACK.max - PILOT_SKILLS.ATTACK.min) + PILOT_SKILLS.ATTACK.min
    end
    
    -- Initialize AI state
    aiState[groupName] = {
        isActive = true,
        skillLevel = skillLevel,
        fatigue = 0,
        threatLevel = 0,
        combatTime = 0,
        lastUpdate = timer.getTime(),
        lastTacticChange = 0,
        currentTactic = "PATROL",
        tacticalProfile = "AIR_SUPERIORITY"
    }
    
    -- Set initial ROE based on skill
    local controller = group:getController()
    if controller then
        controller:setOption(AI.Option.Air.id.ROE, AGGRESSION_LEVELS.REGULAR.roe)
    end
    
    env.info("Tanuki AI: Initialized "..groupName.." (Skill: "..string.format("%.1f", skillLevel*100).."%)")
end

function ApplyTacticSettings(group, tactic)
    if not group or not group:isExist() then return end
    
    local controller = group:getController()
    if not controller then return end
    
    -- Set engagement options based on tactic
    if tactic == "BVR_ENGAGEMENT" then
        controller:setOption(AI.Option.Air.id.ENGAGE_RANGE, AI.Option.Air.val.ENGAGE_RANGE.LONG_RANGE)
        controller:setOption(AI.Option.Air.id.ENGAGE_AIR_WEAPONS, 1)
    elseif tactic == "DOGFIGHT" then
        controller:setOption(AI.Option.Air.id.ENGAGE_RANGE, AI.Option.Air.val.ENGAGE_RANGE.MEDIUM_RANGE)
        controller:setOption(AI.Option.Air.id.ENGAGE_AIR_WEAPONS, 1)
    elseif tactic == "GROUND_ATTACK" then
        controller:setOption(AI.Option.Air.id.ENGAGE_GROUND_WEAPONS, 1)
        controller:setOption(AI.Option.Air.id.ENGAGE_AIR_WEAPONS, 0)
    else -- PATROL/INTERCEPT
        controller:setOption(AI.Option.Air.id.ENGAGE_RANGE, AI.Option.Air.val.ENGAGE_RANGE.MEDIUM_RANGE)
    end
end

function EvaluateTacticalSituation(group)
    if not group or not group:isExist() then return "PATROL" end

    local groupName = group:getName()
    local state = aiState[groupName]
    if not state or not state.isActive then return "PATROL" end

    local coalitionSide = group:getCoalition()
    if not coalitionSide then
        env.warning("Tanuki AI: Group '" .. groupName .. "' has no valid coalition.")
        return "PATROL"
    end

    local now = timer.getTime()
    if now - state.lastTacticChange < 30 then
        return state.currentTactic
    end

    local unit = group:getUnit(1)
    if not unit then return state.currentTactic end
    local pos = unit:getPoint()
    local alt = pos.y

    local threats = {}
    local threatDistance = 999999
    local enemyCoalition = coalition.getOppositeCoalition(coalitionSide)
    local enemyGroups = coalition.getGroups(enemyCoalition, Group.Category.AIRPLANE)

    for _, enemyGroup in pairs(enemyGroups) do
        if enemyGroup:isExist() then
            local enemyUnit = enemyGroup:getUnit(1)
            if enemyUnit then
                local enemyPos = enemyUnit:getPoint()
                local dist = math.sqrt((pos.x - enemyPos.x)^2 + (pos.z - enemyPos.z)^2)
                if dist < 80000 then
                    threats[#threats + 1] = { group = enemyGroup, distance = dist, position = enemyPos }
                    if dist < threatDistance then
                        threatDistance = dist
                    end
                end
            end
        end
    end

    local newTactic = state.currentTactic
    local profile = TACTICAL_PROFILES[state.tacticalProfile]

    if #threats > 0 then
        if threatDistance < 15000 then
            newTactic = "DOGFIGHT"
        elseif threatDistance < profile.attack.maxRange and threatDistance > profile.attack.minRange then
            if profile.attack.preference == "BVR" then
                newTactic = "BVR_ENGAGEMENT"
            else
                newTactic = "STANDOFF_ATTACK"
            end
        else
            newTactic = "INTERCEPT"
        end
    elseif alt < 1000 and (state.tacticalProfile == "CAS" or state.tacticalProfile == "STRIKE") then
        newTactic = "GROUND_ATTACK"
    else
        newTactic = "PATROL"
    end

    if newTactic ~= state.currentTactic then
        state.currentTactic = newTactic
        state.lastTacticChange = now
        ApplyTacticSettings(group, newTactic)
        env.info("Tanuki AI: "..groupName.." changing tactic to "..newTactic)
    end

    return newTactic
end

function AdaptiveTactics(group)
    if not group or not group:isExist() then 
        return 
    end
    
    local groupName = group:getName()
    local state = aiState[groupName]
    if not state or not state.isActive then return end
    
    local controller = group:getController()
    if not controller then return end
    
    local skill = state.skillLevel or 0.7
    local fatigue = state.fatigue or 0
    
    -- Calculate effective skill (skill minus fatigue impact)
    local effectiveSkill = skill - (fatigue * 0.4)
    effectiveSkill = math.max(0.3, math.min(0.98, effectiveSkill))
    
    -- Adjust reaction based on situation
    local reactionLevel
    if state.threatLevel > 0.7 then
        reactionLevel = AI.Option.Air.val.ROE.WEAPON_FREE  -- Aggressive under high threat
    else
        reactionLevel = math.random() < effectiveSkill and 
                        AI.Option.Air.val.ROE.WEAPON_FREE or 
                        AI.Option.Air.val.ROE.WEAPON_HOLD
    end
    controller:setOption(AI.Option.Air.id.ROE, reactionLevel)
    
    -- Random human-like hesitation (less frequent for skilled pilots)
    if math.random() < (0.35 - effectiveSkill * 0.25) then
        local hesitationTime = math.random(2, 6)
        
        -- Only apply hesitation if not in immediate danger
        if state.threatLevel < 0.6 then
            timer.scheduleFunction(function()
                if group and group:isExist() and aiState[groupName] then
                    local c = group:getController()
                    if c then
                        c:setOption(AI.Option.Air.id.ROE, reactionLevel)  -- Restore reaction
                        env.info("Tanuki AI: "..groupName.." recovered from hesitation")
                    end
                end
                return nil
            end, nil, timer.getTime() + hesitationTime)
            
            controller:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.RETURN_FIRE)  -- Temporarily reduce reaction
            env.info("Tanuki AI: "..groupName.." experiencing combat hesitation")
        end
    end
    
    -- Schedule next adjustment
    timer.scheduleFunction(function()
        AdaptiveTactics(group)
        return nil
    end, nil, timer.getTime() + math.random(8, 15))
end

-- Fatigue Simulation
function UpdateFatigue(group)
    if not group or not group:isExist() then 
        return 
    end
    
    local groupName = group:getName()
    local state = aiState[groupName]
    if not state or not state.isActive then return end
    
    local now = timer.getTime()
    local timeDiff = now - state.lastUpdate
    state.lastUpdate = now
    
    -- Update fatigue based on combat status
    if state.threatLevel > 0.7 then
        state.fatigue = state.fatigue + (FATIGUE_FACTORS.COMBAT * timeDiff/60)
        state.combatTime = (state.combatTime or 0) + timeDiff
    elseif state.threatLevel > 0.4 then
        state.fatigue = state.fatigue + (FATIGUE_FACTORS.PATROL * timeDiff/60)
    else
        state.fatigue = math.max(0, state.fatigue - (FATIGUE_FACTORS.RECOVERY * timeDiff/60))
    end
    
    -- Cap fatigue at 1.0
    state.fatigue = math.min(1.0, math.max(0, state.fatigue))
    
    -- Fatigue effects (only apply if fatigue > 0.6)
    if state.fatigue > 0.6 then
        local controller = group:getController()
        if controller then
            -- Reduced awareness when fatigued
            controller:setOption(AI.Option.Air.id.RADAR_USING, 
                               math.random() < (0.8 - state.fatigue*0.3) and 1 or 0)
            controller:setOption(AI.Option.Air.id.FLARE_USING, 
                               math.random() < (0.75 - state.fatigue*0.25) and 1 or 0)
        end
        
        if math.random() < 0.25 then
            env.info("Tanuki AI: "..groupName.." showing fatigue ("..string.format("%.0f%%", state.fatigue*100)..")")
        end
    end
    
    -- Schedule next update
    timer.scheduleFunction(function()
        UpdateFatigue(group)
        return nil
    end, nil, timer.getTime() + math.random(30, 60))
end

-- Enhanced Threat Assessment
function AssessThreats()
    local now = timer.getTime()
    
    for groupName, state in pairs(aiState) do
        if state.isActive then
            local group = Group.getByName(groupName)
            if group and group:isExist() then
                -- Threat decay
                state.threatLevel = state.threatLevel * 0.85
                
                -- Random threat spikes (less frequent)
                if math.random() < 0.07 then
                    state.threatLevel = math.min(1.0, state.threatLevel + math.random() * 0.3)
                end
                
                -- Increase threat if in combat recently
                if state.combatTime and state.combatTime > 0 then
                    state.threatLevel = math.min(1.0, state.threatLevel + 0.15)
                    state.combatTime = state.combatTime * 0.5  -- Decay combat time
                end
            else
                state.isActive = false  -- Mark inactive if group doesn't exist
            end
        end
    end
    
    -- Clean up inactive groups
    for groupName, state in pairs(aiState) do
        if not state.isActive then
            aiState[groupName] = nil
            if pilotSkills[groupName] then
                pilotSkills[groupName] = nil
            end
        end
    end
    
    timer.scheduleFunction(AssessThreats, nil, timer.getTime() + math.random(4, 8))
end

-- DCS 2.9 COMPATIBLE EVENT HANDLER
local tanukiEventHandler = {}
function tanukiEventHandler:onEvent(event)
    if event.id == world.event.S_EVENT_BIRTH then
        local unit = event.initiator
        if unit then
            local group = unit:getGroup()
            if group and group:isExist() and group:getCategory() == Group.Category.AIRPLANE then
                InitializeAIGroup(group)
                AdaptiveTactics(group)
                UpdateFatigue(group)
            end
        end
    end
end

-- Main Initialization
function ApplyLifelikeDefenseToAll()
    -- Blue coalition aircraft
    local blueGroups = coalition.getGroups(coalition.side.BLUE, Group.Category.AIRPLANE)
    if blueGroups then
        for _, group in pairs(blueGroups) do
            if group:isExist() then
                InitializeAIGroup(group)
                AdaptiveTactics(group)
                UpdateFatigue(group)
            end
        end
    end

    -- Red coalition aircraft
    local redGroups = coalition.getGroups(coalition.side.RED, Group.Category.AIRPLANE)
    if redGroups then
        for _, group in pairs(redGroups) do
            if group:isExist() then
                InitializeAIGroup(group)
                AdaptiveTactics(group)
                UpdateFatigue(group)
            end
        end
    end
    
    -- Start threat assessment
    timer.scheduleFunction(AssessThreats, nil, timer.getTime() + 5)
    
    -- Register event handler for DCS 2.9
    world.addEventHandler(tanukiEventHandler)
end

-- ========== MAIN INITIALIZATION ========== --
local function delayedStart()
    if coalition.getGroups then
        trigger.action.outText("⚡ TANUKI AI v3.0 ACTIVATED ⚡\n🤖 Adaptive Tactics | 😴 Fatigue System | 🎯 Precision AI", 20)
        env.info("Tanuki AI: Initializing enhanced AI systems")
        
        -- Initialize AI system
        ApplyLifelikeDefenseToAll()
    else
        env.warning("Tanuki AI: Coalition not ready, retrying in 5 seconds.")
        timer.scheduleFunction(delayedStart, {}, timer.getTime() + 5)
    end
    return nil
end

-- Start everything after 10 seconds
timer.scheduleFunction(delayedStart, {}, timer.getTime() + 10)