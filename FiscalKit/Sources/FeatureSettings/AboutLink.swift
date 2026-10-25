import Foundation
import SwiftUI

struct AboutLink: Identifiable {
    enum Kind {
        case website, help, contact, privacy, terms
    }

    let kind: Kind
    let url: URL

    var id: Kind { kind }

    var title: LocalizedStringKey {
        switch kind {
        case .website: "Website"
        case .help: "Help Center"
        case .contact: "Contact Us"
        case .privacy: "Privacy Policy"
        case .terms: "Terms of Use"
        }
    }

    var symbol: String {
        switch kind {
        case .website: "globe"
        case .help: "questionmark.circle"
        case .contact: "envelope"
        case .privacy: "hand.raised"
        case .terms: "doc.text"
        }
    }
}

extension AppInfo {
    var links: [AboutLink] {
        let pairs: [(AboutLink.Kind, URL?)] = [
            (.website, websiteURL), (.help, helpURL), (.contact, supportURL),
            (.privacy, privacyURL), (.terms, termsURL),
        ]
        return pairs.compactMap { kind, url in url.map { AboutLink(kind: kind, url: $0) } }
    }
}
