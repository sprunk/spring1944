function widget:GetInfo ()
    return {
        name = "Wiki Generator",
        desc = "Create the wiki tree with the description of the factions and units",
        author = "Jose Luis Cercos-Pita",
        date = "02/11/2017",
        license = "GPL v3",
        layer = 1,
        enabled = false,
    }
end

-- UNITS_PICS_URL = "https://gitlab.com/Spring1944/spring1944/raw/master/unitpics/"
-- FACTIONS_PICS_URL = "https://gitlab.com/Spring1944/spring1944/raw/master/LuaUI/Widgets/faction_change/"
-- WIKI_WIDGET_PICS_EXT = "svg"
-- STRUCTURE = "hierarchical"  -- Pages are organized in folders
UNITS_PICS_URL = "https://raw.githubusercontent.com/spring1944/spring1944/master/unitpics/"
FACTIONS_PICS_URL = "https://raw.githubusercontent.com/spring1944/spring1944/master/LuaUI/Widgets/faction_change/"
WIKI_WIDGET_PICS_URL = "https://raw.githubusercontent.com/wiki/spring1944/spring1944/images/wiki_widget"
WIKI_WIDGET_PICS_EXT = "png"
WIKI_COMMENT_START = "<!--"
WIKI_COMMENT_END = "-->"
UNIT_THUMBNAIL_SIZE = "36px"
STRUCTURE = "plain"  -- All pages are in root folder, with dot based names

if STRUCTURE == "hierarchical" then
    SEPARATOR = "/"
else
    SEPARATOR = "."    
end

-- =============================================================================
-- STRING UTILITIES
-- =============================================================================

local function __to_string(data, indent)
    local str = ""

    if(indent == nil) then
        indent = 0
    end
    local indenter = "    "
    -- Check the type
    if(type(data) == "string") then
        str = str .. (indenter):rep(indent) .. data .. "\n"
    elseif(type(data) == "number") then
        str = str .. (indenter):rep(indent) .. data .. "\n"
    elseif(type(data) == "boolean") then
        if(data == true) then
            str = str .. "true"
        else
            str = str .. "false"
        end
    elseif(type(data) == "table") then
        local i, v
        for i, v in pairs(data) do
            -- Check for a table in a table
            if(type(v) == "table") then
                str = str .. (indenter):rep(indent) .. i .. ":\n"
                str = str .. __to_string(v, indent + 2)
            else
                str = str .. (indenter):rep(indent) .. i .. ": " .. __to_string(v, 0)
            end
        end
    elseif(type(data) == "function") then
        str = str .. (indenter):rep(indent) .. 'function' .. "\n"
    elseif(type(data) == "nil") then
        str = str .. "*nil"
    else
        print(1, "Error: unknown data type: %s", type(data))
    end

    return str
end

local function __split_str(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

-- =============================================================================
-- FACTIONS AUTO-DOCUMENTATION
-- =============================================================================

UNITS = {}         -- Global list of already parsed units (storing the human name)
UNITS_DEPTHS = {}  -- Depth of each unit, to find the critical line
CURRENT_DEPTH = 0  -- Current parsing depth
UNITS_LINKS = {}   -- Intra-page link to already parsed units
UNITS_LINKED = {}  -- Units with the link already prepared
morphDefs = include("LuaRules/Configs/morph_defs.lua")

function _is_morph_link(id)
    -- Analyze the unit name to determine whether it is a morphing link or not
    local name = id
    if type(name) == "number" then
        name = UnitDefs[id].name
    end

    fields = __split_str(name, "_")
    if #fields >= 4 and fields[2] == "morph" then
        return true
    end

    return false
end

function _is_deploy(orig, dest)
    if orig == nil or UnitDefNames[orig].speed == 0 or UnitDefNames[dest].speed > 0 then
        return false
    end
    return true
end

function _is_pack(orig, dest)
    if orig == nil or UnitDefNames[orig].speed > 0 or UnitDefNames[dest].speed == 0 then
        return false
    end
    return true
end

local invalid_chars = {"/", ":", ",", ";", "'", '"', "#", "\\", "%.",
                       "%(", "%)", "%[", "%]", "%%", "%?", "%+", "%*", "%$",
                       "%^"}
local function _wikilist_header_to_link(str)
    str = string.gsub(string.lower(str), " ", "-")
    for _,c in ipairs(invalid_chars) do
        str = string.gsub(str, c, "")
    end
    return str
end

local function _wikilist_unit_str(str, name, build_chain_prefix, url_base, name_prefix)
    name_prefix = name_prefix or ""

    str = str .. "#### "

    if build_chain_prefix ~= "" then
        str = str .. build_chain_prefix .. " - "
    end
    -- Image/Logo
    local buildPic = string.lower(UnitDefNames[name].buildpicname)
    str = str .. "![](" .. UNITS_PICS_URL .. buildPic .. ") "
    -- Eventual link to the first instance
    local link = ""
    if build_chain_prefix == "" then
        link = "#--"
    else
        link = "#-----"
    end
    if name_prefix ~= "" then
        link = link .. _wikilist_header_to_link(name_prefix) .. "-"
    end
    link = link .. _wikilist_header_to_link(UNITS[name])
    if UNITS_LINKS[name] == nil and UNITS_DEPTHS[name] == CURRENT_DEPTH then
        UNITS_LINKS[name] = link
        UNITS_LINKED[name] = true
    elseif UNITS_LINKS[name] ~= nil then
        if UNITS_DEPTHS[name] == CURRENT_DEPTH and not UNITS_LINKED[name] then
            -- First occurrence, it does not need the link to the critical line
            UNITS_LINKED[name] = true
        else
            str = str .. "[&#8627;](" .. UNITS_LINKS[name] .. ") "
        end
    end
    -- Unit name
    str = str .. name_prefix .. " "
    str = str .. "[" .. UNITS[name] .. "]"
    str = str .. "(" .. url_base .. name .. ")\n\n"

    return str
end

local function _to_wikilist(data, url_base, prefix)
    -- THIS METHOD SHOUDL BE CALLED TWICE. In the first call the links to the
    -- critical lines will be collected, while in the second one they are
    -- conveniently applied. Otherwise, the links to critical lines will work
    -- only in upwards direction
    if(prefix == nil) then
        prefix = ""
    end

    if CURRENT_DEPTH == 0 then
        UNITS_LINKED = {}
    end
    CURRENT_DEPTH = CURRENT_DEPTH + 1

    local str = ""
    for _, v in ipairs(data.children) do
        local name_prefix = ""
        if v.ismorph then
            if _is_deploy(data.name, v.name) then
                name_prefix = "Deploy as:"
            elseif _is_pack(data.name, v.name) then
                name_prefix = "Pack as:"
            else
                name_prefix = "Transform into:"
            end
        end
        str = _wikilist_unit_str(str, v.name, prefix, url_base, name_prefix)

        local buildPic = string.lower(UnitDefNames[v.name].buildpicname)
        local prefix_to_add = '<img src="' .. UNITS_PICS_URL .. buildPic .. '" width="' .. UNIT_THUMBNAIL_SIZE .. '">'
        str = str .. _to_wikilist(v, url_base, prefix .. prefix_to_add)
    end

    CURRENT_DEPTH = CURRENT_DEPTH - 1

    return str
end

function _unit_name(id, side)
    -- Get an unitDefID, and return its name. This function is also resolving
    -- morphing links.
    -- id can be directly the name of the unit in case just the morphing
    -- link resolution should be carried out
    local name = id
    if type(name) == "number" then
        name = UnitDefs[id].name
    end

    -- Morphing link resolution
    fields = __split_str(name, "_")
    if #fields >= 4 and fields[1] == side and fields[2] == "morph" then
        -- It is a morphing unit, see BuildMorphDef function in
        -- LuaRules/Gadgets/unit_morph. We are interested in the morphed
        -- unit instead of the morphing one
        name = fields[4]
        for i = 5,#fields do
            -- Some swe nightmare names has underscores...
            name = name .. "_" .. fields[i]
        end
    end

    return name
end

local function __is_unit_in_chain(name)
    for _, v in ipairs(UNITS_CHAIN) do
        if name == v then
            return true
        end
    end
    return false
end

function _units_tree(startUnit, side)
    -- Departs from the starting unit, and traverse all the tech tree derived
    -- from him, simply following the building capabilities of each unit.
    -- THIS METHOD SHOUDL BE CALLED TWICE. In the first call some units subtrees
    -- can be documented also in suboptimal building chains, while in the second
    -- call trees are arising just from critical lines
    local name = startUnit

    local unitDef = UnitDefNames[name]
    local tree = {
        name = startUnit,
        ismorph = false,
        children = {}
    }

    CURRENT_DEPTH = CURRENT_DEPTH + 1

    if UNITS_DEPTHS[name] ~= nil and UNITS_DEPTHS[name] < CURRENT_DEPTH then
        -- The unit has a more critical line, so we are not interested into
        -- parsing it yet
        CURRENT_DEPTH = CURRENT_DEPTH - 1
        return tree
    end
    UNITS_DEPTHS[name] = CURRENT_DEPTH
    UNITS[name] = unitDef.humanName

    -- Add its children to the tree
    local children = unitDef.buildOptions
    local documented_children = {}  -- Morphs can be repeated
    for _, c in ipairs(children) do
        name = _unit_name(c, side)
        tree.children[#tree.children + 1] = _units_tree(name, side)
        tree.children[#tree.children].ismorph = _is_morph_link(c)
        documented_children[name] = true
    end
    -- Add also the morphs
    children = {}
    if morphDefs[startUnit] ~= nil then
        if morphDefs[startUnit].into ~= nil then
            -- Conveniently transform it in a single element table
            morphDefs[startUnit] = {morphDefs[startUnit]}
        end
        for _, morphDef in pairs(morphDefs[startUnit]) do
            children[#children + 1] =  UnitDefNames[morphDef.into].name
        end
    end
    for _, c in ipairs(children) do
        name = _unit_name(c, side)
        if not documented_children[name] then
            tree.children[#tree.children + 1] = _units_tree(name, side)
            tree.children[#tree.children].ismorph = true
        end
    end

    CURRENT_DEPTH = CURRENT_DEPTH - 1

    return tree
end

function _gen_faction(folder, faction)
    local side = faction.sideName
    local handle
    if STRUCTURE == "hierarchical" then
        local faction_folder = folder .. "/factions/" .. side
        if Spring.CreateDir(faction_folder) == false then
            Spring.Log("cmd_generatewiki.lua", "error",
                "Failure creating the folder '" .. faction_folder .. "'")
        end
        handle = io.open(faction_folder .. "/main.md", "w")
    else
        handle = io.open(folder .. "/factions." .. side ..".md", "w")
    end

    -- Create the wiki page
    handle.write(handle, "# ![side-logo]")
    handle.write(handle, "(" .. FACTIONS_PICS_URL .. side .. ".png) ")
    handle.write(handle, faction.title .. "\n\n")
    handle.write(handle, faction.wiki .. "\n\n")

    -- Faction units tree
    _units_tree(faction.startUnit, side)  -- Fake call to store the critical lines
    local tree = {name = nil, ismorph = false, children={
        _units_tree(faction.startUnit, side)
    }}
    handle.write(handle, "## Units tree\n\n")
    _to_wikilist(tree, "units" .. SEPARATOR)  -- Fake call to collect links to critical lines
    handle.write(handle, _to_wikilist(tree, "units" .. SEPARATOR))
    handle.write(handle, "\n")    

    handle.close(handle)
end

-- =============================================================================
-- UNITS AUTO-DOCUMENTATION
-- =============================================================================

squadDefs = include("LuaRules/Configs/squad_defs.lua")
sortieDefs = include("LuaRules/Configs/sortie_defs.lua")

function _parse_squad(unitDef)
    if squadDefs[unitDef.name] == nil and sortieDefs[unitDef.name] == nil then
        -- Not a squad, just don't write nothing
        return ""
    end
    local squad = squadDefs[unitDef.name] or sortieDefs[unitDef.name]
    if squad.members == nil then
        -- It is actually happening, see ger_all squad, which is afterwards
        -- filled by spammer AI
        return ""
    end
    local t = "![Cost][1] Cost: " .. tostring(squad.buildCostMetal) .. "\n\n"
    t = t .. "This is a team composed by the following members:\n\n"
    local members = {}
    local member, n
    for _, member in pairs(squad.members) do
        if members[member] == nil then
            members[member] = 1
        else
            members[member] = members[member] + 1
        end
    end
    for member, n in pairs(members) do
        local memberDef = UnitDefNames[member]
        t = t .. "* " .. tostring(n) .. " x "
        t = t .. "[" .. memberDef.humanName .. "]"
        t = t .. "(units" .. SEPARATOR .. memberDef.name .. ")\n"
    end

    t = t .. "\n[1]: " .. WIKI_WIDGET_PICS_URL .. "/hammer_icon." .. WIKI_WIDGET_PICS_EXT .. "\n\n"

    return t
end

TEMPLATES_FOLDER = "LuaUI/Widgets/generatewiki/templates/"

function _parse_yard(unitDef)
    local t = VFS.LoadFile(TEMPLATES_FOLDER .. "yard.md")
    t = string.gsub(t,
                    "{iconsUrl}",
                    WIKI_WIDGET_PICS_URL)
    t = string.gsub(t,
                    "{iconExt}",
                    WIKI_WIDGET_PICS_EXT)
    t = string.gsub(t,
                    "{subclass_comments}",
                    unitDef.customParams.wiki_subclass_comments)
    t = string.gsub(t,
                    "{comments}",
                    unitDef.customParams.wiki_comments)
    t = string.gsub(t,
                    "{buildCost}",
                    tostring(unitDef.metalCost))
    t = string.gsub(t,
                    "{buildTime}",
                    tostring(unitDef.buildTime / unitDef.buildSpeed))
    t = string.gsub(t,
                    "{maxDamage}",
                    tostring(unitDef.health))
    t = string.gsub(t,
                    "{supplyRange}",
                    tostring(unitDef.customParams.supplyrange))
    local categories = ""
    for name, value in pairs(unitDef.modCategories) do
        if value then
            categories = categories .. name .. ", "
        end
    end
    t = string.gsub(t,
                    "{categories}",
                    categories)
    t = string.gsub(t,
                    "{armorType}",
                    Game.armorTypes[unitDef.armorType])
    return t
end

function _parse_storage(unitDef)
    local t = VFS.LoadFile(TEMPLATES_FOLDER .. "storage.md")
    t = string.gsub(t,
                    "{iconsUrl}",
                    WIKI_WIDGET_PICS_URL)
    t = string.gsub(t,
                    "{iconExt}",
                    WIKI_WIDGET_PICS_EXT)
    t = string.gsub(t,
                    "{comments}",
                    unitDef.customParams.wiki_comments)
    t = string.gsub(t,
                    "{buildCost}",
                    tostring(unitDef.metalCost))
    local buildSpeed = unitDef.buildSpeed
    if buildSpeed == nil or buildSpeed == 0 then
        buildSpeed = 1
    end
    t = string.gsub(t,
                    "{buildTime}",
                    tostring(unitDef.buildTime / buildSpeed))
    t = string.gsub(t,
                    "{maxDamage}",
                    tostring(unitDef.health))
    t = string.gsub(t,
                    "{energyStorage}",
                    tostring(unitDef.energyStorage))
    local categories = ""
    for name, value in pairs(unitDef.modCategories) do
        if value then
            categories = categories .. name .. ", "
        end
    end
    t = string.gsub(t,
                    "{categories}",
                    categories)
    t = string.gsub(t,
                    "{armorType}",
                    Game.armorTypes[unitDef.armorType])
    return t
end

function _parse_supplies(unitDef)
    local t = VFS.LoadFile(TEMPLATES_FOLDER .. "supplies.md")
    t = string.gsub(t,
                    "{iconsUrl}",
                    WIKI_WIDGET_PICS_URL)
    t = string.gsub(t,
                    "{iconExt}",
                    WIKI_WIDGET_PICS_EXT)
    t = string.gsub(t,
                    "{comments}",
                    unitDef.customParams.wiki_comments)
    t = string.gsub(t,
                    "{buildCost}",
                    tostring(unitDef.metalCost))
    local buildSpeed = unitDef.buildSpeed
    if buildSpeed == nil or buildSpeed == 0 then
        buildSpeed = 1
    end
    t = string.gsub(t,
                    "{buildTime}",
                    tostring(unitDef.buildTime / buildSpeed))
    t = string.gsub(t,
                    "{maxDamage}",
                    tostring(unitDef.health))
    t = string.gsub(t,
                    "{supplyRange}",
                    tostring(unitDef.customParams.supplyrange))
    local categories = ""
    for name, value in pairs(unitDef.modCategories) do
        if value then
            categories = categories .. name .. ", "
        end
    end
    t = string.gsub(t,
                    "{categories}",
                    categories)
    t = string.gsub(t,
                    "{armorType}",
                    Game.armorTypes[unitDef.armorType])
    return t
end

function _parse_infantry(unitDef)
    local t = VFS.LoadFile(TEMPLATES_FOLDER .. "infantry.md")
    t = string.gsub(t,
                    "{iconsUrl}",
                    WIKI_WIDGET_PICS_URL)
    t = string.gsub(t,
                    "{iconExt}",
                    WIKI_WIDGET_PICS_EXT)
    t = string.gsub(t,
                    "{subclass_comments}",
                    unitDef.customParams.wiki_subclass_comments)
    t = string.gsub(t,
                    "{comments}",
                    unitDef.customParams.wiki_comments)
    -- Structural details
    t = string.gsub(t,
                    "{buildCost}",
                    tostring(unitDef.metalCost))
    t = string.gsub(t,
                    "{maxDamage}",
                    tostring(unitDef.health))
    t = string.gsub(t,
                    "{flagCap}",
                    tostring(unitDef.customParams.flagcaprate or 0))
    local categories = ""
    for name, value in pairs(unitDef.modCategories) do
        if value then
            categories = categories .. name .. ", "
        end
    end
    t = string.gsub(t,
                    "{categories}",
                    categories)
    t = string.gsub(t,
                    "{armorType}",
                    Game.armorTypes[unitDef.armorType])
    local maxammo = ""
    if unitDef.customParams.maxammo ~= nil then
        maxammo = "![Ammo][11] Max ammo: " .. unitDef.customParams.maxammo
    end
    t = string.gsub(t,
                    "{maxammo}",
                    maxammo)    
    -- Line of Shight
    t = string.gsub(t,
                    "{sight}",
                    tostring(unitDef.losRadius))
    t = string.gsub(t,
                    "{airLOS}",
                    tostring(unitDef.airLosRadius))
    t = string.gsub(t,
                    "{noiseLOS}",
                    tostring(unitDef.seismicRadius))
    -- Motion
    t = string.gsub(t,
                    "{maxspeed}",
                    tostring(unitDef.speed / 8.0 * 3.6))
    t = string.gsub(t,
                    "{turn}",
                    tostring(unitDef.turnRate * 0.16))
    t = string.gsub(t,
                    "{slope}",
                    tostring(unitDef.moveDef.maxSlope))
    t = string.gsub(t,
                    "{maxdepth}",
                    tostring((unitDef.moveDef.depth or 0) / 8.0))
    return t
end

function _parse_vehicle(unitDef)
    local t = VFS.LoadFile(TEMPLATES_FOLDER .. "vehicles.md")
    t = string.gsub(t,
                    "{iconsUrl}",
                    WIKI_WIDGET_PICS_URL)
    t = string.gsub(t,
                    "{iconExt}",
                    WIKI_WIDGET_PICS_EXT)
    t = string.gsub(t,
                    "{subclass_comments}",
                    unitDef.customParams.wiki_subclass_comments)
    t = string.gsub(t,
                    "{comments}",
                    unitDef.customParams.wiki_comments)
    -- Structural details
    t = string.gsub(t,
                    "{buildCost}",
                    tostring(unitDef.metalCost))
    t = string.gsub(t,
                    "{maxDamage}",
                    tostring(unitDef.health))

    local categories = ""
    for name, value in pairs(unitDef.modCategories) do
        if value then
            categories = categories .. name .. ", "
        end
    end
    t = string.gsub(t,
                    "{categories}",
                    categories)
    t = string.gsub(t,
                    "{armorType}",
                    Game.armorTypes[unitDef.armorType])
    local maxammo = ""
    if unitDef.customParams.maxammo ~= nil then
        maxammo = "![Ammo][11] Max ammo: " .. unitDef.customParams.maxammo
    end
    t = string.gsub(t,
                    "{maxammo}",
                    maxammo)    

    if unitDef.customParams.armour == nil then
        t = string.gsub(t,
                        "{comment_base_section}",
                        WIKI_COMMENT_START)
        t = string.gsub(t,
                        "{end_comment_base_section}",
                        WIKI_COMMENT_END)
        t = string.gsub(t,
                        "{comment_turret_section}",
                        WIKI_COMMENT_START)
        t = string.gsub(t,
                        "{end_comment_turret_section}",
                        WIKI_COMMENT_END)
    else
        local armour = table.unserialize(unitDef.customParams.armour)
        if armour["base"] == nil then
            t = string.gsub(t,
                            "{comment_base_section}",
                            WIKI_COMMENT_START)
            t = string.gsub(t,
                            "{end_comment_base_section}",
                            WIKI_COMMENT_END)
        else
            t = string.gsub(t,
                            "{comment_base_section}",
                            "")
            t = string.gsub(t,
                            "{end_comment_base_section}",
                            "")
            t = string.gsub(t,
                            "{frontArmour}",
                            tostring(armour["base"].front.thickness or 0))
            t = string.gsub(t,
                            "{rearArmour}",
                            tostring(armour["base"].rear.thickness or 0))
            t = string.gsub(t,
                            "{sideArmour}",
                            tostring(armour["base"].side.thickness or 0))
            t = string.gsub(t,
                            "{topArmour}",
                            tostring(armour["base"].top.thickness or 0))
            t = string.gsub(t,
                            "{frontArmourSlope}",
                            tostring(armour["base"].front.slope or 0))
            t = string.gsub(t,
                            "{rearArmourSlope}",
                            tostring(armour["base"].rear.slope or 0))
            t = string.gsub(t,
                            "{sideArmourSlope}",
                            tostring(armour["base"].side.slope or 0))
            t = string.gsub(t,
                            "{topArmourSlope}",
                            tostring(armour["base"].top.slope or 0))
        end
        if armour["turret"] == nil then
            t = string.gsub(t,
                            "{comment_turret_section}",
                            WIKI_COMMENT_START)
            t = string.gsub(t,
                            "{end_comment_turret_section}",
                            WIKI_COMMENT_END)
        else
            t = string.gsub(t,
                            "{comment_turret_section}",
                            "")
            t = string.gsub(t,
                            "{end_comment_turret_section}",
                            "")
            t = string.gsub(t,
                            "{frontTurretArmour}",
                            tostring(armour["turret"].front.thickness or 0))
            t = string.gsub(t,
                            "{rearTurretArmour}",
                            tostring(armour["turret"].rear.thickness or 0))
            t = string.gsub(t,
                            "{sideTurretArmour}",
                            tostring(armour["turret"].side.thickness or 0))
            t = string.gsub(t,
                            "{topTurretArmour}",
                            tostring(armour["turret"].top.thickness or 0))
            t = string.gsub(t,
                            "{frontTurretArmourSlope}",
                            tostring(armour["turret"].front.slope or 0))
            t = string.gsub(t,
                            "{rearTurretArmourSlope}",
                            tostring(armour["turret"].rear.slope or 0))
            t = string.gsub(t,
                            "{sideTurretArmourSlope}",
                            tostring(armour["turret"].side.slope or 0))
            t = string.gsub(t,
                            "{topTurretArmourSlope}",
                            tostring(armour["turret"].top.slope or 0))
        end
    end
    -- Line of Shight
    t = string.gsub(t,
                    "{sight}",
                    tostring(unitDef.losRadius))
    t = string.gsub(t,
                    "{airLOS}",
                    tostring(unitDef.airLosRadius))
    t = string.gsub(t,
                    "{noiseLOS}",
                    tostring(unitDef.seismicRadius))
    -- Motion
    t = string.gsub(t,
                    "{maxspeed}",
                    tostring(unitDef.speed / 8.0 * 3.6))
    t = string.gsub(t,
                    "{turn}",
                    tostring(unitDef.turnRate * 0.16))
    t = string.gsub(t,
                    "{slope}",
                    tostring(unitDef.moveDef.maxSlope))
    t = string.gsub(t,
                    "{maxdepth}",
                    tostring((unitDef.moveDef.depth or 0) / 8.0))
    return t
end

function _parse_aircraft(unitDef)
    local t = VFS.LoadFile(TEMPLATES_FOLDER .. "aircrafts.md")
    t = string.gsub(t,
                    "{iconsUrl}",
                    WIKI_WIDGET_PICS_URL)
    t = string.gsub(t,
                    "{iconExt}",
                    WIKI_WIDGET_PICS_EXT)
    t = string.gsub(t,
                    "{subclass_comments}",
                    unitDef.customParams.wiki_subclass_comments)
    t = string.gsub(t,
                    "{comments}",
                    unitDef.customParams.wiki_comments)
    -- Structural details
    t = string.gsub(t,
                    "{buildCost}",
                    tostring(unitDef.metalCost))
    t = string.gsub(t,
                    "{maxDamage}",
                    tostring(unitDef.health))
    local categories = ""
    for name, value in pairs(unitDef.modCategories) do
        if value then
            categories = categories .. name .. ", "
        end
    end
    t = string.gsub(t,
                    "{categories}",
                    categories)
    t = string.gsub(t,
                    "{armorType}",
                    Game.armorTypes[unitDef.armorType])
    local maxammo = ""
    if unitDef.customParams.maxammo ~= nil then
        maxammo = "![Ammo][11] Max ammo: " .. unitDef.customParams.maxammo
    end
    t = string.gsub(t,
                    "{maxammo}",
                    maxammo)    
    -- Line of Shight
    t = string.gsub(t,
                    "{sight}",
                    tostring(unitDef.losRadius))
    t = string.gsub(t,
                    "{airLOS}",
                    tostring(unitDef.airLosRadius))
    t = string.gsub(t,
                    "{noiseLOS}",
                    tostring(unitDef.seismicRadius))
    -- Motion
    t = string.gsub(t,
                    "{maxspeed}",
                    tostring(unitDef.speed / 8.0 * 3.6))
    t = string.gsub(t,
                    "{turn}",
                    tostring(unitDef.turnRate * 0.16))
    t = string.gsub(t,
                    "{fuel}",
                    tostring(unitDef.customParams.maxfuel))
    return t
end

function _parse_boat(unitDef)
    local t = VFS.LoadFile(TEMPLATES_FOLDER .. "boats.md")
    t = string.gsub(t,
                    "{iconsUrl}",
                    WIKI_WIDGET_PICS_URL)
    t = string.gsub(t,
                    "{iconExt}",
                    WIKI_WIDGET_PICS_EXT)
    t = string.gsub(t,
                    "{subclass_comments}",
                    unitDef.customParams.wiki_subclass_comments)
    t = string.gsub(t,
                    "{comments}",
                    unitDef.customParams.wiki_comments)
    -- Structural details
    t = string.gsub(t,
                    "{buildCost}",
                    tostring(unitDef.metalCost))
    t = string.gsub(t,
                    "{maxDamage}",
                    tostring(unitDef.health))
    t = string.gsub(t,
                    "{frontArmour}",
                    tostring(unitDef.customParams.armor_front or 0))
    t = string.gsub(t,
                    "{rearArmour}",
                    tostring(unitDef.customParams.armor_rear or 0))
    t = string.gsub(t,
                    "{sideArmour}",
                    tostring(unitDef.customParams.armor_side or 0))
    t = string.gsub(t,
                    "{topArmour}",
                    tostring(unitDef.customParams.armor_top or 0))
    local categories = ""
    for name, value in pairs(unitDef.modCategories) do
        if value then
            categories = categories .. name .. ", "
        end
    end
    t = string.gsub(t,
                    "{categories}",
                    categories)
    t = string.gsub(t,
                    "{armorType}",
                    Game.armorTypes[unitDef.armorType])
    local maxammo = ""
    if unitDef.customParams.maxammo ~= nil then
        maxammo = "![Ammo][11] Max ammo: " .. unitDef.customParams.maxammo
    end
    t = string.gsub(t,
                    "{maxammo}",
                    maxammo)    
    -- Line of Shight
    t = string.gsub(t,
                    "{sight}",
                    tostring(unitDef.losRadius))
    t = string.gsub(t,
                    "{airLOS}",
                    tostring(unitDef.airLosRadius))
    t = string.gsub(t,
                    "{noiseLOS}",
                    tostring(unitDef.seismicRadius))
    -- Motion
    t = string.gsub(t,
                    "{maxspeed}",
                    tostring(unitDef.speed / 8.0 * 3.6))
    t = string.gsub(t,
                    "{turn}",
                    tostring(unitDef.turnRate * 0.16))
    t = string.gsub(t,
                    "{mindepth}",
                    tostring(unitDef.moveDef.depth))
    -- Turrets
    if unitDef.customParams.mother and unitDef.customParams.children then
        t = t .. "## Turrets\n\n"
        local children = loadstring("return " .. unitDef.customParams.children)()
        local turret
        for _, turret in pairs(children) do
            local turretDef = UnitDefNames[string.lower(turret)]
            local turretName = turretDef.humanName
            local turretRef = "units" .. SEPARATOR .. string.lower(turret)
            t = t .. "[" .. turretName .. "](" .. turretRef .. ")\n\n"
        end

    end
    return t
end

function _parse_turret(unitDef)
    local t = VFS.LoadFile(TEMPLATES_FOLDER .. "turrets.md")
    t = string.gsub(t,
                    "{iconsUrl}",
                    WIKI_WIDGET_PICS_URL)
    t = string.gsub(t,
                    "{iconExt}",
                    WIKI_WIDGET_PICS_EXT)
    t = string.gsub(t,
                    "{subclass_comments}",
                    unitDef.customParams.wiki_subclass_comments)
    t = string.gsub(t,
                    "{comments}",
                    unitDef.customParams.wiki_comments)
    -- Structural details
    t = string.gsub(t,
                    "{buildCost}",
                    tostring(unitDef.metalCost))
    t = string.gsub(t,
                    "{maxDamage}",
                    tostring(unitDef.health))
    t = string.gsub(t,
                    "{frontArmour}",
                    tostring(unitDef.customParams.armor_front or 0))
    t = string.gsub(t,
                    "{rearArmour}",
                    tostring(unitDef.customParams.armor_rear or 0))
    t = string.gsub(t,
                    "{sideArmour}",
                    tostring(unitDef.customParams.armor_side or 0))
    t = string.gsub(t,
                    "{topArmour}",
                    tostring(unitDef.customParams.armor_top or 0))
    local categories = ""
    for name, value in pairs(unitDef.modCategories) do
        if value then
            categories = categories .. name .. ", "
        end
    end
    t = string.gsub(t,
                    "{categories}",
                    categories)
    t = string.gsub(t,
                    "{armorType}",
                    Game.armorTypes[unitDef.armorType])
    local maxammo = ""
    if unitDef.customParams.maxammo ~= nil then
        maxammo = "![Ammo][11] Max ammo: " .. unitDef.customParams.maxammo
    end
    t = string.gsub(t,
                    "{maxammo}",
                    maxammo)    
    -- Line of Shight
    t = string.gsub(t,
                    "{sight}",
                    tostring(unitDef.losRadius))
    t = string.gsub(t,
                    "{airLOS}",
                    tostring(unitDef.airLosRadius))
    t = string.gsub(t,
                    "{noiseLOS}",
                    tostring(unitDef.seismicRadius))
    return t
end

function _parse_weapon(unitDef, weapon)
    -- The parameter weapon is not a weapon def, but an unitDef weapon table
    weaponDef = WeaponDefs[weapon.weaponDef]
    local t = VFS.LoadFile(TEMPLATES_FOLDER .. "weapon.md")
    t = string.gsub(t,
                    "{iconsUrl}",
                    WIKI_WIDGET_PICS_URL)
    t = string.gsub(t,
                    "{iconExt}",
                    WIKI_WIDGET_PICS_EXT)
    -- Weapon name and comments
    -- ========================
    local comments = weaponDef.customParams.wiki_comments or ""
    t = string.gsub(t,
                    "{name}",
                    weaponDef.name)
    t = string.gsub(t,
                    "{comments}",
                    comments)
    -- Heading and Pitch data
    -- ======================
    local dir = weapon.mainDir or {weapon.mainDirX, weapon.mainDirY, weapon.mainDirZ}
    local angle = math.deg(math.acos(weapon.maxAngleDif))
    local minHeading, maxHeading, minPitch, maxPitch
    local pitchBase = math.deg(math.atan2(
        dir[2], math.sqrt(dir[1] * dir[1] + dir[3] * dir[3])))
    if pitchBase + angle > 90 then
        -- The barrel can be heading everywhere
        minHeading = -360
        maxHeading = 360
        minPitch = math.max(-90, pitchBase - angle)
        maxPitch = 90
    else
        local headingBase = math.deg(math.atan2(-dir[1], dir[3]))
        minHeading = headingBase - angle
        maxHeading = headingBase + angle
        minPitch = math.max(-90, pitchBase - angle)
        maxPitch = math.min(90, pitchBase + angle)
    end
    local speedHeading = unitDef.customParams.turretturnspeed or unitDef.turnRate * 0.16
    local speedPitch = unitDef.customParams.elevationspeed or speedHeading
    t = string.gsub(t,
                    "{minHeading}",
                    tostring(minHeading))
    t = string.gsub(t,
                    "{maxHeading}",
                    tostring(maxHeading))
    t = string.gsub(t,
                    "{speedHeading}",
                    tostring(speedHeading))
    t = string.gsub(t,
                    "{minPitch}",
                    tostring(minPitch))
    t = string.gsub(t,
                    "{maxPitch}",
                    tostring(maxPitch))
    t = string.gsub(t,
                    "{speedPitch}",
                    tostring(speedPitch))
    -- Shot statistics
    -- ===============
    t = string.gsub(t,
                    "{range}",
                    tostring(weaponDef.range))
    t = string.gsub(t,
                    "{damageArea}",
                    tostring(weaponDef.damageAreaOfEffect or 0))
    t = string.gsub(t,
                    "{accuracy}",
                    tostring(weaponDef.accuracy))
    t = string.gsub(t,
                    "{movingAccuracy}",
                    tostring(weaponDef.movingAccuracy))
    local pen100 = weaponDef.customParams.armor_penetration or 0
    local pen1000 = pen100
    if weaponDef.customParams.armor_penetration_100m then
        pen100 = weaponDef.customParams.armor_penetration_100m
    end
    if weaponDef.customParams.armor_penetration_1000m then
        pen1000 = weaponDef.customParams.armor_penetration_1000m
    end
    t = string.gsub(t,
                    "{pen100}",
                    tostring(pen100))
    t = string.gsub(t,
                    "{pen1000}",
                    tostring(pen1000))
    -- Special case of burst/shotgun mode
    local salvoSize = weaponDef.salvoSize * weaponDef.projectiles
    local salvoTime = math.max(weaponDef.reload,
                               weaponDef.salvoSize * weaponDef.salvoDelay)
    t = string.gsub(t,
                    "{fireRate}",
                    tostring(salvoSize / salvoTime))
    t = string.gsub(t,
                    "{ammoCost}",
                    tostring(weaponDef.customParams.weaponcost or 0))
    -- Targets and damage inflicted
    -- ============================
    local targets = ""
    local name, value
    for name, value in pairs(weapon.onlyTargets) do
        if value then
            targets = targets .. name .. ", "
        end
    end
    if targets == "none, " then
        -- This weapon is not actually used, so drop it from the wiki
        return ""
    end
    local damages = ""
    local name, damage
    for id, damage in pairs(weaponDef.damages) do
        if Game.armorTypes[id] ~= nil then
            local name = Game.armorTypes[id]
            damages = damages .. name .. " = " .. tostring(damage) .. ", "
        end
    end
    t = string.gsub(t,
                    "{targets}",
                    targets)
    t = string.gsub(t,
                    "{damages}",
                    tostring(damages))
    return t
end

function _gen_unit(name, folder)
    local unitDef = UnitDefNames[name]
    local handle
    if STRUCTURE == "hierarchical" then
        local unit_folder = folder .. "/units/"
        handle = io.open(unit_folder .. name .. ".md", "w")
    else
        handle = io.open(folder .. "/units." .. name .. ".md", "w")
    end

    -- Title line
    -- ==========

    handle.write(handle, "# ![" .. name .. "-buildpic]")
    handle.write(handle, "(" .. UNITS_PICS_URL .. string.lower(unitDef.buildpicname) .. ") ")
    handle.write(handle, unitDef.humanName .. "\n\n")
    -- Parse the unit by its class
    -- ===========================
    handle.write(handle, _parse_squad(unitDef))
    local customParams = unitDef.customParams
    if customParams then
        local parser = customParams.wiki_parser
        if parser == "yard" then
            handle.write(handle, _parse_yard(unitDef))
        elseif parser == "storage" then
            handle.write(handle, _parse_storage(unitDef))
        elseif parser == "supplies" then
            handle.write(handle, _parse_supplies(unitDef))
        elseif parser == "infantry" then
            handle.write(handle, _parse_infantry(unitDef))
        elseif parser == "vehicle" then
            handle.write(handle, _parse_vehicle(unitDef))
        elseif parser == "aircraft" then
            handle.write(handle, _parse_aircraft(unitDef))
        elseif parser == "boat" then
            if customParams.child then
                handle.write(handle, _parse_turret(unitDef))
            else
                handle.write(handle, _parse_boat(unitDef))
            end
        else
            Spring.Echo("No customParams.wiki_parser : ", unitDef.name)
        end
    end
    -- Parse the weapons
    -- ===========================
    if not ((customParams.wiki_parser == "boat") and customParams.mother) then
        local weapons = unitDef.weapons
        if weapons ~= nil and #weapons > 0 then
            handle.write(handle, "## Weapons\n\n")
            local weapon
            for _, weapon in pairs(weapons) do
                    handle.write(handle, _parse_weapon(unitDef, weapon))
            end
        end
    end
    -- Get the morphing alternatives
    -- =============================
    local nMorphs = 0
    if morphDefs[name] ~= nil then
        handle.write(handle, "## Transformations\n\n")
        handle.write(handle, "This unit can be converted in the following ones:\n\n")
        local morphDef
        if morphDefs[name].into ~= nil then
            -- Conveniently transform it in a single element table
            morphDefs[name] = {morphDefs[name]}
        end
        for _, morphDef in pairs(morphDefs[name]) do
            local childName = UnitDefNames[morphDef.into].name
            local childHumanName = UnitDefNames[morphDef.into].humanName
            local childBuildPic = string.lower(UnitDefNames[morphDef.into].buildpicname)
            -- Image/Logo
            handle.write(handle, "![" .. childName .. "-logo]")
            handle.write(handle, "(" .. UNITS_PICS_URL .. childBuildPic .. ") ")
            -- Name
            handle.write(handle, "[" .. childHumanName .. "]")
            handle.write(handle, "(units" .. SEPARATOR .. childName .. ")\n\n")

            nMorphs = nMorphs + 1
        end
    end
    -- Document the build options
    -- ==========================
    local children = unitDef.buildOptions
    if #children - nMorphs > 0 then
        handle.write(handle, "## Build options\n\n")
        handle.write(handle, "This unit can build the following items:\n\n")
        local child
        for _, child in pairs(children) do
            if not _is_morph_link(child) then
                local childName = UnitDefs[child].name
                local childHumanName = UnitDefs[child].humanName
                local childBuildPic = string.lower(UnitDefs[child].buildpicname)
                -- Image/Logo
                handle.write(handle, "![" .. childName .. "-logo]")
                handle.write(handle, "(" .. UNITS_PICS_URL .. childBuildPic .. ") ")
                -- Name
                handle.write(handle, "[" .. childHumanName .. "]")
                handle.write(handle, "(units" .. SEPARATOR .. childName .. ")\n\n")
            end
        end
    end

    handle.close(handle)
end

function _gen_wiki(folder)
    -- Factions documentation
    -- ======================
    local handle
    if STRUCTURE == "hierarchical" then
        if not Spring.CreateDir(folder .. "/factions") then
            Spring.Log("cmd_generatewiki.lua", "error",
                "Failure creating the folder '" .. folder .. "/factions" .. "'")
            return false
        end
        handle = io.open(folder .. "/factions/main.md", "w")
    else
        if not Spring.CreateDir(folder) then
            Spring.Log("cmd_generatewiki.lua", "error",
                "Failure creating the folder '" .. folder .. "'")
            return false
        end
        handle = io.open(folder .. "/factions" .. ".md", "w")
    end
    handle.write(handle, "# Factions\n")
    local factions = Spring.GetSideData()
    local extra_data = include("gamedata/sidedata.lua")
    for i = 1,#factions do
        if factions[i].startUnit ~= 'gmtoolbox' then
            factions[i].title = extra_data[i].wiki_title
            factions[i].wiki = extra_data[i].wiki_desc
            _gen_faction(folder, factions[i])
            local side = factions[i].sideName
            handle.write(handle, "* ![" .. side .. "]")
            handle.write(handle, "(" .. FACTIONS_PICS_URL .. side .. ".png) ")
            handle.write(handle, "[" .. factions[i].title .. "]")
            if STRUCTURE == "hierarchical" then
                handle.write(handle, "(factions/" .. side .. "/main)\n")
            else
                handle.write(handle, "(factions." .. side .. ")\n")
            end
        end
    end
    handle.write(handle, "\n")
    handle.close(handle)

    -- Units documentation
    -- ===================
    if STRUCTURE == "hierarchical" then
        if not Spring.CreateDir(folder .. "/units") then
            Spring.Log("cmd_generatewiki.lua", "error",
                "Failure creating the folder '" .. folder .. "/units" .. "'")
            return false
        end
    end
    for id,unitDef in pairs(UnitDefs) do
        _gen_unit(unitDef.name, folder)
    end
    
    return true
end

function GenerateWiki(cmd, optLine)
    local folder = Game.gameShortName .. "_wiki"
    
    words = {}
    for word in optLine:gmatch("%S+") do
        table.insert(words, word)
    end
    for i = 1,#words,2 do
        if words[i] == 'folder' then
            folder = words[i + 1]
        end
    end

    Spring.Echo("GenerateWiki", folder)
    return _gen_wiki(folder)
end

function widget:Initialize()
    -- /wiki [folder path]
    widgetHandler:AddAction("wiki", GenerateWiki)
end
