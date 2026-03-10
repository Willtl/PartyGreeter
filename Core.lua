local addon = PartyGreeter

local partySize = 0
local greetedMembers = {}
local newMembers = {}
local greetingScheduleToken = 0

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

local function getGreetingDelay()
    local value = tonumber(PartyGreeterDB.delay) or addon.DEFAULTS.delay
    if value < 0 then
        return 0
    end

    return value
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

    if currentPartySize <= 1 then
        greetedMembers = {}
        newMembers = {}
        clearPendingGreeting()
    elseif currentPartySize > partySize then
        for guid, fullName in pairs(currentMembers) do
            if not greetedMembers[guid] then
                if PartyGreeterDB.includeRealm then
                    table.insert(newMembers, fullName)
                else
                    table.insert(newMembers, stripRealmFromName(fullName))
                end
                greetedMembers[guid] = true
            end
        end

        scheduleGreeting()
    end

    partySize = currentPartySize
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function()
    greetNewPartyMembers()
end)
