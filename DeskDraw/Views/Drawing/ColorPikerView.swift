//
//  ColorPikerView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/1/7.
//

import SwiftUI

struct ColorPickerView: View {
  @AppStorage("drawColor") private var drawColor: Color = .white

  private let columns = [
    GridItem(.adaptive(minimum: 44, maximum: 44)),
  ]

  var body: some View {
    ColorPickerUIView(title: "Pick color", selectedColor: $drawColor)
      .frame(maxWidth: 420)
      .fixedSize()
  }
}

class ColorPickerDelegate: NSObject, UIColorPickerViewControllerDelegate {
  @Binding var selectedColor: Color
  var update = 0

  init(selectedColor: Binding<Color>) {
    _selectedColor = selectedColor
  }

  @MainActor
  func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
    if selectedColor != Color(uiColor: viewController.selectedColor) {
      print(#function, "\(viewController.selectedColor) \(continuously) \(update)")
      selectedColor = Color(uiColor: viewController.selectedColor)
      update += 1
    }
  }

  func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
    print("dismiss colorPicker")
  }
}

struct ColorPickerUIView: UIViewControllerRepresentable {
  @Binding var selectedColor: Color
  private let pickerTitle: String
  @State var update = 0

  init(title: String, selectedColor: Binding<Color>) {
    pickerTitle = title
    _selectedColor = selectedColor
  }

  func makeCoordinator() -> ColorPickerDelegate {
    ColorPickerDelegate(selectedColor: $selectedColor)
  }

  func makeUIViewController(context: Context) -> UIColorPickerViewController {
    let colorPickerController = UIColorPickerViewController()
    colorPickerController.delegate = context.coordinator
    colorPickerController.title = pickerTitle
    colorPickerController.selectedColor = UIColor(selectedColor)
    return colorPickerController
  }

  @MainActor
  func updateUIViewController(_ uiViewController: UIColorPickerViewController, context: Context) {
    if uiViewController.selectedColor != UIColor(selectedColor) {
      uiViewController.selectedColor = UIColor(selectedColor)
      print(#function, update)
      update += 1
    }
  }
}

#Preview() {
  ColorPickerView()
    .environment(AppModel())
}
