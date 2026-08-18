import CoreMediaIO
import Foundation
import Observation

/// Polls whether any camera is currently in use, via the same CoreMediaIO
/// "device-is-running-somewhere" property the system uses to drive the camera indicator
/// light — the same technique as `sindresorhus/is-camera-on` and OverSight. No bundled
/// binary, no subprocess, and (confirmed via a standalone spike against Photo Booth) no
/// TCC camera-permission prompt, since no capture stream is ever opened.
@MainActor
@Observable
final class CameraMonitor {
    private(set) var isCameraInUse: Bool = false

    @ObservationIgnored
    nonisolated(unsafe) private var timer: Timer?

    init(pollInterval: TimeInterval = 10) {
        isCameraInUse = Self.anyCameraRunning()
        startPolling(interval: pollInterval)
    }

    deinit {
        timer?.invalidate()
    }

    private func startPolling(interval: TimeInterval) {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isCameraInUse = Self.anyCameraRunning()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    nonisolated static func anyCameraRunning() -> Bool {
        var deviceListAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        var dataSize: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &deviceListAddress, 0, nil, &dataSize) == kCMIOHardwareNoError,
              dataSize > 0
        else { return false }

        let deviceCount = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: deviceCount)
        var bytesUsed: UInt32 = 0
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &deviceListAddress, 0, nil, dataSize, &bytesUsed, &devices) == kCMIOHardwareNoError
        else { return false }

        for device in devices {
            var isRunningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            guard CMIOObjectHasProperty(device, &isRunningAddress) else { continue }

            var isRunning: UInt32 = 0
            let propertySize = UInt32(MemoryLayout<UInt32>.size)
            var propertyBytesUsed: UInt32 = 0
            if CMIOObjectGetPropertyData(device, &isRunningAddress, 0, nil, propertySize, &propertyBytesUsed, &isRunning) == kCMIOHardwareNoError,
               isRunning != 0 {
                return true
            }
        }
        return false
    }
}
