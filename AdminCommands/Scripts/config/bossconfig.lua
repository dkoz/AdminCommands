local bossconfig = {}

bossconfig.bosses = {
    {
        name = "Balrog",
        characterID = "Boss_Anubis",
        level = 50,
        location = { X = -367250, Y = 279117, Z = 6753 },
        displayName = "Balrog the Destroyer",
        shiny = false,
        scale = 4.0,
        hpMultiplier = 25.0,
        attackMultiplier = 1.0,
        defenseMultiplier = 1.0,
        passiveSkills = { "Legend", "WorldTree_ATK_DEF" },
        activeSkills = {
            "RadiantBarrage",
            "CommetRain",
            "SandTornado",
        },
        rewards = {
            { item = "Unko_S", min = 1, max = 3 },
        },
    },
}

return bossconfig
