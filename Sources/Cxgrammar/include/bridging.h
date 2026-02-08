/*!
 * \file bridging.h
 * \brief C++ bridging functions for the Swift API layer.
 */
#ifndef XGRAMMAR_BRIDGING_H_
#define XGRAMMAR_BRIDGING_H_

#include <xgrammar/compiler.h>
#include <xgrammar/grammar.h>
#include <xgrammar/matcher.h>
#include <xgrammar/tokenizer_info.h>

#include <cstdint>
#include <string>

namespace xgrammar {
namespace bridging {

enum class ErrorKind : int32_t {
  kNone = 0,
  kDeserializeVersion = 1,
  kDeserializeFormat = 2,
  kInvalidJSON = 3,
  kInvalidStructuralTag = 4,
  kInvalidJSONSchema = 5,
  kUnknown = 6
};

// Fill the next-token bitmask into a raw int32 buffer.
bool FillNextTokenBitmask(
    GrammarMatcher* matcher,
    int32_t* bitmask_data,
    int32_t bitmask_count,
    int index = 0,
    bool debug_print = false
);

bool GrammarDeserializeJSON(
    const std::string& json_string,
    Grammar* out_grammar,
    std::string* out_error,
    ErrorKind* out_error_kind
);

bool TokenizerInfoDeserializeJSON(
    const std::string& json_string,
    TokenizerInfo* out_tokenizer,
    std::string* out_error,
    ErrorKind* out_error_kind
);

bool CompiledGrammarDeserializeJSON(
    const std::string& json_string,
    const TokenizerInfo& tokenizer_info,
    CompiledGrammar* out_compiled_grammar,
    std::string* out_error,
    ErrorKind* out_error_kind
);

bool GrammarFromStructuralTag(
    const std::string& structural_tag_json,
    Grammar* out_grammar,
    std::string* out_error,
    ErrorKind* out_error_kind
);

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
);

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
);

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
);

GrammarMatcher CreateGrammarMatcher(
    const CompiledGrammar& compiled_grammar,
    const int32_t* override_stop_tokens,
    int override_stop_token_count,
    bool has_override_stop_tokens,
    bool terminate_without_stop_token,
    int max_rollback_tokens
);

Grammar GrammarUnion(const Grammar* grammars, int grammar_count);

Grammar GrammarConcat(const Grammar* grammars, int grammar_count);

int TokenizerInfoDecodedVocabCount(const TokenizerInfo& tokenizer_info);

std::string TokenizerInfoDecodedVocabAt(const TokenizerInfo& tokenizer_info, int index);

int TokenizerInfoStopTokenIdsCount(const TokenizerInfo& tokenizer_info);

int32_t TokenizerInfoStopTokenIdAt(const TokenizerInfo& tokenizer_info, int index);

int TokenizerInfoSpecialTokenIdsCount(const TokenizerInfo& tokenizer_info);

int32_t TokenizerInfoSpecialTokenIdAt(const TokenizerInfo& tokenizer_info, int index);

int GrammarMatcherStopTokenIdsCount(const GrammarMatcher& matcher);

int32_t GrammarMatcherStopTokenIdAt(const GrammarMatcher& matcher, int index);

TokenizerInfo TokenizerInfoFromVocabAndMetadata(
    const std::string* encoded_vocab,
    int encoded_vocab_count,
    const std::string& metadata
);

}  // namespace bridging
}  // namespace xgrammar

#endif  // XGRAMMAR_BRIDGING_H_
