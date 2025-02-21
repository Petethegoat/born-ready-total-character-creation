local type = {
	vanilla = 1,
	custom = 2,
	random = 3,
	quickstart = 4,
	preconfigured = 5,
}

local newGameOptionsOpen = false
local newGameType = type.vanilla
local chargenScript = "CharGen"

local charGenerationMenu = require("Born Ready Total Character Creation.chargenMenu")

charGenerationMenu.startGameCallback = function()
	newGameType = type.custom
	menu:destroy()
	startNewGame(true)
end

--[[
	wishlist:
		disable tutorial messages via lua (without having to reimplement all the scripts maybe?)
]]

local cgName
local cgFemale
local cgRace
local cgClass
local cgBirthsign

local function setRandomEverything()
	local player = tes3.getObject("player")

	player.female = math.random() > 0.5
	player.name = (player.female and "Ms." or "Mr.") .. " Random"

	--stupid
	local safety = 100
	local n = math.random(#tes3.dataHandler.nonDynamicData.races)
	while not tes3.dataHandler.nonDynamicData.races[n].isPlayable and safety > 0 do
		n = math.random(#tes3.dataHandler.nonDynamicData.races)
		safety = safety + 1
	end
	player.race = tes3.dataHandler.nonDynamicData.races[n]
	player.head = player.female and player.race.femaleBody.head or player.race.maleBody.head
	player.hair = player.female and player.race.femaleBody.hair or player.race.maleBody.hair

	n = math.random(#tes3.dataHandler.nonDynamicData.classes)
	while not tes3.dataHandler.nonDynamicData.classes[n].playable and safety > 0 do
		n = math.random(#tes3.dataHandler.nonDynamicData.classes)
		safety = safety + 1
	end
	player.class = tes3.dataHandler.nonDynamicData.classes[n]

	n = math.random(#tes3.dataHandler.nonDynamicData.birthsigns)
	cgBirthsign = tes3.dataHandler.nonDynamicData.birthsigns[n]
	-- birthsign happens after game start
end

local function setupCharacter()
	if newGameType == type.vanilla then
		return
	elseif newGameType == type.random or newGameType == type.quickstart then
		setRandomEverything()
	else
		local player = tes3.getObject("player")
		player.name = cgName
		player.female = cgFemale
		player.race = cgRace
		player.head = player.female and player.race.femaleBody.head or player.race.maleBody.head
		player.hair = player.female and player.race.femaleBody.hair or player.race.maleBody.hair
		player.class = cgClass
		-- birthsign happens after game start
	end
end

local function finalizeCharacter()
	if newGameType == type.vanilla then
		return
	end

	for _, s in pairs(cgBirthsign.spells) do
		-- birthsign setting doesn't seem to work for abilities, but is fine for powers and spells.
		if s.castType == tes3.spellType.ability then
			tes3.addSpell{ reference = tes3.player, spell = s, updateGUI = true }
		end
	end
	tes3.mobilePlayer.birthsign = cgBirthsign

	local player = tes3.getObject("player")

	-- Attributes.
	for s, _ in pairs(tes3.mobilePlayer.attributes) do
		tes3.mobilePlayer.attributes[s].base = player.female and player.race.baseAttributes[s].female or player.race.baseAttributes[s].male
		if player.class.attributes[1] == s or player.class.attributes[2] == s then	-- Specializations.
			tes3.mobilePlayer.attributes[s].base = tes3.mobilePlayer.attributes[s].base + 10
		end
		tes3.mobilePlayer.attributes[s].current = tes3.mobilePlayer.attributes[s].base
	end

	-- Skills.
	for _, s in pairs(tes3.skill) do	-- Start by resetting skills.
		tes3.mobilePlayer:getSkillStatistic(s).base = 5
	end
	for _, s in pairs(player.race.skillBonuses) do	-- Race bonus skills.
		if s.bonus > 0 then
			tes3.mobilePlayer:getSkillStatistic(s.skill).base = tes3.mobilePlayer:getSkillStatistic(s.skill).base + s.bonus
		end
	end
	for _, m in ipairs(player.class.majorSkills) do	-- Major skills.
		tes3.mobilePlayer:getSkillStatistic(m).base = tes3.mobilePlayer:getSkillStatistic(m).base + 25
	end
	for _, m in ipairs(player.class.minorSkills) do	-- Minor skills.
		tes3.mobilePlayer:getSkillStatistic(m).base = tes3.mobilePlayer:getSkillStatistic(m).base + 10
	end
	for _, m in pairs(tes3.skill) do
		if tes3.getSkill(m).specialization == player.class.specialization then	-- Specializations.
			tes3.mobilePlayer:getSkillStatistic(m).base = tes3.mobilePlayer:getSkillStatistic(m).base + 5
		end

		-- Set current skills too.
		tes3.mobilePlayer:getSkillStatistic(m).current = tes3.mobilePlayer:getSkillStatistic(m).base
	end

	if tes3.player.object.race.isBeast then
		tes3.removeItem{ reference = tes3.player, item = "common_shoes_01", playSound = false }
	end
end

local function startNewGame(skipIntro)
	setupCharacter()

	if skipIntro and mge.enabled() then tes3.hammerKey(tes3.scanCode.esc) end
	tes3.newGame()
	if skipIntro and mge.enabled() then tes3.unhammerKey(tes3.scanCode.esc) end

	finalizeCharacter()
	newGameOptionsOpen = false
end

local function executeChargen()
	tes3.stopLegacyScript{script = chargenScript}

	if newGameType == type.vanilla then
		dofile("Born Ready Total Character Creation.vanilla")
	else
		dofile("Born Ready Total Character Creation.quickstart")
	end
end

--- @param e uiActivatedEventData
local function updateMenu(e)
	if not e.newlyCreated then return end
	local mainMenu = e.element
	local buttonContainer

	local button = mainMenu:findChild("MenuOptions_New_container")
	if button == nil then return end
	button:register(tes3.uiEvent.mouseClick, function()
		newGameOptionsOpen = not newGameOptionsOpen
		buttonContainer.visible = newGameOptionsOpen
		button.parent.visible = not newGameOptionsOpen
		tes3.worldController.menuClickSound:play()
	end)

	buttonContainer = button.parent.parent:createBlock()
	buttonContainer.autoWidth = true
	buttonContainer.height = 300
	buttonContainer.childAlignX = 0.5
	buttonContainer.visible = false
	buttonContainer.flowDirection = tes3.flowDirection.topToBottom

	local vanilla = buttonContainer:createImageButton{
		id =        "menu_newGameOptions_vanilla",
		idle =      "textures/menu_newgame.dds",
		over =      "textures/menu_newgame_over.dds",
		pressed =   "textures/menu_newgame_pressed.dds",
	}
	vanilla.height = 50
	vanilla.autoHeight = false
	vanilla:register(tes3.uiEvent.mouseClick, function()
		newGameType = type.vanilla
		startNewGame(false)
		tes3.worldController.menuClickSound:play()
	end)

	local custom = buttonContainer:createImageButton{
		id =        "menu_newGameOptions_custom",
		idle =      "textures/menu_custom.dds",
		over =      "textures/menu_custom_over.dds",
		pressed =   "textures/menu_custom_pressed.dds",
	}
	custom.height = 50
	custom.autoHeight = false
	custom:register(tes3.uiEvent.mouseClick, function()
		charGenerationMenu.createChargenMenu(buttonContainer)
		tes3.worldController.menuClickSound:play()
	end)

	local random = buttonContainer:createImageButton{
		id =        "menu_newGameOptions_random",
		idle =      "textures/menu_random.dds",
		over =      "textures/menu_random_over.dds",
		pressed =   "textures/menu_random_pressed.dds",
	}
	random.height = 50
	random.autoHeight = false
	random:register(tes3.uiEvent.mouseClick, function()
		newGameType = type.random
		startNewGame(true)
		tes3.worldController.menuClickSound:play()
	end)

	local quickstart = buttonContainer:createImageButton{
		id =        "menu_newGameOptions_quickstart",
		idle =      "textures/menu_quickstart.dds",
		over =      "textures/menu_quickstart_over.dds",
		pressed =   "textures/menu_quickstart_pressed.dds",
	}
	quickstart.height = 50
	quickstart.autoHeight = false
	quickstart:register(tes3.uiEvent.mouseClick, function()
		newGameType = type.quickstart
		startNewGame(true)
		tes3.worldController.menuClickSound:play()
	end)

	local back = buttonContainer:createImageButton{
		id =        "menu_newGameOptions_return",
		idle =      "textures/menu_back.dds",
		over =      "textures/menu_back_over.dds",
		pressed =   "textures/menu_back_pressed.dds",
	}
	back.height = 50
	back.autoHeight = false
	back:register(tes3.uiEvent.mouseClick, function()
		newGameOptionsOpen = not newGameOptionsOpen
		buttonContainer.visible = newGameOptionsOpen
		button.parent.visible = not newGameOptionsOpen
		tes3.worldController.menuClickSound:play()
	end)

	mainMenu:updateLayout()
end
event.register(tes3.event.uiActivated, updateMenu, { filter = "MenuOptions" })

event.register(tes3.event.initialized, function()
	mwse.overrideScript(chargenScript, executeChargen)
end)