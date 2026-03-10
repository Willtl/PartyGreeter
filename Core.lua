local addon = PartyGreeter

local partySize = 0
local greetedMembers = {}
local newMembers = {}
local greetingScheduleToken = 0
local hasSessionBaseline = false
local isBootstrapping = false
local bootstrapStableToken = 0
local bootstrapLastSignature = nil
local BOOTSTRAP_STABLE_SECONDS = 1.5

local function refreshGreetedMembers(currentMembers)
    greetedMembers = {}
    for guid in pairs(currentMembers) do
        greetedMembers[guid] = true
    end
end

local function stripRealmFromName(fullName)
    if not fullName then
        return ""
    end

    local separator = string.find(fullName, "-", 1, true)
    if separator then
        return string.sub(fullName, 1, separator - 1)
    end

    return fullName
end

local function buildUnitName(unit)
    local unitName, unitServer = UnitFullName(unit)
    if not unitName or unitName == "" then
        return nil
    end

    if unitServer and unitServer ~= "" then
        return unitName .. "-" .. unitServer
    end

    return unitName
end

local function isInRaidGroup()
    return UnitInRaid("player") ~= nil
end

local function getCurrentGroupSnapshot()
    local currentMembers = {}
    local playerGUID = UnitGUID("player")

    if isInRaidGroup() then
        local raidSize = 0
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) then
                raidSize = raidSize + 1
                local guid = UnitGUID(unit)
                if guid and guid ~= playerGUID then
                    local fullName = buildUnitName(unit)
                    if fullName then
                        currentMembers[guid] = fullName
                    end
                end
            end
        end

        return raidSize, currentMembers
    end

    if UnitInParty("player") then
        local partySizeWithPlayer = 1
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                partySizeWithPlayer = partySizeWithPlayer + 1
                local guid = UnitGUID(unit)
                if guid then
                    local fullName = buildUnitName(unit)
                    if fullName then
                        currentMembers[guid] = fullName
                    end
                end
            end
        end

        return partySizeWithPlayer, currentMembers
    end

    return 1, currentMembers
end

local function clearPendingGreeting()
    greetingScheduleToken = greetingScheduleToken + 1
end

local function setBaselineFromSnapshot(currentPartySize, currentMembers)
    refreshGreetedMembers(currentMembers)
    partySize = currentPartySize
    newMembers = {}
    clearPendingGreeting()
    hasSessionBaseline = true
end

local function buildRosterSignature(currentPartySize, currentMembers)
    local guids = {}
    for guid in pairs(currentMembers) do
        table.insert(guids, guid)
    end
    table.sort(guids)

    local groupType = "solo"
    if isInRaidGroup() then
        groupType = "raid"
    elseif currentPartySize > 1 then
        groupType = "party"
    end

    return groupType .. "|" .. tostring(currentPartySize) .. "|" .. table.concat(guids, ";")
end

local function startBootstrapStabilizationTimer(expectedSignature)
    bootstrapStableToken = bootstrapStableToken + 1
    local stableToken = bootstrapStableToken
    C_Timer.After(BOOTSTRAP_STABLE_SECONDS, function()
        if stableToken ~= bootstrapStableToken then
            return
        end

        local latestPartySize, latestMembers = getCurrentGroupSnapshot()
        local latestSignature = buildRosterSignature(latestPartySize, latestMembers)
        if latestSignature ~= expectedSignature then
            bootstrapLastSignature = latestSignature
            setBaselineFromSnapshot(latestPartySize, latestMembers)
            startBootstrapStabilizationTimer(latestSignature)
            return
        end

        setBaselineFromSnapshot(latestPartySize, latestMembers)
        bootstrapLastSignature = latestSignature
        isBootstrapping = false
    end)
end

local function processBootstrapSnapshot(currentPartySize, currentMembers)
    local signature = buildRosterSignature(currentPartySize, currentMembers)
    if signature == bootstrapLastSignature then
        return
    end

    bootstrapLastSignature = signature
    setBaselineFromSnapshot(currentPartySize, currentMembers)
    startBootstrapStabilizationTimer(signature)
end

local function beginBootstrap()
    bootstrapStableToken = bootstrapStableToken + 1
    isBootstrapping = true
    hasSessionBaseline = false
    bootstrapLastSignature = nil

    local currentPartySize, currentMembers = getCurrentGroupSnapshot()
    processBootstrapSnapshot(currentPartySize, currentMembers)
end

local function getGreetingDelay()
    local fixedDelay = tonumber(PartyGreeterDB.delay) or addon.DEFAULTS.delay
    if fixedDelay < 0 then
        fixedDelay = 0
    end

    if PartyGreeterDB.randomDelayEnabled then
        local lowerBound = tonumber(PartyGreeterDB.delayLowerBound) or addon.DEFAULTS.delayLowerBound
        local upperBound = tonumber(PartyGreeterDB.delayUpperBound) or addon.DEFAULTS.delayUpperBound

        lowerBound = math.floor(lowerBound + 0.5)
        upperBound = math.floor(upperBound + 0.5)
        if lowerBound < 0 then
            lowerBound = 0
        end
        if upperBound < 0 then
            upperBound = 0
        end
        if lowerBound > upperBound then
            lowerBound, upperBound = upperBound, lowerBound
        end

        return math.random(lowerBound, upperBound)
    end

    return fixedDelay
end

local function sendRandomGreeting()
    if #newMembers == 0 then
        return
    end

    local greetings = PartyGreeterDB.greetings
    if #greetings == 0 then
        newMembers = {}
        return
    end

    local message = greetings[math.random(#greetings)]

    if PartyGreeterDB.includePlayerName and #newMembers == 1 then
        message = message .. " " .. newMembers[1]
    elseif #newMembers > 1 and #PartyGreeterDB.groupTerms > 0 then
        local term = PartyGreeterDB.groupTerms[math.random(#PartyGreeterDB.groupTerms)]
        message = message .. " " .. term
    end

    if isInRaidGroup() then
        if PartyGreeterDB.useInRaid then
            SendChatMessage(message, "RAID")
        end
    else
        SendChatMessage(message, "PARTY")
    end

    newMembers = {}
end

local function scheduleGreeting()
    clearPendingGreeting()
    local scheduleToken = greetingScheduleToken

    C_Timer.After(getGreetingDelay(), function()
        if scheduleToken ~= greetingScheduleToken then
            return
        end

        sendRandomGreeting()
    end)
end

local function greetNewPartyMembers()
    local currentPartySize, currentMembers = getCurrentGroupSnapshot()

    if isBootstrapping then
        processBootstrapSnapshot(currentPartySize, currentMembers)
        return
    end

    if not hasSessionBaseline then
        setBaselineFromSnapshot(currentPartySize, currentMembers)
        return
    end

    if currentPartySize <= 1 then
        greetedMembers = {}
        newMembers = {}
        clearPendingGreeting()
    else
        local hasAddedMembers = false
        for guid, fullName in pairs(currentMembers) do
            if not greetedMembers[guid] then
                if PartyGreeterDB.includeRealm then
                    table.insert(newMembers, fullName)
                else
                    table.insert(newMembers, stripRealmFromName(fullName))
                end
                hasAddedMembers = true
            end
        end

        refreshGreetedMembers(currentMembers)

        if hasAddedMembers then
            scheduleGreeting()
        end
    end

    partySize = currentPartySize
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        if isInitialLogin or isReloadingUi then
            beginBootstrap()
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        greetNewPartyMembers()
    end
end)
