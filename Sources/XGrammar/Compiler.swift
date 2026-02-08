import Cxgrammar
import Foundation

extension Grammar {
    /// A grammar compiled for a specific tokenizer.
    ///
    /// A compiled grammar contains preprocessing results
    /// for both the grammar and tokenizer,
    /// and serves as the input to ``Grammar/Matcher``.
    /// Compiled grammars are safe to serialize and cache.
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

        /// The grammar that was compiled.
        public var grammar: Grammar {
            Grammar(
                handle: Grammar.Handle(
                    xgrammar_compiled_grammar_get_grammar(handle.pointer)
                )
            )
        }

        /// The tokenizer information used during compilation.
        public var tokenizerInfo: TokenizerInfo {
            TokenizerInfo(
                handle: TokenizerInfo.Handle(
                    xgrammar_compiled_grammar_get_tokenizer_info(handle.pointer)
                )
            )
        }

        /// The estimated memory usage of the compiled grammar,
        /// in bytes.
        public var memorySize: Int {
            Int(xgrammar_compiled_grammar_memory_size(handle.pointer))
        }

        /// Creates a compiled grammar from serialized JSON data
        /// and tokenizer information.
        ///
        /// Use this initializer to restore a previously serialized
        /// compiled grammar.
        ///
        /// - Parameters:
        ///   - jsonData: The serialized JSON representation
        ///     of a compiled grammar.
        ///   - tokenizerInfo: The tokenizer information
        ///     to associate with the compiled grammar.
        /// - Throws: An error if the JSON data contains invalid UTF-8
        ///   or fails to deserialize.
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

        /// A JSON representation of the compiled grammar,
        /// suitable for caching or serialization.
        public var jsonData: Data {
            Data(consumeCString(xgrammar_compiled_grammar_serialize_json(handle.pointer)).utf8)
        }

        /// Creates a matcher from this compiled grammar.
        ///
        /// - Parameters:
        ///   - stopTokens: Token IDs that signal the end of generation.
        ///     Pass `nil` to use the stop tokens detected from the tokenizer.
        ///   - terminatesWithoutStopToken: Whether the matcher can terminate
        ///     when the grammar is fully matched,
        ///     even without encountering a stop token.
        /// - Returns: A new matcher configured for this compiled grammar.
        /// - Throws: An error if the matcher can't be created.
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

    /// Compiles grammars for a specific tokenizer,
    /// caching preprocessing results across repeated compilations.
    ///
    /// A compiler is bound to a single ``TokenizerInfo``
    /// and reuses intermediate results when compiling multiple grammars.
    /// Use ``cache`` to inspect or clear cached entries.
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

        /// The built-in JSON grammar, compiled and cached on first access.
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

        /// Creates a compiler bound to the specified tokenizer.
        ///
        /// - Parameters:
        ///   - tokenizerInfo: The tokenizer metadata
        ///     used during compilation.
        ///   - maximumThreadCount: The maximum number of threads
        ///     to use during compilation. Defaults to `8`.
        ///   - cachingEnabled: A Boolean value that indicates
        ///     whether to cache compilation results. Defaults to `true`.
        ///   - cacheSizeLimit: The maximum cache size in bytes,
        ///     or `nil` for unlimited. Defaults to `nil`.
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

        /// Compiles a grammar for use with this compiler's tokenizer.
        ///
        /// - Parameter grammar: The grammar to compile.
        /// - Returns: A compiled grammar
        ///   that can be used to create matchers.
        public func compile(_ grammar: Grammar) -> Compiled {
            Compiled(
                handle: Compiled.Handle(
                    xgrammar_compiler_compile_grammar(handle.pointer, grammar.handle.pointer)
                )
            )
        }

        /// Compiles a JSON schema into a grammar
        /// for use with this compiler's tokenizer.
        ///
        /// - Parameters:
        ///   - schema: A JSON Schema definition string.
        ///   - formatting: The formatting options
        ///     for generated JSON output. Defaults to ``JSONSchemaFormatting/default``.
        ///   - strictMode: A Boolean value that indicates
        ///     whether to disallow unspecified properties and items.
        ///     Defaults to `true`.
        /// - Returns: A compiled grammar
        ///   that constrains output to match the schema.
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

        /// Provides access to compilation cache metrics and controls.
        public actor Cache {
            private let handle: Handle

            fileprivate init(handle: Handle) {
                self.handle = handle
            }

            /// The current cache size, in bytes.
            public var size: Int {
                Int(xgrammar_compiler_cache_size(handle.pointer))
            }

            /// The cache size limit in bytes,
            /// or `nil` if there is no limit.
            public var sizeLimit: Int? {
                let value = xgrammar_compiler_cache_limit(handle.pointer)
                return value < 0 ? nil : Int(value)
            }

            /// Removes all entries from the compilation cache.
            public func clear() {
                xgrammar_compiler_clear_cache(handle.pointer)
            }
        }
    }
}
