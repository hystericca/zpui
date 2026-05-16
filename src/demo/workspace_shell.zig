const std = @import("std");

const frame = @import("../frame.zig");
const render = @import("../render.zig");
const ui = @import("../ui.zig");

const hit = ui.hit;
const layout = ui.layout;
const style = ui.style;

const theme = struct {
    const black = style.Color.rgba(0.000, 0.000, 0.000, 1.0);
    const panel = style.Color.rgba(0.020, 0.020, 0.020, 1.0);
    const raised = style.Color.rgba(0.067, 0.067, 0.067, 1.0);
    const hover = style.Color.rgba(0.090, 0.090, 0.090, 1.0);
    const selected = style.Color.rgba(0.142, 0.142, 0.142, 1.0);
    const border = style.Color.rgba(0.071, 0.071, 0.071, 1.0);
    const border_strong = style.Color.rgba(0.142, 0.142, 0.142, 1.0);
    const bright = style.Color.rgba(0.730, 0.730, 0.730, 1.0);
    const muted = style.Color.rgba(0.373, 0.373, 0.373, 1.0);
    const dim = style.Color.rgba(0.200, 0.200, 0.200, 1.0);
    const cursor = style.Color.rgba(1.000, 1.000, 1.000, 1.0);
};

const hit_id = struct {
    const title: hit.HitId = 1;
    const rail: hit.HitId = 2;
    const project: hit.HitId = 3;
    const editor_body: hit.HitId = 4;
    const editor_tabs: hit.HitId = 5;
    const status: hit.HitId = 6;
    const project_active_row: hit.HitId = 20;
    const editor_active_tab: hit.HitId = 21;
    const editor_active_line: hit.HitId = 22;
};

const TreeRow = struct {
    depth: u32,
    label_w: f32,
    active: bool,
};

pub fn buildScene(f: *frame.Frame) frame.Error!render.Scene {
    const width = f.size[0];
    const height = f.size[1];
    if (width <= 0 or height <= 0) return f.finish();

    const clip = try f.pushDrawableClip();
    try f.beginBatch(clip);

    const title_h: f32 = if (height < 560.0) 30.0 else 34.0;
    const status_h: f32 = 24.0;
    const tab_h: f32 = 38.0;
    const rail_w: f32 = if (width < 760.0) 40.0 else 46.0;
    const project_w: f32 = @min(@max(width * 0.19, 190.0), 282.0);
    const shell_h = @max(height - status_h, 1.0);

    const status_split = try f.splitEdge(.{
        .bounds = rect(0.0, 0.0, width, shell_h + status_h),
        .edge = .bottom,
        .size = status_h,
    });
    const title_split = try f.splitEdge(.{
        .bounds = status_split.tail,
        .edge = .top,
        .size = title_h,
    });
    const rail_split = try f.splitEdge(.{
        .bounds = title_split.tail,
        .edge = .left,
        .size = rail_w,
    });
    const project_split = try f.splitEdge(.{
        .bounds = rail_split.tail,
        .edge = .left,
        .size = project_w,
    });
    const tab_split = try f.splitEdge(.{
        .bounds = project_split.tail,
        .edge = .top,
        .size = tab_h,
    });

    try addHit(f, hit_id.title, title_split.head);
    try addHit(f, hit_id.rail, rail_split.head);
    try addHit(f, hit_id.project, project_split.head);
    try addHit(f, hit_id.editor_body, tab_split.tail);
    try addHit(f, hit_id.editor_tabs, tab_split.head);
    try addHit(f, hit_id.status, status_split.head);

    try quad(f, clip, title_split.head, theme.black);
    try quad(f, clip, rail_split.head, theme.panel);
    try quad(f, clip, project_split.head, theme.panel);
    try quad(f, clip, project_split.tail, theme.black);
    try quad(f, clip, status_split.head, theme.black);

    try hline(f, clip, title_split.head.y + title_split.head.height, width, theme.border);
    try vline(f, clip, rail_split.head.x + rail_split.head.width, rail_split.head.y, rail_split.head.height, theme.border);
    try vline(f, clip, project_split.head.x + project_split.head.width, project_split.head.y, project_split.head.height, theme.border);
    try hline(f, clip, status_split.head.y, width, theme.border_strong);

    try titleBar(f, clip, title_split.head);
    try projectPanel(f, clip, project_split.head);
    try editorTabs(f, clip, tab_split.head);
    try editorBody(f, clip, tab_split.tail);
    try statusBar(f, clip, status_split.head);

    _ = f.resolveHot();
    return f.finish();
}

fn titleBar(f: *frame.Frame, clip: u32, bounds: layout.Rect) frame.Error!void {
    const y = bounds.y + bounds.height * 0.5 - 4.0;
    const items = [_]layout.LayoutItem{
        fixed(8.0, 8.0),
        fixed(8.0, 8.0),
        fixed(8.0, 8.0),
    };
    const controls = try f.pack(.{
        .bounds = rect(bounds.x + 14.0, y, 40.0, 8.0),
        .gap = 8.0,
    }, items[0..]);

    for (controls) |control| {
        try quad(f, clip, control.rect, theme.dim);
    }
    try quad(f, clip, rect(bounds.x + 86.0, y + 1.0, 86.0, 6.0), theme.muted);
    try quad(f, clip, rect(bounds.x + 178.0, y + 1.0, 32.0, 6.0), theme.dim);
}

fn projectPanel(f: *frame.Frame, clip: u32, bounds: layout.Rect) frame.Error!void {
    const header_h: f32 = 38.0;
    const header = rect(bounds.x, bounds.y, bounds.width, header_h);
    try quad(f, clip, header, theme.panel);
    try hlineAt(f, clip, bounds.x, bounds.y + header_h, bounds.width, theme.border);
    try bar(f, clip, bounds.x + 16.0, bounds.y + 15.0, 76.0, 6.0, theme.bright);
    try bar(f, clip, bounds.x + bounds.width - 48.0, bounds.y + 15.0, 18.0, 6.0, theme.muted);
    try bar(f, clip, bounds.x + bounds.width - 24.0, bounds.y + 15.0, 8.0, 6.0, theme.dim);

    const rows = [_]TreeRow{
        .{ .depth = 0, .label_w = 68.0, .active = false },
        .{ .depth = 1, .label_w = 94.0, .active = false },
        .{ .depth = 1, .label_w = 72.0, .active = false },
        .{ .depth = 1, .label_w = 116.0, .active = true },
        .{ .depth = 2, .label_w = 78.0, .active = false },
        .{ .depth = 2, .label_w = 136.0, .active = false },
        .{ .depth = 1, .label_w = 88.0, .active = false },
        .{ .depth = 1, .label_w = 104.0, .active = false },
    };
    const row_y = bounds.y + header_h + 12.0;
    const row_h: f32 = 23.0;
    var row_items: [rows.len]layout.LayoutItem = undefined;
    for (&row_items) |*item| item.* = fixed(bounds.width, row_h);

    const row_layout = try f.pack(.{
        .bounds = rect(bounds.x, row_y, bounds.width, row_h * @as(f32, @floatFromInt(rows.len))),
        .axis = .vertical,
    }, row_items[0..]);
    for (rows, row_layout) |row, result| {
        try treeRow(f, clip, bounds.x, result.rect.y, bounds.width, row);
    }

    try vlineAt(f, clip, bounds.x + 30.0, row_y + row_h * 1.0, row_h * 5.0, theme.border);
    try vlineAt(f, clip, bounds.x + 46.0, row_y + row_h * 4.0, row_h * 2.0, theme.border);

    const bottom = bounds.y + bounds.height - 74.0;
    try hlineAt(f, clip, bounds.x, bottom, bounds.width, theme.border);
    try bar(f, clip, bounds.x + 16.0, bottom + 18.0, bounds.width * 0.38, 6.0, theme.muted);
    try bar(f, clip, bounds.x + 16.0, bottom + 42.0, bounds.width * 0.52, 6.0, theme.dim);
}

fn treeRow(
    f: *frame.Frame,
    clip: u32,
    panel_x: f32,
    y: f32,
    panel_w: f32,
    row: TreeRow,
) frame.Error!void {
    const active_rect = rect(panel_x + 8.0, y - 2.0, panel_w - 16.0, 20.0);
    if (row.active) {
        try addHit(f, hit_id.project_active_row, active_rect);
        try quad(f, clip, active_rect, theme.selected);
    }

    const x = panel_x + 16.0 + @as(f32, @floatFromInt(row.depth)) * 16.0;
    try quad(f, clip, rect(x, y + 5.0, 7.0, 7.0), if (row.active) theme.bright else theme.muted);
    try bar(
        f,
        clip,
        x + 16.0,
        y + 6.0,
        @min(row.label_w, panel_w - (x - panel_x) - 28.0),
        5.0,
        if (row.active) theme.bright else theme.muted,
    );
}

fn editorTabs(f: *frame.Frame, clip: u32, bounds: layout.Rect) frame.Error!void {
    try quad(f, clip, bounds, theme.black);
    try hlineAt(f, clip, bounds.x, bounds.y + bounds.height, bounds.width, theme.border);

    const active_w: f32 = @min(@max(bounds.width * 0.18, 124.0), 184.0);
    const tab_w: f32 = @min(@max(bounds.width * 0.14, 104.0), 160.0);
    const items = [_]layout.LayoutItem{
        fixed(active_w, bounds.height),
        fixed(tab_w, bounds.height),
        fixed(tab_w, bounds.height),
    };
    const tabs = try f.pack(.{ .bounds = bounds }, items[0..]);
    const active = tabs[0].rect;
    const tab2 = tabs[1].rect;
    const tab3 = tabs[2].rect;

    try addHit(f, hit_id.editor_active_tab, active);
    try quad(f, clip, active, theme.raised);
    try hlineAt(f, clip, active.x, active.y + active.height - 1.0, active.width, theme.cursor);
    try bar(f, clip, active.x + 18.0, active.y + 16.0, active.width - 54.0, 6.0, theme.bright);
    try bar(f, clip, active.x + active.width - 24.0, active.y + 16.0, 8.0, 6.0, theme.muted);

    try quad(f, clip, tab2, theme.black);
    try vlineAt(f, clip, tab2.x, tab2.y + 9.0, tab2.height - 18.0, theme.border);
    try bar(f, clip, tab2.x + 18.0, tab2.y + 16.0, tab2.width - 42.0, 5.0, theme.muted);

    try quad(f, clip, tab3, theme.black);
    try vlineAt(f, clip, tab3.x, tab3.y + 9.0, tab3.height - 18.0, theme.border);
    try bar(f, clip, tab3.x + 18.0, tab3.y + 16.0, tab3.width - 58.0, 5.0, theme.dim);
}

fn editorBody(f: *frame.Frame, clip: u32, bounds: layout.Rect) frame.Error!void {
    const gutter_w: f32 = if (bounds.width < 640.0) 48.0 else 62.0;
    const code_x = bounds.x + gutter_w;
    const line_h: f32 = 24.0;
    const top_pad: f32 = 20.0;

    try quad(f, clip, rect(bounds.x, bounds.y, gutter_w, bounds.height), theme.black);
    try vlineAt(f, clip, code_x, bounds.y, bounds.height, theme.border);

    const active_line = rect(code_x, bounds.y + top_pad + line_h * 5.0, @max(bounds.width - gutter_w, 1.0), line_h);
    try addHit(f, hit_id.editor_active_line, active_line);
    try quad(f, clip, active_line, theme.hover);
    try quad(f, clip, rect(code_x + 92.0, active_line.y + 4.0, @min(220.0, bounds.width * 0.34), line_h - 8.0), theme.selected);
    try quad(f, clip, rect(code_x + 326.0, active_line.y + 3.0, 2.0, line_h - 6.0), theme.cursor);

    try vlineAt(f, clip, code_x + 34.0, bounds.y + top_pad, @min(bounds.height - top_pad, line_h * 13.0), theme.border);
    try vlineAt(f, clip, code_x + 68.0, bounds.y + top_pad, @min(bounds.height - top_pad, line_h * 13.0), theme.border);
    try vlineAt(f, clip, code_x + 102.0, bounds.y + top_pad, @min(bounds.height - top_pad, line_h * 13.0), theme.border);

    var line_items: [14]layout.LayoutItem = undefined;
    for (&line_items) |*item| item.* = fixed(1.0, line_h);
    const lines = try f.pack(.{
        .bounds = rect(bounds.x, bounds.y + top_pad, 1.0, line_h * @as(f32, @floatFromInt(line_items.len))),
        .axis = .vertical,
    }, line_items[0..]);
    for (lines, 0..) |line, row| {
        try bar(
            f,
            clip,
            bounds.x + 24.0,
            line.rect.y + 8.0,
            if (row < 9) 8.0 else 14.0,
            5.0,
            if (row == 5) theme.bright else theme.dim,
        );
    }

    try codeRow(f, clip, code_x + 22.0, bounds.y + top_pad + line_h * 0.0, .{ 70.0, 42.0, 126.0, 0.0 });
    try codeRow(f, clip, code_x + 56.0, bounds.y + top_pad + line_h * 1.0, .{ 54.0, 138.0, 46.0, 0.0 });
    try codeRow(f, clip, code_x + 56.0, bounds.y + top_pad + line_h * 2.0, .{ 92.0, 34.0, 168.0, 0.0 });
    try codeRow(f, clip, code_x + 90.0, bounds.y + top_pad + line_h * 3.0, .{ 118.0, 66.0, 42.0, 0.0 });
    try codeRow(f, clip, code_x + 56.0, bounds.y + top_pad + line_h * 4.0, .{ 44.0, 78.0, 214.0, 0.0 });
    try codeRow(f, clip, code_x + 90.0, bounds.y + top_pad + line_h * 5.0, .{ 74.0, 186.0, 38.0, 0.0 });
    try codeRow(f, clip, code_x + 90.0, bounds.y + top_pad + line_h * 6.0, .{ 156.0, 52.0, 96.0, 0.0 });
    try codeRow(f, clip, code_x + 56.0, bounds.y + top_pad + line_h * 7.0, .{ 64.0, 120.0, 72.0, 0.0 });
    try codeRow(f, clip, code_x + 22.0, bounds.y + top_pad + line_h * 8.0, .{ 96.0, 44.0, 156.0, 0.0 });
    try codeRow(f, clip, code_x + 56.0, bounds.y + top_pad + line_h * 9.0, .{ 132.0, 80.0, 0.0, 0.0 });
    try codeRow(f, clip, code_x + 90.0, bounds.y + top_pad + line_h * 10.0, .{ 58.0, 92.0, 164.0, 0.0 });
    try codeRow(f, clip, code_x + 90.0, bounds.y + top_pad + line_h * 11.0, .{ 210.0, 44.0, 0.0, 0.0 });
}

fn codeRow(f: *frame.Frame, clip: u32, x: f32, y: f32, widths: [4]f32) frame.Error!void {
    var items: [widths.len]layout.LayoutItem = undefined;
    var content_w: f32 = 0.0;
    var visible_count: u32 = 0;
    for (widths, &items) |width, *item| {
        item.* = .{
            .size = layout.Size.init(@max(width, 0.0), 5.0),
            .flags = if (width > 0.0) layout.default_flags else 0,
        };
        if (width > 0.0) {
            if (visible_count != 0) content_w += 10.0;
            content_w += width;
            visible_count += 1;
        }
    }

    const segments = try f.pack(.{
        .bounds = rect(x, y + 8.0, content_w, 5.0),
        .gap = 10.0,
    }, items[0..]);
    for (widths, segments) |width, segment| {
        if (width <= 0.0) continue;
        try bar(f, clip, segment.rect.x, segment.rect.y, segment.rect.width, segment.rect.height, theme.muted);
    }
}

fn statusBar(f: *frame.Frame, clip: u32, bounds: layout.Rect) frame.Error!void {
    try quad(f, clip, bounds, theme.black);
    try bar(f, clip, bounds.x + 14.0, bounds.y + 9.0, 34.0, 5.0, theme.bright);
    try bar(f, clip, bounds.x + 62.0, bounds.y + 9.0, 62.0, 5.0, theme.muted);
    try bar(f, clip, bounds.x + bounds.width * 0.50, bounds.y + 9.0, 48.0, 5.0, theme.dim);
    try bar(f, clip, bounds.x + bounds.width - 180.0, bounds.y + 9.0, 54.0, 5.0, theme.muted);
    try bar(f, clip, bounds.x + bounds.width - 92.0, bounds.y + 9.0, 70.0, 5.0, theme.dim);
}

fn fixed(width: f32, height: f32) layout.LayoutItem {
    return layout.LayoutItem.fixed(layout.Size.init(width, height));
}

fn rect(x: f32, y: f32, width: f32, height: f32) layout.Rect {
    return layout.Rect.init(x, y, width, height);
}

fn quad(f: *frame.Frame, clip: u32, bounds: layout.Rect, color: style.Color) frame.Error!void {
    if (bounds.width <= 0.0 or bounds.height <= 0.0) return;
    try f.pushFill(bounds, color, clip);
}

fn bar(f: *frame.Frame, clip: u32, x: f32, y: f32, width: f32, height: f32, color: style.Color) frame.Error!void {
    try quad(f, clip, rect(x, y, width, height), color);
}

fn hline(f: *frame.Frame, clip: u32, y: f32, width: f32, color: style.Color) frame.Error!void {
    try quad(f, clip, rect(0.0, y, width, 1.0), color);
}

fn hlineAt(f: *frame.Frame, clip: u32, x: f32, y: f32, width: f32, color: style.Color) frame.Error!void {
    try quad(f, clip, rect(x, y, width, 1.0), color);
}

fn vline(f: *frame.Frame, clip: u32, x: f32, y: f32, height: f32, color: style.Color) frame.Error!void {
    try quad(f, clip, rect(x, y, 1.0, height), color);
}

fn vlineAt(f: *frame.Frame, clip: u32, x: f32, y: f32, height: f32, color: style.Color) frame.Error!void {
    try quad(f, clip, rect(x, y, 1.0, height), color);
}

fn addHit(f: *frame.Frame, id: hit.HitId, bounds: layout.Rect) frame.Error!void {
    if (bounds.width <= 0.0 or bounds.height <= 0.0) return;
    try f.pushHit(hit.HitItem.init(id, bounds));
}

test "workspace shell stays inside the fixed frame storage" {
    var storage: frame.Storage = .{};
    var f = frame.Frame.begin(&storage, .{ .size = .{ 1440.0, 900.0 } });
    const scene = try buildScene(&f);

    try std.testing.expect(scene.quads.len <= render.max_quads);
    try std.testing.expect(f.hitItems().len <= render.max_quads);
    try std.testing.expect(f.hitItems().len > 0);
    try std.testing.expectEqual(hit.none, f.hitState().hot);
    try std.testing.expectEqual(@as(usize, 1), scene.batches.len);
    try std.testing.expectEqual(@as(usize, 1), scene.clips.len);
}

test "workspace shell resolves hot area from frame input" {
    var storage: frame.Storage = .{};
    var f = frame.Frame.begin(&storage, .{
        .size = .{ 1440.0, 900.0 },
        .input = .{ .cursor = .{ 420.0, 80.0 } },
    });

    _ = try buildScene(&f);

    try std.testing.expectEqual(hit_id.editor_body, f.hitState().hot);
}
