#include "InlineSyntax.h"
#include "Utf8.h"
#include "generated/NamedEntities.h"
#include "generated/UnicodeData.h"

#include <algorithm>
#include <array>
#include <charconv>
#include <cstdint>
#include <iterator>
#include <utility>

namespace marky {
namespace {

using namespace std::string_view_literals;

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
        const auto entity = std::lower_bound(std::begin(named_entities), std::end(named_entities), name,
                                             [](const NamedEntity& entry, std::string_view value) {
                                                 return entry.name < value;
                                             });
        if (entity != std::end(named_entities) && entity->name == name) {
            return InlineToken{InlineTokenKind::literal, begin, begin + end + 2, std::string(entity->text)};
        }
    }
    return std::nullopt;
}

enum class Neighbor { whitespace, punctuation, other };

Neighbor classify_neighbor(std::string_view suffix) {
    if (suffix.empty()) {
        return Neighbor::whitespace;
    }
    const auto scalar = read_utf8_scalar(suffix);
    if (scalar <= 0x7F) {
        if (scalar == ' ' || (scalar >= '\t' && scalar <= '\r' && scalar != '\v')) {
            return Neighbor::whitespace;
        }
        return scalar != '~' && ascii_punctuation(static_cast<char>(scalar)) ?
            Neighbor::punctuation : Neighbor::other;
    }
    const auto contains = [scalar](const auto& ranges) {
        const auto range = std::ranges::lower_bound(ranges, scalar, {}, &unicode_data::ScalarRange::last);
        return range != std::end(ranges) && range->first <= scalar;
    };
    if (contains(unicode_data::inline_whitespace_ranges)) {
        return Neighbor::whitespace;
    }
    return contains(unicode_data::punctuation_ranges) ? Neighbor::punctuation : Neighbor::other;
}

Neighbor classify_previous(std::string_view source, std::size_t end) {
    if (end == 0) {
        return Neighbor::whitespace;
    }
    auto begin = end - 1;
    while ((static_cast<unsigned char>(source[begin]) & 0xC0) == 0x80) {
        --begin;
    }
    return classify_neighbor(source.substr(begin, end - begin));
}

enum class DelimiterKind { asterisk, underscore, tilde };

struct DelimiterRun {
    std::size_t begin;
    std::size_t length;
    DelimiterKind kind;
    bool can_open;
    bool can_close;
    std::size_t closing_bytes = 0;
    std::size_t opening_bytes = 0;
    InlineTrait opens = InlineTrait::none;
    InlineTrait closes = InlineTrait::none;

    std::size_t remaining() const { return length - closing_bytes - opening_bytes; }

    std::size_t opener_class() const {
        return (can_close ? 3 : 0) + length % 3;
    }
};

void collect_delimiters(std::vector<DelimiterRun>& runs, std::string_view source, const InlineToken& token) {
    const auto text = source.substr(token.begin, token.end - token.begin);
    for (std::size_t offset = 0; (offset = text.find_first_of("*_~", offset)) != text.npos;) {
        const auto marker = text[offset];
        const auto length = delimiter_run_length(text.substr(offset), marker);
        const auto begin = token.begin + offset;
        offset += length;
        if (marker == '~' && length > 2) {
            continue;
        }

        // Inspect source scalars even when a neighboring token decodes to different text.
        const auto end = begin + length;
        auto before = classify_previous(source, begin);
        auto after = classify_neighbor(source.substr(end));
        // Adjacent strike markers inherit the outer boundary for emphasis flanking.
        auto before_tildes = begin;
        while (before_tildes > 0 && source[before_tildes - 1] == '~') {
            --before_tildes;
        }
        if (before_tildes < begin && classify_previous(source, before_tildes) != Neighbor::other) {
            before = Neighbor::punctuation;
        }
        auto after_tildes = end;
        while (after_tildes < source.size() && source[after_tildes] == '~') {
            ++after_tildes;
        }
        if (after_tildes > end && classify_neighbor(source.substr(after_tildes)) != Neighbor::other) {
            after = Neighbor::punctuation;
        }
        const bool left_flanking = after != Neighbor::whitespace &&
            (after != Neighbor::punctuation || before != Neighbor::other);
        const bool right_flanking = before != Neighbor::whitespace &&
            (before != Neighbor::punctuation || after != Neighbor::other);
        const bool can_open = left_flanking && (marker != '_' || !right_flanking || before == Neighbor::punctuation);
        const bool can_close = right_flanking && (marker != '_' || !left_flanking || after == Neighbor::punctuation);
        if (can_open || can_close) {
            const auto kind = marker == '*' ? DelimiterKind::asterisk :
                              marker == '_' ? DelimiterKind::underscore : DelimiterKind::tilde;
            runs.push_back({begin, length, kind, can_open, can_close});
        }
    }
}

constexpr auto no_opener = std::string_view::npos;
using OpenerHeads = std::array<std::size_t, 6>;

std::size_t matching_opener(const DelimiterRun& closer, const OpenerHeads& heads) {
    auto latest = no_opener;
    const auto closer_remainder = closer.length % 3;
    for (std::size_t bucket = 0; bucket < heads.size(); ++bucket) {
        const auto opener_remainder = bucket % 3;
        // For runs that can serve both roles, the original widths govern the rule of three.
        if ((closer.can_open || bucket >= 3) && closer_remainder != 0 &&
            (opener_remainder + closer_remainder) % 3 == 0) {
            continue;
        }
        const auto position = heads[bucket];
        if (position != no_opener && (latest == no_opener || position > latest)) {
            latest = position;
        }
    }
    return latest;
}

bool match_delimiters(std::vector<DelimiterRun>& runs) {
    struct Opener {
        std::size_t run_index;
        std::size_t previous_in_class;
    };
    struct OpenerSearch {
        OpenerHeads heads;
        std::array<std::size_t, 3> first_run{};
    };
    std::vector<Opener> stack;
    std::array<OpenerSearch, 3> searches;
    for (auto& search : searches) {
        search.heads.fill(no_opener);
    }
    const auto pop = [&] {
        const auto& opener = stack.back();
        const auto& run = runs[opener.run_index];
        searches[static_cast<std::size_t>(run.kind)].heads[run.opener_class()] = opener.previous_in_class;
        stack.pop_back();
    };

    bool matched = false;
    for (std::size_t index = 0; index < runs.size(); ++index) {
        auto& closer = runs[index];
        auto& [heads, first_run] = searches[static_cast<std::size_t>(closer.kind)];
        auto& first_opener = first_run[closer.length % 3];
        while (closer.can_close && closer.remaining() > 0) {
            const auto position = matching_opener(closer, heads);
            if (position == no_opener || stack[position].run_index < first_opener) {
                // The reader excludes runs before a failed closer from later searches of this width class.
                first_opener = index;
                break;
            }
            // A pair rules out crossing matches. Restore each removed opener's class head.
            while (stack.size() - 1 > position) {
                pop();
            }
            auto& opener = runs[stack.back().run_index];
            if (closer.kind == DelimiterKind::tilde && opener.length != closer.length) {
                // Unequal strike runs stay visible but cannot pair with later runs.
                pop();
                break;
            }
            const auto width = std::min({opener.remaining(), closer.remaining(), std::size_t{2}});
            const auto trait = closer.kind == DelimiterKind::tilde ? InlineTrait::strikethrough :
                               width == 2 ? InlineTrait::strong : InlineTrait::emphasis;
            opener.opening_bytes += width;
            closer.closing_bytes += width;
            opener.opens = opener.opens | trait;
            closer.closes = closer.closes | trait;
            matched = true;
            if (opener.remaining() == 0) {
                pop();
            }
        }
        if (closer.can_open && closer.remaining() > 0) {
            auto& head = heads[closer.opener_class()];
            stack.push_back({index, head});
            head = stack.size() - 1;
        }
    }
    return matched;
}

InlineTrait remove_traits(InlineTrait traits, InlineTrait removed) {
    return static_cast<InlineTrait>(static_cast<unsigned>(traits) & ~static_cast<unsigned>(removed));
}

void append_text(std::vector<InlineToken>& result, std::string_view source,
                 std::size_t begin, std::size_t end, InlineTrait traits) {
    if (begin == end) {
        return;
    }
    const auto text = source.substr(begin, end - begin);
    if (!result.empty() && result.back().kind == InlineTokenKind::text &&
        result.back().end == begin && result.back().traits == traits) {
        result.back().text.append(text);
        result.back().end = end;
    } else {
        result.push_back({InlineTokenKind::text, begin, end, std::string(text), traits});
    }
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

std::vector<InlineToken> resolve_inline(std::string_view source) {
    std::vector<InlineToken> tokens;
    std::vector<DelimiterRun> runs;
    InlineScanner scanner(source);
    while (auto token = scanner.next()) {
        if (token->kind == InlineTokenKind::text) {
            collect_delimiters(runs, source, *token);
        }
        tokens.push_back(std::move(*token));
    }
    if (!match_delimiters(runs)) {
        return tokens;
    }

    std::vector<InlineToken> result;
    auto traits = InlineTrait::none;
    auto run = runs.cbegin();
    for (auto& token : tokens) {
        if (token.kind != InlineTokenKind::text) {
            token.traits = traits;
            result.push_back(std::move(token));
            continue;
        }
        auto cursor = token.begin;
        for (; run != runs.cend() && run->begin < token.end; ++run) {
            if (run->closing_bytes == 0 && run->opening_bytes == 0) {
                continue;
            }
            append_text(result, source, cursor, run->begin, traits);
            // The reader clears a trait at each close, including when an outer span uses it.
            traits = remove_traits(traits, run->closes);
            // A run can close on its left and reopen on its right, leaving literal bytes between.
            cursor = run->begin + run->length;
            append_text(result, source, run->begin + run->closing_bytes, cursor - run->opening_bytes, traits);
            traits = traits | run->opens;
        }
        append_text(result, source, cursor, token.end, traits);
    }
    return result;
}

}
