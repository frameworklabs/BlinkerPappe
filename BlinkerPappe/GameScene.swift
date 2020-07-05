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
            loopUntil({
                exec { val.counter -= 1 }
                await { true }
            }, val.counter == 0)
        }
        
        activity (name.Delay, [name.secs]) { val in
            doRun (name.DelayTicks, [Int(60 * val.secs as Double)])
            nop
        }
        
        activity (name.Blinker, [name.ratio, name.blinker]) { val in
            loop {
                exec { (val.blinker as SKShapeNode).isOn = true }
                doRun (name.Delay, [(val.ratio as Ratio).nom])
                exec { (val.blinker as SKShapeNode).isOn = false }
                doRun (name.Delay, [(val.ratio as Ratio).denom])
            }
            nop
        }
        
        activity (name.ConditionalBlinker, [name.pos, name.targetPos, name.blinker]) { val in
            loop {
                await { val.pos as BlinkerLeverPos == val.targetPos }
                whenAbort (val.pos as BlinkerLeverPos != val.targetPos) {
                    doRun (name.Blinker, [self.blinkerRatioTurning, val.blinker])
                    nop
                }
                exec { (val.blinker as SKShapeNode).fillColor = .clear }
            }
            nop
        }
        
        activity (name.WheelPosMonitor, [], [name.rotation]) { val in
            loop {
                exec {
                    val.rotation = self.rotation
                    self.wheel.position.x -= CGFloat(self.rotation) * 5
                }
                await { true }
            }
            nop
        }

        activity (name.BlinkerLeverMover, [name.blinkerLeverMove, name.prevBlinkerLeverPos], [name.blinkerLeverPos]) { val in
            loop {
                match {
                    cond (val.blinkerLeverMove == BlinkerLeverPos.up) {
                        exec {
                            var pos = val.prevBlinkerLeverPos as BlinkerLeverPos
                            pos.moveUp()
                            val.blinkerLeverPos = pos
                        }
                        nop
                    }
                    cond (val.blinkerLeverMove == BlinkerLeverPos.down) {
                        exec {
                            var pos = val.prevBlinkerLeverPos as BlinkerLeverPos
                            pos.moveDown()
                            val.blinkerLeverPos = pos
                        }
                        nop
                    }
                    cond (true) {
                        exec { val.blinkerLeverPos = val.prevBlinkerLeverPos as BlinkerLeverPos }
                        nop
                    }
                }
                await { true }
            }
            nop
        }
        
        activity (name.BlinkerLeverRotationUpdater, [name.rotation, name.movedBlinkerLeverPos], [name.blinkerLeverPos]) { val in
            exec { val.rotationSum = 0 }
            loop {
                match {
                    cond (val.movedBlinkerLeverPos != BlinkerLeverPos.center) {
                        exec {
                            val.rotationSum = self.updateRotationSum(val.rotation as Int, val.rotationSum as Int)
                        }
                        match {
                            cond (val.rotationSum >= self.rotationThreshold && val.movedBlinkerLeverPos == BlinkerLeverPos.up) {
                                exec {
                                    val.blinkerLeverPos = BlinkerLeverPos.center
                                    val.rotationSum = 0
                                }
                                nop
                            }
                            cond (val.rotationSum <= -self.rotationThreshold && val.movedBlinkerLeverPos == BlinkerLeverPos.down) {
                                exec {
                                    val.blinkerLeverPos = BlinkerLeverPos.center
                                    val.rotationSum = 0
                                }
                                nop
                            }
                            cond (true) {
                                exec { val.blinkerLeverPos = val.movedBlinkerLeverPos as BlinkerLeverPos }
                                nop
                            }
                        }
                        nop
                    }
                    cond (true) {
                        exec { val.blinkerLeverPos = val.movedBlinkerLeverPos as BlinkerLeverPos }
                        nop
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
                    doRun (name.BlinkerLeverMover, [self.blinkerLeverMove, val.blinkerLeverPos], [val.loc.movedBlinkerLeverPos])
                    nop
                }
                strong {
                    doRun (name.BlinkerLeverRotationUpdater, [self.rotation, val.movedBlinkerLeverPos], [val.loc.blinkerLeverPos])
                    nop
                }
            }
            nop
        }
        
        activity (name.BlinkerController, [name.warningPushed, name.blinkerLeverPos]) { val in
            loop {
                whenAbort (val.warningPushed as Bool) {
                    cobegin {
                        strong {
                            doRun (name.ConditionalBlinker, [val.blinkerLeverPos, BlinkerLeverPos.up, self.rightBlinker!])
                            nop
                        }
                        strong {
                            doRun (name.ConditionalBlinker, [val.blinkerLeverPos, BlinkerLeverPos.down, self.leftBlinker!])
                            nop
                        }
                    }
                    nop
                }
                whenAbort (val.warningPushed as Bool) {
                    cobegin {
                        strong {
                            doRun (name.Blinker, [self.blinkerRatioWarning, self.leftBlinker!])
                            nop
                        }
                        strong {
                            doRun (name.Blinker, [self.blinkerRatioWarning, self.rightBlinker!])
                            nop
                        }
                    }
                    nop
                }
                exec {
                    self.leftBlinker.isOn = false
                    self.rightBlinker.isOn = false
                }
            }
            nop
        }
        
        activity (name.Main, []) { val in
            exec {
                val.rotation = 0
                val.blinkerLeverPos = BlinkerLeverPos.center
            }
            cobegin {
                strong {
                    doRun (name.WheelPosMonitor, [], [val.loc.rotation])
                    nop
                }
                strong {
                    doRun (name.BlinkerLeverMonitor, [val.rotation], [val.loc.blinkerLeverPos])
                    nop
                }
                strong {
                    doRun (name.BlinkerController, [self.warningPushed, val.blinkerLeverPos])
                    nop
                }
                weak {
                    loop {
                        exec { self.lever.setBlinkerLeverPos(val.blinkerLeverPos) }
                        await { true }
                    }
                    nop
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
