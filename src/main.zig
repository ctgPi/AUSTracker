const std = @import("std");
const assert = std.debug.assert;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_image.h");
    @cInclude("SDL2/SDL_ttf.h");
});
const Color = c.SDL_Color;
const Position = struct {
    x: i32,
    y: i32,
    anchor: Anchor = .BASELINE_LEFT,

    pub const Anchor = enum {
        BASELINE_LEFT,
        BASELINE_CENTER,
        BASELINE_RIGHT,
    };
};

const GameState = @import("./game_state.zig").GameState;

const window_w = 640;
const window_h = 480;

const RenderContext = struct {
    renderer: *c.SDL_Renderer,
    texture: struct {
        boss_dead: *c.SDL_Texture,
        boss_icon: [17]*c.SDL_Texture,
        floor_none: *c.SDL_Texture,
        floor_duck: *c.SDL_Texture,
        ceiling_none: *c.SDL_Texture,
        ceiling_stick: *c.SDL_Texture,
        ceiling_slide: *c.SDL_Texture,
        bomb_none: *c.SDL_Texture,
        bomb_dive: *c.SDL_Texture,
    },
    font: struct {
        fira_sans: *c.TTF_Font,
        noto_emoji: *c.TTF_Font,
        dejavu_sans: *c.TTF_Font,
    },

    fn drawText(self: RenderContext, text: []const u8, font: *c.TTF_Font, position: Position, color: Color) void {
        var buffer: [64]u8 = [_]u8 { 0 } ** 64;
        @memcpy(buffer[0..text.len], text);

        const surface = c.TTF_RenderUTF8_Blended(font, &buffer, color);
        defer c.SDL_FreeSurface(surface);

        const texture = c.SDL_CreateTextureFromSurface(self.renderer, surface);
        defer c.SDL_DestroyTexture(texture);

        const x: c_int = @intCast(c_int, switch (position.anchor) {
            .BASELINE_LEFT => position.x,
            .BASELINE_CENTER => position.x - @divFloor(@intCast(i32, surface.*.w), 2),
            .BASELINE_RIGHT => position.x - @intCast(i32, surface.*.w),
        });

        const y: c_int = @intCast(c_int, switch (position.anchor) {
            .BASELINE_LEFT,
            .BASELINE_CENTER,
            .BASELINE_RIGHT => position.y - @intCast(i32, c.TTF_FontAscent(font)),
        });

        const target_rect = c.SDL_Rect{ .x = x + 8, .y = y + 8, .w = surface.*.w, .h = surface.*.h };
        _ = c.SDL_RenderCopy(self.renderer, texture, null, &target_rect);
    }

    pub fn render(self: RenderContext, state: GameState) !void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0xff, 0x00, 0xff, 0xff);
        _ = c.SDL_RenderClear(self.renderer);

        const border_size = 8;
        var client_area = c.SDL_Rect{ .x = border_size, .y = border_size, .w = window_w - 2 * border_size, .h = window_h - 2 * border_size };
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0x00, 0x00, 0x00, 0xff);
        _ = c.SDL_RenderFillRect(self.renderer, &client_area);

        var buffer: [4096]u8 = undefined;

        self.drawText("♥", self.font.noto_emoji, .{ .x = 36, .y = 48, .anchor = .BASELINE_CENTER }, .{ .r = 0xff, .g = 0x00, .b = 0x00, .a = 0xff });
        {
            const text = try std.fmt.bufPrint(&buffer, "{d}", .{ state.constitution.health });
            self.drawText(text, self.font.fira_sans, .{ .x = 156, .y = 48, .anchor = .BASELINE_RIGHT }, .{ .r = 0xff, .g = 0xff, .b = 0xff, .a = 0xff });
        }
        self.drawText("🛡️", self.font.noto_emoji, .{ .x = 216, .y = 48, .anchor = .BASELINE_CENTER }, .{ .r = 0x80, .g = 0x80, .b = 0xff, .a = 0xff });
        {
            const text = try std.fmt.bufPrint(&buffer, "{d}", .{ state.constitution.shield });
            self.drawText(text, self.font.fira_sans, .{ .x = 300, .y = 48, .anchor = .BASELINE_RIGHT }, .{ .r = 0xff, .g = 0xff, .b = 0xff, .a = 0xff });
        }
        self.drawText("↷", self.font.dejavu_sans, .{ .x = 360, .y = 48, .anchor = .BASELINE_CENTER }, .{ .r = 0x80, .g = 0x80, .b = 0xff, .a = 0xff });
        {
            const text = try std.fmt.bufPrint(&buffer, "{d}+{d}", .{ state.jump.single, state.jump.double });
            self.drawText(text, self.font.fira_sans, .{ .x = 456, .y = 48, .anchor = .BASELINE_RIGHT }, .{ .r = 0xff, .g = 0xff, .b = 0xff, .a = 0xff });
        }
        if (state.ability[3]) {
            self.drawText("✨", self.font.noto_emoji, .{ .x = 504, .y = 48, .anchor = .BASELINE_CENTER }, .{ .r = 0xff, .g = 0x00, .b = 0x00, .a = 0xff });
        } else {
            self.drawText("✨", self.font.noto_emoji, .{ .x = 504, .y = 48, .anchor = .BASELINE_CENTER }, .{ .r = 0x66, .g = 0x66, .b = 0x66, .a = 0xff });
        }
        if (state.ability[15]) {
            self.drawText("✨", self.font.noto_emoji, .{ .x = 552, .y = 48, .anchor = .BASELINE_CENTER }, .{ .r = 0xff, .g = 0xff, .b = 0x00, .a = 0xff });
        } else {
            self.drawText("✨", self.font.noto_emoji, .{ .x = 552, .y = 48, .anchor = .BASELINE_CENTER }, .{ .r = 0x66, .g = 0x66, .b = 0x66, .a = 0xff });
        }

        self.drawText("⬤", self.font.dejavu_sans, .{ .x = 36, .y = 96, .anchor = .BASELINE_CENTER }, .{ .r = 0xff, .g = 0xcc, .b = 0x00, .a = 0xff });
        {
            const text = try std.fmt.bufPrint(&buffer, "{d}", .{ state.total.gold_orbs });
            self.drawText(text, self.font.fira_sans, .{ .x = 108, .y = 96, .anchor = .BASELINE_RIGHT }, .{ .r = 0xff, .g = 0xff, .b = 0xff, .a = 0xff });
        }

        self.drawText("🌸", self.font.noto_emoji, .{ .x = 180, .y = 96, .anchor = .BASELINE_CENTER }, .{ .r = 0x66, .g = 0x66, .b = 0xff, .a = 0xff });
        {
            const text = try std.fmt.bufPrint(&buffer, "{d}", .{ state.total.flowers });
            self.drawText(text, self.font.fira_sans, .{ .x = 264, .y = 96, .anchor = .BASELINE_RIGHT }, .{ .r = 0xff, .g = 0xff, .b = 0xff, .a = 0xff });
        }

        self.drawText("💰", self.font.noto_emoji, .{ .x = 336, .y = 96, .anchor = .BASELINE_CENTER }, .{ .r = 0x00, .g = 0xff, .b = 0x00, .a = 0xff });
        {
            const text = try std.fmt.bufPrint(&buffer, "{d}", .{ state.money });
            self.drawText(text, self.font.fira_sans, .{ .x = 456, .y = 96, .anchor = .BASELINE_RIGHT }, .{ .r = 0xff, .g = 0xff, .b = 0xff, .a = 0xff });
        }

        // long shot: 

        if (true) {  // draw bosses
            for (0..17) |i| {
                const boss_rectangle = c.SDL_Rect{ .x = 32 + @intCast(c_int, 34 * i), .y = 120, .w = 32, .h = 32 };
                _ = c.SDL_SetRenderDrawColor(self.renderer, 0xff, 0xff, 0xff, 0xff);
                _ = c.SDL_RenderFillRect(self.renderer, &boss_rectangle);

                _ = c.SDL_RenderCopy(self.renderer, self.texture.boss_icon[i], null, &boss_rectangle);

                if (state.boss[i]) {
                    _ = c.SDL_SetRenderDrawBlendMode(self.renderer, c.SDL_BLENDMODE_BLEND);
                    _ = c.SDL_SetRenderDrawColor(self.renderer, 0x00, 0x00, 0x00, 0x99);
                    _ = c.SDL_RenderFillRect(self.renderer, &boss_rectangle);

                    _ = c.SDL_RenderCopy(self.renderer, self.texture.boss_dead, null, &boss_rectangle);
                }
            }
        }

        if (true) {  // draw map
            if (false) {
                const map_rectangle = c.SDL_Rect{ .x = 8, .y = 163, .w = 369, .h = 309 };
                _ = c.SDL_SetRenderDrawColor(self.renderer, 0x00, 0xff, 0x00, 0xff);
                _ = c.SDL_RenderFillRect(self.renderer, &map_rectangle);
            }
            for (0..30) |i| {
                for (0..25) |j| { 
                    const cell = state.map[i][j];
                    const x =  12 + i * 12;
                    const y = 167 + j * 12;
                    const cell_rectangle = c.SDL_Rect{ .x = @intCast(c_int, x + 1), .y = @intCast(c_int, y + 1), .w = 11, .h = 11 };
                    _ = c.SDL_SetRenderDrawColor(self.renderer, cell.color.r, cell.color.g, cell.color.b, 0xff);
                    _ = c.SDL_RenderFillRect(self.renderer, &cell_rectangle);

                    //if (cell.flags & (1 << 0) != 0) {
                    if (false) {
                        const flag_rectangle = c.SDL_Rect{ .x = @intCast(c_int, x + 3), .y = @intCast(c_int, y + 3), .w = 7, .h = 7 };
                        _ = c.SDL_SetRenderDrawColor(self.renderer, 0x00, 0x00, 0x00, 0xff);
                        _ = c.SDL_RenderFillRect(self.renderer, &flag_rectangle);
                    }
                }
            }
        }

        if (true) {
            const floor_rectangle = c.SDL_Rect{ .x = 400, .y = 160, .w = 64, .h = 64 };
            _ = c.SDL_SetRenderDrawColor(self.renderer, 0xff, 0xff, 0xff, 0xff);
            _ = c.SDL_RenderFillRect(self.renderer, &floor_rectangle);

            if (state.ability[8]) {
                _ = c.SDL_RenderCopy(self.renderer, self.texture.floor_duck, null, &floor_rectangle);
            } else {
                _ = c.SDL_RenderCopy(self.renderer, self.texture.floor_none, null, &floor_rectangle);
                _ = c.SDL_SetRenderDrawColor(self.renderer, 0x00, 0x00, 0x00, 0x99);
                _ = c.SDL_RenderFillRect(self.renderer, &floor_rectangle);
            }
        }

        if (true) {
            const ceiling_rectangle = c.SDL_Rect{ .x = 472, .y = 160, .w = 64, .h = 64 };
            _ = c.SDL_SetRenderDrawColor(self.renderer, 0xff, 0xff, 0xff, 0xff);
            _ = c.SDL_RenderFillRect(self.renderer, &ceiling_rectangle);

            if (state.ability[10]) {
                _ = c.SDL_RenderCopy(self.renderer, self.texture.ceiling_slide, null, &ceiling_rectangle);
            } else if (state.ability[9]) {
                _ = c.SDL_RenderCopy(self.renderer, self.texture.ceiling_stick, null, &ceiling_rectangle);
            } else {
                _ = c.SDL_RenderCopy(self.renderer, self.texture.ceiling_none, null, &ceiling_rectangle);
                _ = c.SDL_SetRenderDrawColor(self.renderer, 0x00, 0x00, 0x00, 0x99);
                _ = c.SDL_RenderFillRect(self.renderer, &ceiling_rectangle);
            }
        }

        if (true) {
            const bomb_rectangle = c.SDL_Rect{ .x = 544, .y = 160, .w = 64, .h = 64 };
            _ = c.SDL_SetRenderDrawColor(self.renderer, 0xff, 0xff, 0xff, 0xff);
            _ = c.SDL_RenderFillRect(self.renderer, &bomb_rectangle);

            if (state.ability[12]) {
                _ = c.SDL_RenderCopy(self.renderer, self.texture.bomb_dive, null, &bomb_rectangle);
            } else {
                _ = c.SDL_RenderCopy(self.renderer, self.texture.bomb_none, null, &bomb_rectangle);
                _ = c.SDL_SetRenderDrawColor(self.renderer, 0x00, 0x00, 0x00, 0x99);
                _ = c.SDL_RenderFillRect(self.renderer, &bomb_rectangle);
            }
        }

        if (true) {
            if (state.ability[13]) {
                self.drawText("🔥", self.font.noto_emoji, .{ .x = 430, .y = 256, .anchor = .BASELINE_CENTER }, .{ .r = 0xff, .g = 0x99, .b = 0x00, .a = 0xff });
            } else {
                self.drawText("🔥", self.font.noto_emoji, .{ .x = 430, .y = 256, .anchor = .BASELINE_CENTER }, .{ .r = 0x66, .g = 0x66, .b = 0x66, .a = 0xff });
            }
            if (state.ability[20]) {
                self.drawText("🧊", self.font.noto_emoji, .{ .x = 490, .y = 256, .anchor = .BASELINE_CENTER }, .{ .r = 0x33, .g = 0x99, .b = 0xff, .a = 0xff });
            } else {
                self.drawText("🧊", self.font.noto_emoji, .{ .x = 490, .y = 256, .anchor = .BASELINE_CENTER }, .{ .r = 0x66, .g = 0x66, .b = 0x66, .a = 0xff });
            }
            if (state.ability[15]) {
                self.drawText("⇝", self.font.dejavu_sans, .{ .x = 550, .y = 256, .anchor = .BASELINE_CENTER }, .{ .r = 0xff, .g = 0xff, .b = 0x66, .a = 0xff });
            } else {
                self.drawText("⇝", self.font.dejavu_sans, .{ .x = 550, .y = 256, .anchor = .BASELINE_CENTER }, .{ .r = 0x66, .g = 0x66, .b = 0x66, .a = 0xff });
            }
        }

        c.SDL_RenderPresent(self.renderer);
    }
};

const fira_sans_data = @embedFile("fonts/FiraSans-Regular.otf")[0..];
const noto_emoji_data = @embedFile("fonts/NotoEmoji-Regular.ttf")[0..];
const dejavu_sans_data = @embedFile("fonts/DejaVuSans-Regular.ttf")[0..];

const boss_icon_data: [17][]const u8 = blk: {
    var data: [17][]const u8 = undefined;
    var buffer: [64]u8 = undefined;
    inline for (0..17) |i| {
        const text = std.fmt.bufPrint(&buffer, "images/boss/{d}.png", .{ i }) catch unreachable;
        data[i] = @embedFile(text)[0..];
    }
    break :blk data;
};
const boss_dead_data = @embedFile("images/boss/dead.png")[0..];

const floor_none_data = @embedFile("images/floor/none.png")[0..];
const floor_duck_data = @embedFile("images/floor/duck.png")[0..];

const ceiling_none_data = @embedFile("images/ceiling/none.png")[0..];
const ceiling_stick_data = @embedFile("images/ceiling/stick.png")[0..];
const ceiling_slide_data = @embedFile("images/ceiling/slide.png")[0..];

const bomb_none_data = @embedFile("images/bomb/none.png")[0..];
const bomb_dive_data = @embedFile("images/bomb/dive.png")[0..];

fn loadFont(data: []const u8, font_size: u32) !*c.TTF_Font {
    const font_rw = c.SDL_RWFromConstMem(data.ptr, @intCast(c_int, data.len));
    const font = c.TTF_OpenFontRW(font_rw, 1, @intCast(c_int, font_size)) orelse unreachable;
    c.TTF_SetFontHinting(font, c.TTF_HINTING_LIGHT);
    c.TTF_SetFontKerning(font, 1);

    return font;
}

fn loadTexture(renderer: *c.SDL_Renderer, data: []const u8) !*c.SDL_Texture {
    const texture_rw = c.SDL_RWFromConstMem(data.ptr, @intCast(c_int, data.len));
    const texture = c.IMG_LoadTexture_RW(renderer, texture_rw, 1) orelse unreachable;
    return texture;
}

pub fn main() !void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    _ = c.TTF_Init();
    defer c.TTF_Quit();

    const font_size = 36;

    const fira_sans = try loadFont(fira_sans_data, font_size);
    defer c.TTF_CloseFont(fira_sans);

    const noto_emoji = try loadFont(noto_emoji_data, font_size);
    defer c.TTF_CloseFont(noto_emoji);

    const dejavu_sans = try loadFont(dejavu_sans_data, font_size);
    defer c.TTF_CloseFont(dejavu_sans);

    var window = c.SDL_CreateWindow("AUSTracker", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, window_w, window_h, 0) orelse unreachable;
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC) orelse unreachable;
    defer c.SDL_DestroyRenderer(renderer);
    
    const boss_icon = blk: {
        var texture: [17]*c.SDL_Texture = undefined;
        for (0..17) |i| {
            texture[i] = try loadTexture(renderer, boss_icon_data[i]);
        }
        break :blk texture;
    };
    defer {
        for (0..17) |i| {
            c.SDL_DestroyTexture(boss_icon[i]);
        }
    }

    const boss_dead = try loadTexture(renderer, boss_dead_data);
    defer c.SDL_DestroyTexture(boss_dead);

    const floor_none = try loadTexture(renderer, floor_none_data);
    defer c.SDL_DestroyTexture(floor_none);

    const floor_duck = try loadTexture(renderer, floor_duck_data);
    defer c.SDL_DestroyTexture(floor_duck);

    const ceiling_none = try loadTexture(renderer, ceiling_none_data);
    defer c.SDL_DestroyTexture(ceiling_none);

    const ceiling_stick = try loadTexture(renderer, ceiling_stick_data);
    defer c.SDL_DestroyTexture(ceiling_stick);

    const ceiling_slide = try loadTexture(renderer, ceiling_slide_data);
    defer c.SDL_DestroyTexture(ceiling_slide);

    const bomb_none = try loadTexture(renderer, bomb_none_data);
    defer c.SDL_DestroyTexture(bomb_none);

    const bomb_dive = try loadTexture(renderer, bomb_dive_data);
    defer c.SDL_DestroyTexture(bomb_dive);

    const context = RenderContext {
        .renderer = renderer,
        .texture = .{
            .boss_dead = boss_dead,
            .boss_icon = boss_icon,
            .floor_none = floor_none,
            .floor_duck = floor_duck,
            .ceiling_none = ceiling_none,
            .ceiling_stick = ceiling_stick,
            .ceiling_slide = ceiling_slide,
            .bomb_none = bomb_none,
            .bomb_dive = bomb_dive,
        },
        .font = .{
            .fira_sans = fira_sans,
            .noto_emoji = noto_emoji,
            .dejavu_sans = dejavu_sans,
        },
    };

    var state: GameState = undefined;

    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }

        if (std.fs.cwd().openFile("UntitledSave1", std.fs.File.OpenFlags {})) |save_file| {
            defer save_file.close();
            if (GameState.load(save_file.reader())) |new_state| {
                state = new_state;
            } else |_| {
                // TODO: indicate an error
            }
        } else |_| {
            // TODO: indicate an error
        }

        try context.render(state);
    }
}
