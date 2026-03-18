# mdprev

`mdprev` is a simple macOS Markdown preview application.

## Features

- Open a Markdown file (`.md`, `.markdown`, plain text)
- Drag and drop a file onto the preview area to open it
- GFM-oriented parsing via `cmark-gfm` backend (including table syntax)
- Live preview with automatic reload when the file changes on disk
- Manual reload button (`Cmd+R`)
- Auto-reload toggle
- Adjustable base font size (`Cmd+=`, `Cmd+-`, `Cmd+0`)
- Selectable preview themes (`View > Theme`: System, Light, Dark, Sepia)
- highlight.js syntax highlighting for fenced code blocks
- Selectable code highlight themes (`View > Syntax Highlight > Color Theme`, all highlight.js built-in themes)
- Recent files list in `File > Open Recent` (up to 10 entries)
- Startup screen shows clickable recent files list

Editing is intentionally not included; this app is focused on previewing external files.

## Rendering Backend

`MarkdownRenderer` delegates rendering to a `MarkdownRenderingEngine`.
The current default is `CMarkGFMRenderer` (`swift-cmark` gfm branch).
Rendered HTML is displayed with `WKWebView` to preserve block-level structures like tables.
When moving to `textual`, you can add a new engine implementation and switch the injected engine.

## Development

### Build

```bash
swift build
```

### Test

```bash
swift test
```

### Run

```bash
swift run mdprev
```

### Build Release App Bundle

```bash
make release-app
```

This creates `/Users/mrkn/src/github.com/mrkn/mdprev/dist/mdprev.app`.

## License

GNU Affero General Public License v3.0. See `LICENSE`.
