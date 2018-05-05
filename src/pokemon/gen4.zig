
pub const BasePokemon = packed struct {
    hp:         u8,
    attack:     u8,
    defense:    u8,
    speed:      u8,
    sp_attack:  u8,
    sp_defense: u8,

    types: [2]Type,

    catch_rate:     u8,
    base_exp_yield: u8,

    evs: common.EvYield,
    items: [2]Little(u16),

    gender_ratio: u8,
    egg_cycles: u8,
    base_friendship: u8,
    growth_rate: common.GrowthRate,

    egg_group1: common.EggGroup,
    egg_group1_pad: u4,
    egg_group2: common.EggGroup,
    egg_group2_pad: u4,

    abilities: [2]u8,
    flee_rate: u8,

    color: common.Color,
    color_padding: bool,

    // Memory layout
    // TMS 01-92, HMS 01-08
    tm_hm_learnset: Little(u128),
};
