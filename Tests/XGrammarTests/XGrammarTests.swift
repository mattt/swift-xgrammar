import Testing

@testable import XGrammar

@Test func grammarFromEBNF() async throws {
    let grammar = Grammar.fromEBNF("root ::= \"a\"")
    #expect(grammar.toString().contains("root"))
}

@Test func tokenizerInfoRoundTrip() async throws {
    let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c"])
    let serialized = tokenizer.serializeJSON()
    let restored = try TokenizerInfo.deserializeJSON(serialized)
    #expect(restored.vocabSize == tokenizer.vocabSize)
    #expect(restored.decodedVocab.count == 3)
}

@Test func compilerBasicCompile() async throws {
    let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c"])
    var compiler = GrammarCompiler(tokenizerInfo: tokenizer)
    let compiled = compiler.compileBuiltinJSONGrammar()
    #expect(compiled.memorySizeBytes() > 0)
}
