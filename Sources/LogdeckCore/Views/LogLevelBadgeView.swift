import SwiftUI

struct LogLevelBadgeView: View {
    let level: LogLevel

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(level.label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(backgroundStyle)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(borderStyle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .accessibilityLabel(level.label)
    }

    private var tint: Color {
        switch level {
        case .debug:
            return .secondary
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .fault:
            return .purple
        }
    }

    private var foregroundStyle: AnyShapeStyle {
        if level.isIssueLevel || level == .warning {
            return AnyShapeStyle(tint)
        }

        return AnyShapeStyle(.secondary)
    }

    private var backgroundStyle: Color {
        if level.isIssueLevel || level == .warning {
            return tint.opacity(0.16)
        }

        return Color.secondary.opacity(0.09)
    }

    private var borderStyle: Color {
        if level.isIssueLevel || level == .warning {
            return tint.opacity(0.38)
        }

        return Color.secondary.opacity(0.16)
    }
}
