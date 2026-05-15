#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <mach-o/dyld.h>
#import <stdatomic.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

typedef struct ZPUISurface ZPUISurface;

extern int zpui_surface_create(id device, ZPUISurface **outSurface);
extern void zpui_surface_destroy(ZPUISurface *surface);
extern CAMetalLayer *zpui_surface_layer(ZPUISurface *surface);
extern int zpui_surface_resize(ZPUISurface *surface, double width, double height, double scale);
extern int zpui_demo_draw_frame(ZPUISurface *surface, id<CAMetalDrawable> drawable);

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
    default:
        return "unknown platform error";
    }
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

@interface ZPUIWindow : NSWindow <NSWindowDelegate>
@property(nonatomic, weak) id<ZPUIWindowSurface> metalView;
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
    [self.metalView requestFrame];
}

- (void)windowDidChangeScreen:(NSNotification *)notification {
    (void)notification;
    [self.metalView requestFrame];
}

- (void)windowDidChangeOcclusionState:(NSNotification *)notification {
    (void)notification;
    if ((self.occlusionState & NSWindowOcclusionStateVisible) != 0) {
        [self.metalView requestFrame];
    } else {
        [self.metalView stopDisplayLink];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    [self.metalView stopDisplayLink];
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
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (CAMetalLayer *)layer;
- (void)resizeToDrawableSize:(CGSize)drawableSize scale:(CGFloat)scale;
- (BOOL)drawFrame;
- (BOOL)drawFrameWithTransaction:(BOOL)presentsWithTransaction;
@end

@implementation ZPUIRenderer {
    ZPUISurface *_surface;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        int surfaceStatus = zpui_surface_create(device, &_surface);
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

    int drawStatus = zpui_demo_draw_frame(_surface, drawable);
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
}

@end

@interface ZPUIMetalView : NSView <ZPUIWindowSurface>
@property(nonatomic, strong, readonly) ZPUIRenderer *renderer;
- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device;
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

- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device {
    self = [super initWithFrame:frame];
    if (self) {
        _renderer = [[ZPUIRenderer alloc] initWithDevice:device];
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
    [self stopDisplayLink];
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

int zpui_run_macos_hello_window(void) {
    @autoreleasepool {
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

        const NSRect frame = NSMakeRect(0, 0, 960, 600);
        const NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                        NSWindowStyleMaskMiniaturizable |
                                        NSWindowStyleMaskResizable;

        ZPUIWindow *window = [[ZPUIWindow alloc] initWithContentRect:frame
                                                           styleMask:style
                                                             backing:NSBackingStoreBuffered
                                                               defer:NO];
        if (window == nil) {
            return 1;
        }

        window.title = @"ZPUI";
        window.releasedWhenClosed = NO;
        [window center];

        ZPUIMetalView *metalView = [[ZPUIMetalView alloc] initWithFrame:window.contentView.bounds
                                                                 device:device];
        if (metalView == nil) {
            return 1;
        }

        [window.contentView addSubview:metalView];
        window.metalView = metalView;
        window.delegate = window;
        [window makeFirstResponder:metalView];
        [window makeKeyAndOrderFront:nil];
        [metalView requestFrame];

        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }

    return 0;
}
