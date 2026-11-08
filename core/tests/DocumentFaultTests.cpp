#include "DocumentTestCheckpoints.h"
#include "MarkyCore.h"

#include <cstdlib>
#include <functional>
#include <iostream>
#include <latch>
#include <memory>
#include <new>
#include <string>
#include <string_view>
#include <thread>

namespace {

using marky::test::Checkpoint;

thread_local std::function<void(Checkpoint)> on_checkpoint;
thread_local size_t destroyed_documents = 0;

std::string block_input() {
    return "# Heading\n\n~~~\n" + std::string(128 * 1024, 'x') +
           "\n~~~\n\n    indented\n\nAfter\n\n- [x] List item with owned source\n  continuation\n02) Next item"
           "\n> Quote line with owned source\n>> Nested quote";
}

void check_document_failure(const auto& check, Checkpoint injection_point,
                            MarkyStatus expected_status, size_t expected_destructions,
                            MarkyDocument* existing, size_t checkpoint_occurrence = 1) {
    const auto input = block_input();
    const size_t destroyed_before = destroyed_documents;
    on_checkpoint = [=](Checkpoint point) mutable {
        if (point == injection_point && --checkpoint_occurrence == 0) {
            if (expected_status == MARKY_STATUS_ALLOCATION_FAILURE) {
                throw std::bad_alloc{};
            }
            throw 42; // Exercise containment of exceptions outside std::exception.
        }
    };
    MarkyDocument* output = existing;
    const auto status = marky_document_create(input.data(), input.size(), &output);
    on_checkpoint = {};
    check(status == expected_status && output == nullptr,
          "injected failure must map to the expected status and clear the output");
    check(destroyed_documents - destroyed_before == expected_destructions,
          "injected failure must destroy any built but unpublished document");
    if (output != existing) {
        marky_document_release(output);
    }

    output = nullptr;
    check(marky_document_create(input.data(), input.size(), &output) == MARKY_STATUS_OK &&
              output != existing && marky_document_block_count(output) == 6 &&
              marky_document_list_item_count(output, 4) == 2 &&
              marky_document_quote_line_count(output, 5) == 2,
          "creation must recover all blocks after an injected failure");
    if (output != existing) {
        marky_document_release(output);
    }
}

void check_token_allocation_failure(const auto& check, MarkyCancellationToken* existing) {
    on_checkpoint = [](Checkpoint point) {
        if (point == Checkpoint::beforeTokenAllocation) {
            throw std::bad_alloc{};
        }
    };
    MarkyCancellationToken* output = existing;
    const auto status = marky_cancellation_token_create(&output);
    on_checkpoint = {};
    check(status == MARKY_STATUS_ALLOCATION_FAILURE && output == nullptr,
          "token allocation failure must return a typed status and clear the output");
    if (output != existing) {
        marky_cancellation_token_release(output);
    }
}

void check_mid_call_cancellation(const auto& check, Checkpoint pause_at,
                                 size_t expected_destructions, MarkyDocument* existing,
                                 size_t checkpoint_occurrence = 1) {
    MarkyCancellationToken* raw_token = nullptr;
    const auto status = marky_cancellation_token_create(&raw_token);
    const std::unique_ptr<MarkyCancellationToken, decltype(&marky_cancellation_token_release)>
        token(raw_token, marky_cancellation_token_release);
    const bool token_created = status == MARKY_STATUS_OK && token != nullptr;
    check(token_created, "token creation must recover after an injected failure");
    if (!token_created) {
        return;
    }

    std::latch reached_checkpoint(1);
    std::latch resume_worker(1);
    const auto input = block_input();
    MarkyDocument* output = existing;
    MarkyStatus result = MARKY_STATUS_OK;
    size_t destruction_count = 0;
    bool paused = false;
    std::thread worker([&] {
        on_checkpoint = [&](Checkpoint point) {
            if (point == pause_at) {
                if (paused) {
                    // Make continued parsing distinguishable from cancellation at publication.
                    throw 42;
                }
                if (--checkpoint_occurrence == 0) {
                    paused = true;
                    reached_checkpoint.count_down();
                    resume_worker.wait();
                }
            }
        };
        const size_t destroyed_before = destroyed_documents;
        result = marky_document_create_cancellable(input.data(), input.size(), token.get(), &output);
        destruction_count = destroyed_documents - destroyed_before;
        if (!paused) {
            reached_checkpoint.count_down();
        }
    });
    reached_checkpoint.wait();
    marky_cancellation_token_request(token.get());
    resume_worker.count_down();
    worker.join();

    check(paused && result == MARKY_STATUS_CANCELLED && output == nullptr,
          "cancellation requested during creation must clear the output");
    check(destruction_count == expected_destructions,
          "cancellation must destroy any built but unpublished document");
    if (output != existing) {
        marky_document_release(output);
    }
}

}

namespace marky::test {

void checkpoint(Checkpoint point) {
    if (on_checkpoint) {
        on_checkpoint(point);
    }
}

void document_destroyed() noexcept {
    ++destroyed_documents;
}

}

int main() {
    int failures = 0;
    const auto check = [&failures](bool condition, std::string_view message) {
        if (!condition) {
            std::cerr << "FAIL: " << message << '\n';
            ++failures;
        }
    };

    MarkyDocument* raw_document = nullptr;
    MarkyCancellationToken* raw_token = nullptr;
    const auto document_status = marky_document_create("keep", 4, &raw_document);
    const auto token_status = marky_cancellation_token_create(&raw_token);
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);
    const std::unique_ptr<MarkyCancellationToken, decltype(&marky_cancellation_token_release)>
        token(raw_token, marky_cancellation_token_release);
    if (document_status != MARKY_STATUS_OK || document == nullptr ||
        token_status != MARKY_STATUS_OK || token == nullptr) {
        std::cerr << "FAIL: could not initialize fault test fixtures\n";
        return EXIT_FAILURE;
    }

    check_token_allocation_failure(check, token.get());
    // After line four, the heading is complete and the fence has pending literal text.
    constexpr size_t in_open_fence = 4;
    check_document_failure(check, Checkpoint::afterBlockLine,
                           MARKY_STATUS_ALLOCATION_FAILURE, 0, document.get(), in_open_fence);
    check_mid_call_cancellation(check, Checkpoint::afterBlockLine, 0, document.get(), in_open_fence);
    // After line twelve, the first list item has a continuation and the list is still open.
    constexpr size_t in_list = 12;
    check_document_failure(check, Checkpoint::afterBlockLine,
                           MARKY_STATUS_ALLOCATION_FAILURE, 0, document.get(), in_list);
    check_mid_call_cancellation(check, Checkpoint::afterBlockLine, 0, document.get(), in_list);
    // After line fourteen, the quote owns its first line and is still open.
    constexpr size_t in_quote = 14;
    check_document_failure(check, Checkpoint::afterBlockLine,
                           MARKY_STATUS_ALLOCATION_FAILURE, 0, document.get(), in_quote);
    check_mid_call_cancellation(check, Checkpoint::afterBlockLine, 0, document.get(), in_quote);
    check_document_failure(check, Checkpoint::beforeDocumentAllocation,
                           MARKY_STATUS_ALLOCATION_FAILURE, 0, document.get());
    check_document_failure(check, Checkpoint::beforeDocumentPublication,
                           MARKY_STATUS_INTERNAL_ERROR, 1, document.get());
    check_mid_call_cancellation(check, Checkpoint::beforeDocumentAllocation, 0, document.get());
    check_mid_call_cancellation(check, Checkpoint::beforeDocumentPublication, 1, document.get());

    if (failures != 0) {
        return EXIT_FAILURE;
    }
    std::cout << "PASS: injected failures, partial construction and in-flight cancellation checks\n";
    return EXIT_SUCCESS;
}
