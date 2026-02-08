import Cxgrammar
import Foundation

/// Tokenizer vocabulary and metadata used for grammar compilation and matching.
public struct TokenizerInfo: @unchecked Sendable, CustomStringConvertible {
    let handle: Handle

    /// ARC-managed wrapper around the opaque C handle.
    final class Handle: @unchecked Sendable {
        let pointer: OpaquePointer
        init(_ pointer: OpaquePointer) { self.pointer = pointer }
        deinit { xgrammar_tokenizer_info_destroy(pointer) }
    }

    init(handle: Handle) {
        self.handle = handle
    }

    /// Vocabulary information used by the grammar compiler.
    public struct Vocabulary: @unchecked Sendable {
        fileprivate let handle: Handle

        /// The encoding strategy for vocabulary tokens.
        public enum Encoding: Sendable, CaseIterable, Equatable, CustomStringConvertible {
            case raw
            case byteFallback
            case byteLevel

            var cValue: xgrammar_vocab_type {
                switch self {
                case .raw:
                    return XGRAMMAR_VOCAB_RAW
                case .byteFallback:
                    return XGRAMMAR_VOCAB_BYTE_FALLBACK
                case .byteLevel:
                    return XGRAMMAR_VOCAB_BYTE_LEVEL
                }
            }

            init(_ cValue: xgrammar_vocab_type) {
                switch cValue {
                case XGRAMMAR_VOCAB_BYTE_FALLBACK:
                    self = .byteFallback
                case XGRAMMAR_VOCAB_BYTE_LEVEL:
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
            Encoding(xgrammar_tokenizer_info_vocab_type(handle.pointer))
        }

        /// The reported vocabulary size.
        public var size: Int {
            Int(xgrammar_tokenizer_info_vocab_size(handle.pointer))
        }

        /// The decoded vocabulary strings.
        public var decoded: [String] {
            let count = Int(xgrammar_tokenizer_info_decoded_vocab_count(handle.pointer))
            var result: [String] = []
            result.reserveCapacity(count)
            for index in 0 ..< count {
                result.append(
                    consumeCString(
                        xgrammar_tokenizer_info_decoded_vocab_at(
                            handle.pointer,
                            Int32(index)
                        )
                    )
                )
            }
            return result
        }

        /// Lazily decodes vocabulary strings as a sequence.
        public var decodedSequence: AnySequence<String> {
            AnySequence(DecodedSequence(handle: handle))
        }

        private struct DecodedSequence: Sequence {
            let handle: Handle

            func makeIterator() -> Iterator {
                Iterator(handle: handle)
            }
        }

        private struct Iterator: IteratorProtocol {
            let handle: Handle
            let count: Int
            var index: Int

            init(handle: Handle) {
                self.handle = handle
                self.count = Int(xgrammar_tokenizer_info_decoded_vocab_count(handle.pointer))
                self.index = 0
            }

            mutating func next() -> String? {
                guard index < count else {
                    return nil
                }
                defer { index += 1 }
                return consumeCString(
                    xgrammar_tokenizer_info_decoded_vocab_at(handle.pointer, Int32(index))
                )
            }
        }
    }

    /// A human-readable metadata description.
    public var description: String {
        consumeCString(xgrammar_tokenizer_info_dump_metadata(handle.pointer))
    }

    /// Whether tokenization requires a prefix space.
    public var addPrefixSpace: Bool {
        xgrammar_tokenizer_info_add_prefix_space(handle.pointer)
    }

    /// Vocabulary metadata.
    public var vocabulary: Vocabulary {
        Vocabulary(handle: handle)
    }

    /// Stop token IDs detected from the vocabulary or provided explicitly.
    public var stopTokenIDs: [Int32] {
        let count = Int(xgrammar_tokenizer_info_stop_token_ids_count(handle.pointer))
        var result: [Int32] = []
        result.reserveCapacity(count)
        for index in 0 ..< count {
            result.append(
                xgrammar_tokenizer_info_stop_token_id_at(handle.pointer, Int32(index))
            )
        }
        return result
    }

    /// Special token IDs detected from the vocabulary.
    public var specialTokenIDs: [Int32] {
        let count = Int(xgrammar_tokenizer_info_special_token_ids_count(handle.pointer))
        var result: [Int32] = []
        result.reserveCapacity(count)
        for index in 0 ..< count {
            result.append(
                xgrammar_tokenizer_info_special_token_id_at(handle.pointer, Int32(index))
            )
        }
        return result
    }

    /// Detects tokenizer metadata from a Hugging Face backend string.
    public static func detectHuggingFaceMetadata(from backendString: String) -> String {
        consumeCString(xgrammar_tokenizer_info_detect_metadata_from_hf(backendString))
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
        let stopTokens = stopTokenIDs ?? []
        let ptr = withCStringArray(encodedVocab) { vocabPtr, vocabCount in
            stopTokens.withUnsafeBufferPointer { stopBuffer in
                xgrammar_tokenizer_info_create(
                    vocabPtr,
                    vocabCount,
                    encoding.cValue,
                    Int32(vocabularySize ?? 0),
                    vocabularySize != nil,
                    stopBuffer.baseAddress,
                    Int32(stopBuffer.count),
                    stopTokenIDs != nil,
                    addPrefixSpace
                )
            }
        }
        self.handle = Handle(ptr!)
    }

    /// Creates tokenizer info from serialized JSON data.
    public init(jsonData: Data) throws {
        guard let json = String(data: jsonData, encoding: .utf8) else {
            throw XGrammarError.invalidJSON("Invalid UTF-8 data.")
        }
        var errorKind = XGRAMMAR_ERROR_NONE
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard
            let ptr = xgrammar_tokenizer_info_create_from_serialized_json(
                json,
                &errorKind,
                &errorMessage
            )
        else {
            let message = consumeCString(errorMessage)
            throw makeXGrammarError(kind: errorKind, message: message)
        }
        self.handle = Handle(ptr)
    }

    /// Creates tokenizer info from vocab strings and serialized metadata.
    public init(encodedVocab: [String], metadata: String) {
        let ptr = withCStringArray(encodedVocab) { vocabPtr, vocabCount in
            xgrammar_tokenizer_info_create_from_vocab_and_metadata(
                vocabPtr,
                vocabCount,
                metadata
            )
        }
        self.handle = Handle(ptr!)
    }

    /// Serializes tokenizer info to JSON data.
    public var jsonData: Data {
        Data(consumeCString(xgrammar_tokenizer_info_serialize_json(handle.pointer)).utf8)
    }
}
