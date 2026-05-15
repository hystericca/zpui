const std = @import("std");
const zpui = @import("zpui");

pub fn main() !void {
    try zpui.runHelloWindow();
}

test "native entry point is available" {
    try std.testing.expect(@TypeOf(zpui.runHelloWindow) == fn () zpui.NativeError!void);
}
