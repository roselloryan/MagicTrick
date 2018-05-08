//
//  ViewController.swift
//  MagicTrick
//
//  Created by RYAN ROSELLO on 5/3/18.
//  Copyright © 2018 RYAN ROSELLO. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var hatIsPlaced = false
    var hatNode: SCNNode?
    var ballsThrown = [SCNNode]()
    var ballsInHat = [SCNNode]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let hatScene = SCNScene(named: "art.scnassets/hat.scn")!
        
        // Set the scene to the view
        sceneView.scene = hatScene
        
        // Set hat node as property
        if let hat = sceneView.scene.rootNode.childNode(withName: "hat", recursively: true) {
            print("\nSeting hat as property")
            hatNode = hat
            hatNode?.removeFromParentNode()
        }

        // Lighten up gravity
        sceneView.scene.physicsWorld.gravity = SCNVector3Make(0, -0.2, 0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        createBallInHatToggleButton()
    
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Add horizontal plane detection
        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    @IBAction func tapDetected(_ sender: UITapGestureRecognizer) {
        
        if !hatIsPlaced {
            let location = sender.location(in: sceneView)
        
            let hitResults = sceneView.hitTest(location, types: .existingPlaneUsingExtent)
        
            if let hit = hitResults.first {
                // Get transform form hit plane
                let transform = hit.worldTransform
                
                // Plane postition from 4th column
                let planePosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
                
                // Create floor
                let floor = SCNFloor()
                floor.reflectivity = 0.5
                floor.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.5)
                let floorNode = SCNNode(geometry: floor)
                let floorPhysics = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: floor, options: nil))
                floorPhysics.friction = 0.5
                floorNode.position = planePosition
                floorNode.physicsBody = floorPhysics
                sceneView.scene.rootNode.addChildNode(floorNode)

                // Place the hat
                if let hat = hatNode {
                    let boundingBox = hatNode?.boundingBox
                    let hatHeight = boundingBox!.max.y - boundingBox!.min.y
                    let hatPosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y + hatHeight / 2, transform.columns.3.z)
                    hat.position = hatPosition
                    sceneView.scene.rootNode.addChildNode(hat)
                    hatIsPlaced = true
                }
            }
        }
        else {
            // throw a ball
            let ball = SCNSphere(radius: 0.03)
            let node = SCNNode(geometry: ball)
            node.name = "ball"
            let physicsBody = SCNPhysicsBody.init(type: .dynamic, shape: SCNPhysicsShape(geometry: ball, options: nil))
            physicsBody.isAffectedByGravity = true
            physicsBody.friction = 0.5
            physicsBody.rollingFriction = 0.5
            node.physicsBody = physicsBody
            
            if let camera = sceneView.session.currentFrame?.camera {
                let cameraTransform = camera.transform

                var translation = matrix_identity_float4x4
                translation.columns.3.z = -0.05 // Translate 10 cm in front of the camera
                let newMatrix = matrix_multiply(cameraTransform, translation)

                node.simdTransform = newMatrix
                let impulseVector = SCNVector3Make(node.worldFront.x * 0.5, node.worldFront.y * 0.5, node.worldFront.z * 0.5)
                node.physicsBody?.applyForce(impulseVector, asImpulse: true)
                
                sceneView.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    @objc private func switchToggled(sender: UISwitch) {
        if sender.isOn {
            print("You turned me ON")
            for ball in ballsInHat {
                ball.opacity = 1
            }
        }
        else {
            print("I am turned OFF")
            for ball in ballsInHat {
                ball.opacity = 0
            }
        }
    }
    
    func createBallInHatToggleButton() {
        let frame = CGRect(x: sceneView.frame.width * 3/4, y: sceneView.frame.height * 7/8, width: sceneView.frame.width / 4, height: sceneView.frame.height / 8)
        let toggle = UISwitch(frame: frame)
        toggle.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
        toggle.layer.borderWidth = 2.0
        toggle.layer.borderColor = UIColor.red.cgColor
        sceneView.addSubview(toggle)
    }
    
    // MARK: - ARSCNViewDelegate
    
    // Override to create and configure nodes for anchors added to the view's session.
    var planeNode: SCNNode?
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
    
        if anchor is ARPlaneAnchor {
            planeNode = SCNNode()
            return planeNode
        }
     
        return nil
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if anchor is ARPlaneAnchor && !hatIsPlaced {
            let planeNode = planeNodeForAnchor(planeAnchor: anchor as! ARPlaneAnchor)
            node.addChildNode(planeNode)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        
        for node in sceneView.scene.rootNode.childNodes {
            if node.name == "ball" {
            
                if node.physicsBody!.isResting {
                
                    if hatNode!.boundingBoxContains(point: node.presentation.position,  in: sceneView.scene.rootNode) {
                        node.name = "ballInHat"
                        node.physicsBody = nil
                        node.opacity = 0.0
                        ballsInHat.append(node)
                    }
                }
            }
        }
    }
    
    func planeNodeForAnchor(planeAnchor: ARPlaneAnchor) -> SCNNode {
        
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.3)
        plane.materials = [planeMaterial]
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        // This transform lays the plane flat on the ground rather than standing vertical`
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
        
        return planeNode
    }
    
    // TODO: Learn rendererUpdateNode method!
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

extension SCNNode {
    func boundingBoxContains(point: SCNVector3, in node: SCNNode) -> Bool {
        let localPoint = self.convertPosition(point, from: node)
        return boundingBoxContains(point: localPoint)
    }
    
    func boundingBoxContains(point: SCNVector3) -> Bool {
        return BoundingBox(self.boundingBox).contains(point)
    }
}

struct BoundingBox {
    let min: SCNVector3
    let max: SCNVector3
    
    init(_ boundTuple: (min: SCNVector3, max: SCNVector3)) {
        min = boundTuple.min
        max = boundTuple.max
    }
    
    func contains(_ point: SCNVector3) -> Bool {
        let contains =
            min.x <= point.x &&
                min.y <= point.y &&
                min.z <= point.z &&
                
                max.x > point.x &&
                max.y > point.y &&
                max.z > point.z
        
        return contains
    }
}
