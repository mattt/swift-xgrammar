/*!
 * \file bridging.cc
 * \brief C bridging API implementation.
 */
#include "bridging.h"

#include <dlpack/dlpack.h>
#include <xgrammar/compiler.h>
#include <xgrammar/config.h>
#include <xgrammar/exception.h>
#include <xgrammar/grammar.h>
#include <xgrammar/matcher.h>
#include <xgrammar/object.h>
#include <xgrammar/tokenizer_info.h>

#include <cstdlib>
#include <cstring>
#include <optional>
#include <string>
#include <variant>
#include <vector>

/* ------------------------------------------------------------------ */
/*  Opaque handle definitions                                         */
/* ------------------------------------------------------------------ */

struct xgrammar_grammar {
  xgrammar::Grammar obj;
};

struct xgrammar_compiled_grammar {
  xgrammar::CompiledGrammar obj;
};

struct xgrammar_grammar_compiler {
  xgrammar::GrammarCompiler obj;
};

struct xgrammar_grammar_matcher {
  xgrammar::GrammarMatcher obj;
};

struct xgrammar_tokenizer_info {
  xgrammar::TokenizerInfo obj;
};

/* ------------------------------------------------------------------ */
/*  Internal helpers                                                  */
/* ------------------------------------------------------------------ */

namespace {

char* copy_string(const std::string& str) {
  char* result = static_cast<char*>(std::malloc(str.size() + 1));
  if (result) {
    std::memcpy(result, str.c_str(), str.size() + 1);
  }
  return result;
}

template <typename VariantType>
std::string variant_error_to_string(const VariantType& error) {
  return std::visit([](const auto& err) { return std::string(err.what()); }, error);
}

xgrammar_error_kind error_kind_from_serialization(const xgrammar::SerializationError& error) {
  if (std::holds_alternative<xgrammar::DeserializeVersionError>(error))
    return XGRAMMAR_ERROR_DESERIALIZE_VERSION;
  if (std::holds_alternative<xgrammar::DeserializeFormatError>(error))
    return XGRAMMAR_ERROR_DESERIALIZE_FORMAT;
  if (std::holds_alternative<xgrammar::InvalidJSONError>(error)) return XGRAMMAR_ERROR_INVALID_JSON;
  return XGRAMMAR_ERROR_UNKNOWN;
}

xgrammar_error_kind error_kind_from_structural_tag(const xgrammar::StructuralTagError& error) {
  if (std::holds_alternative<xgrammar::InvalidJSONError>(error)) return XGRAMMAR_ERROR_INVALID_JSON;
  if (std::holds_alternative<xgrammar::InvalidJSONSchemaError>(error))
    return XGRAMMAR_ERROR_INVALID_JSON_SCHEMA;
  if (std::holds_alternative<xgrammar::InvalidStructuralTagError>(error))
    return XGRAMMAR_ERROR_INVALID_STRUCTURAL_TAG;
  return XGRAMMAR_ERROR_UNKNOWN;
}

std::vector<std::string> to_string_vector(const char* const* strings, int32_t count) {
  std::vector<std::string> result;
  if (strings && count > 0) {
    result.reserve(static_cast<size_t>(count));
    for (int32_t i = 0; i < count; ++i) {
      result.emplace_back(strings[i] ? strings[i] : "");
    }
  }
  return result;
}

xgrammar::VocabType to_vocab_type(xgrammar_vocab_type vt) {
  switch (vt) {
    case XGRAMMAR_VOCAB_BYTE_FALLBACK:
      return xgrammar::VocabType::BYTE_FALLBACK;
    case XGRAMMAR_VOCAB_BYTE_LEVEL:
      return xgrammar::VocabType::BYTE_LEVEL;
    default:
      return xgrammar::VocabType::RAW;
  }
}

}  // namespace

/* ------------------------------------------------------------------ */
/*  String management                                                 */
/* ------------------------------------------------------------------ */

void xgrammar_free_string(char* str) { std::free(str); }

/* ------------------------------------------------------------------ */
/*  Grammar                                                           */
/* ------------------------------------------------------------------ */

xgrammar_grammar* xgrammar_grammar_create_builtin_json(void) {
  return new xgrammar_grammar{xgrammar::Grammar::BuiltinJSONGrammar()};
}

xgrammar_grammar* xgrammar_grammar_create_from_ebnf(const char* ebnf, const char* root_rule) {
  return new xgrammar_grammar{
      xgrammar::Grammar::FromEBNF(std::string(ebnf), std::string(root_rule ? root_rule : "root"))
  };
}

xgrammar_grammar* xgrammar_grammar_create_from_regex(const char* regex) {
  return new xgrammar_grammar{xgrammar::Grammar::FromRegex(std::string(regex), false)};
}

xgrammar_grammar* xgrammar_grammar_create_from_json_schema(
    const char* schema,
    bool any_whitespace,
    bool has_indent,
    int32_t indent,
    bool has_separators,
    const char* sep_item,
    const char* sep_line,
    bool strict_mode,
    bool has_max_whitespace,
    int32_t max_whitespace,
    bool print_converted_ebnf
) {
  std::optional<int> indent_opt = has_indent ? std::optional<int>(indent) : std::nullopt;
  std::optional<std::pair<std::string, std::string>> separators_opt;
  if (has_separators) {
    separators_opt = std::make_pair(std::string(sep_item), std::string(sep_line));
  }
  std::optional<int> max_ws_opt =
      has_max_whitespace ? std::optional<int>(max_whitespace) : std::nullopt;

  return new xgrammar_grammar{xgrammar::Grammar::FromJSONSchema(
      std::string(schema),
      any_whitespace,
      indent_opt,
      separators_opt,
      strict_mode,
      max_ws_opt,
      print_converted_ebnf
  )};
}

xgrammar_grammar* xgrammar_grammar_create_from_structural_tag(
    const char* json, xgrammar_error_kind* out_error_kind, char** out_error
) {
  auto result = xgrammar::Grammar::FromStructuralTag(std::string(json));
  if (std::holds_alternative<xgrammar::Grammar>(result)) {
    if (out_error_kind) *out_error_kind = XGRAMMAR_ERROR_NONE;
    return new xgrammar_grammar{std::get<xgrammar::Grammar>(result)};
  }

  const auto& error = std::get<xgrammar::StructuralTagError>(result);
  if (out_error) *out_error = copy_string(variant_error_to_string(error));
  if (out_error_kind) *out_error_kind = error_kind_from_structural_tag(error);
  return nullptr;
}

xgrammar_grammar* xgrammar_grammar_create_from_serialized_json(
    const char* json, xgrammar_error_kind* out_error_kind, char** out_error
) {
  auto result = xgrammar::Grammar::DeserializeJSON(std::string(json));
  if (std::holds_alternative<xgrammar::Grammar>(result)) {
    if (out_error_kind) *out_error_kind = XGRAMMAR_ERROR_NONE;
    return new xgrammar_grammar{std::get<xgrammar::Grammar>(result)};
  }

  const auto& error = std::get<xgrammar::SerializationError>(result);
  if (out_error) *out_error = copy_string(variant_error_to_string(error));
  if (out_error_kind) *out_error_kind = error_kind_from_serialization(error);
  return nullptr;
}

xgrammar_grammar* xgrammar_grammar_create_union(
    const xgrammar_grammar* const* grammars, int32_t count
) {
  std::vector<xgrammar::Grammar> vec;
  if (grammars && count > 0) {
    vec.reserve(static_cast<size_t>(count));
    for (int32_t i = 0; i < count; ++i) {
      vec.push_back(grammars[i]->obj);
    }
  }
  return new xgrammar_grammar{xgrammar::Grammar::Union(vec)};
}

xgrammar_grammar* xgrammar_grammar_create_concat(
    const xgrammar_grammar* const* grammars, int32_t count
) {
  std::vector<xgrammar::Grammar> vec;
  if (grammars && count > 0) {
    vec.reserve(static_cast<size_t>(count));
    for (int32_t i = 0; i < count; ++i) {
      vec.push_back(grammars[i]->obj);
    }
  }
  return new xgrammar_grammar{xgrammar::Grammar::Concat(vec)};
}

void xgrammar_grammar_destroy(xgrammar_grammar* grammar) { delete grammar; }

char* xgrammar_grammar_to_string(const xgrammar_grammar* grammar) {
  return copy_string(grammar->obj.ToString());
}

char* xgrammar_grammar_serialize_json(const xgrammar_grammar* grammar) {
  return copy_string(grammar->obj.SerializeJSON());
}

/* ------------------------------------------------------------------ */
/*  Compiled Grammar                                                  */
/* ------------------------------------------------------------------ */

xgrammar_compiled_grammar* xgrammar_compiled_grammar_create_from_serialized_json(
    const char* json,
    const xgrammar_tokenizer_info* tokenizer_info,
    xgrammar_error_kind* out_error_kind,
    char** out_error
) {
  auto result = xgrammar::CompiledGrammar::DeserializeJSON(std::string(json), tokenizer_info->obj);
  if (std::holds_alternative<xgrammar::CompiledGrammar>(result)) {
    if (out_error_kind) *out_error_kind = XGRAMMAR_ERROR_NONE;
    return new xgrammar_compiled_grammar{std::get<xgrammar::CompiledGrammar>(result)};
  }

  const auto& error = std::get<xgrammar::SerializationError>(result);
  if (out_error) *out_error = copy_string(variant_error_to_string(error));
  if (out_error_kind) *out_error_kind = error_kind_from_serialization(error);
  return nullptr;
}

void xgrammar_compiled_grammar_destroy(xgrammar_compiled_grammar* cg) { delete cg; }

xgrammar_grammar* xgrammar_compiled_grammar_get_grammar(const xgrammar_compiled_grammar* cg) {
  return new xgrammar_grammar{cg->obj.GetGrammar()};
}

xgrammar_tokenizer_info* xgrammar_compiled_grammar_get_tokenizer_info(
    const xgrammar_compiled_grammar* cg
) {
  return new xgrammar_tokenizer_info{cg->obj.GetTokenizerInfo()};
}

size_t xgrammar_compiled_grammar_memory_size(const xgrammar_compiled_grammar* cg) {
  return cg->obj.MemorySizeBytes();
}

char* xgrammar_compiled_grammar_serialize_json(const xgrammar_compiled_grammar* cg) {
  return copy_string(cg->obj.SerializeJSON());
}

/* ------------------------------------------------------------------ */
/*  Grammar Compiler                                                  */
/* ------------------------------------------------------------------ */

xgrammar_grammar_compiler* xgrammar_compiler_create(
    const xgrammar_tokenizer_info* tokenizer_info,
    int32_t max_threads,
    bool cache_enabled,
    int64_t max_memory_bytes
) {
  return new xgrammar_grammar_compiler{
      xgrammar::GrammarCompiler(tokenizer_info->obj, max_threads, cache_enabled, max_memory_bytes)
  };
}

void xgrammar_compiler_destroy(xgrammar_grammar_compiler* compiler) { delete compiler; }

xgrammar_compiled_grammar* xgrammar_compiler_compile_grammar(
    xgrammar_grammar_compiler* compiler, const xgrammar_grammar* grammar
) {
  return new xgrammar_compiled_grammar{compiler->obj.CompileGrammar(grammar->obj)};
}

xgrammar_compiled_grammar* xgrammar_compiler_compile_json_schema(
    xgrammar_grammar_compiler* compiler,
    const char* schema,
    bool any_whitespace,
    bool has_indent,
    int32_t indent,
    bool has_separators,
    const char* sep_item,
    const char* sep_line,
    bool strict_mode,
    bool has_max_whitespace,
    int32_t max_whitespace
) {
  std::optional<int> indent_opt = has_indent ? std::optional<int>(indent) : std::nullopt;
  std::optional<std::pair<std::string, std::string>> separators_opt;
  if (has_separators) {
    separators_opt = std::make_pair(std::string(sep_item), std::string(sep_line));
  }
  std::optional<int> max_ws_opt =
      has_max_whitespace ? std::optional<int>(max_whitespace) : std::nullopt;

  return new xgrammar_compiled_grammar{compiler->obj.CompileJSONSchema(
      std::string(schema), any_whitespace, indent_opt, separators_opt, strict_mode, max_ws_opt
  )};
}

xgrammar_compiled_grammar* xgrammar_compiler_compile_builtin_json(
    xgrammar_grammar_compiler* compiler
) {
  return new xgrammar_compiled_grammar{compiler->obj.CompileBuiltinJSONGrammar()};
}

int64_t xgrammar_compiler_cache_size(const xgrammar_grammar_compiler* compiler) {
  return compiler->obj.GetCacheSizeBytes();
}

int64_t xgrammar_compiler_cache_limit(const xgrammar_grammar_compiler* compiler) {
  return compiler->obj.CacheLimitBytes();
}

void xgrammar_compiler_clear_cache(xgrammar_grammar_compiler* compiler) {
  compiler->obj.ClearCache();
}

/* ------------------------------------------------------------------ */
/*  Grammar Matcher                                                   */
/* ------------------------------------------------------------------ */

xgrammar_grammar_matcher* xgrammar_matcher_create(
    const xgrammar_compiled_grammar* compiled_grammar,
    const int32_t* override_stop_tokens,
    int32_t override_stop_token_count,
    bool has_override_stop_tokens,
    bool terminate_without_stop_token,
    int32_t max_rollback_tokens
) {
  std::optional<std::vector<int32_t>> override_opt;
  if (has_override_stop_tokens) {
    if (override_stop_tokens && override_stop_token_count > 0) {
      override_opt.emplace(override_stop_tokens, override_stop_tokens + override_stop_token_count);
    } else {
      override_opt.emplace();
    }
  }
  return new xgrammar_grammar_matcher{xgrammar::GrammarMatcher(
      compiled_grammar->obj, override_opt, terminate_without_stop_token, max_rollback_tokens
  )};
}

void xgrammar_matcher_destroy(xgrammar_grammar_matcher* matcher) { delete matcher; }

bool xgrammar_matcher_accept_token(xgrammar_grammar_matcher* matcher, int32_t token_id) {
  return matcher->obj.AcceptToken(token_id, false);
}

bool xgrammar_matcher_accept_string(xgrammar_grammar_matcher* matcher, const char* str) {
  return matcher->obj.AcceptString(std::string(str), false);
}

bool xgrammar_matcher_fill_next_token_bitmask(
    xgrammar_grammar_matcher* matcher, int32_t* bitmask_data, int32_t bitmask_count, int32_t index
) {
  if (!matcher || !bitmask_data || bitmask_count <= 0) return false;

  int64_t shape[1] = {static_cast<int64_t>(bitmask_count)};
  DLTensor bitmask;
  bitmask.data = bitmask_data;
  bitmask.device = DLDevice{kDLCPU, 0};
  bitmask.ndim = 1;
  bitmask.dtype = DLDataType{kDLInt, 32, 1};
  bitmask.shape = shape;
  bitmask.strides = nullptr;
  bitmask.byte_offset = 0;

  return matcher->obj.FillNextTokenBitmask(&bitmask, index, false);
}

char* xgrammar_matcher_find_jump_forward_string(xgrammar_grammar_matcher* matcher) {
  return copy_string(matcher->obj.FindJumpForwardString());
}

void xgrammar_matcher_rollback(xgrammar_grammar_matcher* matcher, int32_t num_tokens) {
  matcher->obj.Rollback(num_tokens);
}

void xgrammar_matcher_reset(xgrammar_grammar_matcher* matcher) { matcher->obj.Reset(); }

bool xgrammar_matcher_is_terminated(const xgrammar_grammar_matcher* matcher) {
  return matcher->obj.IsTerminated();
}

int32_t xgrammar_matcher_stop_token_ids_count(const xgrammar_grammar_matcher* matcher) {
  return static_cast<int32_t>(matcher->obj.GetStopTokenIds().size());
}

int32_t xgrammar_matcher_stop_token_id_at(const xgrammar_grammar_matcher* matcher, int32_t index) {
  const auto& ids = matcher->obj.GetStopTokenIds();
  if (index < 0 || index >= static_cast<int32_t>(ids.size())) return 0;
  return ids[static_cast<size_t>(index)];
}

char* xgrammar_matcher_debug_print(const xgrammar_grammar_matcher* matcher) {
  return copy_string(matcher->obj._DebugPrintInternalState());
}

/* ------------------------------------------------------------------ */
/*  Tokenizer Info                                                    */
/* ------------------------------------------------------------------ */

xgrammar_tokenizer_info* xgrammar_tokenizer_info_create(
    const char* const* encoded_vocab,
    int32_t encoded_vocab_count,
    xgrammar_vocab_type vocab_type,
    int32_t vocab_size,
    bool has_vocab_size,
    const int32_t* stop_token_ids,
    int32_t stop_token_count,
    bool has_stop_token_ids,
    bool add_prefix_space
) {
  auto vec = to_string_vector(encoded_vocab, encoded_vocab_count);

  std::optional<int> vocab_size_opt =
      has_vocab_size ? std::optional<int>(vocab_size) : std::nullopt;

  std::optional<std::vector<int32_t>> stop_opt;
  if (has_stop_token_ids) {
    if (stop_token_ids && stop_token_count > 0) {
      stop_opt.emplace(stop_token_ids, stop_token_ids + stop_token_count);
    } else {
      stop_opt.emplace();
    }
  }

  return new xgrammar_tokenizer_info{xgrammar::TokenizerInfo(
      vec, to_vocab_type(vocab_type), vocab_size_opt, stop_opt, add_prefix_space
  )};
}

xgrammar_tokenizer_info* xgrammar_tokenizer_info_create_from_vocab_and_metadata(
    const char* const* encoded_vocab, int32_t encoded_vocab_count, const char* metadata
) {
  auto vec = to_string_vector(encoded_vocab, encoded_vocab_count);
  return new xgrammar_tokenizer_info{
      xgrammar::TokenizerInfo::FromVocabAndMetadata(vec, std::string(metadata))
  };
}

xgrammar_tokenizer_info* xgrammar_tokenizer_info_create_from_serialized_json(
    const char* json, xgrammar_error_kind* out_error_kind, char** out_error
) {
  auto result = xgrammar::TokenizerInfo::DeserializeJSON(std::string(json));
  if (std::holds_alternative<xgrammar::TokenizerInfo>(result)) {
    if (out_error_kind) *out_error_kind = XGRAMMAR_ERROR_NONE;
    return new xgrammar_tokenizer_info{std::get<xgrammar::TokenizerInfo>(result)};
  }

  const auto& error = std::get<xgrammar::SerializationError>(result);
  if (out_error) *out_error = copy_string(variant_error_to_string(error));
  if (out_error_kind) *out_error_kind = error_kind_from_serialization(error);
  return nullptr;
}

void xgrammar_tokenizer_info_destroy(xgrammar_tokenizer_info* info) { delete info; }

xgrammar_vocab_type xgrammar_tokenizer_info_vocab_type(const xgrammar_tokenizer_info* info) {
  switch (info->obj.GetVocabType()) {
    case xgrammar::VocabType::BYTE_FALLBACK:
      return XGRAMMAR_VOCAB_BYTE_FALLBACK;
    case xgrammar::VocabType::BYTE_LEVEL:
      return XGRAMMAR_VOCAB_BYTE_LEVEL;
    default:
      return XGRAMMAR_VOCAB_RAW;
  }
}

bool xgrammar_tokenizer_info_add_prefix_space(const xgrammar_tokenizer_info* info) {
  return info->obj.GetAddPrefixSpace();
}

int32_t xgrammar_tokenizer_info_vocab_size(const xgrammar_tokenizer_info* info) {
  return static_cast<int32_t>(info->obj.GetVocabSize());
}

char* xgrammar_tokenizer_info_dump_metadata(const xgrammar_tokenizer_info* info) {
  return copy_string(info->obj.DumpMetadata());
}

char* xgrammar_tokenizer_info_serialize_json(const xgrammar_tokenizer_info* info) {
  return copy_string(info->obj.SerializeJSON());
}

char* xgrammar_tokenizer_info_detect_metadata_from_hf(const char* backend_str) {
  return copy_string(xgrammar::TokenizerInfo::DetectMetadataFromHF(std::string(backend_str)));
}

int32_t xgrammar_tokenizer_info_decoded_vocab_count(const xgrammar_tokenizer_info* info) {
  return static_cast<int32_t>(info->obj.GetDecodedVocab().size());
}

char* xgrammar_tokenizer_info_decoded_vocab_at(const xgrammar_tokenizer_info* info, int32_t index) {
  const auto& vocab = info->obj.GetDecodedVocab();
  if (index < 0 || index >= static_cast<int32_t>(vocab.size())) return copy_string("");
  return copy_string(vocab[static_cast<size_t>(index)]);
}

int32_t xgrammar_tokenizer_info_stop_token_ids_count(const xgrammar_tokenizer_info* info) {
  return static_cast<int32_t>(info->obj.GetStopTokenIds().size());
}

int32_t xgrammar_tokenizer_info_stop_token_id_at(
    const xgrammar_tokenizer_info* info, int32_t index
) {
  const auto& ids = info->obj.GetStopTokenIds();
  if (index < 0 || index >= static_cast<int32_t>(ids.size())) return 0;
  return ids[static_cast<size_t>(index)];
}

int32_t xgrammar_tokenizer_info_special_token_ids_count(const xgrammar_tokenizer_info* info) {
  return static_cast<int32_t>(info->obj.GetSpecialTokenIds().size());
}

int32_t xgrammar_tokenizer_info_special_token_id_at(
    const xgrammar_tokenizer_info* info, int32_t index
) {
  const auto& ids = info->obj.GetSpecialTokenIds();
  if (index < 0 || index >= static_cast<int32_t>(ids.size())) return 0;
  return ids[static_cast<size_t>(index)];
}

/* ------------------------------------------------------------------ */
/*  Utility                                                           */
/* ------------------------------------------------------------------ */

int32_t xgrammar_get_bitmask_size(int32_t vocab_size) {
  return xgrammar::GetBitmaskSize(vocab_size);
}

int32_t xgrammar_get_max_recursion_depth(void) {
  return static_cast<int32_t>(xgrammar::GetMaxRecursionDepth());
}

void xgrammar_set_max_recursion_depth(int32_t depth) { xgrammar::SetMaxRecursionDepth(depth); }

char* xgrammar_get_serialization_version(void) {
  return copy_string(xgrammar::GetSerializationVersion());
}
