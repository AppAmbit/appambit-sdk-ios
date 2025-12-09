import Foundation

class StringValidation {
    static func isSignedDecimal(_ s: String?) -> Bool {
        guard let raw = s else { return false }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }

        let u: Substring
        if t.hasPrefix("+") {
            u = t.dropFirst()
        } else if t.hasPrefix("-") {
            return false
        } else {
            u = Substring(t)
        }
        guard !u.isEmpty else { return false }

        guard u.unicodeScalars.allSatisfy({ 48...57 ~= $0.value }) else { return false }

        return u.unicodeScalars.contains { $0.value != 48 }
    }
}

extension String {
    var isUIntNumber: Bool { StringValidation.isSignedDecimal(self) }
}
