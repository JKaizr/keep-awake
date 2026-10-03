import SwiftUI

/// The status block at the top of the menu. Hosted inside an NSMenuItem and
/// observes the controller, so the remaining time updates live.
struct StatusHeaderView: View {
    @ObservedObject var controller: AwakeController

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                Text(controller.headline)
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(controller.detail)
                .font(.system(size: 12, weight: controller.isIndefinite ? .medium : .regular))
                .monospacedDigit()
                .foregroundColor(controller.isIndefinite ? .orange : .secondary)
                .padding(.leading, 13)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .frame(width: 290, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var dotColor: Color {
        if !controller.isActive { return Color.secondary.opacity(0.6) }
        return controller.isIndefinite ? .orange : .green
    }
}
