#include "MarkyCore.h"
#include "LiteralSyntax.h"

#ifdef MARKY_CORE_TEST_CHECKPOINTS
#include "DocumentTestCheckpoints.h"
#endif

#include <atomic>
#include <memory>
#include <new>
#include <optional>
#include <string>
#include <utility>
#include <vector>

struct MarkyDocument {
    struct Block {
        MarkyBlockKind kind;
        std::string text;
    };

    const std::vector<Block> blocks;
#ifdef MARKY_CORE_TEST_CHECKPOINTS
    ~MarkyDocument() { marky::test::document_destroyed(); }
#endif
};

struct MarkyCancellationToken {
    std::atomic<bool> requested{false};
};

namespace {

bool cancellation_requested(const MarkyCancellationToken* token) noexcept {
    // The flag carries no other state. The caller manages token lifetime.
    return token != nullptr && token->requested.load(std::memory_order_relaxed);
}

struct Fence {
    char marker;
    size_t length;
};

// Match the existing reader's horizontal whitespace on a fence closer.
bool horizontal_whitespace_only(std::string_view text) {
    while (!text.empty()) {
        const auto ascii_end = text.find_first_not_of(" \t");
        if (ascii_end == std::string_view::npos) {
            return true;
        }
        text.remove_prefix(ascii_end);
        if (text.starts_with("\xC2\xA0")) { // U+00A0
            text.remove_prefix(2);
        } else if (text.starts_with("\xE1\x9A\x80") || // U+1680
                   text.starts_with("\xE2\x80\xAF") || // U+202F
                   text.starts_with("\xE2\x81\x9F") || // U+205F
                   text.starts_with("\xE3\x80\x80") || // U+3000
                   (text.size() >= 3 && text.starts_with("\xE2\x80") &&
                    static_cast<unsigned char>(text[2]) >= 0x80 &&
                    static_cast<unsigned char>(text[2]) <= 0x8B)) { // U+2000–U+200B
            text.remove_prefix(3);
        } else {
            return false;
        }
    }
    return true;
}

std::optional<Fence> fence_transition(std::string_view line, std::optional<Fence> open) {
    const auto indent = marky::delimiter_run_length(line, ' ');
    if (indent > 3 || indent == line.size()) {
        return std::nullopt;
    }
    line.remove_prefix(indent);
    const char marker = line.front();
    if (marker != '`' && marker != '~') {
        return std::nullopt;
    }
    const auto length = marky::delimiter_run_length(line, marker);
    const auto suffix = line.substr(length);
    const bool valid = open ? marker == open->marker && length >= open->length &&
                                  horizontal_whitespace_only(suffix)
                            : length >= 3 && (marker != '`' || suffix.find('`') == std::string_view::npos);
    return valid ? std::optional{Fence{marker, length}} : std::nullopt;
}

std::optional<std::vector<MarkyDocument::Block>> parse_fenced_blocks(
    std::string_view source, const MarkyCancellationToken* token) {
    std::vector<MarkyDocument::Block> blocks;
    std::optional<Fence> open;
    std::string text;
    bool has_line = false;
    bool has_prose = false;

    const auto flush = [&] {
        if (open || has_prose) {
            blocks.push_back({open ? MARKY_BLOCK_CODE : MARKY_BLOCK_PARAGRAPH, std::move(text)});
        }
        text.clear();
        has_line = false;
        has_prose = false;
    };

    for (;;) {
        if (cancellation_requested(token)) {
            return std::nullopt;
        }
        const auto newline = source.find('\n');
        auto line = source.substr(0, newline);
        if (newline != std::string_view::npos && line.ends_with('\r')) {
            line.remove_suffix(1);
        }

        if (const auto fence = fence_transition(line, open)) {
            flush();
            open = open ? std::nullopt : fence;
        } else {
            if (has_line) {
                text.push_back('\n');
            }
            text.append(line);
            has_line = true;
            has_prose = has_prose || (!open && !horizontal_whitespace_only(line));
        }

        if (newline == std::string_view::npos) {
            break;
        }
        source.remove_prefix(newline + 1);
    }
    flush();
    return blocks;
}

}

MarkyStatus marky_document_create(const char* utf8, size_t byte_count,
                                  MarkyDocument** out_document) {
    return marky_document_create_cancellable(utf8, byte_count, nullptr, out_document);
}

MarkyStatus marky_cancellation_token_create(MarkyCancellationToken** out_token) try {
    if (out_token == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_token = nullptr;
#ifdef MARKY_CORE_TEST_CHECKPOINTS
    marky::test::checkpoint(marky::test::Checkpoint::beforeTokenAllocation);
#endif
    *out_token = new MarkyCancellationToken;
    return MARKY_STATUS_OK;
} catch (const std::bad_alloc&) {
    return MARKY_STATUS_ALLOCATION_FAILURE;
} catch (...) {
    return MARKY_STATUS_INTERNAL_ERROR;
}

void marky_cancellation_token_request(MarkyCancellationToken* token) {
    if (token != nullptr) {
        token->requested.store(true, std::memory_order_relaxed);
    }
}

void marky_cancellation_token_release(MarkyCancellationToken* token) {
    delete token;
}

MarkyStatus marky_document_create_cancellable(const char* utf8, size_t byte_count,
                                              const MarkyCancellationToken* token,
                                              MarkyDocument** out_document) try {
    if (out_document == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_document = nullptr;
    if (utf8 == nullptr && byte_count != 0) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    if (cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }

    const auto input = byte_count == 0 ? std::string_view("") : std::string_view(utf8, byte_count);
    auto blocks = parse_fenced_blocks(input, token);
    if (!blocks) {
        return MARKY_STATUS_CANCELLED;
    }
#ifdef MARKY_CORE_TEST_CHECKPOINTS
    marky::test::checkpoint(marky::test::Checkpoint::beforeDocumentAllocation);
#endif
    if (cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }

    auto document = std::make_unique<MarkyDocument>(std::move(*blocks));
#ifdef MARKY_CORE_TEST_CHECKPOINTS
    marky::test::checkpoint(marky::test::Checkpoint::beforeDocumentPublication);
#endif
    if (cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }
    *out_document = document.release();
    return MARKY_STATUS_OK;
} catch (const std::bad_alloc&) {
    return MARKY_STATUS_ALLOCATION_FAILURE;
} catch (...) {
    return MARKY_STATUS_INTERNAL_ERROR;
}

size_t marky_document_block_count(const MarkyDocument* document) {
    return document != nullptr ? document->blocks.size() : 0;
}

MarkyStatus marky_document_block_at(const MarkyDocument* document, size_t index,
                                    MarkyBlockKind* out_kind, MarkyUtf8View* out_text) {
    if (out_kind != nullptr) {
        *out_kind = MARKY_BLOCK_INVALID;
    }
    if (out_text != nullptr) {
        *out_text = {};
    }
    if (out_kind == nullptr || out_text == nullptr || index >= marky_document_block_count(document)) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }

    const auto& block = document->blocks[index];
    *out_kind = block.kind;
    *out_text = {block.text.data(), block.text.size()};
    return MARKY_STATUS_OK;
}

MarkyStatus marky_document_paragraph_at(const MarkyDocument* document, size_t index,
                                        MarkyUtf8View* out_text) {
    MarkyBlockKind kind;
    const auto status = marky_document_block_at(document, index, &kind, out_text);
    if (status == MARKY_STATUS_OK && kind != MARKY_BLOCK_PARAGRAPH) {
        *out_text = {};
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    return status;
}

void marky_document_release(MarkyDocument* document) {
    delete document;
}
