import Foundation

class iOS_ReversiGameViewModel: ObservableObject {
    @Published var board: [[Int]]
    @Published var currentPlayer: Int
    @Published var gameEnded: Bool
    @Published var winner: Int?

    let boardSize = 8

    init() {
        board = [
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 1, 2, 0, 0, 0],
            [0, 0, 0, 2, 1, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0]
        ]
        currentPlayer = 1
        gameEnded = false
        winner = nil
    }

    func resetGame() {
        board = [
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 1, 2, 0, 0, 0],
            [0, 0, 0, 2, 1, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0]
        ]
        currentPlayer = 1
        gameEnded = false
        winner = nil
    }

    func placeDisk(row: Int, col: Int) {
        guard isValidMove(row: row, col: col, player: currentPlayer) else { return }

        board[row][col] = currentPlayer
        flipDisks(row: row, col: col, player: currentPlayer)

        if hasValidMove(player: 3 - currentPlayer) {
            currentPlayer = 3 - currentPlayer
        } else if !hasValidMove(player: currentPlayer) {
            endGame()
        }
    }

    func isValidMove(row: Int, col: Int, player: Int) -> Bool {
        if board[row][col] != 0 { return false }

        for (dx, dy) in directions {
            var x = row + dx
            var y = col + dy
            var hasOpponentBetween = false

            while x >= 0, y >= 0, x < boardSize, y < boardSize {
                if board[x][y] == 0 { break }
                if board[x][y] == player {
                    if hasOpponentBetween {
                        return true
                    } else {
                        break
                    }
                } else {
                    hasOpponentBetween = true
                }
                x += dx
                y += dy
            }
        }

        return false
    }

    func hasValidMove(player: Int) -> Bool {
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                if isValidMove(row: row, col: col, player: player) {
                    return true
                }
            }
        }
        return false
    }

    func flipDisks(row: Int, col: Int, player: Int) {
        for (dx, dy) in directions {
            var x = row + dx
            var y = col + dy
            var positionsToFlip: [(Int, Int)] = []

            while x >= 0, y >= 0, x < boardSize, y < boardSize {
                if board[x][y] == 0 {
                    break
                } else if board[x][y] == player {
                    for (fx, fy) in positionsToFlip {
                        board[fx][fy] = player
                    }
                    break
                } else {
                    positionsToFlip.append((x, y))
                }
                x += dx
                y += dy
            }
        }
    }

    func endGame() {
        gameEnded = true
        let flatBoard = board.flatMap { $0 }
        let blackCount = flatBoard.filter { $0 == 1 }.count
        let whiteCount = flatBoard.filter { $0 == 2 }.count

        if blackCount > whiteCount {
            winner = 1
        } else if whiteCount > blackCount {
            winner = 2
        } else {
            winner = 0 // 引き分け
        }
    }

    let directions = [
        (-1, -1), (-1, 0), (-1, 1),
        ( 0, -1),         ( 0, 1),
        ( 1, -1), ( 1, 0), ( 1, 1)
    ]
}

