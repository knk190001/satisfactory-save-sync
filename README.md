# Satisfactory Save Sync

Sync your Satisfactory save files between multiple players

## Table of Contents

- [Satisfactory Save Sync](#satisfactory-save-sync)
  - [Table of Contents](#table-of-contents)
  - [About ](#about-)
  - [Warning ](#warning-)
  - [Getting Started ](#getting-started-)
    - [Prerequisites](#prerequisites)
    - [Installing](#installing)
      - [Setting up for a new sync group](#setting-up-for-a-new-sync-group)
      - [Setting up for an existing sync group](#setting-up-for-an-existing-sync-group)
  - [Usage ](#usage-)
  - [Documentation](#documentation)

## About <a name = "about"></a>

Satisfactory Save Sync is a tool that allows you to sync your save files between multiple players. It is designed to be used with the Steam version of the game, and is an temporary alternative using dedicated servers.

## Warning <a name = "warning"></a>

This app tampers with your save files, and can cause data loss. Use at your own risk. It does create backups of your save files locally, but it is recommended to manually backup your save files before using this app. Neither Ficsit Inc. nor I am responsible for any data loss caused by this app.

## Getting Started <a name = "getting_started"></a>

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See [deployment](#deployment) for notes on how to deploy the project on a live system.

### Prerequisites

- GitHub account
- Git installed on your machine, and configured with your GitHub account
- Write access to the repository, ([fork it](https://github.com/husain3012/satisfactory-save-sync) to create your own synced repository )
- Satisfactory installed on your machine (Steam version)

### Installing

#### Setting up for a new sync group

This will clear all existing save files in the repository, and create a new sync group. This is irreversible, and will cause data loss. Use with caution. It won't delete any save files from your game.

1. Fork this repository to your account here: [Fork]()
2. Clone the repository to your local machine
3. Make sure you give write access to the repository to all the players you want to sync with

4. Run the following command in powershell

   ```bash
   .\app.ps1 setup
   ```

5. Enter Game ID (for satisfactory, it is `526870`)
6. Enter the path to your save files (example: `C:\Users\<UserName>\AppData\Local\FactoryGame\Saved\SaveGames\<UserID>`)
7. **NOTE**: The path should be absolute, and **should not** have aliases like `%LOCALAPPDATA%`
8. Add regex patterns for save files to sync (example: `^Autosave`, `^1\.0.*`)

The script will copy all save files from the specified path to the repository, and commit and push them.

#### Setting up for an existing sync group

1. Clone the repository to your local machine
2. Make sure you give write access to the repository
3. Set your save files path using:

   ```bash
   .\app.ps1 set-save-path
   ```

4. Enter the path to your save files (example: `C:\Users\<UserName>\AppData\Local\FactoryGame\Saved\SaveGames\<UserID>`)
5. **NOTE**: The path should be absolute, and **should not** have aliases like `%LOCALAPPDATA%`

## Usage <a name = "usage"></a>

- To sync your save files, run the following command in powershell:

    ```bash
    .\sync.ps1
    ```

- To run the game, with automatically syncing save files, run the following command in powershell:

    ```bash
    .\run.ps1
    ```

## Documentation

Too lazy to write this