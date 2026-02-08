import Foundation
import Testing

@testable import XGrammar

func allowedTokenIndices(
    _ bitmask: Grammar.Matcher.TokenBitmask,
    vocabSize: Int,
    batchIndex: Int = 0
) -> [Int] {
    var result: [Int] = []
    let wordsPerBatch = bitmask.wordsPerBatch
    let baseOffset = batchIndex * wordsPerBatch
    for tokenId in 0 ..< vocabSize {
        let wordIndex = tokenId / 32
        let bitIndex = tokenId % 32
        let storageIndex = baseOffset + wordIndex
        guard storageIndex < bitmask.storage.count else {
            continue
        }
        let word = UInt32(bitPattern: bitmask.storage[storageIndex])
        if (word & (UInt32(1) << UInt32(bitIndex))) != 0 {
            result.append(tokenId)
        }
    }
    return result
}

func makeJSONVocab() -> [String] {
    ["{", "}", "\"", ":", ",", "a", "b", " "]
}

func makeSimpleTokenizer() -> TokenizerInfo {
    TokenizerInfo(encodedVocab: ["a", "b", "c"])
}
