import SwiftUI
import UIKit

/// Live bot desktops (screenshot stream), empty slots show a cat. View only in v1.
struct ScreensView: View {
    @Environment(AppModel.self) private var model
    @State private var fullScreen: BotScreen?
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(0..<max(model.maxScreens, 4), id: \.self) { slot in
                        if slot < model.screens.count {
                            let screen = model.screens[slot]
                            ScreenTile(screen: screen)
                                .onTapGesture { fullScreen = screen }
                        } else {
                            CatTile(slot: slot)
                        }
                    }
                }
                .padding(10)
            }
            .background(Palette.bg)
            .navigationTitle("Экраны")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ServerSwitcher() }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(model.screens.count)/\(model.maxScreens)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .task(id: model.selectedServerID) {
                while !Task.isCancelled {
                    await model.refreshScreens()
                    try? await Task.sleep(for: .seconds(3))
                }
            }
            .fullScreenCover(item: $fullScreen) { screen in
                ScreenFullView(screen: screen)
            }
        }
    }
}

/// Polls one desktop's JPEG while visible
struct LiveScreenImage: View {
    @Environment(AppModel.self) private var model
    let screenID: String
    let width: Int
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ProgressView()
            }
        }
        .task(id: screenID) {
            while !Task.isCancelled {
                if let api = model.api,
                   let data = try? await api.screenImage(screenID, width: width),
                   let fresh = UIImage(data: data) {
                    image = fresh
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }
}

struct ScreenTile: View {
    @Environment(AppModel.self) private var model
    let screen: BotScreen

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScreenFrame { LiveScreenImage(screenID: screen.id, width: 640) }
            HStack(spacing: 6) {
                Circle().fill(BoardColumn.done.color).frame(width: 6, height: 6)
                Text(screen.id).font(.caption2.monospaced())
                Spacer()
                if let idle = screen.idleMin, idle > 0 {
                    Text("простой \(idle) мин").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            if let roleID = screen.roleId {
                RoleChip(name: model.role(roleID)?.name ?? roleID, color: model.roleColor(roleID))
            }
            if let taskID = screen.taskId {
                Text("\(taskID) \(screen.taskTitle ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .card()
    }
}

struct CatTile: View {
    let slot: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScreenFrame {
                AsyncImage(url: URL(string: "https://cataas.com/cat?width=480&height=300&t=\(slot)")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill().opacity(0.85)
                    } else {
                        Image(systemName: "cat.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("слот \(slot + 1) свободен")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .card()
    }
}

struct ScreenFullView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let screen: BotScreen
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            LiveScreenImage(screenID: screen.id, width: 1280)
                .scaleEffect(scale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in scale = min(max(lastScale * value.magnification, 1), 5) }
                        .onEnded { _ in lastScale = scale }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring) { scale = 1; lastScale = 1 }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                }
                if let roleID = screen.roleId {
                    RoleChip(name: model.role(roleID)?.name ?? roleID, color: model.roleColor(roleID))
                }
            }
            .padding()
        }
    }
}
