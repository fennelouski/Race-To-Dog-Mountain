import Foundation
import TVServices

final class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        // Curated public artwork ships in this extension. No networking or user data.
        let features: [(id: String, title: String)] = [
            ("pick", "Choose a tile"),
            ("score", "Follow the score"),
            ("together", "Pass & Play"),
        ]
        let items = features.enumerated().compactMap { index, feature -> TVTopShelfSectionedItem? in
            guard let image = Bundle.main.url(forResource: "shelf-item-\(index + 1)", withExtension: "jpg"),
                  let action = URL(string: "tallytangletv://shelf/\(feature.id)") else { return nil }
            let item = TVTopShelfSectionedItem(identifier: feature.id)
            item.title = feature.title
            item.imageShape = .hdtv
            item.setImageURL(image, for: [])
            item.setImageURL(image, for: .screenScale1x)
            item.setImageURL(image, for: .screenScale2x)
            item.displayAction = TVTopShelfAction(url: action)
            return item
        }
        // Returning nil enables the compiled static fallback.
        guard items.count == features.count else { return nil }
        let section = TVTopShelfItemCollection(items: items)
        section.title = "Learn the Board"
        return TVTopShelfSectionedContent(sections: [section])
    }
}
