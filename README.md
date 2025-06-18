# The Bubble - DCS dynamic unit culling

## Why and how this works
DCS AI is heavy on CPU, on myc potapo CPU(I7-3770) i get bottleneck at around 400 ground units, and just disabling AI(setAI on/off) not working, seems like AI still active and doing some calculations, just not doing anything in 3D world. This simple script respawn group with disable AI(LATE ACTIVATIOAN + VISIBLE BEFORE ACTIVATION) and activate ob the fly when Aircraft/Helo close enough. This allows large missions(all Iran on PG with ~1000 units) works with GPU bound even on F-4!

## Limitaions
* Only gound units supported.
* Moving vehicles not supported, they will despawn and stay on their position
* Script won't help is you have compacted areq with hungreds on unts and larget battles, it main purpose is large missions on vast expanse, it just helps your pc, unused units so you PC won't do AI math of SAM site 400km from you

# Quick start
1. Add MIST to mission
2. Include bubble.lua AFTER MIST

* Quick add all units(except EW radars)
```
--Add all ground units from red coalition, with automatic activation range:
BubbleSystem:addGroups(coalition.side.RED) 
--start service
BubbleSystem:start() 
```
* Skynet iads also supported, all SAM will be added automatically
```
--Add all ground units from red coalition, with automatic activation range:
BubbleSystem:addGroups(coalition.side.RED, iadsInstance)  
```
# Advanced settings
```
BubbleSystem:addGroupsByPrefix(prefix, activateRange, iads, callbackActivate, callbackDeactivate, onlyPlayers)
```
* prefix - name prefix of groups, all group contains prefix in name will be added. Also can be just group name
* activateRange - from aircraft/helo opposite coalition to activate group. Minimum 20000 recommended, script execute checks every 30 sec, very small values may result that fast mover will fly right through
* iads - SkynetIADS instance, will add group to IADS on spawn
* callbackActivate/callbackDeactivate - callback to execute on activate/deactivate events
```
arg = {
group = DCS Group,
iads = SkynetIADS which group belongs to,
iadsSam = Skynet SAM of group
}
```
you can use it to setup SkynetIADS SAM:
```
function HAWKCLBK(arg) 
--Modify HARM Detection chance of SAM
arg.iadsSam:setHARMDetectionChance(75)
end

local iads = SkynetIADS:create("red")
--add all groups with 'HAWK' in name
BubbleSystem:addGroupsByPrefix("HAWK", 30*1852, iads, HAWKCLB)
```
* onlyForPlayers - this group will activate only for player controlled aircraft, can be useful to activate AAA/SHORAD only for players, and skip to AI flights
