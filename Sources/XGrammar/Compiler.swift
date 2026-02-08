import Cxgrammar
import CxxStdlib
import Foundation

typealias CxxCompiledGrammar = xgrammar.CompiledGrammar
typealias CxxGrammarCompiler = xgrammar.GrammarCompiler

extension Grammar {
    /// A compiled grammar tied to a specific tokenizer.
    ///
    /// This type contains preprocessing results for both the grammar and tokenizer and is the
    /// input to `Grammar.Matcher`. It is safe to serialize and cache.
    public struct Compiled: @unchecked Sendable {
        var raw: CxxCompiledGrammar

        /// The original grammar.
        public var grammar: Grammar {
            Grammar(raw: raw.GetGrammar())
        }

        /// The tokenizer info used for compilation.
        public var tokenizerInfo: TokenizerInfo {
            TokenizerInfo(raw: raw.GetTokenizerInfo())
        }

        /// Estimated memory usage of the compiled grammar, in bytes.
        public var memorySize: Int {
            Int(raw.MemorySizeBytes())
        }

        init(raw: CxxCompiledGrammar) {
            self.raw = raw
        }

        /// Creates a compiled grammar from serialized JSON data and a tokenizer.
        public init(
            jsonData: Data,
            tokenizerInfo: TokenizerInfo
        ) throws {
            guard let json = String(data: jsonData, encoding: .utf8) else {
                throw XGrammarError.invalidJSON("Invalid UTF-8 data.")
            }
            var result = CxxCompiledGrammar(xgrammar.NullObj())
            var error = std.string()
            var errorKind = xgrammar.bridging.ErrorKind.none
            let ok = xgrammar.bridging.CompiledGrammarDeserializeJSON(
                std.string(json),
                tokenizerInfo.raw,
                &result,
                &error,
                &errorKind
            )
            if !ok {
                throw makeXGrammarError(kind: errorKind, message: String(error))
            }
            self.raw = result
        }

        /// Serializes the compiled grammar to JSON data.
        public var jsonData: Data {
            return Data(String(raw.SerializeJSON()).utf8)
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
        private var raw: CxxGrammarCompiler
        private var compiledJSONCache: Compiled?

        /// Lazily compiled built-in JSON grammar.
        public var compiledJSON: Compiled {
            if let cached = compiledJSONCache {
                return cached
            }
            let compiled = Compiled(raw: raw.CompileBuiltinJSONGrammar())
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
            self.raw = CxxGrammarCompiler(
                tokenizerInfo.raw,
                Int32(maximumThreadCount),
                cachingEnabled,
                Int64(cacheSizeLimit ?? -1)
            )
        }

        /// Compiles a grammar into a compiled grammar.
        public func compile(_ grammar: Grammar) -> Compiled {
            Compiled(raw: raw.CompileGrammar(grammar.raw))
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
                raw: xgrammar.bridging.GrammarCompilerCompileJSONSchema(
                    &raw,
                    std.string(schema),
                    formatting.allowsFlexibleWhitespace,
                    hasIndentation,
                    Int32(formatting.indentation ?? 0),
                    hasSeparators,
                    std.string(separatorsValue.itemSeparator),
                    std.string(separatorsValue.keyValueSeparator),
                    strictMode,
                    hasMaxWhitespace,
                    Int32(formatting.maximumWhitespaceCount ?? 0)
                )
            )
        }

        /// Cache metrics and controls for a compiler.
        public struct Cache: @unchecked Sendable {
            fileprivate unowned let compiler: Compiler

            /// Current cache size in bytes.
            public var size: Int {
                Int(compiler.raw.GetCacheSizeBytes())
            }

            /// Cache size limit in bytes.
            public var sizeLimit: Int? {
                let value = compiler.raw.CacheLimitBytes()
                return value < 0 ? nil : Int(value)
            }

            /// Clears the compilation cache.
            public func clear() {
                compiler.raw.ClearCache()
            }
        }
    }
}
