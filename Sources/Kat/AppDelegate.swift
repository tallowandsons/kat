import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsStore: SettingsStore?
    private var scheduler: BreakScheduler?
    private var statusItemController: StatusItemController?
    private var overlayController: BreakOverlayController?
    private var notificationManager: BreakNotificationManager?
    private var lifecycleScriptRunner: LifecycleScriptRunner?
    private var cameraMonitor: CameraMonitor?
    private var lockStateMonitor: LockStateMonitor?
    private var preferencesWindowController: PreferencesWindowController?
    private var welcomeWindowController: WelcomeWindowController?
    private var updateMonitor: UpdateAvailabilityMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders: Info.plist's LSUIElement handles this once bundled as
        // Kat.app, but setting it explicitly also keeps unbundled `swift run` dev
        // launches free of a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let settingsStore = SettingsStore()
        self.settingsStore = settingsStore

        let scheduler = BreakScheduler(scheduleProvider: { [settingsStore] in settingsStore.scheduleConfig })
        self.scheduler = scheduler
        scheduler.isCameraGateEnabled = { [settingsStore] in settingsStore.postponeOnCameraUse }

        let cameraMonitor = CameraMonitor()
        self.cameraMonitor = cameraMonitor
        scheduler.isCameraInUse = { [weak cameraMonitor] in cameraMonitor?.isCameraInUse ?? false }

        let lockStateMonitor = LockStateMonitor()
        self.lockStateMonitor = lockStateMonitor
        lockStateMonitor.gracePeriodSecondsProvider = { [settingsStore] in settingsStore.lockGracePeriodSeconds }

        // True from the moment a break ends until the screensaver actually disengages
        // (the user is genuinely back) — see `BreakStatus.breakOverMessage`.
        var breakJustEnded = false

        // Weak captures: this closure is stored on `scheduler.onBreakStart`/`onBreakEnd`
        // etc. below, so a strong capture of `scheduler` here would be a retain cycle
        // (scheduler -> closure -> scheduler).
        let publishStatus: () -> Void = { [weak scheduler, weak lockStateMonitor, settingsStore] in
            guard let scheduler, let lockStateMonitor else { return }
            BreakStatusPublisher.publish(
                from: scheduler,
                isScreenLocked: lockStateMonitor.isLocked,
                breakOverMessage: breakJustEnded ? settingsStore.breakOverMessage : nil
            )
        }
        lockStateMonitor.onChange = { _ in publishStatus() }
        lockStateMonitor.onScreensaverDisengaged = {
            breakJustEnded = false
            publishStatus()
        }

        let overlayController = BreakOverlayController(scheduler: scheduler)
        self.overlayController = overlayController
        overlayController.customButtonsProvider = { [settingsStore] in settingsStore.customButtons }

        let lifecycleScriptRunner = LifecycleScriptRunner()
        self.lifecycleScriptRunner = lifecycleScriptRunner
        lifecycleScriptRunner.onStartScriptsProvider = { [settingsStore] in settingsStore.onStartScripts }
        lifecycleScriptRunner.onEndScriptsProvider = { [settingsStore] in settingsStore.onEndScripts }

        scheduler.onBreakStart = { [weak overlayController, weak lifecycleScriptRunner, settingsStore] in
            overlayController?.present()
            lifecycleScriptRunner?.runOnStartScripts()
            if settingsStore.pauseMediaOnBreakStart {
                MediaController.pausePlayingMedia()
            }
            breakJustEnded = false
            publishStatus()
        }
        scheduler.onBreakEnd = { [weak overlayController, weak lifecycleScriptRunner] in
            overlayController?.dismiss()
            lifecycleScriptRunner?.runOnEndScripts()
            breakJustEnded = true
            publishStatus()
        }

        let notificationManager = BreakNotificationManager()
        self.notificationManager = notificationManager
        notificationManager.isCameraGateEnabled = { [settingsStore] in settingsStore.postponeOnCameraUse }
        notificationManager.isCameraInUse = { [weak cameraMonitor] in cameraMonitor?.isCameraInUse ?? false }
        notificationManager.requestAuthorization()
        notificationManager.scheduleHeadsUp(for: scheduler.nextBreakDate)
        scheduler.onNextBreakDateChange = { [weak notificationManager] nextBreakDate in
            notificationManager?.scheduleHeadsUp(for: nextBreakDate)
            publishStatus()
        }
        publishStatus()

        let updateMonitor = UpdateAvailabilityMonitor()
        self.updateMonitor = updateMonitor
        updateMonitor.checkForUpdatesProvider = { [settingsStore] in settingsStore.checkForUpdates }
        updateMonitor.start()

        let preferencesWindowController = PreferencesWindowController(
            settingsStore: settingsStore,
            onCheckForUpdatesChanged: { [weak updateMonitor] in updateMonitor?.recheck() }
        )
        self.preferencesWindowController = preferencesWindowController

        let statusItemController = StatusItemController(scheduler: scheduler, updateMonitor: updateMonitor)
        statusItemController.onOpenPreferences = { [weak preferencesWindowController] in
            preferencesWindowController?.show()
        }
        self.statusItemController = statusItemController

        let welcomeWindowController = WelcomeWindowController(settingsStore: settingsStore)
        self.welcomeWindowController = welcomeWindowController
        if !settingsStore.hasShownWelcome {
            welcomeWindowController.show()
            settingsStore.hasShownWelcome = true
        }
    }
}
