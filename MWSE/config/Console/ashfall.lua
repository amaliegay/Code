tes3.addItem({ reference = tes3.player, item = "ashfall_firewood", count = 10 })
tes3.addItem({ reference = tes3.player, item = "ashfall_straw", count = 10 })
tes3.addItem({ reference = tes3.player, item = "ashfall_rope", count = 10 })
tes3.addItem({ reference = tes3.player, item = "ashfall_plant_fibre", count = 10 })

local skillModule = include("OtherSkills.skillModule")
if skillModule then
	local skill = skillModule.getSkill("Bushcrafting")
	if skill then for _ = 1, 10 do skill:progressSkill(100) end end
end
