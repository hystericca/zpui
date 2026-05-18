#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <mach-o/dyld.h>
#import <math.h>
#import <stdatomic.h>
#import <stddef.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

typedef struct ZPUISurface ZPUISurface;

enum {
    ZPUI_WINDOW_TITLED = 1u << 0,
    ZPUI_WINDOW_CLOSABLE = 1u << 1,
    ZPUI_WINDOW_MINIATURIZABLE = 1u << 2,
    ZPUI_WINDOW_RESIZABLE = 1u << 3,
    ZPUI_WINDOW_FULL_SIZE_CONTENT = 1u << 4,
    ZPUI_WINDOW_TITLEBAR_TRANSPARENT = 1u << 5,
    ZPUI_WINDOW_TITLE_VISIBLE = 1u << 6,
    ZPUI_WINDOW_MOVABLE = 1u << 7,
    ZPUI_WINDOW_MOVABLE_BY_BACKGROUND = 1u << 8,
    ZPUI_WINDOW_HAS_SHADOW = 1u << 9,
    ZPUI_WINDOW_TRAFFIC_LIGHT_POSITION = 1u << 10,
};

enum {
    ZPUI_WINDOW_BACKGROUND_OPAQUE = 0,
    ZPUI_WINDOW_BACKGROUND_TRANSPARENT = 1,
    ZPUI_WINDOW_BACKGROUND_BLURRED = 2,
};

enum {
    ZPUI_WINDOW_APPEARANCE_SYSTEM = 0,
    ZPUI_WINDOW_APPEARANCE_AQUA = 1,
    ZPUI_WINDOW_APPEARANCE_DARK_AQUA = 2,
    ZPUI_WINDOW_APPEARANCE_VIBRANT_LIGHT = 3,
    ZPUI_WINDOW_APPEARANCE_VIBRANT_DARK = 4,
};

enum {
    ZPUI_WINDOW_TOOLBAR_STYLE_AUTOMATIC = 0,
    ZPUI_WINDOW_TOOLBAR_STYLE_EXPANDED = 1,
    ZPUI_WINDOW_TOOLBAR_STYLE_PREFERENCE = 2,
    ZPUI_WINDOW_TOOLBAR_STYLE_UNIFIED = 3,
    ZPUI_WINDOW_TOOLBAR_STYLE_UNIFIED_COMPACT = 4,
};

enum {
    ZPUI_WINDOW_TITLEBAR_SEPARATOR_AUTOMATIC = 0,
    ZPUI_WINDOW_TITLEBAR_SEPARATOR_NONE = 1,
    ZPUI_WINDOW_TITLEBAR_SEPARATOR_LINE = 2,
    ZPUI_WINDOW_TITLEBAR_SEPARATOR_SHADOW = 3,
};

typedef struct {
    uint32_t flags;
    uint32_t background;
    uint32_t toolbar_style;
    uint32_t titlebar_separator_style;
    uint32_t appearance;
    uint32_t reserved;
    double traffic_light_x;
    double traffic_light_y;
} ZPUIWindowChrome;

_Static_assert(sizeof(ZPUIWindowChrome) == 40, "ZPUIWindowChrome ABI size mismatch");
_Static_assert(offsetof(ZPUIWindowChrome, flags) == 0, "ZPUIWindowChrome flags offset mismatch");
_Static_assert(offsetof(ZPUIWindowChrome, traffic_light_x) == 24,
               "ZPUIWindowChrome traffic_light_x offset mismatch");
_Static_assert(offsetof(ZPUIWindowChrome, traffic_light_y) == 32,
               "ZPUIWindowChrome traffic_light_y offset mismatch");

typedef struct {
    float size;
    float scale;
    float ascent;
    float descent;
    float leading;
    float line_height;
    uint32_t atlas_width;
    uint32_t atlas_height;
} ZPUITextFontMetrics;

typedef struct {
    uint32_t codepoint;
    uint32_t glyph_id;
    uint32_t atlas_x;
    uint32_t atlas_y;
    uint32_t atlas_width;
    uint32_t atlas_height;
    float offset_x;
    float offset_y;
    float advance;
    uint32_t flags;
} ZPUITextGlyphMetric;

typedef struct {
    uint32_t tag;
    float value;
} ZPUIFontVariation;

#define ZPUI_INPUT_MAX_KEY_EVENTS 64
#define ZPUI_INPUT_MAX_TEXT_EVENTS 64
#define ZPUI_INPUT_MAX_MOUSE_EVENTS 64
#define ZPUI_INPUT_MAX_SCROLL_EVENTS 32

enum {
    ZPUI_MOD_SHIFT = 1u << 0,
    ZPUI_MOD_CONTROL = 1u << 1,
    ZPUI_MOD_OPTION = 1u << 2,
    ZPUI_MOD_COMMAND = 1u << 3,
    ZPUI_MOD_CAPS_LOCK = 1u << 4,
};

enum {
    ZPUI_BUTTON_LEFT = 1u << 0,
    ZPUI_BUTTON_RIGHT = 1u << 1,
    ZPUI_BUTTON_OTHER = 1u << 2,
};

enum {
    ZPUI_KEY_DOWN = 1,
    ZPUI_KEY_UP = 2,
    ZPUI_KEY_MODIFIERS_CHANGED = 3,
};

enum {
    ZPUI_KEY_REPEAT = 1u << 0,
};

enum {
    ZPUI_MOUSE_MOVE = 1,
    ZPUI_MOUSE_DOWN = 2,
    ZPUI_MOUSE_UP = 3,
    ZPUI_MOUSE_DRAG = 4,
};

enum {
    ZPUI_WINDOW_FOCUSED = 1u << 0,
    ZPUI_WINDOW_BLURRED = 1u << 1,
    ZPUI_WINDOW_RESIZED = 1u << 2,
};

typedef struct {
    uint32_t kind;
    uint32_t key_code;
    uint32_t logical;
    uint32_t mods;
    uint32_t flags;
    double timestamp;
} ZPUIKeyEvent;

typedef struct {
    uint8_t bytes[8];
    uint32_t len;
    uint32_t mods;
    double timestamp;
} ZPUITextInputEvent;

typedef struct {
    uint32_t kind;
    uint32_t button;
    uint32_t click_count;
    uint32_t mods;
    float x;
    float y;
    double timestamp;
} ZPUIMouseEvent;

typedef struct {
    float dx;
    float dy;
    float precise_dx;
    float precise_dy;
    uint32_t mods;
    double timestamp;
} ZPUIScrollEvent;

typedef struct {
    uint32_t has_cursor;
    uint32_t buttons;
    uint32_t mods;
    uint32_t window;
    float cursor_x;
    float cursor_y;
    uint32_t key_count;
    uint32_t text_count;
    uint32_t mouse_count;
    uint32_t scroll_count;
    ZPUIKeyEvent keys[ZPUI_INPUT_MAX_KEY_EVENTS];
    ZPUITextInputEvent text[ZPUI_INPUT_MAX_TEXT_EVENTS];
    ZPUIMouseEvent mouse[ZPUI_INPUT_MAX_MOUSE_EVENTS];
    ZPUIScrollEvent scroll[ZPUI_INPUT_MAX_SCROLL_EVENTS];
} ZPUIRawInputSnapshot;

_Static_assert(sizeof(ZPUIRawInputSnapshot) == 6696, "ZPUIRawInputSnapshot ABI size mismatch");
_Static_assert(offsetof(ZPUIRawInputSnapshot, has_cursor) == 0,
               "ZPUIRawInputSnapshot has_cursor offset mismatch");
_Static_assert(offsetof(ZPUIRawInputSnapshot, cursor_x) == 16,
               "ZPUIRawInputSnapshot cursor_x offset mismatch");
_Static_assert(offsetof(ZPUIRawInputSnapshot, key_count) == 24,
               "ZPUIRawInputSnapshot key_count offset mismatch");
_Static_assert(offsetof(ZPUIRawInputSnapshot, keys) == 40,
               "ZPUIRawInputSnapshot keys offset mismatch");
_Static_assert(offsetof(ZPUIRawInputSnapshot, text) == 2088,
               "ZPUIRawInputSnapshot text offset mismatch");
_Static_assert(offsetof(ZPUIRawInputSnapshot, mouse) == 3624,
               "ZPUIRawInputSnapshot mouse offset mismatch");
_Static_assert(offsetof(ZPUIRawInputSnapshot, scroll) == 5672,
               "ZPUIRawInputSnapshot scroll offset mismatch");

enum {
    ZPUI_TEXT_GLYPH_PRESENT = 1u << 0,
    ZPUI_TEXT_GLYPH_VISIBLE = 1u << 1,
};

enum {
    ZPUI_FONT_STATUS_OK = 0,
    ZPUI_FONT_STATUS_FAILED = 1,
    ZPUI_FONT_STATUS_UNAVAILABLE = 2,
    ZPUI_FONT_STATUS_INVALID_VARIATION = 3,
};

extern int zpui_surface_create(id device, ZPUISurface **outSurface);
extern int zpui_surface_create_with_options(id device, unsigned int layerOpaque,
                                            ZPUISurface **outSurface);
extern void zpui_surface_destroy(ZPUISurface *surface);
extern CAMetalLayer *zpui_surface_layer(ZPUISurface *surface);
extern int zpui_surface_resize(ZPUISurface *surface, double width, double height, double scale);
extern int zpui_macos_draw_frame(ZPUISurface *surface, id<CAMetalDrawable> drawable);

static const char *zpui_platform_status_name(int status) {
    switch (status) {
    case 0:
        return "ok";
    case 10:
        return "invalid device";
    case 11:
        return "invalid surface";
    case 12:
        return "missing Objective-C class";
    case 13:
        return "missing Objective-C selector";
    case 14:
        return "layer allocation failed";
    case 15:
        return "retain failed";
    case 16:
        return "out of memory";
    case 17:
        return "command queue creation failed";
    case 18:
        return "unsupported device for ZPUI developer target";
    case 19:
        return "command allocator creation failed";
    case 20:
        return "command buffer creation failed";
    case 21:
        return "buffer creation failed";
    case 22:
        return "buffer contents unavailable";
    case 23:
        return "argument table descriptor creation failed";
    case 24:
        return "argument table creation failed";
    case 25:
        return "shared event creation failed";
    case 26:
        return "residency set descriptor creation failed";
    case 27:
        return "residency set creation failed";
    case 28:
        return "frame encoding failed";
    case 29:
        return "shader library creation failed";
    case 30:
        return "compiler descriptor creation failed";
    case 31:
        return "compiler creation failed";
    case 32:
        return "function descriptor creation failed";
    case 33:
        return "string creation failed";
    case 34:
        return "pipeline descriptor creation failed";
    case 35:
        return "pipeline creation failed";
    case 36:
        return "render pass descriptor creation failed";
    case 37:
        return "render attachment descriptor creation failed";
    case 38:
        return "render encoder creation failed";
    case 39:
        return "drawable texture unavailable";
    case 40:
        return "invalid drawable size";
    case 41:
        return "invalid scale";
    case 42:
        return "frame wait timed out";
    case 43:
        return "invalid clip rect";
    case 44:
        return "Objective-C object creation failed";
    case 45:
        return "system default Metal device unavailable";
    case 46:
        return "invalid drawable count";
    case 47:
        return "drawable unavailable";
    case 48:
        return "too many items";
    case 49:
        return "font atlas creation failed";
    case 50:
        return "texture descriptor creation failed";
    case 51:
        return "texture creation failed";
    case 52:
        return "invalid texture size";
    case 53:
        return "sampler descriptor creation failed";
    case 54:
        return "sampler state creation failed";
    case 55:
        return "invalid font options";
    case 56:
        return "font unavailable";
    case 57:
        return "font registration failed";
    case 58:
        return "invalid font data";
    case 59:
        return "invalid font slot";
    case 60:
        return "font variation unavailable";
    case 61:
        return "invalid mask id";
    case 62:
        return "invalid mask";
    case 63:
        return "mask atlas full";
    case 64:
        return "mask entry capacity exceeded";
    default:
        return "unknown platform error";
    }
}

static ZPUIRawInputSnapshot zpuiInputState = {0};

static uint32_t zpui_modifiers(NSEventModifierFlags flags) {
    uint32_t mods = 0;
    if ((flags & NSEventModifierFlagShift) != 0) {
        mods |= ZPUI_MOD_SHIFT;
    }
    if ((flags & NSEventModifierFlagControl) != 0) {
        mods |= ZPUI_MOD_CONTROL;
    }
    if ((flags & NSEventModifierFlagOption) != 0) {
        mods |= ZPUI_MOD_OPTION;
    }
    if ((flags & NSEventModifierFlagCommand) != 0) {
        mods |= ZPUI_MOD_COMMAND;
    }
    if ((flags & NSEventModifierFlagCapsLock) != 0) {
        mods |= ZPUI_MOD_CAPS_LOCK;
    }
    return mods;
}

static void zpui_record_key_event(uint32_t kind, NSEvent *event, uint32_t logical, uint32_t flags) {
    zpuiInputState.mods = zpui_modifiers(event.modifierFlags);
    if (zpuiInputState.key_count >= ZPUI_INPUT_MAX_KEY_EVENTS) {
        return;
    }

    ZPUIKeyEvent *key = &zpuiInputState.keys[zpuiInputState.key_count++];
    key->kind = kind;
    key->key_code = event.keyCode;
    key->logical = logical;
    key->mods = zpuiInputState.mods;
    key->flags = flags;
    key->timestamp = event.timestamp;
}

static void zpui_record_text_events(NSString *text, NSEvent *event) {
    if (text.length == 0) {
        return;
    }

    for (NSUInteger i = 0;
         i < text.length && zpuiInputState.text_count < ZPUI_INPUT_MAX_TEXT_EVENTS; i++) {
        uint8_t bytes[8] = {0};
        NSUInteger used = 0;
        BOOL ok = [text getBytes:bytes
                       maxLength:sizeof(bytes)
                      usedLength:&used
                        encoding:NSUTF8StringEncoding
                         options:0
                           range:NSMakeRange(i, 1)
                  remainingRange:NULL];
        if (!ok || used == 0 || used > sizeof(bytes)) {
            continue;
        }

        ZPUITextInputEvent *input = &zpuiInputState.text[zpuiInputState.text_count++];
        memcpy(input->bytes, bytes, used);
        input->len = (uint32_t)used;
        input->mods = zpui_modifiers(event.modifierFlags);
        input->timestamp = event.timestamp;
    }
}

static void zpui_record_mouse_event(uint32_t kind, NSEvent *event, NSView *view, uint32_t button,
                                    uint32_t clickCount) {
    NSPoint point = [view convertPoint:event.locationInWindow fromView:nil];
    zpuiInputState.has_cursor = 1;
    zpuiInputState.cursor_x = (float)point.x;
    zpuiInputState.cursor_y = (float)point.y;
    zpuiInputState.mods = zpui_modifiers(event.modifierFlags);
    if (zpuiInputState.mouse_count >= ZPUI_INPUT_MAX_MOUSE_EVENTS) {
        return;
    }

    ZPUIMouseEvent *mouse = &zpuiInputState.mouse[zpuiInputState.mouse_count++];
    mouse->kind = kind;
    mouse->button = button;
    mouse->click_count = clickCount;
    mouse->mods = zpuiInputState.mods;
    mouse->x = zpuiInputState.cursor_x;
    mouse->y = zpuiInputState.cursor_y;
    mouse->timestamp = event.timestamp;
}

void zpui_macos_input_snapshot(ZPUIRawInputSnapshot *out) {
    if (out == NULL) {
        return;
    }

    *out = zpuiInputState;
    zpuiInputState.key_count = 0;
    zpuiInputState.text_count = 0;
    zpuiInputState.mouse_count = 0;
    zpuiInputState.scroll_count = 0;
    zpuiInputState.window = 0;
    memset(zpuiInputState.keys, 0, sizeof(zpuiInputState.keys));
    memset(zpuiInputState.text, 0, sizeof(zpuiInputState.text));
    memset(zpuiInputState.mouse, 0, sizeof(zpuiInputState.mouse));
    memset(zpuiInputState.scroll, 0, sizeof(zpuiInputState.scroll));
}

static NSURL *zpui_metallib_url(void) {
    uint32_t pathLength = 0;
    _NSGetExecutablePath(NULL, &pathLength);

    char *path = malloc(pathLength);
    if (path == NULL) {
        return nil;
    }
    if (_NSGetExecutablePath(path, &pathLength) != 0) {
        free(path);
        return nil;
    }

    NSString *executablePath =
        [[NSFileManager defaultManager] stringWithFileSystemRepresentation:path
                                                                    length:strlen(path)];
    free(path);
    if (executablePath == nil) {
        return nil;
    }

    NSString *executableDirectory = [executablePath stringByDeletingLastPathComponent];
    NSString *metallibPath = [executableDirectory stringByAppendingPathComponent:@"zpui.metallib"];
    return [NSURL fileURLWithPath:metallibPath];
}

static bool zpui_cfstring_matches(CFStringRef value, CFStringRef requested) {
    if (value == NULL || requested == NULL) {
        return false;
    }
    return CFStringCompare(value, requested, kCFCompareCaseInsensitive | kCFCompareNonliteral) ==
           kCFCompareEqualTo;
}

static bool zpui_font_matches_request(CTFontRef font, CFStringRef requestedName) {
    if (font == NULL || requestedName == NULL) {
        return false;
    }

    bool matched = false;
    CFStringRef postscriptName = CTFontCopyPostScriptName(font);
    CFStringRef familyName = CTFontCopyFamilyName(font);
    CFStringRef fullName = CTFontCopyFullName(font);

    matched = zpui_cfstring_matches(postscriptName, requestedName) ||
              zpui_cfstring_matches(familyName, requestedName) ||
              zpui_cfstring_matches(fullName, requestedName);

    if (postscriptName != NULL)
        CFRelease(postscriptName);
    if (familyName != NULL)
        CFRelease(familyName);
    if (fullName != NULL)
        CFRelease(fullName);
    return matched;
}

static bool zpui_copy_cfstring_utf8(CFStringRef value, char *out, uint32_t outCapacity,
                                    uint32_t *outLen) {
    if (outLen != NULL) {
        *outLen = 0;
    }
    if (out == NULL || outCapacity == 0) {
        return false;
    }
    out[0] = '\0';
    if (value == NULL) {
        return false;
    }

    CFIndex used = 0;
    CFRange range = CFRangeMake(0, CFStringGetLength(value));
    CFStringGetBytes(value, range, kCFStringEncodingUTF8, 0, false, (UInt8 *)out,
                     (CFIndex)outCapacity - 1, &used);
    out[used] = '\0';
    if (outLen != NULL) {
        *outLen = (uint32_t)used;
    }
    return used > 0;
}

static void zpui_copy_resolved_font_name(CTFontRef font, char *resolvedName,
                                         uint32_t resolvedNameCapacity, uint32_t *resolvedNameLen) {
    CFStringRef name = CTFontCopyPostScriptName(font);
    if (name == NULL) {
        name = CTFontCopyFamilyName(font);
    }
    zpui_copy_cfstring_utf8(name, resolvedName, resolvedNameCapacity, resolvedNameLen);
    if (name != NULL) {
        CFRelease(name);
    }
}

static bool zpui_cfnumber_u32(CFNumberRef value, uint32_t *out) {
    if (value == NULL || out == NULL) {
        return false;
    }

    int64_t number = 0;
    if (!CFNumberGetValue(value, kCFNumberSInt64Type, &number)) {
        return false;
    }
    if (number <= 0 || number > UINT32_MAX) {
        return false;
    }

    *out = (uint32_t)number;
    return true;
}

static bool zpui_cfnumber_double(CFNumberRef value, double *out) {
    if (value == NULL || out == NULL) {
        return false;
    }

    double number = 0.0;
    if (!CFNumberGetValue(value, kCFNumberDoubleType, &number)) {
        return false;
    }

    *out = number;
    return isfinite(number);
}

static bool zpui_font_axis_accepts(CFDictionaryRef axis, uint32_t tag, float value) {
    if (axis == NULL || !isfinite(value)) {
        return false;
    }

    uint32_t axisTag = 0;
    if (!zpui_cfnumber_u32(CFDictionaryGetValue(axis, kCTFontVariationAxisIdentifierKey),
                           &axisTag) ||
        axisTag != tag) {
        return false;
    }

    double minValue = 0.0;
    double maxValue = 0.0;
    if (!zpui_cfnumber_double(CFDictionaryGetValue(axis, kCTFontVariationAxisMinimumValueKey),
                              &minValue) ||
        !zpui_cfnumber_double(CFDictionaryGetValue(axis, kCTFontVariationAxisMaximumValueKey),
                              &maxValue)) {
        return false;
    }

    const double requested = (double)value;
    return requested >= minValue && requested <= maxValue;
}

static bool zpui_validate_font_variations(CTFontRef font, const ZPUIFontVariation *variations,
                                          uint32_t variationCount) {
    if (variationCount == 0) {
        return true;
    }
    if (font == NULL || variations == NULL) {
        return false;
    }

    CFArrayRef axes = CTFontCopyVariationAxes(font);
    if (axes == NULL) {
        return false;
    }

    bool ok = true;
    const CFIndex axisCount = CFArrayGetCount(axes);
    for (uint32_t variationIndex = 0; variationIndex < variationCount; variationIndex++) {
        const ZPUIFontVariation variation = variations[variationIndex];
        if (variation.tag == 0 || !isfinite(variation.value)) {
            ok = false;
            break;
        }

        bool found = false;
        for (CFIndex axisIndex = 0; axisIndex < axisCount; axisIndex++) {
            CFDictionaryRef axis = CFArrayGetValueAtIndex(axes, axisIndex);
            if (zpui_font_axis_accepts(axis, variation.tag, variation.value)) {
                found = true;
                break;
            }
        }
        if (!found) {
            ok = false;
            break;
        }
    }

    CFRelease(axes);
    return ok;
}

static int zpui_create_requested_font(CFStringRef requestedName, CGFloat pixelSize,
                                      const ZPUIFontVariation *variations, uint32_t variationCount,
                                      CTFontRef *outFont) {
    if (outFont == NULL) {
        return ZPUI_FONT_STATUS_FAILED;
    }
    *outFont = NULL;

    CTFontRef baseFont = CTFontCreateWithName(requestedName, pixelSize, NULL);
    if (baseFont == NULL) {
        return ZPUI_FONT_STATUS_UNAVAILABLE;
    }
    if (!zpui_font_matches_request(baseFont, requestedName)) {
        CFRelease(baseFont);
        return ZPUI_FONT_STATUS_UNAVAILABLE;
    }

    if (variationCount == 0) {
        *outFont = baseFont;
        return ZPUI_FONT_STATUS_OK;
    }
    if (!zpui_validate_font_variations(baseFont, variations, variationCount)) {
        CFRelease(baseFont);
        return ZPUI_FONT_STATUS_INVALID_VARIATION;
    }

    CTFontDescriptorRef descriptor = CTFontCopyFontDescriptor(baseFont);
    CFRelease(baseFont);
    if (descriptor == NULL) {
        return ZPUI_FONT_STATUS_FAILED;
    }

    CTFontDescriptorRef current = descriptor;
    for (uint32_t variationIndex = 0; variationIndex < variationCount; variationIndex++) {
        int64_t signedTag = (int64_t)variations[variationIndex].tag;
        CFNumberRef axis = CFNumberCreate(NULL, kCFNumberSInt64Type, &signedTag);
        if (axis == NULL) {
            CFRelease(current);
            return ZPUI_FONT_STATUS_FAILED;
        }

        CTFontDescriptorRef next = CTFontDescriptorCreateCopyWithVariation(
            current, axis, (CGFloat)variations[variationIndex].value);
        CFRelease(axis);
        CFRelease(current);
        if (next == NULL) {
            return ZPUI_FONT_STATUS_FAILED;
        }
        current = next;
    }

    CTFontRef font = CTFontCreateWithFontDescriptor(current, pixelSize, NULL);
    CFRelease(current);
    if (font == NULL) {
        return ZPUI_FONT_STATUS_FAILED;
    }
    if (!zpui_font_matches_request(font, requestedName)) {
        CFRelease(font);
        return ZPUI_FONT_STATUS_UNAVAILABLE;
    }

    *outFont = font;
    return ZPUI_FONT_STATUS_OK;
}

static bool zpui_font_registration_already_done(CFErrorRef error) {
    if (error == NULL) {
        return false;
    }
    return CFEqual(CFErrorGetDomain(error), kCTFontManagerErrorDomain) &&
           CFErrorGetCode(error) == kCTFontManagerErrorAlreadyRegistered;
}

int zpui_macos_register_font_file(const char *path) {
    if (path == NULL || path[0] == '\0') {
        return ZPUI_FONT_STATUS_UNAVAILABLE;
    }

    NSString *fontPath = [NSString stringWithUTF8String:path];
    if (fontPath == nil || ![[NSFileManager defaultManager] fileExistsAtPath:fontPath]) {
        return ZPUI_FONT_STATUS_UNAVAILABLE;
    }

    NSURL *url = [NSURL fileURLWithPath:fontPath];
    CFErrorRef error = NULL;
    bool ok = CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess,
                                               &error);
    if (!ok && !zpui_font_registration_already_done(error)) {
        if (error != NULL)
            CFRelease(error);
        return ZPUI_FONT_STATUS_FAILED;
    }
    if (error != NULL)
        CFRelease(error);
    return ZPUI_FONT_STATUS_OK;
}

int zpui_macos_register_font_bytes(const uint8_t *bytes, size_t len) {
    if (bytes == NULL || len == 0) {
        return ZPUI_FONT_STATUS_UNAVAILABLE;
    }

    CFDataRef data = CFDataCreate(NULL, bytes, (CFIndex)len);
    if (data == NULL) {
        return ZPUI_FONT_STATUS_FAILED;
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGFontRef font = provider != NULL ? CGFontCreateWithDataProvider(provider) : NULL;
    if (provider != NULL) {
        CGDataProviderRelease(provider);
    }
    CFRelease(data);
    if (font == NULL) {
        return ZPUI_FONT_STATUS_UNAVAILABLE;
    }

    CFErrorRef error = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    bool ok = CTFontManagerRegisterGraphicsFont(font, &error);
#pragma clang diagnostic pop
    CGFontRelease(font);
    if (!ok && !zpui_font_registration_already_done(error)) {
        if (error != NULL)
            CFRelease(error);
        return ZPUI_FONT_STATUS_FAILED;
    }
    if (error != NULL)
        CFRelease(error);
    return ZPUI_FONT_STATUS_OK;
}

int zpui_macos_build_ascii_font_atlas(const char *fontName, float fontSize,
                                      const ZPUIFontVariation *variations, uint32_t variationCount,
                                      float scale, uint8_t *atlasBytes, uint32_t atlasWidth,
                                      uint32_t atlasHeight, ZPUITextFontMetrics *outMetrics,
                                      ZPUITextGlyphMetric *outGlyphs, uint32_t glyphCount,
                                      char *resolvedName, uint32_t resolvedNameCapacity,
                                      uint32_t *resolvedNameLen) {
    if (resolvedNameLen != NULL) {
        *resolvedNameLen = 0;
    }
    if (resolvedName != NULL && resolvedNameCapacity != 0) {
        resolvedName[0] = '\0';
    }
    if (fontName == NULL || atlasBytes == NULL || outMetrics == NULL || outGlyphs == NULL ||
        resolvedName == NULL || resolvedNameLen == NULL) {
        return ZPUI_FONT_STATUS_FAILED;
    }
    if (variationCount > 0 && variations == NULL) {
        return ZPUI_FONT_STATUS_INVALID_VARIATION;
    }
    if (fontSize <= 0.0f || scale <= 0.0f || atlasWidth == 0 || atlasHeight == 0 ||
        glyphCount < 128 || resolvedNameCapacity == 0) {
        return ZPUI_FONT_STATUS_FAILED;
    }

    memset(atlasBytes, 0, (size_t)atlasWidth * (size_t)atlasHeight);
    memset(outGlyphs, 0, sizeof(ZPUITextGlyphMetric) * glyphCount);

    CGFloat pixelSize = (CGFloat)fontSize * (CGFloat)scale;
    CFStringRef requestedName = CFStringCreateWithCString(NULL, fontName, kCFStringEncodingUTF8);
    if (requestedName == NULL) {
        return ZPUI_FONT_STATUS_FAILED;
    }

    CTFontRef font = NULL;
    int fontStatus =
        zpui_create_requested_font(requestedName, pixelSize, variations, variationCount, &font);
    CFRelease(requestedName);
    if (fontStatus != ZPUI_FONT_STATUS_OK) {
        return fontStatus;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    if (colorSpace == NULL) {
        CFRelease(font);
        return ZPUI_FONT_STATUS_FAILED;
    }

    CGContextRef context = CGBitmapContextCreate(atlasBytes, atlasWidth, atlasHeight, 8, atlasWidth,
                                                 colorSpace, (CGBitmapInfo)kCGImageAlphaOnly);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL) {
        CFRelease(font);
        return ZPUI_FONT_STATUS_FAILED;
    }

    CGContextSetTextDrawingMode(context, kCGTextFill);
    CGContextSetAllowsAntialiasing(context, true);
    CGContextSetShouldAntialias(context, true);
    CGContextSetAllowsFontSubpixelPositioning(context, true);
    CGContextSetShouldSubpixelPositionFonts(context, true);
    CGContextSetAllowsFontSubpixelQuantization(context, false);
    CGContextSetShouldSubpixelQuantizeFonts(context, false);
    CGContextSetShouldSmoothFonts(context, false);
    CGContextSetGrayFillColor(context, 1.0, 1.0);

    const CGFloat ascent = CTFontGetAscent(font);
    const CGFloat descent = CTFontGetDescent(font);
    const CGFloat leading = CTFontGetLeading(font);
    outMetrics->size = fontSize;
    outMetrics->scale = scale;
    outMetrics->ascent = (float)(ascent / (CGFloat)scale);
    outMetrics->descent = (float)(descent / (CGFloat)scale);
    outMetrics->leading = (float)(leading / (CGFloat)scale);
    outMetrics->line_height = outMetrics->ascent + outMetrics->descent + outMetrics->leading;
    outMetrics->atlas_width = atlasWidth;
    outMetrics->atlas_height = atlasHeight;
    zpui_copy_resolved_font_name(font, resolvedName, resolvedNameCapacity, resolvedNameLen);

    const uint32_t pad = 2;
    uint32_t penX = pad;
    uint32_t penY = pad;
    uint32_t rowHeight = 0;

    for (uint32_t codepoint = 32; codepoint <= 126; codepoint++) {
        UniChar character = (UniChar)codepoint;
        CGGlyph glyph = 0;
        bool found = CTFontGetGlyphsForCharacters(font, &character, &glyph, 1);
        if (!found) {
            continue;
        }

        CGSize advance = CGSizeZero;
        CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, &glyph, &advance, 1);
        CGRect bounds =
            CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationHorizontal, &glyph, NULL, 1);

        ZPUITextGlyphMetric *metric = &outGlyphs[codepoint];
        metric->codepoint = codepoint;
        metric->glyph_id = glyph;
        metric->advance = (float)(advance.width / (CGFloat)scale);
        metric->flags = ZPUI_TEXT_GLYPH_PRESENT;

        if (CGRectIsEmpty(bounds) || bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
            continue;
        }

        const CGFloat glyphMinX = floor(bounds.origin.x);
        const CGFloat glyphMaxX = ceil(bounds.origin.x + bounds.size.width);
        const CGFloat glyphMinY = floor(bounds.origin.y);
        const CGFloat glyphMaxY = ceil(bounds.origin.y + bounds.size.height);
        const uint32_t glyphWidth = (uint32_t)(glyphMaxX - glyphMinX);
        const uint32_t glyphHeight = (uint32_t)(glyphMaxY - glyphMinY);
        const uint32_t tileWidth = glyphWidth + pad * 2;
        const uint32_t tileHeight = glyphHeight + pad * 2;
        if (tileWidth >= atlasWidth || tileHeight >= atlasHeight) {
            CGContextRelease(context);
            CFRelease(font);
            return ZPUI_FONT_STATUS_FAILED;
        }

        if (penX + tileWidth >= atlasWidth) {
            penX = pad;
            penY += rowHeight + pad;
            rowHeight = 0;
        }
        if (penY + tileHeight >= atlasHeight) {
            CGContextRelease(context);
            CFRelease(font);
            return ZPUI_FONT_STATUS_FAILED;
        }

        metric->atlas_x = penX;
        metric->atlas_y = penY;
        metric->atlas_width = tileWidth;
        metric->atlas_height = tileHeight;
        metric->offset_x = (float)((glyphMinX - (CGFloat)pad) / (CGFloat)scale);
        metric->offset_y = (float)((ascent - glyphMaxY - (CGFloat)pad) / (CGFloat)scale);
        metric->flags |= ZPUI_TEXT_GLYPH_VISIBLE;

        CGPoint point =
            CGPointMake((CGFloat)penX + (CGFloat)pad - glyphMinX,
                        (CGFloat)atlasHeight - ((CGFloat)penY + (CGFloat)pad) - glyphMaxY);
        CTFontDrawGlyphs(font, &glyph, &point, 1, context);

        penX += tileWidth + pad;
        if (tileHeight > rowHeight) {
            rowHeight = tileHeight;
        }
    }

    CGContextRelease(context);
    CFRelease(font);
    return ZPUI_FONT_STATUS_OK;
}

id<MTLLibrary> zpui_platform_create_shader_library(id<MTLDevice> device)
    __attribute__((ns_returns_retained));

id<MTLLibrary> zpui_platform_create_shader_library(id<MTLDevice> device) {
    NSError *error = nil;
    NSURL *metallibURL = zpui_metallib_url();
    id<MTLLibrary> library = nil;
    if (metallibURL != nil) {
        library = [device newLibraryWithURL:metallibURL error:&error];
        if (library != nil) {
            return library;
        }
    }

    NSString *runDirectoryPath = [[NSFileManager defaultManager] currentDirectoryPath];
    NSString *installedMetallibPath =
        [[runDirectoryPath stringByAppendingPathComponent:@"zig-out/bin"]
            stringByAppendingPathComponent:@"zpui.metallib"];
    NSURL *installedMetallibURL = [NSURL fileURLWithPath:installedMetallibPath];
    library = [device newLibraryWithURL:installedMetallibURL error:&error];
    if (library == nil) {
        fprintf(stderr, "ZPUI: failed to load Metal library: %s\n",
                error.localizedDescription.UTF8String);
    }
    return library;
}

@protocol ZPUIWindowSurface <NSObject>
- (void)requestFrame;
- (void)stopDisplayLink;
@end

static id<ZPUIWindowSurface> zpuiActiveWindowSurface = nil;

void zpui_macos_request_redraw(void) { [zpuiActiveWindowSurface requestFrame]; }

@interface ZPUIWindow : NSWindow <NSWindowDelegate>
@property(nonatomic, assign) id<ZPUIWindowSurface> metalView;
@property(nonatomic) BOOL zpuiHasTrafficLightPosition;
@property(nonatomic) NSPoint zpuiTrafficLightPosition;
@property(nonatomic) BOOL zpuiTitlebarTransparent;
- (void)zpuiApplyTrafficLightPosition;
@end

@implementation ZPUIWindow

- (BOOL)canBecomeMainWindow {
    return YES;
}

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (void)windowDidResize:(NSNotification *)notification {
    (void)notification;
    zpuiInputState.window |= ZPUI_WINDOW_RESIZED;
    [self zpuiApplyTrafficLightPosition];
    [self.metalView requestFrame];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    (void)notification;
    zpuiInputState.window |= ZPUI_WINDOW_FOCUSED;
    [self.metalView requestFrame];
}

- (void)windowDidResignKey:(NSNotification *)notification {
    (void)notification;
    zpuiInputState.window |= ZPUI_WINDOW_BLURRED;
    [self.metalView requestFrame];
}

- (void)windowDidChangeScreen:(NSNotification *)notification {
    (void)notification;
    [self zpuiApplyTrafficLightPosition];
    [self.metalView requestFrame];
}

- (void)windowDidChangeOcclusionState:(NSNotification *)notification {
    (void)notification;
    id<ZPUIWindowSurface> metalView = self.metalView;
    if ((self.occlusionState & NSWindowOcclusionStateVisible) != 0) {
        [self zpuiApplyTrafficLightPosition];
        [metalView requestFrame];
    } else {
        [metalView stopDisplayLink];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    [self.metalView stopDisplayLink];
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    (void)notification;
    NSOperatingSystemVersion version = {15, 3, 0};
    if (self.zpuiTitlebarTransparent &&
        [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version]) {
        self.titlebarAppearsTransparent = NO;
    }
}

- (void)windowWillExitFullScreen:(NSNotification *)notification {
    (void)notification;
    NSOperatingSystemVersion version = {15, 3, 0};
    if (self.zpuiTitlebarTransparent &&
        [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version]) {
        self.titlebarAppearsTransparent = YES;
    }
}

- (void)zpuiApplyTrafficLightPosition {
    if (!self.zpuiHasTrafficLightPosition ||
        ((self.styleMask & NSWindowStyleMaskFullScreen) != 0)) {
        return;
    }

    NSButton *closeButton = [self standardWindowButton:NSWindowCloseButton];
    NSButton *minButton = [self standardWindowButton:NSWindowMiniaturizeButton];
    NSButton *zoomButton = [self standardWindowButton:NSWindowZoomButton];
    if (closeButton == nil || minButton == nil || zoomButton == nil ||
        closeButton.superview == nil) {
        return;
    }

    NSRect closeFrame = closeButton.frame;
    NSRect minFrame = minButton.frame;
    NSRect zoomFrame = zoomButton.frame;
    const CGFloat titlebarHeight = NSHeight(closeButton.superview.bounds);
    const CGFloat y = titlebarHeight - self.zpuiTrafficLightPosition.y - NSHeight(closeFrame);
    const CGFloat spacing = NSMinX(minFrame) - NSMinX(closeFrame);

    closeFrame.origin = NSMakePoint(self.zpuiTrafficLightPosition.x, y);
    minFrame.origin = NSMakePoint(self.zpuiTrafficLightPosition.x + spacing, y);
    zoomFrame.origin = NSMakePoint(self.zpuiTrafficLightPosition.x + spacing * 2.0, y);

    closeButton.frame = closeFrame;
    minButton.frame = minFrame;
    zoomButton.frame = zoomFrame;
}

@end

@interface ZPUIAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation ZPUIAppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

@end

static ZPUIAppDelegate *zpuiAppDelegate = nil;

@interface ZPUIRenderer : NSObject
- (instancetype)initWithDevice:(id<MTLDevice>)device layerOpaque:(BOOL)layerOpaque;
- (CAMetalLayer *)layer;
- (void)resizeToDrawableSize:(CGSize)drawableSize scale:(CGFloat)scale;
- (BOOL)drawFrame;
- (BOOL)drawFrameWithTransaction:(BOOL)presentsWithTransaction;
@end

@implementation ZPUIRenderer {
    ZPUISurface *_surface;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device layerOpaque:(BOOL)layerOpaque {
    self = [super init];
    if (self) {
        int surfaceStatus =
            zpui_surface_create_with_options(device, layerOpaque ? 1u : 0u, &_surface);
        if (surfaceStatus != 0 || _surface == NULL) {
            fprintf(stderr, "ZPUI: failed to create surface in Zig: %s (%d)\n",
                    zpui_platform_status_name(surfaceStatus), surfaceStatus);
            return nil;
        }
    }
    return self;
}

- (CAMetalLayer *)layer {
    return zpui_surface_layer(_surface);
}

- (void)resizeToDrawableSize:(CGSize)drawableSize scale:(CGFloat)scale {
    int status = zpui_surface_resize(_surface, drawableSize.width, drawableSize.height, scale);
    if (status != 0) {
        fprintf(stderr, "ZPUI: failed to resize surface in Zig: %s (%d)\n",
                zpui_platform_status_name(status), status);
    }
}

- (BOOL)drawFrame {
    return [self drawFrameWithTransaction:NO];
}

- (BOOL)drawFrameWithTransaction:(BOOL)presentsWithTransaction {
    CAMetalLayer *layer = [self layer];
    if (layer == nil || layer.drawableSize.width <= 0 || layer.drawableSize.height <= 0) {
        return YES;
    }

    const BOOL previousPresentsWithTransaction = layer.presentsWithTransaction;
    layer.presentsWithTransaction = presentsWithTransaction;

    id<CAMetalDrawable> drawable = [layer nextDrawable];
    if (drawable == nil) {
        layer.presentsWithTransaction = previousPresentsWithTransaction;
        return NO;
    }

    int drawStatus = zpui_macos_draw_frame(_surface, drawable);
    if (drawStatus != 0) {
        fprintf(stderr, "ZPUI: failed to draw frame in Zig: %s (%d)\n",
                zpui_platform_status_name(drawStatus), drawStatus);
        layer.presentsWithTransaction = previousPresentsWithTransaction;
        return NO;
    }

    layer.presentsWithTransaction = previousPresentsWithTransaction;
    return YES;
}

- (void)dealloc {
    zpui_surface_destroy(_surface);
    _surface = NULL;
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

@end

@interface ZPUIMetalView : NSView <ZPUIWindowSurface>
@property(nonatomic, strong, readonly) ZPUIRenderer *renderer;
- (instancetype)initWithFrame:(NSRect)frame
                       device:(id<MTLDevice>)device
                  layerOpaque:(BOOL)layerOpaque;
- (void)requestFrame;
- (void)setContinuousFrames:(BOOL)enabled;
- (void)startDisplayLink;
- (void)stopDisplayLink;
- (BOOL)drawFrame;
@end

@implementation ZPUIMetalView {
    CADisplayLink *_displayLink;
    atomic_bool _needsFrame;
    BOOL _continuousFrames;
}

- (instancetype)initWithFrame:(NSRect)frame
                       device:(id<MTLDevice>)device
                  layerOpaque:(BOOL)layerOpaque {
    self = [super initWithFrame:frame];
    if (self) {
        _renderer = [[ZPUIRenderer alloc] initWithDevice:device layerOpaque:layerOpaque];
        if (_renderer == nil) {
            return nil;
        }

        atomic_init(&_needsFrame, false);
        _continuousFrames = NO;

        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.wantsLayer = YES;
        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
        [self updateDrawableSize];
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    NSString *characters = event.charactersIgnoringModifiers;
    uint32_t logical = characters.length > 0 ? [characters characterAtIndex:0] : 0;
    uint32_t flags = event.isARepeat ? ZPUI_KEY_REPEAT : 0;
    zpui_record_key_event(ZPUI_KEY_DOWN, event, logical, flags);

    const uint32_t mods = zpui_modifiers(event.modifierFlags);
    if ((mods & (ZPUI_MOD_COMMAND | ZPUI_MOD_CONTROL)) == 0) {
        zpui_record_text_events(event.characters, event);
    }
    [self requestFrame];
}

- (void)keyUp:(NSEvent *)event {
    NSString *characters = event.charactersIgnoringModifiers;
    uint32_t logical = characters.length > 0 ? [characters characterAtIndex:0] : 0;
    zpui_record_key_event(ZPUI_KEY_UP, event, logical, 0);
    [self requestFrame];
}

- (void)flagsChanged:(NSEvent *)event {
    zpui_record_key_event(ZPUI_KEY_MODIFIERS_CHANGED, event, 0, 0);
    [self requestFrame];
}

- (void)mouseMoved:(NSEvent *)event {
    zpui_record_mouse_event(ZPUI_MOUSE_MOVE, event, self, 0, 0);
    [self requestFrame];
}

- (void)mouseDragged:(NSEvent *)event {
    zpui_record_mouse_event(ZPUI_MOUSE_DRAG, event, self, ZPUI_BUTTON_LEFT, 0);
    [self requestFrame];
}

- (void)rightMouseDragged:(NSEvent *)event {
    zpui_record_mouse_event(ZPUI_MOUSE_DRAG, event, self, ZPUI_BUTTON_RIGHT, 0);
    [self requestFrame];
}

- (void)otherMouseDragged:(NSEvent *)event {
    zpui_record_mouse_event(ZPUI_MOUSE_DRAG, event, self, ZPUI_BUTTON_OTHER, 0);
    [self requestFrame];
}

- (void)mouseDown:(NSEvent *)event {
    zpuiInputState.buttons |= ZPUI_BUTTON_LEFT;
    zpui_record_mouse_event(ZPUI_MOUSE_DOWN, event, self, ZPUI_BUTTON_LEFT,
                            (uint32_t)event.clickCount);
    [self requestFrame];
}

- (void)rightMouseDown:(NSEvent *)event {
    zpuiInputState.buttons |= ZPUI_BUTTON_RIGHT;
    zpui_record_mouse_event(ZPUI_MOUSE_DOWN, event, self, ZPUI_BUTTON_RIGHT,
                            (uint32_t)event.clickCount);
    [self requestFrame];
}

- (void)otherMouseDown:(NSEvent *)event {
    zpuiInputState.buttons |= ZPUI_BUTTON_OTHER;
    zpui_record_mouse_event(ZPUI_MOUSE_DOWN, event, self, ZPUI_BUTTON_OTHER,
                            (uint32_t)event.clickCount);
    [self requestFrame];
}

- (void)mouseUp:(NSEvent *)event {
    zpui_record_mouse_event(ZPUI_MOUSE_UP, event, self, ZPUI_BUTTON_LEFT,
                            (uint32_t)event.clickCount);
    zpuiInputState.buttons &= ~ZPUI_BUTTON_LEFT;
    [self requestFrame];
}

- (void)rightMouseUp:(NSEvent *)event {
    zpui_record_mouse_event(ZPUI_MOUSE_UP, event, self, ZPUI_BUTTON_RIGHT,
                            (uint32_t)event.clickCount);
    zpuiInputState.buttons &= ~ZPUI_BUTTON_RIGHT;
    [self requestFrame];
}

- (void)otherMouseUp:(NSEvent *)event {
    zpui_record_mouse_event(ZPUI_MOUSE_UP, event, self, ZPUI_BUTTON_OTHER,
                            (uint32_t)event.clickCount);
    zpuiInputState.buttons &= ~ZPUI_BUTTON_OTHER;
    [self requestFrame];
}

- (void)scrollWheel:(NSEvent *)event {
    zpui_record_mouse_event(ZPUI_MOUSE_MOVE, event, self, 0, 0);
    if (zpuiInputState.scroll_count < ZPUI_INPUT_MAX_SCROLL_EVENTS) {
        ZPUIScrollEvent *scroll = &zpuiInputState.scroll[zpuiInputState.scroll_count++];
        scroll->dx = (float)event.scrollingDeltaX;
        scroll->dy = (float)event.scrollingDeltaY;
        scroll->precise_dx = event.hasPreciseScrollingDeltas ? scroll->dx : 0.0f;
        scroll->precise_dy = event.hasPreciseScrollingDeltas ? scroll->dy : 0.0f;
        scroll->mods = zpui_modifiers(event.modifierFlags);
        scroll->timestamp = event.timestamp;
    }
    [self requestFrame];
}

- (CALayer *)makeBackingLayer {
    return _renderer.layer;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self updateDrawableSize];
    [self requestFrame];
}

- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    [self updateDrawableSize];
    [self requestFrame];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self updateDrawableSize];
    [self requestFrame];
}

- (void)displayLayer:(CALayer *)layer {
    (void)layer;
    [self stopDisplayLink];
    atomic_store_explicit(&_needsFrame, false, memory_order_release);
    [self updateDrawableSize];
    if (![_renderer drawFrameWithTransaction:YES]) {
        atomic_store_explicit(&_needsFrame, true, memory_order_release);
    }
    if (_continuousFrames || atomic_load_explicit(&_needsFrame, memory_order_acquire)) {
        [self startDisplayLink];
    }
}

- (void)updateDrawableSize {
    CGFloat scale = self.window.backingScaleFactor;
    if (scale <= 0) {
        scale = NSScreen.mainScreen.backingScaleFactor;
    }
    if (scale <= 0) {
        scale = 1.0;
    }

    NSSize size = self.bounds.size;
    CGSize drawableSize = CGSizeMake(size.width * scale, size.height * scale);
    if (drawableSize.width <= 0 || drawableSize.height <= 0) {
        return;
    }
    [_renderer resizeToDrawableSize:drawableSize scale:scale];
}

- (void)requestFrame {
    atomic_store_explicit(&_needsFrame, true, memory_order_release);
    [self startDisplayLink];
}

- (void)setContinuousFrames:(BOOL)enabled {
    _continuousFrames = enabled;
    if (enabled) {
        [self startDisplayLink];
    } else if (!atomic_load_explicit(&_needsFrame, memory_order_acquire)) {
        [self stopDisplayLink];
    }
}

- (void)startDisplayLink {
    if (_displayLink != nil) {
        return;
    }

    _displayLink = [self displayLinkWithTarget:self selector:@selector(displayLinkTick:)];
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)stopDisplayLink {
    if (_displayLink == nil) {
        return;
    }

    [_displayLink invalidate];
    _displayLink = nil;
}

- (BOOL)drawFrame {
    [self updateDrawableSize];
    return [_renderer drawFrame];
}

- (void)displayLinkTick:(CADisplayLink *)displayLink {
    (void)displayLink;
    if (self.window == nil || ![self.window isVisible] ||
        ([self.window occlusionState] & NSWindowOcclusionStateVisible) == 0) {
        [self stopDisplayLink];
        return;
    }

    const bool needsFrame = atomic_exchange_explicit(&_needsFrame, false, memory_order_acq_rel);
    if (_continuousFrames || needsFrame) {
        if (![self drawFrame]) {
            atomic_store_explicit(&_needsFrame, true, memory_order_release);
        }
    }

    if (!_continuousFrames && !atomic_load_explicit(&_needsFrame, memory_order_acquire)) {
        [self stopDisplayLink];
    }
}

- (void)dealloc {
    if (zpuiActiveWindowSurface == self) {
        zpuiActiveWindowSurface = nil;
    }
    [self stopDisplayLink];
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

@end

static void zpui_install_menu(void) {
    NSMenu *menuBar = [[NSMenu alloc] init];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menuBar addItem:appMenuItem];
    [NSApp setMainMenu:menuBar];

    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"ZPUI"];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit ZPUI"
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    [appMenu addItem:quitItem];
    [appMenuItem setSubmenu:appMenu];
}

static NSWindowStyleMask zpui_window_style_mask(ZPUIWindowChrome chrome) {
    NSWindowStyleMask style = (NSWindowStyleMask)0;
    if ((chrome.flags & ZPUI_WINDOW_TITLED) != 0) {
        style |= NSWindowStyleMaskTitled;
    }
    if ((chrome.flags & ZPUI_WINDOW_CLOSABLE) != 0) {
        style |= NSWindowStyleMaskClosable;
    }
    if ((chrome.flags & ZPUI_WINDOW_MINIATURIZABLE) != 0) {
        style |= NSWindowStyleMaskMiniaturizable;
    }
    if ((chrome.flags & ZPUI_WINDOW_RESIZABLE) != 0) {
        style |= NSWindowStyleMaskResizable;
    }
    if ((chrome.flags & ZPUI_WINDOW_FULL_SIZE_CONTENT) != 0) {
        style |= NSWindowStyleMaskFullSizeContentView;
    }
    return style;
}

static BOOL zpui_window_layer_opaque(ZPUIWindowChrome chrome) {
    return chrome.background == ZPUI_WINDOW_BACKGROUND_OPAQUE ? YES : NO;
}

static NSWindowToolbarStyle zpui_toolbar_style(uint32_t style) {
    switch (style) {
    case ZPUI_WINDOW_TOOLBAR_STYLE_EXPANDED:
        return NSWindowToolbarStyleExpanded;
    case ZPUI_WINDOW_TOOLBAR_STYLE_PREFERENCE:
        return NSWindowToolbarStylePreference;
    case ZPUI_WINDOW_TOOLBAR_STYLE_UNIFIED:
        return NSWindowToolbarStyleUnified;
    case ZPUI_WINDOW_TOOLBAR_STYLE_UNIFIED_COMPACT:
        return NSWindowToolbarStyleUnifiedCompact;
    default:
        return NSWindowToolbarStyleAutomatic;
    }
}

static NSTitlebarSeparatorStyle zpui_titlebar_separator_style(uint32_t style) {
    switch (style) {
    case ZPUI_WINDOW_TITLEBAR_SEPARATOR_NONE:
        return NSTitlebarSeparatorStyleNone;
    case ZPUI_WINDOW_TITLEBAR_SEPARATOR_LINE:
        return NSTitlebarSeparatorStyleLine;
    case ZPUI_WINDOW_TITLEBAR_SEPARATOR_SHADOW:
        return NSTitlebarSeparatorStyleShadow;
    default:
        return NSTitlebarSeparatorStyleAutomatic;
    }
}

static void zpui_apply_window_appearance(NSWindow *window, uint32_t appearance) {
    NSString *name = nil;
    switch (appearance) {
    case ZPUI_WINDOW_APPEARANCE_AQUA:
        name = NSAppearanceNameAqua;
        break;
    case ZPUI_WINDOW_APPEARANCE_DARK_AQUA:
        name = NSAppearanceNameDarkAqua;
        break;
    case ZPUI_WINDOW_APPEARANCE_VIBRANT_LIGHT:
        name = NSAppearanceNameVibrantLight;
        break;
    case ZPUI_WINDOW_APPEARANCE_VIBRANT_DARK:
        name = NSAppearanceNameVibrantDark;
        break;
    default:
        window.appearance = nil;
        return;
    }
    window.appearance = [NSAppearance appearanceNamed:name];
}

static void zpui_apply_window_background(NSWindow *window, ZPUIWindowChrome chrome) {
    const BOOL opaque = zpui_window_layer_opaque(chrome);
    window.opaque = opaque;
    window.backgroundColor = opaque
                                 ? [NSColor colorWithSRGBRed:0.0 green:0.0 blue:0.0 alpha:1.0]
                                 : [NSColor colorWithSRGBRed:0.0 green:0.0 blue:0.0 alpha:0.0001];

    if (chrome.background != ZPUI_WINDOW_BACKGROUND_BLURRED) {
        return;
    }

    NSVisualEffectView *blurView =
        [[NSVisualEffectView alloc] initWithFrame:window.contentView.bounds];
    blurView.autoresizingMask =
        (NSAutoresizingMaskOptions)(NSViewWidthSizable | NSViewHeightSizable);
    blurView.material = NSVisualEffectMaterialWindowBackground;
    blurView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    blurView.state = NSVisualEffectStateActive;
    [window.contentView addSubview:blurView positioned:NSWindowBelow relativeTo:nil];
}

static void zpui_apply_window_chrome(ZPUIWindow *window, ZPUIWindowChrome chrome) {
    window.movable = (chrome.flags & ZPUI_WINDOW_MOVABLE) != 0;
    window.movableByWindowBackground = (chrome.flags & ZPUI_WINDOW_MOVABLE_BY_BACKGROUND) != 0;
    window.hasShadow = (chrome.flags & ZPUI_WINDOW_HAS_SHADOW) != 0;

    if ((chrome.flags & ZPUI_WINDOW_TITLEBAR_TRANSPARENT) != 0) {
        window.zpuiTitlebarTransparent = YES;
        window.titlebarAppearsTransparent = YES;
    }
    window.titleVisibility = (chrome.flags & ZPUI_WINDOW_TITLE_VISIBLE) != 0 ? NSWindowTitleVisible
                                                                             : NSWindowTitleHidden;

    if (@available(macOS 11.0, *)) {
        window.toolbarStyle = zpui_toolbar_style(chrome.toolbar_style);
        window.titlebarSeparatorStyle =
            zpui_titlebar_separator_style(chrome.titlebar_separator_style);
    }

    zpui_apply_window_appearance(window, chrome.appearance);
    zpui_apply_window_background(window, chrome);

    if ((chrome.flags & ZPUI_WINDOW_TRAFFIC_LIGHT_POSITION) != 0) {
        window.zpuiHasTrafficLightPosition = YES;
        window.zpuiTrafficLightPosition =
            NSMakePoint(chrome.traffic_light_x, chrome.traffic_light_y);
    }
}

int zpui_macos_init_window(const char *title, double width, double height,
                           ZPUIWindowChrome chrome) {
    @autoreleasepool {
        if (title == NULL || title[0] == '\0' || width <= 0.0 || height <= 0.0 ||
            !isfinite(width) || !isfinite(height)) {
            return 1;
        }

        NSString *windowTitle = [[NSString alloc] initWithUTF8String:title];
        if (windowTitle == nil) {
            return 1;
        }

        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        zpuiAppDelegate = [[ZPUIAppDelegate alloc] init];
        NSApp.delegate = zpuiAppDelegate;
        zpui_install_menu();

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            fprintf(stderr, "ZPUI: Metal is unavailable on this machine.\n");
            return 2;
        }

        const NSRect frame = NSMakeRect(0, 0, width, height);
        const NSWindowStyleMask style = zpui_window_style_mask(chrome);

        ZPUIWindow *window = [[ZPUIWindow alloc] initWithContentRect:frame
                                                           styleMask:style
                                                             backing:NSBackingStoreBuffered
                                                               defer:NO];
        if (window == nil) {
            return 1;
        }

        window.title = windowTitle;
        window.releasedWhenClosed = NO;
        window.acceptsMouseMovedEvents = YES;
        zpui_apply_window_chrome(window, chrome);
        [window center];

        ZPUIMetalView *metalView =
            [[ZPUIMetalView alloc] initWithFrame:window.contentView.bounds
                                          device:device
                                     layerOpaque:zpui_window_layer_opaque(chrome)];
        if (metalView == nil) {
            return 1;
        }

        [window.contentView addSubview:metalView];
        zpuiActiveWindowSurface = metalView;
        window.metalView = metalView;
        window.delegate = window;
        [window makeFirstResponder:metalView];
        [window makeKeyAndOrderFront:nil];
        [window zpuiApplyTrafficLightPosition];
        [metalView requestFrame];

        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }

    return 0;
}
