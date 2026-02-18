import SwiftUI

/// SwiftUI view for managing the application ignore list.
struct IgnoreListView: View {
    @State private var ignoredApps: [IgnoredApp] = []
    @State private var suggestedApps: [SuggestedApp] = []
    @State private var isShowingAddSheet = false
    @State private var customBundleId = ""

    let ignoreListManager: IgnoreListManager
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ignoredAppsSection
                    suggestedAppsSection
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 500)
        .task {
            await loadApps()
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text("Privacy Settings")
                .font(.headline)
            Spacer()
            Button("Done") {
                onClose()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    // MARK: - Ignored Apps Section
    private var ignoredAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ignored Applications")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Clips from these applications will not be captured.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if ignoredApps.isEmpty {
                emptyStateView
            } else {
                ignoredAppsList
            }

            // Add custom app button
            Button(action: { isShowingAddSheet = true }) {
                Label("Add Application...", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .sheet(isPresented: $isShowingAddSheet) {
                AddAppSheet(
                    isPresented: $isShowingAddSheet,
                    ignoreListManager: ignoreListManager
                ) {
                    Task {
                        await loadApps()
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No applications ignored")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Add password managers or other sensitive applications.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private var ignoredAppsList: some View {
        VStack(spacing: 1) {
            ForEach(ignoredApps) { app in
                IgnoredAppRow(app: app) {
                    Task {
                        await removeApp(app)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Suggested Apps Section

    private var suggestedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Password Managers")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Common password managers that you may want to ignore.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if suggestedApps.isEmpty {
                Text("No password managers detected on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
            } else {
                suggestedAppsList
            }
        }
    }

    private var suggestedAppsList: some View {
        VStack(spacing: 1) {
            ForEach(suggestedApps.filter { !$0.isInstalled }) { app in
                SuggestedAppRow(app: app) {
                    Task {
                        await addSuggestedApp(app)
                    }
                }
            }
            // Show installed apps that aren't already ignored
            ForEach(suggestedApps.filter { $0.isInstalled && !isIgnored($0) }) { app in
                SuggestedAppRow(app: app) {
                    Task {
                        await addSuggestedApp(app)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Helpers

    private func loadApps() async {
        ignoredApps = await ignoreListManager.getIgnoredApps()
        suggestedApps = await ignoreListManager.getAllSuggestedPasswordManagers()
    }

    private func removeApp(_ app: IgnoredApp) async {
        await ignoreListManager.removeBundleIdentifier(app.bundleIdentifier)
        await loadApps()
    }

    private func addSuggestedApp(_ app: SuggestedApp) async {
        await ignoreListManager.addBundleIdentifier(app.bundleIdentifier)
        await loadApps()
    }

    private func isIgnored(_ app: SuggestedApp) -> Bool {
        ignoredApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
    }
}

// MARK: - Ignored App Row

struct IgnoredAppRow: View {
    let app: IgnoredApp
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }

            // App info
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Remove from ignore list")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
}

// MARK: - Suggested App Row

struct SuggestedAppRow: View {
    let app: SuggestedApp
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }

            // App info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.body)
                    if !app.isInstalled {
                        Text("Not installed")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary)
                            .cornerRadius(4)
                    }
                }
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Add button
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .help("Add to ignore list")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
}

// MARK: - Add App Sheet

struct AddAppSheet: View {
    @State private var customBundleId = ""
    @State private var availableApps: [IgnoredApp] = []
    @Binding var isPresented: Bool

    let ignoreListManager: IgnoreListManager
    let onAdded: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Application to Ignore List")
                .font(.headline)

            // Running applications
            VStack(alignment: .leading, spacing: 8) {
                Text("Running Applications")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(availableApps) { app in
                            HStack {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                }
                                Text(app.name)
                                    .font(.body)
                                Spacer()
                                Button("Add") {
                                    Task {
                                        await addApp(app)
                                    }
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }

            // Custom bundle ID
            VStack(alignment: .leading, spacing: 8) {
                Text("Or enter bundle identifier manually:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("com.example.app", text: $customBundleId)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        Task {
                            await addCustomBundleId()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(customBundleId.isEmpty)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 400)
        .task {
            await loadRunningApps()
        }
    }

    private func loadRunningApps() async {
        let runningApps = NSWorkspace.shared.runningApplications
        let ignoredBundleIds = await ignoreListManager.getIgnoredBundleIdentifiers()

        availableApps = runningApps.compactMap { app -> IgnoredApp? in
            guard let bundleId = app.bundleIdentifier,
                  app.activationPolicy == .regular, // Only show regular apps
                  !ignoredBundleIds.contains(bundleId)
            else { return nil }

            let icon = app.icon
            let name = app.localizedName ?? bundleId

            return IgnoredApp(bundleIdentifier: bundleId, name: name, icon: icon)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func addApp(_ app: IgnoredApp) async {
        await ignoreListManager.addBundleIdentifier(app.bundleIdentifier)
        await loadRunningApps()
        onAdded()
    }

    private func addCustomBundleId() async {
        let trimmed = customBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await ignoreListManager.addBundleIdentifier(trimmed)
        customBundleId = ""
        onAdded()
    }
}
