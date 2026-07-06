### GearCheck
- A lightweight inventory and gear parse utility for Ashita version 4+

### Overview
- Automatically scans your active inventory against your LuAshitacast profiles to verify you have all required gear on hand.
- Identifies missing equipment and tells you exactly which storage container (Safe, Storage, Satchel, etc.) it was left in.
- Zero automation, it's parsing gear to make sure you have them on your character, if not it tells you the location to grab them from.

### Features
- **Gear Tracking:** Parses your LuAshitacast `.lua` profile line-by-line to extract standard equipment slots.
- **Item Tracking:** Track custom items (`Item1` through `Item20` by creating a set called gearcheck).
    ```lua
    gearcheck = {
        Item1 = 'Silent Oil',
        Item2 = 'Tavnazian Ring',
        Item3 = 'Squid Sushi',
        Item4 = 'Warp Cudgel',
        Item5 = 'Sole Sushi',
        Item6 = 'Toolbag (Shihe)',
    };
    ```
- **Search:** Cross-references equipable items with active gear containers (Inventory & Wardrobes). If items are not able to be equipped (Safe, Locker, Satchel, etc.) it will let you know their location so that you can grab them.
- **Color-Coded Feedback:** Prints a sorted list to the chat log prioritizing completely missing items (`Not Found`) followed by items in storage.
- **Case & Spelling Senitive Matching:** Ex. Matches `Tpl. Cyclas +1` not (`Temple Cyclas +1` or `temple cyclas +1`)

### Screenshots

![gc1](https://github.com/Mr-Sithel/gearcheck/blob/main/Example1.png?raw=true)

![gc2](https://github.com/Mr-Sithel/gearcheck/blob/main/Example2.png?raw=true)

### Commands

* `/gearcheck validate` or `/gc validate` - Automatically detects your current main job and validates your inventory against that specific LuAshitacast profile.
* `/gearcheck <job>` or `/gc <job>` - Manually checks your inventory against a specified job profile (e.g., `/gc sam`). 
* `/gearcheck` or `/gc` - Displays the command help menu.

### Installation

* Download and unzip the addon into your Ashita addons directory.
* Addon directory is: `...\Game\addons\GearCheck`
* This was created for `Ashita (Interface v4.30)`
* You can load the addon by typing `/addon load GearCheck`. It is recommended to add this line to your `scripts/default.txt` file to load it automatically on startup.

#### Credit
- Created by Sithel and some A.I.