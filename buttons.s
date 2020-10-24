PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
PCR = $600c ; peripheral control register
IFR = $600d ; interrupt flag register (what caused the interrupt)
IER  = $600e ; interrupt enable register

value = $0200 ; 2 bytes
mod10 = $0202 ; 2 bytes
message = $0204 ; 6 bytes
counter = $020a ; 2 bytes

E  = %10000000
RW = %01000000
RS = %00100000

  .org $8000

reset:
  ldx #$ff
  txs
  cli ; clear interrupt enable

  lda #$9b ; enable CA1, CA2, CB1, CB2 82=CA1
  sta IER
  lda #%00 ; setup peripheral control registerwq
  sta PCR

  lda #%11111111 ; Set all pins on port B to output
  sta DDRB
  lda #%11100000 ; Set top 3 pins on port A to output
  sta DDRA

  lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #%00000001 ; Clear display
  jsr lcd_instruction

  lda #0
  sta counter
  sta counter+1

loop:
  lda #%00000010 ; go to home
  jsr lcd_instruction

  lda #0
  sta message

  ; copy counter to value (2 bytes)
  sei ; set interrupt disable
  lda counter
  sta value
  lda counter+1
  sta value+1
  cli ; clear interrupt disable

divide:
  ; init mod10 (remainder) with zero in both bytes
  lda #0
  sta mod10
  sta mod10+1
  clc ; clear carry bit


  ldx #16 ; number of loops
divloop:
  ; rotate all four bits to left
  rol value ; rotate left
  rol value+1
  rol mod10
  rol mod10+1

  ; a, y register = dividend - divisor
  sec ; set carry bits
  lda mod10
  sbc #10 ; subtract with carry
  tay ; transfer to y (save low bytes)
  lda mod10 + 1
  sbc #0
  bcc ignore_result ; branch if carry clear. branch if dividend < divisor
  ; result is in a,y register.
  sty mod10
  sta mod10+1

ignore_result:
  dex ; decrement x
  bne divloop ; if x is not 0 (0 flag not set)

  rol value ; shift in the last bit of the quotient
  rol value+1

  ; remainder is our digit.
  lda mod10
  clc
  adc #"0" ; add a register to 0 character (convert binary to ascii)
  jsr push_char

  ; done when result is 0 (value !=0) continue dividing
  lda value
  ora value + 1 ; or top and bottom half
  bne divide ; branch if value not zero

; message has the end string so now lets print it
  ldx #0
print:
  lda message,x
  beq loop
  jsr print_char
  inx
  jmp print

  jmp loop

number: .word 1729

; add the character in the A register to the beginning of
; the null-terminated string `message`
push_char:
  pha ; push new first character onto stack
  ldy #0 ; index
char_loop:
  lda message,y ; get char from string
  tax ; put char into x
  pla
  sta message,y ; pull char off stack and add to string
  iny ; increment y
  txa ; transfer X to A
  pha ; push char from string onto stack (0 if end)
  bne char_loop
  pla ; pull off null
  sta message,y ; add to end of string
  rts ; return


lcd_wait:
  pha
  lda #%00000000  ; Port B is input
  sta DDRB
lcdbusy:
  lda #RW
  sta PORTA
  lda #(RW | E)
  sta PORTA
  lda PORTB
  and #%10000000
  bne lcdbusy

  lda #RW
  sta PORTA
  lda #%11111111  ; Port B is output
  sta DDRB
  pla
  rts

lcd_instruction:
  jsr lcd_wait
  sta PORTB
  lda #0         ; Clear RS/RW/E bits
  sta PORTA
  lda #E         ; Set E bit to send instruction
  sta PORTA
  lda #0         ; Clear RS/RW/E bits
  sta PORTA
  rts

print_char:
  jsr lcd_wait
  sta PORTB
  lda #RS         ; Set RS; Clear RW/E bits
  sta PORTA
  lda #(RS | E)   ; Set E bit to send instruction
  sta PORTA
  lda #RS         ; Clear E bits
  sta PORTA
  rts


nmi:
  inc counter
  bne exit_nmi
  inc counter+1
exit_nmi:
  rti

irq:
  pha ; push a, then x->a , ...
  txa
  pha
  tya
  pha

  inc counter
  bne exit_irq
  inc counter+1
exit_irq:
  ; delay to effectively debounce
  ldx #$ff
  ldy #$ff
delay:
  dex
  bne delay ; loop
  dey
  bne delay

  bit PORTA ; read port a (bit test w/o storing it) to clear interrupt

  pla ; pull these back from stack
  tay
  pla
  tax
  pla

  rti

  .org $fffa
  .word nmi
  .word reset
  .word irq
