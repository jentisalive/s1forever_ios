# Sonic Forever for iOS

Native arm64 iOS adaptation of Team Forever's Sonic 1 Forever 1.5.0, using the RSDKv4 decompilation. Requires iOS 15 or later. Intended for installation through TrollStore or a compatible signing tool.

## Status

Initial port. Check the latest GitHub Actions build for compilation status. A successful build is not a device playtest; menus, touch controls, audio and full level progression still need testing on an iPhone.

## Install

1. Open **Actions → Build iOS**, select a successful run and download **SonicForever-iOS**.
2. Extract the artifact ZIP and install the `.ipa` (or `.tipa`) with your compatible installer.
3. Launch **Sonic Forever** and tap **Import Data.rsdk**. Select the data archive from your own Sonic 1 (2013) copy. The app copies it into its Documents folder.
4. Saves, settings and mods are accessible in **Files → On My iPhone → Sonic Forever**. To replace the data archive later, close the game and replace `Data.rsdk` there.

The original Sonic 1 data archive is not included in the repository or build. Sonic 2 data and an unconverted Origins datapack are not substitutes. The importer checks the RSDKv4 format; game compatibility is checked when the engine loads it.

## Build

The workflow builds on a macOS GitHub Actions runner with Xcode. To build manually on a Mac:

```sh
bash scripts/build-ios.sh
```

Dependencies are fetched at pinned commits by `scripts/fetch-deps.sh`. `scripts/prepare-ios.py` applies checked iOS patches to that engine checkout and stages the bundled Forever mod. No signing certificate or Apple Developer account is needed to generate the ad-hoc signed artifact. Installation depends on your device's installer and signing environment.

## Port implementation

- SDL2 UIKit app lifecycle, OpenGL ES 1 rendering and arm64 build.
- Native document picker for user-owned game data.
- Writable Documents directory for saves, configuration and mods.
- Bundled Forever mod enabled on first launch; touch mode selected on startup.
- Static SDL2/Ogg/Vorbis libraries; no externally installed frameworks.

## Credits and original project information

iOS integration: jentisalive project. Original Forever code and resources belong to Team Forever and the credited contributors. Engine: Rubberduckycooly, RMGRich and RSDKModding contributors. Original RSDK: Christian Whitehead. Sonic: SEGA and Sonic Team.

# Sonic the Hedgehog Forever
A modification of the 2013 mobile port, based on the 2021 decompilation


"Sonic the Hedgehog Forever" is a non-profit project. It is not
affiliated with SEGA®, Sonic Team®, or Christian Whitehead in any way.
Sonic the Hedgehog is a trademark of SEGA®. All copyrights regarding Sonic
the Hedgehog, including characters, names, terms, art, and music belong to
SEGA®. All registered trademarks belong to SEGA® and Sonic Team®. The
developers of "Sonic the Hedgehog Forever" have no intent to infringe said
copyrights and registered trademarks. No financial gain is made from this
project.


# Credits

Team Leads:
- Aprkot
- ElspethThePict
- AlyStyle


Coding:
- AlyStyle
- Cosmic Eternity
- ElspethThePict
- Tania
- with contributions by
	- Leonx254 
	- GeffGeff

Art:
- AlyStyle
- Aprkot
- Cosmic Eternity
- Cyb
- KatKuriN
- King the Memer
- Louplayer
- RetroForever
- Storice
- TruthTomato
- Viator_
- with contributions by
	- GreenKnight9000
	- Makoto

Player Animations:
- RetroForever

Music:
- Glacesu
- KatKuriN
- SNick!

Translation:
- Aprkot
- Cybercymbre
- Freezer X-Treme
- RetroForever
- Storice
- ThunderLeon
- TruthTomato
- WorksOfMagic

Testing:
- AlyStyle
- BrySkye
- Burrotis Man
- Cosmic Eternity
- Cybercymbre
- Denzel The Eternal Understudy
- Freezer X-Treme
- Goofyking
- Greenie
- Louplayer
- MCDUltra
- Petlamb
- Pyxie
- RetroForever
- Storice
- Tania
- ThunderLeon
- TruthTomato

Social Media:
- Petlamb

Trailers:
- AlyStyle
- Cosmic Eternity
- Elspeth The Pict

Original Drop Dash Code:
- MainMemory
- campbellsonic
- splemb
	
Scrap Brain Zone GG/MS remix by Gustavo Firmino Cazonato
- used with permission
- https://www.youtube.com/watch?v=CYL_XCmn_78
	
Original Boss Rush Tileset by Egg Master, Techokami, and Dolphman/RetroBunyip	
- https://www.spriters-resource.com/custom_edited/sonicthehedgehogcustoms/sheet/116537/

Amy Moveset and Sprites inspired by the Amy Mania mod by Troopsushi and CodenameGamma
- used with permission
- https://gamebanana.com/wips/50006
	

RSDKv3/v4 DECOMPILATION by RubberDuckyCooly and RMGRich
- https://github.com/Rubberduckycooly/Sonic-1-2-2013-Decompilation

> The code in this repository is a decompilation of RSDK (Retro-Engine)	version 3 or 4. There is original code in this repo, but most of the code is to be functionally the same as the version of RSDK this repo	specifies.
> 
> This code is provided as-is, that is to say, without liability or	warranty. Original authors of RSDK and authors of the decompilation	are not held responsible for any damages or other claims said. You may copy, modify, contribute, and distribute, for public or private use,	as long as the following are followed:
> 
> - You may not use the decompilation for commercial (any sort of profit) use.
> - You must clearly specify that the decompilation and original code are	not yours: the developers of both must be credited.
> - You may not distribute assets used to run the game not directly provided	by the repository (other than unique, modded assets).
> - This license must be in all modified copies of source code, and all forks	must follow this license.
> 
> Original RSDK author: Christian "Taxman" Whitehead
> 
> Decompilation authors: Rubberduckycooly and RMGRich

Special thanks to Lave SIime for their help with SonLVL and format information

Special thanks to RubberDuckyCooly, Megami, Leonx254, and the users of Retro Engine Modding Server for their advice, assistance and feedback.
- https://dc.railgun.works/retroengine
	
Special Thanks to huds601, flying fox, and HyperStormH for extra testing and feedback.

Original Game by SEGA® and Sonic Team®

Ported by Taxman and Stealth
