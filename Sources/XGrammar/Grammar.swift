import Cxgrammar
import CxxStdlib
import Foundation

typealias CxxGrammar = xgrammar.Grammar

/// An abstract syntax tree (AST) for an EBNF grammar used to constrain text generation.
///
/// This type models a standard BNF grammar with regex-style character classes
/// (for example, `[a-z]` or `[^a-z]`).
/// You can construct grammars from EBNF, JSON Schema, regex patterns, or structural tag definitions.
///
/// Use `Grammar.Compiled` and `Grammar.Matcher` to apply a grammar to a specific tokenizer
/// and to constrain token-by-token decoding.
public struct Grammar: @unchecked Sendable {
    var raw: CxxGrammar

    /// The built-in JSON grammar.
    public static let json = Grammar(raw: CxxGrammar.BuiltinJSONGrammar())

    /// Returns a grammar that matches any of the provided grammars.
    public static func anyOf(_ grammars: [Grammar]) -> Grammar {
        let rawGrammars = grammars.map { $0.raw }
        return rawGrammars.withUnsafeBufferPointer { buffer in
            Grammar(
                raw: xgrammar.bridging.GrammarUnion(
                    buffer.baseAddress,
                    Int32(buffer.count)
                )
            )
        }
    }

    /// Returns a grammar that matches the concatenation of the provided grammars.
    public static func sequence(_ grammars: [Grammar]) -> Grammar {
        let rawGrammars = grammars.map { $0.raw }
        return rawGrammars.withUnsafeBufferPointer { buffer in
            Grammar(
                raw: xgrammar.bridging.GrammarConcat(
                    buffer.baseAddress,
                    Int32(buffer.count)
                )
            )
        }
    }

    /// Creates a grammar from an EBNF string.
    ///
    /// - Parameters:
    ///   - ebnf: An EBNF-formatted grammar definition.
    ///   - rootRule: The name of the root rule.
    public init(ebnf: String, rootRule: String = "root") {
        self.raw = CxxGrammar.FromEBNF(std.string(ebnf), std.string(rootRule))
    }

    /// Creates a grammar from a regex pattern.
    ///
    /// The regex is converted to EBNF internally.
    public init(regex: String) {
        self.raw = CxxGrammar.FromRegex(std.string(regex), false)
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
        self.raw = xgrammar.bridging.GrammarFromJSONSchema(
            std.string(jsonSchema),
            formatting.allowsFlexibleWhitespace,
            hasIndentation,
            Int32(formatting.indentation ?? 0),
            hasSeparators,
            std.string(separatorsValue.itemSeparator),
            std.string(separatorsValue.keyValueSeparator),
            strictMode,
            hasMaxWhitespace,
            Int32(formatting.maximumWhitespaceCount ?? 0),
            false
        )
    }

    /// Creates a grammar from a structural tag JSON definition.
    public init(structuralTag json: String) throws {
        var result = CxxGrammar(xgrammar.NullObj())
        var error = std.string()
        var errorKind = xgrammar.bridging.ErrorKind.none
        let ok = xgrammar.bridging.GrammarFromStructuralTag(
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

    /// Creates a grammar from serialized JSON data.
    public init(jsonData: Data) throws {
        guard let json = String(data: jsonData, encoding: .utf8) else {
            throw XGrammarError.invalidJSON("Invalid UTF-8 data.")
        }
        var result = CxxGrammar(xgrammar.NullObj())
        var error = std.string()
        var errorKind = xgrammar.bridging.ErrorKind.none
        let ok = xgrammar.bridging.GrammarDeserializeJSON(
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

    init(raw: CxxGrammar) {
        self.raw = raw
    }

    /// Serializes the grammar to JSON data.
    public var jsonData: Data {
        return Data(String(raw.SerializeJSON()).utf8)
    }

    /// Compiles this grammar for a specific tokenizer.
    public func compiled(for tokenizerInfo: TokenizerInfo) -> Grammar.Compiled {
        let compiler = Grammar.Compiler(tokenizerInfo: tokenizerInfo)
        return compiler.compile(self)
    }

    /// Creates a matcher for this grammar with a specific tokenizer.
    public func matcher(
        for tokenizerInfo: TokenizerInfo,
        stopTokens: [Int32]? = nil,
        terminatesWithoutStopToken: Bool = false
    ) -> Grammar.Matcher {
        compiled(for: tokenizerInfo)
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
        String(raw.ToString())
    }
}
