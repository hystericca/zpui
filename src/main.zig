const zpui = @import("zpui-app");

pub fn main() !void {
    try zpui.initWindow(.{
        .title = "ZPUI Visual Primitives",
        .draw = draw,
    });
}

fn draw(ctx: *zpui.DrawContext) zpui.DrawError!void {
    try ctx.setFont(.{ .family = "Menlo", .size = 15.0 });

    var frame = ctx.beginFrame(.{
        .clear_color = .{ 0.055, 0.058, 0.063, 1.0 },
    });
    const clip = try frame.pushDrawableClip();
    const width = @max(frame.size[0], 1.0);
    const height = @max(frame.size[1], 1.0);

    try frame.beginLayerBatch(clip, zpui.scene.layer_background);
    try frame.pushFill(
        zpui.ui.layout.Rect.init(0.0, 0.0, width, height),
        zpui.ui.style.Color.rgb(0.055, 0.058, 0.063),
        clip,
    );
    try frame.endBatch();

    try frame.pushStyledRectLayer(
        zpui.ui.layout.Rect.init(18.0, 18.0, @max(width - 36.0, 1.0), 34.0),
        .{
            .fill = zpui.ui.style.Color.rgba(0.082, 0.086, 0.094, 0.96),
            .border = zpui.ui.style.Border.solid(1.0, zpui.ui.style.Color.rgba(0.22, 0.24, 0.27, 0.75)),
        },
        clip,
        zpui.scene.layer_surface,
    );

    try frame.pushStyledRectLayer(
        zpui.ui.layout.Rect.init(18.0, 52.0, 238.0, @max(height - 76.0, 1.0)),
        .{
            .fill = zpui.ui.style.Color.rgba(0.072, 0.076, 0.084, 0.94),
            .border = zpui.ui.style.Border.solid(1.0, zpui.ui.style.Color.rgba(0.18, 0.20, 0.23, 0.8)),
        },
        clip,
        zpui.scene.layer_surface,
    );

    try frame.pushStyledRectLayer(
        zpui.ui.layout.Rect.init(256.0, 52.0, @max(width - 274.0, 1.0), @max(height - 76.0, 1.0)),
        .{
            .fill = zpui.ui.style.Color.rgba(0.062, 0.066, 0.073, 0.98),
            .border = zpui.ui.style.Border.solid(1.0, zpui.ui.style.Color.rgba(0.16, 0.18, 0.21, 0.8)),
        },
        clip,
        zpui.scene.layer_content,
    );

    const tab_rect = zpui.ui.layout.Rect.init(270.0, 58.0, 132.0, 28.0);
    try frame.pushStyledRectLayer(
        tab_rect,
        .{
            .fill = zpui.ui.style.Color.rgba(0.11, 0.12, 0.14, 0.95),
            .radius = zpui.ui.style.Radius.all(5.0),
            .border = zpui.ui.style.Border.solid(1.0, zpui.ui.style.Color.rgba(0.28, 0.31, 0.36, 0.9)),
        },
        clip,
        zpui.scene.layer_surface,
    );

    try frame.pushStyledRectLayer(
        zpui.ui.layout.Rect.init(270.0, 126.0, @max(width - 300.0, 1.0), 20.0),
        .{
            .fill = zpui.ui.style.Color.rgba(0.16, 0.27, 0.44, 0.45),
            .radius = zpui.ui.style.Radius.all(3.0),
        },
        clip,
        zpui.scene.layer_content,
    );

    const path_runs = [_]zpui.text.TextRun{
        .{ .bytes = "src/", .color = zpui.ui.style.Color.rgb(0.50, 0.55, 0.62) },
        .{ .bytes = "main.zig", .color = zpui.ui.style.Color.rgb(0.82, 0.86, 0.92) },
    };
    const project_row = zpui.ui.layout.Rect.init(52.0, 76.0, 168.0, 28.0);
    const project_text = try frame.placeTextInRow(project_row);
    _ = try frame.pushTextRuns(zpui.ui.layout.Point.init(74.0, project_text.origin_y), path_runs[0..], clip, zpui.scene.layer_content);

    const tab_runs = [_]zpui.text.TextRun{
        .{ .bytes = "main", .color = zpui.ui.style.Color.rgb(0.86, 0.89, 0.94) },
        .{ .bytes = ".zig", .color = zpui.ui.style.Color.rgb(0.52, 0.58, 0.67) },
    };
    const tab_text = try frame.placeTextInRow(tab_rect);
    _ = try frame.pushTextRuns(zpui.ui.layout.Point.init(292.0, tab_text.origin_y), tab_runs[0..], clip, zpui.scene.layer_content);

    _ = try frame.pushText(
        zpui.ui.layout.Point.init(292.0, 112.0),
        "const frame = ctx.beginFrame(.{});",
        zpui.ui.style.Color.rgb(0.88, 0.90, 0.92),
        clip,
    );
    _ = try frame.pushText(
        zpui.ui.layout.Point.init(292.0, 134.0),
        "try frame.pushStyledRectLayer(...);",
        zpui.ui.style.Color.rgb(0.70, 0.78, 0.90),
        clip,
    );
    _ = try frame.pushText(
        zpui.ui.layout.Point.init(292.0, 178.0),
        "quads, text, app-owned masks",
        zpui.ui.style.Color.rgb(0.50, 0.55, 0.62),
        clip,
    );

    try frame.pushFillLayer(
        zpui.ui.layout.Rect.init(289.0, 132.0, 2.0, 18.0),
        zpui.ui.style.Color.rgb(0.52, 0.76, 1.0),
        clip,
        zpui.scene.layer_foreground,
    );

    const scene = try frame.finish();
    try ctx.drawScene(&scene);
}
