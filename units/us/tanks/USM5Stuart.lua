local StuartBase = LightTank:New{
	acceleration		= 0.065,
	brakeRate			= 0.15,
	maxDamage			= 1520,
	maxReverseVelocity	= 2.15,
	maxVelocity			= 4.3,
	trackOffset			= 5,
	trackWidth			= 18,
	trackType			= "USStuart",
	turnRate			= 280, -- FIXME: worth it?
	
	customParams = {
		armor_front			= 43,
		armor_rear			= 28,
		armor_side			= 28,
		armor_top			= 13,
	},
}	

local USM5Stuart = StuartBase:New{
	name				= "M5A1 Stuart",
	buildCostMetal		= 1725,

	weapons = {
		[1] = {
			name				= "M637mmAP",
			mainDir				= [[0 16 1]],
			maxAngleDif			= 210,
		},
		[2] = {
			name				= "M637mmCanister",
			mainDir				= [[0 16 1]],
			maxAngleDif			= 210,
		},
		[3] = {
			name				= "M637mmHE",
			mainDir				= [[0 16 1]],
			maxAngleDif			= 210,
		},
		[4] = {
			name				= "M1919A4Browning",
		},
		[5] = {
			name				= "M2BrowningAA",
		},
		[6] = {
			name				= ".50calproof",
		},
	},
	customParams = {
		maxammo				= 27,
		weapontoggle		= false,
		weaponcost			= 8,
		weaponswithammo		= 3,
		
		cegpiece = {
			[3] = "flare",
			[4] = "coaxflare",
			[5] = "aaflare",
		},
	},
}

local USM8Scott = StuartBase:New(AssaultGun):New{
	name				= "M8 Scott GMC",
	buildCostMetal		= 2100,
	
	weapons = {
		[1] = {
			name				= "M875mmHE",
			mainDir				= [[0 16 1]],
			maxAngleDif			= 210,
		},
		[2] = {
			name				= "M2BrowningAA",
		},
		[3] = {
			name				= ".50calproof",
		},
	},
	customParams = {
		maxammo				= 9,
		weaponcost			= 12,
		weapontoggle		= false,
		weaponswithammo		= 1,
		cegpiece = {
			[2] = "aaflare",
		},
	},
}

return lowerkeys({
	["USM5Stuart"] = USM5Stuart,
	["USM8Scott"] = USM8Scott,
})
