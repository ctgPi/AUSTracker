const std = @import("std");

fn LineReader(comptime Buffer: type, comptime Reader: type) type {
    return struct {
        buffer: Buffer,
        stream: std.io.FixedBufferStream(Buffer),
        reader: Reader,

        const Self = @This();

        pub fn readLine(self: *Self) ![]u8 {
            self.stream.reset();
            // TODO: look for the "\r\n" sequence specifically
            if (self.reader.streamUntilDelimiter(self.stream.writer(), '\r', null)) {
                std.debug.assert(try self.reader.readByte() == '\n');
                return self.stream.buffer[0..self.stream.pos];
            } else |err| {
                if (self.stream.pos > 0) {
                    return self.stream.buffer[0..self.stream.pos];
                } else {
                    return err;
                }
            }
        }
    };
}

fn lineReader(buffer: anytype, reader: anytype) LineReader(Slice(@TypeOf(buffer)), @TypeOf(reader)) {
    return .{
        .buffer = buffer,
        .stream = std.io.fixedBufferStream(buffer),
        .reader = reader,
    };
}

// FIXME
fn Slice(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Pointer => |ptr_info| {
            var new_ptr_info = ptr_info;
            switch (ptr_info.size) {
                .Slice => {},
                .One => switch (@typeInfo(ptr_info.child)) {
                    .Array => |info| new_ptr_info.child = info.child,
                    else => @compileError("invalid type given to fixedBufferStream"),
                },
                else => @compileError("invalid type given to fixedBufferStream"),
            }
            new_ptr_info.size = .Slice;
            return @Type(.{ .Pointer = new_ptr_info });
        },
        else => @compileError("invalid type given to fixedBufferStream"),
    }
}

pub const GameState = struct {
    ability: [24]bool,
    boss: [17]bool,
    constitution: struct {
        health: u16,
        breath: u8,
        shield: u8,
    },
    jump: struct {
        single: u4,
        double: u4,
    },
    money: u32,
    total: struct {
        gold_orbs: u8,
        flowers: u8,
    },
    map: [30][25] struct {
        color: struct {
            r: u8,
            g: u8,
            b: u8,
        },
        flags: u8,  // FIXME
    },

    fn check(condition: bool) !void {
        if (!condition) {
            return error.InvalidSaveFile;
        }
    }

    pub fn load(reader: anytype) !GameState {
        var state: GameState = undefined;

        var buffer: [4096]u8 = undefined;
        var line_reader = lineReader(&buffer, reader);

        { // Header
            const line = try line_reader.readLine();
            try check(std.mem.eql(u8, "Untitled Story Save File", line));
        }

        { // Header
            const line = try line_reader.readLine();
            try check(
                std.mem.eql(u8, "!!! WARNING: EDITING WILL RESULT IN DELETION !!!", line) or
                std.mem.eql(u8, "!!! WARNING: EDITED SAVEFILES MAY NOT LOAD !!!", line));
        }

        { // Abilities
            const line = try line_reader.readLine();
            try check(line.len == 23);

            for (0..23) |i| {
                switch (line[i]) {
                    '0' => state.ability[i] = false,
                    '1' => state.ability[i] = true,
                    else => unreachable,
                }
            }
        }

        { // Hearts [1..90]
            const line = try line_reader.readLine();
            try check(line.len == 90);
        }

        { // Gold orbs
            const line = try line_reader.readLine();
            try check(line.len == 10);
        }

        { // Unlocked secrets [1..90]
            const line = try line_reader.readLine();
            try check(line.len == 90);
        }

        { // Purchases
            const line = try line_reader.readLine();
            try check(line.len == 24);
        }

        { // Bosses
            const line = try line_reader.readLine();
            try check(line.len == 17);
            for (0..17) |i| {
                switch (line[i]) {
                    '0' => state.boss[i] = false,
                    '1' => state.boss[i] = true,
                    else => unreachable,
                }
            }
        }

        { // Options
            const line = try line_reader.readLine();
            try check(line.len == 5);
        }

        // Map
        for (0..30) |i| {
            for (0..25) |j| {
                {
                    const line = try line_reader.readLine();
                    const packed_color = try std.fmt.parseInt(u32, line, 10);
                    state.map[i][j].color.r = @truncate(u8, packed_color >>  0);
                    state.map[i][j].color.g = @truncate(u8, packed_color >>  8);
                    state.map[i][j].color.b = @truncate(u8, packed_color >> 16);
                }

                {
                    const line = try line_reader.readLine();
                    try check(line.len == 3);

                    state.map[i][j].flags = 0;
                    for (0..3) |k| {
                        switch (line[k]) {
                            '0' => continue,
                            '1' => state.map[i][j].flags |= @as(u8, 1) << @truncate(u3, k),
                            else => unreachable,
                        }
                    }
                }
            }
        }

        // Mini-games
        for (0..5) |_| {
            for (0..3) |_| {
                {
                    const line = try line_reader.readLine();
                    try check(line.len < 100);  // FIXME
                }
            }
        }

        { // Gold orb count
            const line = try line_reader.readLine();
            state.total.gold_orbs = try std.fmt.parseInt(u8, line, 10);
        }

        { // Heart count
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Blue orb count
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Flower count
            const line = try line_reader.readLine();
            state.total.flowers = try std.fmt.parseInt(u8, line, 10);
        }

        { // Maximum life
            const line = try line_reader.readLine();
            state.constitution.health = try std.fmt.parseInt(u16, line, 10);
        }

        { // Maximum air
            const line = try line_reader.readLine();
            state.constitution.breath = try std.fmt.parseInt(u8, line, 10);
        }

        { // Jump height
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Double jump height
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Money
            const line = try line_reader.readLine();
            state.money = try std.fmt.parseInt(u32, line, 10);
        }

        { // In-game timer
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Deaths
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Saves
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Damage
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Stage X
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Stage Y
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Player X
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Player Y
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Save slot
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Name
            const line = try line_reader.readLine();
            try check(line.len < 100);  // FIXME
        }

        // Controls
        for (0..10) |_| { // FIXME
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Checksum
            const line = try line_reader.readLine();
            _ = try std.fmt.parseInt(u32, line, 10);
        }

        { // Abilities
            const line = try line_reader.readLine();
            for (23..24) |i| {
                switch (line[i-23]) {
                    '0' => state.ability[i] = false,
                    '1' => state.ability[i] = true,
                    else => unreachable,
                }
            }
        }

        { // Hearts [91..95]
            const line = try line_reader.readLine();
            try check(line.len == 5);
        }

        { // Secrets [91..95]
            const line = try line_reader.readLine();
            try check(line.len == 5);
        }

        state.jump.single = 0;
        for (0..3) |i| {
            if (state.ability[i]) { state.jump.single += 1; }
        }

        state.jump.double = 0;
        for (5..8) |i| {
            if (state.ability[i]) { state.jump.double += 1; }
        }

        state.constitution.shield = 0;
        for (21..24) |i| {
            if (state.ability[i]) { state.constitution.shield += 10; }
        }

        return state;
    }
};

// pub fn main() !void {
//     const stdout = std.io.getStdOut().writer();
// 
//     const save_file = std.fs.cwd().openFile("../../Downloads/VMShared/Games/AnUntitledStory/UntitledSave1", std.fs.File.OpenFlags {}) catch unreachable;
//     defer save_file.close();
// 
//     const game_state = try parseSave(save_file.reader());
//     try stdout.print("❤️  {d} 🩵  {d} 🛡️  {d}\n", .{ game_state.constitution.health, game_state.constitution.breath, game_state.constitution.shield });
//     try stdout.print("Jump {d}+{d}\n", .{ game_state.jump.single, game_state.jump.double });
//     try stdout.print("money {d}\n", .{ game_state.money });
//     try stdout.print("🟡 {d}\n", .{ game_state.gold_orbs });
//     if (game_state.ability[3]) {
//         // red energy
//     }
//     if (game_state.ability[4]) {
//         try stdout.print("🏺\n", .{ });
//     }
//     if (game_state.ability[8]) {
//         try stdout.print("🦆\n", .{ });
//     }
//     if (game_state.ability[9]) {
//         // stick
//     }
//     if (game_state.ability[10]) {
//         // slide
//     }
//     if (game_state.ability[11]) {
//         // teleport
//     }
//     if (game_state.ability[12]) {
//         // dive bomb
//     }
//     if (game_state.ability[13]) {
//         try stdout.print("🔥\n", .{ });
//     }
//     if (game_state.ability[14]) {
//         // long shot
//     }
//     if (game_state.ability[15]) {
//         // yellow energy
//     }
//     if (game_state.ability[16]) {
//         try stdout.print("🐣\n", .{ });
//     }
//     if (game_state.ability[19]) {
//         try stdout.print("🧲\n", .{ });
//     }
//     if (game_state.ability[20]) {
//         try stdout.print("🧊\n", .{ });
//     }
// }
