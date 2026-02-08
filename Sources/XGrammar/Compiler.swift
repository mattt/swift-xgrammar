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
                throw makeXGrammarError(kind: errorKind, message: message)
            }
            self.handle = Handle(ptr)
        }

        /// Serializes the compiled grammar to JSON data.
        public var jsonData: Data {
            Data(consumeCString(xgrammar_compiled_grammar_serialize_json(handle.pointer)).utf8)
        }

        /// Creates a matcher from this compiled grammar.
        public func matcher(
            stopTokens: [Int32]? = nil,
            terminatesWithoutStopToken: Bool = false
        ) -> Grammar.Matcher {
            Grammar.Matcher(
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
    public final class Compiler: @unchecked Sendable {
        private let handle: Handle
        private let compiledJSONLock = NSLock()
        private var compiledJSONCache: Compiled?

        /// ARC-managed wrapper around the opaque C handle.
        private final class Handle: @unchecked Sendable {
            let pointer: OpaquePointer
            init(_ pointer: OpaquePointer) { self.pointer = pointer }
            deinit { xgrammar_compiler_destroy(pointer) }
        }

        /// Lazily compiled built-in JSON grammar.
        public var compiledJSON: Compiled {
            compiledJSONLock.lock()
            defer { compiledJSONLock.unlock() }
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

        /// Cache metrics and controls for this compiler.
        public var cache: Cache {
            Cache(compiler: self)
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
            self.handle = Handle(
                xgrammar_compiler_create(
                    tokenizerInfo.handle.pointer,
                    Int32(maximumThreadCount),
                    cachingEnabled,
                    Int64(cacheSizeLimit ?? -1)
                )
            )
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
        public struct Cache: @unchecked Sendable {
            fileprivate unowned let compiler: Compiler

            /// Current cache size in bytes.
            public var size: Int {
                Int(xgrammar_compiler_cache_size(compiler.handle.pointer))
            }

            /// Cache size limit in bytes.
            public var sizeLimit: Int? {
                let value = xgrammar_compiler_cache_limit(compiler.handle.pointer)
                return value < 0 ? nil : Int(value)
            }

            /// Clears the compilation cache.
            public func clear() {
                xgrammar_compiler_clear_cache(compiler.handle.pointer)
            }
        }
    }
}
