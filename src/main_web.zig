const rl = @import("raylib");
const gameLogic = @import("game.zig");

const c = @cImport({
    @cInclude("emscripten/emscripten.h");
});

export fn main() callconv(.C) c_int {
    return safeMain() catch |err| {
        rl.traceLog(rl.TraceLogLevel.err, "ERROR: {s}", .{err});
        return 1;
    };
}

export fn emsc_set_window_size(width: c_int, height: c_int) callconv(.C) void {
    rl.setWindowSize(@intCast(width), @intCast(height));
}

fn safeMain() !c_int {
    if (gameLogic.startGame()) {
        defer rl.closeWindow();
        defer gameLogic.closeGame();

        c.emscripten_set_main_loop(updateFrame, 0, true);
        return 0;
    }
    return 1;
}

export fn updateFrame() callconv(.C) void {
    _ = gameLogic.updateFrame();
}
