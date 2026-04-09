import Foundation
import SwiftUI

final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    private init() {}

    @Published var current: ToastMessage?
    private var workItem: DispatchWorkItem?

    func show(_ text: String, style: ToastMessage.ToastStyle = .info, position: ToastMessage.ToastPosition = .top) {
        workItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            current = ToastMessage(text: text, style: style, position: position)
        }
        let item = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) { self?.current = nil }
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }

    func dismiss() {
        workItem?.cancel()
        withAnimation(.easeOut(duration: 0.25)) { current = nil }
    }
}
