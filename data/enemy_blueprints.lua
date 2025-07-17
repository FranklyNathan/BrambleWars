-- enemy_blueprints.lua
-- Defines the data-driven blueprints for all enemy types.

local EnemyBlueprints = {
    brawler = {
        color = {0.7, 0.7, 0.7},
        maxHp = 140,
        attackStat = 60,
        defenseStat = 50,
        movement = 5,
        weight = 7, -- Medium-Heavy
        attacks = {"slash"}
    },
    archer = {
        color = {0.7, 0.7, 0.7},
        maxHp = 110,
        attackStat = 50,
        defenseStat = 40,
        movement = 4,
        weight = 4, -- Light
        attacks = {"fireball", "longshot"}
    },
    punter = {
        color = {0.7, 0.7, 0.7},
        maxHp = 120,
        attackStat = 50,
        defenseStat = 40,
        movement = 5,
        weight = 8, -- Heavy
        attacks = {"uppercut"}
    }
}

return EnemyBlueprints