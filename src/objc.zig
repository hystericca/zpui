const std = @import("std");

pub const Object = opaque {};
pub const Selector = opaque {};

pub const Id = *Object;
pub const Class = *Object;
pub const Sel = *Selector;
pub const Imp = *const anyopaque;
pub const ObjCBool = c_char;
pub const BOOL = ObjCBool;
pub const CGFloat = f64;
pub const CGSize = extern struct {
    width: CGFloat,
    height: CGFloat,
};
pub const NSSize = CGSize;
pub const NSUInteger = usize;
pub const NSInteger = isize;
pub const CAAutoresizingMask = c_uint;

extern fn objc_getClass(name: [*:0]const u8) ?Class;
extern fn objc_allocateClassPair(superclass: ?Class, name: [*:0]const u8, extra_bytes: usize) ?Class;
extern fn objc_registerClassPair(cls: Class) void;
extern fn sel_registerName(name: [*:0]const u8) ?Sel;
extern fn class_addMethod(cls: Class, name: Sel, imp: Imp, types: [*:0]const u8) ObjCBool;

const MsgId0 = *const fn (?Id, Sel) callconv(.c) ?Id;
const MsgVoid0 = *const fn (?Id, Sel) callconv(.c) void;
const MsgInt0 = *const fn (?Id, Sel) callconv(.c) c_int;
const MsgBool0 = *const fn (?Id, Sel) callconv(.c) BOOL;
const MsgSize0 = *const fn (?Id, Sel) callconv(.c) CGSize;
const MsgU64_0 = *const fn (?Id, Sel) callconv(.c) u64;
const MsgPtr0 = *const fn (?Id, Sel) callconv(.c) ?*anyopaque;
const MsgVoidId1 = *const fn (?Id, Sel, ?Id) callconv(.c) void;
const MsgVoidBool1 = *const fn (?Id, Sel, BOOL) callconv(.c) void;
const MsgBoolISize1 = *const fn (?Id, Sel, isize) callconv(.c) BOOL;
const MsgBoolU64U64_2 = *const fn (?Id, Sel, u64, u64) callconv(.c) BOOL;
const MsgIdUSizeUSize2 = *const fn (?Id, Sel, usize, usize) callconv(.c) ?Id;
const MsgIdIdPtr2 = *const fn (?Id, Sel, ?Id, ?*anyopaque) callconv(.c) ?Id;
const MsgVoidU64USize2 = *const fn (?Id, Sel, u64, usize) callconv(.c) void;
const MsgVoidIdUSize2 = *const fn (?Id, Sel, ?Id, usize) callconv(.c) void;
const MsgVoidIdU64_2 = *const fn (?Id, Sel, ?Id, u64) callconv(.c) void;
const MsgVoidU64_1 = *const fn (?Id, Sel, u64) callconv(.c) void;
const MsgVoidUSize1 = *const fn (?Id, Sel, usize) callconv(.c) void;
const MsgVoidUInt1 = *const fn (?Id, Sel, c_uint) callconv(.c) void;
const MsgVoidF64_1 = *const fn (?Id, Sel, f64) callconv(.c) void;
const MsgVoidSize1 = *const fn (?Id, Sel, CGSize) callconv(.c) void;

const msg_id_0: MsgId0 = @extern(MsgId0, .{ .name = "objc_msgSend" });
const msg_void_0: MsgVoid0 = @extern(MsgVoid0, .{ .name = "objc_msgSend" });
const msg_int_0: MsgInt0 = @extern(MsgInt0, .{ .name = "objc_msgSend" });
const msg_bool_0: MsgBool0 = @extern(MsgBool0, .{ .name = "objc_msgSend" });
const msg_size_0: MsgSize0 = @extern(MsgSize0, .{ .name = "objc_msgSend" });
const msg_u64_0: MsgU64_0 = @extern(MsgU64_0, .{ .name = "objc_msgSend" });
const msg_ptr_0: MsgPtr0 = @extern(MsgPtr0, .{ .name = "objc_msgSend" });
const msg_void_id_1: MsgVoidId1 = @extern(MsgVoidId1, .{ .name = "objc_msgSend" });
const msg_void_bool_1: MsgVoidBool1 = @extern(MsgVoidBool1, .{ .name = "objc_msgSend" });
const msg_bool_isize_1: MsgBoolISize1 = @extern(MsgBoolISize1, .{ .name = "objc_msgSend" });
const msg_bool_u64_u64_2: MsgBoolU64U64_2 = @extern(MsgBoolU64U64_2, .{ .name = "objc_msgSend" });
const msg_id_usize_usize_2: MsgIdUSizeUSize2 = @extern(MsgIdUSizeUSize2, .{ .name = "objc_msgSend" });
const msg_id_id_ptr_2: MsgIdIdPtr2 = @extern(MsgIdIdPtr2, .{ .name = "objc_msgSend" });
const msg_void_u64_usize_2: MsgVoidU64USize2 = @extern(MsgVoidU64USize2, .{ .name = "objc_msgSend" });
const msg_void_id_usize_2: MsgVoidIdUSize2 = @extern(MsgVoidIdUSize2, .{ .name = "objc_msgSend" });
const msg_void_id_u64_2: MsgVoidIdU64_2 = @extern(MsgVoidIdU64_2, .{ .name = "objc_msgSend" });
const msg_void_u64_1: MsgVoidU64_1 = @extern(MsgVoidU64_1, .{ .name = "objc_msgSend" });
const msg_void_usize_1: MsgVoidUSize1 = @extern(MsgVoidUSize1, .{ .name = "objc_msgSend" });
const msg_void_uint_1: MsgVoidUInt1 = @extern(MsgVoidUInt1, .{ .name = "objc_msgSend" });
const msg_void_f64_1: MsgVoidF64_1 = @extern(MsgVoidF64_1, .{ .name = "objc_msgSend" });
const msg_void_size_1: MsgVoidSize1 = @extern(MsgVoidSize1, .{ .name = "objc_msgSend" });

pub fn toObjCBool(value: bool) BOOL {
    return if (value) 1 else 0;
}

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

pub fn sendBool0(receiver: ?Id, op: Sel) bool {
    return msg_bool_0(receiver, op) != 0;
}

pub fn sendSize0(receiver: ?Id, op: Sel) CGSize {
    return msg_size_0(receiver, op);
}

pub fn sendU64_0(receiver: ?Id, op: Sel) u64 {
    return msg_u64_0(receiver, op);
}

pub fn sendPtr0(receiver: ?Id, op: Sel) ?*anyopaque {
    return msg_ptr_0(receiver, op);
}

pub fn sendVoidId(receiver: ?Id, op: Sel, arg: ?Id) void {
    msg_void_id_1(receiver, op, arg);
}

pub fn sendBoolISize(receiver: ?Id, op: Sel, arg: isize) bool {
    return msg_bool_isize_1(receiver, op, arg) != 0;
}

pub fn sendBoolU64U64(receiver: ?Id, op: Sel, arg0: u64, arg1: u64) bool {
    return msg_bool_u64_u64_2(receiver, op, arg0, arg1) != 0;
}

pub fn sendIdUSizeUSize(receiver: ?Id, op: Sel, arg0: usize, arg1: usize) ?Id {
    return msg_id_usize_usize_2(receiver, op, arg0, arg1);
}

pub fn sendIdIdPtr(receiver: ?Id, op: Sel, arg0: ?Id, arg1: ?*anyopaque) ?Id {
    return msg_id_id_ptr_2(receiver, op, arg0, arg1);
}

pub fn sendVoidU64USize(receiver: ?Id, op: Sel, arg0: u64, arg1: usize) void {
    msg_void_u64_usize_2(receiver, op, arg0, arg1);
}

pub fn sendVoidIdUSize(receiver: ?Id, op: Sel, arg0: ?Id, arg1: usize) void {
    msg_void_id_usize_2(receiver, op, arg0, arg1);
}

pub fn sendVoidIdU64(receiver: ?Id, op: Sel, arg0: ?Id, arg1: u64) void {
    msg_void_id_u64_2(receiver, op, arg0, arg1);
}

pub fn sendVoidU64(receiver: ?Id, op: Sel, arg: u64) void {
    msg_void_u64_1(receiver, op, arg);
}

pub fn sendVoidBool(receiver: ?Id, op: Sel, arg: bool) void {
    msg_void_bool_1(receiver, op, toObjCBool(arg));
}

pub fn sendVoidUSize(receiver: ?Id, op: Sel, arg: usize) void {
    msg_void_usize_1(receiver, op, arg);
}

pub fn sendVoidUInt(receiver: ?Id, op: Sel, arg: c_uint) void {
    msg_void_uint_1(receiver, op, arg);
}

pub fn sendVoidF64(receiver: ?Id, op: Sel, arg: f64) void {
    msg_void_f64_1(receiver, op, arg);
}

pub fn sendVoidSize(receiver: ?Id, op: Sel, arg: CGSize) void {
    msg_void_size_1(receiver, op, arg);
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
