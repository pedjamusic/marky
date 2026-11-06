# Markdown Showcase & Manual Verification Fixture

This document serves as a comprehensive visual and functional test fixture for the Marky Markdown reader. It covers CommonMark core specifications, GitHub Flavored Markdown (GFM) extensions, and edge cases.

---

## 1. Headings

### ATX Headings

# Heading Level 1
## Heading Level 2
### Heading Level 3
#### Heading Level 4
##### Heading Level 5
###### Heading Level 6

### Setext Headings

Setext Heading Level 1
======================

Setext Heading Level 2
----------------------

---

## 2. Text Formatting & Inline Styles

- **Bold with asterisks**: **This is bold text**
- **Bold with underscores**: __This is also bold text__
- *Italic with asterisks*: *This is italic text*
- *Italic with underscores*: _This is also italic text_
- ***Combined bold and italic (stars)***: ***Bold and italic text***
- ___Combined bold and italic (underscores)___: ___Bold and italic text___
- ~~Strikethrough~~: ~~This text has been struck through~~
- `Inline code`: `let greeting = "Hello, world!"`
- ``Inline code with backticks``: ``Use `git status` to inspect state``
- Protected syntax inside code: `**this stays literal**` and `*not italic*` and `[not a link](url)`

### Nested & Combined Formatting

- **Bold containing *italic* text**
- *Italic containing **bold** text*
- ~~**Strikethrough and bold**~~
- [**Bold Link to Website**](https://example.com)
- [*Italic Link to Website*](https://example.com)
- [Link with `code` in label](https://example.com)

### Literal Code & Intra-Word Protection

- Variable names with underscores stay literal: `user_account_identifier` and `created_at_timestamp`.
- Plain text intra-word underscores do not trigger italics: `snake_case_variable_name` remains intact.
- Backslash escapes remove the backslash and keep characters literal:
  - Asterisk: \*literal asterisk\*
  - Underscore: \_literal underscore\_
  - Bracket: \[literal bracket\]
  - Pipe: \|literal pipe\|
  - Tilde: \~~literal tildes\~~

---

## 3. GitHub Flavored Markdown (GFM) Tables

### Multi-Line Column Wrapping Table (Roadmap Fixture)

| Target Release | Scope & Implementation Details | Architectural Impact & Mitigation |
| :--- | :--- | :--- |
| **0.3.0 Engine Polish** | Complete Swift 6 strict concurrency migration across prepared blocks, reader cache, and AppKit-bridged rich text layout engines. Support full CommonMark inline presentation and GFM extensions. | High architectural impact; verified by comprehensive regression test suite preventing main actor deadlocks and UI freezes. |
| **0.3.1 Visual Styling** | Design token integration with dynamic color schemes, tokenized border line widths, adaptive table column widths, and horizontal scrolling for narrow window viewports. | Text clipping in horizontal scroll containers avoided through explicit per-column width proposals and vertically ideal text sizing. |
| **0.3.2 Media & Network** | Outgoing network connection support for remote image loading with placeholder fallback cards, accompanied by local relative resolution and accessible alt text tags. | User permission boundaries enforced; invalid or unreachable URLs gracefully degrade to branded fallback cards without blocking main actor. |

### Standard Table with Per-Column Colon Alignment

| Feature | Alignment | Description | Status |
| :--- | :---: | ---: | :---: |
| Native Grid | Left | Automatically distributes column widths | Complete |
| Text Alignment | Center | Left, Center, or Right based on colons | Complete |
| Cell Overflow | Right | Smooth horizontal scrolling | Complete |
| Inline Styling | Left | Supports **bold**, *italic*, `code`, and [links](https://example.com) | Complete |

### Escaped Pipes and Code Spans with Pipes

| Command | Pipe Example | Explanation |
| :--- | :--- | :--- |
| Escaped pipe | Value 1 \| Value 2 | The escaped pipe `\|` remains part of the cell text |
| Code with pipe | `cat file \| grep pattern` | The pipe inside backticks is not a column divider |
| Combined | `find . -name "*.swift"` \| wc -l | Escaped pipe outside `\|` and command inside |

### Tables without Outer Boundary Pipes

Category | Priority | Estimate (Days)
--- | :---: | ---:
Engine | High | 3
Design System | Medium | 2
Documentation | Low | 1

### Uneven Rows (Missing & Extra Cells)

| Column 1 | Column 2 | Column 3 |
| --- | --- | --- |
| Full row A | Full row B | Full row C |
| Only Column 1 |
| Row with | Extra cell 3 | Extra cell 4 | Extra ignored cell 5 |

### Wide Table (Horizontal Scroll Verification)

| Field ID | Parameter Name | Data Type | Default Value | Nullable | Validation Rules | Description and Purpose Notes |
| :--- | :--- | :---: | :---: | :---: | :--- | :--- |
| 1001 | `client_session_token` | UUIDv4 | `nil` | No | RFC 4122 compliance | Ephemeral authentication token passed in secure request headers |
| 1002 | `retry_backoff_multiplier` | Float64 | `1.50` | No | Range `[1.0, 5.0]` | Exponential backoff growth factor for transient network timeouts |
| 1003 | `maximum_concurrency_slots` | Int32 | `8` | Yes | Range `[1, 64]` | Thread pool allocation ceiling for asynchronous parsing jobs |
| 1004 | `preferred_typography_mode` | String | `"allSystem"` | No | Member of mode set | Visual font rendering profile selected in Marky Preferences |

---

## 4. Lists & Task Checkboxes

### Unordered Lists with Continuations

- First item in the list
  This is a continuation line for the first item that belongs to the same bullet point.
- Second item in the list
- Third item with sub-items:
  - Indented child item A
  - Indented child item B
    - Deeply nested grandchild item

### Ordered Lists

1. Initialize project session
2. Parse Markdown document structure
   Continuation text explaining the parsing phase in greater detail.
3. Render SwiftUI blocks with theme tokens
4. Present in reader view

### Task Lists (GFM)

- [x] Implement GFM pipe table parser
- [x] Support per-column alignment colons
- [x] Fix italic asterisk and underscore rendering
- [x] Support task checkboxes
- [x] Add horizontal scrolling for wide tables
- [ ] Manual verification in macOS reader by user

---

## 5. Blockquotes

> "Simplicity is prerequisite for reliability."
> — Edsger W. Dijkstra

### Multi-line & Nested Quotes

> Blockquotes can span multiple paragraphs and lines.
>
> They can also contain inline styles such as **bold text**, *italic emphasis*, and `inline code`.
>> Nested blockquotes are indented further to show quoted context inside quotes.
> Back to top-level quote.

---

## 6. Links & Autolinks

- Standard link: [Marky on GitHub](https://github.com)
- Link with title: [Apple Developer](https://developer.apple.com "Official Apple Developer Documentation")
- Direct autolink: <https://www.apple.com>
- Mailto autolink: <mailto:hello@example.com>

---

## 7. Code Blocks (Fenced & Literal)

```swift
import SwiftUI

struct HelloMarkyView: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text("Native macOS Markdown Reader")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
```

Tilde fence block:

~~~markdown
# Literal Markdown Inside Tilde Fences
| Not | A | Table |
| --- | - | ----- |
*Not italic* and **not bold**
~~~

---

## 8. Thematic Breaks (Dividers)

Hyphen break:

---

Asterisk break:

***

Underscore break:

___

Spaced hyphen break:

- - -

---

## 9. Images (Native Presentation)

Standalone image block:

![Marky Mascot](../Marky/Assets.xcassets/MarkyMascot.imageset/marky-mascot.png "Marky Native Mascot Artwork")

Inline image reference in text: The mascot image ![Marky Icon](../Marky/Assets.xcassets/MarkyMascot.imageset/marky-mascot.png) appears inline within this sentence.
