#ifndef MARKY_INLINE_SYNTAX_H
#define MARKY_INLINE_SYNTAX_H

#include "LiteralSyntax.h"

#include <array>
#include <atomic>
#include <cstdint>
#include <memory>
#include <unordered_map>
#include <vector>

namespace marky {

enum class InlineTokenKind { text, literal, code, line_break, label };

struct InlineCancelled {};

enum class InlineTrait : std::uint8_t { none = 0, emphasis = 1, strong = 2, strikethrough = 4 };

constexpr InlineTrait operator|(InlineTrait left, InlineTrait right) {
    return static_cast<InlineTrait>(static_cast<unsigned>(left) | static_cast<unsigned>(right));
}

struct InlineLink {
    std::optional<std::string> destination;
    std::optional<std::string> title;
};

using ReferenceLinks = std::unordered_map<std::string, std::shared_ptr<const InlineLink>>;

std::optional<InlineLink> reference_target(std::string_view destination, std::optional<std::string_view> title);

struct InlineToken {
    InlineTokenKind kind;
    // Half-open byte range in the prepared UTF-8 source.
    std::size_t begin;
    std::size_t end;
    std::string text;
    InlineTrait traits = InlineTrait::none;
    std::shared_ptr<const InlineLink> link = {};
    std::shared_ptr<const InlineLink> image = {};
};

// Paragraph preparation has already folded soft lines to spaces. Only text
// tokens can contain delimiters for later inline passes. Escapes and entities
// yield literal tokens even when their output contains syntax or a newline.
class InlineScanner {
public:
    explicit InlineScanner(std::string_view source) : source(source), spans(source) {}

    std::optional<InlineToken> next();

private:
    friend std::vector<InlineToken> resolve_inline(std::string_view, const ReferenceLinks*, const std::atomic<bool>*);

    struct BracketMatch {
        std::size_t begin;
        std::size_t label_end;
        std::size_t end;
        bool image;
        std::shared_ptr<const InlineLink> target;
    };

    std::optional<InlineToken> next_special();
    std::optional<InlineToken> link_or_html_at_cursor();

    std::string_view source;
    CodeSpanMatcher spans;
    bool scan_links = false;
    const std::atomic<bool>* cancelled = nullptr;
    std::size_t cursor = 0;
    std::optional<InlineToken> pending;
    struct OpenBracket {
        std::size_t begin;
        bool image;
        std::size_t link_floor;
        bool contains_closed_bracket = false;
    };

    std::shared_ptr<const InlineLink> reference_link(const OpenBracket& bracket, std::size_t& end);

    const ReferenceLinks* references = nullptr;
    std::size_t reference_syntax_end = 0;
    bool missing_reference_close = false;
    std::size_t link_floor = 0;
    std::vector<OpenBracket> brackets;
    std::vector<BracketMatch> bracket_matches;
    std::array<bool, 4> missing_html_closers{};
    std::size_t bare_search_end = 0;
};

// Resolve styles and links in one prepared region of validated UTF-8. Consumed
// delimiters are gaps between the returned source ranges. Destinations are
// decoded Markdown data. URL serialization and opening belong to the host.
std::vector<InlineToken> resolve_inline(std::string_view source, const ReferenceLinks* references = nullptr,
                                        const std::atomic<bool>* cancelled = nullptr);

}

#endif
