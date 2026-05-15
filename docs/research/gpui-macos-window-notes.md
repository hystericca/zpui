# GPUI macOS Window Notes

This note tracks the first ZPUI macOS surface after reviewing GPUI internals. The goal is to stay close to the GPU path: AppKit owns the window, ZPUI owns the Metal layer and every visible pixel.

## GPUI Pattern

GPUI does not use `MTKView` for its primary window surface. The relevant shape is:

- `NSWindow` subclass for window behavior and delegate callbacks.
- Custom `NSView` subclass for input, text services, resize/backing changes, and layer ownership.
- `makeBackingLayer` returns a renderer-owned `CAMetalLayer`.
- `displayLayer:` requests a frame instead of relying on `drawRect:`.
- GPUI uses `CVDisplayLink` to drive frame callbacks and marshals work back to the main queue.
- The renderer pulls `nextDrawable` from the layer and presents command buffers directly.

Useful GPUI references:

- `/Users/hystericca/Developer/Projects/zed/crates/gpui_macos/src/window.rs:125`
- `/Users/hystericca/Developer/Projects/zed/crates/gpui_macos/src/window.rs:217`
- `/Users/hystericca/Developer/Projects/zed/crates/gpui_macos/src/window.rs:2462`
- `/Users/hystericca/Developer/Projects/zed/crates/gpui_macos/src/window.rs:2511`
- `/Users/hystericca/Developer/Projects/zed/crates/gpui_macos/src/display_link.rs:15`
- `/Users/hystericca/Developer/Projects/zed/crates/gpui_macos/src/metal_renderer.rs:147`

## Current ZPUI Surface

`src/native/macos_app.m` now follows the same primitive ownership model:

- `ZPUIWindow : NSWindow`
- `ZPUIMetalView : NSView`
- `ZPUIRenderer` owns a `CAMetalLayer`, command queue, and render pipeline.
- `ZPUIMetalView.makeBackingLayer` returns `renderer.layer`.
- Resize/backing changes update `contentsScale` and `drawableSize`.
- `NSView.displayLink(target:selector:)` schedules frame callbacks on current macOS.
- A dirty bit requests frames; the display link stops when no frame is pending.
- A continuous-frame flag exists for future animation, but the static smoke test does not draw forever.
- Zig owns the first frame command through a flat C ABI struct.
- Objective-C asks Zig to fill `ZPUIFrame`, then encodes that data into Metal.
- The first pixels are a Zig-authored triangle encoded directly into the layer drawable.
- `src/objc.zig` proves Zig can call the Objective-C runtime directly and register Objective-C classes with Zig method implementations.

Removed bootstrap shortcuts:

- No `MTKView`.
- No `MTKViewDelegate`.
- No `NSTextField` or AppKit-rendered text overlay.
- No MetalKit framework link.
- No CoreVideo framework link in ZPUI's current bridge; GPUI still uses `CVDisplayLink`, but the macOS 26 SDK now points new code toward AppKit display links.

## Next Steps

1. Replace runtime shader compilation with a checked-in `.metal` shader build path.
2. Expand `ZPUIFrame` from one triangle into a small scene command buffer: clear color plus triangle/quad primitive arrays.
3. Move GPU resource allocation policy into Zig while leaving Cocoa/ObjC object calls in the bridge.
4. Make the dirty/continuous frame flags callable from Zig.
5. Add event callbacks on `ZPUIMetalView` for mouse, keyboard, resize, scale, and close.
6. Add `NSTextInputClient` hooks later for IME, but keep text rendering on the Metal path.

## Objective-C From Zig

Zig can hold Objective-C object pointers, send messages through `objc_msgSend`, register selectors, allocate Objective-C classes, and install Zig functions as Objective-C IMPs. That means the `.m` bridge is a bootstrap convenience, not a hard boundary.

The likely migration path is incremental:

1. Keep the working `.m` bridge while proving each Objective-C runtime operation in Zig.
2. Move selector/class/message wrappers into `src/objc.zig`.
3. Move renderer/resource ownership into Zig first.
4. Move simple Objective-C object setup into Zig next.
5. Leave only the hardest AppKit subclass/delegate/text-input pieces in Objective-C until we have enough Zig runtime helpers to replace them cleanly.
