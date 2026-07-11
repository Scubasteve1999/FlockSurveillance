import ARKit
import RealityKit
import SwiftUI
import UIKit

struct ARCameraSightRepresentable: UIViewRepresentable {
    var annotations: [ARCameraAnnotation]
    var onSelectCameraID: (String) -> Void
    var isActive: Bool
    var trackingResetID: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectCameraID: onSelectCameraID)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.environment.background = .cameraFeed()
        view.renderOptions.insert(.disableMotionBlur)
        view.renderOptions.insert(.disableDepthOfField)

        let root = AnchorEntity(world: .zero)
        root.name = "ar-geo-root"
        view.scene.addAnchor(root)
        context.coordinator.root = root
        context.coordinator.arView = view
        context.coordinator.trackingResetID = trackingResetID

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)

        if isActive {
            context.coordinator.startSession(on: view, forceReset: true)
        }
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.onSelectCameraID = onSelectCameraID
        if isActive {
            let shouldReset = context.coordinator.trackingResetID != trackingResetID
            context.coordinator.trackingResetID = trackingResetID
            context.coordinator.startSession(on: uiView, forceReset: shouldReset)
        } else {
            context.coordinator.pauseSession(on: uiView)
        }
        context.coordinator.syncAnnotations(annotations)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.pauseSession(on: uiView)
        uiView.session.delegate = nil
        uiView.scene.anchors.removeAll()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onSelectCameraID: (String) -> Void
        weak var arView: ARView?
        var root: AnchorEntity?
        var trackingResetID = UUID()
        private var sessionStarted = false
        private var lastSyncedIDs: [String] = []

        init(onSelectCameraID: @escaping (String) -> Void) {
            self.onSelectCameraID = onSelectCameraID
        }

        func startSession(on view: ARView, forceReset: Bool) {
            guard ARWorldTrackingConfiguration.isSupported else { return }
            if sessionStarted, !forceReset { return }
            let config = ARWorldTrackingConfiguration()
            config.worldAlignment = .gravityAndHeading
            config.environmentTexturing = .none
            view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            // Re-attach root after removeExistingAnchors.
            if let root {
                view.scene.addAnchor(root)
            }
            sessionStarted = true
        }

        func pauseSession(on view: ARView) {
            guard sessionStarted else { return }
            view.session.pause()
            sessionStarted = false
        }

        func syncAnnotations(_ annotations: [ARCameraAnnotation]) {
            guard let root else { return }
            let ids = annotations.map(\.id)
            if ids != lastSyncedIDs {
                root.children.removeAll()
                lastSyncedIDs = ids
                for annotation in annotations {
                    root.addChild(makeEntity(for: annotation))
                }
                return
            }

            for annotation in annotations {
                guard let entity = root.children.first(where: { $0.name == annotation.id }) else { continue }
                entity.position = annotation.position
                if let label = entity.findEntity(named: "label") as? ModelEntity {
                    label.model = Self.makeLabelModel(
                        text: annotation.distanceLabel,
                        color: annotation.uiColor
                    )
                }
                syncFOV(on: entity, annotation: annotation)
            }
        }

        private func syncFOV(on entity: Entity, annotation: ARCameraAnnotation) {
            let existing = entity.findEntity(named: "fov")
            guard let yaw = annotation.fovYawRadians else {
                existing?.removeFromParent()
                return
            }
            if let existing {
                existing.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                return
            }
            entity.addChild(makeFOVWedge(color: annotation.uiColor.withAlphaComponent(0.35), yaw: yaw))
        }

        private func makeEntity(for annotation: ARCameraAnnotation) -> Entity {
            let container = Entity()
            container.name = annotation.id
            container.position = annotation.position
            container.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.45)]))

            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.12),
                materials: [UnlitMaterial(color: annotation.uiColor)]
            )
            sphere.name = "pin"
            sphere.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.2)]))
            container.addChild(sphere)

            let label = ModelEntity()
            label.name = "label"
            label.model = Self.makeLabelModel(text: annotation.distanceLabel, color: annotation.uiColor)
            // generateText origin is lower-left; nudge so it sits above the pin.
            label.position = SIMD3(-0.2, 0.28, 0)
            container.addChild(label)

            if let yaw = annotation.fovYawRadians {
                container.addChild(makeFOVWedge(color: annotation.uiColor.withAlphaComponent(0.35), yaw: yaw))
            }

            return container
        }

        private func makeFOVWedge(color: UIColor, yaw: Float) -> ModelEntity {
            let radius = Float(ARGeoMath.fovRadiusMeters)
            let half = Float(ARGeoMath.fovHalfAngleDegrees * .pi / 180)
            let samples = 10
            var positions: [SIMD3<Float>] = [.zero]
            var indices: [UInt32] = []

            for index in 0...samples {
                let t = Float(index) / Float(samples)
                let angle = -half + (2 * half) * t
                // Local FOV along -Z (north in gravityAndHeading), then yaw around Y.
                let x = radius * sin(angle)
                let z = -radius * cos(angle)
                positions.append(SIMD3(x, 0.02, z))
            }

            for index in 1...samples {
                indices.append(0)
                indices.append(UInt32(index))
                indices.append(UInt32(index + 1))
            }

            var descriptor = MeshDescriptor(name: "fov")
            descriptor.positions = MeshBuffers.Positions(positions)
            descriptor.primitives = .triangles(indices)
            let mesh = try? MeshResource.generate(from: [descriptor])
            let material = UnlitMaterial(color: color)
            let entity = ModelEntity(
                mesh: mesh ?? .generatePlane(width: 0.1, depth: 0.1),
                materials: [material]
            )
            entity.name = "fov"
            entity.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            entity.position = SIMD3(0, -ARGeoMath.pinHeightMeters + 0.05, 0)
            return entity
        }

        private static func makeLabelModel(text: String, color: UIColor) -> ModelComponent {
            let mesh = MeshResource.generateText(
                text,
                extrusionDepth: 0.008,
                font: .systemFont(ofSize: 0.14, weight: .bold),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            return ModelComponent(mesh: mesh, materials: [UnlitMaterial(color: color)])
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = arView else { return }
            let location = gesture.location(in: view)
            let hits = view.hitTest(location)
            for hit in hits {
                var entity: Entity? = hit.entity
                while let current = entity {
                    let id = current.name
                    if !id.isEmpty,
                       id != "ar-geo-root", id != "pin", id != "label", id != "fov" {
                        onSelectCameraID(id)
                        return
                    }
                    entity = current.parent
                }
            }
        }
    }
}

struct ARCameraAnnotation: Identifiable, Equatable {
    let id: String
    let position: SIMD3<Float>
    let distanceLabel: String
    let isFlock: Bool
    let fovYawRadians: Float?

    var uiColor: UIColor {
        if isFlock {
            UIColor(red: 0.95, green: 0.42, blue: 0.28, alpha: 1)
        } else {
            UIColor(red: 0.35, green: 0.78, blue: 0.86, alpha: 1)
        }
    }

    static func == (lhs: ARCameraAnnotation, rhs: ARCameraAnnotation) -> Bool {
        lhs.id == rhs.id
            && lhs.position == rhs.position
            && lhs.distanceLabel == rhs.distanceLabel
            && lhs.isFlock == rhs.isFlock
            && lhs.fovYawRadians == rhs.fovYawRadians
    }
}
