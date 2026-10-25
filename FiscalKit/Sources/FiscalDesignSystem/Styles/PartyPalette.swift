import Foundation
import SwiftUI

public struct PartyPalette: Sendable, Equatable {
    public let primary: Color
    public let secondary: Color

    public init(primary: Color, secondary: Color) {
        self.primary = primary
        self.secondary = secondary
    }

    public var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public static func of(party: String, fallback index: Int = 0) -> PartyPalette {
        let key = party.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: " ", with: "")
        if let hex = hexes(for: key) { return make(hex.0, hex.1) }
        return index.isMultiple(of: 2) ? make(0x2A7069, 0x62ABA2) : make(0xB8841C, 0xE3B04B)
    }

    private static func make(_ primary: UInt32, _ secondary: UInt32) -> PartyPalette {
        PartyPalette(
            primary: Color(light: primary, dark: primary),
            secondary: Color(light: secondary, dark: secondary))
    }

    private static func hexes(for key: String) -> (UInt32, UInt32)? {
        switch key {
        case "pt": (0xD7191C, 0x8E0A12)
        case "pcdob": (0xC8102E, 0xF2B705)
        case "psol": (0xF2A900, 0xA6192E)
        case "psb": (0xE4572E, 0xF9C80E)
        case "pdt": (0xD62828, 0x1D3557)
        case "pv": (0x2A9D3C, 0x146B2B)
        case "rede": (0x00A19A, 0xF7941D)
        case "pl": (0x1F3C88, 0x00A859)
        case "republicanos": (0x2D8FD5, 0x0B4F8A)
        case "pp": (0x24569C, 0x6EC1E4)
        case "uniao": (0x1E5BA8, 0xF4C430)
        case "psd": (0x0F6E3A, 0xF2C14E)
        case "mdb": (0x2E9E4F, 0xF5D000)
        case "psdb": (0x1B5FAA, 0xFDD835)
        case "novo": (0xF26522, 0x1C2B39)
        case "podemos": (0x2BB673, 0x0E7C47)
        case "avante": (0xF7941D, 0x00A0DC)
        case "solidariedade": (0xF58220, 0x005BAA)
        case "cidadania": (0xEC008C, 0x2E3192)
        case "missao": (0x111827, 0xF59E0B)
        default: nil
        }
    }
}
