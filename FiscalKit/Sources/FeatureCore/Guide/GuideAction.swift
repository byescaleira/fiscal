import SwiftUI

public struct GuideAction {
    let title: LocalizedStringKey
    let isEnabled: Bool
    let perform: () -> Void

    public init(_ title: LocalizedStringKey, isEnabled: Bool = true, perform: @escaping () -> Void)
    {
        self.title = title
        self.isEnabled = isEnabled
        self.perform = perform
    }
}
