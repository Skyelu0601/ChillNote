import SwiftUI

enum NotificationInboxRoute: Hashable { case inbox }

struct NotificationInboxView: View {
    @ObservedObject var store: NotificationInboxStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 24, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.text("common.back"))
                Text(L10n.text("notifications.title")).font(.system(size: 28, weight: .bold))
                Spacer()
            }
            .foregroundStyle(Color.textMain)
            .padding(.horizontal, 12).padding(.vertical, 12)

            ScrollView {
                LazyVStack(spacing: 16) {
                    if store.isLoading && store.items.isEmpty { ProgressView().padding(32) }
                    if store.failed {
                        VStack(spacing: 8) {
                            Text(L10n.text("notifications.error")).foregroundStyle(Color.textSub)
                            Button(L10n.text("notifications.retry")) { Task { await store.reload() } }
                        }.padding()
                    }
                    if !store.isLoading && !store.failed && store.items.isEmpty {
                        Text(L10n.text("notifications.empty")).foregroundStyle(Color.textSub).padding(.top, 48)
                    }
                    ForEach(store.items) { item in
                        notificationCard(item)
                            .task(id: "\(item.id)-\(store.isLoading)") {
                                // Content has appeared. Do not acknowledge messages fetched only for the badge.
                                if !store.isLoading { await store.markRead(item.id) }
                            }
                    }
                }.padding(.horizontal, 20).padding(.top, 12)
            }
            .refreshable { await store.reload() }
            Text(L10n.text("notifications.footer"))
                .font(.footnote).foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 24).padding(.vertical, 24)
        }
        .background(Color.bgPrimary.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await store.reload() }
    }

    private func notificationCard(_ item: InboxNotification) -> some View {
        let trial = item.trial.flatMap { $0.endDate == nil ? nil : $0 }
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: trial == nil ? "gift" : "envelope")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Color.textMain)
                .frame(width: 48, height: 48)
                .background(Color.bgPrimary, in: Circle())
                .overlay(alignment: .topLeading) {
                    if item.readAt == nil {
                        Circle().fill(Color.brandBlue).frame(width: 7, height: 7)
                    }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                Text(trial != nil
                     ? L10n.text(trial?.reminderStatus == "ended" ? "notifications.trial_ended_title" : "notifications.trial_title")
                     : item.kind == "welcome_credits"
                     ? L10n.text("notifications.credits_title", item.amount ?? 0)
                     : L10n.text("notifications.pro_title"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textMain).fixedSize(horizontal: false, vertical: true)
                if let trial {
                    trialBody(trial)
                } else {
                    Text(L10n.text(item.kind == "welcome_credits" ? "notifications.credits_body" : "notifications.pro_body"))
                        .font(.system(size: 15)).foregroundStyle(Color.textSub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if trial == nil, let date = item.date {
                    Text(date, format: .dateTime.year().month().day())
                        .font(.caption).foregroundStyle(Color.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func trialBody(_ trial: TrialInboxInfo) -> some View {
        if let endDate = trial.endDate {
            let end = formatDate(endDate)
            let reminder = trial.reminderDate.map(formatDate)
            if let message = trialMessage(trial, end: end, reminder: reminder) {
                Text(message)
                    .font(.system(size: 15)).foregroundStyle(Color.textSub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if trial.reminderStatus != "ended" && trial.reminderStatus != "cancelled" && trial.autoRenew {
                Text(L10n.text("notifications.trial_end", end))
                    .font(.system(size: 14)).foregroundStyle(Color.textMain)
            }
            if let url = trial.subscriptionURL {
                Link(L10n.text("notifications.trial_details"), destination: url)
                    .font(.system(size: 15, weight: .semibold)).tint(Color.brandBlue)
                    .padding(.vertical, 8)
            }
        }
    }

    private func trialMessage(_ trial: TrialInboxInfo, end: String, reminder: String?) -> String? {
        if trial.reminderStatus == "ended" { return L10n.text("notifications.trial_ended") }
        if !trial.autoRenew || trial.reminderStatus == "cancelled" { return L10n.text("notifications.trial_cancelled", end) }
        if trial.reminderStatus == "scheduled", reminder != nil, let email = trial.maskedEmail, !email.isEmpty {
            return L10n.text("notifications.trial_scheduled")
        }
        if trial.reminderStatus == "sent", let reminder { return L10n.text("notifications.trial_sent", reminder) }
        return nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
