
import Foundation

class StringValidation {
    static func isUInt64(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.range(of: #"^\d+$"#, options: .regularExpression) != nil else { return false }
        return UInt64(t) != nil
    }
}

extension String {
    var isUInt64Number: Bool { StringValidation.isUInt64(self) }
}
