# XGrammar

A Swift package for grammar-guided text generation, 
powered by [xgrammar](https://github.com/mlc-ai/xgrammar).

XGrammar constrains token-by-token decoding in language models using 
EBNF grammars, JSON schemas, regex patterns, or structural tags. 
It ensures 100% structural correctness of generated output with near-zero overhead.

## Requirements

- Swift 6.0+ / Xcode 16+
- macOS 13+, iOS 16+, tvOS 16+, watchOS 9+, visionOS 1+, or Linux

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/mattt/swift-xgrammar.git", from: "0.1.0")
]
```

## Usage

### Creating a Grammar

Create grammars from EBNF definitions, JSON schemas, regex patterns, or structural tags:

```swift
import XGrammar

// From EBNF
let grammar = Grammar(ebnf: """
    root ::= "yes" | "no"
    """)

// From a regex pattern
let pattern = Grammar(regex: "[a-zA-Z]+")

// Built-in JSON grammar
let json = Grammar.json
```

### JSON Schema

Generate grammars from JSON schemas to constrain output to a specific structure:

```swift
let schema = """
    {
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "integer" }
        },
        "required": ["name", "age"]
    }
    """

let grammar = Grammar(jsonSchema: schema)
```

Configure formatting options for the generated JSON:

```swift
let grammar = Grammar(
    jsonSchema: schema,
    formatting: .compact  // No extra whitespace
)

// Or with custom formatting
let grammar = Grammar(
    jsonSchema: schema,
    formatting: JSONSchemaFormatting(
        indentation: 2,
        separators: (", ", ": ")
    )
)
```

### Composing Grammars

Combine grammars with union or concatenation:

```swift
// Match any of the provided grammars
let either = try Grammar.anyOf([
    Grammar(regex: "[0-9]+"),
    Grammar(regex: "[a-z]+")
])

// Match a sequence of grammars
let sequence = try Grammar.sequence([
    Grammar(ebnf: #"root ::= "hello ""#),
    Grammar(ebnf: #"root ::= "world""#)
])
```

### Constrained Decoding

Compile a grammar for your tokenizer and use a matcher to constrain token selection:

```swift
// Create tokenizer info from your model's vocabulary
let tokenizerInfo = try TokenizerInfo(
    encodedVocab: vocab,  // [String] from your tokenizer
    encoding: .byteLevel
)

// Compile the grammar for this tokenizer
let compiled = await grammar.compiled(for: tokenizerInfo)

// Create a matcher for constrained decoding
let matcher = try compiled.matcher()

// Allocate a token bitmask
var bitmask = Grammar.Matcher.TokenBitmask(
    vocabSize: tokenizerInfo.vocabulary.size
)

// During each decoding step:
matcher.fillNextTokenBitmask(&bitmask)
bitmask.maskLogits(&logits)
// ... sample from masked logits ...
matcher.accept(selectedTokenID)
```

### CoreML Integration

On Apple platforms (macOS 15+, iOS 18+), apply the bitmask directly to an `MLTensor`:

```swift
#if canImport(CoreML)
import CoreML

let maskedLogits = await bitmask.masking(logitsTensor)
#endif
```

### Compiler with Caching

For repeated compilations against the same tokenizer, use a compiler to benefit from caching:

```swift
let compiler = Grammar.Compiler(
    tokenizerInfo: tokenizerInfo,
    maximumThreadCount: 8,
    cacheSizeLimit: 100 * 1024 * 1024  // 100 MB
)

let compiled1 = await compiler.compile(grammar1)
let compiled2 = await compiler.compile(grammar2)

// Access the pre-compiled built-in JSON grammar
let compiledJSON = await compiler.compiledJSON

// Inspect cache usage
print(await compiler.cache.size)
await compiler.cache.clear()
```

### Serialization

Grammars, compiled grammars, and tokenizer info 
all support JSON serialization for caching and transport:

```swift
// Serialize
let data = grammar.jsonData

// Deserialize
let restored = try Grammar(jsonData: data)
```

## Development

### Running Tests

```bash
make test
```

### Formatting

Format Swift and C/C++ sources:

```bash
make format
```

Verify formatting:

```bash
make lint
```

## Acknowledgments

This package vendors C++ sources from 
[xgrammar](https://github.com/mlc-ai/xgrammar) v0.1.31.

## License

This package and the underlying xgrammar library
are available under the Apache 2.0 license.
