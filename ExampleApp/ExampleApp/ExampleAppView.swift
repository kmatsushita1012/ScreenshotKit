import SwiftUI

struct ExampleAppView: View {
    @State private var memos = Memo.sampleNotebook
    @State private var selectedMemoID = Memo.sampleNotebook.first?.id

    private var selectedMemoIndex: Int? {
        guard let selectedMemoID else { return nil }
        return memos.firstIndex { $0.id == selectedMemoID }
    }

    var body: some View {
        NavigationSplitView {
            MemoListView(
                memos: memos,
                selectedMemoID: $selectedMemoID,
                onCreateMemo: addMemo
            )
        } detail: {
            if let selectedMemoIndex {
                MemoEditView(memo: $memos[selectedMemoIndex])
            } else {
                ContentUnavailableView(
                    "empty.selectMemo.title",
                    systemImage: "note.text",
                    description: Text("empty.selectMemo.description")
                )
            }
        }
    }

    private func addMemo() {
        let newMemo = Memo(
            title: String(localized: "memo.new.title"),
            body: "",
            category: String(localized: "memo.new.category"),
            updatedAt: .now,
            isPinned: false
        )
        memos.insert(newMemo, at: 0)
        selectedMemoID = newMemo.id
    }
}

struct MemoListView: View {
    let memos: [Memo]
    private let selectedMemoID: Binding<Memo.ID?>?
    private let onCreateMemo: (() -> Void)?

    init(memos: [Memo]) {
        self.memos = memos
        self.selectedMemoID = nil
        self.onCreateMemo = nil
    }

    init(
        memos: [Memo],
        selectedMemoID: Binding<Memo.ID?>,
        onCreateMemo: (() -> Void)? = nil
    ) {
        self.memos = memos
        self.selectedMemoID = selectedMemoID
        self.onCreateMemo = onCreateMemo
    }

    private var pinnedMemos: [Memo] {
        memos.filter(\.isPinned)
    }

    private var otherMemos: [Memo] {
        memos.filter { !$0.isPinned }
    }

    var body: some View {
        Group {
            if let selectedMemoID {
                List(selection: selectedMemoID) {
                    memoSections
                }
            } else {
                List {
                    memoSections
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("memo.list.navigationTitle"))
        .toolbar {
            if let onCreateMemo {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onCreateMemo) {
                        Label("memo.new.button", systemImage: "square.and.pencil")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var memoSections: some View {
        if !pinnedMemos.isEmpty {
            Section("memo.section.pinned") {
                ForEach(pinnedMemos) { memo in
                    MemoRow(memo: memo)
                        .tag(memo.id)
                }
            }
        }

        Section("memo.section.allNotes") {
            ForEach(otherMemos) { memo in
                MemoRow(memo: memo)
                    .tag(memo.id)
            }
        }
    }
}

struct MemoEditView: View {
    @Environment(\.locale) private var locale
    private let memoBinding: Binding<Memo>?
    @State private var localMemo: Memo

    init(memo: Memo) {
        self.memoBinding = nil
        _localMemo = State(initialValue: memo)
    }

    init(memo: Binding<Memo>) {
        self.memoBinding = memo
        _localMemo = State(initialValue: memo.wrappedValue)
    }

    private var draft: Binding<Memo> {
        memoBinding ?? $localMemo
    }

    var body: some View {
        Form {
            Section("memo.edit.section.details") {
                TextField("memo.edit.field.title", text: draft.title)
                    .font(.title2.weight(.semibold))
                TextField("memo.edit.field.category", text: draft.category)
                Toggle("memo.edit.field.pinned", isOn: draft.isPinned)
            }

            Section("memo.edit.section.content") {
                TextEditor(text: draft.body)
                    .frame(minHeight: 260)
            }

            Section("memo.edit.section.status") {
                LabeledContent("memo.edit.status.lastEdited") {
                    Text(
                        draft.wrappedValue.updatedAt.formatted(
                            Date.FormatStyle(date: .abbreviated, time: .shortened)
                                .locale(locale)
                        )
                    )
                        .foregroundStyle(.secondary)
                }
                LabeledContent("memo.edit.status.words") {
                    Text("\(draft.wrappedValue.wordCount)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(draft.wrappedValue.title.isEmpty ? Text("memo.edit.untitled") : Text(verbatim: draft.wrappedValue.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("memo.edit.done") {}
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: draft.wrappedValue.title) { _, _ in
            touchUpdatedAt()
        }
        .onChange(of: draft.wrappedValue.body) { _, _ in
            touchUpdatedAt()
        }
        .onChange(of: draft.wrappedValue.category) { _, _ in
            touchUpdatedAt()
        }
        .onChange(of: draft.wrappedValue.isPinned) { _, _ in
            touchUpdatedAt()
        }
    }

    private func touchUpdatedAt() {
        draft.updatedAt.wrappedValue = .now
    }
}

private struct MemoRow: View {
    let memo: Memo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(memo.title)
                    .font(.headline)
                    .lineLimit(1)
                if memo.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(memo.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(memo.bodyPreview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(memo.category)
                .font(.caption.weight(.medium))
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 4)
    }
}

struct Memo: Identifiable, Hashable {
    let id: UUID
    var title: String
    var body: String
    var category: String
    var updatedAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        category: String,
        updatedAt: Date,
        isPinned: Bool
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }

    var bodyPreview: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "memo.preview.empty") : trimmed
    }

    var wordCount: Int {
        body.split { $0.isWhitespace || $0.isNewline }.count
    }
}

extension Memo {
    static let sampleNotebook: [Memo] = [
        Memo(
            title: String(localized: "memo.sample.releaseChecklist.title"),
            body: String(localized: "memo.sample.releaseChecklist.body"),
            category: String(localized: "memo.sample.releaseChecklist.category"),
            updatedAt: .now.addingTimeInterval(-2_700),
            isPinned: true
        ),
        Memo(
            title: String(localized: "memo.sample.weekendGroceries.title"),
            body: String(localized: "memo.sample.weekendGroceries.body"),
            category: String(localized: "memo.sample.weekendGroceries.category"),
            updatedAt: .now.addingTimeInterval(-18_000),
            isPinned: true
        ),
        Memo(
            title: String(localized: "memo.sample.designNotes.title"),
            body: String(localized: "memo.sample.designNotes.body"),
            category: String(localized: "memo.sample.designNotes.category"),
            updatedAt: .now.addingTimeInterval(-82_000),
            isPinned: false
        ),
        Memo(
            title: String(localized: "memo.sample.travelPlan.title"),
            body: String(localized: "memo.sample.travelPlan.body"),
            category: String(localized: "memo.sample.travelPlan.category"),
            updatedAt: .now.addingTimeInterval(-172_000),
            isPinned: false
        )
    ]

    static let screenshotList: [Memo] = [
        Memo(
            title: String(localized: "memo.sample.releaseChecklist.title"),
            body: String(localized: "memo.sample.releaseChecklist.body"),
            category: String(localized: "memo.sample.releaseChecklist.category"),
            updatedAt: .now.addingTimeInterval(-2_700),
            isPinned: true
        ),
        Memo(
            title: String(localized: "memo.sample.designNotes.title"),
            body: String(localized: "memo.sample.designNotes.body"),
            category: String(localized: "memo.sample.designNotes.category"),
            updatedAt: .now.addingTimeInterval(-82_000),
            isPinned: false
        ),
        Memo(
            title: String(localized: "memo.sample.travelPlan.title"),
            body: String(localized: "memo.sample.travelPlan.body"),
            category: String(localized: "memo.sample.travelPlan.category"),
            updatedAt: .now.addingTimeInterval(-172_000),
            isPinned: false
        )
    ]

    static let screenshotDraft = Memo(
        title: String(localized: "memo.sample.releaseChecklist.title"),
        body: String(localized: "memo.sample.releaseChecklist.body"),
        category: String(localized: "memo.sample.releaseChecklist.category"),
        updatedAt: .now.addingTimeInterval(-2_700),
        isPinned: true
    )
}

#Preview {
    ExampleAppView()
}
