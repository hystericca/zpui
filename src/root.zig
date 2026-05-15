//! Thin public entry points for the native ZPUI smoke test.

pub const native = @import("native.zig");
pub const objc = @import("objc.zig");
pub const render = @import("render.zig");

pub const NativeError = native.NativeError;
pub const Frame = render.Frame;
pub const runHelloWindow = native.runHelloWindow;
pub const Vertex = render.Vertex;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
