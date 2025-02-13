//
//  ShareImageView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/2/13.
//

import SwiftUI

struct ShareImageView: View {
  @AppStorage("exportImageBackgroundColor") var exportImageBackgroundColor: Color = Color.init(uiColor: .systemGray3)
  @AppStorage("exportImagePadding") private var exportImagePadding: Double = 36
  @AppStorage("exportImageCornerRaius") var exportImageCornerRaius: Double = 36
  let image: UIImage
  var body: some View {
    let newImage = Image(
      uiImage: image
        .padding(exportImagePadding)
        .withBackground(color: UIColor(exportImageBackgroundColor))
        .roundedCorner(with: exportImageCornerRaius)
    )
    NavigationStack {
      List {
        Section {
          newImage
            .resizable()
            .scaledToFit()
        }
        Section {
          HStack {
            Text("Background")
            Spacer(minLength: 12)
            ColorPicker("Color", selection: $exportImageBackgroundColor)
              .labelsHidden()
              .frame(width: 20, height: 20)
              .padding(.trailing, 8)
          }
          HStack {
            Text("Padding")
            Spacer(minLength: 12)
            Slider(value: $exportImagePadding, in: 0 ... min(image.size.width, image.size.height) / 2)
              .frame(maxWidth: 320)
          }
          HStack {
            Text("Corner radius")
            Spacer(minLength: 12)
            Slider(value: $exportImageCornerRaius, in: 0 ... min(image.size.width, image.size.height) / 2)
              .frame(maxWidth: 320)
          }
        }
        Section {
          ShareLink(item: newImage, preview: SharePreview("Drawing", image: newImage)) {
            HStack(spacing: 12) {
              Image(systemName: "square.and.arrow.up")
                .frame(width: 8)
              Text("Export Image")
            }
          }
        }
      }
      .navigationTitle("Export setting")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

extension Color: @retroactive RawRepresentable {
  public init?(rawValue: String) {
    guard let data = Data(base64Encoded: rawValue) else {
      self = .black
      return
    }

    do {
      let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) ?? .black
      self = Color(color)
    } catch {
      self = .black
    }
  }

  public var rawValue: String {
    do {
      let data = try NSKeyedArchiver.archivedData(withRootObject: UIColor(self), requiringSecureCoding: false) as Data
      return data.base64EncodedString()

    } catch {
      return ""
    }
  }
}

extension UIImage {
  func withBackground(color: UIColor, opaque: Bool = true) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale)

    guard let context = UIGraphicsGetCurrentContext(),
          let image = cgImage else { return self }

    let rect = CGRect(origin: .zero, size: size)
    context.setFillColor(color.cgColor)
    context.fill(rect)
    context.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height))
    context.draw(image, in: rect)

    return UIGraphicsGetImageFromCurrentImageContext() ?? self
  }
}

extension UIImage {
  func padding(_ insets: CGFloat) -> UIImage {
    withEdgeInsets(UIEdgeInsets(top: insets, left: insets, bottom: insets, right: insets))
  }

  func withEdgeInsets(_ insets: UIEdgeInsets) -> UIImage {
    let targetWidth = size.width + insets.left + insets.right
    let targetHeight = size.height + insets.top + insets.bottom
    let targetSize = CGSize(width: targetWidth, height: targetHeight)
    let targetOrigin = CGPoint(x: insets.left, y: insets.top)
    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    return renderer.image { _ in
      draw(in: CGRect(origin: targetOrigin, size: size))
    }.withRenderingMode(renderingMode)
  }
}

extension UIImage {
  func roundedCorner(with radius: CGFloat) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { rendererContext in
      let rect = CGRect(origin: .zero, size: size)
      let path = UIBezierPath(roundedRect: rect,
                              byRoundingCorners: .allCorners,
                              cornerRadii: CGSize(width: radius, height: radius))
      path.close()

      let cgContext = rendererContext.cgContext
      cgContext.saveGState()
      path.addClip()
      draw(in: rect)
      cgContext.restoreGState()
    }
  }
}

#Preview {
  NavigationStack {
    ShareImageView(image: UIImage(imageLiteralResourceName: "HandDrawCover"))
  }.frame(width: 480)
}
