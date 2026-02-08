import Testing

@testable import XGrammar

@Suite("TokenBitmask Tests")
struct TokenBitmaskTests {
    @Test func initializesAllBitsSet() {
        let bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: 8)
        #expect(bitmask.storage.allSatisfy { $0 == -1 })
    }

    @Test func resetRestoresAllBits() {
        var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: 8)
        bitmask.storage[0] = 0
        bitmask.reset()
        #expect(bitmask.storage.allSatisfy { $0 == -1 })
    }

    @Test func maskLogitsZeroesDisallowedTokens() {
        var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: 8)
        bitmask.storage[0] = 0
        var logits = Array(repeating: Float(0.5), count: 8)
        bitmask.maskLogits(&logits)
        #expect(logits.allSatisfy { $0 == -Float.infinity })
    }

    @Test func maskLogitsRespectsVocabSize() {
        var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: 64)
        bitmask.storage[0] = 0
        var logits = Array(repeating: Float(1.0), count: 64)
        bitmask.maskLogits(&logits, vocabSize: 32)
        #expect(logits[0 ..< 32].allSatisfy { $0 == -Float.infinity })
        #expect(logits[32 ..< 64].allSatisfy { $0 == 1.0 })
    }

    @Test func isTokenAllowedUsesBitmask() {
        var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 1, vocabSize: 8)
        bitmask.storage[0] = 0
        #expect(!bitmask.isTokenAllowed(0))
        #expect(!bitmask.isTokenAllowed(7))
    }

    @Test func wordsPerBatchCalculations() {
        #expect(Grammar.Matcher.TokenBitmask.wordsPerBatch(vocabSize: 1) == 1)
        #expect(Grammar.Matcher.TokenBitmask.wordsPerBatch(vocabSize: 32) == 1)
        #expect(Grammar.Matcher.TokenBitmask.wordsPerBatch(vocabSize: 33) == 2)
    }

    @Test func batchIndexingUsesOffset() {
        var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 2, vocabSize: 8)
        #expect(bitmask.storage.count == 2)
        bitmask.storage[1] = 0
        #expect(bitmask.isTokenAllowed(0, batchIndex: 0))
        #expect(!bitmask.isTokenAllowed(0, batchIndex: 1))
    }
}
