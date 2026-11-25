import Testing

#if canImport(CoreML)
    import CoreML
#endif

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

    #if canImport(CoreML)
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        @Test func masksCorrespondingTensorRows() async {
            var bitmask = Grammar.Matcher.TokenBitmask(batchSize: 2, vocabSize: 3)
            bitmask.storage = [0b001, 0b110]
            let logits = MLTensor(shape: [2, 4], scalars: (1 ... 8).map(Float.init))

            let masked = await bitmask.masking(logits).shapedArray(of: Float.self)
            #expect(masked.shape == [2, 4])
            #expect(Array(masked.scalars) == [1, -.infinity, -.infinity, 4, -.infinity, 6, 7, 8])
        }
    #endif
}
