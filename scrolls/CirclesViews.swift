import SwiftUI
import PhotosUI
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Helpers for circle messages that carry a shared scroll.  When the user
/// taps "Share to your circles" on a post, the resulting message has a
/// non-nil `sharedPostID` and its body text is set to the share-only
/// sentinel below.  The renderer detects the sentinel and hides the
/// otherwise-redundant text bubble, leaving just the visual SharedScrollPreview
/// card.  Real text messages (typed by the user, with or without an attached
/// share) never use this sentinel and continue to render normally.
enum SharedScrollMessageText {
    /// Sentinel that means "this message is a pure shared-scroll forward;
    /// the SharedScrollPreview card carries all the meaning, don't render
    /// the text bubble."  A single zero-width-space character so the
    /// underlying message infrastructure (which requires non-empty text)
    /// keeps accepting these messages without legacy clients seeing an
    /// embarrassing fallback string.
    static let shareOnlySentinel = "\u{200B}"

    /// Recognises both the new sentinel AND legacy generated bodies
    /// (e.g. `Shared Scroll from @user: "[MUSIC]..."`) so messages sent by
    /// older builds still render cleanly under the new UI.
    static func isShareOnlySentinel(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if trimmed == shareOnlySentinel { return true }
        // Legacy clients sent a "Shared Scroll from @user[: caption]" body.
        // Detect that pattern so existing messages in the chat history also
        // render without the redundant verbose bubble.
        return trimmed.hasPrefix("Shared Scroll from @")
    }
}

struct CirclesView: View {
    @EnvironmentObject private var viewModel: ScrollsFeedViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMembers = Set<UUID>()
    @State private var pendingDeleteCircle: CircleGroup?
    @State private var memberSearchText = ""
    @State private var remoteMemberMatches: [UserProfile] = []
    @State private var memberSearchTask: Task<Void, Never>?
    @State private var conversationSearchText = ""
    @State private var isComposeSheetPresented = false
    @State private var isManageSheetPresented = false
    @State private var composeMessageDraft = ""
    @State private var isRecipientPickerPresented = false
    @FocusState private var composeFocusedField: ComposeFocusedField?
    /// Voice recorder dedicated to the compose sheet so it can capture
    /// the first voice message in a brand-new circle the same way the
    /// existing chat does.  Separate instance so its `isRecording` state
    /// doesn't collide with the chat-view recorder.
    @StateObject private var composeVoiceRecorder = CircleVoiceRecorder()
    @State private var composeVoiceHint: String?

    private var memberPool: [UserProfile] {
        let local = viewModel.mutualCircleCandidates.filter(matchesMemberSearch)
        return deduplicatedProfiles(local + remoteMemberMatches)
    }

    private var createdCircles: [CircleGroup] {
        viewModel.circles.filter { !$0.isOneOnOneConversation }
    }

    private var oneOnOneCircles: [CircleGroup] {
        viewModel.circles.filter { $0.isOneOnOneConversation }
    }

    private enum ComposeFocusedField: Hashable {
        case recipients
        case message
    }

    private var selectedRecipientProfiles: [UserProfile] {
        selectedMembers
            .compactMap { viewModel.profile(for: $0) }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private var canStartComposeConversation: Bool {
        !selectedRecipientProfiles.isEmpty
    }

    private var oneOnOneRows: [CircleGroup] {
        oneOnOneCircles.sorted { lhs, rhs in
            latestActivityDate(for: lhs) > latestActivityDate(for: rhs)
        }
    }

    private var filteredOneOnOneRows: [CircleGroup] {
        let trimmed = conversationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return oneOnOneRows }
        return oneOnOneRows.filter { circle in
            if circle.name.lowercased().contains(trimmed) {
                return true
            }
            if oneOnOneDisplayName(for: circle).lowercased().contains(trimmed) {
                return true
            }
            if let lastMessage = circle.messages.last,
               viewModel.decryptedCircleMessageText(lastMessage, in: circle.id).lowercased().contains(trimmed) {
                return true
            }
            return false
        }
    }

    private var quickAccessCircles: [CircleGroup] {
        createdCircles
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 10) {
                headerBar
                quickAccessStrip
                searchField
                conversationList
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
        }
        .onAppear {
            refreshMemberSearchResults(for: memberSearchText)
        }
        .task {
            viewModel.syncCircleInbox(forceRefresh: true)
        }
        .onChange(of: memberSearchText) { _, newValue in
            refreshMemberSearchResults(for: newValue)
        }
        .onDisappear {
            memberSearchTask?.cancel()
        }
        .sheet(isPresented: $isComposeSheetPresented) {
            composeSheet
        }
        .sheet(isPresented: $isManageSheetPresented) {
            manageSheet
        }
        .confirmationDialog(
            "Delete this created circle?",
            isPresented: Binding(
                get: { pendingDeleteCircle != nil },
                set: { newValue in
                    if !newValue {
                        pendingDeleteCircle = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete circle", role: .destructive) {
                if let circle = pendingDeleteCircle {
                    viewModel.deleteCircle(circle)
                }
                pendingDeleteCircle = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteCircle = nil
            }
        } message: {
            Text("This removes the circle and its messages.")
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                    Text("Feed")
                        .font(.body.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            CirclesIconView(badgeCount: viewModel.circleNotificationCount)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    isManageSheetPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    isComposeSheetPresented = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.headline.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickAccessStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(quickAccessCircles) { circle in
                    NavigationLink {
                        CircleDetailView(circleID: circle.id)
                    } label: {
                        VStack(spacing: 6) {
                            circleAvatar(for: circle, size: 70)
                            Text(conversationTitle(for: circle))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(width: 76)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 6)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search", text: $conversationSearchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !conversationSearchText.isEmpty {
                Button {
                    conversationSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filteredOneOnOneRows.isEmpty {
                    Text("No one-on-one conversations yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 28)
                } else {
                    ForEach(filteredOneOnOneRows) { circle in
                        NavigationLink {
                            CircleDetailView(circleID: circle.id)
                        } label: {
                            conversationRow(for: circle)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if canDelete(circle: circle) {
                                Button(role: .destructive) {
                                    pendingDeleteCircle = circle
                                } label: {
                                    Label("Delete circle", systemImage: "trash")
                                }
                            }
                        }
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
    }

    private var composeSheet: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    Text("New Message")
                        .font(.title3.weight(.semibold))
                    HStack {
                        Spacer()
                        Button {
                            isComposeSheetPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))

                Divider()

                recipientComposerRow

                if isRecipientPickerPresented || !memberSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if memberPool.isEmpty {
                                Text("Search for people to add.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                            } else {
                                ForEach(memberPool) { profile in
                                    Button {
                                        if selectedMembers.contains(profile.id) {
                                            selectedMembers.remove(profile.id)
                                        } else {
                                            selectedMembers.insert(profile.id)
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            AvatarView(profile: profile, size: 34)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(profile.displayName)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundColor(.primary)
                                                Text("@\(profile.username)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: selectedMembers.contains(profile.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(.accentColor)
                                                .font(.title3)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                    .background(Color(.systemBackground))
                }

                Spacer(minLength: 0)

                composeInputBar
            }
        }
        .onAppear {
            composeFocusedField = .recipients
        }
    }

    private var manageSheet: some View {
        NavigationStack {
            List {
                Section("Created Circles") {
                    if createdCircles.isEmpty {
                        Text("No custom circles yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(createdCircles) { circle in
                            ManageCreatedCircleRow(
                                circle: circle,
                                onSaveName: { updatedName in
                                    viewModel.updateCreatedCircleName(circle, to: updatedName)
                                },
                                onAvatarPicked: { image in
                                    viewModel.updateCreatedCircleAvatar(circle, image: image)
                                },
                                onClearAvatar: {
                                    viewModel.clearCreatedCircleAvatar(circle)
                                },
                                onDelete: {
                                    pendingDeleteCircle = circle
                                }
                            )
                        }
                    }
                }

                Section("Tools") {
                    Button("Prune cached circle messages") {
                        viewModel.pruneCircleMessagesNow()
                    }
                }
            }
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isManageSheetPresented = false
                    }
                }
            }
        }
    }

    private var recipientComposerRow: some View {
        HStack(spacing: 10) {
            Text("To:")
                .font(.body)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedRecipientProfiles) { profile in
                        Button {
                            selectedMembers.remove(profile.id)
                        } label: {
                            HStack(spacing: 6) {
                                Text(profile.displayName)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.accentColor.opacity(0.16))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("", text: $memberSearchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($composeFocusedField, equals: .recipients)
                        .frame(minWidth: 90)
                }
                .padding(.vertical, 2)
            }

            Button {
                isRecipientPickerPresented = true
                composeFocusedField = .recipients
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private var composeInputBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                // Voice mic — replaces the previous "+" recipient-picker
                // shortcut.  Mirrors the styling of the in-chat voice mic
                // so the visual language is consistent across compose +
                // chat.  Tapping starts/stops recording; on stop, the
                // captured audio is sent as the first message of a new
                // (or existing) circle with the selected recipients.
                Button {
                    handleComposeVoiceTap()
                } label: {
                    Image(systemName: composeVoiceRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(composeVoiceRecorder.isRecording ? Color.red : Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canStartComposeConversation && !composeVoiceRecorder.isRecording)
                .opacity((canStartComposeConversation || composeVoiceRecorder.isRecording) ? 1 : 0.4)

                HStack(spacing: 8) {
                    TextField("Message", text: $composeMessageDraft, axis: .vertical)
                        .focused($composeFocusedField, equals: .message)
                        .lineLimit(1...4)

                    // The right-side mic icon has been removed per request —
                    // the send button stands alone as the only action inside
                    // the input capsule.  Voice now lives in the dedicated
                    // mic button to the left of the input.
                    if canStartComposeConversation {
                        Button {
                            startComposeConversation()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            // Status line: shown when recording or when a hint is being
            // surfaced (e.g. user tapped mic without picking recipients).
            if composeVoiceRecorder.isRecording {
                Text("Voice \(composeVoiceRecorder.elapsedText)/2:00")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let composeVoiceHint, !composeVoiceHint.isEmpty {
                Text(composeVoiceHint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    /// Compose-sheet mic button handler.  Validates recipients are
    /// selected, then toggles recording.  On stop, creates the circle
    /// (or finds an existing one) and sends the captured audio as the
    /// first message.
    private func handleComposeVoiceTap() {
        if composeVoiceRecorder.isRecording {
            composeVoiceRecorder.stop()
            return
        }
        guard canStartComposeConversation else {
            composeVoiceHint = "Pick at least one recipient first."
            return
        }
        composeVoiceHint = nil
        composeVoiceRecorder.start { url, duration in
            sendComposeVoiceMessage(url: url, durationSeconds: duration)
        }
    }

    private func sendComposeVoiceMessage(url: URL, durationSeconds: Int) {
        let recipients = selectedRecipientProfiles.filter { viewModel.canAddToCircleChats($0) }
        guard !recipients.isEmpty else { return }
        // Resolve target circle the same way the text-send path does.
        var targetCircle: CircleGroup?
        if recipients.count == 1 {
            targetCircle = viewModel.ensureOneOnOneCircle(with: recipients[0])
            if targetCircle == nil {
                viewModel.moderationErrorMessage = "You can only start one-on-one chats with mutual followers."
                return
            }
        } else {
            if let existing = existingConversationCircle(for: recipients) {
                targetCircle = existing
            } else {
                let generatedName = generatedCircleName(for: recipients)
                viewModel.createCircle(name: generatedName, members: recipients)
                targetCircle = existingConversationCircle(for: recipients) ?? viewModel.circles.first
            }
        }
        guard let circle = targetCircle else { return }
        viewModel.sendVoiceMessage(localURL: url, durationSeconds: durationSeconds, in: circle)
        // Reset compose state and dismiss — same as the text-send path.
        composeMessageDraft = ""
        memberSearchText = ""
        selectedMembers.removeAll()
        remoteMemberMatches = []
        isRecipientPickerPresented = false
        isComposeSheetPresented = false
    }

    private func conversationRow(for circle: CircleGroup) -> some View {
        HStack(spacing: 12) {
            circleAvatar(for: circle, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(conversationTitle(for: circle))
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if unreadCount(for: circle) > 0 {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 7, height: 7)
                    }
                }
                Text(conversationPreview(for: circle))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(timestampLabel(for: circle))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func circleAvatar(for circle: CircleGroup, size: CGFloat) -> some View {
        if let partner = oneOnOnePartnerProfile(for: circle) {
            AvatarView(profile: partner, size: size)
        } else if let avatar = circle.avatarImage {
            Image(platformImage: avatar)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.45), Color.indigo.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(initials(for: conversationTitle(for: circle)))
                    .font(.system(size: max(14, size * 0.36), weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }

    private func canDelete(circle: CircleGroup) -> Bool {
        true
    }

    private func startComposeConversation() {
        let recipients = selectedRecipientProfiles.filter { viewModel.canAddToCircleChats($0) }
        guard !recipients.isEmpty else { return }

        let trimmedMessage = composeMessageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        var targetCircle: CircleGroup?

        if recipients.count == 1 {
            targetCircle = viewModel.ensureOneOnOneCircle(with: recipients[0])
            if targetCircle == nil {
                viewModel.moderationErrorMessage = "You can only start one-on-one chats with mutual followers."
                return
            }
        } else {
            if let existing = existingConversationCircle(for: recipients) {
                targetCircle = existing
            } else {
                let generatedName = generatedCircleName(for: recipients)
                viewModel.createCircle(name: generatedName, members: recipients)
                targetCircle = existingConversationCircle(for: recipients) ?? viewModel.circles.first
            }
        }

        if !trimmedMessage.isEmpty, let targetCircle {
            viewModel.sendMessage(text: trimmedMessage, in: targetCircle)
        }

        composeMessageDraft = ""
        memberSearchText = ""
        selectedMembers.removeAll()
        remoteMemberMatches = []
        isRecipientPickerPresented = false
        isComposeSheetPresented = false
    }

    private func existingConversationCircle(for recipients: [UserProfile]) -> CircleGroup? {
        var targetIDs = Set(recipients.map(\.id))
        targetIDs.insert(viewModel.currentUser.id)
        return viewModel.circles.first { circle in
            Set(circle.members.map(\.profileID)) == targetIDs
        }
    }

    private func generatedCircleName(for recipients: [UserProfile]) -> String {
        let names = recipients.map(\.displayName)
        if names.count <= 2 {
            return names.joined(separator: " & ")
        }
        let head = names.prefix(2).joined(separator: ", ")
        return "\(head) +\(names.count - 2)"
    }

    private func oneOnOnePartnerProfile(for circle: CircleGroup) -> UserProfile? {
        guard circle.isOneOnOneConversation else { return nil }
        let otherMember = circle.members.first { $0.profileID != viewModel.currentUser.id && $0.status == .member }
        guard let otherID = otherMember?.profileID else { return nil }
        return viewModel.profile(for: otherID)
    }

    private func conversationTitle(for circle: CircleGroup) -> String {
        if circle.isOneOnOneConversation {
            return oneOnOneDisplayName(for: circle)
        }
        return circle.name
    }

    private func conversationPreview(for circle: CircleGroup) -> String {
        guard let last = circle.messages.last else {
            return circle.isOneOnOneConversation ? "Start your conversation" : "\(circle.memberCount) members"
        }
        if last.sharedPostID != nil {
            return "Shared a scroll"
        }
        let decrypted = viewModel.decryptedCircleMessageText(last, in: circle.id)
        return decrypted.isEmpty ? "Sent a message" : decrypted
    }

    private func unreadCount(for circle: CircleGroup) -> Int {
        circle.messages.reduce(into: 0) { partial, message in
            guard message.userID != viewModel.currentUser.id else { return }
            if viewModel.unreadCircleMessageIDs.contains(message.id) {
                partial += 1
            }
        }
    }

    private func latestActivityDate(for circle: CircleGroup) -> Date {
        circle.messages.last?.timestamp ?? circle.createdAt
    }

    private func timestampLabel(for circle: CircleGroup) -> String {
        let date = latestActivityDate(for: circle)
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func initials(for text: String) -> String {
        let words = text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .prefix(2)
        let letters = words.compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "C" : letters.uppercased()
    }

    private func oneOnOneDisplayName(for circle: CircleGroup) -> String {
        let otherMember = circle.members.first { $0.profileID != viewModel.currentUser.id && $0.status == .member }
        guard let otherID = otherMember?.profileID,
              let profile = viewModel.profile(for: otherID) else {
            return circle.name
        }
        return profile.displayName
    }

    private func matchesMemberSearch(_ profile: UserProfile) -> Bool {
        let trimmed = memberSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return true }
        return profile.displayName.lowercased().contains(trimmed) ||
            profile.username.lowercased().contains(trimmed) ||
            profile.bio.lowercased().contains(trimmed)
    }

    private func refreshMemberSearchResults(for query: String) {
        memberSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            remoteMemberMatches = []
            return
        }
        memberSearchTask = Task {
            let remote = await viewModel.searchProfilesFromBackend(matching: trimmed)
                .filter(viewModel.canAddToCircleChats)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                remoteMemberMatches = remote
            }
        }
    }

    private func deduplicatedProfiles(_ source: [UserProfile]) -> [UserProfile] {
        var seen = Set<UUID>()
        let unique = source.filter { seen.insert($0.id).inserted }
        return unique.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

private struct ManageCreatedCircleRow: View {
    let circle: CircleGroup
    let onSaveName: (String) -> Void
    let onAvatarPicked: (PlatformImage) -> Void
    let onClearAvatar: () -> Void
    let onDelete: () -> Void

    @State private var draftName: String
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isImportingAvatar = false

    init(
        circle: CircleGroup,
        onSaveName: @escaping (String) -> Void,
        onAvatarPicked: @escaping (PlatformImage) -> Void,
        onClearAvatar: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.circle = circle
        self.onSaveName = onSaveName
        self.onAvatarPicked = onAvatarPicked
        self.onClearAvatar = onClearAvatar
        self.onDelete = onDelete
        _draftName = State(initialValue: circle.name)
    }

    private var trimmedDraftName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveName: Bool {
        !trimmedDraftName.isEmpty && trimmedDraftName != circle.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedAvatarItem, matching: .images, preferredItemEncoding: .automatic) {
                    ZStack(alignment: .bottomTrailing) {
                        avatarView(size: 44)
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.accentColor)
                            .background(Circle().fill(Color(.systemBackground)))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isImportingAvatar)

                TextField("Circle name", text: $draftName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        saveNameIfNeeded()
                    }

                if canSaveName {
                    Button("Save") {
                        saveNameIfNeeded()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                if circle.avatarImage != nil || !(circle.avatarRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                    Button("Remove avatar", role: .destructive) {
                        onClearAvatar()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
                if isImportingAvatar {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating avatar...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: circle.name) { _, newValue in
            if trimmedDraftName.isEmpty || draftName == circle.name {
                draftName = newValue
            }
        }
        .onChange(of: selectedAvatarItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await importAvatar(from: newValue)
            }
        }
    }

    @ViewBuilder
    private func avatarView(size: CGFloat) -> some View {
        if let avatar = circle.avatarImage {
            Image(platformImage: avatar)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.45), Color.indigo.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(initials(for: circle.name))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }

    private func initials(for text: String) -> String {
        let words = text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .prefix(2)
        let letters = words.compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "C" : letters.uppercased()
    }

    private func saveNameIfNeeded() {
        guard canSaveName else { return }
        onSaveName(trimmedDraftName)
    }

    private func importAvatar(from item: PhotosPickerItem) async {
        await MainActor.run {
            isImportingAvatar = true
        }
        defer {
            Task { @MainActor in
                isImportingAvatar = false
                selectedAvatarItem = nil
            }
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              !data.isEmpty,
              let image = PlatformImage(data: data) else {
            return
        }
        await MainActor.run {
            onAvatarPicked(image)
        }
    }
}

struct CircleDetailView: View {
    let circleID: UUID
    @EnvironmentObject private var viewModel: ScrollsFeedViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var messageDraft = ""
    @State private var selectedTab: CircleDetailTab = .chat
    @State private var isClearChatConfirmationPresented = false
    @State private var addMemberSearchText = ""
    @State private var remoteAddMemberMatches: [UserProfile] = []
    @State private var addMemberSearchTask: Task<Void, Never>?

    private var circle: CircleGroup? {
        viewModel.circle(by: circleID)
    }

    private var memberProfiles: [(member: CircleMember, profile: UserProfile)] {
        guard let circle else { return [] }
        return circle.members.compactMap { member in
            guard let profile = viewModel.profile(for: member.profileID) else { return nil }
            return (member, profile)
        }
    }

    private var availableMembers: [UserProfile] {
        guard let circle else { return [] }
        let existingIDs = Set(circle.members.map { $0.profileID })
        let local = viewModel.mutualCircleCandidates
            .filter { !existingIDs.contains($0.id) }
            .filter(matchesAddMemberSearch)
        let remote = remoteAddMemberMatches
            .filter { !existingIDs.contains($0.id) }
        return deduplicatedProfiles(local + remote)
    }

    private var currentMembership: CircleMember? {
        guard let circle else { return nil }
        return circle.members.first(where: { $0.profileID == viewModel.currentUser.id })
    }

    private var canPostMessage: Bool {
        currentMembership?.status == .member
    }

    private var canInviteMembers: Bool {
        currentMembership?.status == .member
    }

    private var canDeleteCircle: Bool {
        circle != nil
    }

    var body: some View {
        if let circle {
            let oneOnOnePartnerName = oneOnOneDisplayName(for: circle)
            VStack(spacing: 0) {
                if !circle.isOneOnOneConversation {
                    Picker("", selection: $selectedTab) {
                        ForEach(CircleDetailTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    Divider()
                } else {
                    Divider()
                }

                let activeTab: CircleDetailTab = circle.isOneOnOneConversation ? .chat : selectedTab
                switch activeTab {
                case .chat:
                    CircleChatPane(
                        circle: circle,
                        currentUser: viewModel.currentUser,
                        profileLookup: viewModel.profile,
                        postLookup: viewModel.post(with:),
                        messageDraft: $messageDraft,
                        sendMessage: { text in
                            viewModel.sendMessage(text: text, in: circle)
                            messageDraft = ""
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    viewModel.markCircleMessagesRead(in: circle.id)
                }
                .task(id: circle.id) {
                    viewModel.syncCircleInbox(forceRefresh: true)
                }
                .onChange(of: circle.messages.count) { _, _ in
                    viewModel.markCircleMessagesRead(in: circle.id)
                }
                case .members:
                    membersView(for: circle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(circle.isOneOnOneConversation ? "One on One with \(oneOnOnePartnerName)" : circle.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refreshAddMemberSearchResults(for: addMemberSearchText)
            }
            .onChange(of: addMemberSearchText) { _, newValue in
                refreshAddMemberSearchResults(for: newValue)
            }
            .onDisappear {
                addMemberSearchTask?.cancel()
            }
        } else {
            Text("Circle not found")
                .foregroundColor(.secondary)
                .navigationTitle("Circle")
        }
    }

    private func oneOnOneDisplayName(for circle: CircleGroup) -> String {
        let otherMember = circle.members.first { $0.profileID != viewModel.currentUser.id && $0.status == .member }
        guard let otherID = otherMember?.profileID,
              let profile = viewModel.profile(for: otherID) else {
            return circle.name
        }
        return profile.displayName
    }

    @ViewBuilder
    private func membersView(for circle: CircleGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                membershipActions(for: circle)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Members")
                        .font(.headline)
                        .padding(.horizontal)
                    ForEach(memberProfiles, id: \.member.id) { entry in
                        HStack(spacing: 12) {
                            AvatarView(profile: entry.profile, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.profile.displayName)
                                    .font(.subheadline.weight(.semibold))
                                HStack {
                                    Text("@\(entry.profile.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(entry.member.status.rawValue.capitalized)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Remove") {
                                viewModel.removeMember(entry.profile, from: circle)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Add members")
                        .font(.headline)
                        .padding(.horizontal)
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search people to invite", text: $addMemberSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1.2)
                    )
                    .padding(.horizontal)
                    if !canInviteMembers {
                        Text("Only active members can invite others.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else if availableMembers.isEmpty {
                        if !addMemberSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("No matching profiles found.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    } else {
                        ForEach(availableMembers) { profile in
                            Button {
                                viewModel.addMember(profile, to: circle)
                            } label: {
                                HStack {
                                    AvatarView(profile: profile, size: 32)
                                    VStack(alignment: .leading) {
                                        Text(profile.displayName)
                                            .font(.subheadline.weight(.semibold))
                                        Text("@\(profile.username)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("Invite")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                if canDeleteCircle {
                    Button("Delete circle") {
                        viewModel.deleteCircle(circle)
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal)
                }

                if canInviteMembers {
                    Button("Clear chat") {
                        isClearChatConfirmationPresented = true
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal)
                }
            }
            .padding(.top, 16)
        }
        .confirmationDialog(
            "Clear chat?",
            isPresented: $isClearChatConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Clear chat", role: .destructive) {
                viewModel.clearCircleChat(circle)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes all messages in this circle for everyone.")
        }
    }

    @ViewBuilder
    private func membershipActions(for circle: CircleGroup) -> some View {
        switch currentMembership?.status {
        case .member:
            VStack(alignment: .leading, spacing: 10) {
                Text("You're an active member of this circle.")
                    .font(.subheadline)
                Button("Leave circle", role: .destructive) {
                    viewModel.leaveCircle(circle)
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        case .invited:
            HStack {
                Button("Accept invitation") {
                    viewModel.acceptInvitation(circle: circle)
                }
                Spacer()
                Button("Decline") {
                    viewModel.declineInvitation(circle: circle)
                }
                .foregroundColor(.secondary)
            }
        case .pending:
            HStack {
                Text("Join request pending")
                Spacer()
                Button("Cancel") {
                    viewModel.cancelJoinRequest(circle: circle)
                }
                .foregroundColor(.secondary)
            }
        case .declined:
            HStack {
                Text("Invitation declined")
                Spacer()
                Button("Request again") {
                    viewModel.requestJoin(circle: circle)
                }
            }
        case .none:
            Button("Request to join") {
                viewModel.requestJoin(circle: circle)
            }
        }
    }

    private func matchesAddMemberSearch(_ profile: UserProfile) -> Bool {
        let trimmed = addMemberSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return true }
        return profile.displayName.lowercased().contains(trimmed) ||
            profile.username.lowercased().contains(trimmed) ||
            profile.bio.lowercased().contains(trimmed)
    }

    private func refreshAddMemberSearchResults(for query: String) {
        addMemberSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            remoteAddMemberMatches = []
            return
        }
        addMemberSearchTask = Task {
            let remote = await viewModel.searchProfilesFromBackend(matching: trimmed)
                .filter(viewModel.canAddToCircleChats)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                remoteAddMemberMatches = remote
            }
        }
    }

    private func deduplicatedProfiles(_ source: [UserProfile]) -> [UserProfile] {
        var seen = Set<UUID>()
        let unique = source.filter { seen.insert($0.id).inserted }
        return unique.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

private enum CircleDetailTab: String, CaseIterable, Identifiable {
    case chat
    case members

    var id: Self { self }

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .members: return "Members"
        }
    }
}

@MainActor
private final class CircleVoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedSeconds = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var completion: ((URL, Int) -> Void)?
    private let maxSeconds = 120

    var elapsedText: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    func start(onComplete: ((URL, Int) -> Void)? = nil) {
        guard !isRecording else { return }
        completion = onComplete
        let handlePermission: @Sendable (Bool) -> Void = { [weak self] granted in
            guard granted else { return }
            Task { @MainActor [weak self] in
                self?.startRecording()
            }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: handlePermission)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(handlePermission)
        }
    }

    private func startRecording() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try AVAudioSession.sharedInstance().setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("scrolls-circle-voice-\(UUID().uuidString)")
                .appendingPathExtension("m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
                AVEncoderBitRateKey: 64_000
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.record(forDuration: TimeInterval(maxSeconds))
            self.recorder = recorder
            elapsedSeconds = 0
            isRecording = true
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.elapsedSeconds = min(self.elapsedSeconds + 1, self.maxSeconds)
                    if self.elapsedSeconds >= self.maxSeconds {
                        self.stop()
                    }
                }
            }
        } catch {
            isRecording = false
            recorder = nil
        }
    }

    func stop(onComplete: ((URL, Int) -> Void)? = nil) {
        guard let recorder else { return }
        let url = recorder.url
        let duration = max(1, min(maxSeconds, Int(ceil(recorder.currentTime))))
        let completion = onComplete ?? self.completion
        recorder.stop()
        timer?.invalidate()
        timer = nil
        self.recorder = nil
        self.completion = nil
        isRecording = false
        elapsedSeconds = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        if duration > 0 {
            completion?(url, duration)
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard flag else { return }
        Task { @MainActor in
            if self.isRecording {
                self.stop()
            }
        }
    }
}

private struct CircleChatPane: View {
    @EnvironmentObject private var viewModel: ScrollsFeedViewModel

    let circle: CircleGroup
    let currentUser: UserProfile
    let profileLookup: (UUID) -> UserProfile?
    let postLookup: (UUID) -> FeedPost?
    @Binding var messageDraft: String
    let sendMessage: (String) -> Void

    @State private var presentedSharedPost: FeedPost?
    @StateObject private var voiceRecorder = CircleVoiceRecorder()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoSendErrorMessage: String?
    @FocusState private var isComposerFocused: Bool

    private var isRateLimited: Bool {
        viewModel.isCircleMessageRateLimited(circleID: circle.id)
    }

    private var isDraftEmpty: Bool {
        messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var typingIndicatorID: String {
        "typing-\(circle.id.uuidString)"
    }

    private var bottomAnchorID: String {
        "circle-chat-bottom-\(circle.id.uuidString)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(circle.messages) { message in
                            let profile = profileLookup(message.userID) ?? currentUser
                            let sharedPost = message.sharedPostID.flatMap(postLookup)
                            CircleChatBubble(
                                message: message,
                                circleID: circle.id,
                                sender: profile,
                                isCurrentUser: message.userID == currentUser.id,
                                sharedPost: sharedPost,
                                onShareTap: {
                                    if let sharedPost {
                                        presentedSharedPost = sharedPost
                                    }
                                }
                            )
                            .id(message.id)
                        }
                        let typingParticipants = viewModel.typingParticipants(for: circle.id)
                        if !typingParticipants.isEmpty {
                            CircleTypingIndicatorBubble(participants: typingParticipants)
                                .id(typingIndicatorID)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture {
                    isComposerFocused = false
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: circle.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.typingParticipants(for: circle.id).count) { _, count in
                    guard count > 0 else { return }
                    withAnimation {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
                .onChange(of: isComposerFocused) { _, _ in
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    viewModel.startTypingPresence(for: circle.id)
                    // Land the chat at the bottom (most recent message) by
                    // default — matches the convention every messaging app
                    // uses.  Without this the LazyVStack starts at the top
                    // of the message history, forcing the user to scroll
                    // down to find their latest conversation.
                    //
                    // The scroll is done WITHOUT animation so it doesn't
                    // visibly fly from top to bottom; from the user's
                    // perspective the chat just opens at the latest
                    // message.  Wrapped in DispatchQueue.main.async so the
                    // LazyVStack has a chance to lay out its rows before
                    // we ask the proxy to scroll — calling scrollTo on
                    // a not-yet-laid-out LazyVStack is a no-op.
                    DispatchQueue.main.async {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
                .onDisappear {
                    viewModel.stopTypingPresence(for: circle.id)
                }
                .onChange(of: circle.id) { _, _ in
                    // Switching between circles (without unmounting the
                    // view) should also re-anchor to the bottom of the new
                    // circle's chat history.
                    DispatchQueue.main.async {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
            }

            Divider()

            VStack(spacing: 6) {
                if let photoSendErrorMessage {
                    Text(photoSendErrorMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 10) {
                    Button {
                        if voiceRecorder.isRecording {
                            voiceRecorder.stop()
                        } else {
                            voiceRecorder.start { url, duration in
                                viewModel.sendVoiceMessage(localURL: url, durationSeconds: duration, in: circle)
                            }
                        }
                    } label: {
                        Image(systemName: voiceRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.headline)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .tint(voiceRecorder.isRecording ? .red : .accentColor)
                    .disabled(isRateLimited)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "photo.fill")
                            .font(.headline)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                    .disabled(voiceRecorder.isRecording || isRateLimited)
                    TextField("Message the circle...", text: $messageDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(minHeight: 44)
                        .focused($isComposerFocused)
                        .onChange(of: messageDraft) { _, newValue in
                            let max = viewModel.circleMessageCharacterLimit
                            if newValue.count > max {
                                messageDraft = String(newValue.prefix(max))
                            }
                            let effectiveDraft = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.setTyping(!effectiveDraft.isEmpty, in: circle.id)
                        }
                    Button("Send") {
                        viewModel.setTyping(false, in: circle.id)
                        sendMessage(messageDraft)
                    }
                    .disabled(isDraftEmpty || isRateLimited)
                    .buttonStyle(.borderedProminent)
                }
                HStack {
                    Text("\(messageDraft.count)/\(viewModel.circleMessageCharacterLimit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    if voiceRecorder.isRecording {
                        Text("Voice \(voiceRecorder.elapsedText)/2:00")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    if isRateLimited {
                        Text("Rate limit reached, try again in a moment.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $presentedSharedPost) { post in
            SharedScrollDetailView(post: post)
                .environmentObject(viewModel)
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            photoSendErrorMessage = nil
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        await MainActor.run {
                            photoSendErrorMessage = "Could not load that photo."
                            selectedPhotoItem = nil
                        }
                        return
                    }
                    await MainActor.run {
                        viewModel.sendPhotoMessage(imageData: data, in: circle)
                        selectedPhotoItem = nil
                    }
                } catch {
                    await MainActor.run {
                        photoSendErrorMessage = "Could not load that photo."
                        selectedPhotoItem = nil
                    }
                }
            }
        }
    }
}

private struct CircleTypingIndicatorBubble: View {
    let participants: [TypingParticipant]

    @State private var isAnimating = false

    private var primaryParticipant: TypingParticipant? {
        participants.first
    }

    private var typingLabel: String {
        let names = participants.map(\.displayLabel).filter { !$0.isEmpty }
        switch names.count {
        case 0:
            return "Someone is typing"
        case 1:
            return "\(names[0]) is typing"
        case 2:
            return "\(names[0]) and \(names[1]) are typing"
        default:
            return "\(names[0]) and \(names.count - 1) others are typing"
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            CircleTypingAvatar(participant: primaryParticipant)

            VStack(alignment: .leading, spacing: 4) {
                Text(typingLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary.opacity(0.9))
                            .frame(width: 6, height: 6)
                            .scaleEffect(isAnimating ? 1 : 0.55)
                            .opacity(isAnimating ? 1 : 0.45)
                            .animation(
                                .easeInOut(duration: 0.55)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.16),
                                value: isAnimating
                            )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

private struct CircleTypingAvatar: View {
    let participant: TypingParticipant?

    private var initials: String {
        let label = participant?.displayLabel.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = label.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        if !letters.isEmpty {
            return String(letters).uppercased()
        }
        return "?"
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let avatarRef = participant?.avatarRef,
               let url = URL(string: avatarRef) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Text(initials)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                    }
                }
            } else {
                Text(initials)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

private struct CircleChatBubble: View {
    @EnvironmentObject private var viewModel: ScrollsFeedViewModel

    let message: CircleMessage
    let circleID: UUID
    let sender: UserProfile
    let isCurrentUser: Bool
    let sharedPost: FeedPost?
    let onShareTap: (() -> Void)?

    /// Drives the per-bubble "Report message" sheet.  Local to the
    /// bubble so the parent CircleDetailView doesn't need to track which
    /// message is being reported; the sheet self-dismisses on submit.
    @State private var isReportSheetPresented = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if !isCurrentUser {
                AvatarView(profile: sender, size: 28)
            }
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(sender.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                // Hide the text bubble entirely when the message is a pure
                // shared-scroll forward.  The SharedScrollPreview card carries
                // all the meaning — the cover, title, and author tag.  The
                // text bubble alongside it just exposes raw caption metadata
                // ("[MUSIC] Libertad [MUSIC_RELEASE_TYPE] singlesEPs
                // [MUSIC_TRACKS_BASE64]W3sid...") that's meant to be parsed
                // by the iOS client, not read by humans.  If the user ever
                // adds a personal note to a share (not currently supported,
                // but possible in the future), the text bubble will reappear
                // because the share-only sentinel won't match.
                let renderedText = message.text(for: circleID)
                let isPureShare = message.sharedPostID != nil
                    && SharedScrollMessageText.isShareOnlySentinel(renderedText)
                let isPhotoMessage = message.photoURL() != nil
                    || message.photoPreviewData != nil
                    || renderedText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(CircleMessage.photoPayloadPrefix)
                if isPhotoMessage {
                    CirclePhotoMessageBubble(
                        message: message,
                        isCurrentUser: isCurrentUser,
                        onViewed: {
                            viewModel.markCirclePhotoMessageViewed(message, in: circleID)
                        }
                    )
                } else if message.hasVoiceAttachment {
                    CircleVoiceMessageBubble(
                        message: message,
                        circleID: circleID,
                        isCurrentUser: isCurrentUser,
                        onCompleted: {
                            viewModel.markCircleVoiceMessageListened(message, in: circleID)
                        }
                    )
                } else if !isPureShare {
                    Text(renderedText)
                        .font(.body)
                        .foregroundColor(isCurrentUser ? Color.primary : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(bubbleColor)
                        )
                }
                if let sharedPost = sharedPost, let onShareTap {
                    Button {
                        onShareTap()
                    } label: {
                        SharedScrollPreview(post: sharedPost)
                    }
                    .buttonStyle(.plain)
                } else if isPureShare {
                    SharedScrollUnavailablePreview()
                }
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if isCurrentUser, let status = message.sendStatus {
                        sendStatusView(status)
                    }
                }
            }
            if isCurrentUser {
                AvatarView(profile: sender, size: 28)
            }
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        .contextMenu {
            // Authors can't report their own messages.  Anyone else can
            // long-press a message and route it to the safety queue.
            if !isCurrentUser {
                Button {
                    isReportSheetPresented = true
                } label: {
                    Label("Report message", systemImage: "flag")
                }
                if viewModel.canBlockProfile(sender) {
                    Button(role: .destructive) {
                        viewModel.blockUserProfile(sender)
                    } label: {
                        Label("Block @\(sender.username)", systemImage: "hand.raised")
                    }
                }
            }
        }
        .sheet(isPresented: $isReportSheetPresented) {
            let preview = message.hasPhotoAttachment
                ? "Photo message"
                : String(message.text(for: circleID).prefix(120))
            ReportContentSheet(
                targetType: message.hasVoiceAttachment ? .voiceMessage : .circleMessage,
                targetID: message.id,
                targetOwnerID: sender.id,
                targetTitle: preview,
                onSubmitted: {}
            )
            .environmentObject(viewModel)
        }
    }

    private var bubbleColor: Color {
        if isCurrentUser {
            if message.sendStatus == .failed {
                return Color.red.opacity(0.15)
            }
            return Color.accentColor.opacity(0.25)
        }
        return Color(.systemGray5)
    }

    @ViewBuilder
    private func sendStatusView(_ status: MessageSendStatus) -> some View {
        switch status {
        case .sending:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
        }
    }
}

private struct CirclePhotoMessageBubble: View {
    let message: CircleMessage
    let isCurrentUser: Bool
    let onViewed: () -> Void

    @State private var isPhotoPreviewPresented = false
    @State private var didDeletePhotoAfterPreview = false

    var body: some View {
        Group {
            if !isCurrentUser {
                Button {
                    guard message.photoURL() != nil else { return }
                    isPhotoPreviewPresented = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title3.weight(.semibold))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Photo message")
                                .font(.callout.weight(.semibold))
                            Text(message.photoURL() == nil ? "Preparing" : "Tap to view • Deletes after viewing")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemGray5))
                    )
                }
                .buttonStyle(.plain)
                .disabled(message.photoURL() == nil)
            } else {
                Button {
                    guard message.photoURL() != nil || previewImage != nil else { return }
                    isPhotoPreviewPresented = true
                } label: {
                    photoPreview
                }
                .buttonStyle(.plain)
            }
        }
        .fullScreenCover(isPresented: $isPhotoPreviewPresented, onDismiss: completePhotoPreviewIfNeeded) {
            CirclePhotoFullScreenPreview(
                url: message.photoURL(),
                previewData: message.photoPreviewData,
                isOutgoing: isCurrentUser
            )
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let previewImage {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                photoCaptionOverlay
            }
            .frame(width: photoBubbleSize.width, height: photoBubbleSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(isCurrentUser ? 0 : 0.16), lineWidth: 1)
            )
        } else if let url = message.photoURL() {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        Color.black.opacity(0.18)
                            .overlay(ProgressView().tint(.white))
                    default:
                        Color.black.opacity(0.35)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.75))
                            )
                    }
                }
                photoCaptionOverlay
            }
            .frame(width: photoBubbleSize.width, height: photoBubbleSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(isCurrentUser ? 0 : 0.16), lineWidth: 1)
            )
        } else {
            Text(isCurrentUser ? "Uploading photo message" : "Photo message")
                .font(.body)
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isCurrentUser ? Color.accentColor.opacity(0.25) : Color(.systemGray5))
                )
        }
    }

    @ViewBuilder
    private var photoCaptionOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Photo message")
                .font(.caption.weight(.semibold))
            Text(isCurrentUser ? "Tap to preview • Deletes in 24h or after recipient views" : "Deletes after viewing")
                .font(.caption2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.5), in: Capsule(style: .continuous))
        .padding(8)
    }

    private var previewImage: UIImage? {
        guard let data = message.photoPreviewData else { return nil }
        return UIImage(data: data)
    }

    private var photoBubbleSize: CGSize {
        let maxWidth: CGFloat = 230
        let maxHeight: CGFloat = 300
        guard let width = message.photoWidth,
              let height = message.photoHeight,
              width > 0,
              height > 0 else {
            return CGSize(width: 210, height: 250)
        }
        let ratio = CGFloat(width) / CGFloat(height)
        if ratio >= 1 {
            return CGSize(width: maxWidth, height: max(130, maxWidth / ratio))
        }
        let resolvedHeight = min(maxHeight, max(180, maxWidth / ratio))
        return CGSize(width: max(160, resolvedHeight * ratio), height: resolvedHeight)
    }

    private func completePhotoPreviewIfNeeded() {
        guard !isCurrentUser, message.photoURL() != nil, !didDeletePhotoAfterPreview else { return }
        didDeletePhotoAfterPreview = true
        onViewed()
    }
}

private struct CirclePhotoFullScreenPreview: View {
    let url: URL?
    let previewData: Data?
    let isOutgoing: Bool

    @Environment(\.dismiss) private var dismiss

    private var previewImage: UIImage? {
        guard let previewData else { return nil }
        return UIImage(data: previewData)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .ignoresSafeArea()
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    default:
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("Couldn't load this photo")
                                .font(.headline)
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("Photo is still uploading")
                        .font(.headline)
                }
                .foregroundColor(.white.opacity(0.8))
            }

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Photo message")
                            .font(.headline.weight(.semibold))
                        Text(isOutgoing ? "Only you can preview your sent photo here." : "Deletes after you close this preview.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                Spacer()
            }
        }
    }
}

private struct CircleVoiceMessageBubble: View {
    let message: CircleMessage
    let circleID: UUID
    let isCurrentUser: Bool
    let onCompleted: () -> Void

    @StateObject private var player = CircleVoicePlayer()

    private var durationText: String {
        let seconds = max(1, message.voiceDurationSeconds(for: circleID) ?? 1)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        Button {
            guard let url = message.voiceURL(for: circleID) else { return }
            player.toggle(url: url, onCompleted: onCompleted)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(message.voiceURL(for: circleID) == nil ? "Uploading voice message" : "Voice message")
                        .font(.callout.weight(.semibold))
                    Text(message.voiceURL(for: circleID) == nil ? "Preparing" : "Deletes after listening • \(durationText)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Image(systemName: "waveform")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isCurrentUser ? Color.accentColor.opacity(0.25) : Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
        .disabled(message.voiceURL(for: circleID) == nil)
    }
}

@MainActor
private final class CircleVoicePlayer: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false

    /// AVPlayer (not AVAudioPlayer) — handles both local file URLs AND
    /// remote HTTPS streams.  Voice messages stored on R2 come back as
    /// remote URLs; AVAudioPlayer.init(contentsOf:) only supports local
    /// files, so the previous implementation silently threw and the
    /// playback button became a dead no-op for every circle voice
    /// message stored on the CDN.
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var onCompleted: (() -> Void)?

    func toggle(url: URL, onCompleted: @escaping () -> Void) {
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }
        do {
            // Configure the audio session so we play through the loud
            // speaker even when the device is silenced — voice messages
            // are intentional interactions, not background sound.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Session config failures shouldn't kill the playback
            // attempt — AVPlayer will still try to play through
            // whatever route is available.  Log via debug trail so
            // we can spot pattern failures.
            UserDefaults.standard.set(
                "circle_voice_session_setup_failed: \(error.localizedDescription)",
                forKey: "scrolls.debug.circleVoicePlaybackFailure"
            )
        }

        self.onCompleted = onCompleted
        teardownObservers()

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = false

        // End-of-playback observer — fires when the item finishes
        // naturally.  We use the per-item notification rather than the
        // generic name so we don't accidentally react to other AVPlayer
        // instances in the app (e.g. the video feed players).
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePlaybackFinished()
            }
        }

        // KVO on item.status — surfaces .failed states (404, codec
        // errors, etc.) so the UI doesn't silently sit on isPlaying=true
        // when the stream never starts.
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .failed:
                    UserDefaults.standard.set(
                        "circle_voice_item_failed: \(item.error?.localizedDescription ?? "unknown") url=\(url.absoluteString)",
                        forKey: "scrolls.debug.circleVoicePlaybackFailure"
                    )
                    self.isPlaying = false
                    self.teardownObservers()
                    self.player = nil
                default:
                    break
                }
            }
        }

        self.player = newPlayer
        newPlayer.play()
        isPlaying = true
    }

    private func handlePlaybackFinished() {
        isPlaying = false
        teardownObservers()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        onCompleted?()
        onCompleted = nil
    }

    private func teardownObservers() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        statusObservation?.invalidate()
    }
}

private struct SharedScrollUnavailablePreview: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemFill))
                Image(systemName: "text.alignleft")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 2) {
                Text("Shared Scroll")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text("Loading")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

private struct SharedScrollPreview: View {
    let post: FeedPost

    var body: some View {
        HStack(spacing: 12) {
            SharedScrollThumbnail(post: post)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(sharedScrollPreviewTitle(for: post))
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                Text("@\(post.user.username)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    /// Human-friendly title for a shared scroll preview.  Prefers a clean
    /// display caption (which strips the `[MUSIC]`/`[PODCAST]`/`[ARTICLE]`
    /// machine prefix + base64 track payload from the raw caption) so we
    /// don't expose iOS-side parser metadata in the chat card.
    private func sharedScrollPreviewTitle(for post: FeedPost) -> String {
        if let display = post.displayCaption?.trimmingCharacters(in: .whitespacesAndNewlines),
           !display.isEmpty {
            return display
        }
        if let text = post.mediaPreview.textPreview?.text.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }
        return "Shared Scroll"
    }
}

/// Thumbnail for shared-scroll cards in circle messages.  Replaces the old
/// `MediaPreviewThumbnail` which only inspected `mediaPreview` and gave up
/// to a grey square if the in-memory `platformImage` wasn't present.  This
/// version inspects the full FeedPost so it can resolve:
///   • the explicit cover ref (podcasts, music, articles)
///   • the photo remote URL (photo posts that aren't pre-loaded into memory)
///   • the video poster frame (video posts without an explicit cover)
///   • the text body (text-only posts)
/// and loads via `FeedMediaPrefetcher` for caching consistency with the
/// rest of the app.  Falls back to a typed icon-on-grey placeholder ONLY
/// when none of the above produce an image.
private struct SharedScrollThumbnail: View {
    let post: FeedPost
    @State private var loadedImage: PlatformImage?

    var body: some View {
        ZStack {
            // Placeholder: typed icon on grey, replaced when the real image
            // arrives.  For text-only posts where there's no image to load,
            // this placeholder is the final render.
            placeholderView

            if let loadedImage {
                Image(platformImage: loadedImage)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: thumbnailLoadKey) {
            await loadThumbnail()
        }
    }

    /// Stable identity for the thumbnail load — re-fires the loader when
    /// the post identity changes (rare in chat history, but covers the
    /// case where a SharedScrollPreview gets reused for a different post
    /// in a List/LazyVStack diff).
    private var thumbnailLoadKey: String {
        post.id.uuidString
    }

    @ViewBuilder
    private var placeholderView: some View {
        switch post.mediaPreview {
        case .photo:
            Color(.secondarySystemFill)
        case .video:
            ZStack {
                Color(.secondarySystemFill)
                Image(systemName: post.isAudioPost ? "music.note" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
            }
        case .text(let text):
            ZStack(alignment: .center) {
                Color(.secondarySystemFill)
                if post.isArticle {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    Text(text.text)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary.opacity(0.8))
                        .padding(6)
                }
            }
        }
    }

    @MainActor
    private func loadThumbnail() async {
        // Skip the load entirely for text posts that aren't articles — the
        // placeholder IS the final render.
        if case .text = post.mediaPreview, !post.isArticle {
            return
        }
        // 1. Explicit cover image (podcast, music, article with cover).
        //    This is the highest-fidelity option and what the user expects
        //    to see for these post types.
        if let coverURL = post.podcastCoverImageURL {
            if let image = await FeedMediaPrefetcher.shared.thumbnail(for: coverURL, maxPixel: 200) {
                loadedImage = image
                return
            }
        }
        // 2. Photo post — the preview's fileURL.
        if case let .photo(photo) = post.mediaPreview {
            // Use the in-memory platformImage when present (avoids a network
            // roundtrip for photos the user just posted).
            if let inMemory = photo.platformImage {
                loadedImage = inMemory
                return
            }
            if let image = await FeedMediaPrefetcher.shared.thumbnail(for: photo.fileURL, maxPixel: 200) {
                loadedImage = image
                return
            }
        }
        // 3. Video post without an explicit cover — synthesize a poster
        //    frame from the video.  This covers regular video posts that
        //    aren't podcasts/music.
        if case let .video(video) = post.mediaPreview {
            if let poster = await FeedMediaPrefetcher.shared.videoPoster(for: video.url) {
                loadedImage = poster
                return
            }
        }
        // Nothing loaded — placeholder stays.
    }
}

struct CirclesIconView: View {
    let badgeCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.6), lineWidth: 1.2)
                    .frame(width: 16, height: 16)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.6), lineWidth: 1.2)
                    .frame(width: 16, height: 16)
                    .offset(x: 6, y: 0)
                Circle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 16, height: 16)
                    .offset(x: 3, y: 0)
            }
            .frame(width: 22, height: 18)
            if badgeCount > 0 {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Text("\(min(badgeCount, 9))")
                            .font(.system(size: 7).weight(.bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 6, y: -5)
            }
        }
    }
}

private struct SharedScrollDetailView: View {
    let post: FeedPost

    var body: some View {
        ScrollView {
            FeedPostRow(post: post)
                .padding(.horizontal)
                .padding(.top)
        }
        .navigationTitle("Shared Scroll")
        .navigationBarTitleDisplayMode(.inline)
    }
}
