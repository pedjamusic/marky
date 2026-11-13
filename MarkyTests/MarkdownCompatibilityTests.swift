import AppKit
import Foundation
import Testing
@testable import Marky

/// A projection of the current production path, not a second Markdown parser.
@MainActor
struct MarkdownCompatibilityTests {
    @Test("Shared fixtures agree with production preparation and inline semantics")
    func productionCorpus() throws {
        let corpus = try loadCorpus()
        for fixture in corpus.fixtures {
            let prepared = MarkdownContentBlocks.prepare(from: fixture.input)
            let actual = prepared.map(project)
            let diagnostic = try describe(actual)
            // Compare encoded bytes: Swift String equality alone hides normalization changes.
            #expect(try encoded(actual) == encoded(fixture.blocks), "Fixture \(fixture.id): \(diagnostic)")

            let rendered = MarkdownContentBlocks.render(
                preparedBlocks: prepared, mode: .allSystem, isDarkMode: false
            )
            let visible = rendered.flatMap(visibleText)
            let expected = fixture.blocks.flatMap(expectedVisibleText)
            #expect(try encoded(visible) == encoded(expected), "Production display text: \(fixture.id)")

            if let legacy = fixture.legacyRuns {
                let actual = runs(MarkdownRenderer.render(from: fixture.input))
                let diagnostic = try describe(actual)
                #expect(try encoded(actual) == encoded(legacy),
                        "Older line-based helper \(fixture.id): \(diagnostic)")
            }
            if let inline = fixture.inlineRuns {
                let actual = runs(MarkdownRenderer.renderInline(from: fixture.input))
                let diagnostic = try describe(actual)
                #expect(try encoded(actual) == encoded(inline),
                        "Direct inline seam \(fixture.id): \(diagnostic)")
            }
        }
    }

    @Test("Core base blocks match the shared corpus and Swift preparation")
    func coreBaseBlocks() async throws {
        let ids: Set = [
            "MD-001", "MD-002", "MD-003", "MD-004", "MD-005", "MD-006", "MD-007",
            "MD-008", "MD-009", "MD-010", "MD-011", "MD-012", "MD-040", "MD-041",
            "MD-044", "MD-045", "MD-046", "MD-047", "MD-048", "MD-049", "MD-050",
            "MD-051", "MD-052", "MD-053", "MD-054", "MD-055", "MD-056", "MD-057",
            "MD-084", "MD-085", "MD-086", "MD-087",
        ]
        let fixtures = try loadCorpus().fixtures.filter { ids.contains($0.id) }
        #expect(Set(fixtures.map(\.id)) == ids)
        for fixture in fixtures {
            let document = try await CoreMarkdownParser.parse(fixture.input)
            let actual = document.blocks.map(projectCoreBlock)
            let prepared = MarkdownContentBlocks.prepare(from: fixture.input)
            let expected = prepared.compactMap { block -> BaseBlock? in
                switch block.kind {
                case .heading(let level, let source):
                    return BaseBlock(kind: "heading", level: level, bytes: Array(source.utf8))
                case .paragraph(let source):
                    return BaseBlock(kind: "paragraph", bytes: Array(source.utf8))
                case .code(let text):
                    return BaseBlock(kind: "code", bytes: Array(text.utf8))
                case .thematicBreak:
                    return BaseBlock(kind: "thematicBreak")
                default:
                    Issue.record("Unexpected prepared block in \(fixture.id)")
                    return nil
                }
            }
            #expect(actual == expected, "Prepared source: \(fixture.id)")
            #expect(actual.map(\.kind) == fixture.blocks.map(\.kind), "Block order: \(fixture.id)")
            #expect(actual.map(\.level) == fixture.blocks.map(\.level), "Heading levels: \(fixture.id)")
            #expect(actual.filter { $0.kind == "code" }.compactMap(\.bytes) == literalBytes(fixture),
                    "Literal code: \(fixture.id)")
        }
    }

    @Test("Core quote lines retain shared fixture depth, prepared source and block order")
    func coreQuotes() async throws {
        let fixtures = try loadCorpus().fixtures.filter { $0.blocks.contains { $0.kind == "quote" } }
        #expect(Set(fixtures.map(\.id)).isSuperset(of: ["MD-019", "MD-024", "MD-058", "MD-060", "MD-061", "MD-071"]))
        for fixture in fixtures {
            let document = try await CoreMarkdownParser.parse(fixture.input)
            let prepared = MarkdownContentBlocks.prepare(from: fixture.input)
            #expect(document.blocks.map(projectCoreBlock).map(\.kind) == fixture.blocks.map(\.kind),
                    "Block order: \(fixture.id)")
            for (index, block) in document.blocks.enumerated() {
                guard case .quote(let lines) = block else { continue }
                guard fixture.blocks.indices.contains(index), let expected = fixture.blocks[index].lines,
                      prepared.indices.contains(index), case .quote(let source) = prepared[index].kind
                else {
                    Issue.record("Unexpected quote block in \(fixture.id)")
                    continue
                }
                let bodies = quoteBodies(from: source)
                #expect(lines.map(\.depth) == expected.map(\.depth), "Quote depth: \(fixture.id)")
                #expect(lines.map { Array($0.source.utf8) } == bodies.map { Array($0.body.utf8) },
                        "Prepared quote source: \(fixture.id)")
            }
        }
    }

    private func projectCoreBlock(_ block: CoreMarkdownDocument.Block) -> BaseBlock {
        switch block {
        case .heading(let level, let source):
            BaseBlock(kind: "heading", level: level, bytes: Array(source.utf8))
        case .paragraph(let source):
            BaseBlock(kind: "paragraph", bytes: Array(source.utf8))
        case .code(let text):
            BaseBlock(kind: "code", bytes: Array(text.utf8))
        case .thematicBreak:
            BaseBlock(kind: "thematicBreak")
        case .list:
            BaseBlock(kind: "list")
        case .quote:
            BaseBlock(kind: "quote")
        case .table:
            BaseBlock(kind: "table")
        case .image:
            BaseBlock(kind: "image")
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

    @Test("Core list items match shared fixture order, marker state, depth and prepared source")
    func coreLists() async throws {
        let ids: Set = ["MD-015", "MD-016", "MD-017", "MD-018", "MD-058", "MD-059", "MD-061", "MD-067", "MD-071"]
        let fixtures = try loadCorpus().fixtures.filter { ids.contains($0.id) }
        #expect(Set(fixtures.map(\.id)) == ids)
        for fixture in fixtures {
            let document = try await CoreMarkdownParser.parse(fixture.input)
            let prepared = MarkdownContentBlocks.prepare(from: fixture.input)
            let lists: [(index: Int, items: [CoreMarkdownDocument.ListItem])] = document.blocks.enumerated().compactMap { index, block in
                if case .list(let items) = block { return (index, items) }
                return nil
            }
            #expect(lists.map(\.index) == fixture.blocks.indices.filter { fixture.blocks[$0].kind == "list" },
                    "List block order: \(fixture.id)")
            for (index, items) in lists {
                guard fixture.blocks.indices.contains(index), let expected = fixture.blocks[index].items,
                      prepared.indices.contains(index), case .list(let swiftItems) = prepared[index].kind
                else {
                    Issue.record("Unexpected list block in \(fixture.id)")
                    continue
                }
                let markers: [String] = items.map { item in
                    switch item.marker {
                    case .bullet: "bullet"
                    case .ordered(let spelling): spelling
                    case .task(checked: false): "taskUnchecked"
                    case .task(checked: true): "taskChecked"
                    }
                }
                #expect(markers.map { Array($0.utf8) } == expected.map { Array($0.marker.utf8) },
                        "List markers: \(fixture.id)")
                #expect(items.map(\.depth) == expected.map(\.depth), "List depth: \(fixture.id)")
                #expect(items.map { Array($0.source.utf8) } == swiftItems.map { Array($0.body.utf8) },
                        "Prepared list source: \(fixture.id)")
            }
        }
    }

    @Test("Core tables match shared fixture order, alignment and prepared cell bytes")
    func coreTables() async throws {
        let ids: Set = [
            "MD-020", "MD-021", "MD-022", "MD-023", "MD-024", "MD-025", "MD-026",
            "MD-062", "MD-063", "MD-064", "MD-065", "MD-066", "MD-067", "MD-068",
            "MD-088", "MD-089", "MD-090", "MD-091", "MD-092",
        ]
        let fixtures = try loadCorpus().fixtures.filter { ids.contains($0.id) }
        #expect(Set(fixtures.map(\.id)) == ids)
        for fixture in fixtures {
            let document = try await CoreMarkdownParser.parse(fixture.input)
            let prepared = MarkdownContentBlocks.prepare(from: fixture.input)
            #expect(document.blocks.map(projectCoreBlock).map(\.kind) == fixture.blocks.map(\.kind),
                    "Block order: \(fixture.id)")
            for (index, block) in document.blocks.enumerated() {
                guard case .table(let table) = block else { continue }
                guard fixture.blocks.indices.contains(index),
                      prepared.indices.contains(index),
                      case .table(let headers, let alignments, let rows) = prepared[index].kind
                else {
                    Issue.record("Unexpected table block in \(fixture.id)")
                    continue
                }
                #expect(table.alignments.map(\.rawValue) == fixture.blocks[index].alignments,
                        "Alignment: \(fixture.id)")
                #expect(table.alignments == alignments, "Prepared alignment: \(fixture.id)")
                #expect(table.headers.map { Array($0.utf8) } == headers.map { Array($0.utf8) },
                        "Prepared headers: \(fixture.id)")
                #expect(table.rows.map { $0.map { Array($0.utf8) } } == rows.map { $0.map { Array($0.utf8) } },
                        "Prepared body: \(fixture.id)")
            }
        }
    }

    @Test("Core images retain shared fixture metadata and leave fallback source in prose")
    func coreImages() async throws {
        let ids: Set = ["MD-037", "MD-038", "MD-039", "MD-079", "MD-080", "MD-081", "MD-082", "MD-083", "MD-090"]
        let fixtures = try loadCorpus().fixtures.filter { ids.contains($0.id) }
        #expect(Set(fixtures.map(\.id)) == ids)
        for fixture in fixtures {
            let document = try await CoreMarkdownParser.parse(fixture.input)
            let kinds = document.blocks.map(projectCoreBlock).map(\.kind)
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

    private struct BaseBlock: Equatable {
        let kind: String
        var level: Int?
        var bytes: [UInt8]?
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

    private func project(_ block: MarkdownPreparedBlock) -> Block {
        func inline(_ source: String) -> [Run] {
            runs(MarkdownRenderer.renderInline(from: source, referenceLinks: block.referenceLinks))
        }
        switch block.kind {
        case .heading(let level, let source):
            return Block(kind: "heading", level: level, runs: inline(source))
        case .paragraph(let source):
            return Block(kind: "paragraph", runs: inline(source))
        case .code(let text):
            return Block(kind: "code", text: text)
        case .thematicBreak:
            return Block(kind: "thematicBreak")
        case .image(let alt, let url, let title):
            return Block(kind: "image", alt: alt, destination: url, title: title)
        case .list(let items):
            return Block(kind: "list", items: items.map { item in
                let marker: String
                switch item.marker {
                case "•": marker = "bullet"
                case "☐": marker = "taskUnchecked"
                case "☑": marker = "taskChecked"
                default: marker = item.marker
                }
                return Item(depth: item.nestingLevel, marker: marker, runs: inline(item.body))
            })
        case .quote(let source):
            let bodies = quoteBodies(from: source)
            // Production parses the whole quote once, so styles can cross source lines.
            let rendered = MarkdownRenderer.renderInline(
                from: bodies.map(\.body).joined(separator: "\n"), referenceLinks: block.referenceLinks
            )
            var offset = 0
            let lines = rendered.string.components(separatedBy: "\n").enumerated().map { index, line in
                let length = (line as NSString).length
                let content = rendered.attributedSubstring(from: NSRange(location: offset, length: length))
                offset += length + 1
                #expect(index < bodies.count, "Quote line count must retain source depth mapping")
                return QuoteLine(depth: index < bodies.count ? bodies[index].depth : 1, runs: runs(content))
            }
            #expect(lines.count == bodies.count)
            #expect(offset == rendered.length + 1)
            return Block(kind: "quote", lines: lines)
        case .table(let headers, let alignments, let rows):
            return Block(kind: "table", headers: headers.map(inline),
                         alignments: alignments.map(\.rawValue), rows: rows.map { $0.map(inline) })
        }
    }

    private func quoteBodies(from source: String) -> [(depth: Int, body: String)] {
        source.components(separatedBy: "\n").map { line in
            var body = line.trimmingCharacters(in: .whitespaces)
            var depth = 0
            while body.hasPrefix(">") {
                depth += 1
                body = String(body.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            return (depth: depth, body: body)
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
    let legacyRuns: [Run]?
    let inlineRuns: [Run]?
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
