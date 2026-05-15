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
- `src/surface.zig` owns the native surface state: retained `MTLDevice`, retained `CAMetalLayer`, owned `MTL4CommandQueue`, reusable `MTL4CommandBuffer`, three `MTL4CommandAllocator` instances, `MTLSharedEvent` frame fencing, three per-frame shared/write-combined vertex buffers, an app `MTLResidencySet`, an `MTL4ArgumentTable`, drawable size, backing scale, resize generation, and layer config.
- `src/gpu/metal.zig` records device capabilities and enforces the developer target profile: unified memory, Metal 4, and Apple GPU family 10 or newer.
- `ZPUIRenderer` owns a `ZPUISurface *` handle, plus the temporary Objective-C render pipeline.
- `ZPUIMetalView.makeBackingLayer` returns `renderer.layer`.
- `src/gpu/metal.zig` creates and configures the `CAMetalLayer` through explicit Objective-C runtime calls.
- Resize/backing changes route through Zig before updating `contentsScale` and `drawableSize`.
- `NSView.displayLink(target:selector:)` schedules frame callbacks on current macOS.
- A dirty bit requests frames; the display link stops when no frame is pending.
- A continuous-frame flag exists for future animation, but the static smoke test does not draw forever.
- Zig owns the first frame command through a flat C ABI struct.
- Objective-C asks Zig to prepare the current frame slot and return a small `ZPUIPreparedFrame`, then encodes that data into Metal.
- The first pixels are a Zig-authored triangle encoded directly into the layer drawable.
- Zig writes frame vertices into the active frame slot's shared `MTLBuffer`, binds its `gpuAddress` into `MTL4ArgumentTable`, and Objective-C only issues `setArgumentTable:atStages:` plus `drawPrimitives`.
- `src/objc.zig` owns typed `objc_msgSend` wrappers for Objective-C object pointers, `BOOL`, `NSUInteger`, `CGFloat`, `CGSize`, and `CAAutoresizingMask`.
- `src/objc.zig` also proves Zig can register Objective-C classes with Zig method implementations.

Surface lifetime contract:

- Zig owns the `CAMetalLayer` with an explicit retain and releases it when `zpui_surface_destroy` runs.
- Objective-C receives the layer as borrowed through `zpui_surface_layer`; it must not transfer or release that object.
- Zig owns the `MTL4CommandQueue`, `MTL4CommandBuffer`, and `MTL4CommandAllocator` ring; Objective-C receives borrowed pointers for the current clear-only Metal 4 render pass.
- Zig owns allocator and per-frame buffer reuse policy: it waits on `MTLSharedEvent`, resets the frame allocator, writes the active frame buffer, and signals the next frame completion value after queue commit.
- Zig owns the app residency set for persistent GPU-address resources; Objective-C declares `CAMetalLayer.residencySet` on every command buffer before ending it.
- `zpui_surface_destroy` drains the last submitted frame event before releasing GPU-visible objects.
- Objective-C is responsible for destroying the `ZPUISurface *` handle exactly once after display callbacks have stopped.
- `makeBackingLayer` must return the same borrowed layer for the view lifetime.
- Display callbacks must be stopped before the renderer destroys its `ZPUISurface`.

Removed bootstrap shortcuts:

- No `MTKView`.
- No `MTKViewDelegate`.
- No `NSTextField` or AppKit-rendered text overlay.
- No MetalKit framework link.
- No CoreVideo framework link in ZPUI's current bridge; GPUI still uses `CVDisplayLink`, but the macOS 26 SDK now points new code toward AppKit display links.
- No legacy `MTLCommandQueue`/`MTLCommandBuffer` submission path in current ZPUI rendering.
- No runtime shader string in the current render path; `build.zig` compiles `src/native/shaders/zpui_smoke.metal` into `zig-out/bin/zpui.metallib`.
- No legacy `setVertexBytes:length:atIndex:` resource binding.

## Next Steps

1. Move the remaining pipeline creation policy from Objective-C into Zig while keeping the Metal 4 compiler/pipeline descriptor path.
2. Expand the frame command buffer from one triangle into dense triangle/quad primitive arrays.
3. Replace the fixed three-vertex frame slots with a growable per-frame arena and batching offsets.
4. Make the dirty/continuous frame flags callable from Zig.
5. Add event callbacks on `ZPUIMetalView` for mouse, keyboard, resize, scale, and close.
6. Add `NSTextInputClient` hooks later for IME, but keep text rendering on the Metal path.

## Objective-C From Zig

Zig can hold Objective-C object pointers, send messages through `objc_msgSend`, register selectors, allocate Objective-C classes, and install Zig functions as Objective-C IMPs. That means the `.m` bridge is a bootstrap convenience, not a hard boundary.

The likely migration path is incremental:

1. Keep the working `.m` bridge while proving each Objective-C runtime operation in Zig.
2. Move selector/class/message wrappers into `src/objc.zig`.
3. Move renderer/resource ownership into Zig first. Completed slices so far: `CAMetalLayer` creation/configuration/drawable sizing, Metal 4 command queue/buffer/allocator creation, shared-event allocator fencing, per-frame shared vertex buffer creation, app residency set ownership, `MTL4ArgumentTable` binding, checked-in shader compilation, plus a Zig-owned `Surface` handle with retained Objective-C resources.
4. Move simple Objective-C object setup into Zig next.
5. Leave only the hardest AppKit subclass/delegate/text-input pieces in Objective-C until we have enough Zig runtime helpers to replace them cleanly.

## Milestone 0 Direction

Milestone 0 is the native surface kernel. The current direction is deliberately lower level than a normal Cocoa app:

- AppKit owns the process, menu, window, and view lifecycle.
- Zig owns the Metal surface contract, retained native resources, and explicit status-code failures across the C ABI.
- Objective-C remains a narrow host for AppKit subclassing and the current Metal command encoder.
- Frame data is dense and C ABI friendly, so the renderer can move toward persistent GPU buffers instead of retained object trees.
- The next ownership transfer should be moving Metal 4 pipeline setup into Zig.

## Developer Target Profile

ZPUI's early development target is intentionally narrow:

- Hardware: Apple M5, built-in Apple GPU.
- OS: macOS 26.5 developer beta.
- Metal support: Metal 4 required.
- Memory model: unified memory required.
- GPU family: Apple family 10 or newer required.

This is a deliberate trade against GPUI's broader compatibility surface. GPUI has to keep fallbacks for more Macs; ZPUI can spend the first architecture passes assuming Apple Silicon, shared CPU/GPU memory, modern Metal feature families, and the current SDK. Compatibility can become a separate target later, after the fast path is clean.

## Source Cross-Checks

- GPUI's macOS renderer owns both `metal::MetalLayer` and `CommandQueue` in `/Users/hystericca/Developer/Projects/zed/crates/gpui_macos/src/metal_renderer.rs:113` and `/Users/hystericca/Developer/Projects/zed/crates/gpui_macos/src/metal_renderer.rs:119`.
- GPUI creates its command queue once with `device.new_command_queue()` in `/Users/hystericca/Developer/Projects/zed/crates/gpui_macos/src/metal_renderer.rs:322`, then uses it for per-frame command buffers.
- GPUI checks `device.has_unified_memory()` and `device.supports_family(MTLGPUFamily::Apple1)` to choose storage and rendering paths in `/Users/hystericca/Developer/Projects/zed/crates/gpui_macos/src/metal_renderer.rs:230`.
- ZPUI now diverges from GPUI here: it uses `newMTL4CommandQueue`, `newCommandBuffer`, `newCommandAllocator`, `MTL4RenderPassDescriptor`, and `MTL4CommandQueue.commit:count:`.
- Apple's Metal 4 docs state that `MTL4CommandQueue`/`MTL4CommandBuffer` are independent from legacy `MTLCommandQueue`/`MTLCommandBuffer`, that command buffers come from `MTLDevice`, and that submission happens through `MTL4CommandQueue.commit:count:`.
- Apple's Metal 4 sample flow for drawables is `waitForDrawable:` -> `commit:count:` -> `signalDrawable:` -> `present`.
- Apple's Metal 4 argument-table API binds buffers by `MTLBuffer.gpuAddress` through `MTL4ArgumentTable.setAddress:atIndex:` and exposes those bindings to render stages with `MTL4RenderCommandEncoder.setArgumentTable:atStages:`.
- Apple's local Metal 4 Xcode template uses a `MTLSharedEvent` to wait for prior work before resetting each command allocator, then signals the next frame value on the Metal 4 queue.
- Apple's current `MTLDevice` API exposes `hasUnifiedMemory`, `recommendedMaxWorkingSetSize`, and `supportsFamily:`; the current SDK declares `MTLGPUFamilyMetal4 = 5002` and `MTLGPUFamilyApple10 = 1010`.
