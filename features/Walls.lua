-- Default Spring Treedef

local wallDefs = {}

wallDefs["WallRedBricks"] = {
    description    = "WallRedBricks",
    object         = "Features/WallRedBricks.dae",
    blocking       = true,
    burnable       = false,
    reclaimable    = false,
    noSelect       = false,
    indestructible = false,
    energy          = 0,
    damage          = 1000,
    metal           = 0,
    mass            = 40,
    crushResistance = 14,
    footprintX  = 1,
    footprintZ  = 1,
    upright =  true,
    floating = false,
    collisionVolumeTest = 1,
    collisionVolumeType = "box",
    collisionVolumeScales = {4, 24, 36},
    collisionVolumeOffsets = {0, 12, 0},
    customParams = {
        mod = true,
    },
}

return lowerkeys( wallDefs )
