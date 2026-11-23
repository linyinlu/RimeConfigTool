import Foundation

/// 鼠须管的十六进制颜色使用 0xBBGGRR 或 0xAABBGGRR。
struct SquirrelColor: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    static func parse(_ text: String) -> SquirrelColor? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("0x") || value.hasPrefix("0X") else { return nil }
        let digits = String(value.dropFirst(2))
        guard digits.count == 6 || digits.count == 8,
              digits.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              let number = UInt32(digits, radix: 16) else { return nil }

        return SquirrelColor(
            red: UInt8(number & 0xFF),
            green: UInt8((number >> 8) & 0xFF),
            blue: UInt8((number >> 16) & 0xFF),
            alpha: digits.count == 8 ? UInt8((number >> 24) & 0xFF) : 255
        )
    }

    var encoded: String {
        if alpha == 255 {
            return String(format: "0x%02X%02X%02X", blue, green, red)
        }
        return String(format: "0x%02X%02X%02X%02X", alpha, blue, green, red)
    }
}
