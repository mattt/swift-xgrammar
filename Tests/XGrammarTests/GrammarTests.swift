import Foundation
import Testing

@testable import XGrammar

@Suite("Grammar Tests")
struct GrammarTests {
    @Test func createsFromEBNF() throws {
        let grammar = Grammar(ebnf: #"root ::= "a""#)
        #expect(grammar.description.contains("root"))
    }

    @Test func createsFromEBNFWithRules() throws {
        let grammar = Grammar(ebnf: "root ::= letter+\nletter ::= [a-z]")
        #expect(grammar.description.contains("letter"))
        #expect(grammar.description.contains("root"))
    }

    @Test func usesCustomRootRule() async throws {
        let grammar = Grammar(ebnf: #"start ::= "a""#, rootRule: "start")
        #expect(grammar.description.contains("root"))
        let matcher = await grammar.matcher(for: makeSimpleTokenizer(), terminatesWithoutStopToken: true)
        let accepted = matcher.accept("a")
        #expect(accepted)
    }

    @Test func builtinJSONGrammarIsAvailable() throws {
        let grammar = Grammar.json
        #expect(grammar.description.contains("root"))
    }

    @Test func supportsUnicodeInEBNF() throws {
        let grammar = Grammar(ebnf: #"root ::= "漢""#)
        #expect(grammar.description.contains("root"))
    }

    @Test func serializeRoundTrip() throws {
        let grammar = Grammar(ebnf: #"root ::= "a""#)
        let serialized = grammar.jsonData
        let restored = try Grammar(jsonData: serialized)
        #expect(restored.description.contains("root"))
    }

    @Test func compiledConvenienceBuilds() async throws {
        let grammar = Grammar(ebnf: #"root ::= "a""#)
        let compiled = await grammar.compiled(for: makeSimpleTokenizer())
        #expect(compiled.memorySize > 0)
    }

    @Test func matcherConvenienceBuilds() async throws {
        let grammar = Grammar(ebnf: #"root ::= "a""#)
        let matcher = await grammar.matcher(for: makeSimpleTokenizer())
        let accepted = matcher.accept("a")
        #expect(accepted)
    }
}
