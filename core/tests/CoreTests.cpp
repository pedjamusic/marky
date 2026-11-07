#include "MarkyCore.h"

#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string_view>

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
    std::cout << "PASS: document interface and ownership checks\n";
    return EXIT_SUCCESS;
}
