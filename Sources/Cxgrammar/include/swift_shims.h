/*!
 * \file xgrammar/swift_shims.h
 * \brief Swift-friendly wrappers for C++ APIs.
 */
#ifndef XGRAMMAR_SWIFT_SHIMS_H_
#define XGRAMMAR_SWIFT_SHIMS_H_

#include "compiler.h"
#include "grammar.h"
#include "matcher.h"
#include "tokenizer_info.h"

#include <cstdint>
#include <string>
#include <vector>

namespace xgrammar {
namespace swift_api {

// Fill the next-token bitmask into a raw int32 buffer.
bool FillNextTokenBitmask(
    GrammarMatcher* matcher,
    int32_t* bitmask_data,
    int32_t bitmask_count,
    int index = 0,
    bool debug_print = false
);

// Deserialize helpers with string error messages instead of std::variant.
bool GrammarDeserializeJSON(
    const std::string& json_string,
    Grammar* out_grammar,
    std::string* out_error
);

bool TokenizerInfoDeserializeJSON(
    const std::string& json_string,
    TokenizerInfo* out_tokenizer,
    std::string* out_error
);

bool CompiledGrammarDeserializeJSON(
    const std::string& json_string,
    const TokenizerInfo& tokenizer_info,
    CompiledGrammar* out_compiled_grammar,
    std::string* out_error
);

bool GrammarFromStructuralTag(
    const std::string& structural_tag_json,
    Grammar* out_grammar,
    std::string* out_error
);

Grammar GrammarFromJSONSchemaBasic(
    const std::string& schema,
    bool any_whitespace,
    bool strict_mode,
    bool print_converted_ebnf
);

CompiledGrammar GrammarCompilerCompileJSONSchemaBasic(
    GrammarCompiler* compiler,
    const std::string& schema,
    bool any_whitespace,
    bool strict_mode
);

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
);

GrammarMatcher CreateGrammarMatcherFromArray(
    const CompiledGrammar& compiled_grammar,
    const int32_t* override_stop_tokens,
    int override_stop_token_count,
    bool has_override_stop_tokens,
    bool terminate_without_stop_token,
    int max_rollback_tokens
);

Grammar GrammarUnionFromArray(const Grammar* grammars, int grammar_count);

Grammar GrammarConcatFromArray(const Grammar* grammars, int grammar_count);

int TokenizerInfoDecodedVocabCount(const TokenizerInfo& tokenizer_info);

std::string TokenizerInfoDecodedVocabAt(const TokenizerInfo& tokenizer_info, int index);

int TokenizerInfoStopTokenIdsCount(const TokenizerInfo& tokenizer_info);

int32_t TokenizerInfoStopTokenIdAt(const TokenizerInfo& tokenizer_info, int index);

int TokenizerInfoSpecialTokenIdsCount(const TokenizerInfo& tokenizer_info);

int32_t TokenizerInfoSpecialTokenIdAt(const TokenizerInfo& tokenizer_info, int index);

int GrammarMatcherStopTokenIdsCount(const GrammarMatcher& matcher);

int GrammarMatcherStopTokenIdAt(const GrammarMatcher& matcher, int index);

TokenizerInfo TokenizerInfoFromVocabAndMetadata(
    const std::string* encoded_vocab,
    int encoded_vocab_count,
    const std::string& metadata
);

}  // namespace swift_api
}  // namespace xgrammar

#endif  // XGRAMMAR_SWIFT_SHIMS_H_
