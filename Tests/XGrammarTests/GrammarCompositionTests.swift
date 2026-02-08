import Testing

@testable import XGrammar

@Suite("Grammar Composition Tests")
struct GrammarCompositionTests {
    @Test func anyOfAcceptsEitherGrammar() async throws {
        let tokenizer = try TokenizerInfo(encodedVocab: ["a", "b"])
        let grammarA = Grammar(ebnf: #"root ::= "a""#)
        let grammarB = Grammar(ebnf: #"root ::= "b""#)
        let combined = try Grammar.anyOf([grammarA, grammarB])

        let matcher = try await combined.matcher(for: tokenizer, terminatesWithoutStopToken: true)
        let acceptedA = matcher.accept("a")
        #expect(acceptedA)
        matcher.reset()
        let acceptedB = matcher.accept("b")
        #expect(acceptedB)
    }

    @Test func sequenceRequiresOrder() async throws {
        let vocab = ["a", "b"]
        let tokenizer = try TokenizerInfo(encodedVocab: vocab)
        let grammarA = Grammar(ebnf: #"root ::= "a""#)
        let grammarB = Grammar(ebnf: #"root ::= "b""#)
        let combined = try Grammar.sequence([grammarA, grammarB])

        let matcher = try await combined.matcher(for: tokenizer, terminatesWithoutStopToken: true)
        let acceptedOpen = matcher.accept(Int32(0))
        #expect(acceptedOpen)
        let acceptedClose = matcher.accept(Int32(1))
        #expect(acceptedClose)
        #expect(matcher.isTerminated)
    }

    @Test func anyOfEmptyThrows() {
        do {
            _ = try Grammar.anyOf([])
            #expect(Bool(false))
        } catch let error as XGrammarError {
            switch error {
            case .runtimeError:
                #expect(Bool(true))
            default:
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }
    }

    @Test func sequenceEmptyThrows() {
        do {
            _ = try Grammar.sequence([])
            #expect(Bool(false))
        } catch let error as XGrammarError {
            switch error {
            case .runtimeError:
                #expect(Bool(true))
            default:
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }
    }
}
