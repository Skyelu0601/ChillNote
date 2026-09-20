import Foundation

enum AnnualPriceExperiment: String {
    case annual4999 = "annual_49_99"
    case annual5999 = "annual_59_99"

    static let weeklyProductIdentifier = "com.chillnote.pro.weekly"

    var offeringIdentifier: String {
        switch self {
        case .annual4999: return "post_login_two_page_trial_4999"
        case .annual5999: return "post_login_two_page_trial_5999"
        }
    }

    var annualProductIdentifier: String {
        switch self {
        case .annual4999: return "com.chillnote.pro.yearly49"
        case .annual5999: return "com.chillnote.pro.yearly"
        }
    }

    var allowedProductIdentifiers: Set<String> {
        [Self.weeklyProductIdentifier, annualProductIdentifier]
    }

    static func variant(for userID: String) -> AnnualPriceExperiment {
        var hash: UInt32 = 2_166_136_261
        for byte in userID.lowercased().utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash % 100 < 50 ? .annual4999 : .annual5999
    }
}
