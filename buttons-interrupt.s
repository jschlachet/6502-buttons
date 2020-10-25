;
; Working on my first 6502 programs for learning.
; Jason Schlachet <jss@offramp.org>
;
; Interrupt driven button status. Buttons are connected to Port A, but also
; OR'd together to the CA1 line to generate a positive active edge. When
; an interrupt is received, read Port A and change string to reflect buttons
; status. For some reason, this only shows the button pushed, it doesn't
; support multiple buttons pushed at the same time.
;
PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
PCR = $600c         ; peripheral control register
IFR = $600d         ; interrupt flag register (what caused the interrupt)
IER  = $600e        ; interrupt enable register

value = $0200       ; 2 bytes
mod10 = $0202       ; 2 bytes
message = $0204     ; 6 bytes
buttons = $020a     ; 1 byte

E  = %10000000
RW = %01000000
RS = %00100000

  .org $8000

reset:
  ldx #$ff
  txs
  cli               ; clear interrupt disable

  lda #$82          ; enable CA1
  sta IER
  lda #%00000001          ; setup peripheral control register
  sta PCR

  lda #%11111111    ; Set all pins on port B to output
  sta DDRB
  lda #%11100000    ; Set top 3 pins on port A to output
  sta DDRA

  lda #%00111000    ; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110    ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110    ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #%00000001    ; Clear display
  jsr lcd_instruction

  ; initialize the message string
  lda #"."
  sta message
  sta message+1
  sta message+2
  sta message+3
  sta message+4
  lda #0
  sta message+5

loop:

  lda #%00000010    ; go to home
  jsr lcd_instruction

  ldx #0
print:
  lda message,x
  beq loop
  jsr print_char
  inx
  jmp print

  jmp loop


; add the character in the A register to the beginning of
; the null-terminated string `message`
push_char:
  pha               ; push new first character onto stack
  ldy #0            ; index
char_loop:
  lda message,y     ; get char from string
  tax               ; put char into x
  pla
  sta message,y     ; pull char off stack and add to string
  iny               ; increment y
  txa               ; transfer X to A
  pha               ; push char from string onto stack (0 if end)
  bne char_loop
  pla               ; pull off null
  sta message,y     ; add to end of string
  rts               ; return


lcd_wait:
  pha
  lda #%00000000    ; Port B is input
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
  lda #%11111111    ; Port B is output
  sta DDRB
  pla
  rts

lcd_instruction:
  jsr lcd_wait
  sta PORTB
  lda #0            ; Clear RS/RW/E bits
  sta PORTA
  lda #E            ; Set E bit to send instruction
  sta PORTA
  lda #0            ; Clear RS/RW/E bits
  sta PORTA
  rts

print_char:
  jsr lcd_wait
  sta PORTB
  lda #RS           ; Set RS; Clear RW/E bits
  sta PORTA
  lda #(RS | E)     ; Set E bit to send instruction
  sta PORTA
  lda #RS           ; Clear E bits
  sta PORTA
  rts


nmi:
  rti               ; don't react to NMI

irq:
  pha               ; push A, X, and Y onto stack
  txa
  pha
  tya
  pha

  ; copy output of PORT A into buttons
  lda PORTA         ; read Port A, this should also clear interrupt
  and buttonmask
  sta buttons

  ; loop N times (once per button), reading each line and motifying the status
  ; string based on the state of the bits
  ldy buttoncount
  ldx #0
bit_loop:
  lda buttons
  and #%00000001    ; look at right most bit
  beq bit_off
  txa               ; copy index to a
  adc #"1"          ; add "1" char to a, so the string represents button number
  sta message,x
  jmp bit_next
bit_off:
  lda #"."
  sta message,x
bit_next:
  lsr buttons       ; shift bits right one place
  lda buttons
  inx
  txa               ; copy x to a
  cmp buttoncount   ; compare a to loop iteration max
  beq bit_done
  jmp bit_loop
bit_done:

  pla               ; restore Y, X, and A from stack
  tay
  pla
  tax
  pla

  rti


buttoncount: .byte $5
buttonmask:  .byte $1f ; 00011111

  .org $fffa
  .word nmi
  .word reset
  .word irq
