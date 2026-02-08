/*!
 * \file bridging.h
 * \brief C bridging API for the Swift wrapper layer.
 *
 * All types and functions are C-compatible (extern "C") so that the Swift
 * module can import Cxgrammar without requiring C++ interoperability mode.
 */
#ifndef XGRAMMAR_BRIDGING_H_
#define XGRAMMAR_BRIDGING_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/*  Opaque handle types                                               */
/* ------------------------------------------------------------------ */

typedef struct xgrammar_grammar xgrammar_grammar;
typedef struct xgrammar_compiled_grammar xgrammar_compiled_grammar;
typedef struct xgrammar_grammar_compiler xgrammar_grammar_compiler;
typedef struct xgrammar_grammar_matcher xgrammar_grammar_matcher;
typedef struct xgrammar_tokenizer_info xgrammar_tokenizer_info;

/* ------------------------------------------------------------------ */
/*  Enumerations                                                      */
/* ------------------------------------------------------------------ */

typedef enum {
  XGRAMMAR_ERROR_NONE = 0,
  XGRAMMAR_ERROR_DESERIALIZE_VERSION = 1,
  XGRAMMAR_ERROR_DESERIALIZE_FORMAT = 2,
  XGRAMMAR_ERROR_INVALID_JSON = 3,
  XGRAMMAR_ERROR_INVALID_STRUCTURAL_TAG = 4,
  XGRAMMAR_ERROR_INVALID_JSON_SCHEMA = 5,
  XGRAMMAR_ERROR_UNKNOWN = 6
} xgrammar_error_kind;

typedef enum {
  XGRAMMAR_VOCAB_RAW = 0,
  XGRAMMAR_VOCAB_BYTE_FALLBACK = 1,
  XGRAMMAR_VOCAB_BYTE_LEVEL = 2
} xgrammar_vocab_type;

/* ------------------------------------------------------------------ */
/*  String management                                                 */
/* ------------------------------------------------------------------ */

/// Free a string returned by any xgrammar_* function.
void xgrammar_free_string(char *str);

/* ------------------------------------------------------------------ */
/*  Grammar                                                           */
/* ------------------------------------------------------------------ */

xgrammar_grammar *xgrammar_grammar_create_builtin_json(void);

xgrammar_grammar *xgrammar_grammar_create_from_ebnf(const char *ebnf,
                                                    const char *root_rule);

xgrammar_grammar *xgrammar_grammar_create_from_regex(const char *regex);

xgrammar_grammar *xgrammar_grammar_create_from_json_schema(
    const char *schema, bool any_whitespace, bool has_indent, int32_t indent,
    bool has_separators, const char *sep_item, const char *sep_line,
    bool strict_mode, bool has_max_whitespace, int32_t max_whitespace,
    bool print_converted_ebnf);

/// Returns NULL on failure; sets *out_error_kind and *out_error.
xgrammar_grammar *xgrammar_grammar_create_from_structural_tag(
    const char *json, xgrammar_error_kind *out_error_kind, char **out_error);

/// Returns NULL on failure; sets *out_error_kind and *out_error.
xgrammar_grammar *xgrammar_grammar_create_from_serialized_json(
    const char *json, xgrammar_error_kind *out_error_kind, char **out_error);

xgrammar_grammar *
xgrammar_grammar_create_union(const xgrammar_grammar *const *grammars,
                              int32_t count);

xgrammar_grammar *
xgrammar_grammar_create_concat(const xgrammar_grammar *const *grammars,
                               int32_t count);

void xgrammar_grammar_destroy(xgrammar_grammar *grammar);

/// Caller must free the returned string with xgrammar_free_string.
char *xgrammar_grammar_to_string(const xgrammar_grammar *grammar);

/// Caller must free the returned string with xgrammar_free_string.
char *xgrammar_grammar_serialize_json(const xgrammar_grammar *grammar);

/* ------------------------------------------------------------------ */
/*  Compiled Grammar                                                  */
/* ------------------------------------------------------------------ */

/// Returns NULL on failure; sets *out_error_kind and *out_error.
xgrammar_compiled_grammar *
xgrammar_compiled_grammar_create_from_serialized_json(
    const char *json, const xgrammar_tokenizer_info *tokenizer_info,
    xgrammar_error_kind *out_error_kind, char **out_error);

void xgrammar_compiled_grammar_destroy(xgrammar_compiled_grammar *cg);

/// Caller must destroy the returned grammar.
xgrammar_grammar *
xgrammar_compiled_grammar_get_grammar(const xgrammar_compiled_grammar *cg);

/// Caller must destroy the returned tokenizer info.
xgrammar_tokenizer_info *xgrammar_compiled_grammar_get_tokenizer_info(
    const xgrammar_compiled_grammar *cg);

size_t
xgrammar_compiled_grammar_memory_size(const xgrammar_compiled_grammar *cg);

/// Caller must free the returned string with xgrammar_free_string.
char *
xgrammar_compiled_grammar_serialize_json(const xgrammar_compiled_grammar *cg);

/* ------------------------------------------------------------------ */
/*  Grammar Compiler                                                  */
/* ------------------------------------------------------------------ */

xgrammar_grammar_compiler *
xgrammar_compiler_create(const xgrammar_tokenizer_info *tokenizer_info,
                         int32_t max_threads, bool cache_enabled,
                         int64_t max_memory_bytes);

void xgrammar_compiler_destroy(xgrammar_grammar_compiler *compiler);

/// Caller must destroy the returned compiled grammar.
xgrammar_compiled_grammar *
xgrammar_compiler_compile_grammar(xgrammar_grammar_compiler *compiler,
                                  const xgrammar_grammar *grammar);

/// Caller must destroy the returned compiled grammar.
xgrammar_compiled_grammar *xgrammar_compiler_compile_json_schema(
    xgrammar_grammar_compiler *compiler, const char *schema,
    bool any_whitespace, bool has_indent, int32_t indent, bool has_separators,
    const char *sep_item, const char *sep_line, bool strict_mode,
    bool has_max_whitespace, int32_t max_whitespace);

/// Caller must destroy the returned compiled grammar.
xgrammar_compiled_grammar *
xgrammar_compiler_compile_builtin_json(xgrammar_grammar_compiler *compiler);

int64_t xgrammar_compiler_cache_size(const xgrammar_grammar_compiler *compiler);

int64_t
xgrammar_compiler_cache_limit(const xgrammar_grammar_compiler *compiler);

void xgrammar_compiler_clear_cache(xgrammar_grammar_compiler *compiler);

/* ------------------------------------------------------------------ */
/*  Grammar Matcher                                                   */
/* ------------------------------------------------------------------ */

xgrammar_grammar_matcher *xgrammar_matcher_create(
    const xgrammar_compiled_grammar *compiled_grammar,
    const int32_t *override_stop_tokens, int32_t override_stop_token_count,
    bool has_override_stop_tokens, bool terminate_without_stop_token,
    int32_t max_rollback_tokens);

void xgrammar_matcher_destroy(xgrammar_grammar_matcher *matcher);

bool xgrammar_matcher_accept_token(xgrammar_grammar_matcher *matcher,
                                   int32_t token_id);

bool xgrammar_matcher_accept_string(xgrammar_grammar_matcher *matcher,
                                    const char *str);

bool xgrammar_matcher_fill_next_token_bitmask(xgrammar_grammar_matcher *matcher,
                                              int32_t *bitmask_data,
                                              int32_t bitmask_count,
                                              int32_t index);

/// Caller must free the returned string with xgrammar_free_string.
char *
xgrammar_matcher_find_jump_forward_string(xgrammar_grammar_matcher *matcher);

void xgrammar_matcher_rollback(xgrammar_grammar_matcher *matcher,
                               int32_t num_tokens);

void xgrammar_matcher_reset(xgrammar_grammar_matcher *matcher);

bool xgrammar_matcher_is_terminated(const xgrammar_grammar_matcher *matcher);

int32_t
xgrammar_matcher_stop_token_ids_count(const xgrammar_grammar_matcher *matcher);

int32_t
xgrammar_matcher_stop_token_id_at(const xgrammar_grammar_matcher *matcher,
                                  int32_t index);

/// Caller must free the returned string with xgrammar_free_string.
char *xgrammar_matcher_debug_print(const xgrammar_grammar_matcher *matcher);

/* ------------------------------------------------------------------ */
/*  Tokenizer Info                                                    */
/* ------------------------------------------------------------------ */

xgrammar_tokenizer_info *xgrammar_tokenizer_info_create(
    const char *const *encoded_vocab, int32_t encoded_vocab_count,
    xgrammar_vocab_type vocab_type, int32_t vocab_size, bool has_vocab_size,
    const int32_t *stop_token_ids, int32_t stop_token_count,
    bool has_stop_token_ids, bool add_prefix_space);

xgrammar_tokenizer_info *xgrammar_tokenizer_info_create_from_vocab_and_metadata(
    const char *const *encoded_vocab, int32_t encoded_vocab_count,
    const char *metadata);

/// Returns NULL on failure; sets *out_error_kind and *out_error.
xgrammar_tokenizer_info *xgrammar_tokenizer_info_create_from_serialized_json(
    const char *json, xgrammar_error_kind *out_error_kind, char **out_error);

void xgrammar_tokenizer_info_destroy(xgrammar_tokenizer_info *info);

xgrammar_vocab_type
xgrammar_tokenizer_info_vocab_type(const xgrammar_tokenizer_info *info);

bool xgrammar_tokenizer_info_add_prefix_space(
    const xgrammar_tokenizer_info *info);

int32_t xgrammar_tokenizer_info_vocab_size(const xgrammar_tokenizer_info *info);

/// Caller must free the returned string with xgrammar_free_string.
char *
xgrammar_tokenizer_info_dump_metadata(const xgrammar_tokenizer_info *info);

/// Caller must free the returned string with xgrammar_free_string.
char *
xgrammar_tokenizer_info_serialize_json(const xgrammar_tokenizer_info *info);

/// Caller must free the returned string with xgrammar_free_string.
char *xgrammar_tokenizer_info_detect_metadata_from_hf(const char *backend_str);

int32_t xgrammar_tokenizer_info_decoded_vocab_count(
    const xgrammar_tokenizer_info *info);

/// Caller must free the returned string with xgrammar_free_string.
char *
xgrammar_tokenizer_info_decoded_vocab_at(const xgrammar_tokenizer_info *info,
                                         int32_t index);

int32_t xgrammar_tokenizer_info_stop_token_ids_count(
    const xgrammar_tokenizer_info *info);

int32_t
xgrammar_tokenizer_info_stop_token_id_at(const xgrammar_tokenizer_info *info,
                                         int32_t index);

int32_t xgrammar_tokenizer_info_special_token_ids_count(
    const xgrammar_tokenizer_info *info);

int32_t
xgrammar_tokenizer_info_special_token_id_at(const xgrammar_tokenizer_info *info,
                                            int32_t index);

/* ------------------------------------------------------------------ */
/*  Utility                                                           */
/* ------------------------------------------------------------------ */

int32_t xgrammar_get_bitmask_size(int32_t vocab_size);

int32_t xgrammar_get_max_recursion_depth(void);
void xgrammar_set_max_recursion_depth(int32_t depth);

/// Caller must free the returned string with xgrammar_free_string.
char *xgrammar_get_serialization_version(void);

#ifdef __cplusplus
}
#endif

#endif /* XGRAMMAR_BRIDGING_H_ */
