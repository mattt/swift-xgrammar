import Cxgrammar

public enum XGrammar {}

extension XGrammar {
    /// Global XGrammar configuration.
    public enum Configuration {
        /// The maximum recursion depth for grammar parsing.
        public static var maxRecursionDepth: Int {
            get { Int(xgrammar.GetMaxRecursionDepth()) }
            set { xgrammar.SetMaxRecursionDepth(Int32(newValue)) }
        }

        /// The serialization version for cache compatibility.
        public static var serializationVersion: String {
            String(xgrammar.GetSerializationVersion())
        }
    }
}
