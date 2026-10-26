import Foundation

struct SchemaSwitchSetting: Identifiable, Equatable {
    let index: Int
    let name: String
    let states: [String]
    var id: Int { index }
}

enum SchemaSwitchConfigurationError: LocalizedError, Equatable {
    case invalidReset(index: Int, value: Int)

    var errorDescription: String? {
        switch self {
        case let .invalidReset(index, value):
            return "方案的第 \(index + 1) 个状态开关保存了无效选项 \(value)，已停止加载以避免意外覆盖。"
        }
    }
}

enum SchemaSwitchConfiguration {
    static func definitions(in text: String) -> [SchemaSwitchSetting] {
        var active = false
        var items: [SchemaSwitchSetting] = []
        var currentName: String?
        var switchIndex = -1

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "switches:" {
                active = true
                continue
            }
            if active, !line.hasPrefix(" "), !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                break
            }
            guard active else { continue }
            if trimmed.hasPrefix("- name:") {
                switchIndex += 1
                currentName = scalarValue(String(trimmed.dropFirst("- name:".count)))
            } else if trimmed.hasPrefix("states:"), let name = currentName,
                      let start = trimmed.firstIndex(of: "["), let end = trimmed.lastIndex(of: "]") {
                let labels = trimmed[trimmed.index(after: start)..<end].split(separator: ",").map {
                    scalarValue(String($0))
                }
                if labels.count >= 2 {
                    items.append(SchemaSwitchSetting(index: switchIndex, name: name, states: labels))
                }
                currentName = nil
            }
        }
        return items
    }

    static func selections(in patch: String, for switches: [SchemaSwitchSetting]) throws -> [Int: Int] {
        var result = Dictionary(uniqueKeysWithValues: switches.map { ($0.index, 0) })
        let known = Dictionary(uniqueKeysWithValues: switches.map { ($0.index, $0.states.count) })

        for line in patch.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let separator = trimmed.firstIndex(of: ":") else { continue }
            let key = scalarValue(String(trimmed[..<separator]))
            guard key.hasPrefix("switches/@"), key.hasSuffix("/reset") else { continue }
            let start = key.index(key.startIndex, offsetBy: "switches/@".count)
            let end = key.index(key.endIndex, offsetBy: -"/reset".count)
            guard let index = Int(key[start..<end]), let stateCount = known[index] else { continue }
            let rawValue = trimmed[trimmed.index(after: separator)...]
                .split(whereSeparator: { $0.isWhitespace || $0 == "#" })
                .first
                .flatMap { Int($0) }
            guard let value = rawValue, (0..<stateCount).contains(value) else {
                throw SchemaSwitchConfigurationError.invalidReset(index: index, value: rawValue ?? -1)
            }
            result[index] = value
        }
        return result
    }

    private static func scalarValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
}
