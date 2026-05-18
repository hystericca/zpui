const zpui = @import("zpui-app");

pub fn main() !void {
    try zpui.initWindow(.{
        .title = "ZPUI Visual Primitives",
        .chrome = zpui.WindowChrome.customTitlebar(.{ 14.0, 11.0 }),
        .draw = draw,
    });
}

fn draw(ctx: *zpui.DrawContext) zpui.DrawError!void {
    const font = ctx.defaultFont();

    var frame = ctx.beginFrame(.{
        .clear_color = .{ 0.055, 0.058, 0.063, 1.0 },
    });
    const root = frame.root();
    const clip = try frame.clip(root);
    const width = @max(root.width, 1.0);
    const height = @max(root.height, 1.0);

    var background = frame.draw(.{ .clip = clip, .layer = zpui.scene.layer_background });
    try background.fill(root, zpui.ui.style.Color.rgb(0.055, 0.058, 0.063));

    var panel = frame.draw(.{ .clip = clip, .layer = zpui.scene.layer_surface });
    try panel.rect(zpui.ui.layout.Rect.init(18.0, 18.0, @max(width - 36.0, 1.0), 34.0), .{
        .fill = zpui.ui.style.Color.rgba(0.082, 0.086, 0.094, 0.96),
        .border = zpui.ui.style.Border.solid(1.0, zpui.ui.style.Color.rgba(0.22, 0.24, 0.27, 0.75)),
    });

    try panel.rect(zpui.ui.layout.Rect.init(18.0, 52.0, 238.0, @max(height - 76.0, 1.0)), .{
        .fill = zpui.ui.style.Color.rgba(0.072, 0.076, 0.084, 0.94),
        .border = zpui.ui.style.Border.solid(1.0, zpui.ui.style.Color.rgba(0.18, 0.20, 0.23, 0.8)),
    });

    var content = frame.draw(.{ .clip = clip, .layer = zpui.scene.layer_content });
    try content.rect(zpui.ui.layout.Rect.init(256.0, 52.0, @max(width - 274.0, 1.0), @max(height - 76.0, 1.0)), .{
        .fill = zpui.ui.style.Color.rgba(0.062, 0.066, 0.073, 0.98),
        .border = zpui.ui.style.Border.solid(1.0, zpui.ui.style.Color.rgba(0.16, 0.18, 0.21, 0.8)),
    });

    const tab_rect = zpui.ui.layout.Rect.init(270.0, 58.0, 132.0, 28.0);
    try panel.rect(tab_rect, .{
        .fill = zpui.ui.style.Color.rgba(0.11, 0.12, 0.14, 0.95),
        .radius = zpui.ui.style.Radius.all(5.0),
        .border = zpui.ui.style.Border.solid(1.0, zpui.ui.style.Color.rgba(0.28, 0.31, 0.36, 0.9)),
    });

    try content.rect(zpui.ui.layout.Rect.init(270.0, 126.0, @max(width - 300.0, 1.0), 20.0), .{
        .fill = zpui.ui.style.Color.rgba(0.16, 0.27, 0.44, 0.45),
        .radius = zpui.ui.style.Radius.all(3.0),
    });

    var text_storage: zpui.TextLineStorage = .{};
    const path_runs = [_]zpui.text.TextRun{
        .{ .bytes = "src/", .font = font, .size = 15.0, .color = zpui.ui.style.Color.rgb(0.50, 0.55, 0.62) },
        .{ .bytes = "main.zig", .font = font, .size = 15.0, .color = zpui.ui.style.Color.rgb(0.82, 0.86, 0.92) },
    };
    const project_row = zpui.ui.layout.Rect.init(52.0, 76.0, 168.0, 28.0);
    const path_line = try ctx.shapeLine(&text_storage, path_runs[0..]);
    try content.textLine(zpui.ui.layout.Point.init(74.0, project_row.y + @max(0.0, project_row.height - path_line.line_height) * 0.5), path_line);

    const tab_runs = [_]zpui.text.TextRun{
        .{ .bytes = "main", .font = font, .size = 15.0, .color = zpui.ui.style.Color.rgb(0.86, 0.89, 0.94) },
        .{ .bytes = ".zig", .font = font, .size = 15.0, .color = zpui.ui.style.Color.rgb(0.52, 0.58, 0.67) },
    };
    const tab_line = try ctx.shapeLine(&text_storage, tab_runs[0..]);
    try content.textLine(zpui.ui.layout.Point.init(292.0, tab_rect.y + @max(0.0, tab_rect.height - tab_line.line_height) * 0.5), tab_line);

    const code_line = try ctx.shapeLine(&text_storage, &.{
        .{ .bytes = "const frame = ctx.beginFrame(.{});", .font = font, .size = 15.0, .color = zpui.ui.style.Color.rgb(0.88, 0.90, 0.92) },
    });
    try content.textLine(zpui.ui.layout.Point.init(292.0, 112.0), code_line);
    const api_line = try ctx.shapeLine(&text_storage, &.{
        .{ .bytes = "try d.textLine(...);", .font = font, .size = 15.0, .color = zpui.ui.style.Color.rgb(0.70, 0.78, 0.90) },
    });
    try content.textLine(zpui.ui.layout.Point.init(292.0, 134.0), api_line);
    const accent_line = try ctx.shapeLine(&text_storage, &.{
        .{ .bytes = "15pt text, accents: caf\u{e9}, ligature: ffi", .font = font, .size = 15.0, .color = zpui.ui.style.Color.rgb(0.50, 0.55, 0.62) },
    });
    try content.textLine(zpui.ui.layout.Point.init(292.0, 178.0), accent_line);

    var foreground = frame.draw(.{ .clip = clip, .layer = zpui.scene.layer_foreground });
    try foreground.fill(zpui.ui.layout.Rect.init(289.0, 132.0, 2.0, 18.0), zpui.ui.style.Color.rgb(0.52, 0.76, 1.0));

    const scene = try frame.finish();
    try ctx.drawScene(&scene);
}
