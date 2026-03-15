local addon = PartyGreeter

local greetedMembers = {}
local pendingMembers = {}
local manualPromptQueue = {}
local activePromptMember = nil
local greetingScheduleToken = 0
local hasSessionBaseline = false
local isBootstrapping = false
local bootstrapStableToken = 0
local bootstrapLastSignature = nil
local BOOTSTRAP_STABLE_SECONDS = 1.5
local MANUAL_GREETING_POPUP_KEY = "PARTYGREETER_MANUAL_GREETING"
local isIgnoredMember
local shouldAutoGreetMember
local showNextManualPrompt

local function pruneStoredGreetingHistory(history, now)
    if type(history) ~= "table" then
        return {}
    end

    local retentionSeconds = addon.ANTI_REPEAT_HISTORY_RETENTION_SECONDS or (30 * 24 * 60 * 60)
    local retentionCutoff = now - retentionSeconds
    for guid, timestamp in pairs(history) do
        if type(guid) ~= "string" or guid == "" or type(timestamp) ~= "number" or timestamp < retentionCutoff then
            history[guid] = nil
        end
    end

    return history
end

local function getGreetingHistory()
    PartyGreeterDB.greetingHistory = pruneStoredGreetingHistory(PartyGreeterDB.greetingHistory, GetServerTime())
    return PartyGreeterDB.greetingHistory
end

local function getSessionGreetingHistory()
    PartyGreeterDB.sessionGreetingHistory = PartyGreeterDB.sessionGreetingHistory or {}
    return PartyGreeterDB.sessionGreetingHistory
end

local function clearSessionGreetingHistory()
    PartyGreeterDB.sessionGreetingHistory = {}
end

local function isMemberEligibleForGreeting(guid)
    if not guid or not PartyGreeterDB.antiRepeatEnabled then
        return true
    end

    if PartyGreeterDB.antiRepeatOncePerSession then
        return not getSessionGreetingHistory()[guid]
    end

    local cooldownSeconds = (tonumber(PartyGreeterDB.antiRepeatCooldownMinutes) or addon.DEFAULTS.antiRepeatCooldownMinutes) * 60
    local lastGreetingTime = getGreetingHistory()[guid]
    if type(lastGreetingTime) ~= "number" then
        return true
    end

    return (GetServerTime() - lastGreetingTime) >= cooldownSeconds
end

local function getPendingMembers()
    local members = {}
    for guid, fullName in pairs(pendingMembers) do
        members[#members + 1] = {
            guid = guid,
            fullName = fullName,
        }
    end

    table.sort(members, function(left, right)
        return left.guid < right.guid
    end)

    return members
end

local function getEligiblePendingMembers()
    local members = {}
    for _, member in ipairs(getPendingMembers()) do
        if shouldAutoGreetMember(member.guid, member.fullName) then
            members[#members + 1] = member
        end
    end

    return members
end

local function recordGreetingHistory(members)
    if not PartyGreeterDB.antiRepeatEnabled then
        return
    end

    local sessionGreetingHistory = getSessionGreetingHistory()
    local greetingHistory = nil
    if not PartyGreeterDB.antiRepeatOncePerSession then
        greetingHistory = getGreetingHistory()
    end

    local now = greetingHistory and GetServerTime() or nil
    for _, member in ipairs(members) do
        sessionGreetingHistory[member.guid] = true
        if greetingHistory then
            greetingHistory[member.guid] = now
        end
    end
end

local function clearPendingMembers()
    pendingMembers = {}
end

local function clearManualPromptQueue()
    manualPromptQueue = {}
    activePromptMember = nil
    if StaticPopup_Hide then
        StaticPopup_Hide(MANUAL_GREETING_POPUP_KEY)
    end
end

local function addPendingMember(guid, fullName)
    if not guid or not fullName then
        return
    end

    pendingMembers[guid] = fullName
end

local function prunePendingMembers(currentMembers)
    for guid in pairs(pendingMembers) do
        if not currentMembers[guid] then
            pendingMembers[guid] = nil
        end
    end
end

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

local function normalizeNameForLookup(name)
    local trimmed = addon.TrimWhitespace(name)
    if trimmed == "" then
        return ""
    end

    return string.lower(trimmed)
end

isIgnoredMember = function(fullName)
    if not PartyGreeterDB.ignoreListEnabled then
        return false
    end

    local normalizedFullName = normalizeNameForLookup(fullName)
    local normalizedBaseName = normalizeNameForLookup(stripRealmFromName(fullName))
    if normalizedFullName == "" or normalizedBaseName == "" then
        return false
    end

    for _, ignoredName in ipairs(PartyGreeterDB.ignoredPlayers or addon.DEFAULTS.ignoredPlayers) do
        local normalizedIgnoredName = normalizeNameForLookup(ignoredName)
        if normalizedIgnoredName ~= "" then
            if string.find(normalizedIgnoredName, "-", 1, true) then
                if normalizedIgnoredName == normalizedFullName then
                    return true
                end
            elseif normalizedIgnoredName == normalizedBaseName then
                return true
            end
        end
    end

    return false
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

local function isTrackableGroupMember(unit)
    return UnitExists(unit) and UnitIsPlayer(unit)
end

local function getCurrentGroupSnapshot()
    local currentMembers = {}
    local playerGUID = UnitGUID("player")

    if isInRaidGroup() then
        local raidSize = 0
        for i = 1, 40 do
            local unit = "raid" .. i
            if isTrackableGroupMember(unit) then
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
            if isTrackableGroupMember(unit) then
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
    clearPendingMembers()
    clearManualPromptQueue()
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

local function isInAutoFormedMatchmadeGroup()
    local _, instanceType, _, _, _, _, _, _, _, lfgDungeonID = GetInstanceInfo()
    if not lfgDungeonID or lfgDungeonID <= 0 then
        return false
    end

    return instanceType == "party" or instanceType == "raid"
end

local function shouldSuppressGreeting()
    if not PartyGreeterDB.quietModeEnabled then
        return false
    end

    if PartyGreeterDB.quietModeSuppressInCombat and InCombatLockdown() then
        return true
    end

    if PartyGreeterDB.quietModeSuppressDuringBossPulls and C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress and C_InstanceEncounter.IsEncounterInProgress() then
        return true
    end

    if PartyGreeterDB.quietModeSuppressAfterKeyStart and C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return true
    end

    if PartyGreeterDB.quietModeSuppressInMatchmadeGroups and isInAutoFormedMatchmadeGroup() then
        return true
    end

    return false
end

local function isIgnoredPlayerPromptEnabled()
    return PartyGreeterDB.ignoreListEnabled and PartyGreeterDB.promptBeforeGreeting
end

local function buildGreetingMessage(membersToGreet)
    local greetings = PartyGreeterDB.greetings
    if #greetings == 0 then
        return nil
    end

    local message = greetings[math.random(#greetings)]

    if PartyGreeterDB.includePlayerName and #membersToGreet == 1 then
        local targetName = membersToGreet[1].fullName
        if not PartyGreeterDB.includeRealm then
            targetName = stripRealmFromName(targetName)
        end

        message = message .. " " .. targetName
    elseif #membersToGreet > 1 and #PartyGreeterDB.groupTerms > 0 then
        local term = PartyGreeterDB.groupTerms[math.random(#PartyGreeterDB.groupTerms)]
        message = message .. " " .. term
    end

    return message
end

local function sendGreetingForMembers(membersToGreet, bypassSuppression)
    if #membersToGreet == 0 then
        return false
    end

    if not bypassSuppression and shouldSuppressGreeting() then
        return false
    end

    local message = buildGreetingMessage(membersToGreet)
    if not message then
        return false
    end

    local chatType = "PARTY"
    if isInRaidGroup() then
        if PartyGreeterDB.useInRaid then
            chatType = "RAID"
        else
            return false
        end
    end

    SendChatMessage(message, chatType)
    recordGreetingHistory(membersToGreet)
    return true
end

local function getCurrentMemberNameByGUID(guid)
    local _, currentMembers = getCurrentGroupSnapshot()
    return currentMembers[guid]
end

shouldAutoGreetMember = function(guid, fullName)
    return guid and fullName and isMemberEligibleForGreeting(guid) and not isIgnoredMember(fullName)
end

local function shouldPromptForIgnoredPlayer(guid, fullName)
    return guid and fullName and isMemberEligibleForGreeting(guid) and isIgnoredMember(fullName)
end

local function pruneManualPromptQueue(currentMembers)
    local remainingQueue = {}
    for _, member in ipairs(manualPromptQueue) do
        local latestName = currentMembers[member.guid]
        if shouldPromptForIgnoredPlayer(member.guid, latestName) then
            remainingQueue[#remainingQueue + 1] = {
                guid = member.guid,
                fullName = latestName,
            }
        end
    end
    manualPromptQueue = remainingQueue

    if activePromptMember then
        local latestName = currentMembers[activePromptMember.guid]
        if shouldPromptForIgnoredPlayer(activePromptMember.guid, latestName) then
            activePromptMember.fullName = latestName
        else
            activePromptMember = nil
            if StaticPopup_Hide then
                StaticPopup_Hide(MANUAL_GREETING_POPUP_KEY)
            end
        end
    end
end

local function isPromptQueued(guid)
    if activePromptMember and activePromptMember.guid == guid then
        return true
    end

    for _, member in ipairs(manualPromptQueue) do
        if member.guid == guid then
            return true
        end
    end

    return false
end

local function enqueueManualPrompt(guid, fullName)
    if not shouldPromptForIgnoredPlayer(guid, fullName) or isPromptQueued(guid) then
        return
    end

    manualPromptQueue[#manualPromptQueue + 1] = {
        guid = guid,
        fullName = fullName,
    }
end

local function ensureManualGreetingPopup()
    if not StaticPopupDialogs then
        return false
    end

    if StaticPopupDialogs[MANUAL_GREETING_POPUP_KEY] then
        return true
    end

    StaticPopupDialogs[MANUAL_GREETING_POPUP_KEY] = {
        text = "%s is on your ignore list.\nGreet them anyway?",
        button1 = "Greet Anyway",
        button2 = "Skip Greeting",
        OnAccept = function(_, data)
            if not data or not data.member then
                return
            end

            data.handled = true
            activePromptMember = nil

            local latestName = getCurrentMemberNameByGUID(data.member.guid)
            if latestName and isMemberEligibleForGreeting(data.member.guid) then
                sendGreetingForMembers({
                    {
                        guid = data.member.guid,
                        fullName = latestName,
                    },
                }, true)
            end

            C_Timer.After(0, showNextManualPrompt)
        end,
        OnCancel = function(_, data)
            if not data or not data.member then
                return
            end

            data.handled = true
            activePromptMember = nil

            C_Timer.After(0, showNextManualPrompt)
        end,
        OnHide = function(_, data)
            if not data or data.handled then
                return
            end

            activePromptMember = nil
            C_Timer.After(0, showNextManualPrompt)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    return true
end

showNextManualPrompt = function()
    if activePromptMember or not isIgnoredPlayerPromptEnabled() then
        return
    end

    if shouldSuppressGreeting() then
        manualPromptQueue = {}
        return
    end

    if not ensureManualGreetingPopup() or not StaticPopup_Show then
        return
    end

    while #manualPromptQueue > 0 do
        local member = table.remove(manualPromptQueue, 1)
        local latestName = getCurrentMemberNameByGUID(member.guid)
        if shouldPromptForIgnoredPlayer(member.guid, latestName) then
            member.fullName = latestName
            activePromptMember = member
            StaticPopup_Show(MANUAL_GREETING_POPUP_KEY, member.fullName, nil, {
                member = member,
            })
            return
        end
    end
end

local function sendRandomGreeting()
    local membersToGreet = getEligiblePendingMembers()
    if #membersToGreet == 0 then
        clearPendingMembers()
        return
    end

    sendGreetingForMembers(membersToGreet, false)
    clearPendingMembers()
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
        clearPendingMembers()
        clearManualPromptQueue()
        clearPendingGreeting()
    else
        prunePendingMembers(currentMembers)

        if isIgnoredPlayerPromptEnabled() then
            pruneManualPromptQueue(currentMembers)
        else
            clearManualPromptQueue()
        end

        local hasAutoGreetMembers = false
        for guid, fullName in pairs(currentMembers) do
            if not greetedMembers[guid] then
                if isIgnoredPlayerPromptEnabled() and shouldPromptForIgnoredPlayer(guid, fullName) then
                    enqueueManualPrompt(guid, fullName)
                elseif shouldAutoGreetMember(guid, fullName) then
                    addPendingMember(guid, fullName)
                    hasAutoGreetMembers = true
                end
            end
        end

        refreshGreetedMembers(currentMembers)

        if isIgnoredPlayerPromptEnabled() then
            showNextManualPrompt()
        end

        if hasAutoGreetMembers then
            scheduleGreeting()
        elseif not next(pendingMembers) then
            clearPendingGreeting()
        end
    end

end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        if isInitialLogin then
            clearSessionGreetingHistory()
        end
        if isInitialLogin or isReloadingUi then
            beginBootstrap()
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        greetNewPartyMembers()
    end
end)
