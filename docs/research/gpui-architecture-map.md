# GPUI Architecture Map

This is the first ZPUI research pass over GPUI and Zed. The goal is not to clone GPUI mechanically, but to understand the architectural bets that make Zed possible, then choose the parts ZPUI should copy, compress, or replace with a more data-oriented Zig and Metal design.

## Snapshot

- Upstream repository: [zed-industries/zed](https://github.com/zed-industries/zed)
- Commit: [`700b0b5de6b1101fbe699f714888d1b68680cb0f`](https://github.com/zed-industries/zed/commit/700b0b5de6b1101fbe699f714888d1b68680cb0f)
- Commit date: 2026-05-14
- Subject: `agent_ui: Render skills as creases (#56689)`

## Why Start Here

GPUI source is the right first place to look, but the order matters:

1. Public examples show the intended mental model without internal noise.
2. GPUI internals show how state, invalidation, layout, input, and rendering are actually wired.
3. Zed usage shows which parts survive contact with a real editor.

That third layer is essential. A UI framework can look elegant in examples and still fall apart when asked to host a multi-pane code editor with IME, scrolling text, async project state, command dispatch, theming, and virtualization.

## Core Model

GPUI is best understood as three cooperating registers:

- `Entity<T>`: retained, typed application state owned by `App`.
- `Render`: declarative view code that turns retained state into an element tree.
- `Element`: lower-level UI nodes with layout, prepaint, paint, hit testing, and retained frame state.

Around those registers are the runtime pieces:

- `Application` owns the platform and starts the native event loop.
- `App` owns entities, windows, globals, actions, observers, executors, and invalidation state.
- `Context<T>` is the controlled access path for mutating an entity and notifying dependents.
- `Window` owns per-window input state, focus, element state, layout, hitboxes, dirty views, frames, and scene generation.
- `Scene` is the renderer-facing output: typed primitive arrays plus ordered paint operations.
- Platform crates adapt AppKit, windows, text services, input, atlases, and the Metal renderer.

## Source Map

Public API and examples:

- [GPUI README](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/README.md)
- [`hello_world.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/examples/hello_world.rs)
- [`input.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/examples/input.rs)
- [`uniform_list.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/examples/uniform_list.rs)

Core runtime:

- [`app.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/src/app.rs)
- [`entity_map.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/src/app/entity_map.rs)
- [`context.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/src/app/context.rs)
- [`view.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/src/view.rs)
- [`element.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/src/element.rs)
- [`window.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/src/window.rs)
- [`scene.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/src/scene.rs)
- [`key_dispatch.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui/src/key_dispatch.rs)

macOS and Metal:

- [`gpui_platform.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui_platform/src/gpui_platform.rs)
- [`platform.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui_macos/src/platform.rs)
- [`window.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui_macos/src/window.rs)
- [`metal_renderer.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui_macos/src/metal_renderer.rs)
- [`metal_atlas.rs`](https://github.com/zed-industries/zed/blob/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/gpui_macos/src/metal_atlas.rs)

Zed product usage:

- [`crates/workspace`](https://github.com/zed-industries/zed/tree/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/workspace)
- [`crates/editor`](https://github.com/zed-industries/zed/tree/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/editor)
- [`crates/ui`](https://github.com/zed-industries/zed/tree/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/ui)
- [`crates/command_palette`](https://github.com/zed-industries/zed/tree/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/command_palette)
- [`crates/theme`](https://github.com/zed-industries/zed/tree/700b0b5de6b1101fbe699f714888d1b68680cb0f/crates/theme)

## Runtime Pipeline

1. Native platform event arrives from AppKit.
2. Platform converts it into GPUI input/event data and calls into the owning `Window`.
3. Mouse dispatch uses frame hitboxes and listener tables; keyboard dispatch walks focused dispatch nodes, key contexts, keymaps, and actions.
4. Event handlers mutate retained entities through `Entity::update` and `Context<T>`.
5. `Context::notify` tells `App` an entity changed.
6. `App` maps changed/accessed entities to window invalidators.
7. A frame callback is requested for dirty windows.
8. `Window::draw` invalidates dirty views, lays out the root view, runs prepaint, runs paint, and builds a `Scene`.
9. `Window::present` hands the rendered scene to the platform window.
10. macOS `MetalRenderer` batches scene primitives, writes instance data, encodes Metal draw calls, and presents the drawable.

The key observation for ZPUI: GPUI rebuilds much of the element tree each frame, but state is not thrown away. State is retained behind entity handles, element IDs, cached frame ranges, text/layout caches, focus handles, and platform resources.

## What ZPUI Should Copy

- Keep the three-layer model: retained state, render functions, and low-level elements.
- Use typed generation handles for retained state.
- Gate mutation through an app/context object so invalidation and subscriptions are observable.
- Make semantic actions and key contexts first-class early. They are not editor polish; they are core architecture.
- Provide a `div`-like base element with fluent style and event APIs, but keep the Zig surface smaller and more curated.
- Keep custom elements available for editor text, canvases, virtual lists, and other high-density surfaces.
- Keep a narrow platform boundary: windows, input, frame scheduling, clipboard, text services, IME, drawables, and GPU resource ownership.
- Treat examples as API tests. `hello_world`, input, button/counter, uniform list, and a tiny editor surface should compile from the start.

## What ZPUI Should Change

- Prefer explicit dependency graphs over implicit "accessed entity" tracking where possible.
- Store per-frame UI data as dense arrays instead of pointer-heavy object graphs.
- Model layout, hit testing, dispatch, and painting as data passes over arrays.
- Keep render output close to Metal: SoA primitive buffers, stable texture/atlas references, and batch-friendly command streams.
- Use persistent ring buffers and explicit upload queues for primitive instances, glyphs, and atlas changes.
- Explore argument buffers, texture arrays, and indirect draws once the primitive model is stable.
- Tie task and subscription lifetimes tightly to entities so async work is harder to leak or detach accidentally.
- Avoid pulling a product component layer into the kernel too early. Zed's `crates/ui` is useful inspiration, but ZPUI's core should stay small.

## Zed-Level Requirements

To remake something like Zed, ZPUI eventually needs these capabilities:

- A `Workspace`-like retained root that owns panes, docks, modals, status UI, project state, tasks, and subscriptions.
- A type-erased item abstraction for editor tabs, terminals, search panes, settings, and future tools.
- A custom editor element, not a generic text box.
- Buffer snapshots, display maps, selection state, scroll state, diagnostics, completion UI, and async language/project updates.
- UTF-16-aware text input and IME support for Cocoa.
- Virtualized fixed-height and variable-height lists.
- A semantic theme system with global reactive updates.
- Command palette support over the same action dispatch tree as normal keybindings.

## First ZPUI Milestones

1. Example-first API sketches: `hello_world`, button/counter, text input, and uniform list.
2. Core entity arena: typed handles, weak handles, generations, context-gated mutation, and notifications.
3. Native macOS surface kernel: AppKit run loop, window lifecycle, explicit Objective-C runtime bindings, Zig-owned `CAMetalLayer` setup, frame scheduling, events, and a Metal drawable.
4. Element lifecycle: request layout, prepaint, paint, frame-local state, hitboxes, focus IDs, and scene primitive arrays.
5. Action and focus dispatch: key contexts, action listeners, bubbling, and mouse hit dispatch.
6. Text MVP: shaping, glyph cache, atlas upload, text runs, cursor bounds, and basic IME hooks.
7. Editor prototype: visible-row rendering, scrolling, selection painting, cursor painting, and keyboard input.

## Open Questions

- Should ZPUI bind to Taffy early, or start with a smaller native layout subset?
- How much of Cocoa should be wrapped directly versus hidden behind narrow Zig interfaces?
- What is the most ergonomic Zig surface for render functions and element builders?
- What should the task/executor model look like in Zig?
- How should retained entity lifetime interact with frame-local element allocation?
- Which scene primitives are the minimal useful set for the first Metal renderer?

## Current Bet

The most promising direction is a GPUI-shaped API with a more data-oriented implementation underneath:

- GPUI's user model: entity, context, render, element, action.
- ZPUI's internal model: dense arenas, stable handles, explicit dependency edges, SoA frame data, and Metal-native command preparation.

That gives us a path toward a comfortable application API without giving up the performance profile that Zig and Metal should let us reach.
