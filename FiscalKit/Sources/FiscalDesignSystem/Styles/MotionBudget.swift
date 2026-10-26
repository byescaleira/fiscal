import Foundation

public enum MotionBudget {
    public static var isConstrained: Bool {
        let info = ProcessInfo.processInfo
        return info.isLowPowerModeEnabled
            || info.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }
}
