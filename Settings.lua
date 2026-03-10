local addon = PartyGreeter

local function applyListSetting(dbKey, rawText, fallback)
    local parsed = addon.ParseCommaSeparatedList(rawText)
    if parsed then
        PartyGreeterDB[dbKey] = parsed
    else
        PartyGreeterDB[dbKey] = addon.CloneList(fallback)
    end
end

local function getDelayForUI()
    local value = tonumber(PartyGreeterDB.delay) or addon.DEFAULTS.delay
    if value < 0 then
        return 0
    end

    return value
end

local function getBoundsForUI()
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

    return lowerBound, upperBound
end

function addon.RegisterSettingsPanel()
    if addon.optionsCategory or not Settings or not Settings.RegisterCanvasLayoutCategory then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = "Party Greeter"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Party Greeter")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure automatic party and raid greetings.")

    local includePlayerNameCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    includePlayerNameCheckbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -18)
    local includePlayerNameLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    includePlayerNameLabel:SetPoint("LEFT", includePlayerNameCheckbox, "RIGHT", 4, 1)
    includePlayerNameLabel:SetText("Include player name when greeting one member")

    local includeRealmCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    includeRealmCheckbox:SetPoint("TOPLEFT", includePlayerNameCheckbox, "BOTTOMLEFT", 0, -12)
    local includeRealmLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    includeRealmLabel:SetPoint("LEFT", includeRealmCheckbox, "RIGHT", 4, 1)
    includeRealmLabel:SetText("Include realm in member names")

    local useInRaidCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    useInRaidCheckbox:SetPoint("TOPLEFT", includeRealmCheckbox, "BOTTOMLEFT", 0, -12)
    local useInRaidLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    useInRaidLabel:SetPoint("LEFT", useInRaidCheckbox, "RIGHT", 4, 1)
    useInRaidLabel:SetText("Send greetings in raid groups")

    local randomDelayCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    randomDelayCheckbox:SetPoint("TOPLEFT", useInRaidCheckbox, "BOTTOMLEFT", 0, -22)
    local randomDelayLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    randomDelayLabel:SetPoint("LEFT", randomDelayCheckbox, "RIGHT", 4, 1)
    randomDelayLabel:SetText("Use random delay interval")

    local delayLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    delayLabel:SetPoint("TOPLEFT", randomDelayCheckbox, "BOTTOMLEFT", 0, -12)
    delayLabel:SetText("Delay before greeting (seconds)")

    local delaySlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    delaySlider:SetPoint("TOPLEFT", delayLabel, "BOTTOMLEFT", 0, -10)
    delaySlider:SetWidth(240)
    delaySlider:SetMinMaxValues(0, 15)
    delaySlider:SetValueStep(1)
    delaySlider:SetObeyStepOnDrag(true)

    local delayValueLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    delayValueLabel:SetPoint("LEFT", delaySlider, "RIGHT", 14, 0)

    local lowerBoundLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lowerBoundLabel:SetPoint("TOPLEFT", randomDelayCheckbox, "BOTTOMLEFT", 0, -12)
    lowerBoundLabel:SetText("Lower bound (seconds)")

    local lowerBoundInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    lowerBoundInput:SetPoint("TOPLEFT", lowerBoundLabel, "BOTTOMLEFT", 0, -6)
    lowerBoundInput:SetSize(90, 24)
    lowerBoundInput:SetAutoFocus(false)
    lowerBoundInput:SetNumeric(true)

    local upperBoundLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    upperBoundLabel:SetPoint("LEFT", lowerBoundInput, "RIGHT", 24, 0)
    upperBoundLabel:SetText("Upper bound (seconds)")

    local upperBoundInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    upperBoundInput:SetPoint("LEFT", upperBoundLabel, "RIGHT", 10, 0)
    upperBoundInput:SetSize(90, 24)
    upperBoundInput:SetAutoFocus(false)
    upperBoundInput:SetNumeric(true)

    local greetingsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    greetingsLabel:SetPoint("TOPLEFT", delaySlider, "BOTTOMLEFT", 0, -24)
    greetingsLabel:SetText("Greetings (comma-separated)")

    local greetingsInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    greetingsInput:SetPoint("TOPLEFT", greetingsLabel, "BOTTOMLEFT", 0, -8)
    greetingsInput:SetSize(430, 24)
    greetingsInput:SetAutoFocus(false)

    local groupTermsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    groupTermsLabel:SetPoint("TOPLEFT", greetingsInput, "BOTTOMLEFT", 0, -16)
    groupTermsLabel:SetText("Group terms (comma-separated)")

    local groupTermsInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    groupTermsInput:SetPoint("TOPLEFT", groupTermsLabel, "BOTTOMLEFT", 0, -8)
    groupTermsInput:SetSize(430, 24)
    groupTermsInput:SetAutoFocus(false)

    local helpLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    helpLabel:SetPoint("TOPLEFT", groupTermsInput, "BOTTOMLEFT", 0, -18)
    helpLabel:SetWidth(560)
    helpLabel:SetJustifyH("LEFT")

    local defaultHelpText = "Hover over an option to see what it does."
    helpLabel:SetText(defaultHelpText)

    local isRefreshing = false

    local function bindHoverHelp(widget, helpText)
        widget:SetScript("OnEnter", function()
            helpLabel:SetText(helpText)
        end)
        widget:SetScript("OnLeave", function()
            helpLabel:SetText(defaultHelpText)
        end)
    end

    local function applyDelayBoundsFromInputs()
        local lowerText = addon.TrimWhitespace(lowerBoundInput:GetText())
        local upperText = addon.TrimWhitespace(upperBoundInput:GetText())

        local lowerBound = tonumber(lowerText)
        local upperBound = tonumber(upperText)
        if not lowerBound then
            lowerBound = addon.DEFAULTS.delayLowerBound
        end
        if not upperBound then
            upperBound = addon.DEFAULTS.delayUpperBound
        end

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

        PartyGreeterDB.delayLowerBound = lowerBound
        PartyGreeterDB.delayUpperBound = upperBound
    end

    local function applyDelayModeVisibility(randomEnabled)
        if randomEnabled then
            delayLabel:Hide()
            delaySlider:Hide()
            delayValueLabel:Hide()

            lowerBoundLabel:Show()
            lowerBoundInput:Show()
            upperBoundLabel:Show()
            upperBoundInput:Show()

            greetingsLabel:ClearAllPoints()
            greetingsLabel:SetPoint("TOPLEFT", lowerBoundInput, "BOTTOMLEFT", 0, -20)
        else
            delayLabel:Show()
            delaySlider:Show()
            delayValueLabel:Show()

            lowerBoundLabel:Hide()
            lowerBoundInput:Hide()
            upperBoundLabel:Hide()
            upperBoundInput:Hide()

            greetingsLabel:ClearAllPoints()
            greetingsLabel:SetPoint("TOPLEFT", delaySlider, "BOTTOMLEFT", 0, -24)
        end
    end

    local function refreshControls()
        isRefreshing = true

        includePlayerNameCheckbox:SetChecked(PartyGreeterDB.includePlayerName)
        includeRealmCheckbox:SetChecked(PartyGreeterDB.includeRealm)
        useInRaidCheckbox:SetChecked(PartyGreeterDB.useInRaid)
        local randomDelayEnabled = PartyGreeterDB.randomDelayEnabled and true or false
        randomDelayCheckbox:SetChecked(randomDelayEnabled)
        applyDelayModeVisibility(randomDelayEnabled)

        local delayValue = math.floor(getDelayForUI() + 0.5)
        delaySlider:SetValue(delayValue)
        delayValueLabel:SetText(tostring(delayValue))

        local lowerBound, upperBound = getBoundsForUI()
        lowerBoundInput:SetText(tostring(lowerBound))
        upperBoundInput:SetText(tostring(upperBound))

        greetingsInput:SetText(addon.ListToDisplayText(PartyGreeterDB.greetings))
        groupTermsInput:SetText(addon.ListToDisplayText(PartyGreeterDB.groupTerms))

        isRefreshing = false
    end

    includePlayerNameCheckbox:SetScript("OnClick", function(self)
        PartyGreeterDB.includePlayerName = self:GetChecked() and true or false
    end)

    includeRealmCheckbox:SetScript("OnClick", function(self)
        PartyGreeterDB.includeRealm = self:GetChecked() and true or false
    end)

    useInRaidCheckbox:SetScript("OnClick", function(self)
        PartyGreeterDB.useInRaid = self:GetChecked() and true or false
    end)

    delaySlider:SetScript("OnValueChanged", function(self, value)
        if isRefreshing then
            return
        end

        local rounded = math.floor((value or 0) + 0.5)
        if rounded ~= value then
            isRefreshing = true
            self:SetValue(rounded)
            isRefreshing = false
        end

        PartyGreeterDB.delay = rounded
        delayValueLabel:SetText(tostring(rounded))
    end)

    randomDelayCheckbox:SetScript("OnClick", function(self)
        PartyGreeterDB.randomDelayEnabled = self:GetChecked() and true or false
        applyDelayModeVisibility(PartyGreeterDB.randomDelayEnabled)
    end)

    lowerBoundInput:SetScript("OnEnterPressed", function(self)
        applyDelayBoundsFromInputs()
        self:ClearFocus()
        refreshControls()
    end)
    lowerBoundInput:SetScript("OnEditFocusLost", function()
        applyDelayBoundsFromInputs()
        refreshControls()
    end)

    upperBoundInput:SetScript("OnEnterPressed", function(self)
        applyDelayBoundsFromInputs()
        self:ClearFocus()
        refreshControls()
    end)
    upperBoundInput:SetScript("OnEditFocusLost", function()
        applyDelayBoundsFromInputs()
        refreshControls()
    end)

    greetingsInput:SetScript("OnEnterPressed", function(self)
        applyListSetting("greetings", self:GetText(), addon.DEFAULTS.greetings)
        self:ClearFocus()
        refreshControls()
    end)
    greetingsInput:SetScript("OnEditFocusLost", function(self)
        applyListSetting("greetings", self:GetText(), addon.DEFAULTS.greetings)
        refreshControls()
    end)

    groupTermsInput:SetScript("OnEnterPressed", function(self)
        applyListSetting("groupTerms", self:GetText(), addon.DEFAULTS.groupTerms)
        self:ClearFocus()
        refreshControls()
    end)
    groupTermsInput:SetScript("OnEditFocusLost", function(self)
        applyListSetting("groupTerms", self:GetText(), addon.DEFAULTS.groupTerms)
        refreshControls()
    end)

    bindHoverHelp(includePlayerNameCheckbox, "When enabled, greetings include the player's name when only one new member joins.")
    bindHoverHelp(includeRealmCheckbox, "When enabled, names include realm (for example Name-Realm). When disabled, only character names are used.")
    bindHoverHelp(useInRaidCheckbox, "When enabled, greetings are sent in RAID chat. When disabled, no raid greeting is sent.")
    bindHoverHelp(delaySlider, "Fixed delay in seconds before sending a greeting. Used when random interval is disabled.")
    bindHoverHelp(randomDelayCheckbox, "Enable random delay mode. When enabled, each greeting uses a random delay between lower and upper bounds.")
    bindHoverHelp(lowerBoundInput, "Minimum delay (seconds) for random interval mode.")
    bindHoverHelp(upperBoundInput, "Maximum delay (seconds) for random interval mode.")
    bindHoverHelp(greetingsInput, "Comma-separated list of greeting starters (for example: Hi, Hello, Sup).")
    bindHoverHelp(groupTermsInput, "Comma-separated terms used when greeting multiple members (for example: guys, folks, everyone).")

    panel:SetScript("OnShow", refreshControls)

    addon.optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Party Greeter")
    Settings.RegisterAddOnCategory(addon.optionsCategory)
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
