/// Options that control the formatting of JSON output
/// when generating grammars from JSON Schema.
public struct JSONSchemaFormatting: Sendable {
    /// A Boolean value that indicates whether
    /// arbitrary whitespace is allowed between JSON tokens.
    public var allowsFlexibleWhitespace: Bool

    /// The number of spaces to use for indentation,
    /// or `nil` for single-line output.
    public var indentation: Int?

    /// The separator strings used between array items
    /// and between keys and values,
    /// or `nil` to use the defaults.
    public var separators: (itemSeparator: String, keyValueSeparator: String)?

    /// The maximum number of consecutive whitespace characters to allow,
    /// or `nil` for no limit.
    public var maximumWhitespaceCount: Int?

    /// Default formatting that allows flexible whitespace.
    public static let `default` = JSONSchemaFormatting(allowsFlexibleWhitespace: true)

    /// Compact formatting with no extra whitespace.
    public static let compact = JSONSchemaFormatting(
        allowsFlexibleWhitespace: false,
        separators: (",", ":")
    )

    /// Creates formatting options for JSON Schema grammar generation.
    ///
    /// - Parameters:
    ///   - allowsFlexibleWhitespace: A Boolean value that indicates
    ///     whether arbitrary whitespace is allowed between JSON tokens.
    ///     Defaults to `true`.
    ///   - indentation: The number of spaces for indentation,
    ///     or `nil` for single-line output. Defaults to `nil`.
    ///   - separators: The separator strings for array items
    ///     and key-value pairs,
    ///     or `nil` to use the defaults. Defaults to `nil`.
    ///   - maximumWhitespaceCount: The maximum number
    ///     of consecutive whitespace characters,
    ///     or `nil` for no limit. Defaults to `nil`.
    public init(
        allowsFlexibleWhitespace: Bool = true,
        indentation: Int? = nil,
        separators: (itemSeparator: String, keyValueSeparator: String)? = nil,
        maximumWhitespaceCount: Int? = nil
    ) {
        self.allowsFlexibleWhitespace = allowsFlexibleWhitespace
        self.indentation = indentation
        self.separators = separators
        self.maximumWhitespaceCount = maximumWhitespaceCount
    }
}
