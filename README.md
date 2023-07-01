# WoW Party Greeter Addon

This repository contains the code for a World of Warcraft addon that automatically greets new members when they join your party.

## Features

- Customizable greetings
- Ability to include the player's name and realm in the greeting
- Configurable delay before the greeting is sent after a player joins the party

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
- `/partygreeter <greeting1,greeting2,...>`: Sets the list of possible greetings.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.