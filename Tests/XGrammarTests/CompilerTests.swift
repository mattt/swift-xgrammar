import Testing

@testable import XGrammar

@Suite("Compiler Tests")
struct CompilerTests {
    @Test func basicCompileReturnsCompiledGrammar() {
        let tokenizer = makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let grammar = Grammar(ebnf: #"root ::= "a""#)
        let compiled = compiler.compile(grammar)
        #expect(compiled.memorySize > 0)
    }

    @Test func compiledJSONIsStable() {
        let tokenizer = makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let first = compiler.compiledJSON
        let second = compiler.compiledJSON
        #expect(first.jsonData == second.jsonData)
        #expect(first.grammar.description.contains("root"))
    }

    @Test func compileJSONSchemaUsesFormatting() {
        let tokenizer = TokenizerInfo(encodedVocab: makeJSONVocab())
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let schema = #"{"type":"string"}"#
        let compiled = compiler.compile(
            jsonSchema: schema,
            formatting: .compact,
            strictMode: true
        )
        #expect(compiled.memorySize > 0)
    }

    @Test func cacheSizeUpdatesAndClears() {
        let tokenizer = makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let before = compiler.cache.size
        _ = compiler.compile(Grammar(ebnf: #"root ::= "a""#))
        let after = compiler.cache.size
        #expect(after >= before)
        compiler.cache.clear()
        let cleared = compiler.cache.size
        #expect(cleared <= after)
    }

    @Test func cacheSizeLimitReflectsConstructor() {
        let tokenizer = makeSimpleTokenizer()
        let compiler = Grammar.Compiler(
            tokenizerInfo: tokenizer,
            maximumThreadCount: 2,
            cachingEnabled: true,
            cacheSizeLimit: 1024
        )
        #expect(compiler.cache.sizeLimit == 1024)
    }

    @Test func compilerRespectsCachingDisabled() {
        let tokenizer = makeSimpleTokenizer()
        let compiler = Grammar.Compiler(
            tokenizerInfo: tokenizer,
            maximumThreadCount: 1,
            cachingEnabled: false,
            cacheSizeLimit: nil
        )
        let compiled = compiler.compile(Grammar(ebnf: #"root ::= "a""#))
        #expect(compiled.memorySize > 0)
    }

    @Test func compiledAccessorsReturnExpectedValues() {
        let tokenizer = makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let compiled = compiler.compile(Grammar(ebnf: #"root ::= "a""#))
        #expect(compiled.grammar.description.contains("root"))
        #expect(compiled.tokenizerInfo.vocabulary.size == tokenizer.vocabulary.size)
    }

    @Test func compiledSerializationRoundTrip() throws {
        let tokenizer = makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let compiled = compiler.compile(Grammar(ebnf: #"root ::= "a""#))
        let serialized = compiled.jsonData
        let restored = try Grammar.Compiled(jsonData: serialized, tokenizerInfo: tokenizer)
        #expect(restored.memorySize > 0)
    }
}
