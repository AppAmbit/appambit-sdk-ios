enum MultipartValue {
    case string(String)
    case file(MultipartFile)
    case dictionary([String: MultipartValue])
    case array([MultipartValue])

    static func key(with parentKey: String, key: String, useBrackets: Bool) -> String {
        if parentKey.isEmpty {
            return key
        }
        return useBrackets
            ? "\(parentKey)[\(key)]"
            : "\(parentKey).\(key)"
    }
}

