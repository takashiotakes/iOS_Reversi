import SwiftUI

// 追加：Cell型の定義（セルの位置情報を保持）
struct Cell: Hashable {
    let row: Int
    let col: Int
}

struct iOS_ReversiGameView: View {
    @ObservedObject var viewModel = iOS_ReversiGameViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("iOS Reversi")
                .font(.largeTitle)
                .bold()

            if viewModel.gameEnded {
                if let winner = viewModel.winner {
                    Text(winner == 0 ? "Draw" : "Player \(winner) wins!")
                        .font(.title)
                        .foregroundColor(.purple)
                }
            } else {
                Text("Current Player: \(viewModel.currentPlayer == 1 ? "⚫︎" : "⚪︎")")
                    .font(.title2)
                    .foregroundColor(viewModel.currentPlayer == 1 ? .black : .white)
                    .padding(8)
                    .background(viewModel.currentPlayer == 1 ? Color.white : Color.black)
                    .clipShape(Capsule())
            }

            VStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { col in
                            CellView(cell: Cell(row: row, col: col), state: viewModel.board[row][col]) {
                                viewModel.placeDisk(row: row, col: col)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.green)
            .border(Color.black, width: 2)

            Button("Reset Game") {
                viewModel.resetGame()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
        .background(Color(white: 0.9))
    }
}

struct CellView: View {
    let cell: Cell
    let state: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 40, height: 40)
                if state == 1 {
                    Circle().fill(Color.black).frame(width: 30, height: 30)
                } else if state == 2 {
                    Circle().fill(Color.white).frame(width: 30, height: 30)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    iOS_ReversiGameView()
}

