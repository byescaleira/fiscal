import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct UpdateRequiredScreen: View {
    @Environment(AppUpdateModel.self) private var update
    @Environment(DataExportModel.self) private var export: DataExportModel?
    @Environment(\.openURL) private var openURL

    public init() {}

    public var body: some View {
        VStack(spacing: .spaceXL) {
            Spacer(minLength: 0)
            GuidePage(verbatim: update.requiredTitle, message: update.requiredMessage) {
                FiscalAnimationView(.launch, loops: true)
            }
            Spacer(minLength: 0)
            VStack(spacing: .spaceM) {
                if let url = update.appStoreURL {
                    Button("Update") { openURL(url) }.primaryButton()
                }
                #if !os(tvOS)
                    if let export {
                        UpdateExportButton().environment(export)
                    }
                #endif
                if update.isSimulating {
                    Button("Stop Simulating") { update.simulate(nil) }
                        .font(.buttonLabel)
                        .buttonStyle(.borderless)
                }
            }
        }
        .frame(maxWidth: 440)
        .padding(.spaceXL)
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}

#if !os(tvOS)
    private struct UpdateExportButton: View {
        @Environment(DataExportModel.self) private var export

        var body: some View {
            @Bindable var export = export
            Button {
                Task { await export.prepare() }
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            .font(.buttonLabel)
            .buttonStyle(.borderless)
            .fileExporter(
                isPresented: $export.isExporting, item: export.archive, contentTypes: [.json],
                defaultFilename: export.archive?.fileName, onCompletion: export.finish
            )
            .errorAlert($export.error)
        }
    }
#endif
