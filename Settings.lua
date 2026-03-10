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

    local delayLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    delayLabel:SetPoint("TOPLEFT", useInRaidCheckbox, "BOTTOMLEFT", 0, -22)
    delayLabel:SetText("Delay before greeting (seconds)")

    local delaySlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    delaySlider:SetPoint("TOPLEFT", delayLabel, "BOTTOMLEFT", 0, -10)
    delaySlider:SetWidth(240)
    delaySlider:SetMinMaxValues(0, 15)
    delaySlider:SetValueStep(1)
    delaySlider:SetObeyStepOnDrag(true)

    local delayValueLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    delayValueLabel:SetPoint("LEFT", delaySlider, "RIGHT", 14, 0)

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

    local isRefreshing = false

    local function refreshControls()
        isRefreshing = true

        includePlayerNameCheckbox:SetChecked(PartyGreeterDB.includePlayerName)
        includeRealmCheckbox:SetChecked(PartyGreeterDB.includeRealm)
        useInRaidCheckbox:SetChecked(PartyGreeterDB.useInRaid)

        local delayValue = math.floor(getDelayForUI() + 0.5)
        delaySlider:SetValue(delayValue)
        delayValueLabel:SetText(tostring(delayValue))

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
SlashCmdList["PARTYGREETER"] = function()
    addon.OpenSettingsPanel()
end
