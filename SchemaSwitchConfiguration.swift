import Foundation

struct SchemaSwitchSetting: Identifiable, Equatable {
    let index: Int
    let name: String
    let states: [String]
    let defaultIndex: Int
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
        var schemaResets: [Int: Int] = [:]

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
            } else if trimmed.hasPrefix("reset:"), switchIndex >= 0 {
                // 保留无效值供 selections 报错，避免错误地回显为第 0 项。
                let raw = String(trimmed.dropFirst("reset:".count)).split(separator: "#", maxSplits: 1).first
                schemaResets[switchIndex] = raw.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? -2
            } else if trimmed.hasPrefix("states:"), let name = currentName,
                      let start = trimmed.firstIndex(of: "["), let end = trimmed.lastIndex(of: "]") {
                let labels = trimmed[trimmed.index(after: start)..<end].split(separator: ",").map {
                    scalarValue(String($0))
                }
                if labels.count >= 2 {
                    items.append(SchemaSwitchSetting(index: switchIndex, name: name, states: labels, defaultIndex: 0))
                }
                currentName = nil
            }
        }
        return items.map { item in
            SchemaSwitchSetting(index: item.index, name: item.name, states: item.states,
                                defaultIndex: schemaResets[item.index].map { $0 < 0 && $0 != -2 ? 0 : $0 } ?? 0)
        }
    }

    static func selections(in patch: String, for switches: [SchemaSwitchSetting]) throws -> [Int: Int] {
        var result: [Int: Int] = [:]
        for item in switches {
            guard (0..<item.states.count).contains(item.defaultIndex) else {
                throw SchemaSwitchConfigurationError.invalidReset(index: item.index, value: item.defaultIndex)
            }
            result[item.index] = item.defaultIndex
        }
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
