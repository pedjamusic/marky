#ifndef MARKY_INLINE_SYNTAX_H
#define MARKY_INLINE_SYNTAX_H

#include "LiteralSyntax.h"

#include <cstdint>
#include <vector>

namespace marky {

enum class InlineTokenKind { text, literal, code, line_break };

enum class InlineTrait : std::uint8_t { none = 0, emphasis = 1, strong = 2, strikethrough = 4 };

constexpr InlineTrait operator|(InlineTrait left, InlineTrait right) {
    return static_cast<InlineTrait>(static_cast<unsigned>(left) | static_cast<unsigned>(right));
}

struct InlineToken {
    InlineTokenKind kind;
    // Half-open byte range in the prepared UTF-8 source.
    std::size_t begin;
    std::size_t end;
    std::string text;
    InlineTrait traits = InlineTrait::none;
};

// Paragraph preparation has already folded soft lines to spaces. Only text
// tokens can contain delimiters for later inline passes. Escapes and entities
// yield literal tokens even when their output contains syntax or a newline.
class InlineScanner {
public:
    explicit InlineScanner(std::string_view source) : source(source), spans(source) {}

    std::optional<InlineToken> next();

private:
    std::optional<InlineToken> next_special();

    std::string_view source;
    CodeSpanMatcher spans;
    std::size_t cursor = 0;
    std::optional<InlineToken> pending;
};

// Resolve styles in one prepared region of validated UTF-8. Consumed delimiters
// are gaps between the returned source ranges.
std::vector<InlineToken> resolve_inline(std::string_view source);

}

#endif
