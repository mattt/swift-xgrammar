import Cxgrammar

#if canImport(CoreML)
    import CoreML
#endif

extension Grammar {
    /// A stateful matcher that tracks generation progress and provides token masks.
    ///
    /// The matcher implements a non-deterministic pushdown automaton (NPDA) and supports
    /// backtracking. It can compute the set of acceptable next tokens and store them
    /// into a bitmask for constrained decoding.
    public final class Matcher: @unchecked Sendable {
        let handle: OpaquePointer

        deinit { xgrammar_matcher_destroy(handle) }

        /// A compressed bitmask for constraining next-token selection.
        ///
        /// The bitmask is stored as 32-bit words and sized according to the vocabulary.
        /// Use `maskLogits(_:vocabSize:)` to apply the mask to logits in-place.
        public struct TokenBitmask: Sendable {
            /// The vocabulary size this bitmask was created for.
            public let vocabSize: Int

            /// The number of batch rows stored in this bitmask.
            public let batchSize: Int

            /// The underlying 32-bit word storage.
            var storage: [Int32]

            /// Creates a bitmask for a given batch and vocabulary size.
            public init(batchSize: Int = 1, vocabSize: Int) {
                precondition(batchSize > 0, "Batch size must be positive.")
                precondition(vocabSize > 0, "Vocab size must be positive.")
                self.vocabSize = vocabSize
                self.batchSize = batchSize
                let count = TokenBitmask.wordsPerBatch(vocabSize: vocabSize) * batchSize
                self.storage = Array(repeating: -1, count: count)
            }

            /// Resets the bitmask to all-true.
            public mutating func reset() {
                storage = Array(repeating: -1, count: storage.count)
            }

            /// The number of 32-bit words per batch row.
            var wordsPerBatch: Int {
                TokenBitmask.wordsPerBatch(vocabSize: vocabSize)
            }

            /// Computes the number of 32-bit words needed for a vocabulary size.
            public static func wordsPerBatch(vocabSize: Int) -> Int {
                Int(xgrammar_get_bitmask_size(Int32(vocabSize)))
            }

            /// Applies the bitmask to logits in-place.
            ///
            /// - Parameters:
            ///   - logits: The logits to mask in-place.
            ///   - vocabSize: The number of logits to consider. Defaults to the bitmask's vocab size.
            public func maskLogits(_ logits: inout [Float], vocabSize: Int? = nil) {
                let targetVocabSize = vocabSize ?? self.vocabSize
                precondition(targetVocabSize > 0, "Vocab size must be positive.")
                precondition(
                    logits.count >= targetVocabSize,
                    "Logits length is smaller than vocab size."
                )
                guard !storage.isEmpty else { return }

                let limit = min(targetVocabSize, self.vocabSize)
                for tokenId in 0 ..< limit {
                    if !isTokenAllowed(tokenId, batchIndex: 0) {
                        logits[tokenId] = -Float.infinity
                    }
                }
            }

            /// Returns whether a token is allowed for a batch index.
            public func isTokenAllowed(_ tokenId: Int, batchIndex: Int = 0) -> Bool {
                let wordIndex = tokenId / 32
                let bitIndex = tokenId % 32
                let baseIndex = batchIndex * wordsPerBatch + wordIndex
                guard baseIndex < storage.count else { return true }
                let word = UInt32(bitPattern: storage[baseIndex])
                let mask = UInt32(1) << UInt32(bitIndex)
                return (word & mask) != 0
            }
        }

        /// Whether the matcher has terminated after accepting a stop token.
        public var isTerminated: Bool {
            xgrammar_matcher_is_terminated(handle)
        }

        /// Stop token IDs used by the matcher.
        public var stopTokenIDs: [Int32] {
            let count = Int(xgrammar_matcher_stop_token_ids_count(handle))
            var result: [Int32] = []
            result.reserveCapacity(count)
            for index in 0 ..< count {
                result.append(
                    xgrammar_matcher_stop_token_id_at(handle, Int32(index))
                )
            }
            return result
        }

        /// Creates a matcher for a compiled grammar.
        ///
        /// - Parameters:
        ///   - compiledGrammar: The compiled grammar that includes tokenizer preprocessing.
        ///   - stopTokens: Optional stop tokens that override detection.
        ///   - terminatesWithoutStopToken: Whether the matcher can terminate without a stop token.
        public init(
            _ compiledGrammar: Grammar.Compiled,
            stopTokens: [Int32]? = nil,
            terminatesWithoutStopToken: Bool = false
        ) {
            let resolvedStopTokens = stopTokens ?? []
            let ptr = resolvedStopTokens.withUnsafeBufferPointer { buffer in
                xgrammar_matcher_create(
                    compiledGrammar.handle.pointer,
                    buffer.baseAddress,
                    Int32(buffer.count),
                    stopTokens != nil,
                    terminatesWithoutStopToken,
                    -1
                )
            }
            self.handle = ptr!
        }

        /// Accepts a token and advances the matcher state.
        ///
        /// When the end of the root rule is reached, the matcher can only accept a stop token.
        ///
        /// - Returns: `true` if the token is accepted by the grammar.
        @discardableResult
        public func accept(_ tokenID: Int32) -> Bool {
            xgrammar_matcher_accept_token(handle, tokenID)
        }

        /// Accepts a string as a single rollback step.
        @discardableResult
        public func accept(_ string: String) -> Bool {
            xgrammar_matcher_accept_string(handle, string)
        }

        /// Fills a token bitmask for the next decoding step.
        ///
        /// - Returns: `true` if the bitmask needs to be applied (not all-true).
        @discardableResult
        public func fillNextTokenBitmask(
            _ bitmask: inout TokenBitmask,
            index: Int = 0
        ) -> Bool {
            precondition(index >= 0 && index < bitmask.batchSize, "Bitmask index out of range.")
            let rowCount = bitmask.wordsPerBatch
            let offset = rowCount * index
            return bitmask.storage.withUnsafeMutableBufferPointer { buffer in
                guard let base = buffer.baseAddress?.advanced(by: offset) else {
                    return false
                }
                return xgrammar_matcher_fill_next_token_bitmask(
                    handle,
                    base,
                    Int32(rowCount),
                    Int32(index)
                )
            }
        }

        /// Returns the deterministic jump-forward string from the current state.
        public func jumpForwardString() -> String {
            consumeCString(xgrammar_matcher_find_jump_forward_string(handle))
        }

        /// Rolls back the matcher by a number of accepted tokens.
        public func rollback(count: Int = 1) {
            xgrammar_matcher_rollback(handle, Int32(count))
        }

        /// Resets the matcher to the initial state.
        public func reset() {
            xgrammar_matcher_reset(handle)
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension Grammar.Matcher: CustomDebugStringConvertible {
    public var debugDescription: String {
        consumeCString(xgrammar_matcher_debug_print(handle))
    }
}

// MARK: - CoreML Extensions

#if canImport(CoreML)
    extension Grammar.Matcher.TokenBitmask {
        /// Returns a new tensor with masked logits set to `-infinity`.
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        public func masking(_ logits: MLTensor) async -> MLTensor {
            let shaped = await logits.shapedArray(of: Float.self)
            var scalars = Array(shaped.scalars)
            maskLogits(&scalars, vocabSize: vocabSize)
            return MLTensor(shape: shaped.shape, scalars: scalars)
        }
    }
#endif
