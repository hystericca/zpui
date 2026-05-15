#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <mach-o/dyld.h>
#import <stdatomic.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

#define ZPUI_MAX_FRAME_VERTICES 48

typedef struct {
    double clearColor[4];
    uint32_t vertexCount;
    uint32_t batchCount;
    uint32_t scissorX;
    uint32_t scissorY;
    uint32_t scissorWidth;
    uint32_t scissorHeight;
    uint32_t reserved[2];
} ZPUIPreparedFrame;

typedef struct ZPUISurface ZPUISurface;

extern int zpui_surface_create(id device, ZPUISurface **outSurface);
extern void zpui_surface_destroy(ZPUISurface *surface);
extern CAMetalLayer *zpui_surface_layer(ZPUISurface *surface);
extern id<MTL4CommandQueue> zpui_surface_mtl4_command_queue(ZPUISurface *surface);
extern id<MTL4CommandBuffer> zpui_surface_mtl4_command_buffer(ZPUISurface *surface);
extern id<MTL4CommandAllocator> zpui_surface_next_mtl4_command_allocator(ZPUISurface *surface);
extern int zpui_surface_signal_frame_completion(ZPUISurface *surface);
extern id<MTL4ArgumentTable> zpui_surface_argument_table(ZPUISurface *surface);
extern int zpui_surface_resize(ZPUISurface *surface, double width, double height, double scale);
extern int zpui_demo_prepare_frame(ZPUISurface *surface, ZPUIPreparedFrame *preparedFrame);

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

static id<MTLLibrary> zpui_new_shader_library(id<MTLDevice> device, NSError **error) {
    NSURL *metallibURL = zpui_metallib_url();
    id<MTLLibrary> library = nil;
    if (metallibURL != nil) {
        library = [device newLibraryWithURL:metallibURL error:error];
        if (library != nil) {
            return library;
        }
    }

    NSString *runDirectoryPath = [[NSFileManager defaultManager] currentDirectoryPath];
    NSString *installedMetallibPath =
        [[runDirectoryPath stringByAppendingPathComponent:@"zig-out/bin"]
            stringByAppendingPathComponent:@"zpui.metallib"];
    NSURL *installedMetallibURL = [NSURL fileURLWithPath:installedMetallibPath];
    return [device newLibraryWithURL:installedMetallibURL error:error];
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
    id<MTLDevice> _device;
    ZPUISurface *_surface;
    __unsafe_unretained id<MTL4CommandQueue> _commandQueue;
    __unsafe_unretained id<MTL4CommandBuffer> _commandBuffer;
    __unsafe_unretained id<MTL4ArgumentTable> _argumentTable;
    id<MTLRenderPipelineState> _pipelineState;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        int surfaceStatus = zpui_surface_create(device, &_surface);
        if (surfaceStatus != 0 || _surface == NULL) {
            fprintf(stderr, "ZPUI: failed to create surface in Zig: %s (%d)\n",
                    zpui_platform_status_name(surfaceStatus), surfaceStatus);
            return nil;
        }

        CAMetalLayer *layer = [self layer];
        _commandQueue = zpui_surface_mtl4_command_queue(_surface);
        _commandBuffer = zpui_surface_mtl4_command_buffer(_surface);
        _argumentTable = zpui_surface_argument_table(_surface);
        if (_commandQueue == nil) {
            fprintf(stderr, "ZPUI: surface returned no command queue.\n");
            zpui_surface_destroy(_surface);
            _surface = NULL;
            return nil;
        }
        if (_commandBuffer == nil) {
            fprintf(stderr, "ZPUI: surface returned no command buffer.\n");
            zpui_surface_destroy(_surface);
            _surface = NULL;
            return nil;
        }
        if (_argumentTable == nil) {
            fprintf(stderr, "ZPUI: surface returned no argument table.\n");
            zpui_surface_destroy(_surface);
            _surface = NULL;
            return nil;
        }

        NSError *error = nil;
        id<MTLLibrary> library = zpui_new_shader_library(device, &error);
        if (library == nil) {
            fprintf(stderr, "ZPUI: failed to load Metal library: %s\n",
                    error.localizedDescription.UTF8String);
            zpui_surface_destroy(_surface);
            _surface = NULL;
            return nil;
        }

        id<MTL4Compiler> compiler = [device newCompilerWithDescriptor:[MTL4CompilerDescriptor new]
                                                                error:&error];
        if (compiler == nil) {
            fprintf(stderr, "ZPUI: failed to create Metal 4 compiler: %s\n",
                    error.localizedDescription.UTF8String);
            zpui_surface_destroy(_surface);
            _surface = NULL;
            return nil;
        }

        MTL4LibraryFunctionDescriptor *vertexFunction = [MTL4LibraryFunctionDescriptor new];
        vertexFunction.library = library;
        vertexFunction.name = @"zpui_vertex";
        MTL4LibraryFunctionDescriptor *fragmentFunction = [MTL4LibraryFunctionDescriptor new];
        fragmentFunction.library = library;
        fragmentFunction.name = @"zpui_fragment";

        MTL4RenderPipelineDescriptor *pipelineDescriptor = [MTL4RenderPipelineDescriptor new];
        pipelineDescriptor.vertexFunctionDescriptor = vertexFunction;
        pipelineDescriptor.fragmentFunctionDescriptor = fragmentFunction;
        pipelineDescriptor.colorAttachments[0].pixelFormat = layer.pixelFormat;

        _pipelineState = [compiler newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                    compilerTaskOptions:nil
                                                                  error:&error];
        if (_pipelineState == nil) {
            fprintf(stderr, "ZPUI: failed to create render pipeline: %s\n",
                    error.localizedDescription.UTF8String);
            zpui_surface_destroy(_surface);
            _surface = NULL;
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

    id<MTL4CommandAllocator> allocator = zpui_surface_next_mtl4_command_allocator(_surface);
    if (allocator == nil || _commandQueue == nil || _commandBuffer == nil) {
        layer.presentsWithTransaction = previousPresentsWithTransaction;
        return NO;
    }

    ZPUIPreparedFrame frame = {0};
    int prepareStatus = zpui_demo_prepare_frame(_surface, &frame);
    if (prepareStatus != 0) {
        fprintf(stderr, "ZPUI: failed to prepare frame in Zig: %s (%d)\n",
                zpui_platform_status_name(prepareStatus), prepareStatus);
        layer.presentsWithTransaction = previousPresentsWithTransaction;
        return YES;
    }
    if (frame.vertexCount == 0 || frame.batchCount == 0 ||
        frame.vertexCount > ZPUI_MAX_FRAME_VERTICES) {
        layer.presentsWithTransaction = previousPresentsWithTransaction;
        return YES;
    }

    id<CAMetalDrawable> drawable = [layer nextDrawable];
    if (drawable == nil) {
        layer.presentsWithTransaction = previousPresentsWithTransaction;
        return NO;
    }

    MTL4RenderPassDescriptor *pass = [[MTL4RenderPassDescriptor alloc] init];
    pass.colorAttachments[0].texture = drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(
        frame.clearColor[0], frame.clearColor[1], frame.clearColor[2], frame.clearColor[3]);
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;

    [_commandBuffer beginCommandBufferWithAllocator:allocator];
    id<MTL4RenderCommandEncoder> encoder = [_commandBuffer renderCommandEncoderWithDescriptor:pass];
    if (encoder == nil) {
        [_commandBuffer endCommandBuffer];
        layer.presentsWithTransaction = previousPresentsWithTransaction;
        return NO;
    }
    MTLViewport viewport = {
        .originX = 0.0,
        .originY = 0.0,
        .width = layer.drawableSize.width,
        .height = layer.drawableSize.height,
        .znear = 0.0,
        .zfar = 1.0,
    };
    [encoder setViewport:viewport];
    MTLScissorRect scissor = {
        .x = frame.scissorX,
        .y = frame.scissorY,
        .width = frame.scissorWidth,
        .height = frame.scissorHeight,
    };
    [encoder setScissorRect:scissor];
    [encoder setRenderPipelineState:_pipelineState];
    [encoder setArgumentTable:_argumentTable atStages:MTLRenderStageVertex];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle
                vertexStart:0
                vertexCount:(NSUInteger)frame.vertexCount];
    [encoder endEncoding];
    if (layer.residencySet != nil) {
        [_commandBuffer useResidencySet:layer.residencySet];
    }
    [_commandBuffer endCommandBuffer];

    id<MTL4CommandBuffer> commandBuffers[] = {_commandBuffer};
    [_commandQueue waitForDrawable:drawable];
    [_commandQueue commit:commandBuffers count:1];
    int signalStatus = zpui_surface_signal_frame_completion(_surface);
    if (signalStatus != 0) {
        fprintf(stderr, "ZPUI: failed to signal frame completion: %s (%d)\n",
                zpui_platform_status_name(signalStatus), signalStatus);
    }
    [_commandQueue signalDrawable:drawable];
    [drawable present];

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
