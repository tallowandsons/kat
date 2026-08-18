import Foundation

/// A user-defined button shown on the break overlay. Clicking it runs `scriptPath`
/// (fire-and-forget) without ending the break — the user can also Postpone/Skip.
struct CustomButtonConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var scriptPath: String
}
