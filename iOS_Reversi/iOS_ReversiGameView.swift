import SwiftUI

struct iOS_ReversiGameView: View {
    @ObservedObject var viewModel = iOS_ReversiGameViewModel()
    @Environment(\.colorScheme) var colorScheme // システムのカラーモードを検知

    var body: some View {
        // 全体の背景とパディング
        VStack(spacing: 16) {
            // タイトル
            Text("iOS Reversi")
                .font(.largeTitle)
                .bold()
                .foregroundColor(viewModel.darkMode ? .white : .black) // ダークモード対応

            // ゲーム結果または現在のプレイヤー表示
            if let result = viewModel.gameResult {
                Text(result)
                    .font(.title)
                    .bold()
                    .foregroundColor(viewModel.darkMode ? .purple : .red) // ダークモード対応
                    .transition(.opacity) // 結果表示時にフェードアニメーション
            } else {
                HStack {
                    Text("Black: \(viewModel.blackCount) ⚫︎")
                        .font(.title2)
                        .foregroundColor(viewModel.darkMode ? .white : .black) // ダークモード対応
                    
                    Spacer()
                    
                    Text("White: \(viewModel.whiteCount) ⚪︎")
                        .font(.title2)
                        .foregroundColor(viewModel.darkMode ? .white : .black) // ダークモード対応
                }
                .padding(.horizontal)
                
                // 現在のプレイヤー表示（Web版の「Turn」とカプセルスタイルを再現）
                Text("Turn: \(viewModel.currentPlayer.displayName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.currentPlayer == .black ? .white : .black)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(viewModel.currentPlayer == .black ? Color.black : Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(viewModel.currentPlayer == .black ? Color.white : Color.black, lineWidth: 2)
                    )
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentPlayer) // プレイヤー切り替えアニメーション
            }

            // リバーシ盤
            VStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { col in
                            CellView(
                                row: row,
                                col: col,
                                state: viewModel.currentBoard[row][col],
                                isValidMove: viewModel.isValidMove(x: col, y: row), // x, yの順に注意
                                isFlipped: viewModel.flippedStones.contains(where: { $0[0] == col && $0[1] == row }),
                                isHint: viewModel.showHint && viewModel.hintMove?[0] == col && viewModel.hintMove?[1] == row, // ヒント表示
                                isProcessingAIMove: viewModel.isProcessingAIMove // AI処理中は操作不可
                            ) {
                                viewModel.makeMove(x: col, y: row) // x, yの順に注意
                            }
                        }
                    }
                }
            }
            .padding(4) // 盤面全体のパディング
            .background(Color.green.opacity(0.8)) // 盤面の背景色
            .border(viewModel.darkMode ? Color.white : Color.black, width: 2) // 盤面全体の枠線
            .cornerRadius(5) // 角を少し丸める

            // コントロールボタン群
            VStack(spacing: 10) {
                HStack(spacing: 15) {
                    Button("Reset") {
                        viewModel.resetGame()
                    }
                    .buttonStyle(ReversiButtonStyle(isDarkMode: viewModel.darkMode))
                    .disabled(viewModel.isProcessingAIMove)

                    Button("Undo") {
                        viewModel.undoMove()
                    }
                    .buttonStyle(ReversiButtonStyle(isDarkMode: viewModel.darkMode))
                    .disabled(!viewModel.canUndo || viewModel.isProcessingAIMove)

                    Button("Redo") {
                        viewModel.redoMove()
                    }
                    .buttonStyle(ReversiButtonStyle(isDarkMode: viewModel.darkMode))
                    .disabled(!viewModel.canRedo || viewModel.isProcessingAIMove)

                    Button(viewModel.showHint ? "Hide Hint" : "Hint") {
                        viewModel.toggleHint()
                    }
                    .buttonStyle(ReversiButtonStyle(isDarkMode: viewModel.darkMode))
                    .disabled(viewModel.isProcessingAIMove || viewModel.gameResult != nil || !viewModel.isHumanPlayerTurn)
                }
                
                // プレイヤータイプ設定
                HStack(spacing: 20) {
                    Text("Player 1 (⚫︎):")
                        .foregroundColor(viewModel.darkMode ? .white : .black)
                    Picker("Player 1", selection: $viewModel.firstPlayerType) {
                        ForEach(PlayerType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isProcessingAIMove)
                }
                .padding(.horizontal)

                HStack(spacing: 20) {
                    Text("Player 2 (⚪︎):")
                        .foregroundColor(viewModel.darkMode ? .white : .black)
                    Picker("Player 2", selection: $viewModel.secondPlayerType) {
                        ForEach(PlayerType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isProcessingAIMove)
                }
                .padding(.horizontal)

                // AIの深さ設定
                HStack {
                    Text("AI Depth: \(viewModel.aiDepth)")
                        .foregroundColor(viewModel.darkMode ? .white : .black)
                    Slider(value: Binding(get: {
                        Double(viewModel.aiDepth)
                    }, set: { newValue in
                        viewModel.aiDepth = Int(newValue)
                    }), in: 1...5, step: 1)
                    .disabled(viewModel.isProcessingAIMove)
                }
                .padding(.horizontal)
                
                // ダークモード切り替え
                Button("Toggle Dark Mode") {
                    viewModel.toggleDarkMode()
                }
                .buttonStyle(ReversiButtonStyle(isDarkMode: viewModel.darkMode))
            }
        }
        .padding()
        .background(viewModel.darkMode ? Color.black : Color(white: 0.9)) // 全体の背景色もダークモード対応
        .preferredColorScheme(viewModel.darkMode ? .dark : .light) // システムのカラーモードを強制

    }
}

// CellViewの変更
struct CellView: View {
    let row: Int
    let col: Int
    let state: Player? // Player?型に変更
    let isValidMove: Bool
    let isFlipped: Bool // アニメーション用
    let isHint: Bool // ヒント表示用
    let isProcessingAIMove: Bool // AI処理中はタップ不可

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.8)) // マス目の背景色
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // 可能な限り広げる
                    .aspectRatio(1, contentMode: .fit) // 正方形を維持
                    .overlay(
                        // 有効な手を示すハイライト
                        Group {
                            if isValidMove && !isHint && !isProcessingAIMove { // AI処理中はハイライトしない
                                Circle()
                                    .stroke(Color.yellow.opacity(0.8), lineWidth: 3)
                                    .frame(width: 30, height: 30)
                            }
                        }
                    )
                    .overlay(
                        // ヒント表示
                        Group {
                            if isHint {
                                Circle()
                                    .fill(Color.orange.opacity(0.5))
                                    .frame(width: 30, height: 30)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isHint) // 点滅アニメーション
                            }
                        }
                    )
                
                // 石の表示
                if let player = state {
                    Circle()
                        .fill(player == .black ? Color.black : Color.white)
                        .frame(width: 38, height: 38)
                        .scaleEffect(isFlipped ? 1.1 : 1.0) // ひっくり返るアニメーションのスケール
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isFlipped) // アニメーションの種類
                        .transition(.scale) // 新しく置かれる石のアニメーション
                }
            }
        }
        .disabled(isProcessingAIMove) // AI処理中はボタンを無効化
        .buttonStyle(PlainButtonStyle()) // ボタンのデフォルトスタイルを削除
    }
}

// カスタムボタンのスタイル
struct ReversiButtonStyle: ButtonStyle {
    var isDarkMode: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
            .background(isDarkMode ? Color.blue.opacity(0.8) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}


#Preview {
    iOS_ReversiGameView()
}
