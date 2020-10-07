import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset bac k to zero; the application
        // is not restarted.
        primarySwatch: Colors.indigo,
        buttonTheme: ButtonThemeData(
          textTheme: ButtonTextTheme.primary,
        ),
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(operators: ['+', '-', '*', '/'], rng: new Random()),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.operators, this.rng}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  final List<String> operators;
  final Random rng;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Variables labeled with an _ directly control game state, all other variables are constants that are hardcoded/read from storage
  FocusNode _answerFocusNode;
  final TextEditingController _answerController = TextEditingController();
  Timer _gameTickTimer;
  num _firstNumber,  // Num variables relate to play-to-play and moment-to-moment game state
      _secondNumber,
      _answer,
      _maxNumber,
      _numberSenseBarWidth,
      _attemptedQuestions = 0,
      _correctQuestions = 0,
      _streakCounter = 0,
      _remainingTimeMillis,
      _currentStreakLength = 0;
  String _operator,
      _resultText = "No attempts";
  bool _shouldShowAnswerData = false, _shouldShowRetryButton = false;
  int solveTimeMillis = 10000;
  Map<String, int> difficultyState = {
    'allowNegative': 0,
    'maxOrderOfMagnitude': 10,
    'decimalPlaces': 0,
    'solveTimePreserveFactor': 3,
    'difficultyIncreaseSolveTimeThresholdFactor': 200
  };
  static const int viewAnswerDelayMillis = 3000,
      gameTickLengthMillis = 30,
      uiResponseAnimationMillis = 300;
  static const List<String> trainingSchedule = [
    'maxOrderOfMagnitude'
  ];

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
    super.initState();

    // Start listening to changes.
    _answerController.addListener(() {
      SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
      _checkAnswer();
    });
    _answerFocusNode = FocusNode();
    this._resetGameState();
  }

  void _runOnTick() {
    setState(() {
      _remainingTimeMillis -= gameTickLengthMillis;
      if (_remainingTimeMillis <= 0) {
        _resultText = "You're out of time! the correct answer is $_answer";
        _maxNumber = max(_maxNumber, _answer.abs());
        _gameTickTimer?.cancel();
        _shouldShowAnswerData = true;
        _shouldShowRetryButton = true;
        _attemptedQuestions += 1;
        _currentStreakLength = 0;
        _streakCounter += 1;
        solveTimeMillis += (0.15 * solveTimeMillis).round();
      }
    });
  }

  /* This method is called whenever the game is started or a new question is requested. */
  void _resetGameState() {
    _gameTickTimer = Timer.periodic(
        // Create a game tick timer to call _runOnTick every gameTickLengthMillis milliseconds
        Duration(milliseconds: gameTickLengthMillis),
        (Timer t) => _runOnTick());
    setState(() {
      _shouldShowRetryButton = false;
      _shouldShowAnswerData = false;
      _remainingTimeMillis =
          solveTimeMillis; // Set remaining time to allowed solve time

      /* Select operands and an operator and calculate the correct answer */
      _firstNumber = num.parse(
          ((widget.rng.nextDouble() - 0.5) * (2 * difficultyState['maxOrderOfMagnitude']))
              .toStringAsFixed(difficultyState['decimalPlaces']));
      _operator = widget.operators[widget.rng.nextInt(widget.operators.length)];
      _secondNumber = num.parse(
          ((widget.rng.nextDouble() - 0.5) * (2 * difficultyState['maxOrderOfMagnitude']))
              .toStringAsFixed(difficultyState['decimalPlaces']));
      switch (_operator) {
        case '+':
          _answer = _firstNumber + _secondNumber;
          break;
        case '-':
          _answer = _firstNumber - _secondNumber;
          break;
        case '*':
          _answer = _firstNumber * _secondNumber;
          break;
        case '/':
          if (_secondNumber == 0) {
            _secondNumber = 2;
          }
          _answer = _firstNumber / _secondNumber;
          break;
      }
      _answer = num.parse(_answer.toStringAsFixed(difficultyState['decimalPlaces']));
      _maxNumber = max(_firstNumber.abs(),
          _secondNumber.abs()); // Used to scale the number sense bars
    });
    _answerController
        .clear(); // Clear the TextEditingController for the answer text field
    if (_answerFocusNode.canRequestFocus) {
      _answerFocusNode.requestFocus();
    }
  }

  /* This function is the handler for when the "check"/"try again" button is pressed */
  _checkAnswer() {
    // The user is attempting a solve and has just pressed the "check" button.
    if (_answerController.text != "") {
      // The user has entered an answer, check as usual
      if (num.parse(_answerController.text) == _answer) {
        /* The answer was correct, congratulate the user and reset after viewAnswerDelayMillis milliseconds */
        _gameTickTimer?.cancel();
        setState(() {
          _maxNumber = max(_maxNumber, _answer.abs());
          _resultText = "Nailed it!";
          _shouldShowRetryButton = false;
          _shouldShowAnswerData = true;
          _attemptedQuestions += 1;
          _correctQuestions += 1;
          _currentStreakLength += 1;
          solveTimeMillis -= ((solveTimeMillis - _remainingTimeMillis) / difficultyState['solveTimePreserveFactor']).round();  // Reduce allowed time to solve question
          if (solveTimeMillis < difficultyState['difficultyIncreaseSolveTimeThresholdFactor'] * difficultyState['maxOrderOfMagnitude']) {  // Increase difficulty if solveTimeMillis reduces below threshold
            
          }
        });
        Future.delayed(const Duration(milliseconds: viewAnswerDelayMillis), () {
          this._resetGameState();
        });
      }
    }
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the
    // widget tree.
    _answerController.dispose();
    _gameTickTimer?.cancel(); // Stop the game tick timer
    _answerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _numberSenseBarWidth = MediaQuery.of(context).size.width - 64;
    // String _correctPercentage = ((_correctQuestions / _attemptedQuestions) * 100).toStringAsFixed(0) + '%';
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FractionallySizedBox(
              widthFactor: 1.0,
              child: LinearProgressIndicator(
                // The timer across the top
                minHeight: 8.0,
                value: _remainingTimeMillis / solveTimeMillis,
              ),
            ),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('${_attemptedQuestions > 0 ? ((_correctQuestions / _attemptedQuestions) * 100).toStringAsFixed(1) : 0}% | $_attemptedQuestions',
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor)),
                  Text('$_currentStreakLength',
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor))
                ]),
            Spacer(), // Spacer to keep things pretty
            Text(
                // First operand
                '$_firstNumber',
                style: Theme.of(context).textTheme.headline4),
            Text(
              // Operator combining the operands
              '$_operator',
              style: Theme.of(context)
                  .textTheme
                  .headline4
                  .copyWith(color: Theme.of(context).accentColor),
            ),
            Text(
              // Second operand
              '$_secondNumber',
              style: Theme.of(context).textTheme.headline4,
            ),
            Container(
              // Equals symbol around the answer text input
              margin: EdgeInsets.fromLTRB(32.0, 8.0, 32.0, 32.0),
              decoration: BoxDecoration(
                  border: Border(
                top: BorderSide(width: 3, color: Colors.black26),
                bottom: BorderSide(width: 3, color: Colors.black26),
              )),
              child: TextField(
                // Answer text input
                textAlign: TextAlign.center,
                enabled: !_shouldShowRetryButton,
                maxLines: 1,
                style: Theme.of(context).textTheme.headline5,
                autofocus: true,
                focusNode: _answerFocusNode,
                controller: _answerController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(vertical: 6.0),
                  isDense: true,
                  border: InputBorder.none,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedContainer(
                  // First operand number sense bar
                  duration: Duration(milliseconds: uiResponseAnimationMillis),
                  constraints: BoxConstraints(
                    minWidth: 4.0,
                  ),
                  margin: EdgeInsets.symmetric(vertical: 4.0),
                  alignment: Alignment.center,
                  width: _numberSenseBarWidth *
                      (_firstNumber / _maxNumber).abs(),
                  child: Text('${_firstNumber != 0 ? _firstNumber : ""}',
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Colors.white)),
                  decoration: BoxDecoration(
                    color: Theme.of(context).accentColor,
                  ),
                ),
                AnimatedContainer(
                  // Second operand number sense bar
                  duration: Duration(milliseconds: uiResponseAnimationMillis),
                  constraints: BoxConstraints(
                    minWidth: 4.0,
                  ),
                  margin: EdgeInsets.symmetric(vertical: 4.0),
                  alignment: Alignment.center,
                  width: _numberSenseBarWidth *
                      (_secondNumber / _maxNumber).abs(),
                  child: Text('${_secondNumber != 0 ? _secondNumber : ""}',
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Colors.white)),
                  decoration: BoxDecoration(
                    color: Theme.of(context).accentColor,
                  ),
                ),
                Visibility(
                  visible: _shouldShowAnswerData,
                  child: Container(
                    // Answer number sense bar
                    margin: EdgeInsets.symmetric(vertical: 4.0),
                    constraints: BoxConstraints(
                      minWidth: 4.0,
                    ),
                    alignment: Alignment.center,
                    width: _numberSenseBarWidth *
                        (_answer / _maxNumber).abs(),
                    child: Text('${_answer != 0 ? _answer : ""}',
                        style: Theme.of(context)
                            .textTheme
                            .headline6
                            .copyWith(color: Colors.white)),
                    decoration: BoxDecoration(
                      color: Colors.lightGreen,
                    ),
                  ),
                ),
              ]
            ),
            Spacer(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('$_resultText'), // Result text
                  ),
                  Visibility(
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
                        child: RaisedButton(
                          // "check"/"try again" button
                          child: Text('try again'),
                          color: Theme.of(context).accentColor,
                          onPressed: _resetGameState,
                        ),
                      ),
                    ),
                    visible: _shouldShowRetryButton,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
