import Testing

@testable import XGrammar

@Suite("TokenizerInfo Tests")
struct TokenizerInfoTests {
    @Test func basicCreationAndDecodedVocab() throws {
        let tokenizer = try TokenizerInfo(encodedVocab: ["a", "b", "c"])
        #expect(tokenizer.vocabulary.size == 3)
        #expect(tokenizer.vocabulary.decoded == ["a", "b", "c"])

        let sequence = Array(tokenizer.vocabulary.decodedSequence)
        #expect(sequence == ["a", "b", "c"])
    }

    @Test func encodingVariants() throws {
        let raw = try TokenizerInfo(encodedVocab: ["a"], encoding: .raw)
        let fallback = try TokenizerInfo(encodedVocab: ["<0x41>"], encoding: .byteFallback)
        let byteLevel = try TokenizerInfo(encodedVocab: ["a"], encoding: .byteLevel)

        #expect(raw.vocabulary.encoding == .raw)
        #expect(fallback.vocabulary.encoding == .byteFallback)
        #expect(byteLevel.vocabulary.encoding == .byteLevel)
    }

    @Test func paddedVocabularySizeAddsSpecialTokens() throws {
        let tokenizer = try TokenizerInfo(encodedVocab: ["a"], vocabularySize: 3)
        #expect(tokenizer.vocabulary.size == 3)
        #expect(tokenizer.specialTokenIDs.contains(1))
        #expect(tokenizer.specialTokenIDs.contains(2))
    }

    @Test func explicitStopTokenIDs() throws {
        let tokenizer = try TokenizerInfo(encodedVocab: ["a", "b", "c"], stopTokenIDs: [2])
        #expect(tokenizer.stopTokenIDs == [2])
    }

    @Test func addPrefixSpaceFlag() throws {
        let tokenizer = try TokenizerInfo(encodedVocab: ["a"], addPrefixSpace: true)
        #expect(tokenizer.addPrefixSpace)
    }

    @Test func specialTokenIDsDetectEmptyToken() throws {
        let tokenizer = try TokenizerInfo(encodedVocab: ["", "a"])
        #expect(tokenizer.specialTokenIDs.contains(0))
    }

    @Test func metadataDescriptionIsNonEmpty() throws {
        let tokenizer = try TokenizerInfo(encodedVocab: ["a", "b"])
        #expect(!tokenizer.description.isEmpty)
    }

    @Test func serializationRoundTrip() throws {
        let tokenizer = try TokenizerInfo(encodedVocab: ["a", "b", "c"])
        let serialized = tokenizer.jsonData
        let restored = try TokenizerInfo(jsonData: serialized)
        #expect(restored.vocabulary.size == tokenizer.vocabulary.size)
        #expect(restored.vocabulary.decoded == tokenizer.vocabulary.decoded)
    }

    @Test func initFromVocabAndMetadata() throws {
        let tokenizer = try TokenizerInfo(encodedVocab: ["a", "b"])
        let metadata = tokenizer.description
        let rebuilt = try TokenizerInfo(encodedVocab: ["a", "b"], metadata: metadata)
        #expect(rebuilt.vocabulary.size == 2)
    }

    @Test func detectHuggingFaceMetadata() {
        let backendString = #"""
            {"decoder":{"type":"ByteLevel"},"normalizer":{"type":"Prepend","prepend":"▁"}}
            """#
        let metadata = TokenizerInfo.detectHuggingFaceMetadata(from: backendString)
        #expect(metadata.contains("vocab_type"))
        #expect(metadata.contains("add_prefix_space"))
    }

    @Test func invalidJSONThrows() {
        do {
            _ = try TokenizerInfo(jsonData: "not json".data(using: .utf8)!)
            #expect(Bool(false))
        } catch let error as XGrammarError {
            switch error {
            case .invalidJSON:
                #expect(Bool(true))
            default:
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }
    }
}
