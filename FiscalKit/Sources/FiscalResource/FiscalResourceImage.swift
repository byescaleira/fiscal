import SwiftUI

public enum FiscalResourceImage {
    public static func appIcon(_ name: String) -> Image {
        Image(name, bundle: .module)
    }
}
