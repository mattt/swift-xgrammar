import Testing

@testable import XGrammar

@Suite("JSON Schema Tests")
struct JSONSchemaTests {
    private let vocab = makeJSONVocab() + ["0", "1", "2", "-", "t", "f", "n"]

    private func compileSchema(
        _ schema: String,
        formatting: JSONSchemaFormatting = .default,
        strict: Bool = true
    ) async -> Grammar.Compiled {
        let tokenizer = TokenizerInfo(encodedVocab: vocab)
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        return await compiler.compile(jsonSchema: schema, formatting: formatting, strictMode: strict)
    }

    @Test func schemaTypesCompile() async {
        let schemas = [
            #"{"type":"string"}"#,
            #"{"type":"number"}"#,
            #"{"type":"integer"}"#,
            #"{"type":"boolean"}"#,
            #"{"type":"null"}"#,
        ]
        for schema in schemas {
            let compiled = await compileSchema(schema)
            #expect(compiled.memorySize > 0)
        }
    }

    @Test func objectSchemaCompiles() async {
        let schema = #"""
            {"type":"object","properties":{"a":{"type":"string"},"b":{"type":"integer"}},"required":["a"]}
            """#
        let compiled = await compileSchema(schema)
        #expect(compiled.memorySize > 0)
    }

    @Test func nestedObjectSchemaCompiles() async {
        let schema = #"""
            {"type":"object","properties":{"obj":{"type":"object","properties":{"x":{"type":"string"}},"required":["x"]}}}
            """#
        let compiled = await compileSchema(schema)
        #expect(compiled.memorySize > 0)
    }

    @Test func arraySchemaCompiles() async {
        let schema = #"{"type":"array","items":{"type":"string"}}"#
        let compiled = await compileSchema(schema)
        #expect(compiled.memorySize > 0)
    }

    @Test func enumSchemaCompiles() async {
        let schema = #"{"enum":["a","b"]}"#
        let compiled = await compileSchema(schema)
        #expect(compiled.memorySize > 0)
    }

    @Test func formattingVariantsProduceDifferentGrammars() {
        let schema = #"{"type":"string"}"#
        let defaultGrammar = Grammar(jsonSchema: schema, formatting: .default)
        let compactGrammar = Grammar(jsonSchema: schema, formatting: .compact)
        #expect(defaultGrammar.description != compactGrammar.description)
    }

    @Test func customFormattingCompiles() async {
        let schema = #"{"type":"string"}"#
        let formatting = JSONSchemaFormatting(
            allowsFlexibleWhitespace: true,
            indentation: 2,
            separators: (",", ": "),
            maximumWhitespaceCount: 4
        )
        let compiled = await compileSchema(schema, formatting: formatting, strict: true)
        #expect(compiled.memorySize > 0)
    }

    @Test func strictModeAffectsGrammar() {
        let schema = #"""
            {"type":"object","properties":{"a":{"type":"string"}},"required":["a"]}
            """#
        let strictGrammar = Grammar(jsonSchema: schema, strictMode: true)
        let looseGrammar = Grammar(jsonSchema: schema, strictMode: false)
        #expect(strictGrammar.description != looseGrammar.description)
    }

    @Test func directInitAndCompilerPath() async {
        let schema = #"{"type":"string"}"#
        let grammar = Grammar(jsonSchema: schema)
        #expect(!grammar.description.isEmpty)
        let compiled = await compileSchema(schema)
        #expect(compiled.memorySize > 0)
    }
}
