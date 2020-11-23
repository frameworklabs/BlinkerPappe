//  GameScene.swift
//  BlinkerPappe

import SpriteKit
import Pappe

struct Ratio {
    let nom: Double
    let denom: Double
}

enum BlinkerLeverPos {
    case up
    case center
    case down
    
    mutating func moveUp() {
        if self == .center {
            self = .up
        } else if self == .down {
            self = .center
        }
    }
    
    mutating func moveDown() {
        if self == .up {
            self = .center
        } else if self == .center {
            self = .down
        }
    }
}

class GameScene: SKScene {
    
    // Constants
    let blinkerRatioTurning = Ratio(nom: 0.4, denom: 0.5)
    let blinkerRatioWarning = Ratio(nom: 0.6, denom: 0.7)
    let rotationIncrement = 1
    let rotationThreshold = 3

    // Sensor input
    var blinkerLeverMove = BlinkerLeverPos.center
    var warningPushed = false
    var rotation = 0
    
    // Actuator state
    var leftBlinker: SKShapeNode!
    var rightBlinker: SKShapeNode!
    var lever: SKSpriteNode!
    var wheel: SKShapeNode!

    // Synchronous control program
    lazy var control = Module { name in
        
        activity (name.DelayTicks, [name.ticks]) { val in
            exec { val.counter = val.ticks as Int }
            `repeat` {
                exec { val.counter -= 1 }
                await { true }
            } until: { val.counter == 0 }
        }
        
        activity (name.Delay, [name.secs]) { val in
            Pappe.run (name.DelayTicks, [Int(60 * val.secs as Double)])
        }
        
        activity (name.Blinker, [name.ratio, name.blinker]) { val in
            `repeat` {
                exec { (val.blinker as SKShapeNode).isOn = true }
                Pappe.run (name.Delay, [(val.ratio as Ratio).nom])
                exec { (val.blinker as SKShapeNode).isOn = false }
                Pappe.run (name.Delay, [(val.ratio as Ratio).denom])
            }
        }
        
        activity (name.ConditionalBlinker, [name.pos, name.targetPos, name.blinker]) { val in
            `repeat` {
                await { val.pos as BlinkerLeverPos == val.targetPos }
                when { val.pos as BlinkerLeverPos != val.targetPos } abort: {
                    Pappe.run (name.Blinker, [self.blinkerRatioTurning, val.blinker])
                }
                exec { (val.blinker as SKShapeNode).fillColor = .clear }
            }
        }
        
        activity (name.WheelPosMonitor, [], [name.rotation]) { val in
            `repeat` {
                exec {
                    val.rotation = self.rotation
                    self.wheel.position.x -= CGFloat(self.rotation) * 5
                }
                await { true }
            }
        }

        activity (name.BlinkerLeverMover, [name.blinkerLeverMove, name.prevBlinkerLeverPos], [name.blinkerLeverPos]) { val in
            `repeat` {
                match {
                    cond { val.blinkerLeverMove == BlinkerLeverPos.up } then: {
                        exec {
                            var pos = val.prevBlinkerLeverPos as BlinkerLeverPos
                            pos.moveUp()
                            val.blinkerLeverPos = pos
                        }
                    }
                    cond { val.blinkerLeverMove == BlinkerLeverPos.down } then: {
                        exec {
                            var pos = val.prevBlinkerLeverPos as BlinkerLeverPos
                            pos.moveDown()
                            val.blinkerLeverPos = pos
                        }
                    }
                    cond { true } then: {
                        exec { val.blinkerLeverPos = val.prevBlinkerLeverPos as BlinkerLeverPos }
                    }
                }
                await { true }
            }
        }
        
        activity (name.BlinkerLeverRotationUpdater, [name.rotation, name.movedBlinkerLeverPos], [name.blinkerLeverPos]) { val in
            exec { val.rotationSum = 0 }
            `repeat` {
                match {
                    cond { val.movedBlinkerLeverPos != BlinkerLeverPos.center } then: {
                        exec {
                            val.rotationSum = self.updateRotationSum(val.rotation as Int, val.rotationSum as Int)
                        }
                        match {
                            cond { val.rotationSum >= self.rotationThreshold && val.movedBlinkerLeverPos == BlinkerLeverPos.up } then: {
                                exec {
                                    val.blinkerLeverPos = BlinkerLeverPos.center
                                    val.rotationSum = 0
                                }
                            }
                            cond { val.rotationSum <= -self.rotationThreshold && val.movedBlinkerLeverPos == BlinkerLeverPos.down } then: {
                                exec {
                                    val.blinkerLeverPos = BlinkerLeverPos.center
                                    val.rotationSum = 0
                                }
                            }
                            cond { true } then: {
                                exec { val.blinkerLeverPos = val.movedBlinkerLeverPos as BlinkerLeverPos }
                            }
                        }
                    }
                    cond { true } then: {
                        exec { val.blinkerLeverPos = val.movedBlinkerLeverPos as BlinkerLeverPos }
                    }
                }
                await { true }
            }
        }

        activity (name.BlinkerLeverMonitor, [name.rotation], [name.blinkerLeverPos]) { val in
            exec {
                val.movedBlinkerLeverPos = BlinkerLeverPos.center
            }
            cobegin {
                strong {
                    Pappe.run (name.BlinkerLeverMover, [self.blinkerLeverMove, val.blinkerLeverPos], [val.loc.movedBlinkerLeverPos])
                }
                strong {
                    Pappe.run (name.BlinkerLeverRotationUpdater, [self.rotation, val.movedBlinkerLeverPos], [val.loc.blinkerLeverPos])
                }
            }
        }
        
        activity (name.BlinkerController, [name.warningPushed, name.blinkerLeverPos]) { val in
            `repeat` {
                when { val.warningPushed as Bool } abort: {
                    cobegin {
                        strong {
                            Pappe.run (name.ConditionalBlinker, [val.blinkerLeverPos, BlinkerLeverPos.up, self.rightBlinker!])
                        }
                        strong {
                            Pappe.run (name.ConditionalBlinker, [val.blinkerLeverPos, BlinkerLeverPos.down, self.leftBlinker!])
                        }
                    }
                }
                when { val.warningPushed as Bool } abort: {
                    cobegin {
                        strong {
                            Pappe.run (name.Blinker, [self.blinkerRatioWarning, self.leftBlinker!])
                        }
                        strong {
                            Pappe.run (name.Blinker, [self.blinkerRatioWarning, self.rightBlinker!])
                        }
                    }
                }
                exec {
                    self.leftBlinker.isOn = false
                    self.rightBlinker.isOn = false
                }
            }
        }
        
        activity (name.Main, []) { val in
            exec {
                val.rotation = 0
                val.blinkerLeverPos = BlinkerLeverPos.center
            }
            cobegin {
                strong {
                    Pappe.run (name.WheelPosMonitor, [], [val.loc.rotation])
                }
                strong {
                    Pappe.run (name.BlinkerLeverMonitor, [val.rotation], [val.loc.blinkerLeverPos])
                }
                strong {
                    Pappe.run (name.BlinkerController, [self.warningPushed, val.blinkerLeverPos])
                }
                weak {
                    `repeat` {
                        exec { self.lever.setBlinkerLeverPos(val.blinkerLeverPos) }
                        await { true }
                    }
                }
            }
        }
        
    }.makeProcessor()!

    // Setup
    override func didMove(to view: SKView) {
        leftBlinker = childNode(withName: "leftBlinker") as? SKShapeNode
        rightBlinker = childNode(withName: "rightBlinker") as? SKShapeNode
        lever = childNode(withName: "lever") as? SKSpriteNode
        wheel = childNode(withName: "wheel") as? SKShapeNode
    }
        
    // Input
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126:
            blinkerLeverMove = .up
        case 125:
            blinkerLeverMove = .down
        case 123:
            rotateCounterClock()
        case 124:
            rotateClock()
        case 13:
            warningPushed = true
        default:
            break
        }
    }
    
    // Control
    override func update(_ currentTime: TimeInterval) {
        try! control.tick([], [])
        
        warningPushed = false
        blinkerLeverMove = .center
        rotation = 0
    }
    
    // Helpers
    func updateRotationSum(_ rotation: Int, _ rotationSum: Int) -> Int {
        if rotation > 0 {
            if rotationSum < 0 {
                return rotation
            } else {
                return rotation + rotationSum
            }
        } else if rotation < 0 {
            if rotationSum > 0 {
                return rotation
            } else {
                return rotation + rotationSum
            }
        } else {
            return rotationSum
        }
    }
    
    func rotateCounterClock() {
        rotation = rotationIncrement
    }
    
    func rotateClock() {
        rotation = -rotationIncrement
    }
}

extension SKShapeNode {
    var isOn: Bool {
        get {
            fillColor == .yellow
        }
        set {
            fillColor = newValue ? .yellow : .clear
        }
    }
}

extension SKSpriteNode {
    func setBlinkerLeverPos(_ pos: BlinkerLeverPos) {
        switch pos {
        case .up:
            zRotation = -0.1
        case .center:
            zRotation = 0
        case .down:
            zRotation = 0.1
        }
    }
}
