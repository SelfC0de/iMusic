import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var toast: ToastManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                sectionLabel("Воспроизведение")
                settingsGroup {
                    toggleRow(
                        icon: "play.circle.fill",
                        iconColor: Theme.accent,
                        title: "Автовоспроизведение",
                        subtitle: "Следующий трек запустится автоматически",
                        binding: $settings.autoplay
                    )
                    divider
                    toggleRow(
                        icon: "waveform",
                        iconColor: Theme.accentBright,
                        title: "Эквалайзер",
                        subtitle: "Показывать анимацию эквалайзера",
                        binding: $settings.showEqualizer
                    )
                }

                sectionLabel("Интерфейс")
                settingsGroup {
                    toggleRow(
                        icon: "iphone.radiowaves.left.and.right",
                        iconColor: Theme.success,
                        title: "Тактильный отклик",
                        subtitle: "Вибрация при нажатиях",
                        binding: $settings.haptics
                    )
                }

                sectionLabel("Данные")
                settingsGroup {
                    toggleRow(
                        icon: "wifi.slash",
                        iconColor: Theme.warning,
                        title: "Экономия трафика",
                        subtitle: "Загружать обложки только по Wi-Fi",
                        binding: $settings.saveData
                    )
                    divider
                    HStack(spacing: 14) {
                        iconBox(icon: "internaldrive.fill", color: Theme.danger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Лимит кэша")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Text("\(settings.cacheLimit) МБ")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Stepper("", value: $settings.cacheLimit, in: 100...2000, step: 100)
                            .labelsHidden()
                    }
                    .padding(16)
                }

                sectionLabel("О приложении")
                settingsGroup {
                    infoRow(icon: "music.note", iconColor: Theme.accent, title: "iMusic", value: "1.0.0")
                    divider
                    divider
                    Button {
                        clearCache()
                        toast.show("Кэш очищен", style: .success, position: .top)
                        SettingsStore.shared.triggerHaptic(.medium)
                    } label: {
                        HStack(spacing: 14) {
                            iconBox(icon: "trash.fill", color: Theme.danger)
                            Text("Очистить кэш изображений")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.danger)
                            Spacer()
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 20)
        }
        .background(Theme.bg0)
    }

    private var header: some View {
        HStack {
            Text("Настройки")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
        .padding(.top, 56)
        .padding(.bottom, 20)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Theme.textTertiary)
            .tracking(1)
            .padding(.horizontal, 4)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Theme.surface)
        .cornerRadius(Theme.cornerMd)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerMd)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }

    private func toggleRow(icon: String, iconColor: Color, title: String, subtitle: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            iconBox(icon: icon, color: iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
            Toggle("", isOn: binding)
                .tint(Theme.accent)
                .labelsHidden()
        }
        .padding(16)
    }

    private func infoRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            iconBox(icon: icon, color: iconColor)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(16)
    }

    private func iconBox(icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
        }
    }

    private var divider: some View {
        Divider()
            .background(Theme.borderSubtle)
            .padding(.leading, 62)
    }

    private func clearCache() {
        ImageCache.shared[" "] = nil
    }
}
