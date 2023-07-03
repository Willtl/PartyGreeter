# WoW Party Greeter Addon

A World of Warcraft addon for automatically greeting new party members with customizable messages, delays, and other settings.

## Features

- Customizable greetings
- Ability to include the player's name and realm in the greeting
- Configurable delay before the greeting is sent after a player joins the party
- Greeting can be sent in a raid group as well
- Personalized group terms when greeting multiple players
- A set of slash commands for live customization of the addon's settings

## Installation

1. Download the repository.
2. Extract the content into your `World of Warcraft\_retail_\Interface\AddOns` directory.
3. Restart the game if it is currently running (or use `/reload ui`).

## Usage

Use the following slash commands to configure the addon:

- `/partygreeter`: Lists the current settings.
- `/partygreeter delay <number>`: Sets the delay before the greeting is sent.
- `/partygreeter realm <true/false>`: Specifies whether to include the player's realm in the greeting.
- `/partygreeter playername <true/false>`: Specifies whether to include the player's name in the greeting.
- `/partygreeter useinraid <true/false>`: Specifies whether to use the greeter in raid groups.
- `/partygreeter greetings <greeting1,greeting2,...>`: Sets the list of possible greetings.
- `/partygreeter groupterms <term1,term2,...>`: Sets the custom group terms for greeting.
- `/partygreeter reset`: Resets all settings to their default values.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
