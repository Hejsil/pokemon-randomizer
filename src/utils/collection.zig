pub fn Collection(comptime Item: type, comptime Errors: type) type {
    const VTable = struct {
        const Self = this;

        at: fn (*const u8, usize) Errors!Item,
        length: fn (*const u8) usize,

        fn init(comptime Functions: type, comptime Context: type) Self {
            return Self{
                .at = struct {
                    fn at(d: *const u8, i: usize) Errors!Item {
                        return Functions.at(cast(Context, d), i);
                    }
                }.at,

                .length = struct {
                    fn length(d: *const u8) usize {
                        return Functions.length(cast(Context, d));
                    }
                }.length,
            };
        }

        fn cast(comptime Context: type, ptr: *const u8) *const Context {
            return @ptrCast(*const Context, @alignCast(@alignOf(Context), ptr));
        }
    };

    return struct {
        const Self = this;

        data: *const u8,
        vtable: *const VTable,

        pub fn initContext(context: var) Self {
            return initExternFunctionsAndContext(@TypeOf(context.*), @TypeOf(context.*), context);
        }

        pub fn initSlice(comptime T: type, slice: *const []T) Self {
            return initExternFunctionsAndContext(struct {
                fn at(s: *const []T, index: usize) (Errors!*T) {
                    return &(s.*)[index];
                }
                fn length(s: *const []T) usize {
                    return s.len;
                }
            }, []T, slice);
        }

        pub fn initSliceConst(comptime T: type, slice: *const []const T) Self {
            return initExternFunctionsAndContext(struct {
                fn at(s: []const T, index: usize) (Errors!*const T) {
                    return *s[index];
                }
                fn length(s: []T) usize {
                    return s.len;
                }
            }, []const T, slice);
        }

        pub fn initExternFunctionsAndContext(comptime Functions: type, comptime Context: type, context: *const Context) Self {
            return Self{
                .data = @ptrCast(*const u8, context),
                .vtable = &comptime VTable.init(Functions, Context),
            };
        }

        pub fn at(coll: *const Self, index: usize) Errors!Item {
            return coll.vtable.at(coll.data, index);
        }

        pub fn length(coll: *const Self) usize {
            return coll.vtable.length(coll.data);
        }

        pub fn iterator(coll: *const Self) Iterator {
            return Iterator{
                .current = 0,
                .collection = coll,
            };
        }

        const Iterator = struct {
            current: usize,
            collection: *const Self,

            const Pair = struct {
                value: Item,
                index: usize,
            };

            pub fn next(it: *Iterator) ?Pair {
                while (true) {
                    const res = it.nextWithErrors() catch continue;
                    return res;
                }
            }

            pub fn nextWithErrors(it: *Iterator) Errors!?Pair {
                const l = it.collection.length();
                if (l <= it.current) return null;

                defer it.current += 1;
                return Pair{
                    .value = try it.collection.at(it.current),
                    .index = it.current,
                };
            }
        };
    };
}
