const rl = @import("raylib");
const gameLogic = @import("game.zig");

const c = @cImport({
    @cInclude("emscripten/emscripten.h");
});

export fn main() callconv(.C) c_int {
    return safeMain() catch |err| {
        rl.traceLog(rl.TraceLogLevel.err, "ERROR: {?}", .{err});
        return 1;
    };
}

export fn emsc_set_window_size(width: c_int, height: c_int) callconv(.C) void {
    rl.setWindowSize(@intCast(width), @intCast(height));
}

fn safeMain() !c_int {
    try gameLogic.startGame();
    defer gameLogic.closeGame();
    defer rl.closeWindow();

    c.emscripten_set_main_loop(updateFrame, 0, true);
    return 0;
}

export fn updateFrame() callconv(.C) void {
    _ = gameLogic.updateFrame();
}
