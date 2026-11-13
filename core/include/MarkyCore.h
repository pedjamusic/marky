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
typedef uint32_t MarkyTableAlignment;

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
    MARKY_BLOCK_LIST = 5,
    MARKY_BLOCK_QUOTE = 6,
    MARKY_BLOCK_TABLE = 7,
    MARKY_BLOCK_IMAGE = 8
};

enum {
    MARKY_LIST_MARKER_INVALID = 0,
    MARKY_LIST_MARKER_BULLET = 1,
    MARKY_LIST_MARKER_ORDERED = 2,
    MARKY_LIST_MARKER_TASK_UNCHECKED = 3,
    MARKY_LIST_MARKER_TASK_CHECKED = 4
};

enum {
    MARKY_TABLE_ALIGNMENT_INVALID = 0,
    MARKY_TABLE_ALIGNMENT_LEFT = 1,
    MARKY_TABLE_ALIGNMENT_CENTER = 2,
    MARKY_TABLE_ALIGNMENT_RIGHT = 3
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

typedef struct {
    size_t depth;
    MarkyUtf8View source;
} MarkyQuoteLineView;

typedef struct {
    MarkyTableAlignment alignment;
    MarkyUtf8View header;
} MarkyTableColumnView;

typedef struct {
    MarkyUtf8View alt;
    MarkyUtf8View destination;
    MarkyUtf8View title;
} MarkyImageView;

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
 * breaks, lists, quotes, tables and images have empty block text. List items expose prepared
 * Markdown source, with continuation lines separated by LF. Quote lines expose
 * prepared Markdown source and marker depth in source order.
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

/* Returns the quote's line count, or zero for an invalid index or non-quote. */
size_t marky_document_quote_line_count(const MarkyDocument* document, size_t block_index);

/*
 * Reads a line in source order. Both indices are zero-based. Depth counts
 * stripped quote markers, with 1 denoting a top-level quote line. A line may
 * have empty source. Depth can be 0 if a leading non-LF newline is ignored
 * for block recognition but preserved during quote preparation. The UTF-8
 * view is valid until document release.
 * On invalid arguments, a non-NULL out_line is reset to zero and an empty view.
 */
MarkyStatus marky_document_quote_line_at(const MarkyDocument* document, size_t block_index,
                                        size_t line_index, MarkyQuoteLineView* out_line);

/*
 * Returns the table's column count or body row count. Both return zero for an
 * invalid index or non-table. The header is not part of the body row count.
 */
size_t marky_document_table_column_count(const MarkyDocument* document, size_t block_index);
size_t marky_document_table_row_count(const MarkyDocument* document, size_t block_index);

/*
 * Returns the number of cells through the last nonempty body cell. Returns
 * zero for an empty row or invalid index. The remaining columns are empty.
 */
size_t marky_document_table_row_content_count(const MarkyDocument* document, size_t block_index,
                                              size_t row_index);

/*
 * Reads the alignment and prepared Markdown header at a zero-based column.
 * The UTF-8 view is valid until document release. On invalid arguments, a
 * non-NULL out_column is reset to invalid alignment and an empty view.
 */
MarkyStatus marky_document_table_column_at(const MarkyDocument* document, size_t block_index,
                                          size_t column_index, MarkyTableColumnView* out_column);

/*
 * Reads prepared Markdown at a zero-based body row and column. Short rows
 * expose empty cells through the last column. Surplus cells are discarded.
 * The UTF-8 view is valid until document release. On invalid arguments, a
 * non-NULL out_cell is reset to {NULL, 0}.
 */
MarkyStatus marky_document_table_cell_at(const MarkyDocument* document, size_t block_index,
                                        size_t row_index, size_t column_index, MarkyUtf8View* out_cell);

/*
 * Reads raw alt text, destination and optional title at a zero-based block index.
 * The views borrow immutable UTF-8 bytes until document release. A missing title
 * is {NULL, 0}. A present empty title has a non-NULL data pointer and zero bytes.
 * On invalid arguments or a non-image block, a non-NULL out_image is zeroed.
 */
MarkyStatus marky_document_image_at(const MarkyDocument* document, size_t block_index,
                                    MarkyImageView* out_image);

/* Releases an owned result once and invalidates all its views. NULL is a no-op. */
void marky_document_release(MarkyDocument* document);

#ifdef __cplusplus
}
#endif

#endif
