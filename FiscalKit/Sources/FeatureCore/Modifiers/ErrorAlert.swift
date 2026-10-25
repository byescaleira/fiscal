import FiscalDomain
import SwiftUI

extension View {
    public func errorAlert(_ error: Binding<FiscalError?>) -> some View {
        alert(
            "Couldn't complete",
            isPresented: Binding(
                get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } })
        ) {
            Button("OK", role: .cancel) { error.wrappedValue = nil }
        } message: {
            Text(error.wrappedValue?.localizedDescription ?? "")
        }
    }
}
