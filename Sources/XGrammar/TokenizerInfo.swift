import Cxgrammar
import Foundation

/// Tokenizer vocabulary and metadata
/// used for grammar compilation and matching.
///
/// Create a tokenizer info value from an encoded vocabulary
/// or from previously serialized JSON data,
/// then pass it to a ``Grammar/Compiler``
/// or use it with ``Grammar/compiled(for:)``.
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

    /// Vocabulary information associated with a tokenizer.
    public struct Vocabulary: @unchecked Sendable {
        fileprivate let handle: Handle

        /// The encoding strategy used by a tokenizer's vocabulary.
        public enum Encoding: Sendable, CaseIterable, Equatable, CustomStringConvertible {
            /// Tokens are stored as raw strings with no byte encoding.
            case raw

            /// Tokens use a byte-fallback encoding scheme.
            case byteFallback

            /// Tokens are encoded at the byte level.
            case byteLevel

            /// The corresponding C enum value.
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

            /// Creates an encoding from the corresponding C enum value.
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

        /// The encoding strategy used for this vocabulary's tokens.
        public var encoding: Encoding {
            Encoding(xgrammar_tokenizer_info_vocab_type(handle.pointer))
        }

        /// The total number of tokens in the vocabulary.
        public var size: Int {
            Int(xgrammar_tokenizer_info_vocab_size(handle.pointer))
        }

        /// All vocabulary tokens decoded as strings.
        ///
        /// For large vocabularies, prefer ``decodedSequence``
        /// to avoid allocating the entire array at once.
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

        /// A lazily decoded sequence of vocabulary token strings.
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

    /// A human-readable summary of the tokenizer metadata.
    public var description: String {
        consumeCString(xgrammar_tokenizer_info_dump_metadata(handle.pointer))
    }

    /// A Boolean value that indicates whether
    /// the tokenizer prepends a space before encoding.
    public var addPrefixSpace: Bool {
        xgrammar_tokenizer_info_add_prefix_space(handle.pointer)
    }

    /// The vocabulary associated with this tokenizer.
    public var vocabulary: Vocabulary {
        Vocabulary(handle: handle)
    }

    /// The token IDs that signal the end of generation,
    /// either detected from the vocabulary or provided at initialization.
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

    /// The token IDs identified as special tokens in the vocabulary.
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

    /// Detects tokenizer metadata from a Hugging Face
    /// `backend_tokenizer` JSON string.
    ///
    /// - Parameter backendString: The JSON string
    ///   from the Hugging Face tokenizer configuration.
    /// - Returns: A serialized metadata string
    ///   suitable for use with ``init(encodedVocab:metadata:)``.
    public static func detectHuggingFaceMetadata(from backendString: String) -> String {
        consumeCString(xgrammar_tokenizer_info_detect_metadata_from_hf(backendString))
    }

    /// Creates tokenizer information from an encoded vocabulary.
    ///
    /// - Parameters:
    ///   - encodedVocab: The encoded vocabulary token strings.
    ///   - encoding: The encoding strategy used by the vocabulary.
    ///     Defaults to ``Vocabulary/Encoding/raw``.
    ///   - vocabularySize: The total vocabulary size,
    ///     or `nil` to infer from `encodedVocab.count`.
    ///   - stopTokenIDs: Token IDs that signal the end of generation,
    ///     or `nil` to detect them automatically.
    ///   - addPrefixSpace: A Boolean value that indicates whether
    ///     the tokenizer prepends a space before encoding.
    ///     Defaults to `false`.
    /// - Throws: An error if the tokenizer information
    ///   can't be created from the provided vocabulary.
    public init(
        encodedVocab: [String],
        encoding: Vocabulary.Encoding = .raw,
        vocabularySize: Int? = nil,
        stopTokenIDs: [Int32]? = nil,
        addPrefixSpace: Bool = false
    ) throws {
        let stopTokens = stopTokenIDs ?? []
        let ptr = try withCStringArray(encodedVocab) { vocabPtr, vocabCount in
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
        guard let ptr else {
            throw XGrammarError(runtime: "tokenizer info")
        }
        self.handle = Handle(ptr)
    }

    /// Creates tokenizer information from serialized JSON data.
    ///
    /// Use this initializer to restore previously serialized
    /// tokenizer information.
    ///
    /// - Parameter jsonData: The serialized JSON representation
    ///   of tokenizer information.
    /// - Throws: An error if the data contains invalid UTF-8
    ///   or fails to deserialize.
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
            throw XGrammarError(kind: errorKind, message: message)
        }
        self.handle = Handle(ptr)
    }

    /// Creates tokenizer information from vocabulary strings
    /// and serialized metadata.
    ///
    /// Use ``detectHuggingFaceMetadata(from:)`` to obtain
    /// the metadata string from a Hugging Face tokenizer configuration.
    ///
    /// - Parameters:
    ///   - encodedVocab: The encoded vocabulary token strings.
    ///   - metadata: A serialized metadata string describing
    ///     the tokenizer configuration.
    /// - Throws: An error if the tokenizer information
    ///   can't be created from the provided inputs.
    public init(encodedVocab: [String], metadata: String) throws {
        let ptr = try withCStringArray(encodedVocab) { vocabPtr, vocabCount in
            xgrammar_tokenizer_info_create_from_vocab_and_metadata(
                vocabPtr,
                vocabCount,
                metadata
            )
        }
        guard let ptr else {
            throw XGrammarError(runtime: "tokenizer info")
        }
        self.handle = Handle(ptr)
    }

    /// A JSON representation of the tokenizer information,
    /// suitable for caching or serialization.
    public var jsonData: Data {
        Data(consumeCString(xgrammar_tokenizer_info_serialize_json(handle.pointer)).utf8)
    }
}
