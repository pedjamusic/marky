#ifndef MARKY_CORE_H
#define MARKY_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MarkyDocument MarkyDocument;
typedef struct MarkyProjectFavoriteResult MarkyProjectFavoriteResult;
typedef struct MarkyProjectTree MarkyProjectTree;
typedef struct MarkyProjectQueryResult MarkyProjectQueryResult;
typedef struct MarkyCancellationToken MarkyCancellationToken;
typedef uint32_t MarkyStatus;
typedef uint32_t MarkyBlockKind;
typedef uint32_t MarkyListMarkerKind;
typedef uint32_t MarkyTableAlignment;
typedef uint32_t MarkyInlineFlags;

enum {
    MARKY_STATUS_OK = 0,
    MARKY_STATUS_INVALID_ARGUMENT = 1,
    MARKY_STATUS_ALLOCATION_FAILURE = 2,
    MARKY_STATUS_INTERNAL_ERROR = 3,
    MARKY_STATUS_CANCELLED = 4,
    MARKY_STATUS_PROJECT_SCAN_UNKNOWN = 5,
    MARKY_STATUS_PROJECT_SCAN_FAILED = 6,
    MARKY_STATUS_PROJECT_NODE_NOT_FOUND = 7
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

enum {
    MARKY_INLINE_EMPHASIS = 1,
    MARKY_INLINE_STRONG = 2,
    MARKY_INLINE_STRIKETHROUGH = 4,
    MARKY_INLINE_CODE = 8,
    MARKY_INLINE_LINE_BREAK = 16,
    MARKY_INLINE_IMAGE_ALT = 32
};

typedef struct {
    const char* data;
    size_t byte_count;
} MarkyUtf8View;

typedef uint32_t MarkyProjectEntryKind;

enum {
    MARKY_PROJECT_ENTRY_UNKNOWN = 0,
    MARKY_PROJECT_ENTRY_REGULAR_FILE = 1,
    MARKY_PROJECT_ENTRY_DIRECTORY = 2,
    MARKY_PROJECT_ENTRY_SYMLINK = 3,
    MARKY_PROJECT_ENTRY_PACKAGE = 4,
    MARKY_PROJECT_ENTRY_OTHER = 5
};

typedef uint32_t MarkyProjectEntryDisposition;

enum {
    MARKY_PROJECT_ENTRY_SKIP = 0,
    MARKY_PROJECT_ENTRY_DOCUMENT = 1,
    MARKY_PROJECT_ENTRY_SCAN_DIRECTORY = 2,
    MARKY_PROJECT_ENTRY_NEEDS_TARGET_METADATA = 3
};

typedef struct {
    MarkyUtf8View name_extension;
    MarkyProjectEntryKind kind;
    MarkyProjectEntryKind target_kind;
    uint8_t is_hidden;
} MarkyProjectEntryMetadata;

/*
 * Classifies one enumerated child using native-supplied metadata. Pass the final
 * extension without its dot, in caller-validated UTF-8. For links, pass the
 * link's own extension and the resolved target's kind. Package status takes
 * precedence over file type. is_hidden includes native flags and dot names.
 *
 * An eligible link with unknown target kind requires more metadata. Native
 * probe failures remain scan failures according to the host's scan policy.
 * A document decision belongs to the original entry and carries no target
 * identity. The call neither borrows beyond return nor accesses the filesystem.
 */
MarkyProjectEntryDisposition marky_project_classify_entry(MarkyProjectEntryMetadata entry);

typedef uint32_t MarkyProjectScanState;

enum {
    MARKY_PROJECT_SCAN_UNKNOWN = 0,
    MARKY_PROJECT_SCAN_COMPLETE = 1,
    MARKY_PROJECT_SCAN_PARTIAL = 2,
    MARKY_PROJECT_SCAN_FAILED = 3
};

typedef uint32_t MarkyProjectFavoriteAvailability;

enum {
    MARKY_PROJECT_FAVORITE_UNKNOWN = 0,
    MARKY_PROJECT_FAVORITE_INDEXED_DOCUMENT = 1,
    MARKY_PROJECT_FAVORITE_EXCLUDED_EXISTING = 2,
    MARKY_PROJECT_FAVORITE_UNAVAILABLE = 3,
    MARKY_PROJECT_FAVORITE_AUTHORIZED_MISSING = 4
};

typedef uint32_t MarkyProjectFavoriteDisposition;

enum {
    MARKY_PROJECT_FAVORITE_RETAIN_HIDDEN = 0,
    MARKY_PROJECT_FAVORITE_RETAIN_VISIBLE = 1,
    MARKY_PROJECT_FAVORITE_PRUNE = 2
};

/*
 * Decides membership for one saved favorite using native-supplied evidence.
 * INDEXED_DOCUMENT means an eligible document in the current indexed view.
 * EXCLUDED_EXISTING means an existing entry excluded from that view.
 * AUTHORIZED_MISSING means a native probe under an authorized grant confirmed
 * absence; absence from the index alone is insufficient evidence.
 *
 * Indexed documents are visible for COMPLETE and PARTIAL scans. Only COMPLETE
 * plus AUTHORIZED_MISSING permits pruning. All other combinations retain the
 * favorite hidden, including unknown enum values and UNKNOWN/FAILED scans
 * without a usable indexed view. The call performs no I/O or persistence.
 */
MarkyProjectFavoriteDisposition marky_project_favorite_membership(
    MarkyProjectScanState scan_state, MarkyProjectFavoriteAvailability availability);

typedef struct {
    const MarkyUtf8View* paths;
    size_t count;
} MarkyProjectFavoritePaths;

typedef struct {
    MarkyProjectFavoritePaths latest_canonical;
    MarkyProjectFavoritePaths latest_alias;
    MarkyProjectFavoritePaths confirmed_missing;
    MarkyProjectScanState scan_state;
    uint8_t alias_is_authorized;
} MarkyProjectFavoriteReconciliation;

/*
 * Reconcile one project's latest saved lists. Read them after asynchronous
 * probes finish and before committing the result. confirmed_missing contains
 * only paths whose absence was confirmed by an authorized native probe for
 * this project. Only a complete scan can apply those removals.
 *
 * Supply a nonzero alias_is_authorized only when the opened grant and its
 * distinct canonical project identity authorize migration. In that case the
 * result merges the supplied alias list and directs the caller to migrate
 * that one alias, even if its list is empty. Other saved project keys are
 * outside this operation. Native code owns identity, grants, and persistence.
 *
 * Path keys are caller-validated UTF-8, compared as exact bytes. Use the same
 * native equality representation for all three lists. The result is a unique
 * canonical list in byte order. Native code can apply its own storage order.
 * Arrays and their bytes are borrowed until return. A nonzero count requires
 * a buffer in each used list. An unauthorized alias list and absence evidence
 * for an incomplete scan are ignored. Empty keys are preserved unless pruned.
 *
 * Failure or cancellation leaves *out_result NULL. The optional cancellation
 * token follows marky_document_create_cancellable.
 */
MarkyStatus marky_project_reconcile_favorites(MarkyProjectFavoriteReconciliation input,
                                             const MarkyCancellationToken* token,
                                             MarkyProjectFavoriteResult** out_result);

size_t marky_project_favorite_result_count(const MarkyProjectFavoriteResult* result);
uint8_t marky_project_favorite_result_migrates_alias(const MarkyProjectFavoriteResult* result);

/* The view borrows result storage until release. NULL or out of range yields an empty view. */
MarkyUtf8View marky_project_favorite_result_path(const MarkyProjectFavoriteResult* result, size_t index);
void marky_project_favorite_result_release(MarkyProjectFavoriteResult* result);

typedef struct {
    MarkyUtf8View identity;
    MarkyUtf8View name;
    size_t parent_index;
    MarkyProjectEntryMetadata metadata;
} MarkyProjectTreeEntry;

typedef struct {
    MarkyUtf8View identity;
    MarkyUtf8View name;
    size_t parent_index;
    uint8_t is_directory;
} MarkyProjectTreeNodeView;

/*
 * Builds an owned tree from native enumeration. Entry 0 is the project root;
 * its parent_index is 0 and its metadata is ignored. Every other entry refers
 * to an earlier traversable directory. Supply stable, nonempty opaque UTF-8
 * identities unique within the project. Supply names as caller-validated UTF-8,
 * one relative path segment per child. The root's display name may be empty.
 * Identities and names are copied verbatim. Duplicate retained identities or
 * duplicate retained names under the same parent return INVALID_ARGUMENT.
 *
 * The result retains the root, eligible documents, and their ancestors in
 * supplied order. Its node indices are dense, and parent_index refers to the
 * result's indices. Indices belong to this tree only. Retained document links
 * keep their entry's own identity across builds.
 *
 * COMPLETE represents a successful full scan. PARTIAL represents an
 * intentionally limited view of known entries, such as a single picked file.
 * UNKNOWN and FAILED return the corresponding status without reading entries.
 * Unresolved visible metadata needed for a decision returns PROJECT_SCAN_UNKNOWN.
 * Absence from any tree is insufficient on its own to remove a favorite;
 * a complete scan permits the host to run its authorized absence probes.
 *
 * Inputs and the optional cancellation token are borrowed until return.
 * Any failure leaves *out_tree NULL. See marky_document_create_cancellable
 * for the cancellation and token-lifetime contract.
 */
MarkyStatus marky_project_tree_create(const MarkyProjectTreeEntry* entries, size_t entry_count,
                                     MarkyProjectScanState scan_state, const MarkyCancellationToken* token,
                                     MarkyProjectTree** out_tree);

/* NULL is a no-op for release, and yields UNKNOWN state and zero nodes. */
void marky_project_tree_release(MarkyProjectTree* tree);
MarkyProjectScanState marky_project_tree_scan_state(const MarkyProjectTree* tree);
size_t marky_project_tree_node_count(const MarkyProjectTree* tree);

/* Copies a node view. Its immutable UTF-8 views remain valid until tree release. */
MarkyStatus marky_project_tree_node_at(const MarkyProjectTree* tree, size_t index,
                                      MarkyProjectTreeNodeView* out_node);

/*
 * Look up a retained node by identity or by root-relative name segments.
 * Comparisons use exact bytes. Zero segments select the root. Each supplied
 * identity or segment must have nonempty storage. The call borrows inputs
 * until return and writes *out_index only on success. A well-formed lookup
 * with no match in this tree returns PROJECT_NODE_NOT_FOUND.
 */
MarkyStatus marky_project_tree_find_identity(const MarkyProjectTree* tree, MarkyUtf8View identity,
                                            size_t* out_index);
MarkyStatus marky_project_tree_find_path(const MarkyProjectTree* tree, const MarkyUtf8View* segments,
                                        size_t segment_count, size_t* out_index);

typedef struct {
    size_t node_index;
    uint8_t matches_relative_path;
} MarkyProjectFavoriteMatch;

typedef struct {
    const uint8_t* name_matches;
    size_t name_match_count;
    const MarkyProjectFavoriteMatch* favorites;
    size_t favorite_count;
} MarkyProjectQuery;

typedef struct {
    const size_t* file_indices;
    size_t file_count;
    const size_t* favorite_indices;
    size_t favorite_count;
} MarkyProjectQueryResultView;

/*
 * A NULL name_matches with zero count represents an empty normalized query.
 * Otherwise supply one native name-match flag per tree node, including the
 * root, whose flag is ignored. Nonzero flags mean match. The files result
 * omits the root and retains direct matches and their ancestors in tree order.
 *
 * Pass visible-tree document favorites once each in native display order.
 * A favorite matches a nonempty query when its name or relative path matches.
 * An empty query returns all nonroot nodes and all supplied favorites.
 * Result indices refer to the input tree. Its scan state and membership are
 * unaffected by filtering.
 *
 * Inputs are borrowed until return. The optional cancellation token follows
 * marky_document_create_cancellable. Failure leaves *out_result NULL.
 */
MarkyStatus marky_project_tree_filter(const MarkyProjectTree* tree, MarkyProjectQuery query,
                                      const MarkyCancellationToken* token,
                                      MarkyProjectQueryResult** out_result);

/* Views borrow immutable result storage until release. NULL yields an empty view. */
MarkyProjectQueryResultView marky_project_query_result_view(const MarkyProjectQueryResult* result);
void marky_project_query_result_release(MarkyProjectQueryResult* result);

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

typedef struct {
    size_t block_index;
    size_t row_index;
    size_t column_index;
} MarkyInlineLocation;

typedef struct {
    MarkyInlineFlags flags;
    size_t source_begin;
    size_t source_end;
    MarkyUtf8View text;
    MarkyUtf8View link_destination;
    MarkyUtf8View link_title;
    MarkyUtf8View image_destination;
    MarkyUtf8View image_title;
} MarkyInlineRunView;

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
 * Block text for paragraphs and headings is prepared Markdown.
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

/*
 * Uses the same ownership and cancellation rules as marky_document_create_cancellable.
 * A reader can supply a caller-validated UTF-8 prefix with no CR or LF to
 * reproduce nested quote markers that participate in inline parsing. The
 * parser repeats the prefix depth - 1 times at the start of each nested quote
 * line. Quote line views still expose the original prepared source and depth.
 * An empty prefix gives the ordinary portable quote representation.
 */
MarkyStatus marky_document_create_with_quote_prefix(const char* utf8, size_t byte_count,
                                                    const MarkyCancellationToken* token,
                                                    MarkyUtf8View nested_quote_prefix,
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

/*
 * Inline regions use zero-based locations. Use row and column zero for a
 * paragraph, heading, or entire quote body. A list uses its item index as
 * the row and column zero. A table uses row zero for headers, followed by
 * body rows, with the column index for each cell.
 *
 * Count returns zero for an invalid location or an empty region. Run access
 * zeroes a non-NULL output on failure. All successful views borrow immutable
 * UTF-8 until document release. Optional fields use a NULL data pointer when
 * absent and a non-NULL pointer when present, including empty strings.
 * Source ranges are half-open byte offsets in the prepared region. For a
 * quote, the source is its prepared lines joined with LF, including any
 * prefix supplied at creation. An image alt run
 * spans the whole image expression.
 * An image alt run may also carry a link if the image is inside a link label.
 */
size_t marky_document_inline_run_count(const MarkyDocument* document, MarkyInlineLocation location);
MarkyStatus marky_document_inline_run_at(const MarkyDocument* document, MarkyInlineLocation location,
                                         size_t run_index, MarkyInlineRunView* out_run);

/* Releases an owned result once and invalidates all its views. NULL is a no-op. */
void marky_document_release(MarkyDocument* document);

#ifdef __cplusplus
}
#endif

#endif
