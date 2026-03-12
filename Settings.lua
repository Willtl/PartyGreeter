local addon = PartyGreeter

addon.Settings = addon.Settings or {}
addon.Settings.Keys = {
    IncludePlayerName = "INCLUDE_PLAYER_NAME",
    IncludeRealm = "INCLUDE_REALM",
    UseInRaid = "USE_IN_RAID",
    IgnoreListEnabled = "IGNORE_LIST_ENABLED",
    PromptBeforeGreeting = "PROMPT_BEFORE_GREETING",
    IgnoredPlayers = "IGNORED_PLAYERS",
    AntiRepeatEnabled = "ANTI_REPEAT_ENABLED",
    AntiRepeatCooldownMinutes = "ANTI_REPEAT_COOLDOWN_MINUTES",
    AntiRepeatOncePerSession = "ANTI_REPEAT_ONCE_PER_SESSION",
    QuietModeEnabled = "QUIET_MODE_ENABLED",
    QuietModeSuppressInCombat = "QUIET_MODE_SUPPRESS_IN_COMBAT",
    QuietModeSuppressDuringBossPulls = "QUIET_MODE_SUPPRESS_DURING_BOSS_PULLS",
    QuietModeSuppressAfterKeyStart = "QUIET_MODE_SUPPRESS_AFTER_KEY_START",
    QuietModeSuppressInMatchmadeGroups = "QUIET_MODE_SUPPRESS_IN_MATCHMADE_GROUPS",
    RandomDelayEnabled = "RANDOM_DELAY_ENABLED",
    Delay = "DELAY",
    DelayLowerBound = "DELAY_LOWER_BOUND",
    DelayUpperBound = "DELAY_UPPER_BOUND",
    Greetings = "GREETINGS",
    GroupTerms = "GROUP_TERMS",
}

local TEXT = {
    title = "Party Greeter",
    behaviorHeader = "Behavior",
    ignoreListHeader = "Ignore List",
    antiRepeatHeader = "Anti-Repeat",
    quietModeHeader = "Quiet Mode",
    timingHeader = "Timing",
    messagesHeader = "Messages",

    includePlayerNameLabel = "Include player name when greeting one new member",
    includeRealmLabel = "Include realm in member names",
    useInRaidLabel = "Send greetings in raid groups",
    ignoreListEnabledLabel = "Enable the ignore list",
    promptBeforeGreetingLabel = "Show a greeting prompt when an ignored player joins",
    ignoredPlayersLabel = "Ignored players",
    antiRepeatEnabledLabel = "Avoid repeating greetings to the same player",
    antiRepeatCooldownLabel = "Repeat cooldown (minutes)",
    antiRepeatOncePerSessionLabel = "Only greet each player once per session",
    quietModeEnabledLabel = "Suppress greetings during noisy or disruptive gameplay moments",
    quietModeSuppressInCombatLabel = "Suppress greetings in combat",
    quietModeSuppressDuringBossPullsLabel = "Suppress greetings during boss pulls",
    quietModeSuppressAfterKeyStartLabel = "Suppress greetings after key start",
    quietModeSuppressInMatchmadeGroupsLabel = "Suppress greetings in auto-formed matchmaking groups",

    randomDelayLabel = "Use random delay interval",
    delayLabel = "Fixed delay (seconds)",
    delayLowerBoundLabel = "Random delay lower bound (seconds)",
    delayUpperBoundLabel = "Random delay upper bound (seconds)",

    greetingsLabel = "Greetings",
    addGreetingOption = "Add custom greeting...",
    addGreetingPopupTitle = "Add Custom Greeting",
    groupTermsLabel = "Group Terms",
    addGroupTermOption = "Add custom group term...",
    addGroupTermPopupTitle = "Add Custom Group Term",
    addIgnoredPlayerOption = "Add ignored player...",
    addIgnoredPlayerPopupTitle = "Add Ignored Player",
}

local LIMITS = {
    fixedDelayMin = 0,
    fixedDelayMax = 20,
    randomBoundsMin = 0,
    randomBoundsMax = 20,
    antiRepeatCooldownMin = 1,
    antiRepeatCooldownMax = 1440,
}

local LIST_EDITOR_POPUP_KEY = "PARTYGREETER_EDIT_LIST"
local GREETING_PRESETS = { "Hi", "Hello", "Hey", "Sup", "Yo", "Greetings" }
local settingsPanelRegistered = false

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end

    return value
end

local function normalizeFixedDelay(value)
    local normalized = tonumber(value)
    if not normalized then
        normalized = addon.DEFAULTS.delay
    end
    normalized = math.floor(normalized + 0.5)
    return clamp(normalized, LIMITS.fixedDelayMin, LIMITS.fixedDelayMax)
end

local function normalizeBounds(lower, upper)
    local normalizedLower = tonumber(lower)
    local normalizedUpper = tonumber(upper)
    if not normalizedLower then
        normalizedLower = addon.DEFAULTS.delayLowerBound
    end
    if not normalizedUpper then
        normalizedUpper = addon.DEFAULTS.delayUpperBound
    end

    normalizedLower = math.floor(normalizedLower + 0.5)
    normalizedUpper = math.floor(normalizedUpper + 0.5)
    normalizedLower = clamp(normalizedLower, LIMITS.randomBoundsMin, LIMITS.randomBoundsMax)
    normalizedUpper = clamp(normalizedUpper, LIMITS.randomBoundsMin, LIMITS.randomBoundsMax)

    if normalizedLower > normalizedUpper then
        normalizedLower, normalizedUpper = normalizedUpper, normalizedLower
    end

    return normalizedLower, normalizedUpper
end

local function normalizeAntiRepeatCooldown(value)
    local normalized = tonumber(value)
    if not normalized then
        normalized = addon.DEFAULTS.antiRepeatCooldownMinutes
    end
    normalized = math.floor(normalized + 0.5)
    return clamp(normalized, LIMITS.antiRepeatCooldownMin, LIMITS.antiRepeatCooldownMax)
end

local function listContains(list, value)
    if type(list) ~= "table" then
        return false
    end

    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end

    return false
end

local function appendUnique(list, value)
    if value == nil or value == "" then
        return
    end

    if not listContains(list, value) then
        table.insert(list, value)
    end
end

local function buildOptionsPool(presets, defaultsList, currentList)
    local pool = {}
    local function addAll(source)
        if type(source) ~= "table" then
            return
        end

        for _, item in ipairs(source) do
            local trimmed = addon.TrimWhitespace(item)
            if trimmed ~= "" then
                appendUnique(pool, trimmed)
            end
        end
    end

    addAll(presets)
    addAll(defaultsList)
    addAll(currentList)

    return pool
end

local function ensureListEditorPopup()
    if not StaticPopupDialogs then
        return false
    end

    if StaticPopupDialogs[LIST_EDITOR_POPUP_KEY] then
        return true
    end

    local function getPopupTextRegion(popup)
        return popup.Text or popup.text
    end

    local function getPopupEditBox(popup)
        if popup.EditBox then
            return popup.EditBox
        end
        if popup.editBox then
            return popup.editBox
        end
        if popup.GetEditBox then
            return popup:GetEditBox()
        end

        return nil
    end

    local function getPopupPayload(popup, payloadArg)
        if payloadArg ~= nil then
            return payloadArg
        end

        return popup.data
    end

    StaticPopupDialogs[LIST_EDITOR_POPUP_KEY] = {
        text = "Edit list",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 1024,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(self, data)
            local payload = getPopupPayload(self, data) or {}
            local textRegion = getPopupTextRegion(self)
            if textRegion then
                textRegion:SetText(payload.title or "Edit list")
            end

            local editBox = getPopupEditBox(self)
            if editBox then
                editBox:SetText(payload.initialText or "")
                editBox:SetFocus()
                editBox:HighlightText()
            end
        end,
        OnAccept = function(self, data)
            local payload = getPopupPayload(self, data)
            if not payload or not payload.onAccept then
                return
            end

            local editBox = getPopupEditBox(self)
            if editBox then
                payload.onAccept(editBox:GetText())
            end
        end,
        EditBoxOnEnterPressed = function(editBox)
            local popup = editBox:GetParent()
            local payload = getPopupPayload(popup, nil)
            if payload and payload.onAccept then
                payload.onAccept(editBox:GetText())
            end
            popup:Hide()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
    }

    return true
end

local function showListEditorPopup(title, initialText, onAccept)
    if not ensureListEditorPopup() or not StaticPopup_Show then
        return
    end

    StaticPopup_Show(LIST_EDITOR_POPUP_KEY, nil, nil, {
        title = title,
        initialText = initialText,
        onAccept = onAccept,
    })
end

local function tryAddSectionHeader(layout, text)
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

local function createBooleanSetting(category, key, label, defaultValue, getter, setter)
    local setting = Settings.RegisterProxySetting(
        category,
        key,
        Settings.VarType.Boolean,
        label,
        defaultValue,
        getter,
        setter
    )
    local initializer = Settings.CreateCheckbox(category, setting, nil)

    return setting, initializer
end

local function createSliderSetting(category, key, label, defaultValue, getter, setter, minValue, maxValue, step)
    local setting = Settings.RegisterProxySetting(
        category,
        key,
        Settings.VarType.Number,
        label,
        defaultValue,
        getter,
        setter
    )

    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    local initializer = Settings.CreateSlider(category, setting, options, nil)

    return setting, initializer
end

local function createListMultiSelectSetting(
    category,
    key,
    label,
    dbKey,
    defaultsList,
    presets,
    addOptionLabel,
    addPopupTitle,
    normalizeListFn
)
    local normalize = normalizeListFn or function(list)
        return addon.CloneList(list)
    end

    local function getOptionEntries()
        local entries = {}
        local source = buildOptionsPool(presets, defaultsList, PartyGreeterDB[dbKey])
        for index, value in ipairs(source) do
            entries[index] = {
                id = index,
                label = value,
            }
        end
        return entries
    end

    local function getMaskFromList(list, entries)
        local selected = {}
        if type(list) == "table" then
            for _, value in ipairs(list) do
                selected[value] = true
            end
        end

        local mask = 0
        for _, entry in ipairs(entries) do
            if selected[entry.label] then
                mask = bit.bor(mask, bit.lshift(1, entry.id - 1))
            end
        end

        return mask
    end

    local function getListFromMask(mask, entries)
        local selected = {}
        for _, entry in ipairs(entries) do
            local optionMask = bit.lshift(1, entry.id - 1)
            if bit.band(mask, optionMask) ~= 0 then
                table.insert(selected, entry.label)
            end
        end
        return selected
    end

    local defaultMask = getMaskFromList(defaultsList, getOptionEntries())

    local function getValue()
        local source = type(PartyGreeterDB[dbKey]) == "table" and PartyGreeterDB[dbKey]
            or defaultsList
        return getMaskFromList(source, getOptionEntries())
    end

    local function setValue(mask)
        if type(mask) ~= "number" then
            return
        end

        local entries = getOptionEntries()
        local addOptionIndex = #entries + 1
        local addOptionMask = bit.lshift(1, addOptionIndex - 1)
        local addRequested = bit.band(mask, addOptionMask) ~= 0
        local sanitizedMask = bit.band(mask, bit.bnot(addOptionMask))

        local selected = getListFromMask(sanitizedMask, entries)
        if #selected == 0 then
            selected = addon.CloneList(defaultsList)
        end
        PartyGreeterDB[dbKey] = normalize(selected)

        if not addRequested then
            return
        end

        showListEditorPopup(addPopupTitle, "", function(text)
            local trimmed = addon.TrimWhitespace(text)
            if trimmed == "" then
                return
            end

            local updated = addon.CloneList(PartyGreeterDB[dbKey] or {})
            appendUnique(updated, trimmed)
            PartyGreeterDB[dbKey] = normalize(updated)
        end)
    end

    local setting = Settings.RegisterProxySetting(
        category,
        key,
        Settings.VarType.Number,
        label,
        defaultMask,
        getValue,
        setValue
    )

    local function getOptions()
        local container = Settings.CreateControlTextContainer()

        local entries = getOptionEntries()
        for _, entry in ipairs(entries) do
            container:AddCheckbox(entry.id, entry.label, nil)
        end
        container:AddCheckbox(#entries + 1, addOptionLabel, nil)

        return container:GetData()
    end

    local initializer = Settings.CreateDropdown(category, setting, getOptions, nil)
    return setting, initializer
end

local function createGreetingsMultiSelectSetting(category, key, label)
    return createListMultiSelectSetting(
        category,
        key,
        label,
        "greetings",
        addon.DEFAULTS.greetings,
        GREETING_PRESETS,
        TEXT.addGreetingOption,
        TEXT.addGreetingPopupTitle,
        nil
    )
end

local function createGroupTermsMultiSelectSetting(category, key, label)
    return createListMultiSelectSetting(
        category,
        key,
        label,
        "groupTerms",
        addon.DEFAULTS.groupTerms,
        nil,
        TEXT.addGroupTermOption,
        TEXT.addGroupTermPopupTitle,
        nil
    )
end

local function createIgnoredPlayersMultiSelectSetting(category, key, label)
    return createListMultiSelectSetting(
        category,
        key,
        label,
        "ignoredPlayers",
        addon.DEFAULTS.ignoredPlayers,
        nil,
        TEXT.addIgnoredPlayerOption,
        TEXT.addIgnoredPlayerPopupTitle,
        addon.NormalizeNameList
    )
end

function addon.RegisterSettingsPanel()
    if settingsPanelRegistered or not Settings or not Settings.RegisterVerticalLayoutCategory then
        return
    end

    settingsPanelRegistered = true

    local category, layout = Settings.RegisterVerticalLayoutCategory(TEXT.title)

    tryAddSectionHeader(layout, TEXT.behaviorHeader)

    createBooleanSetting(
        category,
        addon.Settings.Keys.IncludePlayerName,
        TEXT.includePlayerNameLabel,
        addon.DEFAULTS.includePlayerName,
        function()
            return PartyGreeterDB.includePlayerName
        end,
        function(value)
            PartyGreeterDB.includePlayerName = value and true or false
        end
    )

    createBooleanSetting(
        category,
        addon.Settings.Keys.IncludeRealm,
        TEXT.includeRealmLabel,
        addon.DEFAULTS.includeRealm,
        function()
            return PartyGreeterDB.includeRealm
        end,
        function(value)
            PartyGreeterDB.includeRealm = value and true or false
        end
    )

    createBooleanSetting(
        category,
        addon.Settings.Keys.UseInRaid,
        TEXT.useInRaidLabel,
        addon.DEFAULTS.useInRaid,
        function()
            return PartyGreeterDB.useInRaid
        end,
        function(value)
            PartyGreeterDB.useInRaid = value and true or false
        end
    )

    tryAddSectionHeader(layout, TEXT.ignoreListHeader)

    local _, ignoreListEnabledInitializer = createBooleanSetting(
        category,
        addon.Settings.Keys.IgnoreListEnabled,
        TEXT.ignoreListEnabledLabel,
        addon.DEFAULTS.ignoreListEnabled,
        function()
            return PartyGreeterDB.ignoreListEnabled
        end,
        function(value)
            PartyGreeterDB.ignoreListEnabled = value and true or false
        end
    )

    local _, promptBeforeGreetingInitializer = createBooleanSetting(
        category,
        addon.Settings.Keys.PromptBeforeGreeting,
        TEXT.promptBeforeGreetingLabel,
        addon.DEFAULTS.promptBeforeGreeting,
        function()
            return PartyGreeterDB.promptBeforeGreeting
        end,
        function(value)
            PartyGreeterDB.promptBeforeGreeting = value and true or false
        end
    )

    local _, ignoredPlayersInitializer = createIgnoredPlayersMultiSelectSetting(
        category,
        addon.Settings.Keys.IgnoredPlayers,
        TEXT.ignoredPlayersLabel
    )

    promptBeforeGreetingInitializer:SetParentInitializer(ignoreListEnabledInitializer, function()
        return PartyGreeterDB.ignoreListEnabled
    end)
    ignoredPlayersInitializer:SetParentInitializer(ignoreListEnabledInitializer, function()
        return PartyGreeterDB.ignoreListEnabled
    end)

    tryAddSectionHeader(layout, TEXT.antiRepeatHeader)

    local _, antiRepeatEnabledInitializer = createBooleanSetting(
        category,
        addon.Settings.Keys.AntiRepeatEnabled,
        TEXT.antiRepeatEnabledLabel,
        addon.DEFAULTS.antiRepeatEnabled,
        function()
            return PartyGreeterDB.antiRepeatEnabled
        end,
        function(value)
            PartyGreeterDB.antiRepeatEnabled = value and true or false
        end
    )

    local _, antiRepeatCooldownInitializer = createSliderSetting(
        category,
        addon.Settings.Keys.AntiRepeatCooldownMinutes,
        TEXT.antiRepeatCooldownLabel,
        addon.DEFAULTS.antiRepeatCooldownMinutes,
        function()
            return normalizeAntiRepeatCooldown(PartyGreeterDB.antiRepeatCooldownMinutes)
        end,
        function(value)
            PartyGreeterDB.antiRepeatCooldownMinutes = normalizeAntiRepeatCooldown(value)
        end,
        LIMITS.antiRepeatCooldownMin,
        LIMITS.antiRepeatCooldownMax,
        1
    )

    local _, antiRepeatOncePerSessionInitializer = createBooleanSetting(
        category,
        addon.Settings.Keys.AntiRepeatOncePerSession,
        TEXT.antiRepeatOncePerSessionLabel,
        addon.DEFAULTS.antiRepeatOncePerSession,
        function()
            return PartyGreeterDB.antiRepeatOncePerSession
        end,
        function(value)
            PartyGreeterDB.antiRepeatOncePerSession = value and true or false
        end
    )

    antiRepeatCooldownInitializer:SetParentInitializer(antiRepeatEnabledInitializer, function()
        return PartyGreeterDB.antiRepeatEnabled and not PartyGreeterDB.antiRepeatOncePerSession
    end)
    antiRepeatOncePerSessionInitializer:SetParentInitializer(antiRepeatEnabledInitializer, function()
        return PartyGreeterDB.antiRepeatEnabled
    end)

    tryAddSectionHeader(layout, TEXT.quietModeHeader)

    local _, quietModeEnabledInitializer = createBooleanSetting(
        category,
        addon.Settings.Keys.QuietModeEnabled,
        TEXT.quietModeEnabledLabel,
        addon.DEFAULTS.quietModeEnabled,
        function()
            return PartyGreeterDB.quietModeEnabled
        end,
        function(value)
            PartyGreeterDB.quietModeEnabled = value and true or false
        end
    )

    local _, quietModeSuppressInCombatInitializer = createBooleanSetting(
        category,
        addon.Settings.Keys.QuietModeSuppressInCombat,
        TEXT.quietModeSuppressInCombatLabel,
        addon.DEFAULTS.quietModeSuppressInCombat,
        function()
            return PartyGreeterDB.quietModeSuppressInCombat
        end,
        function(value)
            PartyGreeterDB.quietModeSuppressInCombat = value and true or false
        end
    )

    local _, quietModeSuppressDuringBossPullsInitializer = createBooleanSetting(
        category,
        addon.Settings.Keys.QuietModeSuppressDuringBossPulls,
        TEXT.quietModeSuppressDuringBossPullsLabel,
        addon.DEFAULTS.quietModeSuppressDuringBossPulls,
        function()
            return PartyGreeterDB.quietModeSuppressDuringBossPulls
        end,
        function(value)
            PartyGreeterDB.quietModeSuppressDuringBossPulls = value and true or false
        end
    )

    local _, quietModeSuppressAfterKeyStartInitializer = createBooleanSetting(
        category,
        addon.Settings.Keys.QuietModeSuppressAfterKeyStart,
        TEXT.quietModeSuppressAfterKeyStartLabel,
        addon.DEFAULTS.quietModeSuppressAfterKeyStart,
        function()
            return PartyGreeterDB.quietModeSuppressAfterKeyStart
        end,
        function(value)
            PartyGreeterDB.quietModeSuppressAfterKeyStart = value and true or false
        end
    )

    local _, quietModeSuppressInMatchmadeGroupsInitializer = createBooleanSetting(
        category,
        addon.Settings.Keys.QuietModeSuppressInMatchmadeGroups,
        TEXT.quietModeSuppressInMatchmadeGroupsLabel,
        addon.DEFAULTS.quietModeSuppressInMatchmadeGroups,
        function()
            return PartyGreeterDB.quietModeSuppressInMatchmadeGroups
        end,
        function(value)
            PartyGreeterDB.quietModeSuppressInMatchmadeGroups = value and true or false
        end
    )

    quietModeSuppressInCombatInitializer:SetParentInitializer(quietModeEnabledInitializer, function()
        return PartyGreeterDB.quietModeEnabled
    end)
    quietModeSuppressDuringBossPullsInitializer:SetParentInitializer(quietModeEnabledInitializer, function()
        return PartyGreeterDB.quietModeEnabled
    end)
    quietModeSuppressAfterKeyStartInitializer:SetParentInitializer(quietModeEnabledInitializer, function()
        return PartyGreeterDB.quietModeEnabled
    end)
    quietModeSuppressInMatchmadeGroupsInitializer:SetParentInitializer(quietModeEnabledInitializer, function()
        return PartyGreeterDB.quietModeEnabled
    end)

    tryAddSectionHeader(layout, TEXT.timingHeader)

    local _, randomDelayInitializer = createBooleanSetting(
        category,
        addon.Settings.Keys.RandomDelayEnabled,
        TEXT.randomDelayLabel,
        addon.DEFAULTS.randomDelayEnabled,
        function()
            return PartyGreeterDB.randomDelayEnabled
        end,
        function(value)
            PartyGreeterDB.randomDelayEnabled = value and true or false
        end
    )

    local _, delayInitializer = createSliderSetting(
        category,
        addon.Settings.Keys.Delay,
        TEXT.delayLabel,
        addon.DEFAULTS.delay,
        function()
            return normalizeFixedDelay(PartyGreeterDB.delay)
        end,
        function(value)
            PartyGreeterDB.delay = normalizeFixedDelay(value)
        end,
        LIMITS.fixedDelayMin,
        LIMITS.fixedDelayMax,
        1
    )

    local _, lowerBoundInitializer = createSliderSetting(
        category,
        addon.Settings.Keys.DelayLowerBound,
        TEXT.delayLowerBoundLabel,
        addon.DEFAULTS.delayLowerBound,
        function()
            local lowerBound = normalizeBounds(PartyGreeterDB.delayLowerBound, PartyGreeterDB.delayUpperBound)
            return lowerBound
        end,
        function(value)
            local lowerBound, upperBound = normalizeBounds(value, PartyGreeterDB.delayUpperBound)
            PartyGreeterDB.delayLowerBound = lowerBound
            PartyGreeterDB.delayUpperBound = upperBound
        end,
        LIMITS.randomBoundsMin,
        LIMITS.randomBoundsMax,
        1
    )

    local _, upperBoundInitializer = createSliderSetting(
        category,
        addon.Settings.Keys.DelayUpperBound,
        TEXT.delayUpperBoundLabel,
        addon.DEFAULTS.delayUpperBound,
        function()
            local _, upperBound = normalizeBounds(PartyGreeterDB.delayLowerBound, PartyGreeterDB.delayUpperBound)
            return upperBound
        end,
        function(value)
            local lowerBound, upperBound = normalizeBounds(PartyGreeterDB.delayLowerBound, value)
            PartyGreeterDB.delayLowerBound = lowerBound
            PartyGreeterDB.delayUpperBound = upperBound
        end,
        LIMITS.randomBoundsMin,
        LIMITS.randomBoundsMax,
        1
    )

    delayInitializer:SetParentInitializer(randomDelayInitializer, function()
        return not PartyGreeterDB.randomDelayEnabled
    end)
    lowerBoundInitializer:SetParentInitializer(randomDelayInitializer, function()
        return PartyGreeterDB.randomDelayEnabled
    end)
    upperBoundInitializer:SetParentInitializer(randomDelayInitializer, function()
        return PartyGreeterDB.randomDelayEnabled
    end)

    tryAddSectionHeader(layout, TEXT.messagesHeader)

    createGreetingsMultiSelectSetting(
        category,
        addon.Settings.Keys.Greetings,
        TEXT.greetingsLabel
    )
    createGroupTermsMultiSelectSetting(
        category,
        addon.Settings.Keys.GroupTerms,
        TEXT.groupTermsLabel
    )

    Settings.RegisterAddOnCategory(category)
    addon.optionsCategory = category
end

function addon.OpenSettingsPanel()
    addon.RegisterSettingsPanel()

    if not addon.optionsCategory then
        return
    end

    local categoryID = nil
    if addon.optionsCategory.GetID then
        local ok, value = pcall(addon.optionsCategory.GetID, addon.optionsCategory)
        if ok and type(value) == "number" then
            categoryID = value
        end
    end
    if not categoryID and type(addon.optionsCategory.ID) == "number" then
        categoryID = addon.optionsCategory.ID
    end

    if categoryID and C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel then
        C_SettingsUtil.OpenSettingsPanel(categoryID)
        return
    end

    if Settings and Settings.OpenToCategory then
        if categoryID then
            Settings.OpenToCategory(categoryID)
        elseif addon.optionsCategory.GetName then
            Settings.OpenToCategory(addon.optionsCategory:GetName())
        elseif type(addon.optionsCategory.name) == "string" then
            Settings.OpenToCategory(addon.optionsCategory.name)
        end
    end
end

function PartyGreeter_OnCompartmentClick(addonName, buttonName)
    addon.OpenSettingsPanel()
end

function PartyGreeter_OnCompartmentEnter(addonName, menuButtonFrame)
    if not GameTooltip or not menuButtonFrame then
        return
    end

    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:SetText(TEXT.title)
    GameTooltip:AddLine("Open settings", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end

function PartyGreeter_OnCompartmentLeave(addonName, menuButtonFrame)
    if GameTooltip then
        GameTooltip:Hide()
    end
end

SLASH_PARTYGREETER1 = "/partygreeter"
SLASH_PARTYGREETER2 = "/pg"
SlashCmdList["PARTYGREETER"] = function()
    addon.OpenSettingsPanel()
end
