import SwiftUI

struct TodoPanel: View {
    @ObservedObject var store: TodoStore
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 8) {
            inputRow
            if store.items.isEmpty {
                Spacer()
                Text(L("Hiç görev yok. Yukarıdan ekle.", "No tasks yet. Add one above."))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(store.sorted) { item in
                            row(item)
                        }
                    }
                }
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.white.opacity(0.5))
            TextField("", text: $draft,
                      prompt: Text(L("Görev ekle…", "Add a task…")).foregroundStyle(.white.opacity(0.4)))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .onSubmit {
                    store.add(draft)
                    draft = ""
                }
            if store.items.contains(where: { $0.done }) {
                Button(L("Temizle", "Clear")) { store.clearDone() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text("\(store.openCount)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func row(_ item: TodoItem) -> some View {
        HStack(spacing: 8) {
            Button { store.toggle(item.id) } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(item.done ? Color.green : .white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 13))
                .strikethrough(item.done)
                .foregroundStyle(.white.opacity(item.done ? 0.35 : 0.95))
                .lineLimit(1)
            Spacer(minLength: 0)
            Button { store.remove(item.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
    }
}
