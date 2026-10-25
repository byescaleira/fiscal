import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct FlagsSection: View {
    @Environment(\.featureFlags) private var flags

    var body: some View {
        #if DEBUG
            if let flags {
                Section {
                    ForEach(FeatureFlag.allCases) { flag in
                        Toggle(
                            flag.title,
                            isOn: Binding(
                                get: { flags.isOn(flag) }, set: { flags.override(flag, $0) }))
                    }
                    Button {
                        for flag in FeatureFlag.allCases { flags.override(flag, nil) }
                    } label: {
                        IconRow(
                            "Restore Defaults", symbol: "arrow.uturn.backward",
                            color: .companion)
                    }
                } footer: {
                    Text(
                        "This device's rollout group: \(flags.bucket). Only shown in development builds."
                    )
                }
            }
        #endif
    }
}
