#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <stdatomic.h>
#import <stdint.h>
#import <stdio.h>

typedef struct {
    float position[4];
    float color[4];
} ZPUIVertex;

typedef struct {
    double clearColor[4];
    uint32_t vertexCount;
    uint32_t reserved[3];
    ZPUIVertex vertices[3];
} ZPUIFrame;

extern void zpui_build_frame(ZPUIFrame *frame);
extern int zpui_metal_create_layer(id device, void **outLayer);
extern int zpui_metal_resize_layer(CAMetalLayer *layer, double width, double height, double scale);

static const char *zpui_native_status_name(int status) {
    switch (status) {
    case 0:
        return "ok";
    case 10:
        return "invalid device";
    case 11:
        return "invalid layer";
    case 12:
        return "missing Objective-C class";
    case 13:
        return "missing Objective-C selector";
    case 14:
        return "layer allocation failed";
    default:
        return "unknown native error";
    }
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
@property(nonatomic, strong, readonly) CAMetalLayer *layer;
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (void)resizeToDrawableSize:(CGSize)drawableSize scale:(CGFloat)scale;
- (void)drawFrame;
- (void)drawFrameWithTransaction:(BOOL)presentsWithTransaction;
@end

@implementation ZPUIRenderer {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _commandQueue = [device newCommandQueue];
        void *layer = NULL;
        int layerStatus = zpui_metal_create_layer(device, &layer);
        if (layerStatus != 0 || layer == NULL) {
            fprintf(stderr, "ZPUI: failed to create CAMetalLayer in Zig: %s (%d)\n",
                    zpui_native_status_name(layerStatus), layerStatus);
            return nil;
        }
        _layer = (__bridge CAMetalLayer *)layer;

        NSError *error = nil;
        NSString *source =
            @"#include <metal_stdlib>\n"
             "using namespace metal;\n"
             "struct ZPUIVertex { float4 position; float4 color; };\n"
             "struct VertexOut { float4 position [[position]]; float4 color; };\n"
             "vertex VertexOut zpui_vertex(uint vertex_id [[vertex_id]],\n"
             "                             const device ZPUIVertex *vertices [[buffer(0)]]) {\n"
             "    VertexOut out;\n"
             "    out.position = vertices[vertex_id].position;\n"
             "    out.color = vertices[vertex_id].color;\n"
             "    return out;\n"
             "}\n"
             "fragment float4 zpui_fragment(VertexOut vert [[stage_in]]) {\n"
             "    return vert.color;\n"
             "}\n";
        id<MTLLibrary> library = [device newLibraryWithSource:source options:nil error:&error];
        if (library == nil) {
            fprintf(stderr, "ZPUI: failed to compile Metal library: %s\n",
                    error.localizedDescription.UTF8String);
            return nil;
        }

        MTLRenderPipelineDescriptor *pipelineDescriptor =
            [[MTLRenderPipelineDescriptor alloc] init];
        pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"zpui_vertex"];
        pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"zpui_fragment"];
        pipelineDescriptor.colorAttachments[0].pixelFormat = _layer.pixelFormat;

        _pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                                error:&error];
        if (_pipelineState == nil) {
            fprintf(stderr, "ZPUI: failed to create render pipeline: %s\n",
                    error.localizedDescription.UTF8String);
            return nil;
        }
    }
    return self;
}

- (void)resizeToDrawableSize:(CGSize)drawableSize scale:(CGFloat)scale {
    int status = zpui_metal_resize_layer(_layer, drawableSize.width, drawableSize.height, scale);
    if (status != 0) {
        fprintf(stderr, "ZPUI: failed to resize CAMetalLayer in Zig: %s (%d)\n",
                zpui_native_status_name(status), status);
    }
}

- (void)drawFrame {
    [self drawFrameWithTransaction:NO];
}

- (void)drawFrameWithTransaction:(BOOL)presentsWithTransaction {
    if (_layer.drawableSize.width <= 0 || _layer.drawableSize.height <= 0) {
        return;
    }

    const BOOL previousPresentsWithTransaction = _layer.presentsWithTransaction;
    _layer.presentsWithTransaction = presentsWithTransaction;

    id<CAMetalDrawable> drawable = [_layer nextDrawable];
    if (drawable == nil) {
        _layer.presentsWithTransaction = previousPresentsWithTransaction;
        return;
    }

    ZPUIFrame frame = {0};
    zpui_build_frame(&frame);
    if (frame.vertexCount == 0 || frame.vertexCount > 3) {
        _layer.presentsWithTransaction = previousPresentsWithTransaction;
        return;
    }

    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(
        frame.clearColor[0], frame.clearColor[1], frame.clearColor[2], frame.clearColor[3]);
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:_pipelineState];
    [encoder setVertexBytes:frame.vertices length:sizeof(frame.vertices) atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle
                vertexStart:0
                vertexCount:(NSUInteger)frame.vertexCount];
    [encoder endEncoding];

    if (presentsWithTransaction) {
        [commandBuffer commit];
        [commandBuffer waitUntilScheduled];
        [drawable present];
    } else {
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
    _layer.presentsWithTransaction = previousPresentsWithTransaction;
}

@end

@interface ZPUIMetalView : NSView <ZPUIWindowSurface>
@property(nonatomic, strong, readonly) ZPUIRenderer *renderer;
- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device;
- (void)requestFrame;
- (void)setContinuousFrames:(BOOL)enabled;
- (void)startDisplayLink;
- (void)stopDisplayLink;
- (void)drawFrame;
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
    [_renderer drawFrameWithTransaction:YES];
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

- (void)drawFrame {
    [self updateDrawableSize];
    [_renderer drawFrame];
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
        [self drawFrame];
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
