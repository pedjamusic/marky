#include "InlineSyntax.h"

#include <charconv>
#include <cstdint>
#include <utility>

namespace marky {
namespace {

using namespace std::string_view_literals;

// Provisional fixture data. T08.S3 replaces this subset with the pinned,
// reproducible named-entity table and reruns the same lexer checks.
constexpr std::pair<std::string_view, std::string_view> named_entities[] = {
    {"AMP", "&"}, {"GT", ">"}, {"LT", "<"}, {"NewLine", "\n"},
    {"NotEqualTilde", "\xE2\x89\x82\xCC\xB8"}, {"QUOT", "\""}, {"Tab", "\t"},
    {"amp", "&"}, {"apos", "'"}, {"copy", "\xC2\xA9"}, {"gt", ">"},
    {"lt", "<"}, {"nbsp", "\xC2\xA0"}, {"quot", "\""}
};

bool ascii_punctuation(char byte) {
    return (byte >= '!' && byte <= '/') || (byte >= ':' && byte <= '@') ||
           (byte >= '[' && byte <= '`') || (byte >= '{' && byte <= '~');
}

std::size_t line_ending_width(std::string_view source) {
    if (source.starts_with("\r\n")) {
        return 2;
    }
    return source.starts_with('\r') || source.starts_with('\n') ? 1 : 0;
}

std::string scalar_utf8(std::uint32_t scalar) {
    if (scalar == 0 || scalar > 0x10FFFF || (scalar >= 0xD800 && scalar <= 0xDFFF)) {
        return "\xEF\xBF\xBD";
    }
    if (scalar <= 0x7F) {
        return std::string(1, static_cast<char>(scalar));
    }
    const auto continuation = [scalar](unsigned shift) {
        return static_cast<char>(0x80 | ((scalar >> shift) & 0x3F));
    };
    std::string result;
    if (scalar <= 0x7FF) {
        result.push_back(static_cast<char>(0xC0 | (scalar >> 6)));
    } else {
        if (scalar > 0xFFFF) {
            result.push_back(static_cast<char>(0xF0 | (scalar >> 18)));
            result.push_back(continuation(12));
        } else {
            result.push_back(static_cast<char>(0xE0 | (scalar >> 12)));
        }
        result.push_back(continuation(6));
    }
    result.push_back(continuation(0));
    return result;
}

std::optional<InlineToken> entity_at(std::string_view source, std::size_t begin) {
    const auto body = source.substr(begin + 1);
    if (body.starts_with('#')) {
        const bool hex = body.starts_with("#x") || body.starts_with("#X");
        const auto digits_begin = begin + (hex ? 3 : 2);
        const auto digits = source.substr(digits_begin);
        // The current reader accepts up to eight digits in either base.
        const auto candidate = digits.substr(0, 8);
        std::uint32_t scalar = 0;
        const auto [end, error] = std::from_chars(candidate.data(), candidate.data() + candidate.size(),
                                                   scalar, hex ? 16 : 10);
        const auto count = static_cast<std::size_t>(end - digits.data());
        if (error == std::errc{} && count < digits.size() && digits[count] == ';') {
            return InlineToken{InlineTokenKind::literal, begin, digits_begin + count + 1,
                               scalar_utf8(scalar)};
        }
        return std::nullopt;
    }

    constexpr auto name_characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"sv;
    const auto end = body.find_first_not_of(name_characters);
    if (end != std::string_view::npos && body[end] == ';') {
        const auto name = body.substr(0, end);
        for (const auto& [key, value] : named_entities) {
            if (key == name) {
                return InlineToken{InlineTokenKind::literal, begin, begin + end + 2, std::string(value)};
            }
        }
    }
    return std::nullopt;
}

}

std::optional<InlineToken> InlineScanner::next_special() {
    while ((cursor = source.find_first_of("\\`&\r\n", cursor)) != std::string_view::npos) {
        const auto suffix = source.substr(cursor + 1);
        switch (source[cursor]) {
        case '\\':
            if (const auto width = line_ending_width(suffix)) {
                return InlineToken{InlineTokenKind::line_break, cursor, cursor + 1 + width, "\n"};
            }
            if (!suffix.empty() && ascii_punctuation(suffix.front())) {
                return InlineToken{InlineTokenKind::literal, cursor, cursor + 2, std::string(suffix.substr(0, 1))};
            }
            break;
        case '`':
            if (const auto length = backtick_run_length(source.substr(cursor))) {
                if (const auto span = spans.match(cursor, length)) {
                    return InlineToken{InlineTokenKind::code, span->begin, span->end, normalize_code_span(
                        source.substr(span->content_begin, span->content_end - span->content_begin))};
                }
                cursor += length;
                continue;
            }
            break;
        case '&':
            if (auto entity = entity_at(source, cursor)) {
                return entity;
            }
            break;
        default:
            return InlineToken{InlineTokenKind::line_break, cursor,
                               cursor + line_ending_width(source.substr(cursor)), "\n"};
        }
        ++cursor;
    }
    return std::nullopt;
}

std::optional<InlineToken> InlineScanner::next() {
    if (pending) {
        return std::exchange(pending, std::nullopt);
    }
    if (cursor >= source.size()) {
        return std::nullopt;
    }
    const auto begin = cursor;
    auto special = next_special();
    const auto text_end = special ? special->begin : source.size();
    cursor = special ? special->end : text_end;
    if (text_end == begin) {
        return special;
    }
    pending = std::move(special);
    return InlineToken{InlineTokenKind::text, begin, text_end, std::string(source.substr(begin, text_end - begin))};
}

}
