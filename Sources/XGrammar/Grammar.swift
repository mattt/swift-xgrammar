import Cxgrammar
import Foundation

/// A formal grammar used to constrain text generation.
///
/// A grammar models a standard BNF grammar
/// with regex-style character classes
/// (for example, `[a-z]` or `[^a-z]`).
/// You can construct grammars from EBNF strings,
/// JSON Schema definitions, regex patterns,
/// or structural tag specifications.
///
/// To apply a grammar during decoding,
/// compile it for a specific tokenizer using ``compiled(for:)``
/// and create a ``Matcher`` from the result.
public struct Grammar: @unchecked Sendable {
    let handle: Handle

    /// ARC-managed wrapper around the opaque C handle.
    final class Handle: @unchecked Sendable {
        let pointer: OpaquePointer
        init(_ pointer: OpaquePointer) { self.pointer = pointer }
        deinit { xgrammar_grammar_destroy(pointer) }
    }

    init(handle: Handle) {
        self.handle = handle
    }

    /// A built-in grammar that matches any valid JSON value.
    public static let json = Grammar(handle: Handle(xgrammar_grammar_create_builtin_json()))

    /// Returns a grammar that matches any one of the provided grammars.
    ///
    /// The resulting grammar accepts input
    /// that matches at least one of the given grammars.
    ///
    /// - Parameter grammars: The grammars to combine.
    ///   Must contain at least one element.
    /// - Returns: A new grammar representing the union
    ///   of the provided grammars.
    /// - Throws: An error if `grammars` is empty
    ///   or the union can't be created.
    public static func anyOf(_ grammars: [Grammar]) throws -> Grammar {
        guard !grammars.isEmpty else {
            throw XGrammarError.runtimeError("Grammar.anyOf requires at least one grammar.")
        }
        var handles: [OpaquePointer?] = grammars.map { $0.handle.pointer }
        let result = handles.withUnsafeMutableBufferPointer { buf in
            xgrammar_grammar_create_union(buf.baseAddress, Int32(buf.count))
        }
        guard let result else {
            throw XGrammarError(runtime: "union grammar")
        }
        return Grammar(handle: Handle(result))
    }

    /// Returns a grammar that matches the concatenation
    /// of the provided grammars in order.
    ///
    /// The resulting grammar accepts input where each grammar
    /// matches sequentially from start to finish.
    ///
    /// - Parameter grammars: The grammars to concatenate.
    ///   Must contain at least one element.
    /// - Returns: A new grammar representing the ordered concatenation
    ///   of the provided grammars.
    /// - Throws: An error if `grammars` is empty
    ///   or the concatenation can't be created.
    public static func sequence(_ grammars: [Grammar]) throws -> Grammar {
        guard !grammars.isEmpty else {
            throw XGrammarError.runtimeError("Grammar.sequence requires at least one grammar.")
        }
        var handles: [OpaquePointer?] = grammars.map { $0.handle.pointer }
        let result = handles.withUnsafeMutableBufferPointer { buf in
            xgrammar_grammar_create_concat(buf.baseAddress, Int32(buf.count))
        }
        guard let result else {
            throw XGrammarError(runtime: "concatenated grammar")
        }
        return Grammar(handle: Handle(result))
    }

    /// Creates a grammar from an EBNF string.
    ///
    /// - Parameters:
    ///   - ebnf: An EBNF-formatted grammar definition.
    ///   - rootRule: The name of the root production rule.
    ///     Defaults to `"root"`.
    public init(ebnf: String, rootRule: String = "root") {
        self.handle = Handle(xgrammar_grammar_create_from_ebnf(ebnf, rootRule))
    }

    /// Creates a grammar from a regular expression pattern.
    ///
    /// The pattern is converted to EBNF internally.
    ///
    /// - Parameter regex: A regular expression pattern string.
    public init(regex: String) {
        self.handle = Handle(xgrammar_grammar_create_from_regex(regex))
    }

    /// Creates a grammar from a JSON Schema string.
    ///
    /// - Parameters:
    ///   - jsonSchema: A JSON Schema definition string.
    ///   - formatting: The formatting options for generated JSON output.
    ///     Defaults to ``JSONSchemaFormatting/default``.
    ///   - strictMode: A Boolean value that indicates
    ///     whether to disallow unspecified properties and items.
    ///     Defaults to `true`.
    public init(
        jsonSchema: String,
        formatting: JSONSchemaFormatting = .default,
        strictMode: Bool = true
    ) {
        let hasIndentation = formatting.indentation != nil
        let hasSeparators = formatting.separators != nil
        let hasMaxWhitespace = formatting.maximumWhitespaceCount != nil
        let separatorsValue = formatting.separators ?? ("", "")
        self.handle = Handle(
            xgrammar_grammar_create_from_json_schema(
                jsonSchema,
                formatting.allowsFlexibleWhitespace,
                hasIndentation,
                Int32(formatting.indentation ?? 0),
                hasSeparators,
                separatorsValue.itemSeparator,
                separatorsValue.keyValueSeparator,
                strictMode,
                hasMaxWhitespace,
                Int32(formatting.maximumWhitespaceCount ?? 0),
                false
            )
        )
    }

    /// Creates a grammar from a structural tag JSON definition.
    ///
    /// - Parameter json: A JSON string describing the structural tag.
    /// - Throws: An error if the structural tag definition is malformed.
    public init(structuralTag json: String) throws {
        var errorKind = XGRAMMAR_ERROR_NONE
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard
            let ptr = xgrammar_grammar_create_from_structural_tag(
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

    /// Creates a grammar from serialized JSON data.
    ///
    /// Use this initializer to restore a previously serialized grammar.
    ///
    /// - Parameter jsonData: The serialized JSON representation
    ///   of a grammar.
    /// - Throws: An error if the data contains invalid UTF-8
    ///   or fails to deserialize.
    public init(jsonData: Data) throws {
        guard let json = String(data: jsonData, encoding: .utf8) else {
            throw XGrammarError.invalidJSON("Invalid UTF-8 data.")
        }
        var errorKind = XGRAMMAR_ERROR_NONE
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard
            let ptr = xgrammar_grammar_create_from_serialized_json(
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

    /// A JSON representation of the grammar,
    /// suitable for caching or serialization.
    public var jsonData: Data {
        Data(consumeCString(xgrammar_grammar_serialize_json(handle.pointer)).utf8)
    }

    /// Compiles this grammar for use with the specified tokenizer.
    ///
    /// This is a convenience method that creates a temporary compiler.
    /// If you need to compile multiple grammars for the same tokenizer,
    /// create a ``Compiler`` directly to benefit from caching.
    ///
    /// - Parameter tokenizerInfo: The tokenizer metadata
    ///   to compile against.
    /// - Returns: A compiled grammar ready for use with a matcher.
    public func compiled(for tokenizerInfo: TokenizerInfo) async -> Grammar.Compiled {
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizerInfo)
        return await compiler.compile(self)
    }

    /// Creates a matcher for this grammar with the specified tokenizer.
    ///
    /// This is a convenience method that compiles the grammar
    /// and creates a matcher in one step.
    ///
    /// - Parameters:
    ///   - tokenizerInfo: The tokenizer metadata to compile against.
    ///   - stopTokens: Token IDs that signal the end of generation.
    ///     Pass `nil` to use the stop tokens detected from the tokenizer.
    ///   - terminatesWithoutStopToken: Whether the matcher can terminate
    ///     when the grammar is fully matched,
    ///     even without encountering a stop token.
    /// - Returns: A new matcher for constrained decoding.
    /// - Throws: An error if compilation or matcher creation fails.
    public func matcher(
        for tokenizerInfo: TokenizerInfo,
        stopTokens: [Int32]? = nil,
        terminatesWithoutStopToken: Bool = false
    ) async throws -> Grammar.Matcher {
        try await compiled(for: tokenizerInfo)
            .matcher(
                stopTokens: stopTokens,
                terminatesWithoutStopToken: terminatesWithoutStopToken
            )
    }
}

// MARK: - CustomStringConvertible

extension Grammar: CustomStringConvertible {
    /// The EBNF representation of the grammar.
    public var description: String {
        consumeCString(xgrammar_grammar_to_string(handle.pointer))
    }
}
