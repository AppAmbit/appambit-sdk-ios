import Foundation
import Darwin

public struct StackUtils {
    
    public static func getCallerClassName() -> String? {
        let maxStackSize = 10
        var callstack = [UnsafeMutableRawPointer?](repeating: nil, count: maxStackSize)
        let frames = backtrace(&callstack, Int32(maxStackSize))
        
        guard frames > 2 else { return nil }
        
        if let symbols = backtrace_symbols(&callstack, frames) {
            defer { free(symbols) }
            
            for i in 2..<Int(frames) {
                guard let symbolPtr = symbols[i] else { continue }
                let symbolString = String(cString: symbolPtr)
                
                if let className = parseClassName(from: symbolString),
                   !isSystemClass(className) {
                    return className
                }
            }
        }
        return nil
    }
    
    // MARK: - Helpers
    private static func parseClassName(from symbol: String) -> String? {
        let pattern = #"\d+\s+\S+\s+\S+\s+(\$s\S+|\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let range = NSRange(location: 0, length: symbol.utf16.count)
        guard let match = regex.firstMatch(in: symbol, options: [], range: range),
              let swiftRange = Range(match.range(at: 1), in: symbol) else {
            return nil
        }
        
        return String(symbol[swiftRange])
    }
    
    private static func isSystemClass(_ className: String) -> Bool {
        let systemPrefixes = [
            "Swift", "Foundation", "UIKit", "CoreGraphics",
            "Darwin", "Dispatch", "os", "CFNetwork",
            "lib", "_", "UI", "NS"
        ]
        return systemPrefixes.contains { className.hasPrefix($0) }
    }
}
