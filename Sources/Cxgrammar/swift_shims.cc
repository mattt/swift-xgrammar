/*!
 * \file swift_shims.cc
 * \brief Swift-friendly wrappers for C++ APIs.
 */
#include "swift_shims.h"

#include "dlpack.h"
#include "object.h"

#include <optional>
#include <variant>

namespace xgrammar {
namespace swift_api {

namespace {

template <typename VariantType>
std::string VariantErrorToString(const VariantType& error) {
  return std::visit([](const auto& err) { return std::string(err.what()); }, error);
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
    std::string* out_error
) {
  auto result = Grammar::DeserializeJSON(json_string);
  if (std::holds_alternative<Grammar>(result)) {
    if (out_grammar != nullptr) {
      *out_grammar = std::get<Grammar>(result);
    }
    return true;
  }

  if (out_error != nullptr) {
    *out_error = VariantErrorToString(std::get<SerializationError>(result));
  }
  return false;
}

bool TokenizerInfoDeserializeJSON(
    const std::string& json_string,
    TokenizerInfo* out_tokenizer,
    std::string* out_error
) {
  auto result = TokenizerInfo::DeserializeJSON(json_string);
  if (std::holds_alternative<TokenizerInfo>(result)) {
    if (out_tokenizer != nullptr) {
      *out_tokenizer = std::get<TokenizerInfo>(result);
    }
    return true;
  }

  if (out_error != nullptr) {
    *out_error = VariantErrorToString(std::get<SerializationError>(result));
  }
  return false;
}

bool CompiledGrammarDeserializeJSON(
    const std::string& json_string,
    const TokenizerInfo& tokenizer_info,
    CompiledGrammar* out_compiled_grammar,
    std::string* out_error
) {
  auto result = CompiledGrammar::DeserializeJSON(json_string, tokenizer_info);
  if (std::holds_alternative<CompiledGrammar>(result)) {
    if (out_compiled_grammar != nullptr) {
      *out_compiled_grammar = std::get<CompiledGrammar>(result);
    }
    return true;
  }

  if (out_error != nullptr) {
    *out_error = VariantErrorToString(std::get<SerializationError>(result));
  }
  return false;
}

bool GrammarFromStructuralTag(
    const std::string& structural_tag_json,
    Grammar* out_grammar,
    std::string* out_error
) {
  auto result = Grammar::FromStructuralTag(structural_tag_json);
  if (std::holds_alternative<Grammar>(result)) {
    if (out_grammar != nullptr) {
      *out_grammar = std::get<Grammar>(result);
    }
    return true;
  }

  if (out_error != nullptr) {
    *out_error = VariantErrorToString(std::get<StructuralTagError>(result));
  }
  return false;
}

Grammar GrammarFromJSONSchemaBasic(
    const std::string& schema,
    bool any_whitespace,
    bool strict_mode,
    bool print_converted_ebnf
) {
  return Grammar::FromJSONSchema(
      schema,
      any_whitespace,
      std::nullopt,
      std::nullopt,
      strict_mode,
      std::nullopt,
      print_converted_ebnf
  );
}

CompiledGrammar GrammarCompilerCompileJSONSchemaBasic(
    GrammarCompiler* compiler,
    const std::string& schema,
    bool any_whitespace,
    bool strict_mode
) {
  if (compiler == nullptr) {
    return CompiledGrammar(NullObj{});
  }
  return compiler->CompileJSONSchema(
      schema, any_whitespace, std::nullopt, std::nullopt, strict_mode, std::nullopt
  );
}

TokenizerInfo CreateTokenizerInfoFromArray(
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

GrammarMatcher CreateGrammarMatcherFromArray(
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

Grammar GrammarUnionFromArray(const Grammar* grammars, int grammar_count) {
  std::vector<Grammar> grammar_vector;
  if (grammars != nullptr && grammar_count > 0) {
    grammar_vector.assign(grammars, grammars + grammar_count);
  }
  return Grammar::Union(grammar_vector);
}

Grammar GrammarConcatFromArray(const Grammar* grammars, int grammar_count) {
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

}  // namespace swift_api
}  // namespace xgrammar
