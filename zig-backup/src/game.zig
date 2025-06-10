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
            self.frameTimer = 0;
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
    isAlive: bool = true,
    fn setTexture(self: *Flower, texture: rl.Texture2D) void {
        self.animator.setTexture(texture);
    }
    fn update(self: *Flower, delta: f32) void {
        if (!self.isAlive) return;
        if (self.waterLevel != 0.0) {
            self.waterLevel = self.waterLevel - (self.waterDrainSpeed * delta);
        }
        if (self.waterLevel < 0.0) {
            self.waterLevel = 0.0;
        }
        self.animate(delta);
    }
    fn animate(self: *Flower, delta: f32) void {
        if (!self.isAlive) return;
        self.animator.animate(delta);
    }
    fn getWaterLevelPercentage(self: *Flower) f32 {
        if (!self.isAlive) return 0;
        return self.waterLevel / self.maxWaterLevel;
    }
    fn takeDamage(self: *Flower, damage: f32) void {
        if (!self.isAlive) return;
        self.health -= damage;
        if (self.health <= 0) {
            self.isAlive = false;
            self.health = 0;
        }
    }
    fn takeWater(self: *Flower, water: f32) void {
        if (!self.isAlive) return;
        self.waterLevel += water;
        if (self.waterLevel > self.maxWaterLevel) {
            takeDamage(self, 10);
            self.waterLevel = self.maxWaterLevel;
        } else {
            self.health += 1;
        }
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
    position: rl.Vector2 = std.mem.zeroes(rl.Vector2),
};

const WaterParticles = struct {
    amount: f32 = 0,
    position: rl.Vector2 = std.mem.zeroes(rl.Vector2),
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
    startLine: rl.Vector2 = std.mem.zeroes(rl.Vector2),
    endLine: rl.Vector2 = std.mem.zeroes(rl.Vector2),
    lineDuration: f32 = 0,
    currentLine: [2]rl.Vector2 = std.mem.zeroes([2]rl.Vector2),
    sourceRec: rl.Rectangle = std.mem.zeroes(rl.Rectangle),
    windArray: [MAX_WIND_PARTICLES]WindParticles = std.mem.zeroes([MAX_WIND_PARTICLES]WindParticles),
    waterArray: [MAX_WATER_PARTICLES]WaterParticles = std.mem.zeroes([MAX_WATER_PARTICLES]WaterParticles),
    windArrayAmount: usize = 0,
    waterArrayAmount: usize = 0,
    windParticleCD: f32 = 1,
    waterParticleCD: f32 = 1,
    isPlaying: bool = false,
    isSunUp: bool = false,
    isDraging: bool = false,
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
    game.isSunUp = true;

    game.target = rl.loadRenderTexture(nativeWidth, nativeHeight) catch |err| switch (err) {
        rl.RaylibError.LoadRenderTexture => {
            std.debug.print("LoadRenderTexture ERROR", .{});
            return false;
        },
        else => {
            std.debug.print("ERROR", .{});
            return false;
        },
    };
    game.sun.setTexture(rl.Texture.init("resources/sun-0001.png") catch |err| switch (err) {
        rl.RaylibError.LoadTexture => {
            std.debug.print("LoadTexture ERROR", .{});
            return false;
        },
        else => {
            std.debug.print("ERROR", .{});
            return false;
        },
    });
    game.cloud.setTexture(rl.Texture.init("resources/cloud-0001.png") catch |err| switch (err) {
        rl.RaylibError.LoadTexture => {
            std.debug.print("LoadTexture ERROR", .{});
            return false;
        },
        else => {
            std.debug.print("ERROR", .{});
            return false;
        },
    });
    game.flower.setTexture(rl.Texture.init("resources/flower-0001.png") catch |err| switch (err) {
        rl.RaylibError.LoadTexture => {
            std.debug.print("LoadTexture ERROR", .{});
            return false;
        },
        else => {
            std.debug.print("ERROR", .{});
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
    game.virtualRatio = @as(f32, @floatFromInt(game.height)) / @as(f32, @floatFromInt(nativeHeight));
    rl.setMouseScale(1 / game.virtualRatio, 1 / game.virtualRatio);
}
pub var game: Game = .{};
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

    const points = rl.getTouchPointCount();
    if (points > 1 or game.isDraging) {
        if (!game.isDraging) {
            game.isDraging = true;
            game.startLine = rl.Vector2.scale(rl.getMousePosition(), 1 / game.virtualRatio);
            game.endLine = std.mem.zeroes(rl.Vector2);
            game.lineDuration = 40;
            rl.traceLog(rl.TraceLogLevel.info, "Start touch %f - %f", .{ game.startLine.x, game.startLine.y });
        }
        if (points == 0) {
            game.endLine = rl.Vector2.scale(rl.getMousePosition(), 1 / game.virtualRatio);
            rl.traceLog(rl.TraceLogLevel.info, "End touch", .{});
            game.isDraging = false;
        }
    } else {
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            game.startLine = rl.getMousePosition();
            game.endLine = std.mem.zeroes(rl.Vector2);
            game.lineDuration = 40;
            rl.traceLog(rl.TraceLogLevel.info, "Start %03.0f - %03.0f", .{ game.startLine.x, game.startLine.y });
        }
        if (rl.isMouseButtonReleased(rl.MouseButton.left)) {
            game.endLine = rl.getMousePosition();
            rl.traceLog(rl.TraceLogLevel.info, "End", .{});
        }
    }

    if (game.lineDuration > 0) {
        if (game.endLine.x == 0 and game.endLine.y == 0) {
            game.currentLine[0] = game.startLine;
            game.currentLine[1] = rl.getMousePosition();
        } else {
            game.lineDuration -= delta;
            game.currentLine[0] = game.startLine;
            game.currentLine[1] = game.endLine;
        }
    }

    // Clear the native resolution buffer with a background color from our palette
    rl.clearBackground(rl.Color.dark_gray);

    if (game.isSunUp) {
        game.windParticleCD -= delta;
        var i: usize = 0;
        while (i < game.windArrayAmount) {
            var value = &game.windArray[i];
            value.position.x += value.power * delta;
            if (value.position.x > nativeWidth - 85) {
                game.flower.takeDamage(value.power);
                game.windArray[i] = game.windArray[game.windArrayAmount - 1];
                game.windArrayAmount -= 1;
            } else if (game.lineDuration > 0 and rl.checkCollisionPointLine(value.position, game.currentLine[0], game.currentLine[1], 1)) {
                game.windArray[i] = game.windArray[game.windArrayAmount - 1];
                game.windArrayAmount -= 1;
            } else {
                rl.drawPixelV(value.position, rl.Color.ray_white);
                i += 1;
            }
        }
        if (game.windParticleCD < 0) {
            game.windParticleCD = 1;
            if (game.windArrayAmount < MAX_WIND_PARTICLES) {
                game.windArray[game.windArrayAmount].power = 10 + rand.float(f32) * 10;
                game.windArray[game.windArrayAmount].position.y = nativeHeight - 30 + rand.float(f32) * 20;
                game.windArray[game.windArrayAmount].position.x = 1;
                game.windArrayAmount += 1;
            }
        }
        game.sun.animator.texture.drawRec(game.sun.animator.frameRec, .{ .x = 0, .y = 0 }, .white); // Draw part of the texture
    } else {
        var i: usize = 0;
        while (i < game.waterArrayAmount) {
            var value = &game.waterArray[i];
            value.position.y += value.amount * delta;
            if (value.position.x > nativeWidth - 85) {
                game.flower.takeWater(value.amount);
                game.waterArray[i] = game.waterArray[game.waterArrayAmount - 1];
                game.waterArrayAmount -= 1;
            } else if (game.lineDuration > 0 and rl.checkCollisionPointLine(value.position, game.currentLine[0], game.currentLine[1], 1)) {
                game.waterArray[i] = game.waterArray[game.waterArrayAmount - 1];
                game.waterArrayAmount -= 1;
            } else {
                rl.drawPixelV(value.position, rl.Color.ray_white);
                i += 1;
            }
        }
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
        game.cloud.animator.texture.drawRec(game.cloud.animator.frameRec, .{ .x = 40, .y = 0 }, .white); // Draw part of the texture
    }
    game.flower.animator.texture.drawRec(game.flower.animator.frameRec, .{ .x = 60, .y = nativeHeight - 64 }, .white); // Draw part of the texture

    if (game.lineDuration > 0) {
        game.lineDuration -= delta;
        rl.drawLineEx(game.currentLine[0], game.currentLine[1], 5, rl.Color.light_gray);
    }

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
    rl.drawText(rl.textFormat("S2: %03.0f%%", .{game.flower.health}), game.width - 100, 10, 20, waterLevelColor);
    rl.drawText(rl.textFormat("(o): %03.0f%%", .{waterLevelPercentage}), game.width - 100, 30, 20, waterLevelColor);
    rl.drawText(rl.textFormat("->: %03u", .{game.windArrayAmount}), game.width - 100, 50, 20, waterLevelColor);
    if (points != 0) {
        var i: i32 = 0;
        while (i < 7) {
            rl.drawText(rl.textFormat("%i TouchX->: %03.0f TouchY->: %03.0f", .{ i, rl.getTouchPosition(i).x, rl.getTouchPosition(i).y }), 10, 50 + (i * 20), 20, .red);
            i += 1;
        }
        const mousePosition = rl.Vector2.scale(rl.getMousePosition(), 1 / game.virtualRatio);
        rl.drawText(rl.textFormat("%i MouseX->: %03.0f MouseY->: %03.0f", .{ i, mousePosition.x, mousePosition.y }), 10, 50 + (i * 20), 20, .red);
    }
    // Optionally, draw FPS counter for debugging
    rl.drawFPS(10, 10);
    rl.endDrawing(); // Ensure drawing is ended
    if (rl.isKeyDown(rl.KeyboardKey.escape) or rl.windowShouldClose()) {
        game.isPlaying = false;
    }
    return game.isPlaying;
}
