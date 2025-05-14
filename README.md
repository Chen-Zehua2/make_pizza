# Pizza Making Game

A Roblox game where players can make pizzas from scratch, starting with dough preparation.

## Project Structure

- `src/client`: Client-side scripts
  - `DoughSystem.lua`: Handles dough interaction, slicing, and UI
  - `init.client.lua`: Main client entry point
- `src/server`: Server-side scripts
  - `init.server.lua`: Main server script for game setup
- `src/shared`: Shared modules
  - `Roact.lua`: Roact UI library (required - must be placed in shared folder)

## Features

### Dough System
- Click on dough to show interaction UI
- Slice dough by drawing a line across it
- Drag dough to move it around
- Sliced dough automatically becomes rounded using mesh

## Development Setup

This project uses:
- Rojo: For syncing code to Roblox Studio
- Roact: For building UI components (must be placed in src/shared/Roact.lua)

### Setup Instructions

1. Install Rojo plugin in Roblox Studio
2. Clone this repository
3. Ensure Roact module is placed in src/shared/Roact.lua
4. Run `rojo serve` from the project directory
5. Connect to the Rojo server from Roblox Studio
6. Run the game in Roblox Studio

## How to Play

1. Click on a dough to show interaction options
2. Click "Slice" to enter slicing mode
3. Draw a line across the dough to slice it (must be at least 75% of the dough length)
4. Click "Drag" to move the dough around

## License

This project is licensed under the MIT License.
