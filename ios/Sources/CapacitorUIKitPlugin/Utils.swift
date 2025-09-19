import SVGKit

func getImage(named iconName: String, imageBasePath: String?) -> UIImage? {
    guard let url = Bundle.main.url(forResource: "public/\(imageBasePath ?? "assets")/\(iconName)", withExtension: "svg") else {
        print("⚠️ SVG not found:", iconName)
        return nil
    }
    
    guard let svgImage = SVGKImage(contentsOf: url) else {
        print("⚠️ Error on create SVGKImage from local URL")
        return nil
    }
    
    return svgImage.uiImage
}
