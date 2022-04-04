// ignore_for_file: unnecessary_const

import 'agents.dart' as agents;
import 'dart:async';
import 'dart:math';
import 'engine.dart';
import 'package:flutter/material.dart';

const int kNumberOfPlayers = 5;
const Duration kGameTickDuration = const Duration(milliseconds: 60);

void main() {
  runApp(const LambdaBattle());
}

class LambdaBattle extends StatelessWidget {
  const LambdaBattle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lambda Battle!',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BattleGround(title: 'Lambda Battle!'),
    );
  }
}

class BattleGround extends StatefulWidget {
  const BattleGround({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<BattleGround> createState() => _BattleGroundState();
}

class _BattleGroundState extends State<BattleGround> {
  GameState gameState = GameState.empty();
  GameController gameController = GameController();

  final history = GameHistory();

  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _handleTimer(Timer _) {
    nextTurn();
    history.recordDeadPlayer(gameState.deadPlayers);

    if (gameState.isDone) {
      history.recordGame(gameState);

      timer?.cancel();
      timer = null;
      _startBattle();
    }
  }

  void _startBattle() {
    setState(() {
      gameController = GameController.withRandomAgents(kNumberOfPlayers);
      gameState = gameController.getRandomInitialGameState();
    });
    timer = Timer.periodic(kGameTickDuration, _handleTimer);
  }

  void _stopBattle() {
    setState(() {
      timer?.cancel();
      timer = null;
    });
  }

  void nextTurn() {
    setState(() {
      gameState = gameController.takeTurn(gameState);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Row(
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: BoardView(
              gameState: gameState,
            ),
          ),
          Flexible(
            child: Center(
              child: LeaderBoard(history: history),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: timer == null ? _startBattle : _stopBattle,
        child: timer == null
            ? const Icon(Icons.play_arrow)
            : const Icon(Icons.stop),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class BoardView extends StatelessWidget {
  const BoardView({Key? key, required this.gameState}) : super(key: key);

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final winner = gameState.winner;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: BoardPainter(gameState)),
        if (winner != null)
          Container(
            color: Colors.white.withOpacity(0.6),
            child: Center(child: Text('A winner is ${winner.name}')),
          ),
      ],
    );
  }
}

class BoardPainter extends CustomPainter {
  const BoardPainter(this.gameState);

  final GameState gameState;

  void paintBackground(Canvas canvas, Size size, Size cell) {
    final paint = Paint();
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < Board.kWidth; ++i) {
      for (int j = 0; j < Board.kHeight; ++j) {
        paint.color = ((i + j) % 2 == 0) ? Colors.black12 : Colors.black26;
        canvas.drawRect(rectForPosition(Position(i, j), cell), paint);
      }
    }
  }

  Rect rectForPosition(Position position, Size cell) {
    return Rect.fromLTWH(position.x * cell.width, position.y * cell.height,
        cell.width, cell.height);
  }

  void paintPieces(Canvas canvas, Size size, Size cell) {
    gameState.board.forEachPiece((position, piece) {
      piece.owner.paint(canvas, rectForPosition(position, cell), piece.type);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final _cellWidth = size.width / Board.kWidth;
    final _cellHeight = size.height / Board.kHeight;

    final cellSize = Size(_cellWidth, _cellHeight);
    paintBackground(canvas, size, cellSize);
    paintPieces(canvas, size, cellSize);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class GameController {
  GameController() : _agents = <Agent>[];

  GameController.withAgents(this._agents);

  final List<Agent> _agents;

  factory GameController.withRandomAgents(int numberOfPlayers) {
    final rnd = Random();
    return GameController.withAgents(
      List<Agent>.generate(numberOfPlayers, (index) {
        return agents.all[rnd.nextInt(agents.all.length)]();
      }),
    );
  }

  GameState getRandomInitialGameState() {
    Board board = Board.empty();
    for (final player in _agents) {
      Position position;
      do {
        position = Position.random();
      } while (board.getAt(position) != null);

      board = board.placeAt(position, Piece(PieceType.king, player));
    }
    return GameState(board, List<Player>.from(_agents), []);
  }

  GameState takeTurn(GameState gameState) {
    final activePlayer = gameState.activePlayer;
    final view = AgentView(gameState, activePlayer);
    final activeAgent = activePlayer as Agent;
    return gameState.move(activeAgent.pickMove(view));
  }
}

class LeaderBoard extends StatelessWidget {
  const LeaderBoard({Key? key, required this.history}) : super(key: key);

  final GameHistory history;

  static const double _kWidth = 250;

  @override
  Widget build(BuildContext context) {
    if (history.wins.isEmpty) {
      return const SizedBox(
        width: _kWidth,
        child: Text("Tap play to gather data."),
      );
    }
    String asPercent(double value) {
      final percent = (value / history.gameCount) * 100;
      return "${percent.toStringAsFixed(1)}%";
    }

    final entries = history.wins.entries.toList();
    entries.sort((lhs, rhs) => rhs.value.compareTo(lhs.value));

    return SizedBox(
      width: _kWidth,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(130),
          1: FixedColumnWidth(65),
          2: FixedColumnWidth(95),
        },
        border: const TableBorder(
          top: BorderSide(color: Colors.black26),
          bottom: BorderSide(color: Colors.black26),
          right: BorderSide(color: Colors.black26),
          left: BorderSide(color: Colors.black26),
          verticalInside: BorderSide(color: Colors.black26),
        ),
        children: _tableHeaderRow(history.gameCount) +
            entries.map(
              (e) {
                return TableRow(
                  children: <Widget>[
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          '${e.key} ${history.playerIsDead(e.key) ? '☠️' : ''} ${history.isWinner(e.key) ? '👑':''}',
                          style: TextStyle(color: history.colors[e.key]),
                        ),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(asPercent(e.value)),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          '${history.currentRatingForName(e.key).toStringAsFixed(0)} ${history.ratingDropped(e.key) ? '🔻' : '🔼'}',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ).toList(),
      ),
    );
  }
}

List<TableRow> _tableHeaderRow(int gameCount) {
  return <TableRow>[
    TableRow(
      decoration: const BoxDecoration(
        color: Colors.black12,
        border: Border(bottom: BorderSide(color: Colors.black26)),
      ),
      children: <Widget>[
        const TableCell(
          child: const Padding(
            padding: const EdgeInsets.all(4.0),
            child: const Text("Player"),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text("Percent (n=$gameCount)"),
          ),
        ),
        const TableCell(
          child: const Padding(
            padding: const EdgeInsets.all(4.0),
            child: const Text("ELO"),
          ),
        ),
      ],
    ),
  ];
}
