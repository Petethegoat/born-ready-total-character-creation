tes3.setGlobal("CharGenState", 10)

tes3.mobilePlayer.controlsDisabled = true
tes3.mobilePlayer.jumpingDisabled = true
tes3.mobilePlayer.viewSwitchDisabled = true
tes3.mobilePlayer.vanityDisabled = true
tes3.mobilePlayer.attackDisabled = true
tes3.mobilePlayer.magicDisabled = true

local seyda = tes3.getCell{x = -2, y = -9}
seyda.region:changeWeather(tes3.weather.cloudy)

local ship = tes3.getCell{id = "Imperial Prison Ship"}
tes3.positionCell{cell = ship, position = tes3vector3.new(61, -135, 24), orientation = tes3vector3.new(0,0, -0.349)}