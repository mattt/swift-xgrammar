import Cxgrammar
import Foundation

extension Grammar {
    /// A compiled grammar tied to a specific tokenizer.
    ///
    /// This type contains preprocessing results for both the grammar and tokenizer and is the
    /// input to `Grammar.Matcher`. It is safe to serialize and cache.
    public struct Compiled: @unchecked Sendable {
        let handle: Handle

        /// ARC-managed wrapper around the opaque C handle.
        final class Handle: @unchecked Sendable {
            let pointer: OpaquePointer
            init(_ pointer: OpaquePointer) { self.pointer = pointer }
            deinit { xgrammar_compiled_grammar_destroy(pointer) }
        }

        init(handle: Handle) {
            self.handle = handle
        }

        /// The original grammar.
        public var grammar: Grammar {
            Grammar(
                handle: Grammar.Handle(
                    xgrammar_compiled_grammar_get_grammar(handle.pointer)
                )
            )
        }

        /// The tokenizer info used for compilation.
        public var tokenizerInfo: TokenizerInfo {
            TokenizerInfo(
                handle: TokenizerInfo.Handle(
                    xgrammar_compiled_grammar_get_tokenizer_info(handle.pointer)
                )
            )
        }

        /// Estimated memory usage of the compiled grammar, in bytes.
        public var memorySize: Int {
            Int(xgrammar_compiled_grammar_memory_size(handle.pointer))
        }

        /// Creates a compiled grammar from serialized JSON data and a tokenizer.
        public init(
            jsonData: Data,
            tokenizerInfo: TokenizerInfo
        ) throws {
            guard let json = String(data: jsonData, encoding: .utf8) else {
                throw XGrammarError.invalidJSON("Invalid UTF-8 data.")
            }
            var errorKind = XGRAMMAR_ERROR_NONE
            var errorMessage: UnsafeMutablePointer<CChar>?
            guard
                let ptr = xgrammar_compiled_grammar_create_from_serialized_json(
                    json,
                    tokenizerInfo.handle.pointer,
                    &errorKind,
                    &errorMessage
                )
            else {
                let message = consumeCString(errorMessage)
                throw XGrammarError(kind: errorKind, message: message)
            }
            self.handle = Handle(ptr)
        }

        /// Serializes the compiled grammar to JSON data.
        public var jsonData: Data {
            Data(consumeCString(xgrammar_compiled_grammar_serialize_json(handle.pointer)).utf8)
        }

        /// Creates a matcher from this compiled grammar.
        ///
        /// - Throws: `XGrammarError` if matcher creation fails.
        public func matcher(
            stopTokens: [Int32]? = nil,
            terminatesWithoutStopToken: Bool = false
        ) throws -> Grammar.Matcher {
            try Grammar.Matcher(
                self,
                stopTokens: stopTokens,
                terminatesWithoutStopToken: terminatesWithoutStopToken
            )
        }
    }

    /// Compiles grammars into matchers for a specific tokenizer and caches preprocessing results.
    ///
    /// This compiler is bound to a tokenizer and can reuse preprocessing across repeated
    /// compilations. Use `cache` to inspect or clear cached entries.
    public actor Compiler {
        private let handle: Handle
        private var compiledJSONCache: Compiled?
        public let cache: Cache

        /// ARC-managed wrapper around the opaque C handle.
        final class Handle: @unchecked Sendable {
            let pointer: OpaquePointer
            init(_ pointer: OpaquePointer) { self.pointer = pointer }
            deinit { xgrammar_compiler_destroy(pointer) }
        }

        /// Lazily compiled built-in JSON grammar.
        public var compiledJSON: Compiled {
            if let cached = compiledJSONCache {
                return cached
            }
            let compiled = Compiled(
                handle: Compiled.Handle(
                    xgrammar_compiler_compile_builtin_json(handle.pointer)
                )
            )
            compiledJSONCache = compiled
            return compiled
        }

        /// Creates a compiler bound to a tokenizer.
        ///
        /// - Parameters:
        ///   - tokenizerInfo: The tokenizer metadata used for compilation.
        ///   - maximumThreadCount: The maximum number of threads to use during compilation.
        ///   - cachingEnabled: Whether to enable the internal compilation cache.
        ///   - cacheSizeLimit: The maximum cache size in bytes, or `nil` for unlimited.
        public init(
            tokenizerInfo: TokenizerInfo,
            maximumThreadCount: Int = 8,
            cachingEnabled: Bool = true,
            cacheSizeLimit: Int? = nil
        ) {
            let handle = Handle(
                xgrammar_compiler_create(
                    tokenizerInfo.handle.pointer,
                    Int32(maximumThreadCount),
                    cachingEnabled,
                    Int64(cacheSizeLimit ?? -1)
                )
            )
            self.handle = handle
            self.cache = Cache(handle: handle)
        }

        /// Compiles a grammar into a compiled grammar.
        public func compile(_ grammar: Grammar) -> Compiled {
            Compiled(
                handle: Compiled.Handle(
                    xgrammar_compiler_compile_grammar(handle.pointer, grammar.handle.pointer)
                )
            )
        }

        /// Compiles a JSON schema into a compiled grammar.
        public func compile(
            jsonSchema schema: String,
            formatting: JSONSchemaFormatting = .default,
            strictMode: Bool = true
        ) -> Compiled {
            let hasIndentation = formatting.indentation != nil
            let hasSeparators = formatting.separators != nil
            let hasMaxWhitespace = formatting.maximumWhitespaceCount != nil
            let separatorsValue = formatting.separators ?? ("", "")
            return Compiled(
                handle: Compiled.Handle(
                    xgrammar_compiler_compile_json_schema(
                        handle.pointer,
                        schema,
                        formatting.allowsFlexibleWhitespace,
                        hasIndentation,
                        Int32(formatting.indentation ?? 0),
                        hasSeparators,
                        separatorsValue.itemSeparator,
                        separatorsValue.keyValueSeparator,
                        strictMode,
                        hasMaxWhitespace,
                        Int32(formatting.maximumWhitespaceCount ?? 0)
                    )
                )
            )
        }

        /// Cache metrics and controls for a compiler.
        public actor Cache {
            private let handle: Handle

            fileprivate init(handle: Handle) {
                self.handle = handle
            }

            /// Current cache size in bytes.
            public var size: Int {
                Int(xgrammar_compiler_cache_size(handle.pointer))
            }

            /// Cache size limit in bytes.
            public var sizeLimit: Int? {
                let value = xgrammar_compiler_cache_limit(handle.pointer)
                return value < 0 ? nil : Int(value)
            }

            /// Clears the compilation cache.
            public func clear() {
                xgrammar_compiler_clear_cache(handle.pointer)
            }
        }
    }
}
