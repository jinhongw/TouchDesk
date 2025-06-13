//
//  ShareImageView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/2/13.
//

import SwiftUI

struct ExportImageView: View {
  @AppStorage("exportImageBackgroundColor") private var exportImageBackgroundColor: Color = .init(uiColor: .systemGray3)
  @AppStorage("exportImagePadding") private var exportImagePadding: Double = 36
  @AppStorage("exportImageCornerRaius") private var exportImageCornerRaius: Double = 36
  
  @State private var editingExportImagePadding: Double = 0
  @State private var editingExportImageCornerRaius: Double = 0
  @State private var processedImage: UIImage?

  let image: UIImage?
  let bounds: CGSize

  // 获取处理后的图像用于分享
  private func getProcessedImageForSharing() -> UIImage? {
    print(#function, "getProcessedImageForSharing")
    guard let image = image else { return nil }

    // 创建处理图像的容器视图
    let containerSize = CGSize(
      width: image.size.width + exportImagePadding * 2,
      height: image.size.height + exportImagePadding * 2
    )
    let containerView = UIView(frame: CGRect(origin: .zero, size: containerSize))
    containerView.backgroundColor = UIColor(exportImageBackgroundColor)
    containerView.layer.cornerRadius = exportImageCornerRaius
    containerView.clipsToBounds = true

    // 添加原始图像
    let imageView = UIImageView(image: image)
    imageView.contentMode = .scaleAspectFit
    imageView.frame = containerView.bounds.insetBy(dx: exportImagePadding, dy: exportImagePadding)
    containerView.addSubview(imageView)

    // 渲染为新图像
    UIGraphicsBeginImageContextWithOptions(containerSize, false, 0)
    containerView.layer.render(in: UIGraphicsGetCurrentContext()!)
    let processedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return processedImage
  }

  var body: some View {
    if let image = image {
      NavigationStack {
        List {
          Section {
            Image(uiImage: processedImage ?? image)
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
              Slider(value: $editingExportImagePadding, in: 0 ... min(image.size.width, image.size.height) / 2, onEditingChanged: { isEditing in
                if !isEditing {
                  exportImagePadding = editingExportImagePadding
                  // 更新处理后的图像
                  processedImage = getProcessedImageForSharing()
                }
              })
              .frame(maxWidth: 320)
            }
            HStack {
              Text("Corner radius")
              Spacer(minLength: 12)
              Slider(value: $editingExportImageCornerRaius, in: 0 ... min(image.size.width, image.size.height) / 2, onEditingChanged: { isEditing in
                if !isEditing {
                  exportImageCornerRaius = editingExportImageCornerRaius
                  // 更新处理后的图像
                  processedImage = getProcessedImageForSharing()
                }
              })
              .frame(maxWidth: 320)
            }
          }

          Section {
            ShareLink(item: Image(uiImage: processedImage ?? image),
                      preview: SharePreview("Drawing", image: Image(uiImage: processedImage ?? image))) {
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
        .onAppear {
          editingExportImagePadding = exportImagePadding
          editingExportImageCornerRaius = exportImageCornerRaius
          // 初始化处理后的图像
          processedImage = getProcessedImageForSharing()
        }
        .onChange(of: exportImageBackgroundColor) { _, _ in
          // 背景色改变时更新处理后的图像
          processedImage = getProcessedImageForSharing()
        }
      }
    } else {
      ProgressView()
        .frame(width: 480, height: 460 + 480 * bounds.height / bounds.width)
    }
  }

  // 计算相对于容器大小的padding
  private func calculateRelativePadding(containerSize: CGSize) -> CGFloat {
    guard let image = image else { return exportImagePadding }

    // 计算图像在容器中的实际显示尺寸
    let imageAspectRatio = image.size.width / image.size.height
    let containerAspectRatio = containerSize.width / containerSize.height

    var displayedImageSize: CGSize
    if imageAspectRatio > containerAspectRatio {
      // 图像按宽度适应
      displayedImageSize = CGSize(
        width: containerSize.width,
        height: containerSize.width / imageAspectRatio
      )
    } else {
      // 图像按高度适应
      displayedImageSize = CGSize(
        width: containerSize.height * imageAspectRatio,
        height: containerSize.height
      )
    }

    // 计算padding相对于原始图像尺寸的比例
    let paddingRatio = exportImagePadding / max(image.size.width, image.size.height)

    // 应用相同比例到显示尺寸
    return paddingRatio * max(displayedImageSize.width, displayedImageSize.height)
  }

  // 计算相对于容器大小的圆角
  private func calculateRelativeCornerRadius(containerSize: CGSize) -> CGFloat {
    guard let image = image else { return exportImageCornerRaius }

    // 计算图像在容器中的实际显示尺寸
    let imageAspectRatio = image.size.width / image.size.height
    let containerAspectRatio = containerSize.width / containerSize.height

    var displayedImageSize: CGSize
    if imageAspectRatio > containerAspectRatio {
      // 图像按宽度适应
      displayedImageSize = CGSize(
        width: containerSize.width,
        height: containerSize.width / imageAspectRatio
      )
    } else {
      // 图像按高度适应
      displayedImageSize = CGSize(
        width: containerSize.height * imageAspectRatio,
        height: containerSize.height
      )
    }

    // 计算圆角相对于原始图像尺寸的比例
    let cornerRadiusRatio = exportImageCornerRaius / max(image.size.width, image.size.height)

    // 应用相同比例到显示尺寸
    return cornerRadiusRatio * max(displayedImageSize.width, displayedImageSize.height)
  }
}

#Preview {
  NavigationStack {
    ExportImageView(image: UIImage(imageLiteralResourceName: "HandDrawCover"), bounds: .init(width: 480, height: 480))
  }.frame(width: 480)
}
