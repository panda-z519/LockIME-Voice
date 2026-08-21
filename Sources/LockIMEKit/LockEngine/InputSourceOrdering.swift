import Foundation

public enum InputSourceOrdering {
    public static func defaultFirst(
        _ sources: [InputSource],
        defaultSourceID: InputSourceID?
    ) -> [InputSource] {
        guard let defaultSourceID,
              let index = sources.firstIndex(where: { $0.id == defaultSourceID }),
              index != sources.startIndex
        else { return sources }
        var ordered = sources
        ordered.insert(ordered.remove(at: index), at: ordered.startIndex)
        return ordered
    }
}
