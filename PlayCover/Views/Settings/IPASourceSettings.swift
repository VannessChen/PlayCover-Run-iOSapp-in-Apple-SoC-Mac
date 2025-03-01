//
//  IPASourceSettings.swift
//  PlayCover
//
//  Created by Isaac Marovitz on 20/09/2022.
//

import SwiftUI

struct SourceData: Identifiable, Hashable {
    var id: UUID
    var source: String
    var status: SourceValidation
    var isEnabled: Bool

}

extension SourceData: Codable {
    init(source: String, isEnabled: Bool) {
        self.id = UUID()
        self.source = source
        self.status = .checking
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            source: try container.decode(String.self, forKey: .source),
            status: .checking,
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        )
    }
}

struct IPASourceSettings: View {
    @State var selected = Set<UUID>()
    @State var selectedNotEmpty = false
    @State var addSourceSheet = false
    @State var triggerUpdate = false
    @EnvironmentObject var storeVM: StoreVM

    var body: some View {
        Form {
            HStack {
                List(storeVM.sourcesList, id: \.id, selection: $selected) { source in
                    SourceView(source: source,
                               isEnabled: source.isEnabled)
                }
                .listStyle(.bordered(alternatesRowBackgrounds: true))
                Spacer()
                    .frame(width: 20)
                VStack {
                    Button {
                        addSourceSheet.toggle()
                    } label: {
                        Text("preferences.button.addSource")
                            .frame(width: 130)
                    }
                    Button {
                        storeVM.deleteSource(&selected)
                    } label: {
                        Text("preferences.button.deleteSource")
                            .frame(width: 130)
                    }
                    .disabled(!selectedNotEmpty)
                    Spacer()
                        .frame(height: 20)
                    Button {
                        storeVM.moveSourceUp(&selected)
                    } label: {
                        Text("preferences.button.moveSourceUp")
                            .frame(width: 130)
                    }
                    .disabled(!selectedNotEmpty)
                    Button {
                        storeVM.moveSourceDown(&selected)
                    } label: {
                        Text("preferences.button.moveSourceDown")
                            .frame(width: 130)
                    }
                    .disabled(!selectedNotEmpty)
                    Spacer()
                        .frame(height: 20)
                    Button {
                        storeVM.resolveSources()
                    } label: {
                        Text("playapp.refreshSources")
                            .frame(width: 130)
                    }
                }
            }
        }
        .onChange(of: selected) { data in
            selectedNotEmpty = data.count > 0
        }
        .padding(20)
        .frame(width: 600, height: 300, alignment: .center)
        .sheet(isPresented: $addSourceSheet) {
            AddSourceView(addSourceSheet: $addSourceSheet)
                .environmentObject(storeVM)
        }
    }
}

struct SourceView: View {
    var source: SourceData
    @State var isEnabled: Bool
    @State var showingPopover = false

    var body: some View {
        HStack {
            Toggle(source.source, isOn: $isEnabled)
            .foregroundStyle(isEnabled ? .primary : .secondary)
            .help("state.enabled")
            Spacer()
            switch source.status {
            case .badjson:
                StatusBadgeView(imageName: "xmark.circle.fill",
                                imageColor: .red,
                                popoverText: "preferences.popover.badjson",
                                showingPopover: $showingPopover)
            case .badurl:
                StatusBadgeView(imageName: "xmark.circle.fill",
                                imageColor: .red,
                                popoverText: "preferences.popover.badurl",
                                showingPopover: $showingPopover)
            case .checking:
                StatusBadgeView(imageName: "exclamationmark.circle.fill",
                                imageColor: .yellow,
                                popoverText: "preferences.popover.checking",
                                showingPopover: $showingPopover)
            case .duplicate:
                StatusBadgeView(imageName: "exclamationmark.circle.fill",
                                imageColor: .yellow,
                                popoverText: "preferences.popover.duplicate",
                                showingPopover: $showingPopover)
            case .empty:
                EmptyView()
            case .valid:
                if isEnabled {
                    StatusBadgeView(imageName: "checkmark.circle.fill",
                                    imageColor: .green,
                                    popoverText: "preferences.popover.valid",
                                    showingPopover: $showingPopover)
                } else {
                    StatusBadgeView(imageName: "checkmark.circle.badge.xmark.fill",
                                    imageColor: .gray,
                                    popoverText: "state.disabled",
                                    showingPopover: $showingPopover)
                }
            }
        }
        .onChange(of: isEnabled) { value in
            StoreVM.shared.enableSourceToggle(source: source, value: value)
            StoreVM.shared.updateSourcesApps()
        }
    }
}

struct StatusBadgeView: View {
    var imageName: String
    var imageColor: Color
    var popoverText: String
    @Binding var showingPopover: Bool

    var body: some View {
        Button {
            showingPopover.toggle()
        } label: {
            Image(systemName: imageName)
                .foregroundColor(imageColor)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover) {
            Text(NSLocalizedString(popoverText, comment: ""))
                .padding(10)
        }
    }
}

enum SourceValidation: Codable {
    case badjson, badurl, checking, duplicate, valid, empty
}

struct AddSourceView: View {
    @State var newSource = ""
    @State var newSourceURL: URL?
    @State var sourceValidationState = SourceValidation.empty
    @Binding var addSourceSheet: Bool
    @EnvironmentObject var storeVM: StoreVM

    @State var checkTask: Task<Void, Error>?
    @State var urlSessionTask: URLSessionTask?

    var body: some View {
        VStack {
            TextField(text: $newSource, label: {Text("preferences.textfield.url")})
            Spacer()
                .frame(height: 20)
            HStack {
                switch sourceValidationState {
                case .badjson:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("preferences.popover.badjson")
                        .font(.system(.subheadline))
                case .badurl:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("preferences.popover.badurl")
                        .font(.system(.subheadline))
                case .checking:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.yellow)
                    Text("preferences.popover.checking")
                        .font(.system(.subheadline))
                case .duplicate:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.yellow)
                    Text("preferences.popover.duplicate")
                        .font(.system(.subheadline))
                case .empty:
                    EmptyView()
                case .valid:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("preferences.popover.valid")
                        .font(.system(.subheadline))
                }
                Spacer()
                Button {
                    addSourceSheet.toggle()
                } label: {
                    Text("button.Cancel")
                }
                Button {
                    if let sourceURL = newSourceURL?.absoluteString {
                        storeVM.addSource(SourceData(source: sourceURL, isEnabled: true))
                        addSourceSheet.toggle()
                    }
                } label: {
                    Text("button.OK")
                }
                .tint(.accentColor)
                .keyboardShortcut(.defaultAction)
                .disabled(![.valid, .duplicate].contains(sourceValidationState))
            }
        }
        .padding()
        .frame(width: 400, height: 100)
        .onChange(of: newSource) { source in
            if let task = checkTask, !task.isCancelled {
                if let session = urlSessionTask {
                    session.cancel()
                }

                task.cancel()
            }
            validateSource(source)
        }
        .onAppear {
            if URLObservable.shared.type == .source {
                newSource = URLObservable.shared.url ?? ""
            }
        }
        .onDisappear {
            URLObservable.shared.url = nil
            URLObservable.shared.type = nil
            URLObservable.shared.action = nil
        }
    }

    func validateSource(_ source: String) {
        guard NetworkVM.isConnectedToNetwork() else { return }

        sourceValidationState = .empty

        checkTask = Task {
            if var url = URL(string: source) {
                if url.scheme == nil {
                    url = URL(string: "https://" + url.absoluteString) ?? url
                }

                newSourceURL = url
                urlSessionTask = URLSession.shared.dataTask(with: URLRequest(url: url)) { jsonData, response, error in
                    guard error == nil,
                          ((response as? HTTPURLResponse)?.statusCode ?? 200) == 200,
                          let jsonData = jsonData else {
                        Task { @MainActor in
                            self.sourceValidationState = .badurl
                        }
                        return
                    }

                    do {
                        let _: SourceJSON = try JSONDecoder().decode(SourceJSON.self, from: jsonData)
                        Task { @MainActor in
                            sourceValidationState = storeVM.sourcesList.filter {
                                $0.source == source
                            }.isEmpty ? .valid : .duplicate
                        }
                    } catch {
                        do {
                            let data: [SourceAppsData] = try JSONDecoder().decode([SourceAppsData].self, from: jsonData)
                            if data.count > 0 {
                                Task { @MainActor in
                                    sourceValidationState = storeVM.sourcesList.filter {
                                        $0.source == source
                                    }.isEmpty ? .valid : .duplicate
                                }
                            }
                        } catch {
                            Task { @MainActor in
                                self.sourceValidationState = .badjson
                            }
                        }
                    }
                }

                urlSessionTask?.resume()
                sourceValidationState = .checking
                return
            }
            Task { @MainActor in
                self.sourceValidationState = .badurl
            }
        }
    }
}

struct IPASourceSettings_Previews: PreviewProvider {
    static var previews: some View {
        IPASourceSettings()
    }
}
