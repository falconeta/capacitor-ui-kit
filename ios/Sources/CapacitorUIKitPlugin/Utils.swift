import SVGKit

func getImage(named iconName: String, imageBasePath: String?) -> UIImage? {
    guard !iconName.isEmpty,
          let url = Bundle.main.url(forResource: "public/\(imageBasePath ?? "assets")/\(iconName)", withExtension: "svg") else {
        return nil
    }
    let source = SVGKSourceLocalFile.source(fromFilename: url.path)
    var parsed = SVGKParser.parseSource(usingDefaultSVGKParser: source)
    // SVGKit's device-PPI initializer throws once for newer device identifiers,
    // even for icons sized in px. Retry only that initialization failure.
    if parsed?.errorsFatal.contains(where: {
        ($0 as? NSError)?.localizedDescription.contains("Cannot determine the PPI") == true
    }) == true {
        parsed = SVGKParser.parseSource(usingDefaultSVGKParser: SVGKSourceLocalFile.source(fromFilename: url.path))
    }
    guard let parsed, parsed.parsedDocument != nil,
          let svgImage = SVGKImage(parsedSVG: parsed, from: source) else { return nil }
    return svgImage.uiImage
}
