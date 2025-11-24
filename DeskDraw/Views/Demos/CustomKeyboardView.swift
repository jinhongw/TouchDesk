//
//  CustomKeyboardView.swift
//  DeskDraw
//
//  Custom keyboard view based on Medium article MVP
//

import SwiftUI
import RealityKit

struct CustomKeyboardView: View {
  @Binding var text: String
  @State private var isUppercase = false
  
  // QWERTY keyboard layout
  let row1 = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
  let row2 = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
  let row3 = ["z", "x", "c", "v", "b", "n", "m"]
  
  var body: some View {
    VStack(spacing: 10) {
      // First row: Q W E R T Y U I O P
      HStack(spacing: 8) {
        ForEach(row1, id: \.self) { key in
          KeyButton(
            title: isUppercase ? key.uppercased() : key,
            action: {
              text.append(isUppercase ? key.uppercased() : key)
            }
          )
        }
      }
      
      // Second row: Shift + A S D F G H J K L
      HStack(spacing: 8) {
        // Shift key
        KeyButton(
          title: "⇧",
          action: {
            isUppercase.toggle()
          },
          backgroundColor: isUppercase ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2),
          width: 70
        )
        
        ForEach(row2, id: \.self) { key in
          KeyButton(
            title: isUppercase ? key.uppercased() : key,
            action: {
              text.append(isUppercase ? key.uppercased() : key)
            }
          )
        }
      }
      
      // Third row: Shift + Z X C V B N M + Delete
      HStack(spacing: 8) {
        // Shift key
        KeyButton(
          title: "⇧",
          action: {
            isUppercase.toggle()
          },
          backgroundColor: isUppercase ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2),
          width: 70
        )
        
        ForEach(row3, id: \.self) { key in
          KeyButton(
            title: isUppercase ? key.uppercased() : key,
            action: {
              text.append(isUppercase ? key.uppercased() : key)
            }
          )
        }
        
        // Delete key
        KeyButton(
          title: "⌫",
          action: {
            if !text.isEmpty {
              text.removeLast()
            }
          },
          backgroundColor: Color.red.opacity(0.2),
          width: 70
        )
      }
      
      // Fourth row: Space + Return
      HStack(spacing: 8) {
        // Space key
        KeyButton(
          title: "Space",
          action: {
            text.append(" ")
          },
          backgroundColor: Color.gray.opacity(0.2),
          width: 200
        )
        
        // Return key
        KeyButton(
          title: "Return",
          action: {
            text.append("\n")
          },
          backgroundColor: Color.green.opacity(0.2),
          width: 100
        )
      }
    }
    .padding()
  }
}

// Key button component
struct KeyButton: View {
  let title: String
  let action: () -> Void
  var backgroundColor: Color = Color.gray.opacity(0.2)
  var width: CGFloat = 50
  
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.title3)
        .fontWeight(.medium)
        .frame(width: width, height: 50)
        .background(backgroundColor)
        .cornerRadius(8)
    }
  }
}

struct CustomKeyboardBottomView: View {
  @State private var text = ""
  @State private var isKeyboardVisible = false
  
  var body: some View {
    GeometryReader3D { proxy in
      let width = proxy.size.width
      let height = proxy.size.height
      let depth = proxy.size.depth
      
      RealityView { content, attachments in
        // TextField at the front
        if let textFieldView = attachments.entity(for: "textFieldView") {
          textFieldView.name = "textFieldView"
          // Move upward and backward
          textFieldView.position = SIMD3<Float>(0, 0.1, -0.1)
          content.add(textFieldView)
        }
        
        // Keyboard at the bottom
        if let keyboardView = attachments.entity(for: "keyboardView") {
          keyboardView.name = "keyboardView"
          keyboardView.setOrientation(.init(angle: -.pi / 2, axis: .init(x: 1, y: 0, z: 0)), relativeTo: nil)
          content.add(keyboardView)
        }
      } attachments: {
        // TextField attachment at the front
        Attachment(id: "textFieldView") {
          VStack {
            TextField("Enter text", text: $text)
              .textFieldStyle(.roundedBorder)
              .padding()
              .onTapGesture {
                isKeyboardVisible = true
              }
            
            if isKeyboardVisible {
              Button("Done") {
                isKeyboardVisible = false
              }
              .padding()
            }
          }
          .frame(width: width, height: height)
          .colorScheme(.light)
        }
        
        // Keyboard attachment at the bottom
        Attachment(id: "keyboardView") {
          CustomKeyboardView(text: $text)
            .frame(width: width, height: depth)
            .colorScheme(.light)
//            .opacity(isKeyboardVisible ? 1 : 0)
        }
      }
      .frame(width: width, height: depth)
      .frame(depth: height)
      .offset(y: proxy.size.height / 2)
      .animation(.easeInOut, value: isKeyboardVisible)
    }
  }
}

