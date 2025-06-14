//
//  CanvasState.swift
//  DeskDraw
//
//  Created by jinhong on 2025/6/14.
//

import Foundation
import SwiftUI

/// 画布的显示状态
enum CanvasDisplayState {
  case drawing    // 显示绘图
  case notes      // 显示笔记
  case mini       // 最小化显示
}

/// 表示单个画布的状态
@MainActor
@Observable
class CanvasState {
  var drawingId: UUID?
  var imageEditingId: UUID?
  var displayState: CanvasDisplayState = .drawing
  var isLocked = false
  var canvasZoomFactor: Double = 100
  
  init(drawingId: UUID? = nil) {
    self.drawingId = drawingId
  }
}

// MARK: - CanvasState Methods
extension CanvasState {
  /// 设置绘图ID
  func setDrawingId(_ drawingId: UUID?) {
    self.drawingId = drawingId
  }
  
  /// 设置图像编辑ID
  func setImageEditingId(_ imageEditingId: UUID?) {
    self.imageEditingId = imageEditingId
  }
  
  /// 设置显示状态
  func setDisplayState(_ state: CanvasDisplayState) {
    self.displayState = state
  }
  
  /// 设置隐藏在迷你模式
  func setHideInMini(_ hide: Bool) {
    self.displayState = hide ? .mini : .drawing
  }
  
  /// 设置显示绘图
  func setShowDrawing(_ show: Bool) {
    if show {
      self.displayState = .drawing
    }
  }
  
  /// 设置显示笔记
  func setShowNotes(_ show: Bool) {
    if show {
      self.displayState = .notes
    }
  }
  
  /// 切换显示状态
  func toggleDisplayState() {
    switch displayState {
    case .drawing:
      displayState = .notes
    case .notes:
      displayState = .mini
    case .mini:
      displayState = .drawing
    }
  }
  
  /// 切换最小化状态
  func toggleMini() {
    displayState = (displayState == .mini) ? .drawing : .mini
  }
  
  /// 设置锁定状态
  func setIsLocked(_ locked: Bool) {
    self.isLocked = locked
  }
  
  /// 设置画布缩放因子
  func setCanvasZoomFactor(_ factor: Double) {
    self.canvasZoomFactor = factor
  }
  
  /// 重置画布状态到默认值
  func reset() {
    drawingId = nil
    imageEditingId = nil
    displayState = .drawing
    isLocked = false
    canvasZoomFactor = 100
  }
  
  /// 获取当前绘图（从 AppModel 获取）
  func getCurrentDrawing(from appModel: AppModel) -> DrawingModel? {
    guard let drawingId = drawingId else { return nil }
    return appModel.drawings[drawingId]
  }
}

// MARK: - AppModel 画布管理
extension AppModel {
  /// 创建新画布，返回画布状态实例
  func createCanvas(drawingId: UUID? = nil) -> (canvasId: UUID, canvasState: CanvasState) {
    let canvasId = UUID()
    let canvasState = CanvasState(drawingId: drawingId)
    canvasStates[canvasId] = canvasState
    return (canvasId, canvasState)
  }
  
  /// 关闭画布
  func closeCanvas(_ canvasId: UUID) {
    canvasStates.removeValue(forKey: canvasId)
  }
  
  /// 获取指定画布的状态
  func getCanvasState(_ canvasId: UUID) -> CanvasState? {
    return canvasStates[canvasId]
  }
  
  /// 获取所有画布ID
  var allCanvasIds: [UUID] {
    return Array(canvasStates.keys)
  }
  
  /// 获取当前画布数量
  var canvasCount: Int {
    return canvasStates.count
  }
  
  /// 获取所有画布状态
  var allCanvasStates: [CanvasState] {
    return Array(canvasStates.values)
  }
}

// MARK: - AppModel 绘图操作（需要画布上下文的方法）
extension AppModel {
  /// 添加图像到指定画布
  func addImage(_ imageData: Data, at position: CGPoint, size: CGSize, rotation: Double = 0, to canvasId: UUID) {
    let imageElement = ImageElement(id: UUID(), imageData: imageData, position: position, size: size, rotation: rotation)
    guard let drawingId = canvasStates[canvasId]?.drawingId else { return }
    drawings[drawingId]?.images.append(imageElement)
    updateDrawing(drawingId)
    canvasStates[canvasId]?.setImageEditingId(imageElement.id)
  }
  
  /// 添加文本到指定画布
  func addText(_ text: String, at position: CGPoint, fontSize: CGFloat = 16, fontWeight: Font.Weight = .regular, color: Color = .black, rotation: Double = 0, to canvasId: UUID) {
    let textElement = TextElement(id: UUID(), text: text, position: position, fontSize: fontSize, fontWeight: fontWeight, color: color, rotation: rotation)
    guard let drawingId = canvasStates[canvasId]?.drawingId else { return }
    drawings[drawingId]?.texts.append(textElement)
    updateDrawing(drawingId)
  }
  
  /// 从指定画布删除图像
  func deleteImage(_ imageId: UUID, from canvasId: UUID) {
    guard let drawingId = canvasStates[canvasId]?.drawingId else { return }
    drawings[drawingId]?.images.removeAll { $0.id == imageId }
    // 清除编辑状态
    canvasStates[canvasId]?.setImageEditingId(nil)
    // 保存更改
    updateDrawing(drawingId)
  }
}
