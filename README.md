# RogueHUD

A rogue HUD for the WoW Forever client. It shows energy, combo points, dual-wield swings, cooldown rows, poison inventory, and weapon enchant status. It only loads for rogues.

## Installation

Download the latest release zip and extract it into `Interface/AddOns` so the addon manifest is at `Interface/AddOns/RogueHUD/RogueHUD.toc`.

## Releases

Releases are built from `vX.Y.Z` Git tags. The tag must match `## Version` in `RogueHUD.toc`. GitHub Actions packages the addon and publishes it to GitHub Releases. With the `CF_API_KEY` repository secret, the packager also uploads tagged versions to CurseForge. Wago imports GitHub releases through its release webhook.

## License

RogueHUD's original code and media are licensed under [Apache License 2.0](LICENSE), copyright 2026 beemerwt. The bundled Inter fonts remain under the [SIL Open Font License 1.1](Media/Fonts/LICENSE-Inter-OFL.txt).

## Getting started

1. Enable RogueHUD for your rogue and click its minimap icon, type `/roguehud`, or use **Options > AddOns > RogueHUD** to open its settings.
   Press Escape to close the settings window. RogueHUD waits for windows managed by the game that were already open to close first.
2. Use **General** to unlock and move the HUD, then lock it again.
3. Configure the game's Cooldown Manager Essential and Utility categories. RogueHUD uses those choices and their order. If a category cannot be read, it shows a known-spell rogue fallback.
4. Choose poison visibility and order in **Poisons**. Left click a poison badge for the main hand; right click for the off hand. The badge counts only the highest usable rank currently in your bags.

Poison badges start on the left for new profiles. Existing poison placement is preserved. Cooldown icons are display only; the **Cooldowns** page controls their swipe, countdown numbers, tint, and opacity. The **Bars** page adjusts bar sizes and orders the vertical HUD with Up and Down buttons. Its default top-to-bottom order is Essential cooldowns, Combo Points, Health, Energy, swing lanes, and Utility cooldowns. Health remains hidden until enabled. Use **Reset Order** to restore that sequence without resetting other settings.

The **Castbar** page controls a separate player castbar modeled on the saved ForeverAuras player castbar group. It shows casts and channels outside the HUD stack, below it by default with a 10 screen-pixel gap. It follows HUD width and scale, but stays fully opaque. Its default look has a 26-pixel height, 26-by-26 spell icon with its own 30% zoom setting and 2-pixel gap, Rogue-yellow fill, centered spell name with a 10 screen-pixel right offset, right-side remaining time, and red latency segment. Spell-name alignment and horizontal offset are independent settings; the name stays clipped to its space beside the timer. Icon size stays square and can extend beyond the progress bar; the HUD gap is measured from its visible edge. The GCD overlay from the ForeverAuras group is omitted. While RogueHUD and its castbar are enabled, the game's player castbar is replaced; disabling either restores it. Existing profiles keep their castbar enabled choice, while their old ordered castbar settings migrate to the new defaults.

The HUD's default appearance follows ForeverCatLitter's compact Feral proportions: one physical-pixel black borders, a warm dark backdrop, 8% icon crop, 2-pixel gaps, a 240-wide bar, and separate 36/28-pixel cooldown rows. RogueHUD retains its rogue resource colors and red expiry-warning borders. **Appearance** controls texture, font, borders, icon shape and overlay, zoom, shadows, swipe darkness, and colors for each theme. All existing profiles receive the new visual dimensions once; their positions, bar order, visibility, and behavior settings are preserved. RogueHUD's texture assets are original.

Energy text shows current energy only. Health text can show percentage (the default), current health, or both with current health 4 units inside the left edge and percentage 4 units inside the right edge. Current health is abbreviated in whole thousands from 100,000 upward (`1,428,000` displays as `1428 K`). The **Bars** page controls health text visibility and format. Its GCD setting draws a colored trail clockwise over the energy bar border during the global cooldown, with a soft spark at the moving tip. The trail matches the border thickness, and the sample HUD preview shows part of it.

The **Cues** page sets separate Slice and Dice and Rupture warning thresholds. While either aura is active, its icon shows whole seconds remaining. Its border turns red below its threshold and stays red after the aura ends until the target changes or dies. An aura already active on the new target starts from its current remaining time.

When learned, Riposte is appended to Essential regardless of the selected cooldown source. Its icon appears during its cooldown or when the client reports it usable after a parry, and the row closes the gap when it disappears. During the usable window, its border is red if **Show cues** is enabled; using Riposte clears that border and shows the cooldown. Riposte ignores **Only show on cooldown** and the global icon opacity settings. The hidden spell IDs setting can suppress it. A proc that the client does not report as usable, such as one masked by insufficient energy, may not be shown.

HUD text defaults to Inter SemiBold. The **Appearance** page offers Inter, Inter Medium, Inter SemiBold, and the previous font choices. The selected font applies to RogueHUD-created HUD text; the settings window and Blizzard's cooldown countdown digits keep their own fonts. Existing profiles switch to Inter SemiBold once and can select another font afterward. The former “Rogue Feral” theme is now “Default”; existing profiles and old import codes retain their colors when its saved ID changes to `default`.

The bundled static `Inter-Regular.ttf`, `Inter-Medium.ttf`, and `Inter-SemiBold.ttf` files come from the [official Inter 4.1 release](https://github.com/rsms/inter/releases/tag/v4.1) (`Inter-4.1.zip`, `extras/ttf/`). The original copyright notice and SIL Open Font License 1.1 are in [Media/Fonts/LICENSE-Inter-OFL.txt](Media/Fonts/LICENSE-Inter-OFL.txt). When LibSharedMedia has a font registered under a matching Inter name, RogueHUD uses that registration; the bundled files keep it independent of ForeverAuras and LibSharedMedia.

The energy bar turns purple in Stealth and bluish-gray while a readable Vanish aura is active. It returns to the selected theme's energy color when stealth ends. Preview shows the normal theme color. Older profiles and import codes no longer add a separate STEALTH alert bar.

`/rhud` is an alias. `/roguehud lock`, `/roguehud unlock`, `/roguehud reset`, and `/roguehud preview` are also available.

Left-click the minimap icon to open or close settings, or drag it around the minimap. **General > Show minimap icon** hides or restores it. Its position and visibility are saved per character across profiles. The icon is hidden while **Show RogueHUD** is off; the slash command and AddOns settings remain available.

## Poison weapon status

The client reports temporary weapon enchant IDs and remaining time. RogueHUD learns a poison family's enchant ID after it observes a successful application from one of its badges. Until it can identify an existing enchant, the hand status shows `enchant ?` with its remaining time. It never labels an unknown enchant as a specific poison.

Secure item actions are configured outside combat. If the carried rank changes during combat, the badge's action switches to the new rank when combat ends.

## Profiles and sounds

The **Profiles** page copies the current settings into a named profile and offers a `RHUD1:` export and import code. These profiles are independent of ForeverCatLitter. The **Sounds** page accepts rules as `spell ID,success|start,path,channel`, separated by semicolons. Sound files must be accessible inside the game folder.

## Acknowledgment

The layout and feature concept were inspired by ForeverCatLitter (Miao Litter) by Elspeth. RogueHUD's implementation and media are original; no ForeverCatLitter source or media is bundled.
