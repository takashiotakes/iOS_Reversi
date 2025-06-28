import Foundation
import SwiftUI
import AVFoundation // サウンド再生用

// MARK: - Enum, Struct Definitions

enum Player: String, Codable {
    case black
    case white

    var opponent: Player {
        self == .black ? .white : .black
    }
    
    var displayName: String {
        self == .black ? "Black" : "White"
    }
    
    var symbol: String {
        // Based on darkMode for consistent display in kifu
        // This needs to be handled within the view or kifu generation based on darkMode state
        return self == .black ? "⚫︎" : "⚪︎" // Unicode circles for black/white
    }
}

enum PlayerType: String, Codable, CaseIterable, Identifiable {
    case human
    case ai
    
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .human: return "Human"
        case .ai: return "AI"
        }
    }
}

typealias Cell = Player?

struct Move: Codable {
    let board: [[Cell]]
    let player: Player // This player's turn comes after this move
    let movePos: [Int]? // Coordinates of the move made, null if pass
    let isAIMove: Bool // Flag to indicate if this move was made by AI or human
}

struct KifuEntry: Identifiable {
    let id = UUID()
    let move: Int
    let player: String
    let coordinate: String
}

// MARK: - iOS_ReversiGameViewModel Class

class iOS_ReversiGameViewModel: ObservableObject {
    // MARK: - Published Properties (UIを更新するために監視される)
    @Published var currentBoard: [[Cell]]
    @Published var currentPlayer: Player
    @Published var gameResult: String?
    @Published var blackCount: Int
    @Published var whiteCount: Int
    @Published var darkMode: Bool
    @Published var flippedStones: [[Int]] // `[]` はプロパティ宣言時に初期化されるため不要
    @Published var showHint: Bool
    @Published var hintMove: [Int]?

    // Game Settings
    @Published var firstPlayerType: PlayerType
    @Published var secondPlayerType: PlayerType
    @Published var aiDepth: Int
    
    @Published var isProcessingAIMove: Bool

    // MARK: - Private Properties
    private var history: [Move]
    private var currentMoveIndex: Int
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Computed Properties
    var canUndo: Bool { currentMoveIndex > 0 }
    var canRedo: Bool { currentMoveIndex < history.count - 1 }
    var isValidMoveList: [[Int]] {
        getValidMoves(board: currentBoard, player: currentPlayer)
    }
    
    var isHumanPlayerTurn: Bool {
        (currentPlayer == .black && firstPlayerType == .human) ||
        (currentPlayer == .white && secondPlayerType == .human)
    }

    var turnMessage: String {
        if let result = gameResult {
            return result // ゲーム終了時は結果メッセージのみ
        }
        
        let playerTypeDisplay = (currentPlayer == .black ? firstPlayerType : secondPlayerType).displayName
        return "\(playerTypeDisplay)'s Turn (\(currentPlayer.displayName))"
    }
    
    var kifuData: [KifuEntry] {
        generateKifuData()
    }

    // MARK: - Initializer
    init() {
        // MARK: - Step 1: Initialize all stored properties *first*
        self.currentBoard = Array(repeating: Array(repeating: nil, count: 8), count: 8) // 一時的な初期値
        self.currentPlayer = .black
        self.gameResult = nil
        self.blackCount = 0 // 後で正しい数に更新
        self.whiteCount = 0 // 後で正しい数に更新
        self.darkMode = false
        self.flippedStones = [] // プロパティ宣言で初期化済みだが、明示的に
        self.showHint = false // プロパティ宣言で初期化済み
        self.hintMove = nil // プロパティ宣言で初期化済み
        self.firstPlayerType = .human
        self.secondPlayerType = .ai
        self.aiDepth = 3
        self.isProcessingAIMove = false
        self.history = [] // 一時的な初期値
        self.currentMoveIndex = 0
        self.audioPlayer = nil // 後でロード

        // MARK: - Step 2: Now that `self` is fully initialized, call methods on `self` and finalize properties
        let initialBoardState = initialBoard() // これで`initialBoard()`が安全に呼び出せる
        self.currentBoard = initialBoardState // 実際の初期ボードを設定
        
        // 初期ボードに基づき石の数を更新
        self.blackCount = 2
        self.whiteCount = 2
        
        // 履歴の最初の状態を設定
        self.history = [Move(board: initialBoardState, player: .black, movePos: nil, isAIMove: false)]
        
        // サウンドファイルのロード
        if let url = Bundle.main.url(forResource: "flip", withExtension: "mp3") {
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.prepareToPlay()
            } catch {
                print("Error loading sound file: \(error.localizedDescription)")
            }
        } else {
            print("Sound file 'flip.mp3' not found in bundle.")
        }
        
        // 最初のAIのターンをチェック (UIが更新された後に実行されるように非同期で)
        DispatchQueue.main.async {
            self.checkGameLogic()
        }
    }

    // MARK: - Game Logic Functions

    // Function to initialize the Reversi board
    private func initialBoard() -> [[Cell]] {
        var board: [[Cell]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        board[3][3] = .white
        board[3][4] = .black
        board[4][3] = .black
        board[4][4] = .white
        return board
    }

    // Checks if the given coordinates are within the board boundaries
    private func isOnBoard(x: Int, y: Int) -> Bool {
        x >= 0 && x < 8 && y >= 0 && y < 8
    }

    // Generates a list of valid moves for the current board and player
    private func getValidMoves(board: [[Cell]], player: Player) -> [[Int]] {
        let opponent = player.opponent
        var moves: [[Int]] = []

        for y in 0..<8 {
            for x in 0..<8 {
                if board[y][x] != nil { continue }

                for (dx, dy) in directions {
                    var nx = x + dx
                    var ny = y + dy
                    var hasOpponent = false

                    while isOnBoard(x: nx, y: ny) && board[ny][nx] == opponent {
                        nx += dx
                        ny += dy
                        hasOpponent = true
                    }

                    if hasOpponent && isOnBoard(x: nx, y: ny) && board[ny][nx] == player {
                        moves.append([x, y])
                        break
                    }
                }
            }
        }
        return moves
    }

    // Applies a move and flips stones on the board
    private func applyMove(board: [[Cell]], x: Int, y: Int, player: Player) -> (newBoard: [[Cell]], flippedCoords: [[Int]]) {
        var newBoard = board
        let opponent = player.opponent
        newBoard[y][x] = player

        var flippedCoordinates: [[Int]] = []

        for (dx, dy) in directions {
            var nx = x + dx
            var ny = y + dy
            var stonesInLine: [[Int]] = []

            while isOnBoard(x: nx, y: ny) && newBoard[ny][nx] == opponent {
                stonesInLine.append([nx, ny])
                nx += dx
                ny += dy
            }

            if isOnBoard(x: nx, y: ny) && newBoard[ny][nx] == player {
                // 修正箇所: for ループの構文
                for stoneCoord in stonesInLine {
                    let fx = stoneCoord[0]
                    let fy = stoneCoord[1]
                    newBoard[fy][fx] = player
                    flippedCoordinates.append([fx, fy])
                }
            }
        }
        return (newBoard, flippedCoords: flippedCoordinates)
    }

    // Plays the flip sound
    private func playFlipSound() {
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
    
    // Evaluates the board and returns a score (for AI)
    private func evaluateBoard(board: [[Cell]], player: Player) -> Int {
        let opponent = player.opponent
        var score = 0
        for y in 0..<8 {
            for x in 0..<8 {
                if board[y][x] == player {
                    score += positionWeights[y][x]
                } else if board[y][x] == opponent {
                    score -= positionWeights[y][x]
                }
            }
        }
        return score
    }

    // Minimax algorithm (simplified for Swift)
    private func minimax(board: [[Cell]], depth: Int, maximizing: Bool, player: Player, alpha: Int, beta: Int) -> (x: Int, y: Int, score: Int) {
        let validMoves = getValidMoves(board: board, player: player)
        
        if depth == 0 || validMoves.isEmpty {
            return (-1, -1, evaluateBoard(board: board, player: player))
        }

        // 修正: bestMoveをタプルとして定義
        var bestMove: (Int, Int) = (-1, -1)
        var currentBestScore = maximizing ? -Int.max : Int.max
        var currentAlpha = alpha
        var currentBeta = beta

        for move in validMoves {
            let (x, y) = (move[0], move[1])
            let (simulatedBoard, _) = applyMove(board: board, x: x, y: y, player: player)
            let (_, _, score) = minimax(board: simulatedBoard, depth: depth - 1, maximizing: !maximizing, player: player.opponent, alpha: currentAlpha, beta: currentBeta)

            if maximizing {
                if score > currentBestScore {
                    currentBestScore = score
                    // 修正: bestMoveをタプルとして代入
                    bestMove = (x, y)
                }
                currentAlpha = max(currentAlpha, currentBestScore)
            } else {
                if score < currentBestScore {
                    currentBestScore = score
                    // 修正: bestMoveをタプルとして代入
                    bestMove = (x, y)
                }
                currentBeta = min(currentBeta, currentBestScore)
            }
            if currentBeta <= currentAlpha { break }
        }
        // 修正: bestMoveの要素に.0と.1でアクセス
        return (bestMove.0, bestMove.1, currentBestScore)
    }

    // Counts stones of a specific color
    private func countStones(board: [[Cell]], color: Player) -> Int {
        board.flatMap { $0 }.filter { $0 == color }.count
    }
    
    // MARK: - UI Actions

    func makeMove(x: Int, y: Int) {
        // Human player logic
        guard isHumanPlayerTurn else { return }
        guard isValidMove(x: x, y: y) else { return }

        let (newBoard, flippedCoords) = applyMove(board: currentBoard, x: x, y: y, player: currentPlayer)
        playFlipSound()
        
        // アニメーション用のフリップ石座標をセット
        flippedStones = flippedCoords
        
        // 履歴を更新 (現在の位置から新しい手を追加)
        history.removeSubrange(currentMoveIndex + 1..<history.count)
        history.append(Move(board: newBoard, player: currentPlayer.opponent, movePos: [x, y], isAIMove: false))
        currentMoveIndex += 1
        
        // 状態を更新
        currentBoard = newBoard
        currentPlayer = currentPlayer.opponent
        
        // ヒントを非表示にする
        showHint = false
        hintMove = nil
        
        updateCountsAndCheckGameEnd()
        
        // アニメーション終了後にフリップ石座標をクリア
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.flippedStones = []
        }
        
        // 次のAIのターンがあれば実行
        performAIMoveIfNeeded()
    }
    
    func resetGame() {
        let initial = initialBoard()
        currentBoard = initial
        currentPlayer = .black
        // 修正: Move構造体のインスタンスを明示的に作成
        history = [Move(board: initial, player: .black, movePos: nil, isAIMove: false)]
        currentMoveIndex = 0
        gameResult = nil
        blackCount = 2
        whiteCount = 2
        darkMode = false
        firstPlayerType = .human
        self.secondPlayerType = .ai
        self.aiDepth = 3
        
        DispatchQueue.main.async { // UIが更新されてからAI処理をチェック
            self.checkGameLogic()
        }
    }

    func undoMove() {
        guard currentMoveIndex > 0 else { return }
        
        // AI vs AI モードの場合、単純に1つ戻る
        if firstPlayerType == .ai && secondPlayerType == .ai {
            currentMoveIndex -= 1
        } else {
            // 人間がプレイするモードの場合、人間のターンまで巻き戻す
            var targetIndex = currentMoveIndex - 1
            while targetIndex >= 0 {
                let playerWhoseTurnItIs = history[targetIndex].player // この状態の次のターン
                let isThisStateForHumanPlayer =
                    (playerWhoseTurnItIs == .black && firstPlayerType == .human) ||
                    (playerWhoseTurnItIs == .white && secondPlayerType == .human)

                if isThisStateForHumanPlayer || targetIndex == 0 {
                    currentMoveIndex = targetIndex
                    break
                }
                targetIndex -= 1
            }
        }
        applyHistoryState()
    }

    func redoMove() {
        guard currentMoveIndex < history.count - 1 else { return }
        
        // AI vs AI モードの場合、単純に1つ進む
        if firstPlayerType == .ai && secondPlayerType == .ai {
            currentMoveIndex += 1
        } else {
            // 人間がプレイするモードの場合、次の人間のターンまで進む
            var targetIndex = currentMoveIndex + 1
            while targetIndex < history.count {
                let playerWhoseTurnItIsNext = history[targetIndex].player
                let isNextPlayerHuman =
                    (playerWhoseTurnItIsNext == .black && firstPlayerType == .human) ||
                    (playerWhoseTurnItIsNext == .white && secondPlayerType == .human)

                if isNextPlayerHuman {
                    currentMoveIndex = targetIndex
                    break
                }
                targetIndex += 1
            }
            if targetIndex >= history.count { // 履歴の最後まで行った場合
                currentMoveIndex = history.count - 1
            }
        }
        applyHistoryState()
    }

    // Apply the state from history to current properties
    private func applyHistoryState() {
        let state = history[currentMoveIndex]
        currentBoard = state.board
        currentPlayer = state.player
        gameResult = nil
        flippedStones = []
        showHint = false
        hintMove = nil
        isProcessingAIMove = false // 履歴を操作したらAI処理フラグをリセット
        updateCountsAndCheckGameEnd() // カウントを更新し、ゲーム終了を再チェック
        
        // 履歴操作後にAIのターンであればAIを動かす
        DispatchQueue.main.async { // UIが更新されてからAI処理をチェック
            self.checkGameLogic()
        }
    }

    func toggleDarkMode() {
        darkMode.toggle()
    }
    
    func toggleHint() {
        guard isHumanPlayerTurn && !isProcessingAIMove && gameResult == nil else {
            if showHint { // ヒントが表示されていて、表示条件が満たされない場合は非表示にする
                showHint = false
                hintMove = nil
            }
            return
        }

        if showHint {
            showHint = false
            hintMove = nil
        } else {
            let movesForCurrentPlayer = getValidMoves(board: currentBoard, player: currentPlayer)
            if movesForCurrentPlayer.isEmpty {
                // SwiftUIではアラートを直接表示せず、別の状態変数で管理しビューで表示する
                gameResult = "No moves available. Current player must pass."
                return
            }
            
            // バックグラウンドでAIに最適な手を選ばせる
            isProcessingAIMove = true
            DispatchQueue.global(qos: .userInitiated).async {
                // 修正: minimaxからの戻り値をタプルで受け取る
                let (bestX, bestY, _) = self.minimax(board: self.currentBoard, depth: self.aiDepth, maximizing: true, player: self.currentPlayer, alpha: -Int.max, beta: Int.max)
                
                DispatchQueue.main.async {
                    if bestX != -1 && bestY != -1 {
                        self.hintMove = [bestX, bestY]
                        self.showHint = true
                    } else {
                        self.gameResult = "Could not calculate optimal move for hint."
                    }
                    self.isProcessingAIMove = false
                }
            }
        }
    }


    // MARK: - Internal Helper Functions

    // Update stone counts and check for game end conditions
    private func updateCountsAndCheckGameEnd() {
        blackCount = countStones(board: currentBoard, color: .black)
        whiteCount = countStones(board: currentBoard, color: .white)
        
        let movesForCurrent = getValidMoves(board: currentBoard, player: currentPlayer)
        let movesForOpponent = getValidMoves(board: currentBoard, player: currentPlayer.opponent)

        // Game End Conditions
        if blackCount == 0 || whiteCount == 0 || (movesForCurrent.isEmpty && movesForOpponent.isEmpty) || (currentMoveIndex >= 60 && currentBoard.flatMap{$0}.count >= 60) {
            if blackCount > whiteCount {
                gameResult = "Black wins!"
            } else if whiteCount > blackCount {
                gameResult = "White wins!"
            } else {
                gameResult = "Draw!"
            }
            isProcessingAIMove = false // ゲーム終了時はAI処理を停止
            showHint = false // ゲーム終了時はヒントを非表示
            hintMove = nil
            return
        }
        
        // Pass condition (only if current player has no valid moves)
        if movesForCurrent.isEmpty && gameResult == nil { // gameResultがnilの場合はまだゲームが続いている
            // Alert user or automatically pass
            gameResult = "\(currentPlayer.displayName) has no valid moves. Passing turn to \(currentPlayer.opponent.displayName)."
            
            // AIが処理中の場合はこのパス処理はAI_MoveIfNeededで吸収される
            if !isProcessingAIMove {
                // 人間がパスする場合、少し遅延させて次のAIターンを呼ぶ
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.performPass()
                }
            }
        } else {
            gameResult = nil // ゲームが続行する場合、結果メッセージをクリア
        }
    }
    
    // Executes a pass action
    private func performPass() {
        guard !isProcessingAIMove else { return } // 既にAI処理中なら重複しない
        isProcessingAIMove = true // パス処理中を設定
        
        let passMove = Move(board: currentBoard, player: currentPlayer.opponent, movePos: nil, isAIMove: (currentPlayer == .black && firstPlayerType == .ai) || (currentPlayer == .white && secondPlayerType == .ai))
        
        history.removeSubrange(currentMoveIndex + 1..<history.count)
        history.append(passMove)
        currentMoveIndex += 1
        currentPlayer = currentPlayer.opponent // 次のプレイヤーへ
        
        // UI更新は自動的に行われるため、特にここでの変更は不要
        updateCountsAndCheckGameEnd()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // 少し待ってAI処理フラグを解除
            self.isProcessingAIMove = false
            self.checkGameLogic() // パス後に次のAIのターンをチェック
        }
    }

    // This method is called after any state change that might require AI to act
    func checkGameLogic() {
        updateCountsAndCheckGameEnd() // 最新のボード状態とカウントを更新

        // 既にゲームが終了している場合は何もしない
        guard gameResult == nil else {
            return
        }
        
        // 履歴の最新位置にいる場合のみAIを動かす
        guard currentMoveIndex == history.count - 1 else { return }
        
        // AIのターンであればAIを動かす
        performAIMoveIfNeeded()
    }
    
    // AIのターンであれば自動的に手を打つ
    private func performAIMoveIfNeeded() {
        guard gameResult == nil else { return } // ゲームが終了していたら何もしない

        let movesForCurrentPlayer = getValidMoves(board: currentBoard, player: currentPlayer)
        
        let isAIPlayer = (currentPlayer == .black && firstPlayerType == .ai) || (currentPlayer == .white && secondPlayerType == .ai)
        
        // AIのターンであり、まだ処理中でなく、かつ有効な手がある場合
        if isAIPlayer && !isProcessingAIMove {
            if movesForCurrentPlayer.isEmpty {
                // AIに有効な手がない場合、パスする
                gameResult = "\(currentPlayer.displayName) (AI) has no valid moves. Passing turn to \(currentPlayer.opponent.displayName)."
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.performPass()
                }
                return
            }
            
            isProcessingAIMove = true // AI処理中フラグを設定
            showHint = false // AIが動くときはヒントを隠す
            hintMove = nil

            // バックグラウンドスレッドでAIの計算を実行
            DispatchQueue.global(qos: .userInitiated).async {
                let (bestX, bestY, _) = self.minimax(board: self.currentBoard, depth: self.aiDepth, maximizing: true, player: self.currentPlayer, alpha: -Int.max, beta: Int.max)
                
                // メインスレッドでUIを更新
                DispatchQueue.main.async {
                    if bestX != -1 && bestY != -1 {
                        let (newBoard, flippedCoords) = self.applyMove(board: self.currentBoard, x: bestX, y: bestY, player: self.currentPlayer)
                        self.playFlipSound()
                        
                        self.flippedStones = flippedCoords // フリップアニメーション用
                        
                        self.history.removeSubrange(self.currentMoveIndex + 1..<self.history.count)
                        self.history.append(Move(board: newBoard, player: self.currentPlayer.opponent, movePos: [bestX, bestY], isAIMove: true))
                        self.currentMoveIndex += 1
                        
                        self.currentBoard = newBoard
                        self.currentPlayer = self.currentPlayer.opponent
                        
                        self.updateCountsAndCheckGameEnd()
                        
                        // アニメーション終了後にフリップ石座標をクリア
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.flippedStones = []
                            self.isProcessingAIMove = false // AI処理終了
                            self.checkGameLogic() // 次のターンもAIなら再度呼び出す
                        }
                    } else {
                        self.gameResult = "AI could not find a valid move."
                        self.isProcessingAIMove = false
                    }
                }
            }
        } else if !isAIPlayer && !movesForCurrentPlayer.isEmpty {
            // ... (既存のロジック)
        }
    }

    // Valid move check for UI
    func isValidMove(x: Int, y: Int) -> Bool {
        return isValidMoveList.contains(where: { $0[0] == x && $0[1] == y })
    }
    
    // Generates Kifu data
    private func generateKifuData() -> [KifuEntry] {
        var kifuEntries: [KifuEntry] = []
        for i in 1...currentMoveIndex {
            let moveRecord = history[i]
            let playerWhoMoved = history[i-1].player

            let playerSymbol = darkMode ? playerWhoMoved.opponent.symbol : playerWhoMoved.symbol
            let playerText = "\(playerSymbol) \(playerWhoMoved.displayName)"
            
            var coordinateText = "-"
            if let movePos = moveRecord.movePos {
                let col = Character(UnicodeScalar(65 + movePos[0])!)
                let row = movePos[1] + 1
                coordinateText = "\(col)\(row)"
            } else {
                coordinateText = "PASS"
            }
            
            kifuEntries.append(KifuEntry(move: i, player: playerText, coordinate: coordinateText))
        }
        return kifuEntries
    }
}


// MARK: - Constants and Helper Extensions

// Directions for checking stone flips
fileprivate let directions = [
    (0, 1), (1, 0), (0, -1), (-1, 0), // Straight
    (1, 1), (-1, -1), (1, -1), (-1, 1) // Diagonal
]

// Evaluation values for each cell (used for AI's thinking)
fileprivate let positionWeights = [
    [100, -20, 10, 5, 5, 10, -20, 100],
    [-20, -50, -2, -2, -2, -2, -50, -20],
    [10, -2, -1, -1, -1, -1, -2, 10],
    [5, -2, -1, -1, -1, -1, -2, 5],
    [5, -2, -1, -1, -1, -1, -2, 5],
    [10, -2, -1, -1, -1, -1, -2, 10],
    [-20, -50, -2, -2, -2, -2, -50, -20],
    [100, -20, 10, 5, 5, 10, -20, 100],
]

// Extend Color for convenience (e.g., .darkGray)
extension Color {
    static let darkGray = Color(red: 0.2, green: 0.2, blue: 0.2)
}
