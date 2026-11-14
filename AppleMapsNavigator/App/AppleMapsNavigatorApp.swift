import SwiftUI

@main
struct AppleMapsNavigatorApp: App {
    @State private var viewModel = MapNavigatorViewModel()

    var body: some Scene {
        WindowGroup {
            MainMapCanvasView(viewModel: viewModel)
                .preferredColorScheme(viewModel.themeMode.colorScheme)
        }
    }
}
