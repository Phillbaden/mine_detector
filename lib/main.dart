import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/rendering.dart';

enum TileState { covered, blown, open, flagged, revealed }

void main() {
//  debugPaintSizeEnabled = true;
  runApp(MineSweeper());
}

class MineSweeper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MineDetector",
      home: Board(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Board extends StatefulWidget {
  @override
  BoardState createState() => BoardState();
}

class BoardState extends State<Board> {
  final int rows = 9;
  final int cols = 9;
  final int numOfMines = 11;

  List<List<TileState>> uiState;
  List<List<bool>> tiles;

  bool alive;
  bool wonGame;
  int minesFound;
  Timer timer;
  Stopwatch stopwatch = Stopwatch();

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void resetBoard() {
    alive = true;
    wonGame = false;
    minesFound = 0;
    stopwatch.reset();

    timer?.cancel();
    timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      setState(() {});
    });

    uiState = new List<List<TileState>>.generate(rows, (row) {
      return new List<TileState>.filled(cols, TileState.covered);
    });

    tiles = new List<List<bool>>.generate(rows, (row) {
      return new List<bool>.filled(cols, false);
    });

    Random random = Random();
    int remainingMines = numOfMines;
    while (remainingMines > 0) {
      int pos = random.nextInt(rows * cols);
      int row = pos ~/ rows;
      int col = pos % cols;
      if (!tiles[row][col]) {
        tiles[row][col] = true;
        remainingMines--;
      }
    }
  }

  @override
  void initState() {
    resetBoard();
    super.initState();
  }

  Widget buildBoard() {
    bool hasCoveredCell = false;
    List<Row> boardRow = <Row>[];
    for (int y = 0; y < rows; y++) {
      List<Widget> rowChildren = <Widget>[];
      for (int x = 0; x < cols; x++) {
        TileState state = uiState[y][x];
        int count = mineCount(x, y);

        if (!alive) {
          if (state != TileState.blown)
            state = tiles[y][x] ? TileState.revealed : state;
        }

        if (state == TileState.covered || state == TileState.flagged) {
          rowChildren.add(GestureDetector(
            onLongPress: () {
              flag(x, y);
            },
            onTap: () {
              if (state == TileState.covered) probe(x, y);
            },
            child: Listener(
                child: CoveredMineTile(
              flagged: state == TileState.flagged,
              posX: x,
              posY: y,
            )),
          ));
          if (state == TileState.covered) {
            hasCoveredCell = true;
          }
        } else {
          rowChildren.add(
            OpenMineTile(
              state: state,
              count: count,
            ),
          );
        }
      }
      boardRow.add(
        Row(
          children: rowChildren,
          mainAxisAlignment: MainAxisAlignment.center,
          key: ValueKey<int>(y),
        ),
      );
    }
    if (!hasCoveredCell) {
      if ((minesFound == numOfMines) && alive) {
        wonGame = true;
        stopwatch.stop();
      }
    }

    return Container(
//      color: Colors.grey[600],
      color: Color(0xFF006ea1),
      padding: EdgeInsets.all(10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: boardRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int timeElapsed = stopwatch.elapsedMilliseconds ~/ 1000;
    final mediaQuery = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Mine Detector",
          style: TextStyle(
            color: Colors.black,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(30.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Container(
                height: 25.0,
                width: mediaQuery.width * 0.3,
                padding: EdgeInsets.symmetric(horizontal: 3),
                child: FlatButton(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                  ),
                  onPressed: () => resetBoard(),
                  highlightColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Color(0xFF006ea1), width: 2),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  color: Colors.white,
                ),
              ),
              Container(
                height: 40.0,
                width: mediaQuery.width * 0.7,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 3),
                child: RichText(
                  text: TextSpan(
                    text: wonGame
                        ? "You've Won! $timeElapsed seconds"
                        : alive
                            ? "[Found: $minesFound]  [Total: $numOfMines]  [$timeElapsed seconds]"
                            : "You've Lost! It took $timeElapsed seconds",
                    style: TextStyle(
                      color: Colors.black,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        color: Colors.grey[50],
        child: Center(
          child: buildBoard(),
        ),
      ),
    );
  }

  void probe(int x, int y) {
    if (!alive) return;
    if (uiState[y][x] == TileState.flagged) return;
    setState(() {
      if (tiles[y][x]) {
        uiState[y][x] = TileState.blown;
        alive = false;
        timer.cancel();
      } else {
        open(x, y);
        if (!stopwatch.isRunning) stopwatch.start();
      }
    });
  }

  void open(int x, int y) {
    if (!inBoard(x, y)) return;
    if (uiState[y][x] == TileState.open) return;
    uiState[y][x] = TileState.open;

    if (mineCount(x, y) > 0) return;

    open(x - 1, y);
    open(x + 1, y);
    open(x, y - 1);
    open(x, y + 1);
    open(x - 1, y - 1);
    open(x + 1, y + 1);
    open(x + 1, y - 1);
    open(x - 1, y + 1);
  }

  void flag(int x, int y) {
    if (!alive) return;
    setState(() {
      if (uiState[y][x] == TileState.flagged) {
        uiState[y][x] = TileState.covered;
        --minesFound;
      } else {
        uiState[y][x] = TileState.flagged;
        ++minesFound;
      }
    });
  }

  int mineCount(int x, int y) {
    int count = 0;
    count += bombs(x - 1, y);
    count += bombs(x + 1, y);
    count += bombs(x, y - 1);
    count += bombs(x, y + 1);
    count += bombs(x - 1, y - 1);
    count += bombs(x + 1, y + 1);
    count += bombs(x + 1, y - 1);
    count += bombs(x - 1, y + 1);
    return count;
  }

  int bombs(int x, int y) => inBoard(x, y) && tiles[y][x] ? 1 : 0;
  bool inBoard(int x, int y) => x >= 0 && x < cols && y >= 0 && y < rows;
}

Widget buildTile(Widget child, BuildContext context) {
  return Container(
    padding: EdgeInsets.all(1.0),
    height: MediaQuery.of(context).size.height * 0.05,
    width: MediaQuery.of(context).size.height * 0.05,
    color: Colors.grey[400],
    margin: EdgeInsets.all(2.0),
    child: child,
  );
}

Widget buildInnerTile(Widget child) {
  return Container(
    padding: EdgeInsets.all(1.0),
    margin: EdgeInsets.all(2.0),
    height: 15.0,
    width: 15.0,
    child: child,
  );
}

class CoveredMineTile extends StatelessWidget {
  final bool flagged;
  final int posX;
  final int posY;

  CoveredMineTile({this.flagged, this.posX, this.posY});

  @override
  Widget build(BuildContext context) {
    Widget text;
    if (flagged) {
      text = buildInnerTile(
        RichText(
          text: TextSpan(
            text: "\u2691",
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.height * 0.02,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    Widget innerTile = Container(
      padding: EdgeInsets.all(1.0),
      margin: EdgeInsets.all(2.0),
      height: 20.0,
      width: 20.0,
      color: Colors.grey[200],
      child: text,
    );
    return buildTile(innerTile, context);
  }
}

class OpenMineTile extends StatelessWidget {
  final TileState state;
  final int count;
  OpenMineTile({this.state, this.count});

  final List textColor = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.cyan,
    Colors.amber,
    Colors.brown,
    Colors.black,
  ];

  @override
  Widget build(BuildContext context) {
    Widget text;

    if (state == TileState.open) {
      if (count != 0) {
        text = RichText(
          text: TextSpan(
            text: '$count',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor[count - 1],
                fontSize: 17),
          ),
          textAlign: TextAlign.center,
        );
      }
    } else {
      text = RichText(
        text: TextSpan(
          text: '\u2739',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
            fontSize: MediaQuery.of(context).size.height * 0.025,
          ),
        ),
        textAlign: TextAlign.center,
      );
    }
    return buildTile(buildInnerTile(text), context);
  }
}
