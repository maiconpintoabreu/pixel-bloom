const rl = @import("raylib");
const std = @import("std");

const Flower = struct {
    waterDrainSpeed: f32 = 0.2,
    maxWaterLevel: f32 = 200,
    waterLevel: f32 = 120,
    fn update(self: *Flower, delta: f32) void {
        if (self.waterLevel != 0.0) {
            self.waterLevel = self.waterLevel - (self.waterDrainSpeed * delta);
        }
        if (self.waterLevel < 0.0) {
            self.waterLevel = 0.0;
        }
    }
    fn getWaterLevelPercentage(self: *Flower) f32 {
        return self.waterLevel / self.maxWaterLevel;
    }
};

pub fn main() anyerror!void {
    // Actual screen dimensions for the window
    var screenWidth: i32 = 800;
    var screenHeight: i32 = 450;

    const nativeWidth = 160; // e.g., 160x90 for a 16:9 aspect ratio
    const nativeHeight = 90;

    var virtualRatio: f32 = @as(f32, @floatFromInt(screenWidth)) / @as(f32, @floatFromInt(nativeWidth));

    // Initialize the Raylib window
    rl.initWindow(screenWidth, screenHeight, "Pixel Bloom");
    defer rl.closeWindow(); // Ensure the window is closed when main exits

    // Initialize Flower
    var flower: Flower = .{};
    const flowerSize: f32 = 10.0;

    // Set target FPS for consistent game speed
    rl.setTargetFPS(60);
    var currentFrame: u8 = 0;

    var framesCounter: u8 = 0;
    const framesSpeed: u8 = 8; // Number of spritesheet frames shown by second

    const target = try rl.loadRenderTexture(nativeWidth, nativeHeight);
    defer rl.unloadRenderTexture(target); // Ensure the render texture is unloaded

    const sunTexture = try rl.Texture.init("resources/sun-0001.png"); // Texture loading
    defer rl.unloadTexture(sunTexture); // Texture unloading

    const cloudTexture = try rl.Texture.init("resources/cloud-0001.png"); // Texture loading
    defer rl.unloadTexture(cloudTexture); // Texture unloading

    var isSunUp: bool = true;

    var climateFrameRec = rl.Rectangle.init(
        0,
        0,
        0,
        0,
    );
    if (currentFrame > 4) currentFrame = 0;
    climateFrameRec = rl.Rectangle.init(
        0,
        0,
        @as(f32, @floatFromInt(@divFloor(sunTexture.width, 5))),
        @as(f32, @floatFromInt(sunTexture.height)),
    );

    // Main game loop
    while (!rl.windowShouldClose()) {
        // input

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            isSunUp = !isSunUp;
            currentFrame = 0;
            framesCounter = 0;

            if (isSunUp) {
                if (currentFrame > 4) currentFrame = 0;
                climateFrameRec = rl.Rectangle.init(
                    0,
                    0,
                    @as(f32, @floatFromInt(@divFloor(sunTexture.width, 5))),
                    @as(f32, @floatFromInt(sunTexture.height)),
                );
            } else {
                if (currentFrame > 7) currentFrame = 0;
                climateFrameRec = rl.Rectangle.init(
                    0,
                    0,
                    @as(f32, @floatFromInt(@divFloor(cloudTexture.width, 8))),
                    @as(f32, @floatFromInt(cloudTexture.height)),
                );
            }
        }

        framesCounter += 1;
        if (rl.isWindowResized()) {
            screenWidth = rl.getScreenWidth();
            screenHeight = rl.getScreenHeight();

            virtualRatio = @as(f32, @floatFromInt(screenWidth)) / @as(f32, @floatFromInt(nativeWidth));
        }
        flower.update(rl.getFrameTime());

        rl.beginTextureMode(target);

        // Clear the native resolution buffer with a background color from our palette
        rl.clearBackground(rl.Color.dark_gray);

        // --- Draw a Sample Pixel Art Flower ---
        // Position the flower slightly to the left of the center flower
        const flowerBaseX = (@as(f32, nativeWidth) / 2.0) - (flowerSize / 2.0);
        const flowerBaseY = @as(f32, nativeHeight) - flowerSize; // Position it below the flower

        if (framesCounter >= (60 / framesSpeed)) {
            framesCounter = 0;
            currentFrame += 1;
            if (isSunUp) {
                climateFrameRec.x = @as(f32, @floatFromInt(currentFrame)) * @as(f32, @floatFromInt(@divFloor(sunTexture.width, 5)));
            } else {
                climateFrameRec.x = @as(f32, @floatFromInt(currentFrame)) * @as(f32, @floatFromInt(@divFloor(cloudTexture.width, 8)));
            }
        }
        if (isSunUp) {
            sunTexture.drawRec(climateFrameRec, .{ .x = 0, .y = 0 }, .white); // Draw part of the texture
        } else {
            cloudTexture.drawRec(climateFrameRec, .{ .x = 40, .y = 0 }, .white); // Draw part of the texture
        }

        // Stem (using DARK_GREY for a darker shade)
        rl.drawPixel(flowerBaseX, flowerBaseY, rl.Color.gray);
        rl.drawPixel(flowerBaseX, flowerBaseY - 1, rl.Color.gray);
        rl.drawPixel(flowerBaseX, flowerBaseY - 2, rl.Color.gray);

        // // Petals (using MEDIUM_GREY for the main petals)
        rl.drawPixel(flowerBaseX - 1, flowerBaseY - 3, rl.Color.gray); // Left petal
        rl.drawPixel(flowerBaseX + 1, flowerBaseY - 3, rl.Color.gray); // Right petal
        rl.drawPixel(flowerBaseX, flowerBaseY - 4, rl.Color.gray); // Top petal

        // Center of the flower (using WHITE for a highlight/bloom effect)
        rl.drawPixel(flowerBaseX, flowerBaseY - 3, rl.Color.ray_white);

        rl.endTextureMode(); // Ensure texture mode is ended
        rl.beginDrawing();
        defer rl.endDrawing(); // Ensure drawing is ended
        rl.clearBackground(rl.Color.black);
        const sourceRec = rl.Rectangle{
            .x = 0.0,
            .y = 0.0,
            // Negative height flips the texture vertically, as Raylib's texture origin is top-left
            // but RenderTextures are typically drawn bottom-up.
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
        rl.drawText(rl.textFormat("(o): %03.0f%%", .{waterLevelPercentage}), screenWidth - 100, 12, 20, waterLevelColor);
        // Optionally, draw FPS counter for debugging
        rl.drawFPS(10, 10);
    }
}
