const std = @import("std");

const render = @import("../render.zig");

const Color = [4]f32;

const theme = struct {
    const black: Color = .{ 0.000, 0.000, 0.000, 1.0 };
    const panel: Color = .{ 0.020, 0.020, 0.020, 1.0 };
    const raised: Color = .{ 0.067, 0.067, 0.067, 1.0 };
    const hover: Color = .{ 0.090, 0.090, 0.090, 1.0 };
    const selected: Color = .{ 0.142, 0.142, 0.142, 1.0 };
    const border: Color = .{ 0.071, 0.071, 0.071, 1.0 };
    const border_strong: Color = .{ 0.142, 0.142, 0.142, 1.0 };
    const bright: Color = .{ 0.730, 0.730, 0.730, 1.0 };
    const muted: Color = .{ 0.373, 0.373, 0.373, 1.0 };
    const dim: Color = .{ 0.200, 0.200, 0.200, 1.0 };
    const cursor: Color = .{ 1.000, 1.000, 1.000, 1.0 };
};

pub fn buildScene(storage: *render.SceneStorage, drawable_size: [2]f32) render.SceneBuildError!render.Scene {
    var builder = render.SceneBuilder.begin(storage, drawable_size, .{ 0.0, 0.0, 0.0, 1.0 });

    const width = drawable_size[0];
    const height = drawable_size[1];
    if (width <= 0 or height <= 0) return builder.finish();

    const clip = try builder.pushDrawableClip();
    try builder.beginBatch(clip);

    const title_h: f32 = if (height < 560.0) 30.0 else 34.0;
    const status_h: f32 = 24.0;
    const tab_h: f32 = 38.0;
    const rail_w: f32 = if (width < 760.0) 40.0 else 46.0;
    const project_w: f32 = @min(@max(width * 0.19, 190.0), 282.0);
    const shell_h = @max(height - status_h, 1.0);
    const side_x = rail_w;
    const editor_x = rail_w + project_w;
    const editor_w = @max(width - editor_x, 1.0);
    const editor_y = title_h + tab_h;
    const editor_h = @max(shell_h - editor_y, 1.0);

    try quad(&builder, clip, rect(0, 0, width, title_h), theme.black);
    try quad(&builder, clip, rect(0, title_h, rail_w, shell_h - title_h), theme.panel);
    try quad(&builder, clip, rect(side_x, title_h, project_w, shell_h - title_h), theme.panel);
    try quad(&builder, clip, rect(editor_x, title_h, editor_w, shell_h - title_h), theme.black);
    try quad(&builder, clip, rect(0, shell_h, width, status_h), theme.black);

    try hline(&builder, clip, title_h, width, theme.border);
    try vline(&builder, clip, rail_w, title_h, shell_h - title_h, theme.border);
    try vline(&builder, clip, editor_x, title_h, shell_h - title_h, theme.border);
    try hline(&builder, clip, shell_h, width, theme.border_strong);

    try titleBar(&builder, clip, width, title_h);
    try projectPanel(&builder, clip, side_x, title_h, project_w, shell_h - title_h);
    try editorTabs(&builder, clip, editor_x, title_h, editor_w, tab_h);
    try editorBody(&builder, clip, editor_x, editor_y, editor_w, editor_h);
    try statusBar(&builder, clip, width, shell_h, status_h);

    return builder.finish();
}

fn titleBar(builder: *render.SceneBuilder, clip: u32, width: f32, title_h: f32) render.SceneBuildError!void {
    _ = width;
    const y = title_h * 0.5 - 4.0;
    try quad(builder, clip, rect(14, y, 8, 8), theme.dim);
    try quad(builder, clip, rect(30, y, 8, 8), theme.dim);
    try quad(builder, clip, rect(46, y, 8, 8), theme.dim);
    try quad(builder, clip, rect(86, y + 1.0, 86, 6), theme.muted);
    try quad(builder, clip, rect(178, y + 1.0, 32, 6), theme.dim);
}

fn projectPanel(builder: *render.SceneBuilder, clip: u32, x: f32, y: f32, width: f32, height: f32) render.SceneBuildError!void {
    const header_h: f32 = 38.0;
    try quad(builder, clip, rect(x, y, width, header_h), theme.panel);
    try hlineAt(builder, clip, x, y + header_h, width, theme.border);
    try bar(builder, clip, x + 16, y + 15, 76, 6, theme.bright);
    try bar(builder, clip, x + width - 48, y + 15, 18, 6, theme.muted);
    try bar(builder, clip, x + width - 24, y + 15, 8, 6, theme.dim);

    const row_y = y + header_h + 12.0;
    const row_h: f32 = 23.0;
    try treeRow(builder, clip, x, row_y + row_h * 0.0, width, 0, 68, false);
    try treeRow(builder, clip, x, row_y + row_h * 1.0, width, 1, 94, false);
    try treeRow(builder, clip, x, row_y + row_h * 2.0, width, 1, 72, false);
    try treeRow(builder, clip, x, row_y + row_h * 3.0, width, 1, 116, true);
    try treeRow(builder, clip, x, row_y + row_h * 4.0, width, 2, 78, false);
    try treeRow(builder, clip, x, row_y + row_h * 5.0, width, 2, 136, false);
    try treeRow(builder, clip, x, row_y + row_h * 6.0, width, 1, 88, false);
    try treeRow(builder, clip, x, row_y + row_h * 7.0, width, 1, 104, false);

    try vlineAt(builder, clip, x + 30, row_y + row_h * 1.0, row_h * 5.0, theme.border);
    try vlineAt(builder, clip, x + 46, row_y + row_h * 4.0, row_h * 2.0, theme.border);

    const bottom = y + height - 74.0;
    try hlineAt(builder, clip, x, bottom, width, theme.border);
    try bar(builder, clip, x + 16, bottom + 18.0, width * 0.38, 6, theme.muted);
    try bar(builder, clip, x + 16, bottom + 42.0, width * 0.52, 6, theme.dim);
}

fn treeRow(
    builder: *render.SceneBuilder,
    clip: u32,
    panel_x: f32,
    y: f32,
    panel_w: f32,
    depth: u32,
    label_w: f32,
    active: bool,
) render.SceneBuildError!void {
    if (active) {
        try quad(builder, clip, rect(panel_x + 8, y - 2.0, panel_w - 16.0, 20.0), theme.selected);
    }
    const x = panel_x + 16.0 + @as(f32, @floatFromInt(depth)) * 16.0;
    try quad(builder, clip, rect(x, y + 5.0, 7.0, 7.0), if (active) theme.bright else theme.muted);
    try bar(builder, clip, x + 16.0, y + 6.0, @min(label_w, panel_w - (x - panel_x) - 28.0), 5.0, if (active) theme.bright else theme.muted);
}

fn editorTabs(builder: *render.SceneBuilder, clip: u32, x: f32, y: f32, width: f32, height: f32) render.SceneBuildError!void {
    try quad(builder, clip, rect(x, y, width, height), theme.black);
    try hlineAt(builder, clip, x, y + height, width, theme.border);

    const active_w: f32 = @min(@max(width * 0.18, 124.0), 184.0);
    const tab_w: f32 = @min(@max(width * 0.14, 104.0), 160.0);
    try quad(builder, clip, rect(x, y, active_w, height), theme.raised);
    try hlineAt(builder, clip, x, y + height - 1.0, active_w, theme.cursor);
    try bar(builder, clip, x + 18, y + 16, active_w - 54, 6, theme.bright);
    try bar(builder, clip, x + active_w - 24, y + 16, 8, 6, theme.muted);

    const tab2_x = x + active_w;
    try quad(builder, clip, rect(tab2_x, y, tab_w, height), theme.black);
    try vlineAt(builder, clip, tab2_x, y + 9.0, height - 18.0, theme.border);
    try bar(builder, clip, tab2_x + 18, y + 16, tab_w - 42, 5, theme.muted);

    const tab3_x = tab2_x + tab_w;
    try quad(builder, clip, rect(tab3_x, y, tab_w, height), theme.black);
    try vlineAt(builder, clip, tab3_x, y + 9.0, height - 18.0, theme.border);
    try bar(builder, clip, tab3_x + 18, y + 16, tab_w - 58, 5, theme.dim);
}

fn editorBody(builder: *render.SceneBuilder, clip: u32, x: f32, y: f32, width: f32, height: f32) render.SceneBuildError!void {
    const gutter_w: f32 = if (width < 640.0) 48.0 else 62.0;
    const code_x = x + gutter_w;
    const line_h: f32 = 24.0;
    const top_pad: f32 = 20.0;

    try quad(builder, clip, rect(x, y, gutter_w, height), theme.black);
    try vlineAt(builder, clip, code_x, y, height, theme.border);
    try quad(builder, clip, rect(code_x, y + top_pad + line_h * 5.0, @max(width - gutter_w, 1.0), line_h), theme.hover);
    try quad(builder, clip, rect(code_x + 92.0, y + top_pad + line_h * 5.0 + 4.0, @min(220.0, width * 0.34), line_h - 8.0), theme.selected);
    try quad(builder, clip, rect(code_x + 326.0, y + top_pad + line_h * 5.0 + 3.0, 2.0, line_h - 6.0), theme.cursor);

    try vlineAt(builder, clip, code_x + 34.0, y + top_pad, @min(height - top_pad, line_h * 13.0), theme.border);
    try vlineAt(builder, clip, code_x + 68.0, y + top_pad, @min(height - top_pad, line_h * 13.0), theme.border);
    try vlineAt(builder, clip, code_x + 102.0, y + top_pad, @min(height - top_pad, line_h * 13.0), theme.border);

    var row: u32 = 0;
    while (row < 14) : (row += 1) {
        const row_y = y + top_pad + @as(f32, @floatFromInt(row)) * line_h;
        try bar(builder, clip, x + 24.0, row_y + 8.0, if (row < 9) 8.0 else 14.0, 5.0, if (row == 5) theme.bright else theme.dim);
    }

    try codeRow(builder, clip, code_x + 22.0, y + top_pad + line_h * 0.0, .{ 70, 42, 126, 0 });
    try codeRow(builder, clip, code_x + 56.0, y + top_pad + line_h * 1.0, .{ 54, 138, 46, 0 });
    try codeRow(builder, clip, code_x + 56.0, y + top_pad + line_h * 2.0, .{ 92, 34, 168, 0 });
    try codeRow(builder, clip, code_x + 90.0, y + top_pad + line_h * 3.0, .{ 118, 66, 42, 0 });
    try codeRow(builder, clip, code_x + 56.0, y + top_pad + line_h * 4.0, .{ 44, 78, 214, 0 });
    try codeRow(builder, clip, code_x + 90.0, y + top_pad + line_h * 5.0, .{ 74, 186, 38, 0 });
    try codeRow(builder, clip, code_x + 90.0, y + top_pad + line_h * 6.0, .{ 156, 52, 96, 0 });
    try codeRow(builder, clip, code_x + 56.0, y + top_pad + line_h * 7.0, .{ 64, 120, 72, 0 });
    try codeRow(builder, clip, code_x + 22.0, y + top_pad + line_h * 8.0, .{ 96, 44, 156, 0 });
    try codeRow(builder, clip, code_x + 56.0, y + top_pad + line_h * 9.0, .{ 132, 80, 0, 0 });
    try codeRow(builder, clip, code_x + 90.0, y + top_pad + line_h * 10.0, .{ 58, 92, 164, 0 });
    try codeRow(builder, clip, code_x + 90.0, y + top_pad + line_h * 11.0, .{ 210, 44, 0, 0 });
}

fn codeRow(builder: *render.SceneBuilder, clip: u32, x: f32, y: f32, widths: [4]f32) render.SceneBuildError!void {
    var cursor = x;
    for (widths) |w| {
        if (w <= 0) continue;
        try bar(builder, clip, cursor, y + 8.0, w, 5.0, theme.muted);
        cursor += w + 10.0;
    }
}

fn statusBar(builder: *render.SceneBuilder, clip: u32, width: f32, y: f32, height: f32) render.SceneBuildError!void {
    try quad(builder, clip, rect(0, y, width, height), theme.black);
    try bar(builder, clip, 14.0, y + 9.0, 34.0, 5.0, theme.bright);
    try bar(builder, clip, 62.0, y + 9.0, 62.0, 5.0, theme.muted);
    try bar(builder, clip, width * 0.50, y + 9.0, 48.0, 5.0, theme.dim);
    try bar(builder, clip, width - 180.0, y + 9.0, 54.0, 5.0, theme.muted);
    try bar(builder, clip, width - 92.0, y + 9.0, 70.0, 5.0, theme.dim);
}

fn rect(x: f32, y: f32, width: f32, height: f32) render.Rect {
    return .{ .x = x, .y = y, .width = width, .height = height };
}

fn quad(builder: *render.SceneBuilder, clip: u32, r: render.Rect, color: Color) render.SceneBuildError!void {
    if (r.width <= 0 or r.height <= 0) return;
    try builder.pushQuad(r, color, clip);
}

fn bar(builder: *render.SceneBuilder, clip: u32, x: f32, y: f32, width: f32, height: f32, color: Color) render.SceneBuildError!void {
    try quad(builder, clip, rect(x, y, width, height), color);
}

fn hline(builder: *render.SceneBuilder, clip: u32, y: f32, width: f32, color: Color) render.SceneBuildError!void {
    try quad(builder, clip, rect(0, y, width, 1.0), color);
}

fn hlineAt(builder: *render.SceneBuilder, clip: u32, x: f32, y: f32, width: f32, color: Color) render.SceneBuildError!void {
    try quad(builder, clip, rect(x, y, width, 1.0), color);
}

fn vline(builder: *render.SceneBuilder, clip: u32, x: f32, y: f32, height: f32, color: Color) render.SceneBuildError!void {
    try quad(builder, clip, rect(x, y, 1.0, height), color);
}

fn vlineAt(builder: *render.SceneBuilder, clip: u32, x: f32, y: f32, height: f32, color: Color) render.SceneBuildError!void {
    try quad(builder, clip, rect(x, y, 1.0, height), color);
}

test "workspace shell stays inside the fixed scene storage" {
    var storage: render.SceneStorage = undefined;
    const scene = try buildScene(&storage, .{ 1440.0, 900.0 });

    try std.testing.expect(scene.quads.len <= render.max_quads);
    try std.testing.expectEqual(@as(usize, 1), scene.batches.len);
    try std.testing.expectEqual(@as(usize, 1), scene.clips.len);
}
