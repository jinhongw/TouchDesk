//
//  StorageModels.swift
//  DeskDraw
//
//  Created by jinhong on 2025/5/3.
//

import SwiftUI

/// 用于AppStorage存储的数据结构，使用RawRepresentable将[Color]转换为String类型，而String可以存入AppStorage中
struct ColorArrayStorageModel: RawRepresentable {
  var colors: [Color]

  init(colors: [Color] = []) {
    self.colors = colors
  }

  init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
          let colorStrings = try? JSONDecoder().decode([String].self, from: data),
          let colors = colorStrings.map({ Color(rawValue: $0) }) as? [Color]
    else {
      return nil
    }
    self.colors = colors
  }

  var rawValue: String {
    let colorStrings = colors.map { $0.rawValue }
    guard let data = try? JSONEncoder().encode(colorStrings),
          let string = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }
    return string
  }
}

/// 用于AppStorage存储的数据结构，使用RawRepresentable将[Double]转换为String类型，而String可以存入AppStorage中
struct DoubleArrayStorageModel: RawRepresentable {
  var array: [Double]
  
  init(array: [Double] = []) {
    self.array = array
  }
  
  init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
          let array = try? JSONDecoder().decode([Double].self, from: data)
    else {
      return nil
    }
    self.array = array
  }
  
  var rawValue: String {
    guard let data = try? JSONEncoder().encode(array),
          let string = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }
    return string
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
