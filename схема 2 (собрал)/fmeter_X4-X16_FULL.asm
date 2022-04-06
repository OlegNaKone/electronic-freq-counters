
;==========================================================================
;  ��������� �������������������� �����������
;
;  �����: ����� ������, �.�������, 2014�. (bash-07@yandex.ru)    
;==========================================================================

        LIST         P=16F628A
		#include p16f628a.inc  


;----------------------------------------------------------------------------------
;               ��������������� ������ EEPROM
;   00h - 27h - �� 8 ���� ����. �������� F(st),F(sp),P,t(1),t(0)
;   30h - ��������� �����
;   31h - ����. ������� ��������� (1,2,4,8) (*0.25c)
;   32h - ����� �� ����������     (1,2,4,8) (*8 min)
;   33h - ����� �������� ������� ������ (1,2,4,8) (+2 sec)
;----------------------------------------------------------------------------------
			org  h'2100'
			de   77h,0,0,0,0,0,0,0,77h,0,0,0,0,0,0,0,77h,0,0,0,0,0,0,0,77h,0,0,0,0,0,0,0,77h,0,0,0,0,0,0,0
            org  h'2130'
            de   1h,2h,2h,4h ; ��. ����., ������ 0.5���., ����� 20 ���., ����. 6 ���.
			org  h'2140'
			de   "Author:  Bashir Balayev. Nalchik 2014. bash-07@yandex.ru"


;========================================================================================
;  ��������� ������� ���������� ����������
;----------------------------------------------------------------------------------------
X_16      EQU       0      ;  1 - 16 MHz , 0 - 4 MHz
;========================================================================================


;============================================================================================================



     __CONFIG (_BOREN_OFF&_CP_OFF&_DATA_CP_OFF&_PWRTE_ON&_WDT_OFF&_LVP_OFF&_MCLRE_ON&_HS_OSC)     



;====================================================================================
; ����������� ����������        
; =================================================================================== 


    CBLOCK		70h
		LED_OUT :8    ; 8 ������ �� ��������� 
		fsr_temp 
		status_temp
		w_temp
		pause_          ; ����� - �*2 ��
        pause_H         ;
        pause_Hst       ; 2 min
		tmr2_count   
		fflags_  
    ENDC                  ;7Fh

    CBLOCK      20h
		out_bcd :4
		regime_      ;0-����. ����������, 1-����.����������, 3-������, 4-����. �����.
                     ;5-����. ���. ��������
		reg_temp
		butt_flags   ; ����� ������. ������
		PC_temp
		tmr1_count   
		count_
		column        ;� ����������� �������
		var_temp
		freq_  :4   ; ������� � ��. ������� (f, T, t) � 2-���� ����
        temp :4
        var_pause 
        flags_      ; ������ �����: (7 - ���� ��������� �� 0.25 ���, 
        flash_flags :3  ; 1-� - ����� ���������� ����.(1-����.), ������ - �������.
        ind_per     ; ������ ��������� (0,1,2 �����. 0.25, 0.5, 1 ���.)
        off_time    ; ����� �� ���������� (0-31 �����. 2-62 ���.)
        butt_time   ; ����� �������� ������� ������
        L_out  :8   ; ����� ������ �� ���������
        portb_temp  ; ����������� ����. ����� �
    ENDC    ;43h
;------------------------------------------------------------------------------------




;====================================================================================
;                            ���������
;====================================================================================

LEVEL_CONT SET .10   ; 1/3 ���-�� ������� ��� ���. ��. ������ (�� 5 �� .30)

      IF  (LEVEL_CONT < .5)||(LEVEL_CONT >.30)
    LEVEL_CONT SET .15           ;<5 ��� >30 -->15
      ENDIF



;------------------------------------------------------------------------------------
;  ����� �� ���������
;------------------------------------------------------------------------------------
 
_A       EQU  b'11100111' ;   A 
_b       EQU  b'11110100' ;   b 
_C       EQU  b'01110001' ;   C 
_c       EQU  b'10110000' ;   c 
_d       EQU  b'10110110' ;   d
_E       EQU  b'11110001' ;   E    
_F       EQU  b'11100001' ;   F 
_SPACE   EQU  b'00000000' ;  �����
_P       EQU  b'11100011' ;   P 
_t       EQU  b'11110000' ;   t                            
_L       EQU  b'01110000' ;   L 
_r       EQU  b'10100000' ;   r 
_BOTTOM  EQU  b'00010000' ;  '_'
_Y       EQU  b'11010110' ;   Y 
_u       EQU  b'00110100' ;  'u'
_U       EQU  b'01110110' ;   U 
_H       EQU  b'11100110' ;   H 
_h       EQU  b'11100100' ;   h 
_MIDDLE  EQU  b'10000000' ;  '-'
_UP      EQU  b'00000001' ;  '����. ������'
_q       EQU  b'11000111' ;   q                     
_N       EQU  b'01100111' ;   � 
_n       EQU  b'10100100' ;   n 
_G       EQU  b'01110101' ;   G 
_I       EQU  b'00000110' ;  'I'
_i       EQU  b'00000100' ;  'i'
_O       EQU  b'01110111' ;  'O'  
_o       EQU  b'10110100' ;  'o'  
_S       EQU  b'11010101' ;  'S'

_d2      EQU  b'10110011' ; = 2         
_d3      EQU  b'10010111' ; = 3   
_d4      EQU  b'11000110' ; = 4   
_d6      EQU  b'11110101' ; = 6 
_d7      EQU  b'00000111' ; = 7                     
_d8      EQU  b'11110111' ; = 8                                     
_d9      EQU  b'11010111' ; = 9                    





;------------------------------------------------------------------------------------
            org 0
            goto      begin



;==================================================================================
;==================================================================================
;    ������������ ��������� ����������
;==================================================================================
;==================================================================================			          

			org 4

			movwf       w_temp
            swapf       STATUS,w
            movwf       status_temp  ;coxpa����� W � STATUS
			swapf       FSR,w
			movwf       fsr_temp

			clrw        
            movwf       STATUS ; ����0, ����� 0
		
			btfsc       PIR1,TMR2IF
            goto        tmr2_int
 
        	btfsc       PIR1,TMR1IF
            goto        tmr1_int 

			goto        exit_

;=============================���������� �� TMR1============================================ 
tmr1_int 
			bcf         PIR1,TMR1IF 
            bcf         tmr1_count,7 ; ����� ����� ������������ TMR1 �� �����. �������			
			incf        tmr1_count,f ; ����. ������ �������� ������� TMR1
			btfss       PIR1,CCP1IF 
            goto        ti_0  
            movf        CCPR1H,f  
            btfsc       STATUS,Z  ;
            goto        ti_0 
            bsf         tmr1_count,7 
            goto        exit_
ti_0
    IF   X_16
			movlw       .120            ;
        ELSE
            movlw       .46
    ENDIF
			subwf       tmr1_count,w    ; >=120/46 ?
			btfss       STATUS,C        ;
			goto        exit_           ; ��������� ������. ���� ������ ����� 2(3 -��� 4MHz) ���.
			bsf         fflags_,1      ; ���������� ���� ������������
			bsf         PIR1,CCP1IF     
			goto        exit_

;============================ ���������� �� TMR2 ======================================
tmr2_int ;.......................��. ����������............................................
			btfss       fflags_,3
			goto        t2i_1     ; ���������� ���� �� ����������
			btfsc       fflags_,7
			goto        t2i_3      ; ���� ���� ��� ����
			bsf         fflags_,7  ; c��� �����
            bsf         PORTB,3
			clrf        tmr2_count
			clrf        TMR0          ;
			bsf         STATUS,RP0  ; bank 1
			bsf         TRISB,3 
			bcf         STATUS,RP0  ; bank 0
			goto        t2i_1
t2i_3
			btfss       fflags_,5   
			goto        t2i_4      
			bsf         STATUS,RP0  ; bank 1
            nop
			bcf         TRISB,3  
			bcf         STATUS,RP0  ; bank 0
			bsf         fflags_,4  ; c��� �������
			goto        t2i_1
t2i_4
			incf        tmr2_count,f
			btfss       STATUS,Z
			goto        t2i_1
			btfsc       fflags_,6  
			goto        t2i_2
			bsf         fflags_,6  ;������ �������� ���.
			movlw       .13
			movwf       tmr2_count ; ���.����.
			goto        t2i_1
t2i_2
			bsf         fflags_,5  ;
	   ;------------------------------------------------------------------------------------								
t2i_1    

		 	incf        pause_,f   ; ��������� "pause_" ������ 2 ��
            btfsc       STATUS,Z
            incf        pause_H,f
            btfsc       STATUS,Z
            incf        pause_Hst,f ;������� 2 ���. ����������

;..........................������������ ���������...........................................  
        movf        flash_flags,w ; (xxxxxxxx) 1-��������, 0-��� ��������

 			incf        column,f  ; ����. ������
			btfsc       column,3  ; ���� ��� 7-� ������
			clrf        column    ; ��������� 0-�� ������� 

        btfsc       STATUS,Z        ;
        movwf       flash_flags+1   ; 
        rrf         flash_flags+1,f ;
        clrf        flash_flags+2   ;
        btfss       STATUS,C        ;
        decf        flash_flags+2,f ; ��������� �������� �����

			clrf        PORTB    ; �������� ��������
			clrf        PORTA    ; � �������

			movlw       LED_OUT
			addwf       column,w 
			movwf       FSR      ; ����� ����. �����

			movf        column,w ;
			btfsc       INDF,3      ;
			iorlw       b'00001000' ; ���������� 3-� ��� LED_OUT - ������ �������
            movwf       PORTA    ; ����� ������� � �������

			movf        INDF,w  ; ����. ����
			andlw       b'11110111' ; �������� 3-� ���

        btfsc       pause_,7       ;
        andwf       flash_flags+2,w ; ���������� ��������

			movwf       PORTB      ; ����� �� ��������� LED_OUT ���������. �������

            bcf         PIR1,TMR2IF  ; ����� �����  

;========================= ����� �� ���� ���������� ==============================
exit_  		swapf       fsr_temp,w
			movwf       FSR       ; �����. FSR
		    swapf       status_temp,w
            movwf       STATUS
            swapf       w_temp,f  ; �������������� W � STATUS
            swapf       w_temp,w
 			retfie

;-----------------------------------------------------------------------------------
;===================================================================================




			

;====================================================================================
;                 � � � � � � � � A
;====================================================================================
;                ������  (�������������)
;====================================================================================
begin       bcf       STATUS,RP1
			bsf       STATUS,RP0  ; bank 1
			movlw     b'00001000'
			movwf     TRISB
			movlw     b'11110000' ; ����� � ������������ � ����������� ��������
			movwf     TRISA      
			clrwdt
          	movlw     b'11100111'
            movwf     OPTION_REG  ; TMR0 �� RA4, �������� �����, �������.TMR0- 256, ���.-����.

            clrf      LED_OUT
            clrf      LED_OUT+1
            clrf      LED_OUT+2
            clrf      LED_OUT+3
            clrf      LED_OUT+4
            clrf      LED_OUT+5
            clrf      LED_OUT+6
            clrf      LED_OUT+7  ; ������������� ���������� ���������

            movlw     b'00000010'
			movwf     PIE1     ; ���������� �� TMR2  
 		
			movlw     .124
            movwf     PR2   ; ������� ���������� �� TMR2 - 125*16 = 2 ����

			bcf       STATUS,RP0 ; bank0
            movlw     07h
			movwf     CMCON  ; ����. �����������

    IF   X_16
            movlw     b'00011111'; �������� TMR2, �������. = 16. ���. ��� - 4.
        ELSE
            movlw     b'00000111'; �������� TMR2, �������. = 16. ���. ��� - 1.
    ENDIF
			movwf     T2CON     

			clrf      fflags_
            clrf      flash_flags
            clrf      flash_flags+1
			clrf      tmr2_count
		    clrf      TMR0		
			clrf      TMR2
            clrf      pause_H
            clrf      pause_Hst
            movlw     b'00000001' 
            movwf     column     ; ������ "1"
			movlw     b'11000000' ; ��������� ������. �� ��������� ,
			movwf     INTCON    ;  + ����������

  ;---------------------- �������������� ����������� �������� ----------          
  
            bsf       regime_,7  ;  ���������

			bsf       STATUS,RP0 ; bank1
            movlw     30h
            movwf     EEADR    ;���. ��������:
			call      EE_read__
            call      var_test__; �������� ������������ ����������
			movwf     regime_   ; ����� 
			call      EE_read__
            call      var_test__
			movwf     ind_per   ; ������ ��������� 
			call      EE_read__
            call      var_test__
			movwf     off_time  ; ����� �� ����������  
			call      EE_read__
            call      var_test__
			movwf     butt_time ; ����� �������� ���. ������  



;================================================================================            
;		       	� � � � � � � � �  (�������� ����)
;================================================================================
            movlw     .250
            call      pause__     ; 0.5 sec

            movlw     .104      ;
            movwf     freq_     ;
            movlw     .136      ;
            movwf     freq_+1   ;
            call      write__   ; 

start   ; ������� ����

			btfsc     regime_,0 ; 0 ��� - ������� ����������
			call      freq_standart__
			btfsc     regime_,1 ; 1 ��� - ����. ����������
			call      freq_special__
            btfsc     regime_,2 ; 2 ��� - ������
            call      period__
            btfsc     regime_,3 ; 3 ��� - ������������ 1
            call      t_meter__
            btfsc     regime_,4 ; 4 ��� - ������������ 0
            call      t_meter__

            call      time_Sleep 
           
            movlw     .150
		    call      delay_Wx4__    ; 0.6 ms      

			call      button__

			btfsc     butt_flags,7  ;
            clrf      flash_flags   ;����. �������� ��� ������� ������ 
			btfsc     butt_flags,7  ;
            clrf      pause_Hst     ;����� ������� ����. 

			btfss     butt_flags,0 
            goto      st_2
			call      put_butt_1__   ; ���� ������ 1-� ������
            goto      start
st_2
			btfsc     butt_flags,1 
			call      EE_ls__     ; ���� ������ 2-� ������

            goto   start


;---------------------------------------------------------------------------------------




			


;=======================================================================================
; ������������  ����������� ������������
; 1. �� 1000 �� - ���������� ����. F=1/T, ��� � - ������
; 2. �� 1000 �� - ������� ������� ���. �� 1 ���.
;    ���������� - 100 �� (�.�. ��������� 0 - 1000 �� � 900 - 50000000��)
;=======================================================================================
freq_special__
            btfsc      fflags_,2  ; ���������� ���� ����. �����������?
            goto       fs_0

            call       freq_standart__   ; �����. �-���

            movf       fflags_,w
            andlw      b'11111000'
            btfss      STATUS,Z  ; ����� ���� ���� �� �������
            return            

            movf       out_bcd+3,w
            iorwf      out_bcd+2,w
            btfss      STATUS,Z   ; >9999 ?
            return
            movf       out_bcd+1,w
            sublw      08h
            btfss      STATUS,C   ; >899 ?
            return
            bsf        fflags_,2  ; ���������� ���� ����. ����������� (�����. <900)

fs_0               ; ............. ����������  F = 1/T .................................
 
            call      time_meter__ ; (�� ���. W=0 - ����. ���. W=1 - ���������)
            andlw     1            ;
            btfsc     STATUS,Z     ;
            return    ; W=0        ; 

            call       T_imp__    ; ���������� �������
            clrf       freq_+3
            btfsc      fflags_,0  ; the "too small" flag  
            goto       fs_1   ; �����. � ����. �����������

            btfss      fflags_,1  ; ������������?
            goto       fs_2
            clrf       out_bcd
            clrf       out_bcd+1
            clrf       out_bcd+2
            goto       fs_6
fs_2   
            call       DIVIDE_1byX__  ; F=1/T
            andlw      0ffh
            btfsc      STATUS,Z  ; w=0(������� �� 0) --> �����. � ����. �����������
            goto       fs_1  

                                               ; ���������
            call       b2bcd__  ; bin---->bcd
                                    ; F > 999.999 ---> ��. �-���
            movf       out_bcd+3,f
            btfss      STATUS,Z   ;>999.999 
            goto       fs_1   ; �����. � ����. �����������
fs_6
            movlw      3    ; ������� � ���. 3 (������� � 0) ������
            call       outBCD__
            movlw      _F
            movwf      LED_OUT+7  ; "F"
            movlw      _UP
            movwf      LED_OUT+6  ; "����� ������"
            return
fs_1
            bcf        fflags_,2  ; ���������� ���� �������� �����������
            return


;-----------------------------------------------------------------------------



;=======================================================================================
; ������������  ��������� �������
; 1. �� 1000 �� - ���������� ������� ��������
; 2. �� 1000 �� - ������� ������� ���. �� 1 ���. ����� ������. T=1/F, ��� F - �������
;    ���������� - 100 �� (�.�. ��������� 0 - 1100 �� � 1000 - 50000000��)
;=======================================================================================
period__
            btfss      fflags_,2  ; ���������� ���� ������� ���������� � (=0)?
            goto       pe_20

            call       freq__   ; ������� �-���

            movf       fflags_,w
            andlw      b'11111000'
            btfss      STATUS,Z  
            return            

            clrf       var_temp;... ��������. freq_ � 3-����. � var_temp - ����������...
pe_12                          ; �.�. �������� - 3-����. �����
            movf       freq_+3,f 
            btfsc      STATUS,Z  ; ���. �� ����� - ���. �����. ����.=0
            goto       pe_11
            bcf        STATUS,C
            rrf        freq_+3,f
            rrf        freq_+2,f
            rrf        freq_+1,f
            rrf        freq_,f
            incf       var_temp,f
            goto       pe_12    ;....................................................
pe_11
            call       DIVIDE_1byX__  ; F=1/T
            andlw      0ffh
            btfsc      STATUS,Z  ; w=0 --> �����. � ������� ��������� �
            goto       pe_10  
            
                    ;...... �������� ��������. freq_ � �����. � var_temp ...........
            movf       var_temp,f 
pe_13
            btfsc      STATUS,Z
            goto       pe_14
            bcf        STATUS,C
            rrf        freq_+3,f
            rrf        freq_+2,f
            rrf        freq_+1,f
            rrf        freq_,f
            decf       var_temp,f
            goto       pe_13  ;....................................................
pe_14
                ;�����: ���� freq_ >= 1000000 (000F4240h) --> ������ ���. �

            movlw      40h          
            subwf      freq_,w      
 
            movlw      42h          
            btfss      STATUS,C     
            addlw      1            
            subwf      freq_+1,w        

            movlw      0fh       
            btfss      STATUS,C  
            addlw      1         
            subwf      freq_+2,w   

            clrw                   
            btfss      STATUS,C    
            addlw      1           
            subwf      freq_+3,w   

            btfsc      STATUS,C  ; freq_ >= 1000000 (000F4240h)?
            goto       pe_10     ;.....................................................       

                                              ; ��������� .............................
            call       b2bcd__  ; bin---->bcd

            movlw      3    ; ������� � ���. 3 (������� � 0) ������
            call       outBCD__

            movlw      _P
            movwf      LED_OUT+7  ; "P"
            movlw      _UP
            movwf      LED_OUT+6  ; "����� ������"
            return     
pe_10       bcf        fflags_,2  ; ���������� ���� ������� ���������� �
            return     ;.......................����� ���� P=1/F.......................


pe_20                 ; ............. ������ ���������� T ............................


            call      time_meter__ ; (�� ���. W=0 - ����. ���. W=1 - ���������)
            andlw     1
            btfsc     STATUS,Z
            return    ; W=0

            call       T_imp__    
            clrf       freq_+3
            btfsc      fflags_,0  ; the "too small" flag  
            goto       pe_21       ; �����. � ���������� T=1/F

            movf       temp,f  ; ����������� ����. TMR0 =0? 
            btfsc      STATUS,Z
            goto       pe_18         ; ������� ---> " NO_SIG."............    

            btfsc      fflags_,1  ; ������������?
            goto       pe_22      ; c������ ������� ������  ---------------

                                               ; ���������
            call       b2bcd__  ; bin---->bcd
                                    ; F > 999.999 ---> ��. �-���
            movf       out_bcd+3,w
            iorwf      out_bcd+2,w
            btfss      STATUS,Z   ;>9999? 
            goto       pe_17     ; 
            movlw      09h
            subwf      out_bcd+1,w 
            btfss      STATUS,C   ; <900?
            goto       pe_21
pe_17            
            clrw      ; ��� �������
            call       outBCD__
            goto       pe_19
pe_18
            movlw      7
            call       out_word__ 
            bsf        LED_OUT,3
pe_19
            movlw      _P
            iorlw      b'00001000' ; �������
            movwf      LED_OUT+7  ; "P."
            return

pe_22               ; c������ ������� ������  -----------------------------------------------
            movlw      .9
			call       out_word__ 
            movlw      _P
            movwf      LED_OUT+7  ; ������ ������ ����� F �� P
            return

pe_21
            bsf        fflags_,2  ; ���������� ���� ���������� T=1/F
            return


;-----------------------------------------------------------------------------




;====================================================================================
; ������������ ������ ������������� ���������� (IND_INTERVAL =6->0.25s, =7->0.5s)
;====================================================================================
time_meter__
            btfss      ind_per,0 ;
            goto       tm_113     ;
            btfss      pause_,6   ;
            goto       tm_111     ;
tm_113                            ;
            btfss      ind_per,1 ;
            goto       tm_114     ;
            btfss      pause_,7   ;
            goto       tm_111     ;
tm_114                            ;
            btfss      ind_per,2 ;
            goto       tm_115     ;
            btfss      pause_H,0  ;
            goto       tm_111     ;
tm_115                            ;
            btfss      ind_per,3 ;
            goto       tm_116     ;
            btfss      pause_H,1  ; ��������� 1 ��� � 0.25/0.5/1/2 �.........
            goto       tm_111     ;
tm_116  
            btfsc      flags_,7
            retlw      0        ; ���������� ���� 6 ��� pause_ =1 � ����=1
            goto       tm_112
tm_111            
            bcf        flags_,7 ; �������� ���� ���.
            retlw      0         ; ���������� ���� 6 ��� pause_ =0
tm_112  
            bsf        flags_,7 ; ���. ���� ���.
            retlw      1        ; ���������.....................................

;------------------------------------------------------------------------------------




;===================================================================================
; ������������ ������������ �����������
;===================================================================================
freq_standart__
            call       freq__
            movf       fflags_,w
            andlw      b'11111000'
            btfss      STATUS,Z  ; ����� ���� ���� �� �������
            return            

			call       b2bcd__      ; ������. � �������-�����. ������
			clrw                 ; W=0 --> ��� ������� 
         	call       outBCD__     ; ����� �� ��������� � �������� ������. �����

            movf       LED_OUT+7,f
            btfss      STATUS,Z
            return               ; ����� ��� ��������� ������� �������

            movlw      _F
            iorlw      b'00001000' ; �������
            movwf      LED_OUT+7  ; "F."

            return
;-----------------------------------------------------------------------------------







;===================================================================================
;    ������� ������������  �����������
;  ����: fflags_, ����� (�������) - freq_ (4-����.)
;===================================================================================
freq__
			btfsc      fflags_,3
			goto       fr_1      ; ��������� 

			clrf       freq_+2   ;.........���������� ������� � ������....................
			clrf       freq_+3
            bcf        PORTB,3
			bsf        STATUS,RP0 ;bank1 
			clrwdt
          	movlw      b'11100111'
            movwf      OPTION_REG  ; TMR0 �� RA4, �������� �����, �������.TMR0- 256, ���.-����.
			bcf        TRISB,3   
			bcf        STATUS,RP0 ;bank0 
            bcf        INTCON,T0IF   ; ����� ����� TMR0 
			bsf        fflags_,3    ;.............................................
			return
fr_1
			btfss      INTCON,T0IF ;
			goto       fr_3        ;
			bcf        INTCON,T0IF ;
			incf       freq_+2,f   ;
			btfsc      STATUS,Z    ; ��� ������������ TMR0, ���������� ����. ��������
			incf       freq_+3,f   ; 	
fr_3
			btfss      fflags_,4
			return                 
			
			movf       TMR0,w ; TMR0 � W --> freq_+1
			movwf      freq_+1
    		
                        ; ����� - ������ .......................
			clrf       count_
			btfss      TMR0,0
			goto       fr_4  ; ���� 0 ��� =0
fr_2
			bsf        PORTB,3     ;������� �� ��. ����
			incf       count_,f
			bcf        PORTB,3
			btfsc      TMR0,0 
			goto       fr_2
			goto       fr_5
fr_4
			bsf        PORTB,3     ;������� �� ��. ����
			incf       count_,f
			bcf        PORTB,3
			btfss      TMR0,0 
			goto       fr_4
fr_5              ; ....����� ������� - <=1540.....................

			comf       count_,f  ;
			incf       count_,w ; ���������� � count_ -->W: � W - ����� � ����������
 			movwf      freq_

			movlw      b'00000111'
			andwf      fflags_,f    
            
			return

;------------------------------------------------------------------------------------------






;=======================================================================================
; ������������ ��������� ������������ ��������� (�����. � ���.)
;
;=======================================================================================

t_meter__
            call      time_meter__ ; 
            andlw     1
            btfsc     STATUS,Z
            return    ; W=0

                     ; ��������� ������������------------------------------------------
            movlw     8
            movwf     temp+1
            movf      pause_,w    ; ����. �������
            movwf     temp+2      ;
            incf      pause_H,w   ;
            movwf     temp+3      ; ������. pause_H+1 ��� ����. ������� 0.5 ���

tm_2   ;.............................................................
            call      t_imp__             

            btfsc     INTCON,T0IF   
            goto      tm_0         

            movf       temp,f  ; ����������� ����. TMR0 =0? 
            btfsc      STATUS,Z
            goto       tm_9             

            btfsc     fflags_,1  ; ������������?
            goto      tm_10            

            movf      temp,w  ; ����������� ����. TMR0  
            sublw     .15   
            btfss     STATUS,C ; >15?
            goto      tm_0         

            btfss     fflags_,0    ; the "too small" flag c������  
            goto      tm_1         
   
            movf      pause_,w  ; ������ 0.5 ��� ?
            subwf     temp+2,w  ;
            movf      pause_H,w ;
            btfss     STATUS,C  ;
            incfsz    pause_H,w ; 
            subwf     temp+3,w  ; (pause_(1)+0.5c)-pause_(2)<0 ?           
            btfss     STATUS,C  ; 0.5 s ������ ?
            goto      tm_3    ;�� - exit

            decfsz    temp+1,f   
            goto      tm_2  ;...............................................................


tm_3               ;--------------------------------------------------
            movf      freq_,w   ;
            movwf     out_bcd   ;
            movf      freq_+1,w ;
            movwf     out_bcd+1 ;
            movf      freq_+2,w ;
            movwf     out_bcd+2 ;  ���������� freq_ � out_bcd

            call      T_imp__      

            btfss     fflags_,0    ; ������� the "too small" flag 
            goto      tm_4

            call      t_256__   ; ���. ����. <256

            btfsc      fflags_,1   ; ������������? (������)
            return                ;����� 
            btfsc     CCPR1H,0    ; t>=128 uS (���. ����� ���. >=256 uS)(������)
            return               ;�����
   
            btfss     fflags_,0    ; the "too small" flag =0
            goto      tm_1         ; �����. � ������� ��������� ��������....


            movf      freq_,w   ;
            movwf     out_bcd   ; ����. � out_bcd
            clrf      out_bcd+1
            clrf      out_bcd+2

            call      T_256__      

            btfsc     CCPR1H,0    ; t>=128 uS (���. ����� ���. >=256 uS)(������)
            return               ;����� 

            btfsc     fflags_,0    ; the "too small" flag 
            goto      tm_0         ; �����. "������� ������� �������".....

tm_4
            btfsc      fflags_,1   ; ������������?
            goto       tm_10           


        ; -------------------------------------------------------------------------

               ; (t_imp_1/0 -> ���.) minus ������
            movf      freq_,w
            subwf     out_bcd,f
            movf      freq_+1,w
            btfss     STATUS,C
            incfsz    freq_+1,w
            subwf     out_bcd+1,f
            movf      freq_+2,w
            btfss     STATUS,C
            incfsz    freq_+2,w
            subwf     out_bcd+2,f

            btfsc     STATUS,C       ; ������ �� ������ ��� (t_imp_1/0 -> ���.) ?
            goto      tm_12          ; x>=0

            movf      out_bcd+1,w ;....��� ������� ����. ����� ffh?..............
            andwf     out_bcd+2,w ;
            xorlw     0ffh ; comf ;
            btfss     STATUS,Z    ; 
            return                ; ........ .............
            
            movlw     1h        ;
            addwf     out_bcd,w ;
            btfss     STATUS,C  ;
            goto      tm_6      ;���� ������� <= 1��� 
            goto      tm_5             

tm_12
            movf      out_bcd+1,w ;....��� ������� ����. ����� 0?..............
            iorwf     out_bcd+2,w ;
            btfss     STATUS,Z    ; 
            return                ; ........��� --> o����� - ����� ...........

            movf      out_bcd,w    ;
            sublw     1h           ; ���� ������� <= 1��� 
            btfsc     STATUS,C     ; 
            goto      tm_6         ;...........................................
    

                    ; (t_imp_1/0 -> ���.) - ����.+������

            movf      out_bcd,w
            movwf     freq_
            clrf      freq_+1
            clrf      freq_+2
            goto      tm_14         ; �����. � ������� ��������� ��������...............            

tm_5              
                 ; ���� t = (t-T)+T
            movf      out_bcd,w
            addwf     freq_,f
            movf      out_bcd+1,w
            btfsc     STATUS,C
            incfsz    out_bcd+1,w
            addwf     freq_+1,f
            movf      out_bcd+2,w
            btfsc     STATUS,C
            incfsz    out_bcd+2,w
            addwf     freq_+2,f    ; � freq_ ��������������� ��������
            goto      tm_14         ; �����. � ������� ��������� ��������...            

tm_6 
            call      t_1_or_0__   ; �������� �������
            movwf     temp         ; ����. W
            btfsc     temp,1    ; =2
            return              ;������������� (������) - �����
            
            btfsc     regime_,4
            goto      tm_7
                    ; ���. �����. ��������
            btfsc     temp,0    ; �����. ������ (t=T)   
            goto      tm_14         ; �����. � ������� ��������� ��������...            
            goto      tm_8    ; =0

tm_7                ; ���. ���. ��������
            btfss     temp,0    ; ���. ������ (t=T)   
            goto      tm_14         ; �����. � ������� ��������� ��������...            
                        
tm_8              ;t=0 (�������� �������)
            clrf      freq_
            incf      freq_,f  ; =1us
            clrf      freq_+1
            clrf      freq_+2
            clrf      freq_+3
                     ; �����. � ������� ��������� ��������...
  
              ;------------------------- ���������---------------------------------
          
tm_14
            bsf        flash_flags,7  
            goto       tm_13
tm_1
            clrf       flash_flags  ;����. ��������
tm_13

    IF   X_16
            call       t_imp_out__ ;�� ���. � ���������� 1/4 ���
        ELSE
			call       b2bcd__      ; ������. � �������-�����. ������
			clrw                 ; W=0 --> ��� ������� 
         	call       outBCD__     ; ����� �� ��������� � �������� ������. �����
    ENDIF         

            movlw      _t
            movwf      LED_OUT+7  ; "t"

            movlw      _UP
            btfsc      regime_,4
            movlw      _BOTTOM      ; "����. ������" - ���.3, "_" - ���.4

            movf       LED_OUT+6,f
            btfsc      STATUS,Z
            movwf      LED_OUT+6    ; 2-� ������ ��� ������� ������� �������
            btfss      STATUS,Z
            movwf      LED_OUT+7    ; 1-� ������ ��� ��������� ������� �������
  
            return

tm_0               ; c������ ������� �������-------------------------------
            movlw      .9
			call       out_word__ 
            clrf       flash_flags  ;����. ��������
            return

tm_9               ; ������������ .........................
            movlw      .7
			call       out_word__ 
            bsf        LED_OUT,3  ; ���. ��. ���.
            clrf       flash_flags  ;����. ��������
            return

tm_10               ; c������ ������� ������  -----------------------------------------------
            movlw      .9
			call       out_word__ 
            movlw      _P
            movwf      LED_OUT+7  ; ������ ������ ����� F �� P
            clrf       flash_flags  ;����. ��������
            return

            
            
;------------------------------------------------------------------------------------------


;=========================================================================
; ����� �� ��������� ����. �������� 
; 
;=========================================================================

    IF   X_16
t_imp_out__
            movf       freq_+1,w  ;
            andlw      b'10000000';
            iorwf      freq_+2,w  ; x < 32768 ? (�� - Z=1)
            btfsc      STATUS,Z
            goto       tio_1
                ; x>=32768 (t>=8192 mcs) 
            bcf        STATUS,C
            rrf        freq_+2,f
            rrf        freq_+1,f
            rrf        freq_,f   ;*2
            bcf        STATUS,C
            rrf        freq_+2,f
            rrf        freq_+1,f
            rrf        freq_,f   ;*4

			call       b2bcd__      ; ������. � �������-�����. ������
			clrw                 ; W=0 --> ��� ������� 
         	call       outBCD__     ; ����� �� ��������� � �������� ������. �����
            return
            
tio_1          ; x<32768 

            bcf        STATUS,C
            rlf        freq_,w
            movwf      out_bcd 
            rlf        freq_+1,w
            movwf      out_bcd+1
            rlf        freq_+2,w
            movwf      out_bcd+2
            rlf        out_bcd,f 
            rlf        out_bcd+1,f 
            rlf        out_bcd+2,f 
            rlf        out_bcd,f 
            rlf        out_bcd+1,f 
            rlf        out_bcd+2,f  ; (x*8)

            movf       freq_,w      ; x*8+x ....... ...................
            addwf      out_bcd,f        
            movf       freq_+1,w     
            btfsc      STATUS,C      
            incfsz     freq_+1,w     
            addwf      out_bcd+1,f        
            movf       freq_+2,w       
            btfsc      STATUS,C       
            incfsz     freq_+2,w
            addwf      out_bcd+2,f ;................................... 

            movlw      .4         ;.................................
            movwf      count_
tio_2
            bcf        STATUS,C   
            rlf        freq_,f  
            rlf        freq_+1,f
            rlf        freq_+2,f
            decfsz     count_,f
            goto       tio_2     ; x*16 ........................
            
            movf       out_bcd,w      ; x*16+x*8+x = x*25  ...................
            addwf      freq_,f        
            movf       out_bcd+1,w     
            btfsc      STATUS,C      
            incfsz     out_bcd+1,w     
            addwf      freq_+1,f        
            movf       out_bcd+2,w       
            btfsc      STATUS,C       
            incfsz     out_bcd+2,w
            addwf      freq_+2,f ;................................... 

			call       b2bcd__      ; ������. � �������-�����. ������
			movlw      2             
         	call       outBCD__     ; ����� �� ��������� � �������� ������. �����
            return
    ENDIF

;-------------------------------------------------------------------------








;=======================================================================================
;  ������������ ��������� �������� �������� �������� ������� (LEVEL_CONT*3 �������)
;=======================================================================================

t_1_or_0__
            movlw      .3*LEVEL_CONT     
            movwf      temp+1
            clrf       temp
tor_1
            btfsc      PORTB,3
            incf       temp,f    ; +1 ��� ���. ������
            decfsz     temp+1,f
            goto       tor_1   ; ���� 30 ���

            movf       temp,w
            sublw      LEVEL_CONT
            btfsc      STATUS,C
            retlw      0         ; ��������������� 0

            movf       temp,w
            sublw      .2*LEVEL_CONT
            btfss      STATUS,C
            retlw      1         ; ��������������� 1

            retlw      2         ; �������������

;-----------------------------------------------------------------------------------

            
                       





;000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000



;=========================================================================================
;   ������������ ��������� ������� �������� 
;=========================================================================================

T_imp__
            call       t_imp_begin__ 

			movlw      b'00000100'
			clrf       TMR0
			bcf        PIR1,CCP1IF  
			movwf      CCP1CON 
T_1
			btfss      PIR1,CCP1IF ; ........................
			goto       T_1  
			movf       CCPR1L,w    ;
			movwf      freq_       ;
			movf       CCPR1H,w    ;
			movwf      freq_+1     ;
			movf       tmr1_count,w; ����. 
			movwf      freq_+2     ;
            bcf        tmr1_count,7 ; 			
			bcf        PIR1,CCP1IF  ;
T_3
			btfss      PIR1,CCP1IF ; ........................
			goto       T_3 
			movf       TMR0,w   
			clrf       CCP1CON    ;����.  

			call       t_imp_end__
			return


;---------------------------------------------------------------------------------------





;=========================================================================================
;   ������������ ��������� ������������ �������������� ��� �������������� ��������
;   (freq_ - �������� �������� � ���) 
;=========================================================================================

t_imp__
            call       t_imp_begin__ 

            btfsc      regime_,4
            goto       ti_5

			movlw      b'00000101'
			clrf       TMR0
			bcf        PIR1,CCP1IF  
			movwf      CCP1CON 
ti_7
			btfss      PIR1,CCP1IF ; ........................
			goto       ti_7  
			movf       CCPR1L,w    ;
			movwf      freq_       ;
			movf       CCPR1H,w    ;
			movwf      freq_+1     ;
			movf       tmr1_count,w; 
			movwf      freq_+2     ;			
            bcf        tmr1_count,7; 			
			decf       CCP1CON,f   ;
			bcf        PIR1,CCP1IF ;����� ����� 
ti_6
			btfss      PIR1,CCP1IF ; ........................
			goto       ti_6 
			incf       TMR0,w   
			clrf       CCP1CON     

			call       t_imp_end__
			return


ti_5  ; ���. ���. ......................................................
			movlw      b'00000100'
			clrf       TMR0
			bcf        PIR1,CCP1IF  
			movwf      CCP1CON ; 
ti_1
			btfss      PIR1,CCP1IF ; ........................
			goto       ti_1  
			movf       CCPR1L,w    ;
			movwf      freq_       ;
			movf       CCPR1H,w    ;
			movwf      freq_+1     ;
			movf       tmr1_count,w; 
			movwf      freq_+2     ;			
            bcf        tmr1_count,7; 			
			incf       CCP1CON,f   ;
			bcf        PIR1,CCP1IF  ;����� ����� 
ti_3
			btfss      PIR1,CCP1IF ; ........................
			goto       ti_3 
			incf       TMR0,w   
			clrf       CCP1CON     

			call       t_imp_end__   
			return


;---------------------------------------------------------------------------------------









;=======================================================================================
; ������������ - ������ ����������� T_imp__ � t_imp__
;========================================================================================
            
t_imp_begin__
            movlw      b'00000100'
            andwf      fflags_,f    
			clrf       T1CON ; ������� TMR1
			clrf       TMR1L
			clrf       TMR1H
            bcf        PIR1,TMR1IF
			clrf       tmr1_count
			clrwdt
          	movlw      b'11111000' ; TMR0 �� RA4, ����. �����, ���.-����.  �������.off	
     ;���. ���.
            btfsc      regime_,3
            movlw      b'11101000'  ; TMR0 �� RA4, ���. �����, ���.-����.  �������. off	

			bsf        STATUS,RP0 ;bank1 
            movwf      OPTION_REG  		
			bsf        TRISB,3     ; RB3 - ����
			bsf        PIE1,TMR1IE  ;������. ������. �� TMR1
			bcf        STATUS,RP0 ;bank0 

			bcf        INTCON,GIE   ;..................................................
ti_2
			btfss      PIR1,TMR2IF
			goto       ti_2
			bsf        INTCON,GIE   ;..................................

            clrf       TMR0
            bcf        INTCON,T0IF 
    IF   X_16
            movf       regime_,w
            andlw      b'00000110'
			movlw      b'00000001'; �����.-1/1, ����.-osc/4, �������� TMR1
            btfss      STATUS,Z ; ����.���������� � ������?  
            movlw      b'00100001'; �����.-1/4, ����.-osc/4, �������� TMR1
        ELSE
			movlw      b'00000001'; �����.-1/1, ����.-osc/4, �������� TMR1
    ENDIF            
			movwf      T1CON   
            return


;--------------------------------------------------------------------------------------------







;=========================================================================================
; ������������ - ����� �����������  T_imp__, t_imp1__ � t_imp0__
;=========================================================================================

t_imp_end__
            movwf      temp  

            btfsc      INTCON,T0IF  
            bsf        fflags_,0 ; ���� "������� ��������"
            
            sublw      2h      ; (������� �������� �������)
            btfss      STATUS,C
            bsf        fflags_,0 ; ���� "������� ��������"

			clrf       T1CON ; ������� TMR1 
			bcf        PIR1,CCP1IF  ;����� ����� 
            btfsc      tmr1_count,7  ;............................................ 
            decf       tmr1_count,f
            btfsc      freq_+2,7
            decf       freq_+2,f
            movlw      b'01111111'
            andwf      tmr1_count,f
            andwf      freq_+2,f ; .....��������� �������� 

			movf       freq_+2,w    ;............................................
			subwf      tmr1_count,w
			movwf      freq_+2
			movf       freq_+1,w
			subwf      CCPR1H,w
			movwf      freq_+1
			btfss      STATUS,C
			decf       freq_+2,1
			movf       freq_,w
			subwf      CCPR1L,w
			movwf      freq_
			btfsc      STATUS,C
			goto       t0_4
			decf       freq_+1,f
			incf       freq_+1,f
			btfsc      STATUS,Z
			decf       freq_+2,f
			decf       freq_+1,f      ;......���������� �������� ��������--> freq_.............
t0_4
            clrf       freq_+3   ; ����� ������� ������ =0
			bsf        STATUS,RP0 ;bank1 
			bcf        PIE1,TMR1IE  ;������ ������. �� TMR1
			bcf        STATUS,RP0 ;bank0 
			return
;---------------------------------------------------------------------------------------	





;=========================================================================================
;   ������������ ��������� ������� �������� ( < 256/2 uS)
;  (freq_ - �������� �������� � ���)
;=========================================================================================

T_256__
            call       t_256_begin__ 

			movlw      b'00000100'
			clrf       TMR0
			bcf        PIR1,CCP1IF  
			movwf      CCP1CON 
T2_1
			btfss      PIR1,CCP1IF ; ........................
			goto       T2_1  
			movf       CCPR1L,w    ;
			movwf      freq_       ;
			bcf        PIR1,CCP1IF  ;
T2_3
			btfss      PIR1,CCP1IF ; ........................
			goto       T2_3 
			movf       TMR0,w   
			clrf       CCP1CON     

            call       t_256_end__
            movf       freq_,w
            sublw      7h
            btfsc      STATUS,C
            bsf        fflags_,0  ; ���. ���� "������� ������� �������" ��� T<8

			return


;---------------------------------------------------------------------------------------






;=========================================================================================
; ������������ ��������� ������������ �����. ��� ���. �������� � ������������� <256/2 ���
; (freq_ - �������� �������� � ���)
;=========================================================================================

t_256__
            call       t_256_begin__ 
            
            btfsc      regime_,4
            goto       ti2_5

                    ; �����. ������� ...........................................
			movlw      b'00000101'
			clrf       TMR0
			bcf        PIR1,CCP1IF  
			movwf      CCP1CON 
ti2_7
			btfss      PIR1,CCP1IF ; ........................
			goto       ti2_7  
			movf       CCPR1L,w    ;
			movwf      freq_       ;
			decf       CCP1CON,f   ;
			bcf        PIR1,CCP1IF  ;����� ����� 
ti2_6
			btfss      PIR1,CCP1IF ; ........................
			goto       ti2_6 
			incf       TMR0,w   
			clrf       CCP1CON     

			call       t_256_end__
			return


ti2_5  ; ���. ���. ......................................................
			movlw      b'00000100'
			clrf       TMR0
			bcf        PIR1,CCP1IF  
			movwf      CCP1CON 
ti2_1
			btfss      PIR1,CCP1IF ; ........................
			goto       ti2_1  
			movf       CCPR1L,w    ;
			movwf      freq_       ;
			incf       CCP1CON,f   ;
			bcf        PIR1,CCP1IF ;
ti2_3
			btfss      PIR1,CCP1IF ;........................
			goto       ti2_3 
			incf       TMR0,w   
			clrf       CCP1CON   

			call       t_256_end__   
			return

;-------------------------------------------------------------------------------------------





;=======================================================================================
; ������������ - ������ ����������� _256_
;========================================================================================
            
t_256_begin__
            movlw      b'00000100'
            andwf      fflags_,f    
			clrf       T1CON ; ������� TMR1
			clrf       TMR1L
			clrf       TMR1H
            bcf        PIR1,TMR1IF
			clrwdt
          	movlw      b'11111000' ; TMR0 �� RA4, ����. �����, ���.-����.  �������.off	
     ;���. ���.
            btfsc      regime_,3
            movlw      b'11101000'  ; TMR0 �� RA4, ���. �����, ���.-����.  �������. off	

			bsf        STATUS,RP0 ;bank1 
            movwf      OPTION_REG  		
			bsf        TRISB,3     ; RB3 - ����
			bcf        STATUS,RP0 ;bank0 

			bcf        INTCON,GIE   ;..................................................
ti2_2
			btfss      PIR1,TMR2IF
			goto       ti2_2
			bsf        INTCON,GIE   

            clrf       TMR0
            bcf        INTCON,T0IF 
			movlw      b'00000001'
			movwf      T1CON   ; �����.-1/1, ����.-osc/4, �������� TMR1
            return


;---------------------------------------------------------------------------------------




;=======================================================================================
; ������������ - ����� ����������� _256_
;========================================================================================
            
t_256_end__
            movwf      var_temp  ;    

            btfsc      INTCON,T0IF  
            bsf        fflags_,0 ; ���� "������� ��������"
            
            sublw      2h      ; (������� �������� �������)
            btfss      STATUS,C
            bsf        fflags_,0 ; 

			clrf       T1CON ; ������� TMR1 
			bcf        PIR1,CCP1IF  
 
			movf       freq_,w
			subwf      CCPR1L,w
			movwf      freq_   ;......���������� �������� ��������--> freq_.............
            clrf       freq_+1
            clrf       freq_+2
            clrf       freq_+3 
  
			bsf        STATUS,RP0 ;bank1 
			bcf        PIE1,TMR1IE  ;������ ������. �� TMR1
			bcf        STATUS,RP0 ;bank0 			
            
            movlw      1h
            movf       CCPR1H,f
            btfss      STATUS,Z
            movwf      CCPR1H    
            btfsc      PIR1,TMR1IF
            movwf      CCPR1H    ;  0 - <128 uS, 1 - >128 uS
           
            return

;------------------------------------------------------------------------------------------



;000000000000000000000000000000000000000000000000000000000000000000000000000000000000000





;==============================================================================
;  ������������ ����������� ������� ������
;  ��������: butt_flags - 7 ��� -���� ���. ��., 1 -������ 1, 0 -������ 2 
;  ���������� ����������� �� 16 ������
;==============================================================================
button__
			clrf      butt_flags 
			btfsc     fflags_,5 
			return                

			bcf       INTCON,GIE  ; ������ ����������
        movf      PORTB,w  
        clrf      PORTB  ; ����. ��������
        movwf     portb_temp  ;����. ����. ����� �
   			bsf       STATUS,RP0  ; bank 1
   			movlw     0ffh
			movwf     TRISA
 			bcf       STATUS,RP0  ; bank 0
            comf      PORTA,w       ;
            andlw     b'00000011'   ; ���������� ��������� ������ (1-������)
			movwf     butt_flags    ;

			bsf       STATUS,RP0  ; bank 1
			movlw     b'11110000' 
			movwf     TRISA    ;�������������� �
			bcf       STATUS,RP0  ; bank 0

        movf      portb_temp,w
        movwf     PORTB       ;�������������� B          
			bsf       INTCON,GIE  ; ����. ����������

			movf      butt_flags,f
			btfss     STATUS,Z    ; ���� ������� �������?(<>0)
			bsf       butt_flags,7 ; ���. 7-� ��� - ������� ������� ������
			return                
;------------------------------------------------------------------------------------




;==============================================================================
;  ������������ �������� 0.02 - 0.5 ���
;  �������� pause_, �������� - � "W"   (P = w*2 mc)
;==============================================================================

pause__                ; ��� w �� 10 �� 256, ����� 0.02 - 0.5 ���. 
			addwf        pause_,w
			movwf        var_pause ;var_pause=pause+w
			  
p_1			movf         pause_,w
			xorwf        var_pause,w ; �������� pause_ (���������������� � ���������� TMR0)
			btfss        STATUS,Z ; ����� ��� pause_= var_pause
			goto         p_1
			return                 

;------------------------------------------------------------------------------			         






      
;====================================================================================
; ������������ ������� ����� ��� ������ �� 7-����. ���������  w = .9 max
; ===================================================================================

Table_s__ 
			movwf       PC_temp
            sublw       .9          ;
            btfss       STATUS,C     ;
            retlw       0  ;  �������� w>max.? ���� �� --->"������� �����"
            movf        PC_temp,w

			movlw       HIGH table_
			movwf       PCLATH
			movf        PC_temp,0
			addlw       LOW table_ 
			btfsc       STATUS,C
			incf        PCLATH,1
			movwf       PCL        ; ���������� �������� ������ PC �������������
table_                                    ; �� �������� ����������� ������������ W.
            retlw       _O ; = 0 (O)      
            retlw       _I ; = 1 (I)         
            retlw       _d2; = 2                 
            retlw       _d3; = 3                 
            retlw       _d4; = 4                  
            retlw       _S ; = 5 (S)            
            retlw       _d6; = 6                 
            retlw       _d7; = 7                                     
            retlw       _d8; = 8                                     
            retlw       _d9; = 9                    


;-----------------------------------------------------------------------------------




;===========================================================================
; ������������ ����� W*4 ���  
;===========================================================================
delay_Wx4__	
			addlw       -1
        IF  X_16
			nop
			nop	  
			nop
			nop	  
			nop
			nop	  
			nop
			nop	  
			nop
			nop	  
			nop
			nop	
        ENDIF  
			btfss       STATUS,Z
			goto        delay_Wx4__
			return
;-----------------------------------------------------------------------





;==============================================================================
;           ������������ �������� ��������� � ������� >0.2 ���. ������  
;==============================================================================

wait_nobutt__   
				call      button__
				movlw     .50
				call      pause__  ; =100ms
				btfsc     butt_flags,7
				goto      wait_nobutt__ ; �������� ��������� ������ 

				movlw     .50
				call      pause__  ; =100ms
				call      button__
				btfsc     butt_flags,7  ; �������� ��������� � ������� >0.2 ���. ������ 
				goto      wait_nobutt__
				return

;-------------------------------------------------------------------------------



;===================================================================================
;           ������������ �������� ������� ������
;     �������� - butt_time
;     �����: � W -1 -���� ������� , 0 - ��� ������� � ������� (3,4,6,10) ���.
;===================================================================================
wait_butt__
            
			movlw     .2 ;
            addwf     butt_time,w 
            movwf     count_    
            bcf       STATUS,C 
            rlf       count_,f   ;[(X+2)*2]*0.5 sec
wai_b
			movlw     .250
			call      pause__  ;500ms
			call      button__ 
			btfsc     butt_flags,7
			retlw     1h       ; ����� w=1, ���� ������ ������
			decfsz    count_,1 
			goto      wai_b   	  
			retlw     0h 	  
;-----------------------------------------------------------------------------------
 



;===================================================================================
;           ������������ ����������� ������� ������
;     �����: � W - 0 - ������� 1-� ��., 1 - ������� 2-� ��. 2-������� ����� ������
;            W>2 - ������ �� ������ 
;===================================================================================

push_butt__	  ; �������������� ��������� ����� �����. button__
			movf       butt_flags,w
			andlw      b'00000011'
			addlw      -1         ; � W - �������� �������� ���������
            clrf       pause_Hst ;����� ��������� �������� �� ���. ������
			return     

;----------------------------------------------------------------------------------









;=====================================================================================
;       ������������ ������������ ������
;  �������� regime_. ����: 0-���������� �������, 1-���������� ����., 2-������,
;                          3-����. �����. ���., 4-����. �����. ���., 5-����-FTt1t0
;=====================================================================================



regime__    
            clrf      fflags_    ; ����� ������ ���������

         	movf      regime_,w
			movwf     reg_temp   ; ��������� regime_ 

r_			call      ind_re__

			call      wait_nobutt__

			call      wait_butt__
			xorlw     0h
			btfsc     STATUS,Z
			goto      end_re  ; ��� �������  3/6/8/10 � - ����� �� ��

			call      push_butt__ ;���� ������ ������, ��������� �����
			xorlw     0h
			btfsc     STATUS,Z
			goto      r_3      ; 1-� - ��������� ������������� ������
			xorlw     1h
			btfss     STATUS,Z
			goto      r_      ; ��� ��� �� ���� - �� ������
                              ; ���� - ���� 2-� ������ ������

            bsf       STATUS,RP0 ;bank1 ......................
            movlw     30h
            movwf     EEADR  ;adr = 30h (regime_)
            bcf       STATUS,RP0 ;bank0
			movf      regime_,w  
			movwf     reg_temp   ; ���������� reg_temp
            call      EE_write__ ; ����. �����

r_2		
			clrw
			call      out_word__   ;W=0    ��������� ��������� ������ "--YES-- "
			call      wait_nobutt__ ;�������� �������
            goto      end_re
r_3		
			movlw     .1
			bcf       STATUS,C
			rlf       regime_,1   ;����� regime_
			btfsc     regime_,5   ;�� �����
			movwf     regime_     ;-->0..4,0.. 

			goto      r_

end_re
    		movf      reg_temp,w
			movwf     regime_    ; �������������� ������

            movlw     8h
            call      out_word__ ; ����� �� ���. ����� "-COUNt--"

			return



;--------------------------------------------------------------------------------------





;======================================================================================
;    ������������ ��������� �������
;    �������� - regime_
;======================================================================================
ind_re__
			btfsc   regime_,0
			movlw   1h    
			btfsc   regime_,1
			movlw   2h    
			btfsc   regime_,2
			movlw   3h     
			btfsc   regime_,3
			movlw   4h
			btfsc   regime_,4
			movlw   5h        ; ��������� ������� �������� ������ .....................

			call    out_word__ ; ����� �� ���. �����. ������
			return

;--------------------------------------------------------------------------------------





      
;====================================================================================
; ������������ ������� ��������� �� ��������� ����. w = .208 max
; ===================================================================================

tab_word__ 
			movwf       PC_temp
			movlw       HIGH t_word
			movwf       PCLATH
			movf        PC_temp,w
			addlw       LOW t_word 
			btfsc       STATUS,C
			incf        PCLATH,f
			movwf       PCL        ; ���������� �������� ������ PC �������������
t_word                             ; �� �������� ����������� ������������ W.

            retlw       _MIDDLE   
            retlw       _MIDDLE 
            retlw       _Y 
            retlw       _E       
            retlw       _S 
            retlw       _MIDDLE        
            retlw       _MIDDLE 
            retlw       _SPACE  
            retlw       _F 
            retlw       _r        
            retlw       _E       
            retlw       _q 
            retlw       _BOTTOM
            retlw       _BOTTOM    
            retlw       _S 
            retlw       _t             
            retlw       _F 
            retlw       _r        
            retlw       _E        
            retlw       _q 
            retlw       _BOTTOM 
            retlw       _BOTTOM        
            retlw       _S 
            retlw       _P            
            retlw       _SPACE  
            retlw       _P  
            retlw       _E  
            retlw       _r  
            retlw       _i        
            retlw       _o        
            retlw       _d  
            retlw       _SPACE        
            retlw       _t 
            retlw       _SPACE        
            retlw       _BOTTOM 
            retlw       _BOTTOM 
            retlw       _N 
            retlw       _BOTTOM        
            retlw       _BOTTOM
            retlw       _SPACE  
            retlw       _t 
            retlw       _SPACE        
            retlw       _UP  
            retlw       _UP         
            retlw       _U 
            retlw       _UP  
            retlw       _UP  
            retlw       _SPACE       
            retlw       _S       
            retlw       _E  
            retlw       _t
            retlw       _t       
            retlw       _I       
            retlw       _N  
            retlw       _G
            retlw       _S            
            retlw       _SPACE
            retlw       _SPACE
            retlw       _N        
            retlw       _O        
            retlw       _BOTTOM  
            retlw       _S 
            retlw       _I        
            retlw       _G            
            retlw       _MIDDLE
            retlw       _C        
            retlw       _O        
            retlw       _U  
            retlw       _N 
            retlw       _t        
            retlw       _MIDDLE
            retlw       _MIDDLE       
            retlw       _F
            retlw       _BOTTOM
            retlw       _t
            retlw       _o        
            retlw       _o        
            retlw       _BOTTOM  
            retlw       _h 
            retlw       _i            
            retlw       _P 
            retlw       _I        
            retlw       _n       
            retlw       _d 
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE 
            retlw       _SPACE         
            retlw       _t 
            retlw       _O        
            retlw       _F       
            retlw       _F 
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE 
            retlw       _SPACE  
            retlw       _t 
            retlw       _b        
            retlw       _u       
            retlw       _t 
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE 
            retlw       _SPACE  
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE     
            retlw       _F
            retlw       _P
            retlw       _t
            retlw       _MIDDLE        
            retlw       _t        
            retlw       _E  
            retlw       _S 
            retlw       _t            
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE     
            retlw       _MIDDLE
            retlw       _H
            retlw       _E
            retlw       _L        
            retlw       _L        
            retlw       _O  
            retlw       _MIDDLE 
            retlw       _SPACE        
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE     
            retlw       _A
            retlw       _u    
            retlw       _t
            retlw       _h    
            retlw       _o
            retlw       _r    
            retlw       _SPACE
            retlw       _SPACE     
            retlw       _SPACE
            retlw       _SPACE     
            retlw       _b
            retlw       _A    
            retlw       _L
            retlw       _A    
            retlw       _E
            retlw       _U          
            retlw       _SPACE
            retlw       _SPACE     
            retlw       _b
            retlw       _A    
            retlw       _S
            retlw       _h    
            retlw       _i
            retlw       _r          
            retlw       _SPACE
            retlw       _SPACE     
            retlw       _d2 ; = 2 
            retlw       _O    
            retlw       _I
            retlw       _d4 ; = 4    
            retlw       _SPACE
            retlw       _SPACE      
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE    
            retlw       _SPACE
            retlw       _SPACE     
            retlw       _SPACE
            retlw       _MIDDLE    
            retlw       _L
            retlw       _O    
            retlw       _A
            retlw       _d
            retlw       _MIDDLE
            retlw       _SPACE     
            retlw       _SPACE
            retlw       _MIDDLE    
            retlw       _S
            retlw       _A    
            retlw       _U
            retlw       _E
            retlw       _MIDDLE
            retlw       _SPACE     
            retlw       _t
            retlw       _o    
            retlw       _BOTTOM
            retlw       _S    
            retlw       _L
            retlw       _E
            retlw       _E
            retlw       _P         
     
            

       
       
          

;-------------------------------------------------------------------------------------- 


;=================================================================================
; ������������ ������ ������ � ���� ������� ������
;freq_  - ����� ��������� �����, freq_+1  - ��������
;=================================================================================
write__		movf        freq_,w  
			call        out_8__
			movf        freq_+1,w  
			subwf       freq_,w
			btfsc       STATUS,C  ;�������� ��������� ������
			return	 
			incf        freq_,1  ;����� ���� �� ���� �����
			movlw       .160
			call        pause__
 			goto        write__

;------------------------------------------------------------------------------------











;======================================================================================
;  ������������ ������ �����(8 ������) �� ������� �� ���������
;  � W - ���������� ����� ����� � �������
;  out_word__ - ���� (w)- ����� �����
;  out_8__ - ���� (w) - ����� ������ �����
;======================================================================================
out_word__
			movwf       var_temp
			bcf         STATUS,C
			rlf         var_temp,f
			rlf         var_temp,f
			rlf         var_temp,w ; *8 = ������. ����� 1-�� �����
out_8__            
            movwf       var_temp
			movlw       8h
			movwf       count_  ; ����� 8-�� ������
			addwf       var_temp,f ; 1-� ���� + 8
			movlw       LED_OUT+7
			movwf       FSR     ; ����� ������� �����
ow_1
			movf        count_,w
			subwf       var_temp,w ;  ������. ����� ���������� �����
			call        tab_word__ ;  ��������� ����
			movwf       INDF       ;  ���� �� ���������
			decf        FSR,f
			decfsz      count_,f   ;  ��� 8 ������?
			goto        ow_1       

			return


;-----------------------------------------------------------------------------------



;===================================================================================
; ������������ �������� ��������� 4-���������� ����� � ��������������� BCD
; ���������: 4-����. ����� freq_, out_bcd  - ������� ����. - �����. �������� 
; 1871 ������
;===================================================================================
b2bcd__
			movlw	.32		; 4 ����� - 32-����
			movwf	count_		 
			clrf	out_bcd		
			clrf	out_bcd+1
			clrf	out_bcd+2
			clrf	out_bcd+3   ; ������� ����� BCD
	
b2bcd2
			movlw	out_bcd		
			movwf	FSR
			movlw	4h
			movwf	temp ; ��������� ���. �����

b2bcd3  		        ; ���� 
			movlw	33h		
			addwf	INDF,f		; ����� ��� ���������
			btfsc	INDF,3		;  �7 ?
			andlw	0f0h		; ����������� ����. ��. ���������
			btfsc	INDF,7		; ��. �������� >7 ?
			andlw	0fh	 	  	; ����������� ����. ��.���������
			subwf	INDF,f		; �������� ������������� ���������
			incf	FSR,f		; ��������� ����
			decfsz	temp,f
			goto	b2bcd3
	
			rlf	freq_+0,f 	; ����. ���
			rlf freq_+1,f
			rlf freq_+2,f
			rlf	freq_+3,f
			rlf	out_bcd+0,f	; --> BCD
			rlf	out_bcd+1,f
			rlf	out_bcd+2,f
			rlf	out_bcd+3,f

			decfsz	count_,f		; ���?
			goto	b2bcd2	
			return			;�����

;----------------------------------------------------------------------------------


;======================================================================================
;  ������������ ������ �� ��������� bcd-����� � �������� ���������� ����� �����
;  ���������: � W -  ���. ������� ������ ������ (0-7) W=0 or W>7 - ���. ���
;======================================================================================
outBCD__
			bcf        INTCON,GIE   ;..................................................
obcd_0
			btfss      PIR1,TMR2IF
			goto       obcd_0
			bsf        INTCON,GIE   
			movwf     temp  ; ���� ��. ��������
						  
			sublw     7h
			btfss     STATUS,C
			clrf      temp  ; W>7 --->W=0
			movf      temp,w

			clrf      temp+1
			decf      temp+1,f ; =ffh
obcd_2
			bcf       STATUS,C
			rlf       temp+1,f
			addlw     -1
			btfsc     STATUS,C
			goto      obcd_2     ; �� ������: ������ ���. ���. �������. ����, ����� -1

			
			movlw	LED_OUT+7
			movwf	freq_+1		; ����� ������
			movlw	out_bcd+3
			movwf	freq_+2		; ������� bcd �����
			movlw	4h		; 4 �����
			movwf	count_
obcd_3
			movf	freq_+2,w	; ������� ������ �����
			movwf	FSR
			decf	freq_+2,f	; ����. ����. �������� ����� 
			movf	INDF,w		; ���������� 2 bcd
			movwf	freq_		; ����������
			movf	freq_+1,w	; ������� ������ ������ 
			movwf	FSR
			decf	freq_+1,f	; 
			decf	freq_+1,f   ; ���. --> -2 ������
			swapf	freq_,w		; 
			andlw	0fh         ; ����. �������� ����. �� ������������ �������� �����
			btfss   STATUS,Z    ;=0?
			clrf    temp+1      ; ��������� <>0 --> ������ ��� ���� ��������
			call    Table_s__   ; ��������������
			btfsc   temp+1,7
			movlw   _SPACE      ; ������� ����������� ����
			movwf	INDF		; �� �����
			bcf     STATUS,C
			rlf     temp+1,f    ; ��� �������� ����. ����.

			decf	FSR,f
			movf	freq_,w		; 
			andlw	0fh	 		; ���������� ��. ���������
			btfss   STATUS,Z
			clrf    temp+1    ; ��������� <>0 --> ������ ��� ���� ��������
			call    Table_s__   ; ��������������
			btfsc   temp+1,7    ;...... 7-� ��� =1 - ����. ���� (���������� ������)......
			movlw   _SPACE      ; ������� ����������� ����
			movwf	INDF		; �� �����
			bcf     STATUS,C
			rlf     temp+1,f    ; ��� �������� ����. ����.

			decfsz	count_,f	; ��� �����?
			goto	obcd_3
	
                           ;.................����� �������....................... 
			movf      temp,f 
			btfsc     STATUS,Z   ; ��� �������
			return
			movlw     LED_OUT
			addwf     temp,w
			movwf     FSR
			bsf       INDF,3     ; � �������, ��� ������� - ���. ��� 3
			return
			
;---------------------------------------------------------------------------------------


;=======================================================================================
; ������������ ���������� ��������� ���� 1/�, ������� ���������� ���. 1000000000/�
; ������� �������� ���, ����� ��������� ��������� � ������������� ��� � ������.
; ���������: out_bcd - ������� (1000000000), freq_ -��������, temp - ��������������� �����
;            (��� ����� ��������������, 1-� ������ - ��. ������), ��������� - � freq_
; ����������: 0 - �������� ����� ����, 1 - �������        
;========================================================================================

DIVIDE_1byX__

        ; Test for zero division
        movf    freq_,w
        iorwf   freq_+1,w
        iorwf   freq_+2,w
        btfsc   STATUS,Z
        retlw   0x00    ; divisor = zero, not possible to calculate return with zero in w



        movlw   3bh
        movwf   out_bcd+3
        movlw   9ah
        movwf   out_bcd+2
        movlw   0cah
        movwf   out_bcd+1
        clrf    out_bcd     ; ��������� � out_bcd �������� 1000.000.000 (0x3B9ACA00)

                   ;��� ���������� ����������, ������ x/y ��������� (x+y/2)/y       
        bcf     STATUS,C   ;
        rrf     freq_+2,w  ;
        movwf   temp+2     ;
        rrf     freq_+1,w  ;
        movwf   temp+1     ;
        rrf     freq_,w    ;
        movwf   temp       ; freq_/2 ---> temp

        movf    temp,w        ; out_bcd = 1000000000+freq_/2 ...................
        addwf   out_bcd,f        
        movf    temp+1,w     
        btfsc   STATUS,C      
        incfsz  temp+1,w     
        addwf   out_bcd+1,f        
        movf    temp+2,w       
        btfsc   STATUS,C       
        incfsz  temp+2,w
        addwf   out_bcd+2,f 
        btfsc   STATUS,C       
        incf    out_bcd+3,f    ;............................................... 
                    

        call    DEVIDE_32to24__ ;  (1000000000+freq_/2)/freq_

        movf    out_bcd,w
        movwf   freq_
        movf    out_bcd+1,w
        movwf   freq_+1
        movf    out_bcd+2,w
        movwf   freq_+2
        movf    out_bcd+3,w
        movwf   freq_+3       ;  ----> freq_

        retlw   1    ; done

;---------------------------------------------------------------------------------------
   




;=======================================================================================
;  ������������ ������� 4-���������� ����� (out_bcd) �� 3-� ��������� (freq_)
;  temp - 4-� ��������� �����
;  ��������� - out_bcd, ������� - temp
;=======================================================================================
DEVIDE_32to24__

        ; prepare used variables
        clrf    temp
        clrf    temp+1
        clrf    temp+2
        clrf    temp+3

        movlw  .32     ;MOVLW   D'48'           ; initialize bit counter
        movwf   count_

DIVIDE_LOOP_48by24
        rlf     out_bcd,f
        rlf     out_bcd+1,f
        rlf     out_bcd+2,f
        rlf     out_bcd+3,f
        ; shift in highest bit from dividend through carry in temp
        rlf     temp,f
        rlf     temp+1,f
        rlf     temp+2,f

        rlf     temp+3, f

        movf    freq_,w     ; get LSB of divisor
        btfsc   temp+3, 7
        goto    Div48by24_add

        ; subtract 24 bit divisor from 24 bit temp
        subwf   temp,f        ; subtract

        movf    freq_+1,w     ; get middle byte
        btfss   STATUS,C        ;  if overflow ( from prev. subtraction )
        incfsz  freq_+1,w     ; incresase source
        subwf   temp+1,f        ; and subtract from dest.

        movf    freq_+2,w       ; get top byte
        btfss   STATUS,C        ;  if overflow ( from prev. subtraction )
        incfsz  freq_+2,w       ; increase source
        subwf   temp+2,f          ; and subtract from dest.

        movlw   1
        btfss   STATUS,C
        subwf   temp+3, f
        goto    DIVIDE_SKIP_48by24 ; carry was set, subtraction ok, continue with next bit 

Div48by24_add
        ; result of subtraction was negative restore temp
        addwf   temp,f        ; add it to the lsb of temp

        movf    freq_+1,w     ; middle byte
        btfsc   STATUS,C        ; check carry for overflow from previous addition
        incfsz  freq_+1,w     ; if carry set we add 1 to the source
        addwf   temp+1,f        ; and add it if not zero in that case Product+Multipland=Product

        movf    freq_+2,w       ; MSB byte
        btfsc   STATUS,C        ; check carry for overflow from previous addition
        incfsz  freq_+2,w
        addwf   temp+2,f          ; handle overflow

        movlw   1
        btfsc   STATUS,C
        addwf   temp+3, f

DIVIDE_SKIP_48by24
        decfsz  count_,f      ; decrement loop counter
        goto    DIVIDE_LOOP_48by24      ; another run
        ; finally shift in the last carry
        rlf     out_bcd,f
        rlf     out_bcd+1,f
        rlf     out_bcd+2,f
        rlf     out_bcd+3,f

        return 
;----------------------------------------------------------------------------------------




;=================================================================
; ������������ �������� � ������ �����
;=================================================================
to_Sleep__
            movlw   .22
            call    out_word__ ;�������� ���.

            bcf     INTCON,GIE

            movlw   b'00000100'
            movwf   PORTA
            clrf    PORTB

            bsf     STATUS,RP0 ;bank 1
            movlw   b'11110011'
            movwf   TRISA
            movlw   b'10000000'
            movwf   TRISB

            bcf     STATUS,RP0 ;bank 0
            movf    PORTB,w    ;   ��������� �������.
            bsf     STATUS,RP0 ;bank 1

            bsf     INTCON,RBIE
            bcf     INTCON,RBIF
            sleep           
            bcf     INTCON,RBIE

			movlw     .124   ;-- ��������������--
            movwf     PR2   ; ������� ���������� �� TMR2 - 125*16 = 2 ����

            movlw   b'11110000'
            movwf   TRISA
            movlw   b'00001000'
            movwf   TRISB
            bcf     STATUS,RP0 ;bank 0

            bsf     INTCON,GIE
            call    wait_nobutt__
            return
;-------------------------------------------------------------------

                                    


;=============================================================================
;        ������������ ���������� �� EEPROM
; ��������� ���� ���������� ����� ���., ����� ���. �����. (+1)
;=============================================================================

EE_read__	bsf        STATUS,RP0  ; BANK 1
			bsf        EECON1,RD
			movf       EEDATA,w
			incf       EEADR,1
			bcf        STATUS,RP0  ; BANK 0
			return
;-----------------------------------------------------------------------------


;=============================================================================
;        ������������ ������ � EEPROM
; ����������� ���� ���������� ����� ���., ����� ���. �����. (+1)
;=============================================================================
EE_write__ 
            bsf        STATUS,RP0  ;  ����1. 
            movwf      EEDATA     ; �������� ������

			bcf        INTCON,GIE   ; ��������� ����������
			bcf        STATUS,RP0  ;  ����0.

			clrf       PORTB      ; �������� ��������� ����������
			bcf        PORTA,3    ; �������� ���������� �� ����� ������

			movlw      .250         ;
			call       delay_Wx4__  ;   
			movlw      .250         ;
			call       delay_Wx4__  ;   
			movlw      .250         ;
			call       delay_Wx4__  ; ����� 3 ���� 
			
			bsf        STATUS,RP0  ;  ����1. 	
            bsf        EECON1,WREN    ; ��������� ������.                                   
            movlw      55h        ; ������������
            movwf      EECON2      ; ���������
            movlw      0AAh        ; ��� ������.
            movwf      EECON2      ; ----"----
            bsf        EECON1,WR    ; ----"----

			bsf        INTCON,GIE  ;��������� ����������

            bcf        STATUS,RP0  ; ����0			
eepr_1		btfss      PIR1,EEIF
			goto       eepr_1    ;�������� ����� ������ 
			bcf        PIR1,EEIF  ;����� ����� ����.

			bsf        STATUS,RP0  ;  ����1. 
			bcf        EECON1,WREN ;������ ������
			incf       EEADR,1     ; ���������� �����a ��� ��������� ������
            bcf        STATUS,RP0  ; ����0
			return


;-----------------------------------------------------------------------------



;============================================================================
; ������������ ���������
; ����������: ind_per, off_time, butt_time.  temp - ��������� 
;             temp+1 - � �������� ���-��� ����
;============================================================================

to_sets__    
            movlw     .1
            movwf     temp 
            movf      ind_per,w
            movwf     temp+1
ts_1
    		call      ind_set__
            call      wait_nobutt__

            movlw     b'00000111'
            btfsc     temp,3
            clrw
            movwf     flash_flags ; �������� 3-� ��. ����.(����) 

			call      wait_butt__
			xorlw     0h
			btfsc     STATUS,Z
			goto      ts_2  ; ��� ������� 8 � - ����� �� ��

			call      push_butt__ ;���� ������ ������, ��������� �����
			xorlw     0h
			btfsc     STATUS,Z
			goto      ts_3      ; 1-� - ��������� ������������� ������
			xorlw     1h
			btfss     STATUS,Z
			goto      ts_1     ; ��� ��� �� ���� - �� ������
                              ; ���� - ���� 2-� ������ ������

            btfss     temp,3
            goto      ts_4
            call      auth__
            call      wait_nobutt__
            return
ts_4
			movlw     .1
			bcf       STATUS,C
			rlf       temp+1,f   ;�����
			btfsc     temp+1,4   ;�� �����
			movwf     temp+1     ;-->0..3,0.. 

			goto      ts_1

			     
ts_3		
            movf      temp+1,w  ;
            btfsc     temp,0    ;
            movwf     ind_per   ;
            btfsc     temp,1    ;
            movwf     off_time  ;
            btfsc     temp,2    ;
            movwf     butt_time ; ������ ������ ����. ���. ���.

			movlw     .1
			bcf       STATUS,C
			rlf       temp,f   ;�����
			btfsc     temp,4   ;�� �����
			movwf     temp     ;-->0..3,0.. 

            btfsc     temp,3
            goto      ts_1

            btfsc     temp,0
            movf      ind_per,w
            btfsc     temp,1
            movf      off_time,w
            btfsc     temp,2
            movf      butt_time,w
            movwf     temp+1


			goto      ts_1

ts_2
            movf      temp+1,w  ;
            btfsc     temp,0    ;
            movwf     ind_per   ;
            btfsc     temp,1    ;
            movwf     off_time  ;
            btfsc     temp,2    ;
            movwf     butt_time ; ������ ������ ����. ���. ���.

            bsf       STATUS,RP0 ;bank1 ......................
            movlw     31h
            movwf     EEADR  ;adr = 31h
            bcf       STATUS,RP0 ;bank0
            movf      ind_per,w
            call      EE_write__  
            movf      off_time,w
            call      EE_write__  
            movf      butt_time,w
            call      EE_write__  ;....������ ��������� � EEprom

            clrf      flash_flags        
			return

;--------------------------------------------------------------------------------


;======================================================================================
;    ������������ ��������� ������� SET
;    �������� - temp
;======================================================================================
ind_set__
			btfsc   temp,0
			movlw   .10    
			btfsc   temp,1
			movlw   .11    
			btfsc   temp,2
			movlw   .12    
			btfsc   temp,3
			movlw   .18     ; ��������� ������� �������� ������ SET .....................

			call    out_word__ ; ����� �� ���. �����. ������ SET
            call    out_set__  ; ����� ����. �����. ���������

            btfss   temp,3
            bsf     LED_OUT+7,3 ; ������� � 1-� ����. ����� 'Author'

			return

;--------------------------------------------------------------------------------------



;======================================================================================
;    ������������ ��������� �������� ������� ���������
;    �������� - temp, temp+1
;======================================================================================
out_set__
			btfss   temp,0
            goto    os_1

            movlw   _O; 0  ;----- ��� ���. 1-�� ����---------
            btfsc   temp+1,0 ; 0.25,0.5,1.0,2.0
            movlw   _S; 5
            movwf   LED_OUT

            movlw   _O; 0
            btfsc   temp+1,1
            movlw   _S; 5
            btfsc   temp+1,0
            movlw   _d2 ; = 2
            movwf   LED_OUT+1

            movlw   _O; 0
            btfsc   temp+1,2
            movlw   _I; 1
            btfsc   temp+1,3
            movlw   _d2 ; = 2
            movwf   LED_OUT+2
            bsf     LED_OUT+2,3 ; �������
            return       ;---------------------------------------
os_1   
			btfss   temp,1
            goto    os_2
            
            clrw            ; .. 8,16,32,64..................
            btfsc   temp+1,1
            movlw   _I
            btfsc   temp+1,2
            movlw   _d3 ; = 3
            btfsc   temp+1,3
            movlw   _d6 ; = 6
            movwf   LED_OUT+1

            movlw   _d8 ; = 8
            btfsc   temp+1,1
            movlw   _d6 ; = 6
            btfsc   temp+1,2
            movlw   _d2 ; = 2
            btfsc   temp+1,3
            movlw   _d4 ; = 4 
            movwf   LED_OUT
            return
os_2
			btfss   temp,2
            return
            
            movlw   _O        ;....... 3,4,6,10...........
            btfsc   temp+1,0
            movlw   _d3 ; = 3
            btfsc   temp+1,1
            movlw   _d4 ; = 4 
            btfsc   temp+1,2
            movlw   _d6 ; = 6
            movwf   LED_OUT

            movlw   _I 
            btfsc   temp+1,3
            movwf   LED_OUT+1
            return

;--------------------------------------------------------------------------------------



;=============================================================================
; ������������ �������� ��������� ������� �� ���������� � SLEEP
;=============================================================================
time_Sleep
            bcf     STATUS,C    ;
            rlf     off_time,w  ;
            movwf   count_      ;
            rlf     count_,w    ;off_time*4
            
            xorwf   pause_Hst,w
            btfss   STATUS,Z
            return
            call    to_Sleep__
            clrf    pause_Hst
            return

;-----------------------------------------------------------------------------




;===========================================================================
; ������������ 
;===========================================================================
auth__
            movlw     .250
            call      pause__
            movlw     .250
            call      pause__

            movlw     .136      ;
            movwf     freq_     ;
            movlw     .176      ;
            movwf     freq_+1   ;
            call      write__   ; 

            movlw     .250
            call      pause__
            movlw     .250
            call      pause__

            return



;============================================================================
; ������������ ��������� ������� 2-� ������ (������,������ �������� � EEPROM)
;============================================================================
EE_ls__
			movlw      b'00000111'
			andwf      fflags_,f    ; c���� ���� ������ �������� ����-��

            btfsc      regime_,0
            clrw
            btfsc      regime_,1
            movlw      .8
            btfsc      regime_,2
            movlw      .16
            btfsc      regime_,3
            movlw      .24
            btfsc      regime_,4
            movlw      .32

            bsf        STATUS,RP0 ;bank1
            movwf      EEADR
            bcf        STATUS,RP0 ;bank0

            movf     LED_OUT,w
            movwf    L_out
            movf     LED_OUT+1,w
            movwf    L_out+1
            movf     LED_OUT+2,w
            movwf    L_out+2
            movf     LED_OUT+3,w
            movwf    L_out+3
            movf     LED_OUT+4,w
            movwf    L_out+4
            movf     LED_OUT+5,w
            movwf    L_out+5
            movf     LED_OUT+6,w
            movwf    L_out+6
            movf     LED_OUT+7,w
            movwf    L_out+7  ;.......... LED_OUT --> L_out.......

            movlw     .23
            call      out_word__ ; ' -LOAd- '
	    	movlw     .100
			call      pause__  ; =200ms

els_1
			call      button__
			btfsc     butt_flags,0 
            goto      els_2   ; ������ 1-� (���) ������
			movlw     .5
			call      pause__  ; =10ms
			btfsc     butt_flags,7
			goto      els_1 ; �������� ��������� ������ 
			movlw     .25
			call      pause__  ; =50ms
			call      button__
			btfsc     butt_flags,7  ; �������� ��������� � ������� >0.1 ���. ������ 
			goto      els_1

         ;.............. ���� ������ ������ 2-� ������ .................

            movlw      LED_OUT  ;...................................
            movwf      FSR
            movlw      .8
            movwf      count_
els_3
            call       EE_read__
            movwf      INDF
            incf       FSR,f
            decfsz     count_,f
            goto       els_3   ;...... �� ���. - ����������� ����. ....
            
            movlw      0ffh
            movwf      flash_flags ; �������� ���� ����.

            clrf       pause_H    ;
els_5                             ;
            btfss      pause_H,4  ;
            goto       els_5      ; ����� 8 ���.

            clrf       flash_flags
            return
            
els_2    ;...............������ ��� ������ ������������.................
            movlw      .24
            call       out_word__ ; ' -SAUE- '
            call       wait_nobutt__
            movlw      0ffh
            movwf      flash_flags ; �������� ���� ����.

            movlw      L_out  ;...................................
            movwf      FSR
            movlw      .8
            movwf      count_
els_6
            movf       INDF,w
            call       EE_write__
            incf       FSR,f
            decfsz     count_,f
            goto       els_6   ;...... �� ���. - ����������� ����. ....

            clrf       pause_H    ;
els_7                             ;
            btfss      pause_H,3  ;
            goto       els_7      ; ����� 4 ���.

            clrf       flash_flags
            return

;------------------------------------------------------------------------------


;=====================================================================================
;       ������������ ��������� � ����������
;=====================================================================================

off_set__    
    		clrf      reg_temp

ofs_1		
			movlw     6h
			btfss     reg_temp,0
			movlw     .25        ; ��������� ������� �������� ������ 

			call      out_word__ ; ����� �� ���. �����. ������

			call      wait_nobutt__

			call      wait_butt__
			xorlw     0h
			btfsc     STATUS,Z
			goto      ofs_5     ; ��� �������  3/6/8/10 � - ����� �� ��

			call      push_butt__ ;���� ������ ������, ��������� �����
			xorlw     0h
			btfss     STATUS,Z
			goto      ofs_2 
                         ; 1-� - ��������� ������������� ������
            comf      reg_temp,f
            goto      ofs_1            
ofs_2
			xorlw     1h
			btfss     STATUS,Z
			goto      ofs_1    ; ��� ��� �� ���� - �� ������
                              ; ���� - ���� 2-� ������ ������

			clrw
			call      out_word__   ;W=0    ��������� ��������� ������ "--YES-- "
			call      wait_nobutt__ ;�������� �������

            btfsc     reg_temp,0 ; 
            call      to_sets__ ; ���������
ofs_5
            btfss     reg_temp,0 ; 
            call      to_Sleep__; Sleep

            movlw     8h
            call      out_word__ ; ����� �� ���. ����� "-COUNt--"

			return



;--------------------------------------------------------------------------------------



;======================================================================================
; ������������ ��������� ������� 1-�� ������
;======================================================================================
put_butt_1__
			movlw      b'00000111'
			andwf      fflags_,f    ; c���� ���� ������ �������� ����-��

            movlw      .100
            call       pause__ ; 0.2 s
            call       ind_re__

            movlw     .30
            movwf     count_
pb_1   
			call      button__
			movlw     .50
			call      pause__  ; =100ms
			btfsc     butt_flags,2  ; 2-� ��.?
			return 
    		btfss     butt_flags,7
			goto      pb_2 ; ���. ��� ��������� ������� 
            decfsz    count_,f
            goto      pb_1

            call      off_set__
            return
pb_2
            call      regime__
            return

;---------------------------------------------------------------------------



;===========================================================================
;  ������������ �������� ������������ ����������� �� EEPROM ����������
;  � ������ �������������� - ������ �� ����������� �������� (1)
;  ����, ����� - W
;===========================================================================
var_test__
            andlw     b'00011111'
            btfss     regime_,7 ; ����������, ���� ���. - regime_
            andlw     b'00001111'
            movwf     var_temp   ; ����. 
            movwf     temp
            movlw     5h
            movwf     count_
            clrw
vt_1
            btfsc     temp,0
            addlw     1h
            rrf       temp,f
            decfsz    count_,f
            goto      vt_1
                    ; ��� ���������� ��������  w=1
            xorlw     1h
            btfss     STATUS,Z
            retlw     1h  ;   w<>1 - ������ �� 1
            movf      var_temp,w ; ��������������
            return

;------------------------------------------------------------------------------






			end



