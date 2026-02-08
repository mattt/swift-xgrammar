/*!
 * \file bridging.cc
 * \brief C++ bridging functions for the Swift API layer.
 */
#include "bridging.h"

#include <dlpack/dlpack.h>
#include <xgrammar/exception.h>
#include <xgrammar/object.h>

#include <optional>
#include <variant>

namespace xgrammar {
namespace bridging {

namespace {

template <typename VariantType>
std::string VariantErrorToString(const VariantType& error) {
  return std::visit([](const auto& err) { return std::string(err.what()); }, error);
}

ErrorKind ErrorKindFromSerializationError(const SerializationError& error) {
  if (std::holds_alternative<DeserializeVersionError>(error)) {
    return ErrorKind::kDeserializeVersion;
  }
  if (std::holds_alternative<DeserializeFormatError>(error)) {
    return ErrorKind::kDeserializeFormat;
  }
  if (std::holds_alternative<InvalidJSONError>(error)) {
    return ErrorKind::kInvalidJSON;
  }
  return ErrorKind::kUnknown;
}

ErrorKind ErrorKindFromStructuralTagError(const StructuralTagError& error) {
  if (std::holds_alternative<InvalidJSONError>(error)) {
    return ErrorKind::kInvalidJSON;
  }
  if (std::holds_alternative<InvalidJSONSchemaError>(error)) {
    return ErrorKind::kInvalidJSONSchema;
  }
  if (std::holds_alternative<InvalidStructuralTagError>(error)) {
    return ErrorKind::kInvalidStructuralTag;
  }
  return ErrorKind::kUnknown;
}

}  // namespace

bool FillNextTokenBitmask(
    GrammarMatcher* matcher,
    int32_t* bitmask_data,
    int32_t bitmask_count,
    int index,
    bool debug_print
) {
  if (matcher == nullptr || bitmask_data == nullptr || bitmask_count <= 0) {
    return false;
  }

  int64_t shape[1] = {static_cast<int64_t>(bitmask_count)};
  DLTensor bitmask;
  bitmask.data = bitmask_data;
  bitmask.device = DLDevice{kDLCPU, 0};
  bitmask.ndim = 1;
  bitmask.dtype = DLDataType{kDLInt, 32, 1};
  bitmask.shape = shape;
  bitmask.strides = nullptr;
  bitmask.byte_offset = 0;

  return matcher->FillNextTokenBitmask(&bitmask, index, debug_print);
}

bool GrammarDeserializeJSON(
    const std::string& json_string,
    Grammar* out_grammar,
    std::string* out_error,
    ErrorKind* out_error_kind
) {
  auto result = Grammar::DeserializeJSON(json_string);
  if (std::holds_alternative<Grammar>(result)) {
    if (out_grammar != nullptr) {
      *out_grammar = std::get<Grammar>(result);
    }
    if (out_error_kind != nullptr) {
      *out_error_kind = ErrorKind::kNone;
    }
    return true;
  }

  const auto& error = std::get<SerializationError>(result);
  if (out_error != nullptr) {
    *out_error = VariantErrorToString(error);
  }
  if (out_error_kind != nullptr) {
    *out_error_kind = ErrorKindFromSerializationError(error);
  }
  return false;
}

bool TokenizerInfoDeserializeJSON(
    const std::string& json_string,
    TokenizerInfo* out_tokenizer,
    std::string* out_error,
    ErrorKind* out_error_kind
) {
  auto result = TokenizerInfo::DeserializeJSON(json_string);
  if (std::holds_alternative<TokenizerInfo>(result)) {
    if (out_tokenizer != nullptr) {
      *out_tokenizer = std::get<TokenizerInfo>(result);
    }
    if (out_error_kind != nullptr) {
      *out_error_kind = ErrorKind::kNone;
    }
    return true;
  }

  const auto& error = std::get<SerializationError>(result);
  if (out_error != nullptr) {
    *out_error = VariantErrorToString(error);
  }
  if (out_error_kind != nullptr) {
    *out_error_kind = ErrorKindFromSerializationError(error);
  }
  return false;
}

bool CompiledGrammarDeserializeJSON(
    const std::string& json_string,
    const TokenizerInfo& tokenizer_info,
    CompiledGrammar* out_compiled_grammar,
    std::string* out_error,
    ErrorKind* out_error_kind
) {
  auto result = CompiledGrammar::DeserializeJSON(json_string, tokenizer_info);
  if (std::holds_alternative<CompiledGrammar>(result)) {
    if (out_compiled_grammar != nullptr) {
      *out_compiled_grammar = std::get<CompiledGrammar>(result);
    }
    if (out_error_kind != nullptr) {
      *out_error_kind = ErrorKind::kNone;
    }
    return true;
  }

  const auto& error = std::get<SerializationError>(result);
  if (out_error != nullptr) {
    *out_error = VariantErrorToString(error);
  }
  if (out_error_kind != nullptr) {
    *out_error_kind = ErrorKindFromSerializationError(error);
  }
  return false;
}

bool GrammarFromStructuralTag(
    const std::string& structural_tag_json,
    Grammar* out_grammar,
    std::string* out_error,
    ErrorKind* out_error_kind
) {
  auto result = Grammar::FromStructuralTag(structural_tag_json);
  if (std::holds_alternative<Grammar>(result)) {
    if (out_grammar != nullptr) {
      *out_grammar = std::get<Grammar>(result);
    }
    if (out_error_kind != nullptr) {
      *out_error_kind = ErrorKind::kNone;
    }
    return true;
  }

  const auto& error = std::get<StructuralTagError>(result);
  if (out_error != nullptr) {
    *out_error = VariantErrorToString(error);
  }
  if (out_error_kind != nullptr) {
    *out_error_kind = ErrorKindFromStructuralTagError(error);
  }
  return false;
}

Grammar GrammarFromJSONSchema(
    const std::string& schema,
    bool any_whitespace,
    bool has_indent,
    int indent,
    bool has_separators,
    const std::string& separators_item,
    const std::string& separators_line,
    bool strict_mode,
    bool has_max_whitespace_cnt,
    int max_whitespace_cnt,
    bool print_converted_ebnf
) {
  std::optional<int> indent_opt =
      has_indent ? std::optional<int>(indent) : std::nullopt;
  std::optional<std::pair<std::string, std::string>> separators_opt = std::nullopt;
  if (has_separators) {
    separators_opt = std::make_pair(separators_item, separators_line);
  }
  std::optional<int> max_whitespace_opt =
      has_max_whitespace_cnt ? std::optional<int>(max_whitespace_cnt) : std::nullopt;

  return Grammar::FromJSONSchema(
      schema,
      any_whitespace,
      indent_opt,
      separators_opt,
      strict_mode,
      max_whitespace_opt,
      print_converted_ebnf
  );
}

CompiledGrammar GrammarCompilerCompileJSONSchema(
    GrammarCompiler* compiler,
    const std::string& schema,
    bool any_whitespace,
    bool has_indent,
    int indent,
    bool has_separators,
    const std::string& separators_item,
    const std::string& separators_line,
    bool strict_mode,
    bool has_max_whitespace_cnt,
    int max_whitespace_cnt
) {
  if (compiler == nullptr) {
    return CompiledGrammar(NullObj{});
  }

  std::optional<int> indent_opt =
      has_indent ? std::optional<int>(indent) : std::nullopt;
  std::optional<std::pair<std::string, std::string>> separators_opt = std::nullopt;
  if (has_separators) {
    separators_opt = std::make_pair(separators_item, separators_line);
  }
  std::optional<int> max_whitespace_opt =
      has_max_whitespace_cnt ? std::optional<int>(max_whitespace_cnt) : std::nullopt;

  return compiler->CompileJSONSchema(
      schema,
      any_whitespace,
      indent_opt,
      separators_opt,
      strict_mode,
      max_whitespace_opt
  );
}

TokenizerInfo CreateTokenizerInfo(
    const std::string* encoded_vocab,
    int encoded_vocab_count,
    VocabType vocab_type,
    int vocab_size,
    bool has_vocab_size,
    const int32_t* stop_token_ids,
    int stop_token_count,
    bool has_stop_token_ids,
    bool add_prefix_space
) {
  std::vector<std::string> encoded_vector;
  if (encoded_vocab != nullptr && encoded_vocab_count > 0) {
    encoded_vector.assign(encoded_vocab, encoded_vocab + encoded_vocab_count);
  }

  std::optional<int> vocab_size_opt =
      has_vocab_size ? std::optional<int>(vocab_size) : std::nullopt;

  std::optional<std::vector<int32_t>> stop_tokens_opt = std::nullopt;
  if (has_stop_token_ids) {
    if (stop_token_ids != nullptr && stop_token_count > 0) {
      stop_tokens_opt.emplace(stop_token_ids, stop_token_ids + stop_token_count);
    } else {
      stop_tokens_opt.emplace();
    }
  }

  return TokenizerInfo(encoded_vector, vocab_type, vocab_size_opt, stop_tokens_opt, add_prefix_space);
}

GrammarMatcher CreateGrammarMatcher(
    const CompiledGrammar& compiled_grammar,
    const int32_t* override_stop_tokens,
    int override_stop_token_count,
    bool has_override_stop_tokens,
    bool terminate_without_stop_token,
    int max_rollback_tokens
) {
  std::optional<std::vector<int32_t>> override_opt = std::nullopt;
  if (has_override_stop_tokens) {
    if (override_stop_tokens != nullptr && override_stop_token_count > 0) {
      override_opt.emplace(override_stop_tokens, override_stop_tokens + override_stop_token_count);
    } else {
      override_opt.emplace();
    }
  }

  return GrammarMatcher(
      compiled_grammar, override_opt, terminate_without_stop_token, max_rollback_tokens
  );
}

Grammar GrammarUnion(const Grammar* grammars, int grammar_count) {
  std::vector<Grammar> grammar_vector;
  if (grammars != nullptr && grammar_count > 0) {
    grammar_vector.assign(grammars, grammars + grammar_count);
  }
  return Grammar::Union(grammar_vector);
}

Grammar GrammarConcat(const Grammar* grammars, int grammar_count) {
  std::vector<Grammar> grammar_vector;
  if (grammars != nullptr && grammar_count > 0) {
    grammar_vector.assign(grammars, grammars + grammar_count);
  }
  return Grammar::Concat(grammar_vector);
}

int TokenizerInfoDecodedVocabCount(const TokenizerInfo& tokenizer_info) {
  return static_cast<int>(tokenizer_info.GetDecodedVocab().size());
}

std::string TokenizerInfoDecodedVocabAt(const TokenizerInfo& tokenizer_info, int index) {
  const auto& vocab = tokenizer_info.GetDecodedVocab();
  if (index < 0 || index >= static_cast<int>(vocab.size())) {
    return std::string();
  }
  return vocab[static_cast<size_t>(index)];
}

int TokenizerInfoStopTokenIdsCount(const TokenizerInfo& tokenizer_info) {
  return static_cast<int>(tokenizer_info.GetStopTokenIds().size());
}

int32_t TokenizerInfoStopTokenIdAt(const TokenizerInfo& tokenizer_info, int index) {
  const auto& values = tokenizer_info.GetStopTokenIds();
  if (index < 0 || index >= static_cast<int>(values.size())) {
    return 0;
  }
  return values[static_cast<size_t>(index)];
}

int TokenizerInfoSpecialTokenIdsCount(const TokenizerInfo& tokenizer_info) {
  return static_cast<int>(tokenizer_info.GetSpecialTokenIds().size());
}

int32_t TokenizerInfoSpecialTokenIdAt(const TokenizerInfo& tokenizer_info, int index) {
  const auto& values = tokenizer_info.GetSpecialTokenIds();
  if (index < 0 || index >= static_cast<int>(values.size())) {
    return 0;
  }
  return values[static_cast<size_t>(index)];
}

int GrammarMatcherStopTokenIdsCount(const GrammarMatcher& matcher) {
  return static_cast<int>(matcher.GetStopTokenIds().size());
}

int GrammarMatcherStopTokenIdAt(const GrammarMatcher& matcher, int index) {
  const auto& values = matcher.GetStopTokenIds();
  if (index < 0 || index >= static_cast<int>(values.size())) {
    return 0;
  }
  return values[static_cast<size_t>(index)];
}

TokenizerInfo TokenizerInfoFromVocabAndMetadata(
    const std::string* encoded_vocab,
    int encoded_vocab_count,
    const std::string& metadata
) {
  std::vector<std::string> encoded_vector;
  if (encoded_vocab != nullptr && encoded_vocab_count > 0) {
    encoded_vector.assign(encoded_vocab, encoded_vocab + encoded_vocab_count);
  }
  return TokenizerInfo::FromVocabAndMetadata(encoded_vector, metadata);
}

}  // namespace bridging
}  // namespace xgrammar
