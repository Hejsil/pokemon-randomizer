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

    pub fn getTrainerPokemon(wrapper: &const Gen3, trainer: &const gen3.Trainer, index: usize) -> ?&gen3.PartyMemberBase {
        if (trainer.party_offset.get() < 0x8000000) return null;

        const offset = trainer.party_offset.get() - 0x8000000;

        switch (trainer.party_type) {
            gen3.PartyType.Standard => {
                return getBasePartyMember(gen3.PartyMember, wrapper.game.data, index, offset, trainer.party_size.get());
            },
            gen3.PartyType.WithMoves => {
                return getBasePartyMember(gen3.PartyMemberWithMoves, wrapper.game.data, index, offset, trainer.party_size.get());
            },
            gen3.PartyType.WithHeld => {
                return getBasePartyMember(gen3.PartyMemberWithHeld, wrapper.game.data, index, offset, trainer.party_size.get());
            },
            gen3.PartyType.WithBoth => {
                return getBasePartyMember(gen3.PartyMemberWithBoth, wrapper.game.data, index, offset, trainer.party_size.get());
            },
            else => return null,
        }
    }

    fn getBasePartyMember(comptime TMember: type, data: []u8, index: usize, offset: usize, size: usize) -> ?&gen3.PartyMemberBase {
        const party_end = offset + size * @sizeOf(TMember);
        if (data.len < party_end) return null;

        const party = ([]TMember)(data[offset..party_end]);
        const pokemon = utils.ptrAt(TMember, party, index) ?? return null;
        return &pokemon.base;
    }
};
