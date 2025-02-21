local charGenerationMenu = {}

charGenerationMenu.startGameCallback = {}

--- @class tes3birthsign
local cgBirthsign = nil

local attributeIcons = {
	[0] = "strength",
	[1] = "int",
	[2] = "wilpower",
	[3] = "agility",
	[4] = "speed",
	[5] = "endurance",
	[6] = "personality",
	[7] = "luck",
}
local attributeDescStartingGMST = tes3.gmst.sStrDesc

local backgroundsInterop = require("mer.characterBackgrounds.interop")
local cgBackground = nil

local cgHead = 1
local cgHair = 1
local lastRace = nil
local lastSex = nil
local heads = {}
local hairs = {}
local function GetHeadHairsForRace()
	local player = tes3.getObject("player") --[[@as tes3npc]]
	if lastRace == player.race and lastSex == player.female then
		return
	end
	lastRace = player.race
	lastSex = player.female
	cgHead = 1
	cgHair = 1
	heads = {}
	hairs = {}

	for o in tes3.iterateObjects(tes3.objectType.bodyPart) do
		if not o.deleted and o.partType == tes3.activeBodyPartLayer.base and
		o.raceName == player.race.name and o.playable and player.female == o.female and not o.vampiric then
			if o.part == tes3.partIndex.head then
				table.insert(heads, o)
			elseif o.part == tes3.partIndex.hair then
				table.insert(hairs, o)
			end
		end
	end
end

local function updatePlayerStats()
	local player = tes3.getObject("player") --[[@as tes3npc]]
	-- Attributes.
	for s = 1, #player.attributes do
		player.attributes[s] = player.female and player.race.baseAttributes[s].female or player.race.baseAttributes[s].male
		if player.class.attributes[1] == s or player.class.attributes[2] == s then	-- Specializations.
			player.attributes[s] = player.attributes[s] + 10
		end
	end

	-- Skills.
	for s = 1, #player.skills do	-- Start by resetting skills.
		player.skills[s] = 5
	end
	for _, s in pairs(player.race.skillBonuses) do	-- Race bonus skills.
		if s.bonus > 0 then
			player.skills[s.skill + 1] = player.skills[s.skill + 1] + s.bonus
		end
	end
	for _, m in ipairs(player.class.majorSkills) do	-- Major skills.
		player.skills[m + 1] = player.skills[m + 1] + 25
	end
	for _, m in ipairs(player.class.minorSkills) do	-- Minor skills.
		player.skills[m + 1] = player.skills[m + 1] + 10
	end
	for _, m in pairs(tes3.skill) do
		if tes3.getSkill(m).specialization == player.class.specialization then	-- Specializations.
			player.skills[m + 1] = player.skills[m + 1] + 5
		end
	end
end

local function createEffectLine(parent, spellEffect, spellType, indent)
	local effect = parent:createBlock()
	effect.autoHeight = true
	effect.autoWidth = true
	effect.borderAllSides = 4
	effect.borderLeft = 4 + indent
	local icon = effect:createImage{ path = string.format("icons\\%s", spellEffect.object.icon) }
	icon.borderTop = 1
	icon.borderRight = 6
	local label
	if spellType == tes3.spellType.ability then
		local labelString = string.format("%s", spellEffect)
		label = effect:createLabel{ text = labelString:sub(1, #labelString - 8) }
	else
		label = effect:createLabel{ text = string.format("%s", spellEffect) }
	end
	label.wrapText = false
end

--- @param parent tes3uiElement
local function createSpells(parent, spells, spellType, label, showEffects)
	if not spells:containsType(spellType) then return end

	parent:createLabel{ text = label }.color = tes3ui.getPalette(tes3.palette.headerColor)
	for _, s in pairs(spells) do
		if s.castType == spellType then
			local spell = parent:createLabel{ text = s.name }
			spell.borderLeft = 8
			if showEffects then
				for i = 1, #s.effects do
					local e = s.effects[i]
					if e.id == -1 then break end
					-- Abilities do not use durations!
					if s.castType == tes3.spellType.ability then
						e.duration = 0
					end
					createEffectLine(parent, e, spellType, 8)
				end
			else
				spell:register(tes3.uiEvent.help, function()
					local help = tes3ui.createTooltipMenu()
					help:getContentElement().childAlignX = 0
					for i = 1, #s.effects do
						local e = s.effects[i]
						if e.id == -1 then break end
						-- Abilities do not use durations!
						if s.castType == tes3.spellType.ability then
							e.duration = 0
						end
						createEffectLine(help, e, spellType, 0)
					end
				end)
			end
		end
	end
end

--- @return tes3uiElement
local function createStatLine(parent, label, value, indent)
	local b = parent:createBlock()
	b.borderLeft = indent
	b.autoHeight = true
	b.widthProportional = 1
	b.childAlignX = -1
	b:createLabel{ text = label }
	b:createLabel{ text = "" .. value }
	b.consumeMouseEvents = true
	return b
end

local function createSkillLine(parent, skill, value, indent)
	createStatLine(parent, tes3.getSkillName(skill), value, indent):register(tes3.uiEvent.help, function()
		tes3ui.createTooltipMenu{ skill = tes3.getSkill(skill) }
	end)
end

--- @param attribute tes3.attribute
local function createAttributeTooltip(attribute)
	local tooltip = tes3ui.createTooltipMenu()
	tooltip:getContentElement().autoHeight = true
	tooltip:getContentElement().maxWidth = 400
	tooltip:getContentElement().childAlignX = 0
	tooltip:getContentElement().paddingAllSides = 10
	local block = tooltip:createBlock()
	block.autoHeight = true
	block.autoWidth = true
	block.childAlignY = 0.5
	block:createImage{ path = "icons\\k\\attribute_" .. attributeIcons[attribute] .. ".dds" }
	local title = block:createLabel{ text = tes3.getAttributeName(attribute) }
	title.color = tes3ui.getPalette(tes3.palette.headerColor)
	title.borderLeft = 10
	local desc = tooltip:createLabel{ text = tes3.findGMST(attributeDescStartingGMST + attribute).value }
	desc.autoHeight = true
	desc.widthProportional = 1
	desc.borderTop = 4
	desc.wrapText = true
	return tooltip
end

--- @param topBlock tes3uiElement
local function createReviewBlock(topBlock)
	local old = topBlock:findChild("chargen_review")
	if old then old:destroy() end

	updatePlayerStats()

	local review = topBlock:createBlock{ id = "chargen_review" }
	review.heightProportional = 1
	review.widthProportional = 0.9

	local player = tes3.getObject("player")
	local left = review:createBlock()
	left.widthProportional = 1
	left.autoHeight = true
	left.flowDirection = tes3.flowDirection.topToBottom
	local main = left:createThinBorder{ id = "main" }
	main.widthProportional = 1
	main.autoHeight = true
	main.flowDirection = tes3.flowDirection.topToBottom
	main.paddingAllSides = 8
	main.borderAllSides = 4
	createStatLine(main, "Name", player.name, 0)
	createStatLine(main, "Race", player.race.name, 0)
	createStatLine(main, "Class", player.class.name, 0)
	createStatLine(main, "Birthsign", cgBirthsign.name, 0)
	if backgroundsInterop and cgBackground then
		createStatLine(main, "Background", cgBackground.name, 0)
	end

	local stats = left:createThinBorder{ id = "attributes" }
	stats.widthProportional = 1
	stats.autoHeight = true
	stats.flowDirection = tes3.flowDirection.topToBottom
	stats.paddingAllSides = 8
	stats.borderAllSides = 4
	for _, s in pairs(tes3.attribute) do
		createStatLine(stats, tes3.getAttributeName(s), player.attributes[s + 1]):register(tes3.uiEvent.help, function()
			createAttributeTooltip(s)
		end)
	end

	local spells = left:createThinBorder{ id = "spells" }
	spells.widthProportional = 1
	spells.autoHeight = true
	spells.flowDirection = tes3.flowDirection.topToBottom
	spells.paddingAllSides = 8
	spells.borderAllSides = 4
	createSpells(spells, player.race.abilities, tes3.spellType.ability, "Racial Abilities", false)
	createSpells(spells, player.race.abilities, tes3.spellType.power, "Racial Powers", false)
	createSpells(spells, player.race.abilities, tes3.spellType.spell, "Racial Spells", false)
	createSpells(spells, cgBirthsign.spells, tes3.spellType.ability, "Birthsign Abilities", false)
	createSpells(spells, cgBirthsign.spells, tes3.spellType.power, "Birthsign Powers", false)
	createSpells(spells, cgBirthsign.spells, tes3.spellType.spell, "Birthsign Spells", false)

	local skills = review:createThinBorder{ id = "skills" }
	skills.widthProportional = 1
	skills.autoHeight = true
	skills.flowDirection = tes3.flowDirection.topToBottom
	skills.paddingAllSides = 8
	skills.borderAllSides = 4
	skills:createLabel{ text = "Major Skills" }.color = tes3ui.getPalette(tes3.palette.headerColor)
	for _, s in ipairs(player.class.majorSkills) do
		createSkillLine(skills, s, player.skills[s + 1], 8)
	end

	local minor = skills:createLabel{ text = "Minor Skills"}
	minor.color = tes3ui.getPalette(tes3.palette.headerColor)
	minor.borderTop = 8
	for _, s in ipairs(player.class.minorSkills) do
		createSkillLine(skills, s, player.skills[s + 1], 8)
	end

	local misc = skills:createLabel{ text = "Miscellaneous Skills"}
	misc.color = tes3ui.getPalette(tes3.palette.headerColor)
	misc.borderTop = 8
	for _, s in pairs(tes3.skill) do
		local skip = false
		for _, v in ipairs(player.class.skills) do
			if s == v then
				skip = true
				break
			end
		end

		if not skip then
			createSkillLine(skills, s, player.skills[s + 1], 8)
		end
	end

	tes3ui.findMenu("menu_chargen"):updateLayout()
end

--- @param tab tes3uiElement
--- @param topBlock tes3uiElement
local function createRaceTab(tab, topBlock, scrollOverride, headZ, headX)
	local old = topBlock:findChild("race_content")
	if old then old:destroy() end

	local player = tes3.getObject("player")

	local content = tab:createBlock{ id = "race_content" }
	content.widthProportional = 1
	content.heightProportional = 1
	content.paddingAllSides = 8
	content.flowDirection = tes3.flowDirection.topToBottom

	local sub = content:createBlock()
	sub.widthProportional = 1
	sub.autoHeight = true

	local pane = sub:createVerticalScrollPane{ id = "race_scroll" }
	pane.widthProportional = -1
	pane.heightProportional = -1
	pane.width = 240
	pane.height = 256
	pane.paddingAllSides = 8
	for i = 1, #tes3.dataHandler.nonDynamicData.races do
		local r = tes3.dataHandler.nonDynamicData.races[i]
		if r.isPlayable then
			local button = pane:createTextSelect{ id = "race_button:" .. r.id }
			button:register(tes3.uiEvent.mouseClick, function()
				player.race = r
				createRaceTab(tab, topBlock, pane.widget.positionY, 180, 45)
				createReviewBlock(topBlock)
			end)
			button.text = r.name
			if r == player.race then
				button.widget.state = tes3.uiState.active
			end
		end
	end
	pane:getTopLevelMenu():updateLayout()
	pane.widget.positionY = scrollOverride

	local subRight = sub:createBlock()
	subRight.widthProportional = 1
	subRight.autoHeight = true
	subRight.flowDirection = tes3.flowDirection.topToBottom
	subRight.borderLeft = 4
	subRight.childAlignX = 0.5

	local subRightTop = subRight:createBlock()
	subRightTop.widthProportional = 1
	subRightTop.autoHeight = true
	subRightTop.childAlignX = 0.5

	GetHeadHairsForRace()

	local head = subRightTop:createThinBorder{ id = "race_head" }
	head.width = 240
	head.height = 240
	head.paddingAllSides = 2
	head.borderBottom = 2
	head.borderRight = 2
	head.consumeMouseEvents = true

	local headXRotate = subRightTop:createSliderVertical{ current = headX, max = 90 }
	headXRotate.height = 240
	headXRotate.autoWidth = true

	local headZRotate = subRight:createSlider{ current = headZ, max = 360 }
	headZRotate.width = 240
	headZRotate.autoHeight = true
	headZRotate.borderRight = 14

	local mouseX, mouseY
	head:register(tes3.uiEvent.mouseDown, function(e)
		tes3ui.captureMouseDrag(true)
		mouseX = e.relativeX
		mouseY = e.relativeY
	end)
	head:register(tes3.uiEvent.mouseStillPressed, function(e)
		headXRotate.widget.current = math.clamp(headXRotate.widget.current + e.relativeY - mouseY, 0, headXRotate.widget.max)
		headZRotate.widget.current = (headZRotate.widget.current + e.relativeX - mouseX) % headZRotate.widget.max
		headXRotate:triggerEvent(tes3.uiEvent.partScrollBarChanged)
		headZRotate:triggerEvent(tes3.uiEvent.partScrollBarChanged)
		headZRotate:getTopLevelMenu():updateLayout()
		mouseX = e.relativeX
		mouseY = e.relativeY
	end)
	head:register(tes3.uiEvent.mouseRelease, function(e)
		tes3ui.captureMouseDrag(false)
	end)

	local buttonBlock = subRight:createBlock()
	buttonBlock.autoWidth = true
	buttonBlock.autoHeight = true
	buttonBlock.flowDirection = tes3.flowDirection.leftToRight

	local sex = buttonBlock:createButton{ text = "Sex" }
	sex:register(tes3.uiEvent.mouseClick, function()
		player.female = not player.female
		createRaceTab(tab, topBlock, pane.widget.positionY, headZRotate.widget.current, headXRotate.widget.current)
		createReviewBlock(topBlock)
	end)
	local nextHead = buttonBlock:createButton{ text = "Head " .. cgHead }
	nextHead:register(tes3.uiEvent.mouseClick, function()
		cgHead = math.max(1, (cgHead + 1) % #heads)
		createRaceTab(tab, topBlock, pane.widget.positionY, headZRotate.widget.current, headXRotate.widget.current)
		createReviewBlock(topBlock)
	end)
	local nextHair = buttonBlock:createButton{ text = "Hair " .. cgHair }
	nextHair:register(tes3.uiEvent.mouseClick, function()
		cgHair = math.max(1, (cgHair + 1) % #hairs)
		createRaceTab(tab, topBlock, pane.widget.positionY, headZRotate.widget.current, headXRotate.widget.current)
		createReviewBlock(topBlock)
	end)

	local desc = content:createLabel{ id = "race_desc", text = player.race.description }
	desc.wrapText = true
	desc.autoHeight = true
	desc.borderAllSides = 8

	local details = content:createBlock()
	details.widthProportional = 1
	details.autoHeight = true

	local skills = details:createBlock()
	skills.flowDirection = tes3.flowDirection.topToBottom
	skills.width = 200
	skills.autoHeight = true
	skills:createLabel{ text = "Skill Bonuses" }.color = tes3ui.getPalette(tes3.palette.headerColor)
	for _, s in pairs(player.race.skillBonuses) do
		if s.bonus > 0 then
			createSkillLine(skills, s.skill, s.bonus, 8)
		end
	end

	local spells = details:createBlock()
	spells.flowDirection = tes3.flowDirection.topToBottom
	spells.autoWidth = true
	spells.autoHeight = true
	spells.borderLeft = 16
	createSpells(spells, player.race.abilities, tes3.spellType.ability, "Abilities", false)
	createSpells(spells, player.race.abilities, tes3.spellType.power, "Powers", false)
	createSpells(spells, player.race.abilities, tes3.spellType.spell, "Spells", false)

	local headPath = heads[cgHead].mesh
	local hairPath = hairs[cgHair].mesh
	player.head = heads[cgHead]
	player.hair = hairs[cgHair]

	local preview = head:createNif{ path = "pg_headref.nif" }
	preview.absolutePosAlignX = 0.5
	preview.absolutePosAlignY = 0.5
	preview:updateLayout()

	local node = preview.sceneNode ---@type any
	local subNode = node.children[2]
	local stencil = node.children[1]
	local childNif = tes3.loadMesh(headPath, false)
	subNode:attachChild(childNif)
	node:update()

	local maxDimension
	local bb = subNode:createBoundingBox(subNode.scale)
	local height = bb.max.z - bb.min.z
	local width = bb.max.y - bb.min.y
	local depth = bb.max.x - bb.min.x
	maxDimension = math.max(width, depth, height)
	local targetHeight = 170
	subNode.scale = targetHeight / maxDimension
	stencil.scale = (head.width - (head.paddingAllSides * 2)) / 100

	-- Attach hair after calculating the bounding box to get more consistent dimensions.
	childNif = tes3.loadMesh(hairPath, false)
	subNode:attachChild(childNif)

	do --add properties
		local zBufferProperty = niZBufferProperty.new()
		zBufferProperty.name = "zbuf yo"
		zBufferProperty:setFlag(true, 0)
		zBufferProperty:setFlag(true, 1)
		node:attachProperty(zBufferProperty)
	end

	do --Apply rotation
		local matrix = tes3matrix33.new()
		local matrix2 = tes3matrix33.new()
		matrix:toRotationZ(math.rad(180) + math.rad(-headZ))
		matrix2:toRotationX(math.rad(-headX + 45))
		subNode.rotation = matrix * matrix2
		local offset = -270
		local lowestPoint = bb.min.z * subNode.scale
		offset = offset - lowestPoint
		subNode.translation.z = subNode.translation.z + offset + targetHeight
		subNode:update()
	end

	node:updateEffects()
	node:updateProperties()
	node.appCulled = false
	node:update()

	headZRotate:register(tes3.uiEvent.partScrollBarChanged, function()
		local matrix = tes3matrix33.new()
		local matrix2 = tes3matrix33.new()
		matrix:toRotationZ(math.rad(180) + math.rad(-headZRotate.widget.current))
		matrix2:toRotationX(math.rad(-headXRotate.widget.current + 45))
		subNode.rotation = matrix * matrix2
		subNode:update()
	end)
	headXRotate:register(tes3.uiEvent.partScrollBarChanged, function()
		local matrix = tes3matrix33.new()
		local matrix2 = tes3matrix33.new()
		matrix:toRotationZ(math.rad(180) + math.rad(-headZRotate.widget.current))
		matrix2:toRotationX(math.rad(-headXRotate.widget.current + 45))
		subNode.rotation = matrix * matrix2
		subNode:update()
	end)

	tab:updateLayout()
end

--- @param tab tes3uiElement
--- @param topBlock tes3uiElement
local function createClassTab(tab, topBlock, scrollOverride)
	local old = topBlock:findChild("class_content")
	if old then old:destroy() end

	local player = tes3.getObject("player")

	local content = tab:createBlock{ id = "class_content" }
	content.widthProportional = 1
	content.heightProportional = 1
	content.childAlignX = 0.5
	content.paddingAllSides = 8
	content.flowDirection = tes3.flowDirection.topToBottom

	local sub = content:createBlock()
	sub.widthProportional = 1
	sub.autoHeight = true

	local pane = sub:createVerticalScrollPane{ id = "class_scroll" }
	pane.widthProportional = -1
	pane.heightProportional = -1
	pane.width = 240
	pane.height = 256
	pane.paddingAllSides = 8
	for i = 1, #tes3.dataHandler.nonDynamicData.classes do
		local c = tes3.dataHandler.nonDynamicData.classes[i]
		if c.playable then
			local button = pane:createTextSelect{ id = "class_buttton:" .. c.id }
			button:register(tes3.uiEvent.mouseClick, function()
				player.class = c
				createClassTab(tab, topBlock, pane.widget.positionY)
				createReviewBlock(topBlock)
			end)
			button.text = c.name
			if c == player.class then
				button.widget.state = tes3.uiState.active
			end
		end
	end
	pane:getTopLevelMenu():updateLayout()
	pane.widget.positionY = scrollOverride

	local subRight = sub:createBlock()
	subRight.widthProportional = 1
	subRight.autoHeight = true
	subRight.flowDirection = tes3.flowDirection.topToBottom
	subRight.borderLeft = 4
	subRight.childAlignX = 0.5

	local border = subRight:createThinBorder()
	border.autoHeight = true
	border.autoWidth = true
	border.paddingAllSides = 2
	border:createImage{ id = "class_image", path = player.class.image}

	local desc = subRight:createLabel{ id = "class_desc", text = player.class.description }
	desc.wrapText = true
	desc.autoHeight = true
	desc.borderAllSides = 8

	local details = content:createBlock()
	details.widthProportional = 1
	details.autoHeight = true
	details.flowDirection = tes3.flowDirection.leftToRight
	details.borderTop = 8

	local left = details:createBlock()
	left.flowDirection = tes3.flowDirection.topToBottom
	left.widthProportional = 1
	left.autoHeight = true
	local specialization = left:createLabel{ text = "Specialization" }
	specialization.color = tes3ui.getPalette(tes3.palette.headerColor)
	specialization:register(tes3.uiEvent.help, function()
		tes3ui.createTooltipMenu():createLabel{ text = tes3.findGMST(tes3.gmst.sCreateClassMenuHelp1).value }
	end)
	left:createLabel{ text = tes3.getSpecializationName(player.class.specialization) }.borderBottom = 8
	local favored = left:createLabel{ text = "Favorite Attributes" }
	favored.color = tes3ui.getPalette(tes3.palette.headerColor)
	favored:register(tes3.uiEvent.help, function()
		tes3ui.createTooltipMenu():createLabel{ text = tes3.findGMST(tes3.gmst.sCreateClassMenuHelp2).value }
	end)
	left:createLabel{ text = tes3.getAttributeName(player.class.attributes[1]) }:register(tes3.uiEvent.help, function()
		createAttributeTooltip(player.class.attributes[1])
	end)
	left:createLabel{ text = tes3.getAttributeName(player.class.attributes[2]) }:register(tes3.uiEvent.help, function()
		createAttributeTooltip(player.class.attributes[2])
	end)

	local mid = details:createBlock()
	mid.flowDirection = tes3.flowDirection.topToBottom
	mid.widthProportional = 1
	mid.autoHeight = true
	local major = mid:createLabel{ text = "Major Skills" }
	major.color = tes3ui.getPalette(tes3.palette.headerColor)
	major:register(tes3.uiEvent.help, function()
		tes3ui.createTooltipMenu():createLabel{ text = "You'll get +25 to your major skills, and they are easiest to increase." }
	end)
	for _, s in ipairs(player.class.majorSkills) do
		mid:createLabel{ text = tes3.getSkillName(s) }:register(tes3.uiEvent.help, function()
			tes3ui.createTooltipMenu{ skill = tes3.getSkill(s) }
		end)
	end

	local right = details:createBlock()
	right.flowDirection = tes3.flowDirection.topToBottom
	right.widthProportional = 1
	right.autoHeight = true
	local minor = right:createLabel{ text = "Minor Skills" }
	minor.color = tes3ui.getPalette(tes3.palette.headerColor)
	minor:register(tes3.uiEvent.help, function()
		tes3ui.createTooltipMenu():createLabel{ text = "You'll get +10 to your minor skills, and they are easier to increase than miscellaneous skills." }
	end)
	for _, s in ipairs(player.class.minorSkills) do
		right:createLabel{ text = tes3.getSkillName(s) }:register(tes3.uiEvent.help, function()
			tes3ui.createTooltipMenu{ skill = tes3.getSkill(s) }
		end)
	end

	tab:updateLayout()
end

--- @param tab tes3uiElement
--- @param topBlock tes3uiElement
local function createBirthsignTab(tab, topBlock, scrollOverride)
	local old = topBlock:findChild("birth_content")
	if old then old:destroy() end

	local content = tab:createBlock{ id = "birth_content" }
	content.widthProportional = 1
	content.heightProportional = 1
	content.paddingAllSides = 8
	content.flowDirection = tes3.flowDirection.topToBottom

	local sub = content:createBlock()
	sub.widthProportional = 1
	sub.autoHeight = true

	local pane = sub:createVerticalScrollPane{ id = "birth_scroll" }
	pane.widthProportional = -1
	pane.heightProportional = -1
	pane.width = 240
	pane.height = 256
	pane.paddingAllSides = 8
	for i = 1, #tes3.dataHandler.nonDynamicData.birthsigns do
		local birth = tes3.dataHandler.nonDynamicData.birthsigns[i]
		local button = pane:createTextSelect{ id = "birth_button:" .. birth.id }
		button:register(tes3.uiEvent.mouseClick, function()
			cgBirthsign = birth
			createBirthsignTab(tab, topBlock, pane.widget.positionY)
			createReviewBlock(topBlock)
		end)
		button.text = birth.name
		if birth == cgBirthsign then
			button.widget.state = tes3.uiState.active
		end
	end
	pane:getTopLevelMenu():updateLayout()
	pane.widget.positionY = scrollOverride

	local subRight = sub:createBlock()
	subRight.widthProportional = 1
	subRight.autoHeight = true
	subRight.flowDirection = tes3.flowDirection.topToBottom
	subRight.borderLeft = 4
	subRight.childAlignX = 0.5

	local border = subRight:createThinBorder()
	border.autoHeight = true
	border.autoWidth = true
	border.paddingAllSides = 2
	border:createImage{ id = "birth_image", path = "Textures\\" .. cgBirthsign.texturePath }

	local desc = subRight:createLabel{ id = "birth_desc", text = cgBirthsign.description }
	desc.wrapText = true
	desc.autoHeight = true
	desc.borderAllSides = 8

	local spells = content:createBlock()
	spells.flowDirection = tes3.flowDirection.topToBottom
	spells.autoWidth = true
	spells.autoHeight = true
	spells.borderTop = 8
	createSpells(spells, cgBirthsign.spells, tes3.spellType.ability, "Abilities", true)
	createSpells(spells, cgBirthsign.spells, tes3.spellType.power, "Powers", true)
	createSpells(spells, cgBirthsign.spells, tes3.spellType.spell, "Spells", true)

	tab:updateLayout()
end

--- @param tab tes3uiElement
--- @param topBlock tes3uiElement
local function createBackgroundTab(tab, topBlock, scrollOverride)
	local old = topBlock:findChild("background_content")
	if old then old:destroy() end

	local content = tab:createBlock{ id = "background_content" }
	content.widthProportional = 1
	content.heightProportional = 1
	content.paddingAllSides = 8
	content.flowDirection = tes3.flowDirection.topToBottom

	local sub = content:createBlock()
	sub.widthProportional = 1
	sub.autoHeight = true

	local pane = sub:createVerticalScrollPane{ id = "background_scroll" }
	pane.widthProportional = -1
	pane.heightProportional = -1
	pane.width = 240
	pane.height = 256
	pane.paddingAllSides = 8
	local sortedList = table.values(backgroundsInterop.getAllBackgrounds(), function(a, b) return a.name:lower() < b.name:lower() end)
	for _, background in pairs(sortedList) do
		if cgBackground == nil then cgBackground = background end
		local button = pane:createTextSelect{ id = "background_button:" .. background.id }
		button:register(tes3.uiEvent.mouseClick, function()
			cgBackground = background
			createBackgroundTab(tab, topBlock, pane.widget.positionY)
			createReviewBlock(topBlock)
		end)
		button.text = background.name
		if background == cgBackground then
			button.widget.state = tes3.uiState.active
		end
	end
	pane:getTopLevelMenu():updateLayout()
	pane.widget.positionY = scrollOverride

	local subRight = sub:createBlock()
	subRight.widthProportional = 1
	subRight.autoHeight = true
	subRight.flowDirection = tes3.flowDirection.topToBottom
	subRight.borderLeft = 4

	local descText
	if type(cgBackground.description) == "function" then
		descText = cgBackground.description()
	else
		descText = cgBackground.description
	end
	local desc = subRight:createLabel{ id = "birth_desc", text = descText }
	desc.autoHeight = true
	desc.wrapText = true
	desc.borderLeft = 8

	tab:updateLayout()
end

function charGenerationMenu.createChargenMenu(menuButtons)
	tes3.fadeOut{ duration = 0.6 }
	menuButtons.visible = false

	if cgBirthsign == nil then
		cgBirthsign = tes3.dataHandler.nonDynamicData.birthsigns[1]
	end
	local player = tes3.getObject("player")
	player.name = "Player"

	local menu = tes3ui.createMenu{ id = "menu_chargen", fixedFrame = true, modal = true }
	menu.alpha = 1
	menu.minWidth = 1200
	menu.minHeight = 640
	menu:getContentElement().childAlignY = -1
	menu:getContentElement().paddingAllSides = 8

	local topBlock = menu:createBlock{ id = "main_container" }
	topBlock.widthProportional = 1
	topBlock.heightProportional = 1
	topBlock.flowDirection = tes3.flowDirection.leftToRight

	-- Tabs
	do
		local tabs = topBlock:createTabContainer{ id = "tabs" }
		tabs.heightProportional = 1
		tabs.widthProportional = 1.1
		tabs:register(tes3.uiEvent.valueChanged, function()
			tes3ui.acquireTextInput(nil)
		end)

		local tab = tabs.widget:addTab{ id = "name", name = "Name" }
		tab.paddingAllSides = 8

		local name = tab:createTextInput{ placeholderText = "Input your name...", autoFocus = true, createBorder = true }
		name:register(tes3.uiEvent.textUpdated, function(e)
			player.name = e.widget.text
			createReviewBlock(topBlock)
		end)

		tab:register(tes3.uiEvent.tabFocus, function()
			tes3ui.acquireTextInput(name)
			-- Doesn't work :( event is edited in to tabcontainer too, but can't get the text input to be focused.
			--name:triggerEvent(tes3.uiEvent.mouseClick)
		end)

		tab = tabs.widget:addTab{ id = "race", name = "Race" }
		createRaceTab(tab, topBlock, 0, 180, 45)
		tab = tabs.widget:addTab{ id = "class", name = "Class" }
		createClassTab(tab, topBlock, 0)
		tab = tabs.widget:addTab{ id = "birth", name = "Birthsign" }
		createBirthsignTab(tab, topBlock, 0)
		-- Should actually do interop here. But I'm stupid.
		--[[
		if backgroundsInterop then
			tab = tabs.widget:addTab{ id = "background", name = "Background" }
			createBackgroundTab(tab, topBlock, 0)
		end
		]]
	end

	-- Review block
	createReviewBlock(topBlock)

	-- Bottom bar
	do
		local block = menu:createBlock{ id = "bottomBar" }
		block.widthProportional = 1
		block.autoHeight = true
		block.childAlignX = -1

		local back = block:createButton{ text = "Back" }
		back:register(tes3.uiEvent.mouseClick, function()
			tes3.fadeIn{duration = 0.01}
			menu:destroy()
			menuButtons.visible = true
		end)

		local play = block:createButton{ text = "Play" }
		play:register(tes3.uiEvent.mouseClick, function()
			tes3.fadeIn{duration = 0.01}
			menu:destroy()
			charGenerationMenu.startGameCallback(cgBirthsign)
		end)
	end

	menu:updateLayout()
end

return charGenerationMenu