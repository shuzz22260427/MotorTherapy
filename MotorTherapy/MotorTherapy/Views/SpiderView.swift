//
//  SpiderView.swift
//  MotorTherapy
//
//  Created by Alejandro Ibarra on 10/29/19.
//  Copyright © 2019 Schlafenhase. All rights reserved.
//

import ARKit
import AVFoundation
import Combine
import RealityKit
import Speech
import UIKit

class SpiderView: UIViewController, ARSessionDelegate, SFSpeechRecognizerDelegate {
    
    // MARK: - UI Elements
    
    // Main UI views
    @IBOutlet var arView: ARView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var gameView: UIView!
    @IBOutlet weak var controlView: UIView!
    
    // Buttons and other elements
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var categoryAnswerLabel: UILabel!
    @IBOutlet weak var categoryGuessLabel: UILabel!
    @IBOutlet weak var categoryPromptLabel: UILabel!
    @IBOutlet weak var endGameLabel: UILabel!
    @IBOutlet weak var messageLabel: MessageLabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    
    // Game view words
    @IBOutlet weak var avatarIcon: UIImageView!
    
    // TEMP TEST BUTTONS
    @IBOutlet weak var upbutton: UIButton!
    @IBOutlet weak var downbutton: UIButton!
    @IBOutlet weak var leftbutton: UIButton!
    @IBOutlet weak var rightbutton: UIButton!
    
    @IBAction func uppress(_ sender: Any) {
        signalUp()
    }
    
    @IBAction func downpress(_ sender: Any) {
        signalDown()
    }
    
    @IBAction func leftpress(_ sender: Any) {
        signalLeft()
    }
    
    @IBAction func rightpress(_ sender: Any) {
        signalRight()
    }
    
    
    // MARK: - Attributes
    
    // Constants
    let animationDuration = 3.0
    let fontSizeSmall: CGFloat = 15
    let fontSizeBig: CGFloat = 2000
    let gameName = "Spider Web"
    
    // Entity data
    var bodyAnchorExists = false
    var bodyPosition: simd_float3?
    var character: BodyTrackedEntity?
    let characterAnchor = AnchorEntity()
    var upBall = Entity()
    var downBall = Entity()
    var leftBall = Entity()
    var rightBall = Entity()
    var leftBox = Entity()
    var rightBox = Entity()
    var leftBoxUp = Entity()
    var rightBoxUp = Entity()
    
    // Additional variables for control
    var audioPlayer: AVAudioPlayer!
    var collectedWords = [String]()
    var columns: Int?
    var gridView: UIImageView?
    var halfAPress = ("", 0)
    var hasSpeechRecognition = false
    var holder = Holder()
    var isFirstTime = true
    var isOnline: Bool?
    var isOver = false
    var rows: Int?
    var score = 0
    var squareHeight: CGFloat?
    var squareWidth: CGFloat?
    var posList = [[graphicalSquare]]()
    var web: SpiderWeb?
    var wordLabelList = [[UILabel]]()
    
    // Speech recogntition
    let audioEngine = AVAudioEngine()
    var request: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    
    // Reality Composer scene
    var experienceScene = Experience.Scene()
    
    // Flush Collision events list for memory management
    var collisionEventStreams = [AnyCancellable]()
    deinit {
        collisionEventStreams.removeAll()
        endGame()
    }
    
    // MARK: - Functions
    
    /// Clears word label list in UI
    func clearGrid() {
        // Remove all word labels
        for i in 0...(wordLabelList.count - 1) {
            for j in  0...(wordLabelList[0].count - 1) {
                let label = wordLabelList[i][j]
                label.removeFromSuperview()
            }
        }
        // Remove grid
        gridView?.removeFromSuperview()
    }
    
    /// Enables  or disables UI elements while connecting
    func disableUI(_ block: Bool) {
        if block {
            backButton.isEnabled = false
            startButton.isEnabled = false
        } else {
            backButton.isEnabled = true
            startButton.isEnabled = true
        }
    }
    
    /// Draws player in position
    func drawPlayer(_ x: Int, _ y: Int) {
        if x > (posList.count - 1) || x < 0 || y > (posList[0].count - 1) || y < 0{
            print("Index out of range")
        } else {
            // Move avatar icon to position of graphical square
            let square = posList[x][y]
            avatarIcon.frame.origin.x = square.x + (squareWidth! / 5)
            avatarIcon.frame.origin.y = square.y + (squareHeight! / 5)
            
            // Update logical player position
            web?.playerPos[0] = x
            web?.playerPos[1] = y
            
            // If player is over a word, collect it
            let wordToCollect = web?.getWord(x, y)
            if (web?.wordPath.contains(web!.playerPos))! && wordToCollect != ""{
                if wordToCollect == "END" {
                    if collectedWords.count == ((web?.wordPath.count)! - 1) {
                        // Check if all words have been collected
                        // End game. No more words
                        web?.setWord(x, y, "")
                        wordLabelList[x][y].text = ""
                        endGame()
                    } else {
                        // There are still words in matrix
                        messageLabel.displayMessage("Collect all words", duration: 5, gameName)
                    }
                } else {
                    // Collect word
                    collectedWords.append(wordToCollect!)
                    web?.setWord(x, y, "")
                    let wordLabel = wordLabelList[x][y]
                    
                    // Animate scale with crossfade
                    enlargeWithCrossFade(wordLabel)
                    
                    // Speak word out loud
                    let synthesizer = AVSpeechSynthesizer()
                    let utterance: AVSpeechUtterance = AVSpeechUtterance(string: wordToCollect!)
                    synthesizer.speak(utterance)
                    
                    // Hide in UI
                    wordLabel.text = ""
                    
                    // Add to score
                    score += (web?.scoreMatrix[x][y])!
                }
            }
        }
    }
    
    /// Draws player in the middle of two positions
    func drawPlayerInMidPos(_ x: Int, _ y: Int, _ translationType: String) {
        if x > (posList.count - 1) || x < 0 || y > (posList[0].count - 1) || y < 0{
            print("Index out of range")
        } else {
            // Move avatar icon to position of graphical square
            let square = posList[x][y]
            if translationType == "left" {
                avatarIcon.frame.origin.x = square.x + 2 * (squareWidth! / 5)
                avatarIcon.frame.origin.y = square.y + (squareWidth! / 5)
            } else if translationType == "right" {
                avatarIcon.frame.origin.x = square.x - 2 * (squareWidth! / 5)
                avatarIcon.frame.origin.y = square.y + (squareWidth! / 5)
            } else if translationType == "up" {
                avatarIcon.frame.origin.x = square.x + (squareWidth! / 5)
                avatarIcon.frame.origin.y = square.y + 4 * (squareWidth! / 5)
            } else {
                avatarIcon.frame.origin.x = square.x + (squareWidth! / 5)
                avatarIcon.frame.origin.y = square.y - (squareWidth! / 5)
            }
        }
    }
    
    /// Draws web in UI
    func drawWeb() {
        // Calculate required datax
        let viewWidth = gameView.frame.width
        let viewHeight = gameView.frame.height
        squareWidth = (viewWidth - 40) / CGFloat(columns!)
        squareHeight = (viewHeight - 40) / CGFloat(rows!)
        
        // Initialize variables
        var posX = CGFloat(20)
        var posY = CGFloat(20)
        
        // Render matrix as an Image View
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: viewWidth, height: viewHeight))
        var graphicalSquareRow = [graphicalSquare]()
        
        let gridImg = renderer.image { ctx in
            ctx.cgContext.setFillColor(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 0))
            ctx.cgContext.setStrokeColor(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1))
            ctx.cgContext.setLineWidth(5)
            
            // Iterate square placement
            for row in 0...(rows! - 1) {
                for column in 0...(columns! - 1) {
                    let rectangle = CGRect(x: posX, y: posY, width: squareWidth!, height: squareHeight!)
                    ctx.cgContext.addRect(rectangle)
                    ctx.cgContext.drawPath(using: .fillStroke)
        
                    // Store graphical square
                    let currentSquare = graphicalSquare(i: row, j: column, x: posX, y: posY)
                    graphicalSquareRow.append(currentSquare)
                    
                    posX += squareWidth!
                }
                posList.append(graphicalSquareRow)
                graphicalSquareRow.removeAll()
                posY += squareHeight!
                posX = CGFloat(20)
            }
        }
        gridView = UIImageView(image: gridImg)
        gameView.addSubview(gridView!)
        drawWordMatrix()
        gameView.bringSubviewToFront(avatarIcon)
    }
    
    /// Draws word matrix in UI
    func drawWordMatrix() {
        let wordMatrix = web?.matrix
        var wordLabelListRow = [UILabel]()
        
        // Create label list
        for i in 0...(wordMatrix!.count - 1) {
            for j in 0...(wordMatrix![0].count - 1) {
                let wordLabel = UILabel(frame: CGRect(x: posList[i][j].x,
                                                      y: posList[i][j].y,
                                                      width: squareWidth!, height: squareHeight!))
                let word = web!.getWord(i, j)
                
                // Add label to UI
                wordLabel.text = word
                wordLabel.textAlignment = .center
                gameView.addSubview(wordLabel)
                wordLabelListRow.append(wordLabel)
            }
            wordLabelList.append(wordLabelListRow)
            wordLabelListRow.removeAll()
        }
    }
    
    /// Ends game
    func endGame() {
        showWinScreen()
        playSound("yay")
    }
    
    /// Enlarges label with cross fade
    func enlargeWithCrossFade(_ label: UILabel) {
        // Copy label to prevent pixelation
        let labelCopy = label.copyLabel()
        gameView.addSubview(labelCopy)
        
        // Access label attributes
        var biggerBounds = CGRect(x: label.frame.origin.x,
                                  y: label.frame.origin.y,
                                  width: gameView.frame.width,
                                  height: gameView.frame.height)
        label.font = label.font.withSize(fontSizeBig)
        biggerBounds.size = CGSize(width: gameView.frame.width, height: gameView.frame.height)
        labelCopy.textAlignment = .center
        
        // Modify element transform
        label.transform = scaleTransform(from: biggerBounds.size, to: label.bounds.size)
        let enlargeTransform = scaleTransform(from: label.bounds.size, to: biggerBounds.size)
        label.bounds = biggerBounds
        label.alpha = 0.0
        
        // Animate enlarge
        UIView.animate(withDuration: animationDuration, animations: {
            label.transform = .identity
            labelCopy.transform = enlargeTransform
        }, completion: { done in
            labelCopy.removeFromSuperview()
        })
        
        // Animate shrink
        UIView.animate(withDuration: animationDuration + 2) {
            label.alpha = 1.0
            labelCopy.alpha = 0.0
        }
    }
    
    /// Loads objects in scene
    func loadObjects() {
        loadReality()
        loadRobot()
    }
    
    /// Initializes attributes locally
    func initializeOfflineAttributes() {
        // Generate random spider web
        let possibleDimensionList = [5, 6]
        let dimensions = possibleDimensionList.randomElement()
        columns = dimensions!
        rows = dimensions!
        disableUI(true)
        
        // Load matrix
        messageLabel.text = "Loading..."
        web = SpiderWeb(dimensions!, dimensions!, isOnline: false)
        messageLabel.displayMessage("Ready!", duration: 3, gameName)
        disableUI(false)
    }
    
    /// Initializes attributes from server
    func initializeOnlineAttributes() {
        // Connect to server to update holder
        messageLabel.text = "Connecting..."
        
        // Try to connect to server
        do{
            holder = connectToServer()
            if !holder.connectionSuccess! {
                // Error connecting. Redirect to offline mode
                isOnline = false
                initializeOfflineAttributes()
                messageLabel.displayMessage("Error connecting. Offline.", duration: 10, self.gameName)
            } else {
                // Connection to server success
                // Get matrix information from holder
                
                let webInstructions = holder.spiderWebLetterInstructions
                let scoreInstructions = holder.spiderWebPointsInstructions
                rows = holder.spiderWebLetterInstructions?.count
                columns = holder.spiderWebLetterInstructions?[0].count
                
                // Initalize word and score matrix
                web = SpiderWeb(rows!, columns!, isOnline: true)
                web?.initializeOnlineMatrix(webInstructions!, scoreInstructions!)
                
                messageLabel.displayMessage("Connected", duration: 3, self.gameName)
            }
        }
    }
    
    /// Loads default elements in AR
    func loadReality() {
        // Assign entities and model entities
        upBall = experienceScene.upBall!
        downBall = experienceScene.downBall!
        leftBall = experienceScene.leftBall!
        rightBall = experienceScene.rightBall!
        leftBoxUp = experienceScene.leftBoxUp!
        rightBoxUp = experienceScene.rightBoxUp!
        leftBox = experienceScene.leftBox!
        rightBox = experienceScene.rightBox!
        
        // Anchor entities
        characterAnchor.addChild(upBall)
        characterAnchor.addChild(downBall)
        characterAnchor.addChild(leftBall)
        characterAnchor.addChild(rightBall)
        characterAnchor.addChild(leftBoxUp)
        characterAnchor.addChild(rightBoxUp)
        characterAnchor.addChild(leftBox)
        characterAnchor.addChild(rightBox)
        
        // Add body tracked character and objects
        arView.scene.addAnchor(characterAnchor)
    }
    
    /// Loads body tracked robot character
    func loadRobot() {
        // Asynchronously load the 3D character.
        var cancellable: AnyCancellable? = nil
        cancellable = Entity.loadBodyTrackedAsync(named: "models/robot").sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    // Model couldn't be lodad
                    print("Error: Unable to load model: \(error.localizedDescription)")
                }
                cancellable?.cancel()
        }, receiveValue: { (character: Entity) in
            if let character = character as? BodyTrackedEntity {
                // Scale the character to human size
                character.scale = [1.0, 1.0, 1.0]
                
                self.character = character
                cancellable?.cancel()
            } else {
                // Couldn't load model as a body
                print("Error: Unable to load model as BodyTrackedEntity")
            }
        })
    }
    
    @IBAction func onStartButtonTap(_ sender: Any) {
        startGame()
    }
    
    /// Plays sounds
    func playSound(_ sound: String) {
        switch sound {
        case "hit":
            if let soundURL = Bundle.main.url(forResource: "hit", withExtension: "mp3") {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                }
                catch {
                    print(error)
                }
                audioPlayer.play()
            } else {
                print("Unable to locate audio file")
            }
        case "yay":
            if let soundURL = Bundle.main.url(forResource: "yay", withExtension: "mp3") {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                }
                catch {
                    print(error)
                }
                audioPlayer.play()
            } else {
                print("Unable to locate audio file")
            }
        default:
            print("No sound found")
        }
    }
    
    /// Scale transform of UI element
    private func scaleTransform(from: CGSize, to: CGSize) -> CGAffineTransform {
        let scaleX = to.width / from.width
        let scaleY = to.height / from.height
        
        return CGAffineTransform(scaleX: scaleX, y: scaleY)
    }
    
    /// Shows animated view screen
    func showWinScreen() {
        blurView.alpha = 0
        blurView.isHidden = false
        blurView.fadeIn()
        isOver = true
        scoreLabel.text = "Score - " + String(score)
        messageLabel.text = "Congratulations!"
        disableUI(false)
        
        // Start speech recognition
        if !isOnline! {
            categoryAnswerLabel.isHidden = false
            categoryGuessLabel.isHidden = false
//            do {
//                try startSpeechRecognition()
//            } catch {
//                print("Error starting spech recognition")
//            }
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(7)) {
//                // Wait 7 seconds to enable next
//                self.startButton.isEnabled = true
//                self.stopSpeechRecognition()
//            }
        }
    }
    
    /// Signal down movement in UI
    func signalDown() {
        // Verify that you have to touch twice to advance, to simulate and out of bounds situation
        halfAPress.1 += 1
        if halfAPress.1 == 1 {
            // Draw player in middle position from origin to target
            halfAPress.0 = "down"
            drawPlayerInMidPos((web?.playerPos[0])! + 1, (web?.playerPos[1])!, "down")
        } else if halfAPress.1 > 1 && halfAPress.0 == "down" {
            // Move player in UI
            drawPlayer((web?.playerPos[0])! + 1, (web?.playerPos[1])!)
            halfAPress.0 = ""
            halfAPress.1 = 0
        } else {
            messageLabel.displayMessage("Out of bounds. Move " + halfAPress.0, duration: 3, gameName)
        }
    }
    
    /// Signal left movement in UI
    func signalLeft() {
        // Verify that you have to touch twice to advance, to simulate and out of bounds situation
        halfAPress.1 += 1
        if halfAPress.1 == 1 {
            // Draw player in middle position from origin to target
            halfAPress.0 = "left"
            drawPlayerInMidPos((web?.playerPos[0])!, (web?.playerPos[1])! - 1, "left")
        } else if halfAPress.1 > 1 && halfAPress.0 == "left" {
            // Move player in UI
            drawPlayer((web?.playerPos[0])!, (web?.playerPos[1])! - 1)
            halfAPress.0 = ""
            halfAPress.1 = 0
        } else {
            messageLabel.displayMessage("Out of bounds. Move " + halfAPress.0, duration: 3, gameName)
        }
    }
    
    /// Signal right movement in UI
    func signalRight() {
        // Verify that you have to touch twice to advance, to simulate and out of bounds situation
        halfAPress.1 += 1
        if halfAPress.1 == 1 {
            // Draw player in middle position from origin to target
            halfAPress.0 = "right"
            drawPlayerInMidPos((web?.playerPos[0])!, (web?.playerPos[1])! + 1, "right")
        } else if halfAPress.1 > 1 && halfAPress.0 == "right" {
            // Move player in UI
            drawPlayer((web?.playerPos[0])!, (web?.playerPos[1])! + 1)
            halfAPress.0 = ""
            halfAPress.1 = 0
        } else {
            messageLabel.displayMessage("Out of bounds. Move " + halfAPress.0, duration: 3, gameName)
        }
    }
    
    /// Signal up movement in UI
    func signalUp() {
        // Verify that you have to touch twice to advance, to simulate and out of bounds situation
        halfAPress.1 += 1
        if halfAPress.1 == 1 {
            // Draw player in middle position from origin to target
            halfAPress.0 = "up"
            drawPlayerInMidPos((web?.playerPos[0])! - 1, (web?.playerPos[1])!, "up")
        } else if halfAPress.1 > 1 && halfAPress.0 == "up" {
             // Move player in UI
            drawPlayer((web?.playerPos[0])! - 1, (web?.playerPos[1])!)
            halfAPress.0 = ""
            halfAPress.1 = 0
        } else {
            messageLabel.displayMessage("Out of bounds. Move " + halfAPress.0, duration: 3, gameName)
        }
    }
    
    /// Start collision detection system for current floating object
    func startCollisions() {
        // Subscribe scene to collision events
        // Signal up
        arView.scene.subscribe(
            to: CollisionEvents.Began.self,
            on: upBall
        ) { event in
            self.signalUp()
            self.playSound("hit")
        }.store(in: &collisionEventStreams)
        
        // Signal down
        arView.scene.subscribe(
            to: CollisionEvents.Began.self,
            on: downBall
        ) { event in
            self.signalDown()
            self.playSound("hit")
        }.store(in: &collisionEventStreams)
        
        // Signal left
        arView.scene.subscribe(
            to: CollisionEvents.Began.self,
            on: leftBall
        ) { event in
            self.signalLeft()
            self.playSound("hit")
        }.store(in: &collisionEventStreams)
        
        // Signal right
        arView.scene.subscribe(
            to: CollisionEvents.Began.self,
            on: rightBall
        ) { event in
            self.signalRight()
            self.playSound("hit")
        }.store(in: &collisionEventStreams)
    }
    
    /// Starts game
    func startGame() {
        if !isOver {
            if !bodyAnchorExists {
                // Body doesn't yet exist
                messageLabel.displayMessage("No person detected", duration: 5, gameName)
            } else {
                // Draw web in UI
                drawWeb()
                
                // Start collision detection
                if isFirstTime {
                    startCollisions()
                    isFirstTime = false
                    drawPlayer((web?.midPos[0])!, (web?.midPos[1])!)
                }
                
                startButton.isEnabled = false
            }
        } else {
            // Restart game
            blurView.fadeOut()
            isOver = false
            if !isOnline! {
                web?.restartWeb(isOnline: false)
            } else {
                web?.restartWeb(isOnline: true)
                initializeOnlineAttributes()
            }
            score = 0
            halfAPress = ("", 0)
            categoryGuessLabel.text = "Your guess: "
            categoryAnswerLabel.text = "Answer: "
            
            // Clear lists
            collectedWords.removeAll()
            posList.removeAll()
            clearGrid()
            wordLabelList.removeAll()
            
            // Reinitialize attributes
            if isOnline! {
                initializeOnlineAttributes()
            } else {
                initializeOfflineAttributes()
            }
            
            startGame()
            drawPlayer((web?.midPos[0])!, (web?.midPos[1])!)
        }
    }
    
    /// Starts speech recognition
    func startSpeechRecognition() throws {
        // Cancel previous tasks
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Initialize variables
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options:  .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.request?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else {
            fatalError("Unable to create request object")
            
        }
        request.shouldReportPartialResults = true
        
        // Enable iOS 13 on-device speech recognition
        if #available(iOS 13, *) {
            if speechRecognizer?.supportsOnDeviceRecognition ?? false {
                request.requiresOnDeviceRecognition = true
            }
        }
        
        // Send and receive request
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    let bestString = result.bestTranscription.formattedString
                    
                    // Show guess and answer on UI
                    self.categoryGuessLabel.text = "Your guess: " + bestString
                    self.categoryAnswerLabel.text = "Answer: " + self.web!.category
                }
            }
            if error != nil {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.request = nil
                self.recognitionTask = nil
            }
        }
    }
    
    func stopSpeechRecognition() {
        self.audioEngine.stop()
        self.request = nil
        self.recognitionTask = nil
    }
    
    // MARK: - View Control
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Prevent screen lock
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Name anchors
        character?.name = "Jackie"
        characterAnchor.name = "Character Anchor"
        
        // Load Reality Composer scene and objects
        experienceScene = try! Experience.loadScene()
        
        // Set speech recognition
        speechRecognizer?.delegate = self
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            switch authStatus {
            case .authorized:
                self.hasSpeechRecognition = true
                print("Speech recognition initiated")
            case .denied:
                print("User denied access to speech recognition")
            case .restricted:
                print("Speech recognition restricted on this device")
            case .notDetermined:
                print("Speech recognition not yet authorized")
            @unknown default:
                print("Error loading speech recognition")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        arView.session.delegate = self
        
        // If the iOS device doesn't support body tracking, raise a developer error
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }

        // Run a body tracking configuration for session
        let configuration = ARBodyTrackingConfiguration()
        
        arView.session.run(configuration)
        
        // Load objects in scene
        loadObjects()
        
        // Initialize Attributes
        if isOnline! {
            initializeOnlineAttributes()
        } else {
            initializeOfflineAttributes()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    // MARK: - Session Control
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Print when new anchor is added
        if !anchors.isEmpty {
            anchors.forEach { (anchor) in
                print("""
                      The Type Of Anchor = \(anchor.classForCoder)
                      The Anchor Identifier = \(anchor.identifier)
                      The Anchor Translation = X: \(anchor.transform.columns.3.x), Y: \(anchor.transform.columns.3.y), Z: \(anchor.transform.columns.3.z)
                      """)
                if anchor is ARBodyAnchor {
                    // ARBodyAnchor is detected. Notify class
                    bodyAnchorExists = true
                }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Iterate over all detected anchors
        for anchor in anchors {
            if anchor is ARBodyAnchor {
                let bodyAnchor = anchor as! ARBodyAnchor
                
                // Tracked body data in skeleton
                let skeleton = bodyAnchor.skeleton
                
                // Obtain position and orientation with anchor data
                let bodyOrientation = Transform(matrix: bodyAnchor.transform).rotation
                let leftHandMidStartPos = simd_make_float3(skeleton.jointModelTransforms[29].columns.3)
                let leftFootPos = simd_make_float3(skeleton.jointModelTransforms[5].columns.3)
                let rightFootPos = simd_make_float3(skeleton.jointModelTransforms[10].columns.3)
                let rightHandMidStartPos = simd_make_float3(skeleton.jointModelTransforms[73].columns.3)
                let rootPos = simd_make_float3(skeleton.jointModelTransforms[0].columns.3)
                bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
                
                // Update position and orientation of elements
                characterAnchor.position = bodyPosition!
                characterAnchor.orientation = bodyOrientation
                
                // Place balls control panel in the air
                upBall.position = rootPos + [-0.4, -0.8, 0.3]
                leftBall.position = rootPos + [0.7, 0, 0]
                rightBall.position = rootPos + [-0.7, 0, 0]
                downBall.position = rootPos + [0.4, -0.8, 0.3]
                leftBox.position = leftFootPos
                rightBox.position = rightFootPos
                leftBoxUp.position = leftHandMidStartPos
                rightBoxUp.position = rightHandMidStartPos
                
//                // Attach character to anchor
//                if let character = character, character.parent == nil {
//                    characterAnchor.addChild(character)
//                }
            }
        }
    }
    
}
