/// Formatting options used when generating grammars from JSON Schema.
public struct JSONSchemaFormatting: Sendable {
    /// Whether to allow any whitespace between JSON tokens.
    public var allowsFlexibleWhitespace: Bool

    /// The indentation width in spaces, or `nil` for single-line output.
    public var indentation: Int?

    /// The separators used between items and key/value pairs.
    public var separators: (itemSeparator: String, keyValueSeparator: String)?

    /// The maximum number of whitespace characters to allow, if any.
    public var maximumWhitespaceCount: Int?

    /// Default formatting with flexible whitespace.
    public static let `default` = JSONSchemaFormatting(allowsFlexibleWhitespace: true)

    /// Compact formatting with no extra whitespace.
    public static let compact = JSONSchemaFormatting(
        allowsFlexibleWhitespace: false,
        separators: (",", ":")
    )

    /// Creates formatting options for JSON schema grammar generation.
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
