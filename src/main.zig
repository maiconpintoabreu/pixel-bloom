const rl = @import("raylib");
const gameLogic = @import("game.zig");

pub fn main() anyerror!void {
    rl.traceLog(rl.TraceLogLevel.info, "Initializing Game!", .{});
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60);
    rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true });

    try gameLogic.startGame();
    defer gameLogic.closeGame();

    while (gameLogic.updateFrame()) {}
}
