-- Tanuki AI Enhanced DCS Tactical System v3.5
-- Advanced Tactical AI System with Enhanced Defense
-- COMPLETE SELF-CONTAINED SYSTEM - NO EXTERNAL DEPENDENCIES

-- ========== COALITION HELPER FUNCTIONS ========== --
local function getEnemyCoalition(coalitionSide)
    if coalitionSide == coalition.side.BLUE then
        return coalition.side.RED
    elseif coalitionSide == coalition.side.RED then
        return coalition.side.BLUE
    end
    return coalition.side.NEUTRAL
end

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

-- ========== ENHANCED DEFENSIVE SYSTEMS ========== --
local DEFENSIVE_PROFILES = {
    EVASIVE_MANEUVER = {
        "BEAM", "NOTCH", "CORKSCREW", "SNAKE", "JINK"
    },
    COUNTERMEASURE_PROFILES = {
        HEAVY = {flare = 8, chaff = 8, interval = 0.5, duration = 4},
        MODERATE = {flare = 4, chaff = 4, interval = 1, duration = 3},
        LIGHT = {flare = 2, chaff = 2, interval = 2, duration = 2}
    }
}

local aiState = {}
local tanukiEventHandler = {}

-- ========== CORE FUNCTIONS ========== --
function InitializeAIGroup(group)
    if not group or not group:isExist() then 
        env.warning("Tanuki AI: InitializeAIGroup called with invalid group")
        return 
    end
    
    local groupName = group:getName()
    local unit = group:getUnit(1)
    if not unit then 
        env.warning("Tanuki AI: Group "..groupName.." has no units")
        return 
    end
    
    local unitType = unit:getTypeName()
    local skillLevel
    
    -- Determine pilot skill based on aircraft type (case-insensitive)
    local unitTypeLower = unitType and unitType:lower() or "fighter"
    if string.find(unitTypeLower, "fighter") or string.find(unitTypeLower, "interceptor") then
        skillLevel = math.random() * (PILOT_SKILLS.FIGHTER.max - PILOT_SKILLS.FIGHTER.min) + PILOT_SKILLS.FIGHTER.min
    elseif string.find(unitTypeLower, "bomber") then
        skillLevel = math.random() * (PILOT_SKILLS.BOMBER.max - PILOT_SKILLS.BOMBER.min) + PILOT_SKILLS.BOMBER.min
    elseif string.find(unitTypeLower, "helicopter") then
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
        tacticalProfile = "AIR_SUPERIORITY",
        lastThreatTime = 0,
        missileAlert = false
    }
    
    -- Set initial ROE based on skill
    local controller = group:getController()
    if controller then
        controller:setOption(AI.Option.Air.id.ROE, AGGRESSION_LEVELS.REGULAR.roe)
        env.info("Tanuki AI: Initialized "..groupName.." (Skill: "..string.format("%.1f", skillLevel*100).."%)")
    else
        env.warning("Tanuki AI: No controller for group "..groupName)
    end
end

function ApplyTacticSettings(group, tactic)
    if not group or not group:isExist() then 
        env.warning("Tanuki AI: ApplyTacticSettings called with invalid group")
        return 
    end
    
    local controller = group:getController()
    if not controller then 
        env.warning("Tanuki AI: No controller for group "..group:getName())
        return 
    end
    
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

-- Enhanced threat detection with missile warning
function DetectIncomingThreats(group)
    if not group or not group:isExist() then 
        env.warning("Tanuki AI: DetectIncomingThreats called with invalid group")
        return false, 0 
    end
    
    local groupName = group:getName()
    local state = aiState[groupName]
    if not state then 
        env.warning("Tanuki AI: No state for group "..groupName)
        return false, 0 
    end
    
    local unit = group:getUnit(1)
    if not unit then 
        env.warning("Tanuki AI: Group "..groupName.." has no units")
        return false, 0 
    end
    
    local pos = unit:getPoint()
    local coalitionSide = group:getCoalition()
    if not coalitionSide then
        env.warning("Tanuki AI: Group "..groupName.." has no coalition")
        return false, 0 
    end
    
    local enemyCoalition = getEnemyCoalition(coalitionSide)
    local missileThreat = false
    local highestThreat = state.threatLevel
    
    -- Check for incoming threats using robust detection
    local controller = unit:getController()
    if controller then
        local success, knownTargets = pcall(function() return controller:getDetectedTargets() end)
        
        if success and knownTargets then
            for _, target in pairs(knownTargets) do
                if target.object and target.object:isExist() then
                    local targetObj = target.object
                    local targetCat = targetObj:getCategory()
                    
                    -- Check if target is a weapon (missile)
                    if targetCat == Object.Category.WEAPON then
                        local targetType = targetObj:getTypeName()
                        targetType = targetType and targetType:lower() or ""
                        
                        if string.find(targetType, "missile") or 
                           string.find(targetType, "rocket") or
                           string.find(targetType, "aam") or
                           string.find(targetType, "sam") then
                            
                            local targetPos = targetObj:getPoint()
                            local dist = math.sqrt((pos.x - targetPos.x)^2 + (pos.z - targetPos.z)^2)
                            
                            -- Detect missiles within 15km
                            if dist < 15000 then
                                missileThreat = true
                                highestThreat = math.max(highestThreat, 0.9)
                                
                                -- Update threat level immediately
                                state.threatLevel = math.max(state.threatLevel, 0.9)
                                state.lastThreatTime = timer.getTime()
                                
                                -- Trigger defensive reaction
                                if dist < 8000 then
                                    return true, 1.0  -- Critical threat
                                end
                            end
                        end
                    end
                end
            end
        else
            -- Fallback threat detection for older DCS versions
            local now = timer.getTime()
            if now - state.lastThreatTime > 10 then
                -- Simulate random threat spikes
                if math.random() < 0.15 then
                    state.threatLevel = math.min(1.0, state.threatLevel + math.random() * 0.3)
                    missileThreat = true
                end
            end
        end
    end
    
    return missileThreat, highestThreat
end

-- Enhanced defensive reaction system
function ExecuteDefensiveManeuvers(group, threatLevel)
    if not group or not group:isExist() then 
        env.warning("Tanuki AI: ExecuteDefensiveManeuvers called with invalid group")
        return 
    end
    
    local groupName = group:getName()
    local state = aiState[groupName]
    if not state then 
        env.warning("Tanuki AI: No state for group "..groupName)
        return 
    end
    
    local controller = group:getController()
    if not controller then 
        env.warning("Tanuki AI: No controller for group "..groupName)
        return 
    end
    
    -- Select defensive profile based on threat level
    local profile
    if threatLevel > 0.8 then
        profile = DEFENSIVE_PROFILES.COUNTERMEASURE_PROFILES.HEAVY
        -- Use aggressive evasive maneuvers
        pcall(function() 
            controller:setOption(AI.Option.Air.id.REACTION_TO_THREAT, AI.Option.Air.val.REACTION_TO_THREAT.EVADE_FIRE)
        end)
    elseif threatLevel > 0.5 then
        profile = DEFENSIVE_PROFILES.COUNTERMEASURE_PROFILES.MODERATE
        pcall(function() 
            controller:setOption(AI.Option.Air.id.REACTION_TO_THREAT, AI.Option.Air.val.REACTION_TO_THREAT.EVADE)
        end)
    else
        profile = DEFENSIVE_PROFILES.COUNTERMEASURE_PROFILES.LIGHT
    end
    
    -- Execute countermeasure program
    pcall(function() 
        controller:setOption(AI.Option.Air.id.ECM_USING, 1)
        controller:setOption(AI.Option.Air.id.FLARE_USING, 1)
        controller:setOption(AI.Option.Air.id.CHAFF_USING, 1)
    end)
    
    -- Advanced countermeasures based on tactical profile
    local cmProfile = "FLARE_CHAFF"
    if TACTICAL_PROFILES[state.tacticalProfile] and TACTICAL_PROFILES[state.tacticalProfile].defense then
        cmProfile = TACTICAL_PROFILES[state.tacticalProfile].defense.countermeasure or "FLARE_CHAFF"
    end
    
    pcall(function()
        if cmProfile == "FLARE_CHAFF" then
            controller:setCountermeasures(profile.chaff, profile.flare, profile.interval, profile.duration)
        elseif cmProfile == "FLARE" then
            controller:setCountermeasures(0, profile.flare * 1.5, profile.interval, profile.duration)
        else
            controller:setCountermeasures(profile.chaff * 1.5, 0, profile.interval, profile.duration)
        end
    end)
    
    -- Select evasive maneuver
    local maneuvers = DEFENSIVE_PROFILES.EVASIVE_MANEUVER
    local selectedManeuver = maneuvers[math.random(#maneuvers)]
    
    -- Apply defensive maneuver
    if threatLevel > 0.7 then
        env.info("Tanuki AI: "..groupName.." executing "..selectedManeuver.." maneuver")
        pcall(function() 
            controller:setOption(AI.Option.Air.id.REACTION_TO_THREAT, AI.Option.Air.val.REACTION_TO_THREAT.EVADE_FIRE)
        end)
    end
end

function EvaluateTacticalSituation(group)
    if not group or not group:isExist() then 
        env.warning("Tanuki AI: EvaluateTacticalSituation called with invalid group")
        return "PATROL" 
    end

    local groupName = group:getName()
    local state = aiState[groupName]
    if not state or not state.isActive then 
        env.warning("Tanuki AI: Inactive state for group "..groupName)
        return "PATROL" 
    end

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
    if not unit then 
        env.warning("Tanuki AI: No unit in group "..groupName)
        return state.currentTactic 
    end
    
    local pos = unit:getPoint()
    local alt = pos.y

    local threats = {}
    local threatDistance = 999999
    local enemyCoalition = getEnemyCoalition(coalitionSide)
    
    -- Get enemy aircraft groups
    local enemyAirGroups = {}
    local success, airplaneGroups = pcall(function() 
        return coalition.getGroups(enemyCoalition, Group.Category.AIRPLANE) 
    end)
    local success2, heliGroups = pcall(function() 
        return coalition.getGroups(enemyCoalition, Group.Category.HELICOPTER) 
    end)
    
    if success and airplaneGroups then
        for _, g in ipairs(airplaneGroups) do
            table.insert(enemyAirGroups, g)
        end
    end
    if success2 and heliGroups then
        for _, g in ipairs(heliGroups) do
            table.insert(enemyAirGroups, g)
        end
    end

    for _, enemyGroup in ipairs(enemyAirGroups) do
        if enemyGroup and enemyGroup:isExist() then
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
    local profile = TACTICAL_PROFILES[state.tacticalProfile] or TACTICAL_PROFILES.AIR_SUPERIORITY

    -- Enhanced threat level calculation
    if #threats > 0 then
        state.threatLevel = math.max(state.threatLevel, 0.8 * (1 - threatDistance / 80000))
        
        if threatDistance < 15000 then
            newTactic = "DOGFIGHT"
        elseif threatDistance < (profile.attack.maxRange or 50000) and 
               threatDistance > (profile.attack.minRange or 5000) then
            
            if profile.attack.preference == "BVR" then
                newTactic = "BVR_ENGAGEMENT"
            else
                newTactic = "STANDOFF_ATTACK"
            end
        else
            newTactic = "INTERCEPT"
        end
        
        -- Immediate defense for close threats
        if threatDistance < 5000 then
            ExecuteDefensiveManeuvers(group, 1.0)  -- Immediate defense
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
        env.warning("Tanuki AI: AdaptiveTactics called with invalid group")
        return 
    end
    
    local groupName = group:getName()
    local state = aiState[groupName]
    if not state or not state.isActive then 
        env.warning("Tanuki AI: Inactive state for group "..groupName)
        return 
    end
    
    local controller = group:getController()
    if not controller then 
        env.warning("Tanuki AI: No controller for group "..groupName)
        return 
    end
    
    -- FIXED: Proper pcall handling for threat detection
    local success, threatBool, threatValue = pcall(DetectIncomingThreats, group)
    local missileThreat, immediateThreat
    if success then
        missileThreat = threatBool
        immediateThreat = threatValue
        state.threatLevel = math.max(state.threatLevel, immediateThreat)
    else
        -- Error in detection, use fallback
        missileThreat = false
        immediateThreat = state.threatLevel
    end
    
    -- If missile threat detected, prioritize defense
    if missileThreat then
        ExecuteDefensiveManeuvers(group, immediateThreat)
        -- Skip other adaptations to focus on defense
        timer.scheduleFunction(function()
            AdaptiveTactics(group)
            return nil
        end, nil, timer.getTime() + math.random(3, 6))
        return
    end
    
    local skill = state.skillLevel or 0.7
    local fatigue = state.fatigue or 0
    
    -- Calculate effective skill (skill minus fatigue impact)
    local effectiveSkill = math.max(0.3, math.min(0.98, skill - (fatigue * 0.4)))
    
    -- Adjust reaction based on situation
    local reactionLevel
    if state.threatLevel > 0.7 then
        reactionLevel = AI.Option.Air.val.ROE.WEAPON_FREE
    else
        reactionLevel = math.random() < effectiveSkill and 
                        AI.Option.Air.val.ROE.WEAPON_FREE or 
                        AI.Option.Air.val.ROE.WEAPON_HOLD
    end
    
    pcall(function() 
        controller:setOption(AI.Option.Air.id.ROE, reactionLevel)
    end)
    
    -- Random human-like hesitation (less frequent for skilled pilots)
    if math.random() < (0.35 - effectiveSkill * 0.25) then
        local hesitationTime = math.random(2, 6)
        
        -- Only apply hesitation if not in immediate danger
        if state.threatLevel < 0.6 then
            timer.scheduleFunction(function()
                if group and group:isExist() and aiState[groupName] then
                    local c = group:getController()
                    if c then
                        pcall(function() 
                            c:setOption(AI.Option.Air.id.ROE, reactionLevel)
                        end)
                        env.info("Tanuki AI: "..groupName.." recovered from hesitation")
                    end
                end
                return nil
            end, nil, timer.getTime() + hesitationTime)
            
            pcall(function() 
                controller:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.RETURN_FIRE)
            end)
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
        env.warning("Tanuki AI: UpdateFatigue called with invalid group")
        return 
    end
    
    local groupName = group:getName()
    local state = aiState[groupName]
    if not state or not state.isActive then 
        env.warning("Tanuki AI: Inactive state for group "..groupName)
        return 
    end
    
    local now = timer.getTime()
    local timeDiff = now - (state.lastUpdate or now)
    state.lastUpdate = now
    
    -- Reduce fatigue impact during high threat situations
    local fatigueImpact = FATIGUE_FACTORS.COMBAT
    if state.threatLevel > 0.7 then
        fatigueImpact = fatigueImpact * 0.6
    end
    
    -- Update fatigue based on combat status
    if state.threatLevel > 0.7 then
        state.fatigue = state.fatigue + (fatigueImpact * timeDiff/60)
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
            pcall(function() 
                controller:setOption(AI.Option.Air.id.RADAR_USING, 
                                   math.random() < (0.8 - state.fatigue*0.3) and 1 or 0)
                controller:setOption(AI.Option.Air.id.FLARE_USING, 
                                   math.random() < (0.75 - state.fatigue*0.25) and 1 or 0)
            end)
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
                    state.combatTime = state.combatTime * 0.5
                end
            else
                state.isActive = false
            end
        end
    end
    
    -- Clean up inactive groups
    for groupName, state in pairs(aiState) do
        if not state.isActive then
            aiState[groupName] = nil
        end
    end
    
    timer.scheduleFunction(AssessThreats, nil, timer.getTime() + math.random(4, 8))
end

-- DCS 2.9 COMPATIBLE EVENT HANDLER
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
    elseif event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_CRASH then
        local unit = event.initiator
        if unit then
            local group = unit:getGroup()
            if group then
                local groupName = group:getName()
                if aiState[groupName] then
                    aiState[groupName].isActive = false
                end
            end
        end
    end
end

-- Main Initialization
function ApplyLifelikeDefenseToAll()
    -- Blue coalition aircraft
    local success, blueGroups = pcall(function() 
        return coalition.getGroups(coalition.side.BLUE, Group.Category.AIRPLANE) 
    end)
    
    if success and blueGroups then
        for _, group in ipairs(blueGroups) do
            if group and group:isExist() then
                InitializeAIGroup(group)
                AdaptiveTactics(group)
                UpdateFatigue(group)
            end
        end
    end

    -- Red coalition aircraft
    local success2, redGroups = pcall(function() 
        return coalition.getGroups(coalition.side.RED, Group.Category.AIRPLANE) 
    end)
    
    if success2 and redGroups then
        for _, group in ipairs(redGroups) do
            if group and group:isExist() then
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
    
    env.info("Tanuki AI: Defense system applied to all aircraft")
end

-- ========== MAIN INITIALIZATION ========== --
local function delayedStart()
    if pcall(function() return coalition.getGroups end) then
        trigger.action.outText("⚡ TANUKI AI ENHANCED DCS TACTICAL SYSTEM v3.5 ⚡\n🤖 Adaptive Tactics | 🛡️ Enhanced Defense | 😴 Fatigue System", 20)
        env.info("Tanuki AI: Initializing enhanced defense systems")
        
        ApplyLifelikeDefenseToAll()
    else
        env.warning("Tanuki AI: Coalition not ready, retrying in 5 seconds.")
        timer.scheduleFunction(delayedStart, {}, timer.getTime() + 5)
    end
    return nil
end

-- Start everything after 10 seconds
timer.scheduleFunction(delayedStart, {}, timer.getTime() + 10)