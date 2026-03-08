import CoreData

struct BlindSuggestion: Equatable {
    let sb: Double
    let bb: Double
    let str: Double
    let ante: Double

    var chipLabel: String {
        var label = "\(AppFormatter.blindValue(sb))/\(AppFormatter.blindValue(bb))"
        if str > 0 { label += "/\(AppFormatter.blindValue(str))" }
        if ante > 0 { label += " (\(AppFormatter.blindValue(ante)))" }
        return label
    }
}

/// Fetches up to 3 distinct blind combinations (SB/BB/straddle/ante) from past sessions,
/// newest first. Two sessions are considered distinct if any of the four values differ.
enum SuggestedBlindsHelper {
    static func suggestionsForLive(context: NSManagedObjectContext, location: Location) -> [BlindSuggestion] {
        let req = NSFetchRequest<LiveCash>(entityName: "LiveCash")
        let name = location.name ?? ""
        req.predicate = NSPredicate(format: "locationEntity == %@ OR location == %@", location, name)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \LiveCash.startTime, ascending: false)]
        req.fetchLimit = 100
        let sessions: [LiveCash]
        do {
            sessions = try context.fetch(req)
        } catch {
            print("[SuggestedBlinds] Live fetch failed: \(error)")
            return []
        }
        var seen = Set<String>()
        var result: [BlindSuggestion] = []
        for s in sessions where result.count < 3 {
            let sb = s.smallBlind, bb = s.bigBlind
            guard sb > 0, bb > 0 else { continue }
            let str = s.straddle, ante = s.ante
            let key = "\(sb)_\(bb)_\(str)_\(ante)"
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(BlindSuggestion(sb: sb, bb: bb, str: str, ante: ante))
        }
        return result
    }

    static func suggestionsForOnline(context: NSManagedObjectContext, platform: Platform) -> [BlindSuggestion] {
        let req = NSFetchRequest<OnlineCash>(entityName: "OnlineCash")
        req.predicate = NSPredicate(format: "platform == %@", platform)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \OnlineCash.startTime, ascending: false)]
        req.fetchLimit = 100
        let sessions: [OnlineCash]
        do {
            sessions = try context.fetch(req)
        } catch {
            print("[SuggestedBlinds] Online fetch failed: \(error)")
            return []
        }
        var seen = Set<String>()
        var result: [BlindSuggestion] = []
        for s in sessions where result.count < 3 {
            let sb = s.smallBlind, bb = s.bigBlind
            guard sb > 0, bb > 0 else { continue }
            let str = s.straddle, ante = s.ante
            let key = "\(sb)_\(bb)_\(str)_\(ante)"
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(BlindSuggestion(sb: sb, bb: bb, str: str, ante: ante))
        }
        return result
    }
}
