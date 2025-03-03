//
//  CornerShapeView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/3/2.
//

import SwiftUI

struct CornerShapeView: View {
  @Binding var isHorizontal: Bool
  let width: CGFloat
  let height: CGFloat
  let depth: CGFloat
  let placeZOffset: CGFloat
  let zOffset: CGFloat
  let shapeWidth: CGFloat = 16
  var body: some View {
    VStack {
      HStack {
        LShape()
          .fill(.clear)
          .glassBackgroundEffect(in: LShape())
          .frame(width: shapeWidth, height: shapeWidth)
          .rotationEffect(.degrees(-90))
          .offset(x: -36, y: 36)
          .padding(36)
          .hoverEffect { effect, isActive, geometry in
            effect.animation(.default) {
              $0.opacity(isActive ? 1 : 0.6)
            }
          }
        Spacer()
        LShape()
          .fill(.clear)
          .glassBackgroundEffect(in: LShape())
          .frame(width: shapeWidth, height: shapeWidth)
          .rotationEffect(.degrees(0))
          .offset(x: 36, y: 36)
          .padding(36)
          .hoverEffect { effect, isActive, geometry in
            effect.animation(.default) {
              $0.opacity(isActive ? 1 : 0.6)
            }
          }
      }
      .opacity(isHorizontal ? 0 : 1)
      .scaleEffect(isHorizontal ? 0 : 1)
      Spacer()
      HStack {
        LShape()
          .fill(.clear)
          .glassBackgroundEffect(in: LShape())
          .frame(width: shapeWidth, height: shapeWidth)
          .rotationEffect(.degrees(-180))
          .offset(x: -36, y: 36)
          .padding(36)
          .hoverEffect { effect, isActive, geometry in
            effect.animation(.default) {
              $0.opacity(isActive ? 1 : 0.6)
            }
          }
        Spacer()
        LShape()
          .fill(.clear)
          .glassBackgroundEffect(in: LShape())
          .frame(width: shapeWidth, height: shapeWidth)
          .rotationEffect(.degrees(90))
          .offset(x: 36, y: 36)
          .padding(36)
          .hoverEffect { effect, isActive, geometry in
            effect.animation(.default) {
              $0.opacity(isActive ? 1 : 0.6)
            }
          }
      }
    }
    .frame(width: width, height: depth)
    .rotation3DEffect(.degrees(90), axis: (1, 0, 0), anchor: .center)
    .offset(y: height / 2 - placeZOffset)
    .offset(z: isHorizontal ? -depth / 2 : -depth / 2 - zOffset)
  }

  struct LShape: InsettableShape {
    var insetAmount: CGFloat = 0
    let cornerRadius: CGFloat = 4
    let widthRatio: CGFloat = 3

    func path(in rect: CGRect) -> Path {
      let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
      let radius = min(cornerRadius, insetRect.width / 6, insetRect.height / 6)
      var path = Path()

      path.move(to: CGPoint(x: insetRect.minX + radius, y: insetRect.minY))
      path.addLine(to: CGPoint(x: insetRect.maxX - radius * 1.5, y: insetRect.minY))
      path.addArc(
        center: CGPoint(x: insetRect.maxX - radius * 1.5, y: insetRect.minY + radius * 1.5),
        radius: radius * 1.5,
        startAngle: Angle(degrees: -90),
        endAngle: Angle(degrees: 0),
        clockwise: false
      )
      path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY - radius))
      path.addArc(
        center: CGPoint(x: insetRect.maxX - radius, y: insetRect.maxY - radius),
        radius: radius,
        startAngle: Angle(degrees: 0),
        endAngle: Angle(degrees: 90),
        clockwise: false
      )
      path.addLine(to: CGPoint(x: insetRect.maxX * (widthRatio - 1) / widthRatio + radius, y: insetRect.maxY))
      path.addArc(
        center: CGPoint(x: insetRect.maxX * (widthRatio - 1) / widthRatio + radius, y: insetRect.maxY - radius),
        radius: radius,
        startAngle: Angle(degrees: 90),
        endAngle: Angle(degrees: 180),
        clockwise: false
      )
      path.addLine(to: CGPoint(x: insetRect.maxX * (widthRatio - 1) / widthRatio, y: insetRect.maxY / widthRatio + radius))
      path.addArc(
        center: CGPoint(x: insetRect.maxX * (widthRatio - 1) / widthRatio - radius, y: insetRect.maxY / widthRatio + radius),
        radius: radius,
        startAngle: Angle(degrees: 0),
        endAngle: Angle(degrees: -90),
        clockwise: true
      )
      path.addLine(to: CGPoint(x: insetRect.minX + radius, y: insetRect.maxY / widthRatio))
      path.addArc(
        center: CGPoint(x: insetRect.minX + radius, y: insetRect.maxY / widthRatio - radius),
        radius: radius,
        startAngle: Angle(degrees: 90),
        endAngle: Angle(degrees: 180),
        clockwise: false
      )
      path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.minY + radius))
      path.addArc(
        center: CGPoint(x: insetRect.minX + radius, y: insetRect.minY + radius),
        radius: radius,
        startAngle: Angle(degrees: 180),
        endAngle: Angle(degrees: 270),
        clockwise: false
      )

      path.closeSubpath()
      return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
      var shape = self
      shape.insetAmount += amount
      return shape
    }
  }
}
