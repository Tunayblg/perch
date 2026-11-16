import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Dosya rafı: dosyaları buraya bırak, sonra başka yere sürükle.
struct ShelfPanel: View {
    @ObservedObject var store: ShelfStore
    @State private var targeted = false

    var body: some View {
        HStack(spacing: 10) {
            airDropTile
                .frame(width: 96)
            shelfZone
        }
    }

    // MARK: - AirDrop

    @State private var airDropTargeted = false

    private var airDropTile: some View {
        VStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 26))
                .foregroundStyle(.white.opacity(airDropTargeted ? 1 : 0.7))
            Text("AirDrop")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(airDropTargeted ? 1 : 0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(airDropTargeted ? 0.22 : 0.1))
        )
        .onDrop(of: [.fileURL], isTargeted: $airDropTargeted) { providers in
            Self.loadURLs(from: providers) { urls in Self.sendViaAirDrop(urls) }
            return true
        }
    }

    private static func sendViaAirDrop(_ urls: [URL]) {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
    }

    // MARK: - Raf

    private var shelfZone: some View {
        ZStack {
            if store.items.isEmpty {
                empty
            } else {
                VStack(spacing: 6) {
                    HStack {
                        Text(L("\(store.items.count) dosya", "\(store.items.count) files"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Button(L("Temizle", "Clear")) { store.clear() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(store.items) { item in
                                tile(item)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(targeted ? Color.white.opacity(0.12) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(targeted ? 0.6 : 0), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .onDrop(of: [.fileURL], isTargeted: $targeted, perform: handleDrop)
        .onAppear { store.pruneMissing() }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.5))
            Text(L("Dosyaları buraya bırak", "Drop files here"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }

    private func tile(_ item: ShelfItem) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 3) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .frame(width: 44, height: 44)
                Text(item.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
            }
            .frame(width: 70)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
            .onDrag { NSItemProvider(object: item.url as NSURL) }

            Button { store.remove(item.id) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .help(item.url.path)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        Self.loadURLs(from: providers) { urls in store.add(urls) }
        return true
    }

    /// Bırakılan sağlayıcılardan dosya adreslerini toplar, hepsi hazır olunca ana kuyrukta döner.
    private static func loadURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                var url: URL?
                if let d = data as? Data { url = URL(dataRepresentation: d, relativeTo: nil) }
                else if let u = data as? URL { url = u }
                if let url { lock.lock(); urls.append(url); lock.unlock() }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(urls) }
    }
}
