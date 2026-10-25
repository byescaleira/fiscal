import FiscalDomain
import SwiftUI

struct LanguageSection: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Section {
            Picker("Language", selection: $settings.language) {
                ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.inline)
        } footer: {
            Text(settings.languageFooter)
        }
    }
}
