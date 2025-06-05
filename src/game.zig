const rl = @import("raylib");
const std = @import("std");
const rand = std.crypto.random;

const Animator = struct {
    frameRec: rl.Rectangle = std.mem.zeroes(rl.Rectangle),
    frames: i8,
    frameTimer: f32 = 0,
    frameSpeed: f32 = 1.0,
    texture: rl.Texture2D = std.mem.zeroes(rl.Texture2D),
    currentFrame: i8 = 0,
    random: bool = false,
    fn setTexture(self: *Animator, texture: rl.Texture2D) void {
        self.texture = texture;
        self.frameRec.width = @as(f32, @floatFromInt(@divFloor(self.texture.width, self.frames)));
        self.frameRec.height = @as(f32, @floatFromInt(self.texture.height));
    }
    fn animate(self: *Animator, delta: f32) void {
        self.frameTimer += delta;
        if (self.frameTimer >= self.frameSpeed) {
            self.frameTimer -= self.frameSpeed;
            self.currentFrame += 1;
            if (self.currentFrame >= self.frames) self.currentFrame = 0;
            if (self.random) {
                const frame = rand.intRangeAtMost(i8, 0, self.frames - 1);
                self.frameRec.x = @as(f32, @floatFromInt(frame)) * @as(f32, @floatFromInt(@divFloor(self.texture.width, self.frames)));
            } else {
                self.frameRec.x = @as(f32, @floatFromInt(self.currentFrame)) * @as(f32, @floatFromInt(@divFloor(self.texture.width, self.frames)));
            }
        }
    }
};

const Flower = struct {
    animator: Animator = .{ .frames = 7, .frameSpeed = 0.3 },
    waterDrainSpeed: f32 = 0.2,
    maxWaterLevel: f32 = 200,
    waterLevel: f32 = 120,
    health: f32 = 100,
    currentFrame: u8 = 0,
    fn setTexture(self: *Flower, texture: rl.Texture2D) void {
        self.animator.setTexture(texture);
    }
    fn update(self: *Flower, delta: f32) void {
        if (self.waterLevel != 0.0) {
            self.waterLevel = self.waterLevel - (self.waterDrainSpeed * delta);
        }
        if (self.waterLevel < 0.0) {
            self.waterLevel = 0.0;
        }
        self.animate(delta);
    }
    fn animate(self: *Flower, delta: f32) void {
        self.animator.animate(delta);
    }
    fn getWaterLevelPercentage(self: *Flower) f32 {
        return self.waterLevel / self.maxWaterLevel;
    }
};

const Sun = struct {
    animator: Animator = .{
        .frames = 8,
        .frameSpeed = 0.1,
        .random = true,
    },
    sunAmount: u8 = 10,
    fn setTexture(self: *Sun, texture: rl.Texture2D) void {
        self.animator.setTexture(texture);
    }
    fn update(self: *Sun, delta: f32) void {
        self.animate(delta);
    }
    fn animate(self: *Sun, delta: f32) void {
        self.animator.animate(delta);
    }
};

const Cloud = struct {
    animator: Animator = .{ .frames = 8 },
    rainAmount: u8 = 5,
    fn setTexture(self: *Cloud, texture: rl.Texture2D) void {
        self.animator.setTexture(texture);
    }
    fn update(self: *Cloud, delta: f32) void {
        self.animate(delta);
    }
    fn animate(self: *Cloud, delta: f32) void {
        self.animator.animate(delta);
    }
};

const WindParticles = struct {
    power: f32 = 0,
    position: rl.Vector2 = .{ .x = 0, .y = 0 },
};

const WaterParticles = struct {
    amount: f32 = 0,
    position: rl.Vector2 = .{ .x = 0, .y = 0 },
};

const Game = struct {
    target: rl.RenderTexture2D = std.mem.zeroes(rl.RenderTexture2D),
    width: i32 = 0,
    height: i32 = 0,
    virtualRatio: f32 = 0,
    currentScore: f32 = 0,
    highestScore: f32 = 0,
    flower: Flower = .{},
    sun: Sun = .{},
    cloud: Cloud = .{},
    sourceRec: rl.Rectangle = std.mem.zeroes(rl.Rectangle),
    windArray: [MAX_WIND_PARTICLES]WindParticles = std.mem.zeroes([MAX_WIND_PARTICLES]WindParticles),
    waterArray: [MAX_WATER_PARTICLES]WaterParticles = std.mem.zeroes([MAX_WATER_PARTICLES]WaterParticles),
    windArrayAmount: usize = 0,
    waterArrayAmount: usize = 0,
    windParticleCD: f32 = 1,
    waterParticleCD: f32 = 1,
    isPlaying: bool = false,
    isSunUp: bool = false,
};
const MAX_WIND_PARTICLES = 200;
const MAX_WATER_PARTICLES = 200;

const nativeWidth = 160; // e.g., 160x90 for a 16:9 aspect ratio
const nativeHeight = 90;

pub fn startGame() bool {
    game.width = 800;
    game.height = 450;
    game.isPlaying = true;
    updateRatio();

    rl.initWindow(game.width, game.height, "Pixel Bloom");

    // Initialize

    game.target = rl.loadRenderTexture(nativeWidth, nativeHeight) catch |err| switch (err) {
        rl.RaylibError.LoadRenderTexture => {
            std.debug.print("ERROR", .{});
            return false;
        },
        else => {
            return false;
        },
    };

    game.isSunUp = true;

    game.sun.setTexture(rl.Texture.init("resources/sun-0001.png") catch |err| switch (err) {
        rl.RaylibError.LoadTexture => {
            std.debug.print("ERROR", .{});
            return false;
        },
        else => {
            return false;
        },
    });
    game.cloud.setTexture(rl.Texture.init("resources/cloud-0001.png") catch |err| switch (err) {
        rl.RaylibError.LoadTexture => {
            std.debug.print("ERROR", .{});
            return false;
        },
        else => {
            return false;
        },
    });
    game.flower.setTexture(rl.Texture.init("resources/flower-0001.png") catch |err| switch (err) {
        rl.RaylibError.LoadTexture => {
            std.debug.print("ERROR", .{});
            return false;
        },
        else => {
            return false;
        },
    });

    game.sourceRec = rl.Rectangle{
        .x = 0.0,
        .y = 0.0,
        .width = @floatFromInt(game.target.texture.width),
        .height = @floatFromInt(-game.target.texture.height),
    };
    return true;
}
pub fn closeGame() void {
    std.debug.print("Closing\n", .{});
    rl.unloadRenderTexture(game.target);
    rl.unloadTexture(game.sun.animator.texture);
    rl.unloadTexture(game.cloud.animator.texture);
    rl.unloadTexture(game.flower.animator.texture);
}
fn updateRatio() void {
    game.virtualRatio = @as(f32, @floatFromInt(game.height)) / @as(f32, @floatFromInt(game.height));
}
pub threadlocal var game: Game = .{};
pub fn updateFrame() bool {
    if (rl.isKeyPressed(rl.KeyboardKey.space)) {
        game.isSunUp = !game.isSunUp;
        game.flower.animator.currentFrame = 0;
        game.cloud.animator.currentFrame = 0;
        game.sun.animator.currentFrame = 0;
        game.windArrayAmount = 0;
        game.waterArrayAmount = 0;
        game.windParticleCD = 1;
        game.waterParticleCD = 1;
    }

    if (rl.isWindowResized()) {
        game.width = rl.getScreenWidth();
        game.height = rl.getScreenHeight();
        updateRatio();
    }
    const delta = rl.getFrameTime();
    if (game.isSunUp) {
        game.sun.update(delta);
    } else {
        game.cloud.update(delta);
    }
    game.flower.update(delta);

    rl.beginTextureMode(game.target);

    // Clear the native resolution buffer with a background color from our palette
    rl.clearBackground(rl.Color.dark_gray);

    if (game.isSunUp) {
        game.windParticleCD -= delta;
        if (game.windParticleCD < 0) {
            game.windParticleCD = 1;
            if (game.windArrayAmount < MAX_WIND_PARTICLES) {
                game.windArray[game.windArrayAmount].power = rand.float(f32) * 20;
                game.windArray[game.windArrayAmount].position.y = nativeHeight - 50 + rand.float(f32) * 20;
                game.windArray[game.windArrayAmount].position.x = 0;
                game.windArrayAmount += 1;
            }
        }
        var i: usize = 0;
        while (i < game.windArrayAmount) {
            i += 1;
            var value = &game.windArray[i];
            value.position.x += value.power * delta;
            if (value.position.x > nativeWidth) {
                game.windArray[i] = game.windArray[game.windArrayAmount];
                game.windArrayAmount -= 1;
            }
            rl.drawPixelV(value.position, rl.Color.ray_white);
        }
        game.sun.animator.texture.drawRec(game.sun.animator.frameRec, .{ .x = 0, .y = 0 }, .white); // Draw part of the texture
    } else {
        game.waterParticleCD -= delta;
        if (game.waterParticleCD < 0) {
            game.waterParticleCD = 1;
            if (game.waterArrayAmount < MAX_WATER_PARTICLES) {
                game.waterArrayAmount += 1;
            }
            game.waterArray[game.waterArrayAmount - 1].amount = rand.float(f32) * 10;
            game.waterArray[game.waterArrayAmount - 1].position.y = 0;
            game.waterArray[game.waterArrayAmount - 1].position.x = 60 + rand.float(f32) * 20;
        }
        var i: usize = 0;
        while (i < game.waterArrayAmount) {
            i += 1;
            var value = &game.waterArray[i];
            value.position.y += value.amount * delta;
            if (value.position.y > nativeHeight) {
                game.waterArray[i] = game.waterArray[game.waterArrayAmount];
                game.waterArrayAmount -= 1;
            }
            rl.drawPixelV(value.position, rl.Color.ray_white);
        }
        game.cloud.animator.texture.drawRec(game.cloud.animator.frameRec, .{ .x = 40, .y = 0 }, .white); // Draw part of the texture
    }
    game.flower.animator.texture.drawRec(game.flower.animator.frameRec, .{ .x = 60, .y = nativeHeight - 64 }, .white); // Draw part of the texture
    std.debug.print("Frame: {d}: amount: {d}\n", .{ game.flower.animator.currentFrame, game.flower.animator.frames });

    rl.endTextureMode(); // Ensure texture mode is ended

    rl.beginDrawing();

    rl.clearBackground(rl.Color.white);

    // Define the destination rectangle on the screen (the entire screen)
    const destRec = rl.Rectangle{
        .x = -game.virtualRatio,
        .y = -game.virtualRatio,
        .width = @as(f32, @floatFromInt(game.width)) + (game.virtualRatio * 2),
        .height = @as(f32, @floatFromInt(game.height)) + (game.virtualRatio * 2),
    };

    // Draw the render texture to the screen, scaled up, with nearest-neighbor filtering
    rl.drawTexturePro(game.target.texture, // The texture to draw
        game.sourceRec, // Part of the texture to draw (entire texture)
        destRec, // Where on the screen to draw it
        rl.Vector2{ .x = 0.0, .y = 0.0 }, // Origin for rotation (top-left)
        0.0, // Rotation angle
        rl.Color.white // Tint color (use WHITE to draw as is)
    );
    // const fps = rl.getFPS();
    // rl.drawText(rl.textFormat("FPS: %03i", .{fps}), game.width - 100, game.height - 20, 20, rl.Color.red);
    const waterLevelPercentage: f32 = game.flower.getWaterLevelPercentage() * 100;
    var waterLevelColor: rl.Color = rl.Color.white;
    if (waterLevelPercentage >= 50) {
        waterLevelColor = rl.Color.gray;
    } else if (waterLevelPercentage >= 10) {
        waterLevelColor = rl.Color.ray_white;
    }
    rl.drawText(rl.textFormat("->: %03u", .{game.windArrayAmount}), game.width - 100, 50, 20, waterLevelColor);
    rl.drawText(rl.textFormat("S2: %03.0f%%", .{game.flower.health}), game.width - 100, 10, 20, waterLevelColor);
    rl.drawText(rl.textFormat("(o): %03.0f%%", .{waterLevelPercentage}), game.width - 100, 30, 20, waterLevelColor);
    // Optionally, draw FPS counter for debugging
    rl.drawFPS(10, 10);
    rl.endDrawing(); // Ensure drawing is ended

    if (rl.isKeyDown(rl.KeyboardKey.escape) or rl.windowShouldClose()) {
        game.isPlaying = false;
    }
    return game.isPlaying;
}
