--Prevent vanilla chargen scripts from running. Thanks Merlord.
local otherChargenScripts = {
	"CharGen_ring_keley",
	"ChargenBed",
	"ChargenBoatNPC",
	"CharGenBoatWomen",
	"CharGenClassNPC",
	"CharGenCustomsDoor",
	"CharGenDagger",
	"CharGenDialogueMessage",
	"CharGenDoorEnterCaptain",
	"CharGenFatigueBarrel",
	"CharGenDoorExit",
	"CharGenDoorExitCaptain",
	"CharGenDoorGuardTalker",
	"CharGenJournalMessage",
	"CharGenNameNPC",
	"CharGenRaceNPC",
	"CharGenStatsSheet",
	"CharGenStuffRoom",
	"CharGenWalkNPC",
}
local chargenObjects = {
	"CharGen Boat",
	"CharGen Boat Guard 1",
	"CharGen Boat Guard 2",
	"CharGen Dock Guard",
	"CharGen_cabindoor",
	"CharGen_chest_02_empty",
	"CharGen_crate_01",
	"CharGen_crate_01_empty",
	"CharGen_crate_01_misc01",
	"CharGen_crate_02",
	"CharGen_lantern_03_sway",
	"CharGen_ship_trapdoor",
	"CharGen_barrel_01",
	"CharGen_barrel_02",
	"CharGenbarrel_01_drinks",
	"CharGen_plank",
	"CharGen StatsSheet",
}

--Disable chargen scripts
for _, script in pairs(otherChargenScripts) do
    mwse.overrideScript(script, function() end)
end
--Disable chargen objects
for _, id in ipairs(chargenObjects) do
    tes3.getReference(id):disable()
end
--unlock door to census office
tes3.getReference("CharGen Door Hall").attachments.lock.locked = false

tes3.setGlobal("CharGenState", -1)

local tradehouse = tes3.getCell{id = "Seyda Neen, Arrille's Tradehouse"}
tes3.positionCell{cell = tradehouse, position = tes3vector3.new(-446, -198, 386)}