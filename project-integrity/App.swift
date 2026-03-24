import SwiftUI
import CoreData

@main
struct ProjectIntegrityApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        migrateHandsCountIfNeeded(context: persistenceController.container.viewContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.dark)
        }
    }
}

/// One-time migration: backfill handsCount for OnlineCash and LiveCash sessions that were
/// saved with handsCount == 0. Uses the same estimate formula as the entry forms.
/// Guarded by a UserDefaults flag so it only runs once per device.
private func migrateHandsCountIfNeeded(context: NSManagedObjectContext) {
    let migrationKey = "didMigrateHandsCount_v1"
    guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

    let settings = UserSettings.shared
    var didChange = false

    // Online sessions
    let onlineRequest: NSFetchRequest<OnlineCash> = OnlineCash.fetchRequest()
    onlineRequest.predicate = NSPredicate(format: "handsCount == 0 AND endTime != nil")
    if let sessions = try? context.fetch(onlineRequest) {
        for session in sessions {
            guard let start = session.startTime, let end = session.endTime else { continue }
            let rawHours = end.timeIntervalSince(start) / 3600.0
            let breakHours = session.breakTime / 60.0
            let durationHours = max(0, rawHours - breakHours)
            let tables = max(1, Int(session.tables))
            let estimated = Int32(durationHours * Double(settings.handsPerHourOnline) * Double(tables))
            if estimated > 0 {
                session.handsCount = estimated
                didChange = true
            }
        }
    }

    // Live sessions
    let liveRequest: NSFetchRequest<LiveCash> = LiveCash.fetchRequest()
    liveRequest.predicate = NSPredicate(format: "handsCount == 0 AND endTime != nil")
    if let sessions = try? context.fetch(liveRequest) {
        for session in sessions {
            guard let start = session.startTime, let end = session.endTime else { continue }
            let rawHours = end.timeIntervalSince(start) / 3600.0
            let breakHours = session.breakTime / 60.0
            let durationHours = max(0, rawHours - breakHours)
            let estimated = Int32(durationHours * Double(settings.handsPerHourLive))
            if estimated > 0 {
                session.handsCount = estimated
                didChange = true
            }
        }
    }

    if didChange {
        try? context.save()
    }

    UserDefaults.standard.set(true, forKey: migrationKey)
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    var body: some View {
        ZStack {
            if !hasSeenTutorial {
                TutorialView()
                    .transition(.opacity)
            } else if !hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
    }
}
