# Reliable Jaw Stab

A Project Zomboid Build 42 mod: once a jaw stab has started, it lands on its zombie, even when multiplayer lag moved the zombie a little out of reach.

## The problem

A jaw stab (the knife's one-hit kill) is chosen when the attack starts: the zombie must be closer than the knife's minimum range (0.61 tiles for a hunting knife). The hit itself is decided later, at the hit point of the animation, against the knife's maximum range (0.9 tiles) and swing angle. Nothing holds the zombie still in between.

In single player the zombie keeps walking into you, so this almost never misses. In multiplayer the zombie on your screen follows the server with small corrections. A jaw stab started near the edge of its range can find no target at the hit point: your character plays the kill animation, no hit is sent to the server, and the zombie just keeps walking.

## What the mod does

At the hit point of a jaw stab (vanilla's `OnWeaponSwingHitPoint` event, which runs right before the game looks for targets), if the nearest standing zombie drifted out of reach but is still within 1.5 tiles, the mod puts it back 0.45 tiles in front of you on your own client. The game then finds it and the normal hit goes to the server, which kills it the vanilla way.

- Only jaw stabs (a knife critical with the `KnifeDeath` hit reaction). Normal stabs, shoves and other weapons are untouched.
- A zombie that is already in reach is left alone.
- A zombie farther than 1.5 tiles, behind a wall, a closed door or a window, or more than one square away is never pulled.

## What it does not change

- When a jaw stab can start (one chasing zombie, the critical roll) is vanilla.
- Knife sticking in the zombie is vanilla. If the server rejects a hit because of lag (attack rate check), the client-server mismatch that can follow is not fixed here.

## Compatibility

- Lua only, client side. No vanilla files replaced. Each player who wants the fix needs it; the server does not.
- Safe to add to or remove from a save.
- Works alongside other jaw stab mods (Better Jaw Stabs, One Clean Jaw Stab and the like); it only acts at the hit point. Not tested together.
- Checked in single player (Build 42.22.2) with a real jaw stab where the test moved the zombie 1.1 tiles to the side after the stab started: without the mod the zombie survives (the bug), with the mod it dies by the jaw stab. Multiplayer: not tested.

## Install

[Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3841038777), or copy `Contents/mods/ReliableJawStab` into `%USERPROFILE%\Zomboid\mods\`.

## Testing

`pzt live` (PZTestHarness) in this folder runs `tests/ReliableJawStab_Test.lua` in one client: the jaw stab check, a normal jaw stab (the mod does nothing), a drift with the mod off (zombie survives), a drift with the mod on (zombie killed, moved once), and a drift beyond reach (left alone).

## Support

If this mod helps you, you can support it via [Ko-fi](https://ko-fi.com/talkinghands2285) or [PayPal](https://www.paypal.com/paypalme/TalkingHands619/3). It's optional; every feature stays free.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/talkinghands2285)
