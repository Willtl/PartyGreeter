-- Persistent variables
greetings = greetings or { "Hi", "Hello", "Sup" }
delay = delay or 4
includeRealm = includeRealm or false
includePlayerName = includePlayerName or true

-- Local variables
local greetingTimer = nil
local partySize = 0
local greetedMembers = {}
local newMembers = {}

-- Function for sending a random greeting to new party members
local function sendRandomGreeting()
    -- Only proceed if there are new members to greet
    if #newMembers > 0 then
        -- Select a random greeting
        local message = greetings[math.random(#greetings)]

        -- Append the player names if option is set
        if includePlayerName then
            message = message .. " " .. table.concat(newMembers, ", ")
        end

        -- Send the greeting
        SendChatMessage(message, "PARTY")

        -- Clear the list of new members
        newMembers = {}
    end
end

-- Function for identifying and greeting new party members
local function greetNewPartyMembers()
    -- Retrieve current party size
    local currentPartySize = GetNumGroupMembers()

    -- Reset the list of greeted members if we are the only one in the party
    if partySize == 0 and currentPartySize == 1 then
        greetedMembers = {}
    elseif currentPartySize > 1 and currentPartySize > partySize then
        -- If the party has grown, check for new members
        local homePartyMembers = {}
        GetHomePartyInfo(homePartyMembers)

        -- For each party member...
        for _, name in ipairs(homePartyMembers) do
            -- Check if we have already greeted this player
            if not tContains(greetedMembers, name) then
                -- Split name and realm, and only use the name if includeRealm is false
                local playerName, playerRealm = strsplit("-", name)
                if includeRealm then
                    table.insert(newMembers, name)
                    table.insert(greetedMembers, name)
                else
                    table.insert(newMembers, playerName)
                    table.insert(greetedMembers, name)
                end
            end
        end

        -- If a greeting timer is already active, cancel it
        if greetingTimer then
            greetingTimer:Cancel()
        end

        -- Create a new timer to send a greeting after `delay` seconds
        -- This timer will only be created if there are new members to greet
        greetingTimer = C_Timer.NewTicker(delay, function()
            sendRandomGreeting()

            -- Cancel the ticker after it fires once
            greetingTimer:Cancel()
            greetingTimer = nil
        end)
    end

    -- Update the party size
    partySize = currentPartySize
end


-- Create a frame to track party changes
local eventFrame = CreateFrame("Frame")

-- Register the event to track party changes
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- Set the function to call when the event is fired
eventFrame:SetScript("OnEvent", greetNewPartyMembers)

-- Create a slash command for configuration
SLASH_PARTYGREETER1 = "/partygreeter"
SlashCmdList["PARTYGREETER"] = function(msg)
    local command, value = strsplit(" ", msg, 2)

    -- Help command
    if command == "help" then
        print("Party Greeter commands:")
        print("/partygreeter : Shows current settings.")
        print("/partygreeter delay <seconds> : Set the delay before greeting new party members.")
        print("/partygreeter realm <true/false> : Set whether to include the realm in greetings.")
        print("/partygreeter playername <true/false> : Set whether to include the player name in greetings.")
        print("/partygreeter greetings <greeting1,greeting2,...> : Set custom greetings separated by commas.")
        return
    end

    -- No command, show current settings
    if command == "" then
        print("Current settings are:")
        print("Greetings: " .. table.concat(greetings, ", "))
        print("Delay: " .. delay)
        print("Include player name in greeting: " .. tostring(includePlayerName))
        print("Include realm in greeting: " .. tostring(includeRealm))
        -- Change delay
    elseif command == "delay" then
        local newDelay = tonumber(value)
        if newDelay then
            delay = newDelay
            print("New delay set: " .. delay)
        else
            print("Invalid delay value. Please provide a number.")
        end
        -- Change realm inclusion
    elseif command == "realm" then
        if value == "true" then
            includeRealm = true
            print("Include realm in greeting: ON")
        elseif value == "false" then
            includeRealm = false
            print("Include realm in greeting: OFF")
        else
            print("Invalid realm value. Please provide either 'true' or 'false'.")
        end
        -- Change player name inclusion
    elseif command == "playername" then
        if value == "true" then
            includePlayerName = true
            print("Include player name in greeting: ON")
        elseif value == "false" then
            includePlayerName = false
            print("Include player name in greeting: OFF")
        else
            print("Invalid playername value. Please provide either 'true' or 'false'.")
        end
        -- Change greetings
    else
        greetings = { strsplit(",", msg) }

        for i, v in ipairs(greetings) do
            greetings[i] = strtrim(v)
        end

        print("New greetings set:")
        for _, v in ipairs(greetings) do
            print(v)
        end
    end
end
