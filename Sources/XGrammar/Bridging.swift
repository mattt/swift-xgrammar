import Cxgrammar

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

/// Takes ownership of a C string allocated by the bridging layer, converts to
/// a Swift `String`, and frees the original.
@inline(__always)
func consumeCString(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
    guard let ptr else { return "" }
    let string = String(cString: ptr)
    xgrammar_free_string(ptr)
    return string
}

/// Calls `body` with a C-compatible array of C string pointers built from
/// `strings`. The pointers are valid only for the duration of `body`.
func withCStringArray<R>(
    _ strings: [String],
    _ body: (UnsafePointer<UnsafePointer<CChar>?>?, Int32) -> R
) -> R {
    let cStrings: [UnsafePointer<CChar>?] = strings.map { str in
        UnsafePointer(strdup(str))
    }
    defer {
        for ptr in cStrings {
            if let p = ptr { free(UnsafeMutablePointer(mutating: p)) }
        }
    }
    return cStrings.withUnsafeBufferPointer { buf in
        body(buf.baseAddress, Int32(strings.count))
    }
}
