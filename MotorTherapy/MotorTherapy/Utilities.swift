//
//  Utilities.swift
//  MotorTherapy
//
//  Created by Alejandro Ibarra on 10/9/19.
//  Copyright © 2019 Schlafenhase. All rights reserved.
//

import ARKit
import AVFoundation
import Foundation
import RealityKit

extension MeshResource {
    
    /// Generate three axes of a coordinate system with x axis = red, y axis = green and z axis = blue
    /// - parameters:
    /// - axisLength: Length of the axes in m
    /// - thickness: Thickness of the axes as a percentage of their length
    static func generateCoordinateSystemAxes(length: Float = 0.1, thickness: Float = 2.0) -> Entity {
        let thicknessInM = (length / 100) * thickness
        let cornerRadius = thickness / 2.0
        let offset = length / 2.0
        
        let xAxisBox = MeshResource.generateBox(size: [length, thicknessInM, thicknessInM], cornerRadius: cornerRadius)
        let yAxisBox = MeshResource.generateBox(size: [thicknessInM, length, thicknessInM], cornerRadius: cornerRadius)
        let zAxisBox = MeshResource.generateBox(size: [thicknessInM, thicknessInM, length], cornerRadius: cornerRadius)
    
        let xAxis = ModelEntity(mesh: xAxisBox, materials: [UnlitMaterial(color: .red)])
        let yAxis = ModelEntity(mesh: yAxisBox, materials: [UnlitMaterial(color: .green)])
        let zAxis = ModelEntity(mesh: zAxisBox, materials: [UnlitMaterial(color: .blue)])
        
        xAxis.position = [offset, 0, 0]
        yAxis.position = [0, offset, 0]
        zAxis.position = [0, 0, offset]
        
        let axes = Entity()
        axes.addChild(xAxis)
        axes.addChild(yAxis)
        axes.addChild(zAxis)
        return axes
    }
}

// Graphical square for spider web
struct graphicalSquare {
    var i: Int
    var j: Int
    var x: CGFloat
    var y: CGFloat
}
