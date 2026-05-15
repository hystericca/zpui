const std = @import("std");

pub const Object = opaque {};
pub const Selector = opaque {};

pub const Id = *Object;
pub const Class = *Object;
pub const Sel = *Selector;
pub const Imp = *const anyopaque;
pub const ObjCBool = c_char;

extern fn objc_getClass(name: [*:0]const u8) ?Class;
extern fn objc_allocateClassPair(superclass: ?Class, name: [*:0]const u8, extra_bytes: usize) ?Class;
extern fn objc_registerClassPair(cls: Class) void;
extern fn sel_registerName(name: [*:0]const u8) ?Sel;
extern fn class_addMethod(cls: Class, name: Sel, imp: Imp, types: [*:0]const u8) ObjCBool;

const MsgId0 = *const fn (?Id, Sel, ...) callconv(.c) ?Id;
const MsgVoid0 = *const fn (?Id, Sel, ...) callconv(.c) void;
const MsgInt0 = *const fn (?Id, Sel, ...) callconv(.c) c_int;

const msg_id_0: MsgId0 = @extern(MsgId0, .{ .name = "objc_msgSend" });
const msg_void_0: MsgVoid0 = @extern(MsgVoid0, .{ .name = "objc_msgSend" });
const msg_int_0: MsgInt0 = @extern(MsgInt0, .{ .name = "objc_msgSend" });

pub fn getClass(name: [*:0]const u8) ?Class {
    return objc_getClass(name);
}

pub fn allocateClass(superclass: ?Class, name: [*:0]const u8, extra_bytes: usize) ?Class {
    return objc_allocateClassPair(superclass, name, extra_bytes);
}

pub fn registerClass(cls: Class) void {
    objc_registerClassPair(cls);
}

pub fn selector(name: [*:0]const u8) ?Sel {
    return sel_registerName(name);
}

pub fn addMethod(cls: Class, name: Sel, imp: Imp, types: [*:0]const u8) bool {
    return class_addMethod(cls, name, imp, types) != 0;
}

pub fn sendId0(receiver: ?Id, op: Sel) ?Id {
    return msg_id_0(receiver, op);
}

pub fn sendVoid0(receiver: ?Id, op: Sel) void {
    msg_void_0(receiver, op);
}

pub fn sendInt0(receiver: ?Id, op: Sel) c_int {
    return msg_int_0(receiver, op);
}

fn testAnswer(_: ?Id, _: Sel) callconv(.c) c_int {
    return 42;
}

test "objc runtime can message Cocoa objects directly from Zig" {
    const ns_object = getClass("NSObject") orelse return error.MissingNSObject;
    const new_sel = selector("new") orelse return error.MissingSelector;
    const release_sel = selector("release") orelse return error.MissingSelector;

    const object = sendId0(ns_object, new_sel) orelse return error.MissingObject;
    defer sendVoid0(object, release_sel);

    try std.testing.expect(object != ns_object);
}

test "objc runtime can register a class backed by a Zig IMP" {
    const ns_object = getClass("NSObject") orelse return error.MissingNSObject;
    const class_name = "ZPUIObjCRuntimeSmokeTest";

    const cls = getClass(class_name) orelse blk: {
        const allocated = allocateClass(ns_object, class_name, 0) orelse return error.ClassAllocationFailed;
        const answer_sel = selector("zpuiAnswer") orelse return error.MissingSelector;
        try std.testing.expect(addMethod(allocated, answer_sel, @ptrCast(&testAnswer), "i@:"));
        registerClass(allocated);
        break :blk allocated;
    };

    const new_sel = selector("new") orelse return error.MissingSelector;
    const release_sel = selector("release") orelse return error.MissingSelector;
    const answer_sel = selector("zpuiAnswer") orelse return error.MissingSelector;

    const object = sendId0(cls, new_sel) orelse return error.MissingObject;
    defer sendVoid0(object, release_sel);

    try std.testing.expectEqual(@as(c_int, 42), sendInt0(object, answer_sel));
}
