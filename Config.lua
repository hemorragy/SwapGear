local _, SG = ...

-- ----------------------------------------------------------------------------
--  REGLES
--  L'ORDRE = LA PRIORITE. La premiere regle de la liste gagne.
--  Exemple : 2 slots de bijou, 3 bijoux "actifs" -> on equipe les 2 premiers.
--
--  item  : ID de l'objet (celui de l'URL wowhead : .../item=11122/...)
--  name  : (optionnel) juste pour l'affichage si le jeu n'a pas encore le nom
--  when  : liste de conditions qui doivent TOUTES etre vraies (ET logique).
--          - une chaine  -> nom d'une condition definie plus bas ("mounted")
--          - "!nom"      -> negation ("!indoors")
--          - une fonction -> condition sur mesure, inline
--
--  Le slot (bijou, gants, bottes...) est deduit automatiquement de l'objet.
-- ----------------------------------------------------------------------------
SG.Rules = {
    -- Speed
    -- +7% mount desert
    { item = 274648, name = "The Desert Rose",   when = { "mounted", "desert" } },
    -- +3% mount
    { item = 11122,  name = "Carrot on a Stick", when = { "mounted" } },
    -- +5% swim
    { item = 260308,  name = "Hyjal Postal Clasp", when = { "swimming" } },

    -- argent dawn
    -- ap
    { item = 13209, name = "Seal of the Dawn", when = { "argent" } },
    -- sp
    { item = 19812, name = "Rune of the Dawn", when = { "argent" } },
    -- base
    { item = 12846, name = "Argent Dawn Commission", when = { "argent" } },

    -- haunted/waste mana caster
    { item = 20512, name = "Sanctified Orb", when = { "hauntedOrWasteland" } },
    -- forest ap
    { item = 270275, name = "Cleansed Vilebranch Medallion", when = { "forest" } },
    -- forest sp
    { item = 270276, name = "Cleansed Vilebranch Icon",      when = { "forest" } },

    -- Exemples (decommente / adapte) :
    -- { item = 12345, name = "Gants Joug-d'hiver", when = { "mounted", function()
    --       return SG.InZone({ "Joug-d'hiver", "Wintergrasp" })
    --   end } },
}

-- ----------------------------------------------------------------------------
--  SLOTS A SACRIFIER EN PREMIER
--  Quand un objet situationnel doit prendre une place, on remplace d'abord ces
--  slots. 13 = bijou du haut, 14 = bijou du bas, 11/12 = anneaux.
-- ----------------------------------------------------------------------------
SG.ReplaceFirst = { 14, 12 }

-- ----------------------------------------------------------------------------
--  ZONES
--  Nombres = uiMapID (tape /sg zone en jeu pour voir celui ou tu es)
--  Chaines = nom de zone tel qu'affiche (pratique en client FR)
--  Le tooltip dit juste "Desert areas" : la liste exacte est a confirmer en
--  jeu. Astuce : equipe la Rose, monte, et compare /sg speed dans la zone.
-- ----------------------------------------------------------------------------
local function I(id) return { instance = id } end
 
SG.Zones = {
    desert = {
        1418,  -- Terres ingrates / Badlands
        1419,  -- Terres foudroyees / Blasted Lands
        1443,  -- Desolace
        1411,  -- Durotar
        1451,  -- Silithus
        1446,  -- Tanaris
        1413,  -- Les Tarides / The Barrens
        1441,  -- Mille pointes / Thousand Needles
        1454,  -- Orgrimmar
        I(509),  -- Ruines d'Ahn'Qiraj (AQ20)
        I(531),  -- Temple d'Ahn'Qiraj (AQ40)
        I(70),   -- Uldaman
        I(209),  -- Zul'Farrak
        "Portes d'Ahn'Qiraj", "Gates of Ahn'Qiraj",
    },
    forest = {
        1417,  -- Hautes-terres d'Arathi
        1440,  -- Orneval / Ashenvale
        1447,  -- Azshara
        1439,  -- Sombrivage / Darkshore
        1426,  -- Dun Morogh
        1431,  -- Bois de la Penombre / Duskwood
        1445,  -- Marecage d'Aprefange / Dustwallow Marsh
        1423,  -- Maleterres de l'Est / Eastern Plaguelands
        1429,  -- Foret d'Elwynn
        1448,  -- Gangrebois / Felwood
        1444,  -- Feralas
        1424,  -- Contreforts de Hautebrande / Hillsbrad
        1432,  -- Loch Modan
        1450,  -- Reflet-de-Lune / Moonglade
        1412,  -- Mulgore
        1433,  -- Les Carmines / Redridge
        1421,  -- Foret des Pins-Argentes / Silverpine
        1442,  -- Les Serres-Rocheuses / Stonetalon
        1434,  -- Vallee de Strangleronce / Stranglethorn
        1435,  -- Marais des Chagrins / Swamp of Sorrows
        1438,  -- Teldrassil
        1425,  -- Les Hinterlands
        1420,  -- Clairieres de Tirisfal
        1449,  -- Cratere d'Un'Goro
        1422,  -- Maleterres de l'Ouest / Western Plaguelands
        1436,  -- Marche de l'Ouest / Westfall
        1437,  -- Les Paluns / Wetlands
        1452,  -- Berceau-de-l'Hiver / Winterspring
        1457,  -- Darnassus
        1453,  -- Hurlevent / Stormwind
        2482,  -- Mount Hyjal
        2548,  -- Riverdale
        I(30),   -- Vallee d'Alterac
        I(529),  -- Bassin Arathi
        I(489),  -- Goulet des Chanteguerres / Warsong Gulch
        I(429),  -- Hache-Tripes / Dire Maul
        I(33),   -- Donjon d'Ombrecroc / Shadowfang Keep
        I(309),  -- Zul'Gurub
        I(2974),  -- Blackmaw Hold
        I(3001),  -- The Shaper's Terrace
        -- zones propres a Forever (nom FR a verifier avec /sg zone) :
        "Darkspear Islands", "Shen'dralas",
        "Zephras Isle", "Excavation Site: Wetlands", "Gilneas",
        "Krol'dok Stronghold", "Ruins of Gilneas", "Valanaar",
    },
    swamp = {
        1439,  -- Sombrivage / Darkshore
        1445,  -- Marecage d'Aprefange / Dustwallow Marsh
        1444,  -- Feralas
        1435,  -- Marais des Chagrins / Swamp of Sorrows
        1449,  -- Cratere d'Un'Goro
        1437,  -- Les Paluns / Wetlands
        2548,  -- Riverdale
        I(349),  -- Maraudon
        I(109),  -- Temple d'Atal'Hakkar
        I(43),   -- Cavernes des Lamentations / Wailing Caverns
        I(2970), -- The Drowned City
        I(3001),  -- The Shaper's Terrace
        "Excavation Site: Wetlands",
    },
    wasteland = {
        1418,  -- Terres ingrates / Badlands
        1419,  -- Terres foudroyees / Blasted Lands
        1428,  -- Steppes ardentes / Burning Steppes
        1430,  -- Defile de Deuillevent / Deadwind Pass
        1443,  -- Desolace
        1411,  -- Durotar
        1423,  -- Maleterres de l'Est
        1448,  -- Gangrebois / Felwood
        1427,  -- Gorge des Vents brulants / Searing Gorge
        1451,  -- Silithus
        1421,  -- Foret des Pins-Argentes / Silverpine
        1446,  -- Tanaris
        1413,  -- Les Tarides / The Barrens
        1420,  -- Clairieres de Tirisfal
        1422,  -- Maleterres de l'Ouest
        1436,  -- Marche de l'Ouest / Westfall
        1454,  -- Orgrimmar
        1458,  -- Fossoyeuse / Undercity
        I(129),  -- Souilles de Tranchebauge / Razorfen Downs
        I(47),   -- Kraal de Tranchebauge / Razorfen Kraul
        I(329),  -- Stratholme
        I(209),  -- Zul'Farrak
        "Ruines de Lordaeron", "Ruins of Lordaeron",
        "Shen'dralas",
    },
    haunted = {
        1430,  -- Defile de Deuillevent / Deadwind Pass
        1431,  -- Bois de la Penombre / Duskwood
        1423,  -- Maleterres de l'Est
        1448,  -- Gangrebois / Felwood
        1421,  -- Foret des Pins-Argentes / Silverpine
        1435,  -- Marais des Chagrins / Swamp of Sorrows
        1420,  -- Clairieres de Tirisfal
        1422,  -- Maleterres de l'Ouest
        1458,  -- Fossoyeuse / Undercity
        I(429),  -- Hache-Tripes / Dire Maul
        I(349),  -- Maraudon
        I(533),  -- Naxxramas
        I(129),  -- Souilles de Tranchebauge / Razorfen Downs
        I(189),  -- Monastere ecarlate
        I(289),  -- Scholomance
        I(33),   -- Donjon d'Ombrecroc / Shadowfang Keep
        I(329),  -- Stratholme
        I(109),  -- Temple d'Atal'Hakkar
        I(209),  -- Zul'Farrak
        I(309),  -- Zul'Gurub
        I(2970), -- The Drowned City
        "Ruines de Lordaeron", "Ruins of Lordaeron",
        "Shen'dralas", "Gilneas", "Ruins of Gilneas", "The Hall of Thanes",
    },
    mountain = {
        1416,  -- Montagnes d'Alterac
        1417,  -- Hautes-terres d'Arathi
        1447,  -- Azshara
        1418,  -- Terres ingrates / Badlands
        1428,  -- Steppes ardentes / Burning Steppes
        1430,  -- Defile de Deuillevent / Deadwind Pass
        1426,  -- Dun Morogh
        1424,  -- Contreforts de Hautebrande / Hillsbrad
        1432,  -- Loch Modan
        1412,  -- Mulgore
        1433,  -- Les Carmines / Redridge
        1427,  -- Gorge des Vents brulants / Searing Gorge
        1442,  -- Les Serres-Rocheuses / Stonetalon
        1434,  -- Vallee de Strangleronce / Stranglethorn
        1413,  -- Les Tarides / The Barrens
        1425,  -- Les Hinterlands
        1441,  -- Mille pointes / Thousand Needles
        1452,  -- Berceau-de-l'Hiver / Winterspring
        1456,  -- Les Pitons-du-Tonnerre / Thunder Bluff
        2482,  -- Mount Hyjal
        I(30),   -- Vallee d'Alterac
        I(529),  -- Bassin Arathi
        I(2974),  -- Blackmaw Hold
        "Mont Rochenoire", "Blackrock Mountain",
        "Zephras Isle", "Krol'dok Stronghold",
    },
    snowy = {
        1416,  -- Montagnes d'Alterac
        1426,  -- Dun Morogh
        1452,  -- Berceau-de-l'Hiver / Winterspring
        I(30),   -- Vallee d'Alterac
    },
    city = {
        1457,  -- Darnassus
        1455,  -- Forgefer / Ironforge
        1454,  -- Orgrimmar
        1453,  -- Hurlevent / Stormwind
        1456,  -- Les Pitons-du-Tonnerre / Thunder Bluff
        1458,  -- Fossoyeuse / Undercity
        I(509), I(531),  -- Ahn'Qiraj (AQ20, AQ40)
        I(48),   -- Profondeurs de Brassenoire / Blackfathom Deeps
        I(230),  -- Profondeurs de Rochenoire / Blackrock Depths
        I(229),  -- Pic Rochenoire / Blackrock Spire
        I(469),  -- Repaire de l'Aile noire / Blackwing Lair
        I(429),  -- Hache-Tripes / Dire Maul
        I(90),   -- Gnomeregan
        I(533),  -- Naxxramas
        I(129),  -- Souilles de Tranchebauge
        I(47),   -- Kraal de Tranchebauge
        I(189),  -- Monastere ecarlate
        I(289),  -- Scholomance
        I(33),   -- Donjon d'Ombrecroc
        I(329),  -- Stratholme
        I(36),   -- Les Mortemines / The Deadmines
        I(34),   -- La Prison / The Stockade
        I(109),  -- Temple d'Atal'Hakkar
        I(70),   -- Uldaman
        I(489),  -- Goulet des Chanteguerres
        I(209),  -- Zul'Farrak
        I(309),  -- Zul'Gurub
        I(2970), -- The Drowned City
        I(2974),  -- Blackmaw Hold
        "Baie-du-Butin", "Booty Bay",
        "Gadgetzan",
        "Long-guet", "Everlook",
        "Mont Rochenoire", "Blackrock Mountain",
        "Portes d'Ahn'Qiraj", "Gates of Ahn'Qiraj",
        "Ruines de Lordaeron", "Ruins of Lordaeron",
        "Alcaz Prison", "City of Dalaran", "Gilneas", "Krol'dok Stronghold",
        "Ruins of Gilneas", "The Hall of Thanes", "Valanaar",
    },
    underground = {
        1455,  -- Forgefer / Ironforge
        1458,  -- Fossoyeuse / Undercity
        I(230),  -- Profondeurs de Rochenoire
        I(229),  -- Pic Rochenoire
        I(469),  -- Repaire de l'Aile noire
        I(90),   -- Gnomeregan
        I(349),  -- Maraudon
        I(409),  -- Coeur du Magma / Molten Core
        I(249),  -- Repaire d'Onyxia
        I(389),  -- Gouffre de Ragefeu / Ragefire Chasm
        I(36),   -- Les Mortemines
        I(34),   -- La Prison
        I(70),   -- Uldaman
        I(43),   -- Cavernes des Lamentations
        I(2974),  -- Blackmaw Hold
        "Alcaz Prison", "The Hall of Thanes",
    },
    -- Pas encore de liste officielle selon la source. Candidats probables,
    -- a verifier avec l'infobulle de l'objet sur place :
    volcanic = {
        1428,   -- Steppes ardentes / Burning Steppes
        1427,   -- Gorge des Vents brulants / Searing Gorge
        I(409), -- Coeur du Magma / Molten Core
    },
    argent = {
        1423,  -- Maleterres de l'Est
        1422,  -- Maleterres de l'Ouest
        I(289),  -- Scholomance
        I(329),  -- Stratholme
    },
}

-- ----------------------------------------------------------------------------
--  CONDITIONS REUTILISABLES
--  Une condition = une fonction sans argument qui renvoie true/false.
-- ----------------------------------------------------------------------------
SG.Conditions = {
    mounted  = function() return IsMounted() end,
    swimming = function() return IsSwimming() end,
    indoors  = function() return IsIndoors() end,
    resting  = function() return IsResting() end,          -- en ville / auberge
    instance = function() return (IsInInstance()) end,     -- donjon / raid / BG
    hauntedOrWasteland = function()
        return SG.InZone(SG.Zones.haunted) or SG.InZone(SG.Zones.wasteland)
    end,
}
