# APAnti
Garry's Mod (GMod) Anti Prop Griefing Solution.


Note: This version is currently untested if you are unsure about using it or are afraid to break things please use https://github.com/LuaTenshi/GLua/tree/master/APAnti

GitHub: Guess.<br/>
Pronunciation: Ae Pea Anti<br/>
Note: What is it with you guys being so lewd and calling this "a panty".<br/>

# Features
- Blocks prop damage and has the ability to freeze props that have hit a player.
- Attempts to stop explosives from exploding.
- Allows you to stop props from taking damage (breaking).
- Allows you to stops prop pushing.
- Allows you to ghosts props when they spawn.
- Allows you to stop vehicles from hitting players.
- Allows you to stop vehicles from doing any damage.
- Allows you to stop players from being able to fling props.
- Allows you to blacklist additional classes. (So that they are not allowed to do damage)
- Allows you to whitelist additional classes. (So that they are allowed to do damage)
- Allows you to auto freeze unfrozen props over time. (To reduce lag)

**You can toggle all of the above features to make this Anti Prop Kill work exactly how you want it to.**

Note: This now comes with a tool for unghosting props without having to physgun them. Useful when building.

# Base APAnti Commands
    Command = Default Value : Description
    
    --- Base AntiPK ---
    apa_antipk 				 = 1, "setting this to 1 will enable anti prop kill.",
    apa_physgunnerf 		 = 1, "setting this to 1 will limit the physgun speed.",
    apa_blockvehicledamage 	 = 1, "setting this to 1 will stop vehicle damage.",
    apa_blockexplosiondamage  = 1, "setting this to 1 will block explosion damage.",
    --- Prop Control ---
    apa_unbreakableprops 	 = 0, "setting this to 1 will make props unbreakable. (disabled by default.)",
    apa_nocollidevehicles 	 = 1, "setting this to 1 will make vehicles not collide with players.",
    apa_nothrow				 = 1, "setting this to 1 will stop people from throwing props.",
    --- Freezing ---
    apa_stopmassunfreeze	 = 1, "setting this to 1 will stop people from unfreezing all their props by double tapping r.",
    apa_stoprunfreeze		 = 0, "setting this to 1 will stop people from unfreezing props by tapping r.",
    apa_freezeonhit 		 = 1, "setting this to 1 will freeze props when they hit a player. (needs antipk.)",
    apa_freezeondrop 		 = 0, "setting this to 1 will freezes props when a player lets go of them. (disabled by default.)",
    apa_freezeonunghost		 = 1, "setting this to 1 will freeze props when they unghost.",
    apa_freezepassive		 = 0, "setting this to 1 will freeze props passivly. (disabled by default.)",
    --- Ghosting ---
    apa_antipush 			 = 1, "setting this to 1 will enable anti prop push (ghosting).",
    apa_ghostspawn			 = 1, "setting this to 1 will enable ghosting on spawn.",
    apa_ghostfreeze			 = 0, "setting this to 1 will freeze ghosts.",
    apa_unghostpassive		 = 0, "setting this to 1 will passivly unghost props. (disabled by default.) (needs antipush.)",
    apa_ghostsnocollide		 = 0, "setting this to 1 will make ghosts nocollide with everything.",
    --- AntiCrash ---
    apa_anticrash			 = 0, "setting this to 1 will enable the anticrash. (disabled by default.) (experimental.)"
# AntiCrash Plugin Commands
Note: The AntiCrash was created by [Kefta](https://github.com/Kefta/) and has its own [Github Page](https://github.com/Kefta/Entity-Crash-Catcher)

    Command = Default Value : Description
    
    -- Notifications --
    apa_anticrash_echofreeze 	 = 0, "tell players when a entity is frozen.",
    apa_anticrash_echoremove 	 = 1, "tell players when a entity is removed.",
    -- Speed --
    apa_anticrash_freezespeed	 = 2000, "Velocity ragdoll is frozen at; make greater than RemoveSpeed if you want to disable freezing.",
    apa_anticrash_removespeed 	 = 4000, "Velocity ragdoll is removed at.",
    -- Delays --
    apa_anticrash_freezetime 	 = 1, "time body is frozen for.",
    apa_anticrash_thinkdelay 	 = 0, "how often the server should check for bad ragdolls; change to 0 to run every think.",
    -- Check For --
    apa_anticrash_effectplayers	 = 0, "check player velocity.",
    apa_anticrash_velocityhook 	 = 1, "check entities for unreasonable velocity.",
    apa_anticrash_unreasonablehook  = 1, "check entities for unreasonable angles/positions.",
    apa_anticrash_massunfreeze	 = 0, "check if lots of entities are being unfrozen in an area and put them to sleep."
