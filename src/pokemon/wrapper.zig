const std   = @import("std");
const gen3  = @import("gen3.zig");
const utils = @import("../utils.zig");

const mem   = std.mem;
const debug = std.debug;

pub const Gen3 = struct {
    game: &gen3.Game,

    pub fn init(game: &gen3.Game) -> Gen3 { return Gen3 { .game = game, }; }

    pub fn getBasePokemon(wrapper: &const Gen3, index: usize) -> ?&gen3.BasePokemon {
        return utils.ptrAt(gen3.BasePokemon, wrapper.game.base_stats, index);
    }

    pub fn getTrainer(wrapper: &const Gen3, index: usize) -> ?&gen3.Trainer {
        return utils.ptrAt(gen3.Trainer, wrapper.game.trainers, index);
    }

    pub fn getTrainerPokemon(wrapper: &const Gen3, trainer: &const gen3.Trainer, index: usize) -> ?&gen3.PartyMember {
        if (trainer.party_offset.get() < 0x8000000) return null;

        const offset = trainer.party_offset.get() - 0x8000000;
        const party_table_start = wrapper.game.offsets.trainer_parties;
        const party_table_end   = wrapper.game.offsets.trainer_class_names;
        const trainer_parties   = wrapper.game.trainer_parties;
        if (offset < party_table_start or party_table_end < offset) return null;

        switch (trainer.party_type) {
            gen3.PartyType.Standard => {
                const party = getParty(gen3.PartyMember, trainer_parties, offset, trainer.party_size.get(), party_table_end) ?? return null;
                return utils.ptrAt(gen3.PartyMember, party, index);
            },
            gen3.PartyType.WithMoves => {
                const party = getParty(gen3.PartyMemberWithMoves, trainer_parties, offset, trainer.party_size.get(), party_table_end) ?? return null;
                const pokemon = utils.ptrAt(gen3.PartyMemberWithMoves, party, index) ?? return null;
                return &pokemon.base;
            },
            gen3.PartyType.WithHeld => {
                const party = getParty(gen3.PartyMemberWithHeld, trainer_parties, offset, trainer.party_size.get(), party_table_end) ?? return null;
                const pokemon = utils.ptrAt(gen3.PartyMemberWithHeld, party, index) ?? return null;
                return &pokemon.base;
            },
            gen3.PartyType.WithBoth => {
                const party = getParty(gen3.PartyMemberWithBoth, trainer_parties, offset, trainer.party_size.get(), party_table_end) ?? return null;
                const pokemon = utils.ptrAt(gen3.PartyMemberWithBoth, party, index) ?? return null;
                return &pokemon.base;
            },
            else => return null,
        }
    }

    fn getParty(comptime TMember: type, trainer_parties: []u8, offset: usize, size: usize, table_end: usize) -> ?[]TMember {
        const party_end = offset + size * @sizeOf(TMember);
        if (table_end < party_end) return null;
        return ([]TMember)(trainer_parties[offset..party_end]);
    }
};
