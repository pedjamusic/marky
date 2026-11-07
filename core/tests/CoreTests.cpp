#include "MarkyCore.h"

#include <array>
#include <barrier>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <string_view>
#include <thread>

namespace {

void check_owned_paragraph(const auto& check) {
    // Decomposed é, emoji, embedded NUL and a final ASCII byte.
    constexpr char expected[] = "e\xCC\x81\xF0\x9F\x8E\xB5\0" "!";
    constexpr size_t byte_count = sizeof(expected) - 1;
    MarkyDocument* document = nullptr;
    {
        char input[byte_count];
        std::memcpy(input, expected, byte_count);
        check(marky_document_create(input, byte_count, &document) == MARKY_STATUS_OK &&
                  document != nullptr,
              "valid length-delimited input must produce an owned document");
        std::memset(input, '?', byte_count);
        MarkyUtf8View text{};
        check(marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_OK &&
                  text.data != input,
              "the paragraph must not alias the caller's buffer");
    }

    check(marky_document_block_count(document) == 1,
          "nonempty input must produce one paragraph");
    MarkyUtf8View text{};
    check(marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_OK,
          "the paragraph must remain readable after the input goes out of scope");

    MarkyDocument* other = nullptr;
    check(marky_document_create("other", 5, &other) == MARKY_STATUS_OK &&
              other != nullptr && other != document,
          "a second call must produce an independent result");
    if (other != document) {
        marky_document_release(other);
    }
    check(text.data != nullptr && text.byte_count == byte_count &&
              std::memcmp(text.data, expected, byte_count) == 0,
          "a view must keep the exact UTF-8 bytes until its own result is released");

    MarkyUtf8View invalid = text;
    check(marky_document_paragraph_at(document, 1, &invalid) == MARKY_STATUS_INVALID_ARGUMENT &&
              invalid.data == nullptr && invalid.byte_count == 0,
          "an out-of-range index must clear the output view");
    check(marky_document_paragraph_at(document, 0, nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "a missing output view must be rejected");

    MarkyDocument* rejected = document;
    check(marky_document_create(nullptr, 1, &rejected) == MARKY_STATUS_INVALID_ARGUMENT &&
              rejected == nullptr,
          "nonzero length with NULL input must clear the output handle");
    marky_document_release(document);
}

void check_empty_document(const auto& check, const char* input) {
    MarkyDocument* document = nullptr;
    check(marky_document_create(input, 0, &document) == MARKY_STATUS_OK && document != nullptr,
          "empty input must produce an owned document");
    check(marky_document_block_count(document) == 0,
          "empty input must have no blocks");

    MarkyUtf8View text{"stale", 5};
    check(marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_INVALID_ARGUMENT &&
              text.data == nullptr && text.byte_count == 0,
          "an empty document must have no paragraph view");
    marky_document_release(document);
}

void check_cancellation(const auto& check) {
    MarkyCancellationToken* raw_token = nullptr;
    check(marky_cancellation_token_create(&raw_token) == MARKY_STATUS_OK && raw_token != nullptr,
          "token creation must return an owned, initially active token");
    std::unique_ptr<MarkyCancellationToken, decltype(&marky_cancellation_token_release)>
        token(raw_token, marky_cancellation_token_release);

    MarkyDocument* document = nullptr;
    check(marky_document_create_cancellable("keep", 4, token.get(), &document) ==
              MARKY_STATUS_OK && document != nullptr,
          "an active token must allow creation");
    marky_cancellation_token_request(token.get());
    marky_cancellation_token_request(token.get());
    for (int attempt = 0; attempt < 2; ++attempt) {
        MarkyDocument* output = document;
        check(marky_document_create_cancellable(nullptr, 0, token.get(), &output) ==
                  MARKY_STATUS_CANCELLED && output == nullptr,
              "a cancelled token must keep cancelling, even for empty input");
        output = document;
        check(marky_document_create_cancellable(nullptr, 1, token.get(), &output) ==
                  MARKY_STATUS_INVALID_ARGUMENT && output == nullptr,
              "invalid input must take precedence over cancellation");
    }

    marky_cancellation_token_request(nullptr);
    marky_cancellation_token_release(nullptr);
    check(marky_cancellation_token_create(nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "token creation must reject a missing output slot");
    check(marky_document_create_cancellable("x", 1, token.get(), nullptr) ==
              MARKY_STATUS_INVALID_ARGUMENT,
          "a cancelled call must reject a missing document slot");

    token.reset();
    MarkyUtf8View text{};
    check(marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_OK &&
              text.data != nullptr && std::string_view(text.data, text.byte_count) == "keep",
          "a published result must survive cancellation and token release");
    marky_document_release(document);
}

void check_concurrent_calls(const auto& check) {
    MarkyCancellationToken* raw_token = nullptr;
    const auto status = marky_cancellation_token_create(&raw_token);
    std::unique_ptr<MarkyCancellationToken, decltype(&marky_cancellation_token_release)>
        token(raw_token, marky_cancellation_token_release);
    const bool active_token_created = status == MARKY_STATUS_OK && token != nullptr;
    check(active_token_created, "concurrent calls need a live token");
    if (!active_token_created) {
        return;
    }

    constexpr std::array<std::string_view, 4> inputs{"first", "second", "third", "fourth"};
    std::array<bool, inputs.size()> succeeded{};
    std::array<std::thread, inputs.size()> workers;
    std::barrier start(static_cast<std::ptrdiff_t>(workers.size()));
    for (size_t index = 0; index < workers.size(); ++index) {
        workers[index] = std::thread([&, index] {
            start.arrive_and_wait();
            const auto input = inputs[index];
            bool matches = true;
            for (int attempt = 0; attempt < 64; ++attempt) {
                MarkyDocument* document = nullptr;
                MarkyUtf8View text{};
                const auto result = marky_document_create_cancellable(
                    input.data(), input.size(), token.get(), &document);
                matches &= result == MARKY_STATUS_OK &&
                           marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_OK &&
                           text.data != nullptr &&
                           std::string_view(text.data, text.byte_count) == input;
                marky_document_release(document);
            }
            start.arrive_and_wait();
            for (int attempt = 0; attempt < 64; ++attempt) {
                marky_cancellation_token_request(token.get());
                MarkyDocument* document = nullptr;
                const auto result = marky_document_create_cancellable(
                    input.data(), input.size(), token.get(), &document);
                matches &= result == MARKY_STATUS_CANCELLED && document == nullptr;
                marky_document_release(document);
            }
            succeeded[index] = matches;
        });
    }
    for (size_t index = 0; index < workers.size(); ++index) {
        workers[index].join();
        check(succeeded[index], "parallel calls must preserve bytes and honor shared cancellation");
    }

    MarkyDocument* document = nullptr;
    const auto result = marky_document_create("fresh", 5, &document);
    token.reset();
    check(result == MARKY_STATUS_OK && marky_document_block_count(document) == 1,
          "a tokenless call must remain independent of a cancelled token");
    marky_document_release(document);
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

    check_owned_paragraph(check);
    check_empty_document(check, nullptr);
    check_empty_document(check, "");
    check_cancellation(check);
    check_concurrent_calls(check);

    check(marky_document_create("x", 1, nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "a missing output handle must be rejected");
    check(marky_document_block_count(nullptr) == 0,
          "a NULL document must report no blocks");
    MarkyUtf8View text{"stale", 5};
    check(marky_document_paragraph_at(nullptr, 0, &text) == MARKY_STATUS_INVALID_ARGUMENT &&
              text.data == nullptr && text.byte_count == 0,
          "a NULL document must clear the output view");
    marky_document_release(nullptr);

    // Exercise the same failure path under CTest, including Release/NDEBUG builds.
    const char* force_failure = std::getenv("MARKY_CORE_TEST_FORCE_FAILURE");
    if (force_failure != nullptr && std::string_view(force_failure) == "1") {
        check(false, "intentional harness failure");
    }

    if (failures != 0) {
        return EXIT_FAILURE;
    }
    std::cout << "PASS: document ownership, cancellation and concurrency checks\n";
    return EXIT_SUCCESS;
}
