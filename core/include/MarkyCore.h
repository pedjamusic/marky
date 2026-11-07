#ifndef MARKY_CORE_H
#define MARKY_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MarkyDocument MarkyDocument;
typedef uint32_t MarkyStatus;

enum {
    MARKY_STATUS_OK = 0,
    MARKY_STATUS_INVALID_ARGUMENT = 1,
    MARKY_STATUS_ALLOCATION_FAILURE = 2,
    MARKY_STATUS_INTERNAL_ERROR = 3
};

typedef struct {
    const char* data;
    size_t byte_count;
} MarkyUtf8View;

/*
 * Borrows byte_count bytes of caller-validated UTF-8 for this synchronous call.
 * The input may be NULL for zero bytes. Embedded NUL bytes are preserved.
 * out_document must point to writable storage separate from the input. It
 * receives a new owned result on success (including empty input) and NULL
 * on failure. Release any previously owned result before reusing the slot.
 *
 * The initial implementation treats nonempty input as one literal paragraph.
 */
MarkyStatus marky_document_create(const char* utf8, size_t byte_count,
                                  MarkyDocument** out_document);

/* Returns the semantic block count, or zero for a NULL document. */
size_t marky_document_block_count(const MarkyDocument* document);

/*
 * Reads the plain text of the paragraph at the zero-based block index.
 * A successful view borrows immutable bytes until document release.
 * On invalid arguments, a non-NULL out_text is set to {NULL, 0}.
 */
MarkyStatus marky_document_paragraph_at(const MarkyDocument* document, size_t index,
                                        MarkyUtf8View* out_text);

/* Releases an owned result once and invalidates all its views. NULL is a no-op. */
void marky_document_release(MarkyDocument* document);

#ifdef __cplusplus
}
#endif

#endif
