import Cxgrammar
import Foundation

/// An error returned by the XGrammar library.
public enum XGrammarError: Error, Sendable {
    /// The serialized data was produced by an incompatible version.
    case deserializeVersion(String)

    /// The serialized data has an invalid format.
    case deserializeFormat(String)

    /// The input isn't valid JSON.
    case invalidJSON(String)

    /// The structural tag definition is malformed.
    case invalidStructuralTag(String)

    /// The JSON Schema definition is invalid.
    case invalidJSONSchema(String)

    /// A general runtime error.
    case runtimeError(String)

    /// Creates an error from a C error kind and message.
    init(kind: xgrammar_error_kind, message: String) {
        switch kind {
        case XGRAMMAR_ERROR_DESERIALIZE_VERSION:
            self = .deserializeVersion(message)
        case XGRAMMAR_ERROR_DESERIALIZE_FORMAT:
            self = .deserializeFormat(message)
        case XGRAMMAR_ERROR_INVALID_JSON:
            self = .invalidJSON(message)
        case XGRAMMAR_ERROR_INVALID_STRUCTURAL_TAG:
            self = .invalidStructuralTag(message)
        case XGRAMMAR_ERROR_INVALID_JSON_SCHEMA:
            self = .invalidJSONSchema(message)
        default:
            self = .runtimeError(message)
        }
    }

    /// Creates a runtime error describing a failed object creation.
    init(runtime context: String) {
        self = .runtimeError("XGrammar failed to create \(context).")
    }
}

// MARK: - CustomStringConvertible

extension XGrammarError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .deserializeVersion(let message),
            .deserializeFormat(let message),
            .invalidJSON(let message),
            .invalidStructuralTag(let message),
            .invalidJSONSchema(let message),
            .runtimeError(let message):
            return message
        }
    }
}

// MARK: - LocalizedError

extension XGrammarError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
