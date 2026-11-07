#include "MarkyCore.h"

#include <new>
#include <string>

struct MarkyDocument {
    const std::string paragraph;
};

MarkyStatus marky_document_create(const char* utf8, size_t byte_count,
                                  MarkyDocument** out_document) {
    if (out_document == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_document = nullptr;
    if (utf8 == nullptr && byte_count != 0) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }

    try {
        *out_document = new MarkyDocument{
            byte_count == 0 ? std::string{} : std::string(utf8, byte_count)
        };
        return MARKY_STATUS_OK;
    } catch (const std::bad_alloc&) {
        return MARKY_STATUS_ALLOCATION_FAILURE;
    } catch (...) {
        return MARKY_STATUS_INTERNAL_ERROR;
    }
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
