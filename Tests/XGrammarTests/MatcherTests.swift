import Testing

@testable import XGrammar

@Suite("Matcher Tests")
struct MatcherTests {
    @Test func acceptTokenSequence() {
        let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c"])
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let compiled = compiler.compile(Grammar(ebnf: #"root ::= "a" "b""#))
        var matcher = Grammar.Matcher(compiled)

        let rejected = matcher.accept(2)
        #expect(rejected == false)
        let acceptedA = matcher.accept(0)
        #expect(acceptedA == true)
        let acceptedB = matcher.accept(1)
        #expect(acceptedB == true)
    }

    @Test func acceptString() {
        let tokenizer = makeSimpleTokenizer()
        let grammar = Grammar(ebnf: #"root ::= "a""#)
        var matcher = Grammar.Matcher(grammar.compiled(for: tokenizer), terminatesWithoutStopToken: true)
        let accepted = matcher.accept("a")
        #expect(accepted)
    }

    @Test func fillNextTokenBitmaskConstrainsTokens() {
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
        #expect(matcher.isTerminated)
    }

    @Test func builtinJSONTokenFlow() {
        let vocab = makeJSONVocab()
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

    @Test func terminationStateChanges() {
        let tokenizer = makeSimpleTokenizer()
        let grammar = Grammar(ebnf: #"root ::= "a" "b""#)
        var matcher = grammar.matcher(for: tokenizer, terminatesWithoutStopToken: true)
        #expect(!matcher.isTerminated)
        _ = matcher.accept(0)
        #expect(!matcher.isTerminated)
        _ = matcher.accept(1)
        #expect(matcher.isTerminated)
    }

    @Test func rollbackRestoresState() {
        let tokenizer = makeSimpleTokenizer()
        let grammar = Grammar(ebnf: #"root ::= "a" "b""#)
        var matcher = grammar.matcher(for: tokenizer, terminatesWithoutStopToken: true)
        let acceptedA = matcher.accept(0)
        #expect(acceptedA)
        let acceptedB = matcher.accept(1)
        #expect(acceptedB)
        matcher.rollback()
        #expect(!matcher.isTerminated)
        let acceptedAgain = matcher.accept(1)
        #expect(acceptedAgain)
    }

    @Test func resetRestoresInitialState() {
        let tokenizer = makeSimpleTokenizer()
        let grammar = Grammar(ebnf: #"root ::= "a""#)
        var matcher = grammar.matcher(for: tokenizer, terminatesWithoutStopToken: true)
        let acceptedA = matcher.accept(0)
        #expect(acceptedA)
        matcher.reset()
        let acceptedAfterReset = matcher.accept(0)
        #expect(acceptedAfterReset)
    }

    @Test func jumpForwardStringReturnsDeterministicText() {
        let tokenizer = makeSimpleTokenizer()
        let grammar = Grammar(ebnf: #"root ::= "a" "b""#)
        var matcher = grammar.matcher(for: tokenizer, terminatesWithoutStopToken: true)
        let jump = matcher.jumpForwardString()
        #expect(!jump.isEmpty)
    }

    @Test func stopTokensPropertyAccess() {
        let tokenizer = makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let compiled = compiler.compiledJSON
        let matcher = Grammar.Matcher(compiled)
        _ = matcher.stopTokenIDs
    }

    @Test func debugDescriptionIsAvailable() {
        let tokenizer = makeSimpleTokenizer()
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let compiled = compiler.compiledJSON
        let matcher = Grammar.Matcher(compiled)
        #expect(!matcher.debugDescription.isEmpty)
    }

    @Test func customStopTokensOverride() {
        let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c"])
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizer)
        let compiled = compiler.compile(Grammar(ebnf: #"root ::= "a""#))
        let matcher = Grammar.Matcher(compiled, stopTokens: [1], terminatesWithoutStopToken: true)
        #expect(matcher.stopTokenIDs == [1])
    }

    @Test func batchBitmaskIndexing() {
        let tokenizer = makeSimpleTokenizer()
        let grammar = Grammar(ebnf: #"root ::= "a""#)
        var matcher = grammar.matcher(for: tokenizer)
        var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: 3)
        _ = matcher.fillNextTokenBitmask(&bitmask, index: 0)
        #expect(bitmask.storage.count == bitmask.wordsPerBatch)
    }

    @Test func rejectsAfterTermination() {
        let tokenizer = makeSimpleTokenizer()
        let grammar = Grammar(ebnf: #"root ::= "a""#)
        var matcher = grammar.matcher(for: tokenizer, terminatesWithoutStopToken: true)
        let acceptedA = matcher.accept(0)
        #expect(acceptedA)
        #expect(matcher.isTerminated)
        let rejectedAfterTermination = matcher.accept(0)
        #expect(!rejectedAfterTermination)
    }
}
