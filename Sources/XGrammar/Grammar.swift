import Cxgrammar
import Foundation

/// An abstract syntax tree (AST) for an EBNF grammar used to constrain text generation.
///
/// This type models a standard BNF grammar with regex-style character classes
/// (for example, `[a-z]` or `[^a-z]`).
/// You can construct grammars from EBNF, JSON Schema, regex patterns, or structural tag definitions.
///
/// Use `Grammar.Compiled` and `Grammar.Matcher` to apply a grammar to a specific tokenizer
/// and to constrain token-by-token decoding.
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

    /// The built-in JSON grammar.
    public static let json = Grammar(handle: Handle(xgrammar_grammar_create_builtin_json()))

    /// Returns a grammar that matches any of the provided grammars.
    ///
    /// - Precondition: `grammars` must not be empty.
    public static func anyOf(_ grammars: [Grammar]) -> Grammar {
        precondition(!grammars.isEmpty, "Grammar.anyOf requires at least one grammar.")
        var handles: [OpaquePointer?] = grammars.map { $0.handle.pointer }
        let result = handles.withUnsafeMutableBufferPointer { buf in
            xgrammar_grammar_create_union(buf.baseAddress, Int32(buf.count))
        }
        return Grammar(handle: Handle(result!))
    }

    /// Returns a grammar that matches the concatenation of the provided grammars.
    ///
    /// - Precondition: `grammars` must not be empty.
    public static func sequence(_ grammars: [Grammar]) -> Grammar {
        precondition(!grammars.isEmpty, "Grammar.sequence requires at least one grammar.")
        var handles: [OpaquePointer?] = grammars.map { $0.handle.pointer }
        let result = handles.withUnsafeMutableBufferPointer { buf in
            xgrammar_grammar_create_concat(buf.baseAddress, Int32(buf.count))
        }
        return Grammar(handle: Handle(result!))
    }

    /// Creates a grammar from an EBNF string.
    ///
    /// - Parameters:
    ///   - ebnf: An EBNF-formatted grammar definition.
    ///   - rootRule: The name of the root rule.
    public init(ebnf: String, rootRule: String = "root") {
        self.handle = Handle(xgrammar_grammar_create_from_ebnf(ebnf, rootRule))
    }

    /// Creates a grammar from a regex pattern.
    ///
    /// The regex is converted to EBNF internally.
    public init(regex: String) {
        self.handle = Handle(xgrammar_grammar_create_from_regex(regex))
    }

    /// Creates a grammar from a JSON schema string.
    ///
    /// - Parameters:
    ///   - jsonSchema: The JSON schema source.
    ///   - formatting: Formatting rules for whitespace, indentation, and separators.
    ///   - strictMode: When `true`, generated grammars disallow unspecified properties and items.
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
            throw makeXGrammarError(kind: errorKind, message: message)
        }
        self.handle = Handle(ptr)
    }

    /// Creates a grammar from serialized JSON data.
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
            throw makeXGrammarError(kind: errorKind, message: message)
        }
        self.handle = Handle(ptr)
    }

    /// Serializes the grammar to JSON data.
    public var jsonData: Data {
        Data(consumeCString(xgrammar_grammar_serialize_json(handle.pointer)).utf8)
    }

    /// Compiles this grammar for a specific tokenizer.
    public func compiled(for tokenizerInfo: TokenizerInfo) async -> Grammar.Compiled {
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizerInfo)
        return await compiler.compile(self)
    }

    /// Creates a matcher for this grammar with a specific tokenizer.
    public func matcher(
        for tokenizerInfo: TokenizerInfo,
        stopTokens: [Int32]? = nil,
        terminatesWithoutStopToken: Bool = false
    ) async -> Grammar.Matcher {
        await compiled(for: tokenizerInfo)
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
