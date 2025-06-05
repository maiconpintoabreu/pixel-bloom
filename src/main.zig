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
            if (self.currentFrame > self.frames) self.currentFrame = 0;
            if (self.random) {
                const frame = rand.intRangeAtMost(i8, 0, self.frames);
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

const MAX_WIND_PARTICLES = 200;
const MAX_WATER_PARTICLES = 200;

const nativeWidth = 160; // e.g., 160x90 for a 16:9 aspect ratio
const nativeHeight = 90;

pub fn main() anyerror!void {
    // Actual screen dimensions for the window
    var screenWidth: i32 = 800;
    var screenHeight: i32 = 450;

    var virtualRatio: f32 = @as(f32, @floatFromInt(screenWidth)) / @as(f32, @floatFromInt(nativeWidth));

    rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true });

    // Initialize the Raylib window
    rl.initWindow(screenWidth, screenHeight, "Pixel Bloom");
    defer rl.closeWindow(); // Ensure the window is closed when main exits

    // Initialize
    var flower: Flower = .{};
    var sun: Sun = .{};
    var cloud: Cloud = .{};

    // Set target FPS for consistent game speed
    rl.setTargetFPS(60);

    const target = try rl.loadRenderTexture(nativeWidth, nativeHeight);
    defer rl.unloadRenderTexture(target); // Ensure the render texture is unloaded

    const sunTexture = try rl.Texture.init("resources/sun-0001.png"); // Texture loading
    defer rl.unloadTexture(sunTexture); // Texture unloading

    const cloudTexture = try rl.Texture.init("resources/cloud-0001.png"); // Texture loading
    defer rl.unloadTexture(cloudTexture); // Texture unloading

    const flowerTexture = try rl.Texture.init("resources/flower-0001.png"); // Texture loading
    defer rl.unloadTexture(flowerTexture); // Texture unloading

    var isSunUp: bool = true;

    sun.setTexture(sunTexture);
    cloud.setTexture(cloudTexture);
    flower.setTexture(flowerTexture);

    // Init Particles
    var windArray: [MAX_WIND_PARTICLES]WindParticles = std.mem.zeroes([MAX_WIND_PARTICLES]WindParticles);
    var waterArray: [MAX_WATER_PARTICLES]WaterParticles = std.mem.zeroes([MAX_WATER_PARTICLES]WaterParticles);
    var windArrayAmount: usize = 0;
    var waterArrayAmount: usize = 0;
    var windParticleCD: f32 = 1;
    var waterParticleCD: f32 = 1;

    // Main game loop
    while (!rl.windowShouldClose()) {
        // input

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            isSunUp = !isSunUp;
            flower.animator.currentFrame = 0;
            cloud.animator.currentFrame = 0;
            sun.animator.currentFrame = 0;
            windArrayAmount = 0;
            waterArrayAmount = 0;
            windParticleCD = 1;
            waterParticleCD = 1;
        }

        if (rl.isWindowResized()) {
            screenWidth = rl.getScreenWidth();
            screenHeight = rl.getScreenHeight();

            virtualRatio = @as(f32, @floatFromInt(screenWidth)) / @as(f32, @floatFromInt(nativeWidth));
        }
        const delta = rl.getFrameTime();
        if (isSunUp) {
            sun.update(delta);
        } else {
            cloud.update(delta);
        }
        flower.update(delta);

        rl.beginTextureMode(target);

        // Clear the native resolution buffer with a background color from our palette
        rl.clearBackground(rl.Color.dark_gray);

        if (isSunUp) {
            windParticleCD -= delta;
            if (windParticleCD < 0) {
                windParticleCD = 1;
                if (windArrayAmount < MAX_WIND_PARTICLES) {
                    windArray[windArrayAmount].power = rand.float(f32) * 20;
                    windArray[windArrayAmount].position.y = nativeHeight - 50 + rand.float(f32) * 20;
                    windArray[windArrayAmount].position.x = 0;
                    windArrayAmount += 1;
                }
            }
            var i: usize = 0;
            while (i < windArrayAmount) {
                i += 1;
                var value = &windArray[i];
                value.position.x += value.power * delta;
                if (value.position.x > nativeWidth) {
                    windArray[i] = windArray[windArrayAmount];
                    windArrayAmount -= 1;
                    std.debug.print("index: {d}: amount: {d}\n", .{ i, windArrayAmount });
                }
                rl.drawPixelV(value.position, rl.Color.ray_white);
            }
            sun.animator.texture.drawRec(sun.animator.frameRec, .{ .x = 0, .y = 0 }, .white); // Draw part of the texture
        } else {
            waterParticleCD -= delta;
            if (waterParticleCD < 0) {
                waterParticleCD = 1;
                if (waterArrayAmount < MAX_WATER_PARTICLES) {
                    waterArrayAmount += 1;
                }
                waterArray[waterArrayAmount - 1].amount = rand.float(f32) * 10;
                waterArray[waterArrayAmount - 1].position.y = 0;
                waterArray[waterArrayAmount - 1].position.x = 60 + rand.float(f32) * 20;
            }
            var i: usize = 0;
            while (i < waterArrayAmount) {
                i += 1;
                var value = &waterArray[i];
                value.position.y += value.amount * delta;
                if (value.position.y > nativeHeight) {
                    waterArray[i] = waterArray[waterArrayAmount];
                    waterArrayAmount -= 1;
                    std.debug.print("index: {d}: amount: {d}\n", .{ i, waterArrayAmount });
                }
                rl.drawPixelV(value.position, rl.Color.ray_white);
            }
            cloud.animator.texture.drawRec(cloud.animator.frameRec, .{ .x = 40, .y = 0 }, .white); // Draw part of the texture
        }
        flower.animator.texture.drawRec(flower.animator.frameRec, .{ .x = 60, .y = nativeHeight - 64 }, .white); // Draw part of the texture

        rl.endTextureMode(); // Ensure texture mode is ended

        rl.beginDrawing();
        defer rl.endDrawing(); // Ensure drawing is ended

        rl.clearBackground(rl.Color.black);
        const sourceRec = rl.Rectangle{
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(target.texture.width),
            .height = @floatFromInt(-target.texture.height),
        };

        // Define the destination rectangle on the screen (the entire screen)
        const destRec = rl.Rectangle{
            .x = -virtualRatio,
            .y = -virtualRatio,
            .width = @as(f32, @floatFromInt(screenWidth)) + (virtualRatio * 2),
            .height = @as(f32, @floatFromInt(screenHeight)) + (virtualRatio * 2),
        };

        // Draw the render texture to the screen, scaled up, with nearest-neighbor filtering
        rl.drawTexturePro(target.texture, // The texture to draw
            sourceRec, // Part of the texture to draw (entire texture)
            destRec, // Where on the screen to draw it
            rl.Vector2{ .x = 0.0, .y = 0.0 }, // Origin for rotation (top-left)
            0.0, // Rotation angle
            rl.Color.white // Tint color (use WHITE to draw as is)
        );
        // const fps = rl.getFPS();
        // rl.drawText(rl.textFormat("FPS: %03i", .{fps}), screenWidth - 100, screenHeight - 20, 20, rl.Color.red);
        const waterLevelPercentage: f32 = flower.getWaterLevelPercentage() * 100;
        var waterLevelColor: rl.Color = rl.Color.white;
        if (waterLevelPercentage >= 50) {
            waterLevelColor = rl.Color.gray;
        } else if (waterLevelPercentage >= 10) {
            waterLevelColor = rl.Color.ray_white;
        }
        rl.drawText(rl.textFormat("->: %03u", .{windArrayAmount}), screenWidth - 100, 50, 20, waterLevelColor);
        rl.drawText(rl.textFormat("S2: %03.0f%%", .{flower.health}), screenWidth - 100, 10, 20, waterLevelColor);
        rl.drawText(rl.textFormat("(o): %03.0f%%", .{waterLevelPercentage}), screenWidth - 100, 30, 20, waterLevelColor);
        // Optionally, draw FPS counter for debugging
        rl.drawFPS(10, 10);
    }
}
