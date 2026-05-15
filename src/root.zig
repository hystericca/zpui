//! public entry points for the smoke test

pub const native = @import("native.zig");
pub const objc = @import("objc.zig");
pub const render = @import("render.zig");
pub const metal = @import("gpu/metal.zig");

pub const NativeError = native.NativeError;
pub const Frame = render.Frame;
pub const runHelloWindow = native.runHelloWindow;
pub const Vertex = render.Vertex;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
