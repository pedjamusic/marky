#include "MarkyCore.h"

#ifdef MARKY_CORE_TEST_CHECKPOINTS
#include "DocumentTestCheckpoints.h"
#endif

#include <atomic>
#include <memory>
#include <new>
#include <string>
#include <utility>

struct MarkyDocument {
    const std::string paragraph;
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

    auto paragraph = byte_count == 0 ? std::string{} : std::string(utf8, byte_count);
#ifdef MARKY_CORE_TEST_CHECKPOINTS
    marky::test::checkpoint(marky::test::Checkpoint::beforeDocumentAllocation);
#endif
    if (cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }

    auto document = std::make_unique<MarkyDocument>(std::move(paragraph));
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
    return document != nullptr && !document->paragraph.empty() ? 1 : 0;
}

MarkyStatus marky_document_paragraph_at(const MarkyDocument* document, size_t index,
                                        MarkyUtf8View* out_text) {
    if (out_text == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_text = {};
    if (index >= marky_document_block_count(document)) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }

    *out_text = {document->paragraph.data(), document->paragraph.size()};
    return MARKY_STATUS_OK;
}

void marky_document_release(MarkyDocument* document) {
    delete document;
}
