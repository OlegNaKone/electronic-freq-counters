$regfile = "2313def.dat"
'+-----------------------------------------------------------------------------+
'|           AVR Attiny2313 Frequency Meter 1.1 (7 digits, 10MHz)              |
'|      Pawe³ Kisielewski (manekinen) manekinen@mdiy.pl   -   MDIY.PL          |
'|                Not for commercial/profit/sell purposes                      |
'|           Compiler: Bascom AVR 2.0.7.6      Date: 25.03.3013                |
'+-----------------------------------------------------------------------------+

'This is only used by me, my prototype board is a bit different - set to 0
Const Proto = 0

'Crystal, put here your crystal frequency
$crystal = 22118400

'Divide your crystal frequency by 1024 and put below
'F.e. 16000000/1024=15625; 20000000/1024=19531,25 (use 19531); 25000000/1024=24414,0625 (use 24414)
Const Compare = 21600

Ddrb = &B11111111
Portb = &B11111111
Ddrd = &B1101111

Config Timer0 = Counter , Edge = Falling
Enable Timer0
On Timer0 Count Nosave

Config Timer1 = Timer , Prescale = 1024 , Clear Timer = 1
On Oc1a 1s Nosave
Enable Compare1a
Compare1a = Compare

Enable Interrupts

'Dim Fast As Bit
Dim Dis As Byte
Dis = 2
Dim Multiplier As Word At &H70
'Dim Mult_copy As Word At &H72
Dim Fr_byte_copy As Byte At &H74
Dim Frequency As Dword
Dim Freq_str As String * 6
Dim Freq_num(8) As Byte

#if Proto = 1
W1 Alias Portb.0
W2 Alias Portd.2
W3 Alias Portd.5
W4 Alias Portd.0
W5 Alias Portd.1
W6 Alias Portd.3
W7 Alias Portd.6
#else
W1 Alias Portd.6
W2 Alias Portb.0
W3 Alias Portd.5
W4 Alias Portd.0
W5 Alias Portd.1
W6 Alias Portd.2
W7 Alias Portd.3
#endif

'Set Fast
'Reset Tccr1b.2
'Set Tccr1b.1
Do

   Portd = &B1101111
   Portb = Lookup(freq_num(dis) , Dig)

   Select Case Dis
      Case 8
      If Freq_num(1) > 6 Then Reset W7
      Case 7
      If Freq_num(1) > 5 Then Reset W6
      Case 6
      If Freq_num(1) > 4 Then Reset W5
      Case 5
      If Freq_num(1) > 3 Then Reset W4
      Case 4
      If Freq_num(1) > 2 Then Reset W3
      Case 3
      If Freq_num(1) > 1 Then Reset W2
      Case 2
      Reset W1
   End Select

   Decr Dis
   If Dis = 1 Then Dis = 8
   Waitms 1

Loop
End

1s:
   $asm
   push R24

   'Fr_byte_copy = Counter0
   IN R24,counter0
   STS &H74,R24
   'Mult_copy = Multiplier
   '!LDS R24,&H70
   '!STS &H72,R24
   '!LDS R24,&H71
   '!STS &H73,R24                                            '

   IN R24, SREG
   push R24
   PUSH R10
   push R11
   push R12
   push R13
   push R14
   push R15
   push R16
   push R17
   push R18
   push R19
   push R20
   push R21
   push R22
   push R23
   push R25
   push R26
   push R27
   push R28
   push R29
   push R30
   push R31
   $end Asm

   Frequency = Multiplier
   Shift Frequency , Left , 8
   Frequency = Frequency + Fr_byte_copy
   'If Fast = 1 Then Shift Frequency , Left , 4
   Freq_str = Str(frequency)
   Str2digits Freq_str , Freq_num(1)

   Multiplier = 0

   $asm
   pop R31
   pop R30
   pop R29
   pop R28
   pop R27
   pop R26
   pop R25
   pop R23
   pop R22
   pop R21
   pop R20
   pop R19
   pop R18
   pop R17
   pop R16
   pop R15
   pop R14
   pop R13
   pop R12
   pop R11
   pop R10

   'reset timer1 & counter0 at the same time
   ldi R24,&H00
   Out Tcnt1l , R24
   Out Tcnt1h , R24
   Out Tcnt0 , R24

   'erase timer0 interrupt flag
   in R24,tifr
   SBR R24,&H01
   Out Tifr , R24

   'in R24,Timsk
   'ori R24,&H01
   'Out Timsk , R24

   pop R24
   Out Sreg , R24
   pop R24
   $end Asm
Return


Count:
   $asm
   push R16
   IN R16, SREG
   push R24
   push R25

   'Incr Multiplier
   lds R24,&H70
   lds R25,&H71
   adiw R24,&H01
   sts &H70,R24
   STS &H71,R25

   POP R25
   POP R24
   Out Sreg , R16
   pop R16
   $end Asm
   '(
   $asm
   push R16
   IN R16, SREG
   push R16
   push R17

   'Incr Multiplier
   lds R16,&H70
   ldi R17,&H01
   add R16,R17
   sts &H70,R16

   lds R16,&H71
   LDI R17,&H00
   ADC R16,R17
   STS &H71,R16

   POP R17
   POP R16
   Out Sreg , R16
   pop R16
   $end Asm
')
Return

Dig:
Data 17 , 125 , 35 , 41 , 77 , 137 , 129 , 61 , 1 , 9
'      0     1    2    3    4    5    6    7    8   9