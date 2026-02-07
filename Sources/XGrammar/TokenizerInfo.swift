import Cxgrammar
import CxxStdlib
import Foundation

typealias CxxTokenizerInfo = xgrammar.TokenizerInfo
typealias CxxVocabType = xgrammar.VocabType

/// Tokenizer vocabulary and metadata used for grammar compilation and matching.
public struct TokenizerInfo: @unchecked Sendable, CustomStringConvertible {
    var raw: CxxTokenizerInfo

    /// Vocabulary information used by the grammar compiler.
    public struct Vocabulary: @unchecked Sendable {
        fileprivate let raw: CxxTokenizerInfo

        /// The encoding strategy for vocabulary tokens.
        public enum Encoding: Sendable, CaseIterable, Equatable, CustomStringConvertible {
            case raw
            case byteFallback
            case byteLevel

            var cxxValue: CxxVocabType {
                switch self {
                case .raw:
                    return .RAW
                case .byteFallback:
                    return .BYTE_FALLBACK
                case .byteLevel:
                    return .BYTE_LEVEL
                }
            }

            init(_ cxxValue: CxxVocabType) {
                switch cxxValue {
                case .RAW:
                    self = .raw
                case .BYTE_FALLBACK:
                    self = .byteFallback
                case .BYTE_LEVEL:
                    self = .byteLevel
                default:
                    self = .raw
                }
            }

            public var description: String {
                switch self {
                case .raw:
                    return "raw"
                case .byteFallback:
                    return "byteFallback"
                case .byteLevel:
                    return "byteLevel"
                }
            }
        }

        /// The encoding strategy used for vocabulary tokens.
        public var encoding: Encoding {
            Encoding(raw.GetVocabType())
        }

        /// The reported vocabulary size.
        public var size: Int {
            Int(raw.GetVocabSize())
        }

        /// The decoded vocabulary strings.
        public var decoded: [String] {
            var result: [String] = []
            let count = Int(xgrammar.bridging.TokenizerInfoDecodedVocabCount(raw))
            result.reserveCapacity(count)
            for index in 0..<count {
                result.append(
                    String(xgrammar.bridging.TokenizerInfoDecodedVocabAt(raw, Int32(index)))
                )
            }
            return result
        }

        /// Lazily decodes vocabulary strings as a sequence.
        public var decodedSequence: AnySequence<String> {
            AnySequence(DecodedSequence(raw: raw))
        }

        private struct DecodedSequence: Sequence {
            let raw: CxxTokenizerInfo

            func makeIterator() -> Iterator {
                Iterator(raw: raw)
            }
        }

        private struct Iterator: IteratorProtocol {
            let raw: CxxTokenizerInfo
            let count: Int
            var index: Int

            init(raw: CxxTokenizerInfo) {
                self.raw = raw
                self.count = Int(xgrammar.bridging.TokenizerInfoDecodedVocabCount(raw))
                self.index = 0
            }

            mutating func next() -> String? {
                guard index < count else {
                    return nil
                }
                defer { index += 1 }
                return String(xgrammar.bridging.TokenizerInfoDecodedVocabAt(raw, Int32(index)))
            }
        }
    }

    init(raw: CxxTokenizerInfo) {
        self.raw = raw
    }

    /// A human-readable metadata description.
    public var description: String {
        String(raw.DumpMetadata())
    }

    /// Whether tokenization requires a prefix space.
    public var addPrefixSpace: Bool {
        raw.GetAddPrefixSpace()
    }

    /// Vocabulary metadata.
    public var vocabulary: Vocabulary {
        Vocabulary(raw: raw)
    }

    /// Stop token IDs detected from the vocabulary or provided explicitly.
    public var stopTokenIDs: [Int32] {
        var result: [Int32] = []
        let count = Int(xgrammar.bridging.TokenizerInfoStopTokenIdsCount(raw))
        result.reserveCapacity(count)
        for index in 0..<count {
            result.append(
                xgrammar.bridging.TokenizerInfoStopTokenIdAt(raw, Int32(index))
            )
        }
        return result
    }

    /// Special token IDs detected from the vocabulary.
    public var specialTokenIDs: [Int32] {
        var result: [Int32] = []
        let count = Int(xgrammar.bridging.TokenizerInfoSpecialTokenIdsCount(raw))
        result.reserveCapacity(count)
        for index in 0..<count {
            result.append(
                xgrammar.bridging.TokenizerInfoSpecialTokenIdAt(raw, Int32(index))
            )
        }
        return result
    }

    /// Detects tokenizer metadata from a Hugging Face backend string.
    public static func detectHuggingFaceMetadata(from backendString: String) -> String {
        String(CxxTokenizerInfo.DetectMetadataFromHF(std.string(backendString)))
    }

    /// Creates tokenizer info from an encoded vocabulary.
    ///
    /// - Parameters:
    ///   - encodedVocab: The encoded vocabulary strings.
    ///   - encoding: The encoding used by the vocabulary.
    ///   - vocabularySize: The total vocabulary size, if different from `encodedVocab.count`.
    ///   - stopTokenIDs: Optional stop tokens to override detection.
    ///   - addPrefixSpace: Whether tokenization requires a prefix space.
    public init(
        encodedVocab: [String],
        encoding: Vocabulary.Encoding = .raw,
        vocabularySize: Int? = nil,
        stopTokenIDs: [Int32]? = nil,
        addPrefixSpace: Bool = false
    ) {
        let encodedStrings = encodedVocab.map { std.string($0) }
        let stopTokens = stopTokenIDs ?? []
        self.raw = encodedStrings.withUnsafeBufferPointer { encodedBuffer in
            stopTokens.withUnsafeBufferPointer { stopBuffer in
                xgrammar.bridging.CreateTokenizerInfo(
                    encodedBuffer.baseAddress,
                    Int32(encodedBuffer.count),
                    encoding.cxxValue,
                    Int32(vocabularySize ?? 0),
                    vocabularySize != nil,
                    stopBuffer.baseAddress,
                    Int32(stopBuffer.count),
                    stopTokenIDs != nil,
                    addPrefixSpace
                )
            }
        }
    }

    /// Creates tokenizer info from serialized JSON data.
    public init(jsonData: Data) throws {
        guard let json = String(data: jsonData, encoding: .utf8) else {
            throw XGrammarError.invalidJSON("Invalid UTF-8 data.")
        }
        var result = CxxTokenizerInfo(xgrammar.NullObj())
        var error = std.string()
        var errorKind = xgrammar.bridging.ErrorKind.none
        let ok = xgrammar.bridging.TokenizerInfoDeserializeJSON(
            std.string(json),
            &result,
            &error,
            &errorKind
        )
        if !ok {
            throw makeXGrammarError(kind: errorKind, message: String(error))
        }
        self.raw = result
    }

    /// Creates tokenizer info from vocab strings and serialized metadata.
    public init(encodedVocab: [String], metadata: String) {
        let encodedStrings = encodedVocab.map { std.string($0) }
        let rawInfo = encodedStrings.withUnsafeBufferPointer { buffer in
            xgrammar.bridging.TokenizerInfoFromVocabAndMetadata(
                buffer.baseAddress,
                Int32(buffer.count),
                std.string(metadata)
            )
        }
        self.raw = rawInfo
    }

    /// Serializes tokenizer info to JSON data.
    public var jsonData: Data {
        return Data(String(raw.SerializeJSON()).utf8)
    }
}
