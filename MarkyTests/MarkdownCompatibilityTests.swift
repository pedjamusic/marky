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
            // Compare encoded bytes: Swift String equality alone hides normalization changes.
            #expect(try encoded(actual) == encoded(fixture.blocks), "Fixture \(fixture.id)")

            let rendered = MarkdownContentBlocks.render(
                preparedBlocks: prepared, mode: .allSystem, isDarkMode: false
            )
            let visible = rendered.flatMap(visibleText)
            let expected = fixture.blocks.flatMap(expectedVisibleText)
            #expect(try encoded(visible) == encoded(expected), "Production display text: \(fixture.id)")
        }
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Hex prevents String's canonical-equivalence comparison from hiding normalization changes.
        return try encoder.encode(value).map { String(format: "%02x", $0) }.joined()
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
            let lines = source.components(separatedBy: "\n").map { line in
                var body = line.trimmingCharacters(in: .whitespaces)
                var depth = 0
                while body.hasPrefix(">") {
                    depth += 1
                    body = String(body.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                return QuoteLine(depth: depth, runs: inline(body))
            }
            return Block(kind: "quote", lines: lines)
        case .table(let headers, let alignments, let rows):
            return Block(kind: "table", headers: headers.map(inline),
                         alignments: alignments.map(\.rawValue), rows: rows.map { $0.map(inline) })
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
