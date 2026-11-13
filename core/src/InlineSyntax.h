#ifndef MARKY_INLINE_SYNTAX_H
#define MARKY_INLINE_SYNTAX_H

#include "LiteralSyntax.h"

namespace marky {

enum class InlineTokenKind { text, literal, code, line_break };

struct InlineToken {
    InlineTokenKind kind;
    // Half-open byte range in the prepared UTF-8 source.
    std::size_t begin;
    std::size_t end;
    std::string text;
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

}

#endif
