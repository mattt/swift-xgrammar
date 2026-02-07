import Foundation
import Testing

@testable import XGrammar

private func allowedTokenIndices(
    _ bitmask: Grammar.Matcher.TokenBitmask,
    vocabSize: Int,
    batchIndex: Int = 0
) -> [Int] {
    var result: [Int] = []
    let wordsPerBatch = bitmask.wordsPerBatch
    let baseOffset = batchIndex * wordsPerBatch
    for tokenId in 0..<vocabSize {
        let wordIndex = tokenId / 32
        let bitIndex = tokenId % 32
        let storageIndex = baseOffset + wordIndex
        guard storageIndex < bitmask.storage.count else {
            continue
        }
        let word = UInt32(bitPattern: bitmask.storage[storageIndex])
        if (word & (UInt32(1) << UInt32(bitIndex))) != 0 {
            result.append(tokenId)
        }
    }
    return result
}

@Test func grammarFromEBNF() async throws {
    let grammar = Grammar(ebnf: "root ::= \"a\"")
    #expect(grammar.description.contains("root"))
}

@Test func tokenizerInfoRoundTrip() async throws {
    let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c"])
    let serialized = tokenizer.jsonData
    let restored = try TokenizerInfo(jsonData: serialized)
    #expect(restored.vocabulary.size == tokenizer.vocabulary.size)
    #expect(restored.vocabulary.decoded.count == 3)
}

@Test func compilerBasicCompile() async throws {
    let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c"])
    let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
    let compiled = compiler.compiledJSON
    #expect(compiled.memorySize > 0)
    #expect(compiled.grammar.description.contains("root"))
}

@Test func grammarSerializeRoundTrip() async throws {
    let grammar = Grammar(ebnf: #"root ::= "a""#)
    let serialized = grammar.jsonData
    let restored = try Grammar(jsonData: serialized)
    #expect(restored.description.contains("root"))
}

@Test func compiledGrammarSerializeRoundTrip() async throws {
    let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c"])
    let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
    let compiled = compiler.compiledJSON
    let serialized = compiled.jsonData
    let restored = try Grammar.Compiled(jsonData: serialized, tokenizerInfo: tokenizer)
    #expect(restored.memorySize > 0)
    #expect(restored.grammar.description.contains("root"))
}

@Test func compileJSONSchemaFullParameters() async throws {
    let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c", "\"", "{", "}", ":", ","])
    let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
    let schema = #"{"type":"string"}"#
    let compiled = compiler.compile(
        jsonSchema: schema,
        formatting: JSONSchemaFormatting(
            allowsFlexibleWhitespace: true,
            indentation: 2,
            separators: (",", ": "),
            maximumWhitespaceCount: 4
        ),
        strictMode: true
    )
    #expect(compiled.memorySize > 0)
}

@Test func tokenBitmaskResetAndApply() async throws {
    var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: 8)
    #expect(bitmask.storage.allSatisfy { $0 == -1 })
    bitmask.storage[0] = 0
    var logits = Array(repeating: Float(0.5), count: 8)
    bitmask.maskLogits(&logits)
    #expect(logits.allSatisfy { $0 == -Float.infinity })
}

@Test func tokenBitmaskShapeMatches() async throws {
    let bitmask = Grammar.Matcher.TokenBitmask(batchSize: 2, vocabSize: 64)
    #expect(bitmask.batchSize == 2)
    #expect(bitmask.wordsPerBatch == 2)
}

@Test func tokenBitmaskApplyRespectsVocabSize() async throws {
    var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: 64)
    bitmask.storage[0] = 0
    var logits = Array(repeating: Float(1.0), count: 64)
    bitmask.maskLogits(&logits, vocabSize: 32)
    #expect(logits[0..<32].allSatisfy { $0 == -Float.infinity })
    #expect(logits[32..<64].allSatisfy { $0 == 1.0 })
}

@Test func matcherFillsBitmask() async throws {
    let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c"])
    let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
    let compiled = compiler.compiledJSON
    var matcher = Grammar.Matcher(compiled)
    var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: tokenizer.vocabulary.size)
    _ = matcher.fillNextTokenBitmask(&bitmask)
    #expect(bitmask.storage.count == bitmask.wordsPerBatch)
}

@Test func matcherRejectsInvalidSequence() async throws {
    let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c"])
    let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
    let compiled = compiler.compile(Grammar(ebnf: #"root ::= "a" "b""#))
    var matcher = Grammar.Matcher(compiled)

    #expect(matcher.accept(2) == false)
    #expect(matcher.accept(0) == true)
    #expect(matcher.accept(1) == true)
}

@Test func matcherTokenBitmaskConstrainsNextTokens() async throws {
    let vocab = ["{", "}", "a", "b"]
    let tokenizer = TokenizerInfo(encodedVocab: vocab)
    let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
    let compiled = compiler.compile(Grammar(ebnf: #"root ::= "{" "a" "}""#))
    var matcher = Grammar.Matcher(compiled, terminatesWithoutStopToken: true)
    var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: vocab.count)

    _ = matcher.fillNextTokenBitmask(&bitmask)
    var allowed = allowedTokenIndices(bitmask, vocabSize: vocab.count)
    #expect(allowed == [0])

    let acceptedOpen = matcher.accept(0)
    #expect(acceptedOpen)
    _ = matcher.fillNextTokenBitmask(&bitmask)
    allowed = allowedTokenIndices(bitmask, vocabSize: vocab.count)
    #expect(allowed == [2])

    let acceptedA = matcher.accept(2)
    #expect(acceptedA)
    _ = matcher.fillNextTokenBitmask(&bitmask)
    allowed = allowedTokenIndices(bitmask, vocabSize: vocab.count)
    #expect(allowed == [1])

    let acceptedClose = matcher.accept(1)
    #expect(acceptedClose)
    #expect(matcher.isTerminated == true)
}

@Test func matcherBuiltinJSONTokenFlow() async throws {
    let vocab = ["{", "}", "\"", ":", ",", "a", "b", " "]
    let tokenizer = TokenizerInfo(encodedVocab: vocab)
    let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
    let compiled = compiler.compiledJSON
    var matcher = Grammar.Matcher(compiled, terminatesWithoutStopToken: true)
    var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: vocab.count)

    let tokenIds = ["{", "\"", "a", "\"", ":", "\"", "b", "\"", "}"]
        .compactMap { vocab.firstIndex(of: $0) }

    for (index, tokenId) in tokenIds.enumerated() {
        _ = matcher.fillNextTokenBitmask(&bitmask)
        let allowed = allowedTokenIndices(bitmask, vocabSize: vocab.count)
        #expect(allowed.contains(tokenId))
        if index == 0 {
            #expect(allowed.contains(vocab.firstIndex(of: "{")!))
            #expect(!allowed.contains(vocab.firstIndex(of: "}")!))
        }
        let accepted = matcher.accept(Int32(tokenId))
        #expect(accepted)
    }
}

@Test func matcherStopTokensProperty() async throws {
    let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c"])
    let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
    let compiled = compiler.compiledJSON
    let matcher = Grammar.Matcher(compiled)
    _ = matcher.stopTokenIDs
}

@Test func vocabEncodingDescription() async throws {
    #expect(TokenizerInfo.Vocabulary.Encoding.raw.description == "raw")
    #expect(TokenizerInfo.Vocabulary.Encoding.byteFallback.description == "byteFallback")
    #expect(TokenizerInfo.Vocabulary.Encoding.byteLevel.description == "byteLevel")
}

@Test func deserializeErrorTyping() async throws {
    do {
        _ = try TokenizerInfo(jsonData: Data("not json".utf8))
        #expect(Bool(false))
    } catch let error as XGrammarError {
        switch error {
        case .invalidJSON:
            #expect(Bool(true))
        default:
            #expect(Bool(false))
        }
    }
}
