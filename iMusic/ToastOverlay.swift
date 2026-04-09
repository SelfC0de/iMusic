import SwiftUI

struct ToastOverlay: View {
    @EnvironmentObject var toast: ToastManager

    var body: some View {
        ZStack {
            if let msg = toast.current {
                switch msg.position {
                case .top:
                    VStack {
                        ToastBubble(msg: msg)
                            .padding(.top, 56)
                            .padding(.horizontal, 20)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                case .center:
                    ToastBubble(msg: msg)
                        .padding(.horizontal, 40)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                case .slideLeft:
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ToastBubble(msg: msg)
                                .padding(.trailing, 20)
                                .padding(.bottom, 100)
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast.current?.id)
        .allowsHitTesting(toast.current != nil)
        .onTapGesture { toast.dismiss() }
    }
}

struct ToastBubble: View {
    let msg: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: msg.style.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(msg.style.color)
            Text(msg.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(msg.style.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 12, y: 4)
        )
    }
}
