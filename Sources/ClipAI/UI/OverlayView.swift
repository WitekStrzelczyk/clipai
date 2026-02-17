import SwiftUI

/// SwiftUI view for the overlay content.
/// Displays a Raycast-style dark overlay with placeholder content.
struct OverlayView: View {
    var body: some View {
        VStack {
            // Placeholder content for Story 2
            // Story 3 will add the actual clipboard history list
            Text("ClipAI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        )
    }
}

#Preview {
    OverlayView()
        .frame(width: 600, height: 400)
}
