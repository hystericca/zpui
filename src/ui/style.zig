const std = @import("std");

pub const Color = extern struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
    b: f32 = 0.0,
    a: f32 = 0.0,

    pub fn rgba(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn rgb(r: f32, g: f32, b: f32) Color {
        return rgba(r, g, b, 1.0);
    }
};

pub const Insets = extern struct {
    top: f32 = 0.0,
    right: f32 = 0.0,
    bottom: f32 = 0.0,
    left: f32 = 0.0,

    pub fn all(value: f32) Insets {
        return .{ .top = value, .right = value, .bottom = value, .left = value };
    }

    pub fn xy(x: f32, y: f32) Insets {
        return .{ .top = y, .right = x, .bottom = y, .left = x };
    }
};

pub const Radius = extern struct {
    top_left: f32 = 0.0,
    top_right: f32 = 0.0,
    bottom_right: f32 = 0.0,
    bottom_left: f32 = 0.0,

    pub fn all(value: f32) Radius {
        return .{
            .top_left = value,
            .top_right = value,
            .bottom_right = value,
            .bottom_left = value,
        };
    }
};

pub const Border = extern struct {
    width: f32 = 0.0,
    color: Color = .{},

    pub fn solid(width: f32, color: Color) Border {
        return .{ .width = width, .color = color };
    }
};

pub const Style = extern struct {
    fill: Color = .{},
    padding: Insets = .{},
    radius: Radius = .{},
    border: Border = .{},
    opacity: f32 = 1.0,
};

comptime {
    std.debug.assert(@sizeOf(Color) == 16);
    std.debug.assert(@sizeOf(Insets) == 16);
    std.debug.assert(@sizeOf(Radius) == 16);
    std.debug.assert(@sizeOf(Border) == 20);
    std.debug.assert(@sizeOf(Style) == 72);
}

test "style defaults are resolved zero data plus opaque opacity" {
    const style: Style = .{};

    try std.testing.expectEqual(Color{}, style.fill);
    try std.testing.expectEqual(Insets{}, style.padding);
    try std.testing.expectEqual(Radius{}, style.radius);
    try std.testing.expectEqual(Border{}, style.border);
    try std.testing.expectEqual(@as(f32, 1.0), style.opacity);
}

test "style constructors produce explicit scalar data" {
    const style: Style = .{
        .fill = Color.rgb(0.25, 0.5, 0.75),
        .padding = Insets.xy(8.0, 4.0),
        .radius = Radius.all(3.0),
        .border = Border.solid(2.0, Color.rgba(1.0, 0.0, 0.0, 0.5)),
        .opacity = 0.8,
    };

    try std.testing.expectEqual(Color.rgba(0.25, 0.5, 0.75, 1.0), style.fill);
    try std.testing.expectEqual(Insets{ .top = 4.0, .right = 8.0, .bottom = 4.0, .left = 8.0 }, style.padding);
    try std.testing.expectEqual(Radius{ .top_left = 3.0, .top_right = 3.0, .bottom_right = 3.0, .bottom_left = 3.0 }, style.radius);
    try std.testing.expectEqual(Border{ .width = 2.0, .color = Color.rgba(1.0, 0.0, 0.0, 0.5) }, style.border);
    try std.testing.expectEqual(@as(f32, 0.8), style.opacity);
}
