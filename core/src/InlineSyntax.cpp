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

constexpr auto letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"sv;
constexpr auto digits = "0123456789"sv;
constexpr auto alphanumeric = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"sv;
constexpr auto link_space = " \t\r\n"sv;

bool escaped_punctuation(std::string_view source) {
    return source.size() >= 2 && source.front() == '\\' && ascii_punctuation(source[1]);
}

std::string decode_link_text(std::string_view source, bool unescape) {
    std::string result;
    for (std::size_t index = 0; index < source.size();) {
        if (unescape && escaped_punctuation(source.substr(index))) {
            result += source[index + 1];
            index += 2;
        } else if (auto entity = source[index] == '&' ? entity_at(source, index) : std::nullopt) {
            result += entity->text;
            index = entity->end;
        } else {
            result += source[index++];
        }
    }
    return result;
}

struct LinkTarget {
    std::size_t end;
    std::string_view destination;
    std::optional<std::string_view> title = std::nullopt;
};

std::size_t skip_space(std::string_view source, std::size_t begin) {
    return std::min(source.find_first_not_of(link_space, begin), source.size());
}

std::optional<LinkTarget> inline_target(std::string_view source) {
    if (!source.starts_with('(')) {
        return std::nullopt;
    }
    auto cursor = skip_space(source, 1);
    auto begin = cursor;
    const bool angle = source.substr(cursor).starts_with('<');
    if (angle) {
        begin = ++cursor;
        while (cursor < source.size() && source[cursor] != '>') {
            if (source[cursor] == '<' || line_ending_width(source.substr(cursor)) != 0) {
                return std::nullopt;
            }
            cursor += escaped_punctuation(source.substr(cursor)) ? 2 : 1;
        }
        if (cursor == source.size()) {
            return std::nullopt;
        }
    } else {
        unsigned depth = 0;
        while (cursor < source.size() && link_space.find(source[cursor]) == link_space.npos) {
            const char byte = source[cursor];
            if (byte == ')' && depth == 0) {
                break;
            }
            if (escaped_punctuation(source.substr(cursor))) {
                cursor += 2;
                continue;
            }
            if (byte == '(' && ++depth > 32) {
                return std::nullopt;
            }
            if (byte == ')') {
                --depth;
            }
            ++cursor;
        }
        if (depth != 0) {
            return std::nullopt;
        }
    }

    LinkTarget target{0, source.substr(begin, cursor - begin)};
    if (angle) {
        ++cursor;
    }
    const auto after_destination = cursor;
    cursor = skip_space(source, cursor);
    if (cursor != after_destination && cursor < source.size() && "\"'("sv.find(source[cursor]) != source.npos) {
        const char close = source[cursor] == '(' ? ')' : source[cursor];
        const auto title_begin = ++cursor;
        for (; cursor < source.size() && source[cursor] != close; ++cursor) {
            if (source[cursor] == '(' && close == ')') {
                return std::nullopt;
            }
            if (escaped_punctuation(source.substr(cursor))) {
                // A final backslash may precede the closing quote in the native parser.
                if (source[cursor + 1] != close || !source.substr(skip_space(source, cursor + 2)).starts_with(')')) {
                    ++cursor;
                }
            }
        }
        if (cursor == source.size()) {
            return std::nullopt;
        }
        target.title = source.substr(title_begin, cursor - title_begin);
        cursor = skip_space(source, cursor + 1);
    }
    if (!source.substr(cursor).starts_with(')')) {
        return std::nullopt;
    }
    target.end = cursor + 1;
    return target;
}

bool scheme(std::string_view name) {
    return !name.empty() && letters.find(name.front()) != letters.npos &&
        std::ranges::all_of(name.substr(1), [](char byte) {
            return alphanumeric.find(byte) != alphanumeric.npos || "+-."sv.find(byte) != alphanumeric.npos;
        });
}

std::optional<std::string> portable_destination(std::string destination) {
    const auto first = destination.find_first_of(":/?#");
    auto authority = std::string_view(destination);
    if (first != destination.npos && destination[first] == ':') {
        if (!scheme(authority.substr(0, first))) {
            return std::nullopt;
        }
        authority.remove_prefix(first + 1);
    }
    if (authority.starts_with("//")) {
        authority.remove_prefix(2);
        authority = authority.substr(0, authority.find_first_of("/?#"));
        if (const auto user = authority.rfind('@'); user != authority.npos) {
            authority.remove_prefix(user + 1);
        }
        if (authority.starts_with('[')) {
            const auto close = authority.find(']');
            if (close == authority.npos || close == 1) {
                return std::nullopt;
            }
            authority.remove_prefix(close + 1);
            if (!authority.empty() && !authority.starts_with(':')) {
                return std::nullopt;
            }
        } else {
            const auto port = authority.find(':');
            if (authority.substr(0, port).find_first_of("[]<>\"\\^\x60{|}") != authority.npos) {
                return std::nullopt;
            }
            authority = port == authority.npos ? std::string_view{} : authority.substr(port);
        }
        if (!authority.empty() && authority.substr(1).find_first_not_of(digits) != authority.npos) {
            return std::nullopt;
        }
    }
    if (destination.empty()) {
        return std::nullopt;
    }
    return destination;
}

bool domain(std::string_view source, bool require_dot) {
    if (require_dot && source.find('.') == source.npos) {
        return false;
    }
    for (;;) {
        const auto dot = source.find('.');
        const auto label = source.substr(0, dot);
        if (label.empty() || label.size() > 63 || alphanumeric.find(label.front()) == alphanumeric.npos ||
            alphanumeric.find(label.back()) == alphanumeric.npos ||
            label.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-") != label.npos) {
            return false;
        }
        if (dot == source.npos) {
            return true;
        }
        source.remove_prefix(dot + 1);
    }
}

std::optional<std::string> angle_link_destination(std::string_view label) {
    const auto colon = label.find(':');
    if (colon >= 2 && colon <= 32 && scheme(label.substr(0, colon))) {
        return decode_link_text(label, false);
    }
    const auto at = label.find('@');
    if (at != label.npos && at != 0 &&
        label.substr(0, at).find_first_not_of(
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.!#$%&'*+/=?^_`{|}~-") == label.npos &&
        domain(label.substr(at + 1), false)) {
        return "mailto:" + std::string(label);
    }
    return std::nullopt;
}

std::size_t html_tag_width(std::string_view source) {
    auto cursor = source.starts_with("</") ? std::size_t{2} : std::size_t{1};
    if (cursor == source.size() || letters.find(source[cursor]) == letters.npos) {
        return 0;
    }
    constexpr auto tag_name = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"sv;
    cursor = std::min(source.find_first_not_of(tag_name, cursor), source.size());
    if (source.starts_with("</")) {
        cursor = skip_space(source, cursor);
        return source.substr(cursor).starts_with('>') ? cursor + 1 : 0;
    }
    constexpr auto name_start = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_:"sv;
    constexpr auto name = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:-"sv;
    while (cursor < source.size()) {
        const auto before_space = cursor;
        cursor = skip_space(source, cursor);
        const auto suffix = source.substr(cursor);
        if (suffix.starts_with('>') || suffix.starts_with("/>")) {
            return cursor + (suffix.starts_with('>') ? 1 : 2);
        }
        if (cursor == before_space || suffix.empty() || name_start.find(suffix.front()) == name_start.npos) {
            return 0;
        }
        cursor = std::min(source.find_first_not_of(name, cursor), source.size());
        const auto equals = skip_space(source, cursor);
        if (!source.substr(equals).starts_with('=')) {
            continue;
        }
        cursor = skip_space(source, equals + 1);
        if (cursor == source.size()) {
            return 0;
        }
        const char quote = source[cursor];
        if (quote == '\'' || quote == '"') {
            const auto end = source.find(quote, cursor + 1);
            if (end == source.npos) {
                return 0;
            }
            cursor = end + 1;
        } else {
            const auto end = std::min(source.find_first_of(" \t\r\n\"'=<>`", cursor), source.size());
            if (end == cursor) {
                return 0;
            }
            cursor = end;
        }
    }
    return 0;
}

constexpr auto bare_email_characters =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._+-"sv;

bool starts_case_insensitive(std::string_view source, std::string_view prefix) {
    return source.size() >= prefix.size() && std::ranges::equal(source.substr(0, prefix.size()), prefix,
        [](char byte, char lower) {
            return byte == lower || (byte >= 'A' && byte <= 'Z' && byte + ('a' - 'A') == lower);
        });
}

std::size_t bare_url_width(std::string_view source, std::size_t prefix) {
    const auto valid_host = [](std::string_view host) {
        constexpr auto host_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.%,-"sv;
        return !host.empty() && !host.starts_with('-') && std::ranges::all_of(host, [host_chars](char byte) {
            return static_cast<unsigned char>(byte) >= 0x80 || host_chars.find(byte) != host_chars.npos;
        });
    };
    const auto host_end = source.find_first_of("/?#: \t\r\n<", prefix);
    if (host_end != source.npos && "/?#"sv.find(source[host_end]) != source.npos &&
        !valid_host(source.substr(prefix, host_end - prefix))) {
        return 0;
    }
    auto end = std::min(source.find_first_of(" \t\r\n<"), source.size());
    if (source.substr(0, end).ends_with(';')) {
        const auto amp = source.substr(0, end).rfind('&');
        if (amp != source.npos && amp + 1 < end - 1 &&
            source.substr(amp + 1, end - amp - 2).find_first_not_of(alphanumeric) == source.npos) {
            end = amp;
        }
    }
    const auto url = source.substr(0, end);
    auto excess_closers = std::ranges::count(url, ')') - std::ranges::count(url, '(');
    while (end > prefix) {
        const char byte = source[end - 1];
        if (byte == ')' && excess_closers > 0) {
            --excess_closers;
        } else if ("?!.,:;*_~"sv.find(byte) == source.npos) {
            break;
        }
        --end;
    }
    auto host = source.substr(prefix, end - prefix);
    host = host.substr(0, host.find_first_of("/?#"));
    host = host.substr(0, host.find(':'));
    return valid_host(host) ? end : 0;
}

std::optional<InlineToken> bare_link(std::string_view source, std::size_t begin, bool in_label,
                                    std::size_t& email_search_end) {
    const auto tail = source.substr(begin);
    const char previous = begin == 0 ? ' ' : source[begin - 1];
    const bool blocked_url = in_label || previous == '[' ||
        (previous == '<' && tail.substr(std::min(tail.find_first_of(" \t\r\n<>"), tail.size())).starts_with('>'));
    const bool after_word = alphanumeric.find(previous) != alphanumeric.npos ||
        static_cast<unsigned char>(previous) >= 0x80;
    if (after_word) {
        return std::nullopt;
    }
    if (!blocked_url) {
        constexpr std::array prefixes{"https://"sv, "http://"sv, "ftp://"sv, "www."sv};
        for (const auto prefix : prefixes) {
            if (!starts_case_insensitive(tail, prefix)) {
                continue;
            }
            if (tail.size() > prefix.size()) {
                const auto width = bare_url_width(tail, prefix == "www." ? 0 : prefix.size());
                if (width == 0) {
                    return std::nullopt;
                }
                const auto text = tail.substr(0, width);
                auto destination = prefix == "www." ? "http://" + std::string(text) : std::string(text);
                if (auto value = portable_destination(std::move(destination))) {
                    return InlineToken{InlineTokenKind::literal, begin, begin + width, std::string(text),
                                       InlineTrait::none, std::make_shared<InlineLink>(InlineLink{std::move(value), {}})};
                }
            }
            return std::nullopt;
        }
    }
    if (begin < email_search_end || alphanumeric.find(tail.front()) == alphanumeric.npos) {
        return std::nullopt;
    }
    const auto prefix = starts_case_insensitive(tail, "mailto:") ? std::size_t{7} : 0;
    if (prefix == 0 && bare_email_characters.find(previous) != bare_email_characters.npos && previous != '_') {
        return std::nullopt;
    }
    const auto local_end = std::min(tail.find_first_not_of(bare_email_characters, prefix), tail.size());
    email_search_end = begin + local_end;
    if (local_end == prefix || !tail.substr(local_end).starts_with('@')) {
        return std::nullopt;
    }
    auto end = std::min(tail.find_first_not_of(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-", local_end + 1), tail.size());
    while (end > local_end + 1 && tail[end - 1] == '.') {
        --end;
    }
    if (!domain(tail.substr(local_end + 1, end - local_end - 1), true)) {
        return std::nullopt;
    }
    const auto text = tail.substr(0, end);
    auto destination = prefix == 0 ? "mailto:" + std::string(text) : std::string(text);
    return InlineToken{InlineTokenKind::literal, begin, begin + end, std::string(text), InlineTrait::none,
                       std::make_shared<InlineLink>(InlineLink{std::move(destination), {}})};
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

std::optional<InlineToken> InlineScanner::link_or_html_at_cursor() {
    const auto suffix = source.substr(cursor);
    if (suffix.starts_with('<')) {
        std::size_t end = 1;
        for (; end < suffix.size(); ++end) {
            const auto byte = static_cast<unsigned char>(suffix[end]);
            if (byte <= ' ' || byte == 0x7F || byte == '<' || byte == '>') {
                break;
            }
        }
        if (suffix.substr(end).starts_with('>')) {
            const auto label = suffix.substr(1, end - 1);
            if (auto destination = angle_link_destination(label)) {
                auto text = decode_link_text(label, false);
                auto link = portable_destination(std::move(*destination));
                return InlineToken{InlineTokenKind::literal, cursor, cursor + end + 1, std::move(text),
                                   InlineTrait::none, std::make_shared<InlineLink>(InlineLink{std::move(link), {}})};
            }
        }

        auto width = html_tag_width(suffix);
        constexpr std::array starts{"<!--"sv, "<?"sv, "<![CDATA["sv, "<!"sv};
        constexpr std::array ends{"-->"sv, "?>"sv, "]]>"sv, ">"sv};
        for (std::size_t i = 0; width == 0 && i < starts.size(); ++i) {
            if (!suffix.starts_with(starts[i])) {
                continue;
            }
            if (i == 3 && (suffix.size() == 2 || suffix[2] < 'A' || suffix[2] > 'Z')) {
                break;
            }
            if (!missing_html_closers[i]) {
                const auto close = suffix.find(ends[i], starts[i].size());
                if (close == suffix.npos) {
                    missing_html_closers[i] = true;
                } else {
                    width = close + ends[i].size();
                }
            }
            break;
        }
        if (width != 0) {
            return InlineToken{InlineTokenKind::literal, cursor, cursor + width, std::string(suffix.substr(0, width))};
        }
        return std::nullopt;
    }
    if (suffix.starts_with('[')) {
        bool image = cursor > 0 && source[cursor - 1] == '!';
        if (image) {
            auto marker = cursor - 1;
            while (marker > 0 && source[marker - 1] == '\\') {
                --marker;
            }
            image = (cursor - 1 - marker) % 2 == 0;
        }
        brackets.push_back({cursor, image});
    } else if (suffix.starts_with(']') && !brackets.empty()) {
        const auto bracket = brackets.back();
        brackets.pop_back();
        if (!bracket.image) {
            if (const auto target = inline_target(suffix.substr(1))) {
                auto destination = portable_destination(decode_link_text(target->destination, true));
                std::optional<std::string> title;
                if (target->title) {
                    title = decode_link_text(*target->title, true);
                }
                const auto end = cursor + 1 + target->end;
                auto link = std::make_shared<InlineLink>(InlineLink{std::move(destination), std::move(title)});
                bracket_links.push_back({bracket.begin, cursor, end, std::move(link)});
                // A successful inner link makes any enclosing link opener inactive.
                brackets.clear();
                return InlineToken{InlineTokenKind::literal, cursor, end, {}};
            }
        }
    } else if (!suffix.starts_with(']')) {
        return bare_link(source, cursor, !brackets.empty(), bare_search_end);
    }
    return std::nullopt;
}

std::optional<InlineToken> InlineScanner::next_special() {
    while (cursor < source.size()) {
        if (!scan_links) {
            cursor = source.find_first_of("\\`&\r\n", cursor);
            if (cursor == source.npos) {
                break;
            }
        }
        const auto suffix = source.substr(cursor + 1);
        switch (source[cursor]) {
        case '\\':
            if (const auto width = line_ending_width(suffix)) {
                return InlineToken{InlineTokenKind::line_break, cursor, cursor + 1 + width, "\n"};
            }
            if (escaped_punctuation(source.substr(cursor))) {
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
        case '\r':
        case '\n':
            return InlineToken{InlineTokenKind::line_break, cursor,
                               cursor + line_ending_width(source.substr(cursor)), "\n"};
        default:
            if (scan_links && (source[cursor] == '<' || source[cursor] == '[' || source[cursor] == ']' ||
                alphanumeric.find(source[cursor]) != alphanumeric.npos)) {
                if (auto link = link_or_html_at_cursor()) {
                    return link;
                }
            }
            break;
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

namespace {

std::vector<InlineToken> resolve_styles(std::string_view source, std::vector<InlineToken> tokens) {
    std::vector<DelimiterRun> runs;
    for (const auto& token : tokens) {
        if (token.kind == InlineTokenKind::text) {
            collect_delimiters(runs, source, token);
        }
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

std::vector<InlineToken> resolve_inline(std::string_view source) {
    InlineScanner scanner(source);
    scanner.scan_links = true;
    std::vector<InlineToken> tokens;
    while (auto token = scanner.next()) {
        tokens.push_back(std::move(*token));
    }
    if (scanner.bracket_links.empty()) {
        return resolve_styles(source, std::move(tokens));
    }

    // Style labels in their own delimiter scope. In the surrounding text each
    // whole link is a single protected token that can inherit outer styles.
    std::vector<InlineToken> outer;
    std::vector<std::vector<InlineToken>> labels;
    auto token = tokens.begin();
    for (const auto& bracket : scanner.bracket_links) {
        while (token->end <= bracket.begin) {
            outer.push_back(std::move(*token++));
        }
        if (token->begin < bracket.begin) {
            append_text(outer, source, token->begin, bracket.begin, InlineTrait::none);
        }
        outer.push_back({InlineTokenKind::literal, bracket.begin, bracket.end, {}, InlineTrait::none, bracket.link});

        std::vector<InlineToken> label;
        while (token->begin < bracket.label_end) {
            if (token->begin <= bracket.begin) {
                append_text(label, source, bracket.begin + 1, token->end, InlineTrait::none);
            } else {
                label.push_back(std::move(*token));
            }
            ++token;
        }
        ++token; // The closing bracket and target are a single scanner token.
        labels.push_back(resolve_styles(source, std::move(label)));
    }
    outer.insert(outer.end(), std::make_move_iterator(token), std::make_move_iterator(tokens.end()));

    std::vector<InlineToken> result;
    auto label = labels.begin();
    for (auto& styled : resolve_styles(source, std::move(outer))) {
        if (styled.link && styled.text.empty()) {
            for (auto& piece : *label++) {
                piece.traits = piece.traits | styled.traits;
                piece.link = styled.link;
                result.push_back(std::move(piece));
            }
        } else {
            result.push_back(std::move(styled));
        }
    }
    return result;
}

}
