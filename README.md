# 6502 Buttons Experiment

Built on Ben Eater's 6502 computer, this is a simple experiment to detect and
react to push buttons connected to the W65C22. To keep this simple, I'm
connecting buttons directly to CA1, CA2, CB1, and CB2 lines.

Build:
```
vasm6502_oldstyle  -Fbin -dotdir buttons.s
minipro -p AT28C256  -w a.out
```
