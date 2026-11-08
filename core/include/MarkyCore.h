#ifndef MARKY_CORE_H
#define MARKY_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MarkyDocument MarkyDocument;
typedef struct MarkyCancellationToken MarkyCancellationToken;
typedef uint32_t MarkyStatus;
typedef uint32_t MarkyBlockKind;
typedef uint32_t MarkyListMarkerKind;

enum {
    MARKY_STATUS_OK = 0,
    MARKY_STATUS_INVALID_ARGUMENT = 1,
    MARKY_STATUS_ALLOCATION_FAILURE = 2,
    MARKY_STATUS_INTERNAL_ERROR = 3,
    MARKY_STATUS_CANCELLED = 4
};

enum {
    MARKY_BLOCK_INVALID = 0,
    MARKY_BLOCK_PARAGRAPH = 1,
    MARKY_BLOCK_CODE = 2,
    MARKY_BLOCK_HEADING = 3,
    MARKY_BLOCK_THEMATIC_BREAK = 4,
    MARKY_BLOCK_LIST = 5
};

enum {
    MARKY_LIST_MARKER_INVALID = 0,
    MARKY_LIST_MARKER_BULLET = 1,
    MARKY_LIST_MARKER_ORDERED = 2,
    MARKY_LIST_MARKER_TASK_UNCHECKED = 3,
    MARKY_LIST_MARKER_TASK_CHECKED = 4
};

typedef struct {
    const char* data;
    size_t byte_count;
} MarkyUtf8View;

typedef struct {
    size_t depth;
    MarkyListMarkerKind marker_kind;
    MarkyUtf8View ordered_marker;
    MarkyUtf8View source;
} MarkyListItemView;

/*
 * Borrows byte_count bytes of caller-validated UTF-8 for this synchronous call.
 * The input may be NULL for zero bytes. Embedded NUL bytes are preserved.
 * out_document must point to writable storage separate from the input. It
 * receives a new owned result on success (including empty input) and NULL
 * on failure. Release any previously owned result before reusing the slot.
 *
 * Normalizes CRLF line endings to LF. Fenced code contains the literal lines
 * between its delimiters, which can be empty. Indented code retains literal
 * content after stripping the required indentation and trailing blank lines.
 * Paragraph and heading text is prepared Markdown awaiting inline parsing.
 * Soft paragraph lines join with spaces and hard breaks retain LF. Thematic
 * breaks and list blocks have empty block text. List items expose prepared
 * Markdown source, with continuation lines separated by LF.
 */
MarkyStatus marky_document_create(const char* utf8, size_t byte_count,
                                  MarkyDocument** out_document);

/*
 * Creates an owned, initially active cancellation token. out_token must point
 * to writable storage and is set to NULL on failure. Release any previously
 * owned token before reusing the slot.
 */
MarkyStatus marky_cancellation_token_create(MarkyCancellationToken** out_token);

/*
 * Requests cancellation permanently. Safe to call repeatedly and concurrently
 * while the token remains alive. NULL is a no-op.
 */
void marky_cancellation_token_request(MarkyCancellationToken* token);

/*
 * Releases an owned token once. All operations borrowing it and all callers
 * requesting cancellation must finish before release. NULL is a no-op.
 */
void marky_cancellation_token_release(MarkyCancellationToken* token);

/*
 * Uses the same input and result rules as marky_document_create. A NULL token
 * disables cancellation. Otherwise the call borrows the token until return.
 * Concurrent calls may share the token but must use separate output slots.
 * Cancellation is cooperative. A request racing the final cancellation check
 * may still yield a complete result. A completed document is independent of
 * the token. Any failure, including cancellation, leaves the output NULL.
 */
MarkyStatus marky_document_create_cancellable(const char* utf8, size_t byte_count,
                                              const MarkyCancellationToken* token,
                                              MarkyDocument** out_document);

/* Returns the semantic block count, or zero for a NULL document. */
size_t marky_document_block_count(const MarkyDocument* document);

/*
 * Reads the kind and text of the block at the zero-based index. Both output
 * pointers are required. A successful view borrows immutable UTF-8 bytes until
 * document release. On failure, non-NULL outputs are reset to invalid/empty.
 */
MarkyStatus marky_document_block_at(const MarkyDocument* document, size_t index,
                                    MarkyBlockKind* out_kind, MarkyUtf8View* out_text);

/*
 * Reads the plain text of the paragraph at the zero-based block index.
 * A block of another kind is rejected.
 * A successful view borrows immutable bytes until document release.
 * On invalid arguments, a non-NULL out_text is set to {NULL, 0}.
 */
MarkyStatus marky_document_paragraph_at(const MarkyDocument* document, size_t index,
                                        MarkyUtf8View* out_text);

/*
 * Reads the level (1–6) of the heading at the zero-based block index.
 * On invalid arguments or a non-heading block, a non-NULL out_level is set to 0.
 */
MarkyStatus marky_document_heading_level_at(const MarkyDocument* document, size_t index,
                                            uint32_t* out_level);

/* Returns the list's item count, or zero for an invalid index or non-list. */
size_t marky_document_list_item_count(const MarkyDocument* document, size_t block_index);

/*
 * Reads an item in source order. Both indices and the item's depth are
 * zero-based. ordered_marker is nonempty only for ordered items and preserves
 * the original number and delimiter. Task state is part of marker_kind.
 * The UTF-8 views are valid until document release. On invalid arguments,
 * a non-NULL out_item is reset to zero depth, invalid marker and empty views.
 */
MarkyStatus marky_document_list_item_at(const MarkyDocument* document, size_t block_index,
                                       size_t item_index, MarkyListItemView* out_item);

/* Releases an owned result once and invalidates all its views. NULL is a no-op. */
void marky_document_release(MarkyDocument* document);

#ifdef __cplusplus
}
#endif

#endif
