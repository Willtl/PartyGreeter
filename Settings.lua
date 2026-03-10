local addon = PartyGreeter

addon.Settings = addon.Settings or {}
addon.Settings.Keys = {
    IncludePlayerName = "INCLUDE_PLAYER_NAME",
    IncludeRealm = "INCLUDE_REALM",
    UseInRaid = "USE_IN_RAID",
    RandomDelayEnabled = "RANDOM_DELAY_ENABLED",
    Delay = "DELAY",
    DelayLowerBound = "DELAY_LOWER_BOUND",
    DelayUpperBound = "DELAY_UPPER_BOUND",
    Greetings = "GREETINGS",
    GroupTerms = "GROUP_TERMS",
}

function addon.Settings.GetDisplayOrder()
    return {
        addon.Settings.Keys.IncludePlayerName,
        addon.Settings.Keys.IncludeRealm,
        addon.Settings.Keys.UseInRaid,
        addon.Settings.Keys.RandomDelayEnabled,
        addon.Settings.Keys.Delay,
        addon.Settings.Keys.DelayLowerBound,
        addon.Settings.Keys.DelayUpperBound,
        addon.Settings.Keys.Greetings,
        addon.Settings.Keys.GroupTerms,
    }
end

local TEXT = {
    title = "Party Greeter",
    behaviorHeader = "Behavior",
    timingHeader = "Timing",
    messagesHeader = "Messages",

    includePlayerNameLabel = "Include player name when greeting one new member",
    includeRealmLabel = "Include realm in member names",
    useInRaidLabel = "Send greetings in raid groups",

    randomDelayLabel = "Use random delay interval",
    delayLabel = "Fixed delay (seconds)",
    delayLowerBoundLabel = "Random delay lower bound (seconds)",
    delayUpperBoundLabel = "Random delay upper bound (seconds)",

    greetingsLabel = "Greetings",
    addGreetingOption = "Add custom greeting...",
    addGreetingPopupTitle = "Add Custom Greeting",
    groupTermsLabel = "Group Terms List",
    editListOption = "Edit custom list...",
}

local LIMITS = {
    fixedDelayMin = 0,
    fixedDelayMax = 15,
    randomBoundsMin = 0,
    randomBoundsMax = 120,
}

local SENTINELS = {
    editList = "__EDIT_LIST__",
}

local LIST_EDITOR_POPUP_KEY = "PARTYGREETER_EDIT_LIST"
local GREETING_PRESETS = { "Hi", "Hello", "Hey", "Sup", "Yo", "Greetings" }

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

local function applyListSetting(dbKey, rawText, fallback)
    local parsed = addon.ParseCommaSeparatedList(rawText)
    if parsed then
        PartyGreeterDB[dbKey] = parsed
    else
        PartyGreeterDB[dbKey] = addon.CloneList(fallback)
    end
end

local function listToDisplay(list)
    return addon.ListToDisplayText(list)
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

local function buildGreetingOptionsPool()
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

    addAll(GREETING_PRESETS)
    addAll(addon.DEFAULTS.greetings)
    addAll(PartyGreeterDB.greetings)

    return pool
end

local function trimDisplay(text)
    if #text <= 54 then
        return text
    end

    return string.sub(text, 1, 51) .. "..."
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

local function createEditableListSetting(category, key, label, dbKey, defaultsList)
    local defaultString = listToDisplay(defaultsList)

    local function getValue()
        return listToDisplay(PartyGreeterDB[dbKey])
    end

    local function setValue(value)
        if value == SENTINELS.editList then
            local currentText = listToDisplay(PartyGreeterDB[dbKey])
            showListEditorPopup(label, currentText, function(text)
                applyListSetting(dbKey, text, defaultsList)
            end)
            return
        end

        applyListSetting(dbKey, value, defaultsList)
    end

    local setting = Settings.RegisterProxySetting(
        category,
        key,
        Settings.VarType.String,
        label,
        defaultString,
        getValue,
        setValue
    )

    local function getOptions()
        local container = Settings.CreateControlTextContainer()
        local currentString = listToDisplay(PartyGreeterDB[dbKey])
        local defaultsString = listToDisplay(defaultsList)

        container:Add(currentString, "Current: " .. trimDisplay(currentString))
        if defaultsString ~= currentString then
            container:Add(defaultsString, "Default: " .. trimDisplay(defaultsString))
        end
        container:Add(SENTINELS.editList, TEXT.editListOption)

        return container:GetData()
    end

    local initializer = Settings.CreateDropdown(category, setting, getOptions, nil)

    return setting, initializer
end

local function createGreetingsMultiSelectSetting(category, key, label)
    local function getOptionEntries()
        local entries = {}
        for index, greeting in ipairs(buildGreetingOptionsPool()) do
            entries[index] = {
                id = index,
                label = greeting,
            }
        end
        return entries
    end

    local function getMaskFromList(list, entries)
        local selected = {}
        if type(list) == "table" then
            for _, greeting in ipairs(list) do
                selected[greeting] = true
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

    local defaultMask = getMaskFromList(addon.DEFAULTS.greetings, getOptionEntries())

    local function getValue()
        local source = type(PartyGreeterDB.greetings) == "table" and PartyGreeterDB.greetings
            or addon.DEFAULTS.greetings
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
            selected = addon.CloneList(addon.DEFAULTS.greetings)
        end
        PartyGreeterDB.greetings = selected

        if not addRequested then
            return
        end

        showListEditorPopup(TEXT.addGreetingPopupTitle, "", function(text)
            local trimmed = addon.TrimWhitespace(text)
            if trimmed == "" then
                return
            end

            local updated = addon.CloneList(PartyGreeterDB.greetings)
            appendUnique(updated, trimmed)
            PartyGreeterDB.greetings = updated
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
        container:AddCheckbox(#entries + 1, TEXT.addGreetingOption, nil)

        return container:GetData()
    end

    local initializer = Settings.CreateDropdown(category, setting, getOptions, nil)
    return setting, initializer
end

function addon.RegisterSettingsPanel()
    if addon.optionsCategory or not Settings or not Settings.RegisterVerticalLayoutCategory then
        return
    end

    local category, layout = Settings.RegisterVerticalLayoutCategory(TEXT.title)
    addon.optionsCategory = category

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
    createEditableListSetting(
        category,
        addon.Settings.Keys.GroupTerms,
        TEXT.groupTermsLabel,
        "groupTerms",
        addon.DEFAULTS.groupTerms
    )

    Settings.RegisterAddOnCategory(category)
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

addon.RegisterSettingsPanel()

SLASH_PARTYGREETER1 = "/partygreeter"
SLASH_PARTYGREETER2 = "/pg"
SlashCmdList["PARTYGREETER"] = function()
    addon.OpenSettingsPanel()
end
