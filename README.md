# 6502 Buttons Experiment

Built on Ben Eater's 6502 computer, this is a simple experiment to detect and
react to push buttons connected to the W65C22. In this first iteration,
I'm just connecting four buttons (pulled low with 1k resistors) to the four
lowest bits of PORTA on the W65C22.

Build:
```
vasm6502_oldstyle  -Fbin -dotdir buttons.s
minipro -p AT28C256  -w a.out
```
