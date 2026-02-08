import Testing

@testable import XGrammar

@Suite("Grammar Composition Tests")
struct GrammarCompositionTests {
    @Test func anyOfAcceptsEitherGrammar() {
        let tokenizer = TokenizerInfo(encodedVocab: ["a", "b"])
        let grammarA = Grammar(ebnf: #"root ::= "a""#)
        let grammarB = Grammar(ebnf: #"root ::= "b""#)
        let combined = Grammar.anyOf([grammarA, grammarB])

        var matcher = combined.matcher(for: tokenizer, terminatesWithoutStopToken: true)
        let acceptedA = matcher.accept("a")
        #expect(acceptedA)
        matcher.reset()
        let acceptedB = matcher.accept("b")
        #expect(acceptedB)
    }

    @Test func sequenceRequiresOrder() {
        let vocab = ["a", "b"]
        let tokenizer = TokenizerInfo(encodedVocab: vocab)
        let grammarA = Grammar(ebnf: #"root ::= "a""#)
        let grammarB = Grammar(ebnf: #"root ::= "b""#)
        let combined = Grammar.sequence([grammarA, grammarB])

        var matcher = combined.matcher(for: tokenizer, terminatesWithoutStopToken: true)
        let acceptedOpen = matcher.accept(Int32(0))
        #expect(acceptedOpen)
        let acceptedClose = matcher.accept(Int32(1))
        #expect(acceptedClose)
        #expect(matcher.isTerminated)
    }
}
