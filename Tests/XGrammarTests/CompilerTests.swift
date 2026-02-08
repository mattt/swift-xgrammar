import Testing

@testable import XGrammar

@Suite("Compiler Tests")
struct CompilerTests {
    @Test func basicCompileReturnsCompiledGrammar() async throws {
        let tokenizer = try makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let grammar = Grammar(ebnf: #"root ::= "a""#)
        let compiled = await compiler.compile(grammar)
        #expect(compiled.memorySize > 0)
    }

    @Test func compiledJSONIsStable() async throws {
        let tokenizer = try makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let first = await compiler.compiledJSON
        let second = await compiler.compiledJSON
        #expect(first.jsonData == second.jsonData)
        #expect(first.grammar.description.contains("root"))
    }

    @Test func compileJSONSchemaUsesFormatting() async throws {
        let tokenizer = try TokenizerInfo(encodedVocab: makeJSONVocab())
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let schema = #"{"type":"string"}"#
        let compiled = await compiler.compile(
            jsonSchema: schema,
            formatting: .compact,
            strictMode: true
        )
        #expect(compiled.memorySize > 0)
    }

    @Test func cacheSizeUpdatesAndClears() async throws {
        let tokenizer = try makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let before = await compiler.cache.size
        _ = await compiler.compile(Grammar(ebnf: #"root ::= "a""#))
        let after = await compiler.cache.size
        #expect(after >= before)
        await compiler.cache.clear()
        let cleared = await compiler.cache.size
        #expect(cleared <= after)
    }

    @Test func cacheSizeLimitReflectsConstructor() async throws {
        let tokenizer = try makeSimpleTokenizer()
        let compiler = Grammar.Compiler(
            tokenizerInfo: tokenizer,
            maximumThreadCount: 2,
            cachingEnabled: true,
            cacheSizeLimit: 1024
        )
        let limit = await compiler.cache.sizeLimit
        #expect(limit == 1024)
    }

    @Test func compilerRespectsCachingDisabled() async throws {
        let tokenizer = try makeSimpleTokenizer()
        let compiler = Grammar.Compiler(
            tokenizerInfo: tokenizer,
            maximumThreadCount: 1,
            cachingEnabled: false,
            cacheSizeLimit: nil
        )
        let compiled = await compiler.compile(Grammar(ebnf: #"root ::= "a""#))
        #expect(compiled.memorySize > 0)
    }

    @Test func compiledAccessorsReturnExpectedValues() async throws {
        let tokenizer = try makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let compiled = await compiler.compile(Grammar(ebnf: #"root ::= "a""#))
        #expect(compiled.grammar.description.contains("root"))
        #expect(compiled.tokenizerInfo.vocabulary.size == tokenizer.vocabulary.size)
    }

    @Test func compiledSerializationRoundTrip() async throws {
        let tokenizer = try makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let compiled = await compiler.compile(Grammar(ebnf: #"root ::= "a""#))
        let serialized = compiled.jsonData
        let restored = try Grammar.Compiled(jsonData: serialized, tokenizerInfo: tokenizer)
        #expect(restored.memorySize > 0)
    }
}
