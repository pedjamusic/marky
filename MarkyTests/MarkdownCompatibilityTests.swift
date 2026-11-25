import AppKit
import Foundation
import Testing
@testable import Marky

/// Checks native core rendering against the shared fixtures.
@MainActor
struct MarkdownCompatibilityTests {
    @Test("The native reader renders every shared fixture's structure, text and inline semantics")
    func nativeCorpus() async throws {
        for fixture in try loadCorpus().fixtures {
            let document = try await CoreMarkdownParser.parse(fixture.input)
            let rendered = MarkdownContentBlocks.render(coreDocument: document, mode: .allSystem, isDarkMode: false)
            let actual = document.blocks.enumerated().map { project($1, at: $0, in: document) }
            let diagnostic = try describe(actual)
            // Compare encoded bytes: Swift String equality alone hides normalization changes.
            #expect(try encoded(actual) == encoded(fixture.blocks), "Fixture \(fixture.id): \(diagnostic)")

            let visible = rendered.flatMap(visibleText)
            let expected = fixture.blocks.flatMap(expectedVisibleText)
            #expect(try encoded(visible) == encoded(expected), "Display text: \(fixture.id)")
            #expect(rendered.map(\.id) == Array(fixture.blocks.indices), "Block identity: \(fixture.id)")
            #expect(rendered.map(renderedShape) == fixture.blocks.map(expectedShape), "Block metadata: \(fixture.id)")
        }
    }

    @Test("Every shared fixture uses the native base style of its block role")
    func nativeCorpusBaseStyles() async throws {
        let typography = MarkdownTypography(mode: .allSystem)
        for fixture in try loadCorpus().fixtures {
            for block in try await coreBlocks(fixture.input) {
                let context = "Fixture \(fixture.id), block \(block.id)"
                switch block.kind {
                case .heading(let level, let text):
                    expectBaseStyle(text, font: typography.headingFont(for: level), kern: typography.headingTracking,
                                    lineHeight: typography.headingLineHeight(for: level), context)
                case .paragraph(let text), .quote(let text):
                    expectBaseStyle(text, font: typography.bodyFont(), kern: typography.bodyTracking,
                                    lineHeight: typography.bodyLineHeightMultiple, context)
                case .list(let items):
                    for item in items {
                        expectBaseStyle(item.body, font: typography.bodyFont(), kern: typography.bodyTracking,
                                        lineHeight: typography.bodyLineHeightMultiple, context)
                    }
                case .table(let table):
                    for cell in table.headers {
                        expectBaseStyle(cell.content, font: typography.bodyFont(), kern: typography.bodyTracking,
                                        lineHeight: typography.bodyLineHeightMultiple, bold: true, context)
                    }
                    for cell in table.rows.flatMap(\.cells) {
                        expectBaseStyle(cell.content, font: typography.bodyFont(), kern: typography.bodyTracking,
                                        lineHeight: typography.bodyLineHeightMultiple, context)
                    }
                case .code, .image, .thematicBreak:
                    break
                }
            }
        }
    }

    /// Everything the view reads from a rendered block besides its text.
    private func renderedShape(_ block: MarkdownRenderedBlock) -> [String] {
        switch block.kind {
        case .heading(let level, _): ["heading", String(level)]
        case .paragraph: ["paragraph"]
        case .quote: ["quote"]
        case .code(let text): ["code", text]
        case .list(let items): ["list"] + items.flatMap { [String($0.id), String($0.nestingLevel), $0.marker] }
        case .table(let table):
            ["table"] + ([table.headers] + table.rows.map(\.cells)).flatMap { cells in
                [String(cells.count)] + cells.map(\.alignment.rawValue)
            }
        case .image(let alt, let url, let title): ["image", alt, url] + (title.map { [$0] } ?? [])
        case .thematicBreak: ["thematicBreak"]
        }
    }

    private func expectedShape(_ block: Block) -> [String] {
        let typography = MarkdownTypography(mode: .allSystem)
        switch block.kind {
        case "heading": return ["heading", String(block.level ?? 0)]
        case "code": return ["code", block.text ?? ""]
        case "list":
            return ["list"] + (block.items ?? []).enumerated().flatMap { index, item in
                let marker = switch item.marker {
                case "bullet": "•"
                case "taskUnchecked": typography.checkboxUncheckedSymbol
                case "taskChecked": typography.checkboxCheckedSymbol
                default: item.marker
                }
                return [String(index), String(item.depth), marker]
            }
        case "table":
            let alignments = block.alignments ?? []
            let row = [String(alignments.count)] + alignments
            return ["table"] + Array(repeating: row, count: (block.rows?.count ?? 0) + 1).flatMap { $0 }
        case "image": return ["image", block.alt ?? "", block.destination ?? ""] + (block.title.map { [$0] } ?? [])
        default: return [block.kind]
        }
    }

    private func expectBaseStyle(
        _ content: AttributedString, font: NSFont, kern: CGFloat, lineHeight: CGFloat,
        bold: Bool = false, _ context: String
    ) {
        let text = NSAttributedString(content)
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, _, _ in
            #expect((attributes[.kern] as? CGFloat) == kern, "\(context)")
            let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle
            #expect(paragraph?.lineHeightMultiple == lineHeight, "\(context)")
            #expect(paragraph?.paragraphSpacing == 0, "\(context)")
            // Code and links replace parts of the base style.
            guard attributes[.backgroundColor] == nil, let actual = attributes[.font] as? NSFont else { return }
            #expect(actual.pointSize == font.pointSize, "\(context)")
            #expect(actual.familyName == font.familyName, "\(context)")
            if attributes[.link] == nil {
                #expect((attributes[.foregroundColor] as? NSColor) == NSColor.labelColor, "\(context)")
            }
            if bold {
                #expect(NSFontManager.shared.traits(of: actual).contains(.boldFontMask), "\(context)")
            }
        }
    }

    @Test("Core fences protect literals in shared reference fixtures")
    func coreFenceReferences() async throws {
        // Definition discovery will change the surrounding paragraph blocks in T10.S2.
        let ids: Set = ["MD-034", "MD-075"]
        let fixtures = try loadCorpus().fixtures.filter { ids.contains($0.id) }
        #expect(Set(fixtures.map(\.id)) == ids)
        for fixture in fixtures {
            let document = try await CoreMarkdownParser.parse(fixture.input)
            let code = document.blocks.compactMap { block -> [UInt8]? in
                guard case .code(let text) = block else { return nil }
                return Array(text.utf8)
            }
            #expect(code == literalBytes(fixture), "Literal code: \(fixture.id)")
        }
    }

    @Test("Core images retain shared fixture metadata and leave fallback source in prose")
    func coreImages() async throws {
        let ids: Set = ["MD-037", "MD-038", "MD-039", "MD-079", "MD-080", "MD-081", "MD-082", "MD-083", "MD-090"]
        let fixtures = try loadCorpus().fixtures.filter { ids.contains($0.id) }
        #expect(Set(fixtures.map(\.id)) == ids)
        for fixture in fixtures {
            let document = try await CoreMarkdownParser.parse(fixture.input)
            let kinds = document.blocks.map(kind)
            if fixture.id == "MD-082" {
                // T10.S3 will interpret the remaining image syntax as alt text.
                #expect(document.blocks == [.paragraph("![pic][asset]")])
                continue
            }
            #expect(kinds == fixture.blocks.map(\.kind), "Block order: \(fixture.id)")
            for (block, expected) in zip(document.blocks, fixture.blocks) {
                if case .image(let alt, let destination, let title) = block {
                    #expect(Array(alt.utf8) == expected.alt.map { Array($0.utf8) }, "Alt: \(fixture.id)")
                    #expect(Array(destination.utf8) == expected.destination.map { Array($0.utf8) },
                            "Destination: \(fixture.id)")
                    #expect(title.map { Array($0.utf8) } == expected.title.map { Array($0.utf8) },
                            "Title: \(fixture.id)")
                } else if case .paragraph(let source) = block {
                    #expect(Array(source.utf8) == Array(fixture.input.utf8), "Fallback source: \(fixture.id)")
                }
            }
        }

        let document = try await CoreMarkdownParser.parse("![](first.png '')\n![](second.png)")
        #expect(document.blocks == [
            .image(alt: "", destination: "first.png", title: ""),
            .image(alt: "", destination: "second.png", title: nil),
        ])
    }

    private func kind(_ block: CoreMarkdownDocument.Block) -> String {
        switch block {
        case .heading: "heading"
        case .paragraph: "paragraph"
        case .code: "code"
        case .thematicBreak: "thematicBreak"
        case .list: "list"
        case .quote: "quote"
        case .table: "table"
        case .image: "image"
        }
    }

    private func literalBytes(_ fixture: Fixture) -> [[UInt8]] {
        fixture.blocks.filter { $0.kind == "code" }.compactMap { $0.text.map { Array($0.utf8) } }
    }

    @Test("Corpus identities, provenance and expected shapes are valid")
    func corpusIntegrity() throws {
        let corpus = try loadCorpus()
        #expect(corpus.version == 1)
        #expect(!corpus.fixtures.isEmpty)
        #expect(Set(corpus.fixtures.map(\.id)).count == corpus.fixtures.count)
        for fixture in corpus.fixtures {
            #expect(fixture.id.hasPrefix("MD-"))
            #expect(!fixture.evidence.isEmpty, "Missing provenance: \(fixture.id)")
            #expect(!fixture.requirements.isEmpty)
            for block in fixture.blocks {
                let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(block)) as? [String: Any])
                let required: Set<String>
                switch block.kind {
                case "heading": required = ["kind", "level", "runs"]
                case "paragraph": required = ["kind", "runs"]
                case "code": required = ["kind", "text"]
                case "list": required = ["kind", "items"]
                case "quote": required = ["kind", "lines"]
                case "table": required = ["kind", "headers", "alignments", "rows"]
                case "image": required = block.title == nil ? ["kind", "alt", "destination"] : ["kind", "alt", "destination", "title"]
                case "thematicBreak": required = ["kind"]
                default:
                    Issue.record("Unknown block kind in \(fixture.id)")
                    continue
                }
                #expect(Set(fields.keys) == required, "Block shape: \(fixture.id)")
            }
        }
    }

    private func loadCorpus() throws -> Corpus {
        let url = try #require(Bundle(for: CompatibilityBundle.self).url(
            forResource: "markdown-compatibility", withExtension: "json"
        ))
        return try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
    }

    private func encoded<T: Encodable>(_ value: T) throws -> String {
        // Hex prevents String's canonical-equivalence comparison from hiding normalization changes.
        try json(value).map { String(format: "%02x", $0) }.joined()
    }

    private func describe<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try json(value), as: UTF8.self)
    }

    private func json<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private func project(
        _ block: CoreMarkdownDocument.Block, at index: Int, in document: CoreMarkdownDocument
    ) -> Block {
        // Default inline styling keeps the heading and table-header base weight out of the semantic traits.
        func inline(row: Int = 0, column: Int = 0) -> [Run] {
            runs(MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: index, row: row, column: column)))
        }
        switch block {
        case .heading(let level, _):
            return Block(kind: "heading", level: level, runs: inline())
        case .paragraph:
            return Block(kind: "paragraph", runs: inline())
        case .code(let text):
            return Block(kind: "code", text: text)
        case .thematicBreak:
            return Block(kind: "thematicBreak")
        case .image(let alt, let url, let title):
            return Block(kind: "image", alt: alt, destination: url, title: title)
        case .list(let items):
            return Block(kind: "list", items: items.enumerated().map { row, item in
                let marker = switch item.marker {
                case .bullet: "bullet"
                case .ordered(let spelling): spelling
                case .task(checked: false): "taskUnchecked"
                case .task(checked: true): "taskChecked"
                }
                return Item(depth: item.depth, marker: marker, runs: inline(row: row))
            })
        case .quote(let source):
            let rendered = MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: index))
            var offset = 0
            let lines = rendered.string.components(separatedBy: "\n").enumerated().map { number, line in
                let length = (line as NSString).length
                let depth = number < source.count ? source[number].depth : 1
                #expect(number < source.count, "Quote line count must retain source depth mapping")
                let indicator = String(repeating: MarkdownContentBlocks.nestedQuoteIndicator, count: max(0, depth - 1))
                #expect(line.hasPrefix(indicator), "Quote indicator")
                let skip = (indicator as NSString).length
                let body = NSRange(location: offset + skip, length: max(0, length - skip))
                offset += length + 1
                return QuoteLine(depth: depth, runs: runs(rendered.attributedSubstring(from: body)))
            }
            #expect(lines.count == source.count)
            return Block(kind: "quote", lines: lines)
        case .table(let table):
            return Block(
                kind: "table",
                headers: table.alignments.indices.map { inline(column: $0) },
                alignments: table.alignments.map(\.rawValue),
                rows: table.rows.indices.map { row in
                    table.alignments.indices.map { inline(row: row + 1, column: $0) }
                }
            )
        }
    }

    private func runs(_ text: NSAttributedString) -> [Run] {
        var result: [Run] = []
        var offset = 0
        // Walk Unicode scalars and check every UTF-16 code unit, including surrogate pairs.
        for scalar in text.string.unicodeScalars {
            let value = String(scalar)
            let length = value.utf16.count
            let run = semanticRun(text.attributes(at: offset, effectiveRange: nil), text: value)
            for unit in offset..<(offset + length) {
                #expect(semanticRun(text.attributes(at: unit, effectiveRange: nil), text: value) == run)
            }
            if let last = result.last, last.traits == run.traits, last.destination == run.destination {
                result[result.count - 1].text += value
            } else {
                result.append(run)
            }
            offset += length
        }
        return result
    }

    private func semanticRun(_ attributes: [NSAttributedString.Key: Any], text: String) -> Run {
        var traits: [String] = []
        if let font = attributes[.font] as? NSFont {
            let fontTraits = NSFontManager.shared.traits(of: font)
            if fontTraits.contains(.boldFontMask) { traits.append("strong") }
            if fontTraits.contains(.italicFontMask) || (attributes[.obliqueness] as? NSNumber)?.doubleValue ?? 0 != 0 {
                traits.append("emphasis")
            }
        }
        if (attributes[.strikethroughStyle] as? NSNumber)?.intValue ?? 0 != 0 { traits.append("strike") }
        if attributes[.backgroundColor] != nil { traits.append("code") }
        return Run(text: text, traits: traits, destination: (attributes[.link] as? URL)?.absoluteString)
    }

    private func visibleText(_ block: MarkdownRenderedBlock) -> [String] {
        switch block.kind {
        case .heading(_, let text), .paragraph(let text), .quote(let text): return [String(text.characters)]
        case .code(let text): return [text]
        case .list(let items): return items.map { String($0.body.characters) }
        case .table(let table):
            return table.headers.map { String($0.content.characters) }
                + table.rows.flatMap { $0.cells.map { String($0.content.characters) } }
        case .image(let alt, _, _): return [alt]
        case .thematicBreak: return []
        }
    }

    private func expectedVisibleText(_ block: Block) -> [String] {
        func text(_ runs: [Run]) -> String { runs.map(\.text).joined() }
        switch block.kind {
        case "heading", "paragraph": return [text(block.runs ?? [])]
        case "code": return [block.text ?? ""]
        case "list": return (block.items ?? []).map { text($0.runs) }
        case "quote":
            return [(block.lines ?? []).map {
                String(repeating: "▎ ", count: max(0, $0.depth - 1)) + text($0.runs)
            }.joined(separator: "\n")]
        case "table": return (block.headers ?? []).map(text) + (block.rows ?? []).flatMap { $0.map(text) }
        case "image": return [block.alt ?? ""]
        default: return []
        }
    }
}

private final class CompatibilityBundle: NSObject {}

private struct Corpus: Decodable {
    let version: Int
    let fixtures: [Fixture]
}

private struct Fixture: Decodable {
    let id: String
    let requirements: [String]
    let evidence: [String]
    let input: String
    let blocks: [Block]
}

private struct Block: Codable {
    var kind: String
    var level: Int? = nil
    var runs: [Run]? = nil
    var text: String? = nil
    var items: [Item]? = nil
    var lines: [QuoteLine]? = nil
    var headers: [[Run]]? = nil
    var alignments: [String]? = nil
    var rows: [[[Run]]]? = nil
    var alt: String? = nil
    var destination: String? = nil
    var title: String? = nil
}

private struct Run: Codable, Equatable {
    var text: String
    var traits: [String]
    var destination: String? = nil
}

private struct Item: Codable {
    let depth: Int
    let marker: String
    let runs: [Run]
}

private struct QuoteLine: Codable {
    let depth: Int
    let runs: [Run]
}
