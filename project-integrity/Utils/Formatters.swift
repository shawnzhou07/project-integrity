import Foundation

enum AppFormatter {
    /// Format: [sign][amount] [currencyCode]. Currency code always after the number. No $ symbol.
    static func currency(_ value: Double, code: String = "") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "0.00"
        let sign = value < 0 ? "-" : ""
        if code.isEmpty {
            return "\(sign)\(formatted)"
        }
        return "\(sign)\(formatted) \(code)"
    }

    /// Signed format: + for positive, - for negative, no sign for zero. Zero shows as "0.00 [currency]" in gray.
    static func currencySigned(_ value: Double, code: String = "") -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        nf.groupingSeparator = ","
        nf.decimalSeparator = "."
        let numStr = nf.string(from: NSNumber(value: abs(value))) ?? "0.00"
        let suffix = code.isEmpty ? "" : " \(code)"
        if value > 0 { return "+\(numStr)\(suffix)" }
        if value < 0 { return "-\(numStr)\(suffix)" }
        return "0.00\(suffix)"
    }

    static func duration(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    /// Format: [sign][amount] [currencyCode]/hr. Value then currency.
    static func hourlyRate(_ value: Double, code: String = "") -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        nf.groupingSeparator = ","
        nf.decimalSeparator = "."
        let numStr = nf.string(from: NSNumber(value: Swift.abs(value))) ?? "0.00"
        let sign: String
        if value > 0 { sign = "+" }
        else if value < 0 { sign = "-" }
        else { sign = "" }
        let suffix = code.isEmpty ? "/hr" : " \(code)/hr"
        return "\(sign)\(numStr)\(suffix)"
    }

    static func percentage(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    static func sessionDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    static func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    /// Compact currency for axis labels: "$1.2k" or "-$500"
    static func currencyCompact(_ value: Double, code: String = "") -> String {
        let absVal = Swift.abs(value)
        let (num, suffix): (String, String)
        if absVal >= 1000 {
            let nf = NumberFormatter()
            nf.maximumFractionDigits = 1
            nf.minimumFractionDigits = 0
            num = nf.string(from: NSNumber(value: absVal / 1000)) ?? "0"
            suffix = "k"
        } else {
            let nf = NumberFormatter()
            nf.maximumFractionDigits = 0
            nf.minimumFractionDigits = 0
            num = nf.string(from: NSNumber(value: absVal)) ?? "0"
            suffix = ""
        }
        let prefix = value < 0 ? "-" : ""
        if code.isEmpty {
            return "\(prefix)$\(num)\(suffix)"
        }
        return "\(prefix)$\(num)\(suffix) \(code)"
    }

    static func monthYear(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    static func timeOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    static func exchangeRate(_ rate: Double) -> String {
        String(format: "%.4f", rate)
    }

    static func handsCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }

    // Format a blind value: show as integer if whole number, else 2 decimal places
    static func blindValue(_ value: Double) -> String {
        if value == value.rounded() && value >= 0 {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    static func bbValue(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
