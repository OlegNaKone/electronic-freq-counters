
;==========================================================================
;  ПРОГРАММА МНОГОФУНКЦИОНАЛЬНОГО ЧАСТОТОМЕРА
;
;  Автор: Башир Балаев, г.Нальчик, 2014г. (bash-07@yandex.ru)    
;==========================================================================

        LIST         P=16F628A
		#include p16f628a.inc  


;----------------------------------------------------------------------------------
;               Предварительная запись EEPROM
;   00h - 27h - по 8 байт сохр. значения F(st),F(sp),P,t(1),t(0)
;   30h - начальный режим
;   31h - знач. периода индикации (1,2,4,8) (*0.25c)
;   32h - время до отключения     (1,2,4,8) (*8 min)
;   33h - время ожидания нажатия кнопки (1,2,4,8) (+2 sec)
;----------------------------------------------------------------------------------
			org  h'2100'
			de   77h,0,0,0,0,0,0,0,77h,0,0,0,0,0,0,0,77h,0,0,0,0,0,0,0,77h,0,0,0,0,0,0,0,77h,0,0,0,0,0,0,0
            org  h'2130'
            de   1h,2h,2h,4h ; ст. част., период 0.5сек., время 20 мин., ожид. 6 сек.
			org  h'2140'
			de   "Author:  Bashir Balayev. Nalchik 2014. bash-07@yandex.ru"


;========================================================================================
;  УСТАНОВКА ЧАСТОТЫ КВАРЦЕВОГО РЕЗОНАТОРА
;----------------------------------------------------------------------------------------
X_16      EQU       0      ;  1 - 16 MHz , 0 - 4 MHz
;========================================================================================


;============================================================================================================



     __CONFIG (_BOREN_OFF&_CP_OFF&_DATA_CP_OFF&_PWRTE_ON&_WDT_OFF&_LVP_OFF&_MCLRE_ON&_HS_OSC)     



;====================================================================================
; Определение переменных        
; =================================================================================== 


    CBLOCK		70h
		LED_OUT :8    ; 8 знаков на индикатор 
		fsr_temp 
		status_temp
		w_temp
		pause_          ; пауза - Х*2 мс
        pause_H         ;
        pause_Hst       ; 2 min
		tmr2_count   
		fflags_  
    ENDC                  ;7Fh

    CBLOCK      20h
		out_bcd :4
		regime_      ;0-обыч. частотомер, 1-спец.частотомер, 3-период, 4-длит. полож.
                     ;5-длит. отр. импульса
		reg_temp
		butt_flags   ; флаги обслуж. кнопок
		PC_temp
		tmr1_count   
		count_
		column        ;№ включенного разряда
		var_temp
		freq_  :4   ; частота и др. отсчеты (f, T, t) в 2-чном виде
        temp :4
        var_pause 
        flags_      ; разные флаги: (7 - была индикация за 0.25 сек, 
        flash_flags :3  ; 1-я - маска моргающего разр.(1-морг.), другие - вспомог.
        ind_per     ; период индикации (0,1,2 соотв. 0.25, 0.5, 1 сек.)
        off_time    ; время до отключения (0-31 соотв. 2-62 мин.)
        butt_time   ; время ожидания нажатия кнопок
        L_out  :8   ; копия знаков на индикатор
        portb_temp  ; сохраненное знач. порта В
    ENDC    ;43h
;------------------------------------------------------------------------------------




;====================================================================================
;                            КОНСТАНТЫ
;====================================================================================

LEVEL_CONT SET .10   ; 1/3 кол-ва выборок при опр. ср. уровня (от 5 до .30)

      IF  (LEVEL_CONT < .5)||(LEVEL_CONT >.30)
    LEVEL_CONT SET .15           ;<5 или >30 -->15
      ENDIF



;------------------------------------------------------------------------------------
;  Знаки на индикатор
;------------------------------------------------------------------------------------
 
_A       EQU  b'11100111' ;   A 
_b       EQU  b'11110100' ;   b 
_C       EQU  b'01110001' ;   C 
_c       EQU  b'10110000' ;   c 
_d       EQU  b'10110110' ;   d
_E       EQU  b'11110001' ;   E    
_F       EQU  b'11100001' ;   F 
_SPACE   EQU  b'00000000' ;  ПОГАШ
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
_UP      EQU  b'00000001' ;  'черт. сверху'
_q       EQU  b'11000111' ;   q                     
_N       EQU  b'01100111' ;   П 
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
;    Подпрограмма обработки прерываний
;==================================================================================
;==================================================================================			          

			org 4

			movwf       w_temp
            swapf       STATUS,w
            movwf       status_temp  ;coxpaнение W и STATUS
			swapf       FSR,w
			movwf       fsr_temp

			clrw        
            movwf       STATUS ; банк0, флаги 0
		
			btfsc       PIR1,TMR2IF
            goto        tmr2_int
 
        	btfsc       PIR1,TMR1IF
            goto        tmr1_int 

			goto        exit_

;=============================ПРЕРЫВАНИЕ ОТ TMR1============================================ 
tmr1_int 
			bcf         PIR1,TMR1IF 
            bcf         tmr1_count,7 ; сброс флага переполнения TMR1 до обраб. захвата			
			incf        tmr1_count,f ; инкр. самого старшего разряда TMR1
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
			goto        exit_           ; завершить прерыв. если прошло менее 2(3 -при 4MHz) сек.
			bsf         fflags_,1      ; установить флаг переполнения
			bsf         PIR1,CCP1IF     
			goto        exit_

;============================ ПРЕРЫВАНИЕ ОТ TMR2 ======================================
tmr2_int ;.......................Об. частотомер............................................
			btfss       fflags_,3
			goto        t2i_1     ; пропустить если не частотомер
			btfsc       fflags_,7
			goto        t2i_3      ; если счет уже идет
			bsf         fflags_,7  ; cчет пошел
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
			bsf         fflags_,4  ; cчет окончен
			goto        t2i_1
t2i_4
			incf        tmr2_count,f
			btfss       STATUS,Z
			goto        t2i_1
			btfsc       fflags_,6  
			goto        t2i_2
			bsf         fflags_,6  ;вторая половина сек.
			movlw       .13
			movwf       tmr2_count ; нач.знач.
			goto        t2i_1
t2i_2
			bsf         fflags_,5  ;
	   ;------------------------------------------------------------------------------------								
t2i_1    

		 	incf        pause_,f   ; инкремент "pause_" каждые 2 мс
            btfsc       STATUS,Z
            incf        pause_H,f
            btfsc       STATUS,Z
            incf        pause_Hst,f ;счетчик 2 мин. интервалов

;..........................Динамическая индикация...........................................  
        movf        flash_flags,w ; (xxxxxxxx) 1-моргание, 0-нет моргания

 			incf        column,f  ; след. разряд
			btfsc       column,3  ; если был 7-й разряд
			clrf        column    ; включение 0-го разряда 

        btfsc       STATUS,Z        ;
        movwf       flash_flags+1   ; 
        rrf         flash_flags+1,f ;
        clrf        flash_flags+2   ;
        btfss       STATUS,C        ;
        decf        flash_flags+2,f ; обработка моргания знака

			clrf        PORTB    ; погасить сегменты
			clrf        PORTA    ; и запятую

			movlw       LED_OUT
			addwf       column,w 
			movwf       FSR      ; Адрес след. знака

			movf        column,w ;
			btfsc       INDF,3      ;
			iorlw       b'00001000' ; установлен 3-й бит LED_OUT - зажечь запятую
            movwf       PORTA    ; вывод разряда и запятой

			movf        INDF,w  ; След. знак
			andlw       b'11110111' ; сбросить 3-й бит

        btfsc       pause_,7       ;
        andwf       flash_flags+2,w ; реализация моргания

			movwf       PORTB      ; вывод на индикатор LED_OUT соответст. разряду

            bcf         PIR1,TMR2IF  ; СБРОС ФЛАГА  

;========================= ВЫХОД ИЗ ВСЕХ ПРЕРЫВАНИЙ ==============================
exit_  		swapf       fsr_temp,w
			movwf       FSR       ; восст. FSR
		    swapf       status_temp,w
            movwf       STATUS
            swapf       w_temp,f  ; восстановление W и STATUS
            swapf       w_temp,w
 			retfie

;-----------------------------------------------------------------------------------
;===================================================================================




			

;====================================================================================
;                 П Р О Г Р А М М A
;====================================================================================
;                НАЧАЛО  (инициализация)
;====================================================================================
begin       bcf       STATUS,RP1
			bsf       STATUS,RP0  ; bank 1
			movlw     b'00001000'
			movwf     TRISB
			movlw     b'11110000' ; число в соответствии с количеством разрядов
			movwf     TRISA      
			clrwdt
          	movlw     b'11100111'
            movwf     OPTION_REG  ; TMR0 от RA4, передний фронт, преддел.TMR0- 256, рез.-откл.

            clrf      LED_OUT
            clrf      LED_OUT+1
            clrf      LED_OUT+2
            clrf      LED_OUT+3
            clrf      LED_OUT+4
            clrf      LED_OUT+5
            clrf      LED_OUT+6
            clrf      LED_OUT+7  ; инициализация сегментных регистров

            movlw     b'00000010'
			movwf     PIE1     ; ПРЕРЫВАНИЕ ОТ TMR2  
 		
			movlw     .124
            movwf     PR2   ; Инервал прерывания от TMR2 - 125*16 = 2 мсек

			bcf       STATUS,RP0 ; bank0
            movlw     07h
			movwf     CMCON  ; откл. компараторы

    IF   X_16
            movlw     b'00011111'; включить TMR2, преддел. = 16. вых. дел - 4.
        ELSE
            movlw     b'00000111'; включить TMR2, преддел. = 16. вых. дел - 1.
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
            movwf     column     ; разряд "1"
			movlw     b'11000000' ; разрешить прерыв. от периферии ,
			movwf     INTCON    ;  + глобальное

  ;---------------------- Восстановление сохраненных значений ----------          
  
            bsf       regime_,7  ;  индикатор

			bsf       STATUS,RP0 ; bank1
            movlw     30h
            movwf     EEADR    ;нач. значения:
			call      EE_read__
            call      var_test__; проверка корректности переменной
			movwf     regime_   ; режим 
			call      EE_read__
            call      var_test__
			movwf     ind_per   ; период индикации 
			call      EE_read__
            call      var_test__
			movwf     off_time  ; время до отключения  
			call      EE_read__
            call      var_test__
			movwf     butt_time ; время ожидания наж. кнопок  



;================================================================================            
;		       	П Р О Г Р А М М А  (основной цикл)
;================================================================================
            movlw     .250
            call      pause__     ; 0.5 sec

            movlw     .104      ;
            movwf     freq_     ;
            movlw     .136      ;
            movwf     freq_+1   ;
            call      write__   ; 

start   ; Главный цикл

			btfsc     regime_,0 ; 0 бит - обычный частотомер
			call      freq_standart__
			btfsc     regime_,1 ; 1 бит - спец. частотомер
			call      freq_special__
            btfsc     regime_,2 ; 2 бит - период
            call      period__
            btfsc     regime_,3 ; 3 бит - длительность 1
            call      t_meter__
            btfsc     regime_,4 ; 4 бит - длительность 0
            call      t_meter__

            call      time_Sleep 
           
            movlw     .150
		    call      delay_Wx4__    ; 0.6 ms      

			call      button__

			btfsc     butt_flags,7  ;
            clrf      flash_flags   ;откл. моргания при нажатии кнопки 
			btfsc     butt_flags,7  ;
            clrf      pause_Hst     ;сброс времени откл. 

			btfss     butt_flags,0 
            goto      st_2
			call      put_butt_1__   ; если нажата 1-я кнопка
            goto      start
st_2
			btfsc     butt_flags,1 
			call      EE_ls__     ; если нажата 2-я кнопка

            goto   start


;---------------------------------------------------------------------------------------




			


;=======================================================================================
; ПОДПРОГРАММА  ЧАСТОТОМЕРА СПЕЦИАЛЬНОГО
; 1. До 1000 Гц - вычисление част. F=1/T, где Т - период
; 2. ОТ 1000 Гц - обычный подсчет имп. за 1 сек.
;    Гистерезис - 100 гц (т.е. интервалы 0 - 1000 Гц и 900 - 50000000Гц)
;=======================================================================================
freq_special__
            btfsc      fflags_,2  ; установлен флаг спец. частотомера?
            goto       fs_0

            call       freq_standart__   ; станд. ч-мер

            movf       fflags_,w
            andlw      b'11111000'
            btfss      STATUS,Z  ; выход если счет не окончен
            return            

            movf       out_bcd+3,w
            iorwf      out_bcd+2,w
            btfss      STATUS,Z   ; >9999 ?
            return
            movf       out_bcd+1,w
            sublw      08h
            btfss      STATUS,C   ; >899 ?
            return
            bsf        fflags_,2  ; установить флаг спец. частотомера (показ. <900)

fs_0               ; ............. вычисление  F = 1/T .................................
 
            call      time_meter__ ; (на вых. W=0 - проп. инд. W=1 - индикация)
            andlw     1            ;
            btfsc     STATUS,Z     ;
            return    ; W=0        ; 

            call       T_imp__    ; вычисление периода
            clrf       freq_+3
            btfsc      fflags_,0  ; the "too small" flag  
            goto       fs_1   ; перех. к обыч. частотомеру

            btfss      fflags_,1  ; переполнение?
            goto       fs_2
            clrf       out_bcd
            clrf       out_bcd+1
            clrf       out_bcd+2
            goto       fs_6
fs_2   
            call       DIVIDE_1byX__  ; F=1/T
            andlw      0ffh
            btfsc      STATUS,Z  ; w=0(деление на 0) --> перех. к обыч. частотомеру
            goto       fs_1  

                                               ; Индикация
            call       b2bcd__  ; bin---->bcd
                                    ; F > 999.999 ---> об. ч-мер
            movf       out_bcd+3,f
            btfss      STATUS,Z   ;>999.999 
            goto       fs_1   ; перех. к обыч. частотомеру
fs_6
            movlw      3    ; запятая в поз. 3 (начиная с 0) справа
            call       outBCD__
            movlw      _F
            movwf      LED_OUT+7  ; "F"
            movlw      _UP
            movwf      LED_OUT+6  ; "ЧЕРТА СВЕРХУ"
            return
fs_1
            bcf        fflags_,2  ; установить флаг обычного частотомера
            return


;-----------------------------------------------------------------------------



;=======================================================================================
; ПОДПРОГРАММА  ИНДИКАЦИИ ПЕРИОДА
; 1. До 1000 Гц - вычисление периода напрямую
; 2. ОТ 1000 Гц - обычный подсчет имп. за 1 сек. потом вычмсл. T=1/F, где F - частота
;    Гистерезис - 100 гц (т.е. интервалы 0 - 1100 Гц и 1000 - 50000000Гц)
;=======================================================================================
period__
            btfss      fflags_,2  ; установлен флаг прямого вычисления Т (=0)?
            goto       pe_20

            call       freq__   ; базовый ч-мер

            movf       fflags_,w
            andlw      b'11111000'
            btfss      STATUS,Z  
            return            

            clrf       var_temp;... преобраз. freq_ в 3-разр. в var_temp - коэфициент...
pe_12                          ; т.к. делитель - 3-разр. слово
            movf       freq_+3,f 
            btfsc      STATUS,Z  ; вых. из цикла - сам. старш. разр.=0
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
            btfsc      STATUS,Z  ; w=0 --> перех. к прямому измерению Т
            goto       pe_10  
            
                    ;...... обратное преобраз. freq_ в соотв. с var_temp ...........
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
                ;далее: если freq_ >= 1000000 (000F4240h) --> прямое выч. Т

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

                                              ; Индикация .............................
            call       b2bcd__  ; bin---->bcd

            movlw      3    ; запятая в поз. 3 (начиная с 0) справа
            call       outBCD__

            movlw      _P
            movwf      LED_OUT+7  ; "P"
            movlw      _UP
            movwf      LED_OUT+6  ; "ЧЕРТА СВЕРХУ"
            return     
pe_10       bcf        fflags_,2  ; установить флаг прямого вычисления Т
            return     ;.......................конец зоны P=1/F.......................


pe_20                 ; ............. прямое вычисление T ............................


            call      time_meter__ ; (на вых. W=0 - проп. инд. W=1 - индикация)
            andlw     1
            btfsc     STATUS,Z
            return    ; W=0

            call       T_imp__    
            clrf       freq_+3
            btfsc      fflags_,0  ; the "too small" flag  
            goto       pe_21       ; перех. к вычислению T=1/F

            movf       temp,f  ; сохраненное знач. TMR0 =0? 
            btfsc      STATUS,Z
            goto       pe_18         ; переход ---> " NO_SIG."............    

            btfsc      fflags_,1  ; переполнение?
            goto       pe_22      ; cлишком длинный период  ---------------

                                               ; Индикация
            call       b2bcd__  ; bin---->bcd
                                    ; F > 999.999 ---> об. ч-мер
            movf       out_bcd+3,w
            iorwf      out_bcd+2,w
            btfss      STATUS,Z   ;>9999? 
            goto       pe_17     ; 
            movlw      09h
            subwf      out_bcd+1,w 
            btfss      STATUS,C   ; <900?
            goto       pe_21
pe_17            
            clrw      ; без запятой
            call       outBCD__
            goto       pe_19
pe_18
            movlw      7
            call       out_word__ 
            bsf        LED_OUT,3
pe_19
            movlw      _P
            iorlw      b'00001000' ; запятая
            movwf      LED_OUT+7  ; "P."
            return

pe_22               ; cлишком длинный период  -----------------------------------------------
            movlw      .9
			call       out_word__ 
            movlw      _P
            movwf      LED_OUT+7  ; замена первой буквы F на P
            return

pe_21
            bsf        fflags_,2  ; установить флаг вычисления T=1/F
            return


;-----------------------------------------------------------------------------




;====================================================================================
; ПОДПРОГРАММА ВЫДАЧИ ИЗМЕРИТЕЛЬНЫХ ИНТЕРВАЛОВ (IND_INTERVAL =6->0.25s, =7->0.5s)
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
            btfss      pause_H,1  ; измерение 1 раз в 0.25/0.5/1/2 с.........
            goto       tm_111     ;
tm_116  
            btfsc      flags_,7
            retlw      0        ; пропустить если 6 бит pause_ =1 и флаг=1
            goto       tm_112
tm_111            
            bcf        flags_,7 ; сбросить флаг инд.
            retlw      0         ; пропустить если 6 бит pause_ =0
tm_112  
            bsf        flags_,7 ; уст. флаг инд.
            retlw      1        ; индикация.....................................

;------------------------------------------------------------------------------------




;===================================================================================
; ПОДПРОГРАММА СТАНДАРТНОГО ЧАСТОТОМЕРА
;===================================================================================
freq_standart__
            call       freq__
            movf       fflags_,w
            andlw      b'11111000'
            btfss      STATUS,Z  ; выход если счет не окончен
            return            

			call       b2bcd__      ; преобр. в двоично-десят. формат
			clrw                 ; W=0 --> нет запятой 
         	call       outBCD__     ; вывод на индикатор с гашением незнач. нулей

            movf       LED_OUT+7,f
            btfss      STATUS,Z
            return               ; выход при ненулевом старшем разряде

            movlw      _F
            iorlw      b'00001000' ; запятая
            movwf      LED_OUT+7  ; "F."

            return
;-----------------------------------------------------------------------------------







;===================================================================================
;    БАЗОВАЯ ПОДПРОГРАММА  ЧАСТОТОМЕРА
;  Вход: fflags_, выход (частота) - freq_ (4-разр.)
;===================================================================================
freq__
			btfsc      fflags_,3
			goto       fr_1      ; измерение 

			clrf       freq_+2   ;.........Подготовка запуска и запуск....................
			clrf       freq_+3
            bcf        PORTB,3
			bsf        STATUS,RP0 ;bank1 
			clrwdt
          	movlw      b'11100111'
            movwf      OPTION_REG  ; TMR0 от RA4, передний фронт, преддел.TMR0- 256, рез.-откл.
			bcf        TRISB,3   
			bcf        STATUS,RP0 ;bank0 
            bcf        INTCON,T0IF   ; сброс флага TMR0 
			bsf        fflags_,3    ;.............................................
			return
fr_1
			btfss      INTCON,T0IF ;
			goto       fr_3        ;
			bcf        INTCON,T0IF ;
			incf       freq_+2,f   ;
			btfsc      STATUS,Z    ; при переполнении TMR0, увеличение след. разрядов
			incf       freq_+3,f   ; 	
fr_3
			btfss      fflags_,4
			return                 
			
			movf       TMR0,w ; TMR0 в W --> freq_+1
			movwf      freq_+1
    		
                        ; далее - досчет .......................
			clrf       count_
			btfss      TMR0,0
			goto       fr_4  ; если 0 бит =0
fr_2
			bsf        PORTB,3     ;импульс на сч. вход
			incf       count_,f
			bcf        PORTB,3
			btfsc      TMR0,0 
			goto       fr_2
			goto       fr_5
fr_4
			bsf        PORTB,3     ;импульс на сч. вход
			incf       count_,f
			bcf        PORTB,3
			btfss      TMR0,0 
			goto       fr_4
fr_5              ; ....время досчета - <=1540.....................

			comf       count_,f  ;
			incf       count_,w ; дополнение к count_ -->W: в W - число с прескалера
 			movwf      freq_

			movlw      b'00000111'
			andwf      fflags_,f    
            
			return

;------------------------------------------------------------------------------------------






;=======================================================================================
; ПОДПРОГРАММА ИЗМЕРЕНИЯ ДЛИТЕЛЬНОСТИ ИМПУЛЬСОВ (ПОЛОЖ. И ОТР.)
;
;=======================================================================================

t_meter__
            call      time_meter__ ; 
            andlw     1
            btfsc     STATUS,Z
            return    ; W=0

                     ; Измерение длительности------------------------------------------
            movlw     8
            movwf     temp+1
            movf      pause_,w    ; фикс. времени
            movwf     temp+2      ;
            incf      pause_H,w   ;
            movwf     temp+3      ; сохран. pause_H+1 для посл. отсечки 0.5 сек

tm_2   ;.............................................................
            call      t_imp__             

            btfsc     INTCON,T0IF   
            goto      tm_0         

            movf       temp,f  ; сохраненное знач. TMR0 =0? 
            btfsc      STATUS,Z
            goto       tm_9             

            btfsc     fflags_,1  ; переполнение?
            goto      tm_10            

            movf      temp,w  ; сохраненное знач. TMR0  
            sublw     .15   
            btfss     STATUS,C ; >15?
            goto      tm_0         

            btfss     fflags_,0    ; the "too small" flag cброшен  
            goto      tm_1         
   
            movf      pause_,w  ; прошло 0.5 сек ?
            subwf     temp+2,w  ;
            movf      pause_H,w ;
            btfss     STATUS,C  ;
            incfsz    pause_H,w ; 
            subwf     temp+3,w  ; (pause_(1)+0.5c)-pause_(2)<0 ?           
            btfss     STATUS,C  ; 0.5 s прошли ?
            goto      tm_3    ;да - exit

            decfsz    temp+1,f   
            goto      tm_2  ;...............................................................


tm_3               ;--------------------------------------------------
            movf      freq_,w   ;
            movwf     out_bcd   ;
            movf      freq_+1,w ;
            movwf     out_bcd+1 ;
            movf      freq_+2,w ;
            movwf     out_bcd+2 ;  сохранение freq_ в out_bcd

            call      T_imp__      

            btfss     fflags_,0    ; сброшен the "too small" flag 
            goto      tm_4

            call      t_256__   ; выч. длит. <256

            btfsc      fflags_,1   ; переполнение? (ошибка)
            return                ;выход 
            btfsc     CCPR1H,0    ; t>=128 uS (общ. время изм. >=256 uS)(ошибка)
            return               ;выход
   
            btfss     fflags_,0    ; the "too small" flag =0
            goto      tm_1         ; перех. к обычной индикации значения....


            movf      freq_,w   ;
            movwf     out_bcd   ; сохр. в out_bcd
            clrf      out_bcd+1
            clrf      out_bcd+2

            call      T_256__      

            btfsc     CCPR1H,0    ; t>=128 uS (общ. время изм. >=256 uS)(ошибка)
            return               ;выход 

            btfsc     fflags_,0    ; the "too small" flag 
            goto      tm_0         ; перех. "слишком высокая частота".....

tm_4
            btfsc      fflags_,1   ; переполнение?
            goto       tm_10           


        ; -------------------------------------------------------------------------

               ; (t_imp_1/0 -> рез.) minus период
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

            btfsc     STATUS,C       ; период не больше чем (t_imp_1/0 -> рез.) ?
            goto      tm_12          ; x>=0

            movf      out_bcd+1,w ;....оба старших разр. равны ffh?..............
            andwf     out_bcd+2,w ;
            xorlw     0ffh ; comf ;
            btfss     STATUS,Z    ; 
            return                ; ........ .............
            
            movlw     1h        ;
            addwf     out_bcd,w ;
            btfss     STATUS,C  ;
            goto      tm_6      ;если разница <= 1мкс 
            goto      tm_5             

tm_12
            movf      out_bcd+1,w ;....оба старших разр. равны 0?..............
            iorwf     out_bcd+2,w ;
            btfss     STATUS,Z    ; 
            return                ; ........нет --> oшибка - выход ...........

            movf      out_bcd,w    ;
            sublw     1h           ; если разница <= 1мкс 
            btfsc     STATUS,C     ; 
            goto      tm_6         ;...........................................
    

                    ; (t_imp_1/0 -> рез.) - длит.+период

            movf      out_bcd,w
            movwf     freq_
            clrf      freq_+1
            clrf      freq_+2
            goto      tm_14         ; перех. к обычной индикации значения...............            

tm_5              
                 ; ниже t = (t-T)+T
            movf      out_bcd,w
            addwf     freq_,f
            movf      out_bcd+1,w
            btfsc     STATUS,C
            incfsz    out_bcd+1,w
            addwf     freq_+1,f
            movf      out_bcd+2,w
            btfsc     STATUS,C
            incfsz    out_bcd+2,w
            addwf     freq_+2,f    ; в freq_ восстановленное значение
            goto      tm_14         ; перех. к обычной индикации значения...            

tm_6 
            call      t_1_or_0__   ; проверка сигнала
            movwf     temp         ; сохр. W
            btfsc     temp,1    ; =2
            return              ;неопределенно (ошибка) - выход
            
            btfsc     regime_,4
            goto      tm_7
                    ; реж. полож. импульса
            btfsc     temp,0    ; полож. сигнал (t=T)   
            goto      tm_14         ; перех. к обычной индикации значения...            
            goto      tm_8    ; =0

tm_7                ; реж. отр. импульса
            btfss     temp,0    ; отр. сигнал (t=T)   
            goto      tm_14         ; перех. к обычной индикации значения...            
                        
tm_8              ;t=0 (короткий импульс)
            clrf      freq_
            incf      freq_,f  ; =1us
            clrf      freq_+1
            clrf      freq_+2
            clrf      freq_+3
                     ; перех. к обычной индикации значения...
  
              ;------------------------- индикация---------------------------------
          
tm_14
            bsf        flash_flags,7  
            goto       tm_13
tm_1
            clrf       flash_flags  ;откл. моргания
tm_13

    IF   X_16
            call       t_imp_out__ ;на инд. с обработкой 1/4 мкс
        ELSE
			call       b2bcd__      ; преобр. в двоично-десят. формат
			clrw                 ; W=0 --> нет запятой 
         	call       outBCD__     ; вывод на индикатор с гашением незнач. нулей
    ENDIF         

            movlw      _t
            movwf      LED_OUT+7  ; "t"

            movlw      _UP
            btfsc      regime_,4
            movlw      _BOTTOM      ; "черт. сверху" - реж.3, "_" - реж.4

            movf       LED_OUT+6,f
            btfsc      STATUS,Z
            movwf      LED_OUT+6    ; 2-й разряд при нулевом старшем разряде
            btfss      STATUS,Z
            movwf      LED_OUT+7    ; 1-й разряд при ненулевом старшем разряде
  
            return

tm_0               ; cлишком высокая частота-------------------------------
            movlw      .9
			call       out_word__ 
            clrf       flash_flags  ;откл. моргания
            return

tm_9               ; переполнение .........................
            movlw      .7
			call       out_word__ 
            bsf        LED_OUT,3  ; зап. мл. раз.
            clrf       flash_flags  ;откл. моргания
            return

tm_10               ; cлишком длинный период  -----------------------------------------------
            movlw      .9
			call       out_word__ 
            movlw      _P
            movwf      LED_OUT+7  ; замена первой буквы F на P
            clrf       flash_flags  ;откл. моргания
            return

            
            
;------------------------------------------------------------------------------------------


;=========================================================================
; ВЫВОД НА ИНДИКАТОР ДЛИТ. ИМПУЛЬСА 
; 
;=========================================================================

    IF   X_16
t_imp_out__
            movf       freq_+1,w  ;
            andlw      b'10000000';
            iorwf      freq_+2,w  ; x < 32768 ? (да - Z=1)
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

			call       b2bcd__      ; преобр. в двоично-десят. формат
			clrw                 ; W=0 --> нет запятой 
         	call       outBCD__     ; вывод на индикатор с гашением незнач. нулей
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

			call       b2bcd__      ; преобр. в двоично-десят. формат
			movlw      2             
         	call       outBCD__     ; вывод на индикатор с гашением незнач. нулей
            return
    ENDIF

;-------------------------------------------------------------------------








;=======================================================================================
;  ПОДПРОГРАММА ВЫЯВЛЕНИЯ СРЕДНЕГО ЗНАЧЕНИЯ ВХОДНОГО СИГНАЛА (LEVEL_CONT*3 выборок)
;=======================================================================================

t_1_or_0__
            movlw      .3*LEVEL_CONT     
            movwf      temp+1
            clrf       temp
tor_1
            btfsc      PORTB,3
            incf       temp,f    ; +1 при выс. уровне
            decfsz     temp+1,f
            goto       tor_1   ; цикл 30 раз

            movf       temp,w
            sublw      LEVEL_CONT
            btfsc      STATUS,C
            retlw      0         ; преимущественно 0

            movf       temp,w
            sublw      .2*LEVEL_CONT
            btfss      STATUS,C
            retlw      1         ; преимущественно 1

            retlw      2         ; неопределенно

;-----------------------------------------------------------------------------------

            
                       





;000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000



;=========================================================================================
;   ПОДПРОГРАММА ИЗМЕРЕНИЯ ПЕРИОДА ИМПУЛЬСА 
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
			movf       tmr1_count,w; сохр. 
			movwf      freq_+2     ;
            bcf        tmr1_count,7 ; 			
			bcf        PIR1,CCP1IF  ;
T_3
			btfss      PIR1,CCP1IF ; ........................
			goto       T_3 
			movf       TMR0,w   
			clrf       CCP1CON    ;откл.  

			call       t_imp_end__
			return


;---------------------------------------------------------------------------------------





;=========================================================================================
;   ПОДПРОГРАММА ИЗМЕРЕНИЯ ДЛИТЕЛЬНОСТИ ПОЛОЖИТЕЛЬНОГО ИЛИ ОТРИЦАТЕЛЬНОГО ИМПУЛЬСА
;   (freq_ - выходное значение в мкс) 
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
			bcf        PIR1,CCP1IF ;сброс флага 
ti_6
			btfss      PIR1,CCP1IF ; ........................
			goto       ti_6 
			incf       TMR0,w   
			clrf       CCP1CON     

			call       t_imp_end__
			return


ti_5  ; отр. имп. ......................................................
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
			bcf        PIR1,CCP1IF  ;сброс флага 
ti_3
			btfss      PIR1,CCP1IF ; ........................
			goto       ti_3 
			incf       TMR0,w   
			clrf       CCP1CON     

			call       t_imp_end__   
			return


;---------------------------------------------------------------------------------------









;=======================================================================================
; ПОДПРОГРАММА - НАЧАЛО ПОДПРОГРАММ T_imp__ и t_imp__
;========================================================================================
            
t_imp_begin__
            movlw      b'00000100'
            andwf      fflags_,f    
			clrf       T1CON ; останов TMR1
			clrf       TMR1L
			clrf       TMR1H
            bcf        PIR1,TMR1IF
			clrf       tmr1_count
			clrwdt
          	movlw      b'11111000' ; TMR0 от RA4, задн. фронт, рез.-откл.  преддел.off	
     ;отр. имп.
            btfsc      regime_,3
            movlw      b'11101000'  ; TMR0 от RA4, пер. фронт, рез.-откл.  преддел. off	

			bsf        STATUS,RP0 ;bank1 
            movwf      OPTION_REG  		
			bsf        TRISB,3     ; RB3 - вход
			bsf        PIE1,TMR1IE  ;разреш. прерыв. от TMR1
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
			movlw      b'00000001'; предд.-1/1, такт.-osc/4, включить TMR1
            btfss      STATUS,Z ; спец.частотомер и период?  
            movlw      b'00100001'; предд.-1/4, такт.-osc/4, включить TMR1
        ELSE
			movlw      b'00000001'; предд.-1/1, такт.-osc/4, включить TMR1
    ENDIF            
			movwf      T1CON   
            return


;--------------------------------------------------------------------------------------------







;=========================================================================================
; ПОДПРОГРАММА - КОНЕЦ ПОДПРОГРАММ  T_imp__, t_imp1__ и t_imp0__
;=========================================================================================

t_imp_end__
            movwf      temp  

            btfsc      INTCON,T0IF  
            bsf        fflags_,0 ; флаг "слишком короткий"
            
            sublw      2h      ; (слишком короткий импульс)
            btfss      STATUS,C
            bsf        fflags_,0 ; флаг "слишком короткий"

			clrf       T1CON ; останов TMR1 
			bcf        PIR1,CCP1IF  ;сброс флага 
            btfsc      tmr1_count,7  ;............................................ 
            decf       tmr1_count,f
            btfsc      freq_+2,7
            decf       freq_+2,f
            movlw      b'01111111'
            andwf      tmr1_count,f
            andwf      freq_+2,f ; .....коррекция значений 

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
			decf       freq_+1,f      ;......вычисление разности отсчетов--> freq_.............
t0_4
            clrf       freq_+3   ; самый старший разряд =0
			bsf        STATUS,RP0 ;bank1 
			bcf        PIE1,TMR1IE  ;запрет прерыв. от TMR1
			bcf        STATUS,RP0 ;bank0 
			return
;---------------------------------------------------------------------------------------	





;=========================================================================================
;   ПОДПРОГРАММА ИЗМЕРЕНИЯ ПЕРИОДА ИМПУЛЬСА ( < 256/2 uS)
;  (freq_ - выходное значение в мкс)
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
            bsf        fflags_,0  ; уст. флаг "слишком большая частота" при T<8

			return


;---------------------------------------------------------------------------------------






;=========================================================================================
; ПОДПРОГРАММА ИЗМЕРЕНИЯ ДЛИТЕЛЬНОСТИ ПОЛОЖ. ИЛИ ОТР. ИМПУЛЬСА С ДЛИТЕЛЬНОСТЬЮ <256/2 МКС
; (freq_ - выходное значение в мкс)
;=========================================================================================

t_256__
            call       t_256_begin__ 
            
            btfsc      regime_,4
            goto       ti2_5

                    ; полож. импульс ...........................................
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
			bcf        PIR1,CCP1IF  ;сброс флага 
ti2_6
			btfss      PIR1,CCP1IF ; ........................
			goto       ti2_6 
			incf       TMR0,w   
			clrf       CCP1CON     

			call       t_256_end__
			return


ti2_5  ; отр. имп. ......................................................
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
; ПОДПРОГРАММА - НАЧАЛО ПОДПРОГРАММ _256_
;========================================================================================
            
t_256_begin__
            movlw      b'00000100'
            andwf      fflags_,f    
			clrf       T1CON ; останов TMR1
			clrf       TMR1L
			clrf       TMR1H
            bcf        PIR1,TMR1IF
			clrwdt
          	movlw      b'11111000' ; TMR0 от RA4, задн. фронт, рез.-откл.  преддел.off	
     ;отр. имп.
            btfsc      regime_,3
            movlw      b'11101000'  ; TMR0 от RA4, пер. фронт, рез.-откл.  преддел. off	

			bsf        STATUS,RP0 ;bank1 
            movwf      OPTION_REG  		
			bsf        TRISB,3     ; RB3 - вход
			bcf        STATUS,RP0 ;bank0 

			bcf        INTCON,GIE   ;..................................................
ti2_2
			btfss      PIR1,TMR2IF
			goto       ti2_2
			bsf        INTCON,GIE   

            clrf       TMR0
            bcf        INTCON,T0IF 
			movlw      b'00000001'
			movwf      T1CON   ; предд.-1/1, такт.-osc/4, включить TMR1
            return


;---------------------------------------------------------------------------------------




;=======================================================================================
; ПОДПРОГРАММА - КОНЕЦ ПОДПРОГРАММ _256_
;========================================================================================
            
t_256_end__
            movwf      var_temp  ;    

            btfsc      INTCON,T0IF  
            bsf        fflags_,0 ; флаг "слишком короткий"
            
            sublw      2h      ; (слишком короткий импульс)
            btfss      STATUS,C
            bsf        fflags_,0 ; 

			clrf       T1CON ; останов TMR1 
			bcf        PIR1,CCP1IF  
 
			movf       freq_,w
			subwf      CCPR1L,w
			movwf      freq_   ;......вычисление разности отсчетов--> freq_.............
            clrf       freq_+1
            clrf       freq_+2
            clrf       freq_+3 
  
			bsf        STATUS,RP0 ;bank1 
			bcf        PIE1,TMR1IE  ;запрет прерыв. от TMR1
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
;  Подпрограмма регистрации нажатия кнопок
;  Параметр: butt_flags - 7 бит -было наж. кн., 1 -кнопка 1, 0 -кнопка 2 
;  Прерывания запрещаются на 16 тактов
;==============================================================================
button__
			clrf      butt_flags 
			btfsc     fflags_,5 
			return                

			bcf       INTCON,GIE  ; запрет прерывания
        movf      PORTB,w  
        clrf      PORTB  ; откл. сегменты
        movwf     portb_temp  ;сохр. сост. порта В
   			bsf       STATUS,RP0  ; bank 1
   			movlw     0ffh
			movwf     TRISA
 			bcf       STATUS,RP0  ; bank 0
            comf      PORTA,w       ;
            andlw     b'00000011'   ; считывание состояния кнопок (1-нажата)
			movwf     butt_flags    ;

			bsf       STATUS,RP0  ; bank 1
			movlw     b'11110000' 
			movwf     TRISA    ;восстановление А
			bcf       STATUS,RP0  ; bank 0

        movf      portb_temp,w
        movwf     PORTB       ;восстановление B          
			bsf       INTCON,GIE  ; разр. прерывания

			movf      butt_flags,f
			btfss     STATUS,Z    ; было нажатие клавиши?(<>0)
			bsf       butt_flags,7 ; уст. 7-й бит - признак нажатия кнопки
			return                
;------------------------------------------------------------------------------------




;==============================================================================
;  Подпрограмма задержки 0.02 - 0.5 сек
;  Параметр pause_, аргумент - в "W"   (P = w*2 mc)
;==============================================================================

pause__                ; при w от 10 до 256, пауза 0.02 - 0.5 сек. 
			addwf        pause_,w
			movwf        var_pause ;var_pause=pause+w
			  
p_1			movf         pause_,w
			xorwf        var_pause,w ; контроль pause_ (декрементируется в преривании TMR0)
			btfss        STATUS,Z ; выход при pause_= var_pause
			goto         p_1
			return                 

;------------------------------------------------------------------------------			         






      
;====================================================================================
; Подпрограмма таблицы чисел для вывода на 7-сегм. индикатор  w = .9 max
; ===================================================================================

Table_s__ 
			movwf       PC_temp
            sublw       .9          ;
            btfss       STATUS,C     ;
            retlw       0  ;  проверка w>max.? если да --->"гашение знака"
            movf        PC_temp,w

			movlw       HIGH table_
			movwf       PCLATH
			movf        PC_temp,0
			addlw       LOW table_ 
			btfsc       STATUS,C
			incf        PCLATH,1
			movwf       PCL        ; Содержимое счетчика команд PC увеличивается
table_                                    ; на величину содержимого аккумулятора W.
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
; Подпрограмма паузы W*4 мкс  
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
;           Подпрограмма ожидания ненажатых в течении >0.2 сек. кнопок  
;==============================================================================

wait_nobutt__   
				call      button__
				movlw     .50
				call      pause__  ; =100ms
				btfsc     butt_flags,7
				goto      wait_nobutt__ ; ожидание ненажатой кнопки 

				movlw     .50
				call      pause__  ; =100ms
				call      button__
				btfsc     butt_flags,7  ; ожидание ненажатой в течении >0.2 сек. кнопки 
				goto      wait_nobutt__
				return

;-------------------------------------------------------------------------------



;===================================================================================
;           ПОДПРОГРАММА ОЖИДАНИЯ НАЖАТИЯ КНОПКИ
;     Параметр - butt_time
;     Выход: в W -1 -есть нажатие , 0 - нет нажатия в течении (3,4,6,10) сек.
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
			retlw     1h       ; выход w=1, если кнопка нажата
			decfsz    count_,1 
			goto      wai_b   	  
			retlw     0h 	  
;-----------------------------------------------------------------------------------
 



;===================================================================================
;           ПОДПРОГРАММА РЕГИСТРАЦИИ НАЖАТОЙ КНОПКИ
;     Выход: в W - 0 - нажатие 1-й кн., 1 - нажатие 2-й кн. 2-нажатие обеих кнопок
;            W>2 - кнопки не нажаты 
;===================================================================================

push_butt__	  ; предварительно требуется вызов подпр. button__
			movf       butt_flags,w
			andlw      b'00000011'
			addlw      -1         ; в W - значение согласно заголовку
            clrf       pause_Hst ;сброс минутного счетчика по наж. кнопки
			return     

;----------------------------------------------------------------------------------









;=====================================================================================
;       ПОДПРОГРАММА ПЕРЕКЛЮЧЕНИЯ РЕЖИМА
;  Параметр regime_. биты: 0-частотомер обычный, 1-частотомер спец., 2-период,
;                          3-длит. полож. имп., 4-длит. отриц. имп., 5-авто-FTt1t0
;=====================================================================================



regime__    
            clrf      fflags_    ; сброс флагов измерений

         	movf      regime_,w
			movwf     reg_temp   ; сохранить regime_ 

r_			call      ind_re__

			call      wait_nobutt__

			call      wait_butt__
			xorlw     0h
			btfsc     STATUS,Z
			goto      end_re  ; без нажатия  3/6/8/10 с - выход из ПП

			call      push_butt__ ;если кнопка нажата, проверить какая
			xorlw     0h
			btfsc     STATUS,Z
			goto      r_3      ; 1-я - изменение индицируемого режима
			xorlw     1h
			btfss     STATUS,Z
			goto      r_      ; оба или ни одна - на начало
                              ; ниже - если 2-я кнопка нажата

            bsf       STATUS,RP0 ;bank1 ......................
            movlw     30h
            movwf     EEADR  ;adr = 30h (regime_)
            bcf       STATUS,RP0 ;bank0
			movf      regime_,w  
			movwf     reg_temp   ; перезапись reg_temp
            call      EE_write__ ; сохр. режим

r_2		
			clrw
			call      out_word__   ;W=0    Индикация изменения словом "--YES-- "
			call      wait_nobutt__ ;ожидание отжатия
            goto      end_re
r_3		
			movlw     .1
			bcf       STATUS,C
			rlf       regime_,1   ;сдвиг regime_
			btfsc     regime_,5   ;по кругу
			movwf     regime_     ;-->0..4,0.. 

			goto      r_

end_re
    		movf      reg_temp,w
			movwf     regime_    ; восстановление режима

            movlw     8h
            call      out_word__ ; вывод на инд. слова "-COUNt--"

			return



;--------------------------------------------------------------------------------------





;======================================================================================
;    ПОДПРОГРАММА ИНДИКАЦИИ РЕЖИМОВ
;    Параметр - regime_
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
			movlw   5h        ; Начальная позиция названия режима .....................

			call    out_word__ ; вывод на инд. обозн. режима
			return

;--------------------------------------------------------------------------------------





      
;====================================================================================
; Подпрограмма таблицы выводимых на индикатор слов. w = .208 max
; ===================================================================================

tab_word__ 
			movwf       PC_temp
			movlw       HIGH t_word
			movwf       PCLATH
			movf        PC_temp,w
			addlw       LOW t_word 
			btfsc       STATUS,C
			incf        PCLATH,f
			movwf       PCL        ; Содержимое счетчика команд PC увеличивается
t_word                             ; на величину содержимого аккумулятора W.

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
; ПОДПРОГРАММА ПЕЧАТИ ТЕКСТА В ВИДЕ БЕГУЩЕЙ СТРОКИ
;freq_  - номер начальной буквы, freq_+1  - конечной
;=================================================================================
write__		movf        freq_,w  
			call        out_8__
			movf        freq_+1,w  
			subwf       freq_,w
			btfsc       STATUS,C  ;проверка окончания текста
			return	 
			incf        freq_,1  ;сдвиг букв на один влево
			movlw       .160
			call        pause__
 			goto        write__

;------------------------------------------------------------------------------------











;======================================================================================
;  ПОДПРОГРАММА ВЫВОДА СЛОВА(8 ЗНАКОВ) ИЗ ТАБЛИЦЫ НА ИНДИКАТОР
;  в W - порядковый номер слова в таблице
;  out_word__ - вход (w)- номер слова
;  out_8__ - вход (w) - номер первой буквы
;======================================================================================
out_word__
			movwf       var_temp
			bcf         STATUS,C
			rlf         var_temp,f
			rlf         var_temp,f
			rlf         var_temp,w ; *8 = порядк. номер 1-го знака
out_8__            
            movwf       var_temp
			movlw       8h
			movwf       count_  ; вывод 8-ми знаков
			addwf       var_temp,f ; 1-й знак + 8
			movlw       LED_OUT+7
			movwf       FSR     ; адрес первого знака
ow_1
			movf        count_,w
			subwf       var_temp,w ;  порядк. номер очередного знака
			call        tab_word__ ;  загрузить знак
			movwf       INDF       ;  знак на индикатор
			decf        FSR,f
			decfsz      count_,f   ;  все 8 знаков?
			goto        ow_1       

			return


;-----------------------------------------------------------------------------------



;===================================================================================
; ПОДПРОГРАММА ПЕРЕВОДА ДВОИЧНОГО 4-РАЗРЯДНОГО ЧИСЛА В ВОСЬМИРАЗРЯДНОЕ BCD
; Параметры: 4-разр. слова freq_, out_bcd  - старший разр. - старш. полубайт 
; 1871 циклов
;===================================================================================
b2bcd__
			movlw	.32		; 4 байта - 32-бита
			movwf	count_		 
			clrf	out_bcd		
			clrf	out_bcd+1
			clrf	out_bcd+2
			clrf	out_bcd+3   ; очистка слова BCD
	
b2bcd2
			movlw	out_bcd		
			movwf	FSR
			movlw	4h
			movwf	temp ; создается нач. точка

b2bcd3  		        ; цикл 
			movlw	33h		
			addwf	INDF,f		; сразу оба полубайта
			btfsc	INDF,3		;  ›7 ?
			andlw	0f0h		; подготовить сохр. мл. полубайта
			btfsc	INDF,7		; ст. полубайт >7 ?
			andlw	0fh	 	  	; подготовить сохр. ст.полубайта
			subwf	INDF,f		; очистить несохраняемые полубайты
			incf	FSR,f		; следующий байт
			decfsz	temp,f
			goto	b2bcd3
	
			rlf	freq_+0,f 	; след. бит
			rlf freq_+1,f
			rlf freq_+2,f
			rlf	freq_+3,f
			rlf	out_bcd+0,f	; --> BCD
			rlf	out_bcd+1,f
			rlf	out_bcd+2,f
			rlf	out_bcd+3,f

			decfsz	count_,f		; все?
			goto	b2bcd2	
			return			;конец

;----------------------------------------------------------------------------------


;======================================================================================
;  ПОДПРОГРАММА ВЫВОДА НА ИНДИКАТОР bcd-ЧИСЛА С ГАШЕНИЕМ НЕЗНАЧАЩИХ НУЛЕЙ СЛЕВА
;  Параметры: в W -  поз. запятой считая справа (0-7) W=0 or W>7 - зап. нет
;======================================================================================
outBCD__
			bcf        INTCON,GIE   ;..................................................
obcd_0
			btfss      PIR1,TMR2IF
			goto       obcd_0
			bsf        INTCON,GIE   
			movwf     temp  ; сохр вх. параметр
						  
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
			goto      obcd_2     ; на выходе: правее поз. зап. включит. нули, левее -1

			
			movlw	LED_OUT+7
			movwf	freq_+1		; адрес выхода
			movlw	out_bcd+3
			movwf	freq_+2		; входное bcd слово
			movlw	4h		; 4 байта
			movwf	count_
obcd_3
			movf	freq_+2,w	; текущий разряд входа
			movwf	FSR
			decf	freq_+2,f	; подг. след. входного байта 
			movf	INDF,w		; считывание 2 bcd
			movwf	freq_		; сохранение
			movf	freq_+1,w	; текущий разряд выхода 
			movwf	FSR
			decf	freq_+1,f	; 
			decf	freq_+1,f   ; вых. --> -2 разряд
			swapf	freq_,w		; 
			andlw	0fh         ; извл. старшего разр. из сохраненного входного байта
			btfss   STATUS,Z    ;=0?
			clrf    temp+1      ; обнаружен <>0 --> дальше все нули значащие
			call    Table_s__   ; преобразование
			btfsc   temp+1,7
			movlw   _SPACE      ; гашение незначащего нуля
			movwf	INDF		; на выход
			bcf     STATUS,C
			rlf     temp+1,f    ; для проверки след. разр.

			decf	FSR,f
			movf	freq_,w		; 
			andlw	0fh	 		; извлечение мл. полубайта
			btfss   STATUS,Z
			clrf    temp+1    ; обнаружен <>0 --> дальше все нули значащие
			call    Table_s__   ; преобразование
			btfsc   temp+1,7    ;...... 7-Й БИТ =1 - НЕЗН. НУЛЬ (ПЕЧАТАЕТСЯ ПРОБЕЛ)......
			movlw   _SPACE      ; гашение незначащего нуля
			movwf	INDF		; на выход
			bcf     STATUS,C
			rlf     temp+1,f    ; для проверки след. разр.

			decfsz	count_,f	; все цифры?
			goto	obcd_3
	
                           ;.................вывод запятой....................... 
			movf      temp,f 
			btfsc     STATUS,Z   ; нет запятой
			return
			movlw     LED_OUT
			addwf     temp,w
			movwf     FSR
			bsf       INDF,3     ; в разряде, где запятая - уст. бит 3
			return
			
;---------------------------------------------------------------------------------------


;=======================================================================================
; ПОДПРОГРАММА ВЫЧИСЛЕНИЯ ВЫРАЖЕНИЯ ТИПА 1/Х, КОТОРАЯ ЗАМЕНЯЕТСЯ ВЫР. 1000000000/Х
; Запятая ставится так, чтобы результат получился в микросекундах или в герцах.
; Параметры: out_bcd - делимое (1000000000), freq_ -делитель, temp - вспомогательное слово
;            (все слова четырехбайтные, 1-я ячейка - мл. разряд), результат - в freq_
; Возвращает: 0 - делитель равен нулю, 1 - успешно        
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
        clrf    out_bcd     ; Занесение в out_bcd значения 1000.000.000 (0x3B9ACA00)

                   ;Для округления результата, вместо x/y вычисляем (x+y/2)/y       
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
;  ПОДПРОГРАММА ДЕЛЕНИЯ 4-РАЗРЯДНОГО СЛОВА (out_bcd) НА 3-Х РАЗРЯДНОЕ (freq_)
;  temp - 4-х разрядное слово
;  Результат - out_bcd, остаток - temp
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
; ПОДПРОГРАММА ПЕРЕХОДА В СПЯЩИЙ РЕЖИМ
;=================================================================
to_Sleep__
            movlw   .22
            call    out_word__ ;погасить инд.

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
            movf    PORTB,w    ;   исключить несоотв.
            bsf     STATUS,RP0 ;bank 1

            bsf     INTCON,RBIE
            bcf     INTCON,RBIF
            sleep           
            bcf     INTCON,RBIE

			movlw     .124   ;-- ВОССТАНОВЛЕНИЕ--
            movwf     PR2   ; Инервал прерывания от TMR2 - 125*16 = 2 мсек

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
;        ПОДПРОГРАММА СЧИТЫВАНИЯ ИЗ EEPROM
; Считанный байт передается через акк., адрес уст. автом. (+1)
;=============================================================================

EE_read__	bsf        STATUS,RP0  ; BANK 1
			bsf        EECON1,RD
			movf       EEDATA,w
			incf       EEADR,1
			bcf        STATUS,RP0  ; BANK 0
			return
;-----------------------------------------------------------------------------


;=============================================================================
;        ПОДПРОГРАММА ЗАПИСИ В EEPROM
; Сохраняемый байт передается через акк., адрес уст. автом. (+1)
;=============================================================================
EE_write__ 
            bsf        STATUS,RP0  ;  банк1. 
            movwf      EEDATA     ; загрузка данных

			bcf        INTCON,GIE   ; запретить прерывания
			bcf        STATUS,RP0  ;  банк0.

			clrf       PORTB      ; погасить индикатор устранения
			bcf        PORTA,3    ; просадки напряжения во время записи

			movlw      .250         ;
			call       delay_Wx4__  ;   
			movlw      .250         ;
			call       delay_Wx4__  ;   
			movlw      .250         ;
			call       delay_Wx4__  ; Пауза 3 мсек 
			
			bsf        STATUS,RP0  ;  банк1. 	
            bsf        EECON1,WREN    ; Разрешить запись.                                   
            movlw      55h        ; Обязательная
            movwf      EECON2      ; процедура
            movlw      0AAh        ; при записи.
            movwf      EECON2      ; ----"----
            bsf        EECON1,WR    ; ----"----

			bsf        INTCON,GIE  ;разрешить прерывания

            bcf        STATUS,RP0  ; банк0			
eepr_1		btfss      PIR1,EEIF
			goto       eepr_1    ;ожидание конца записи 
			bcf        PIR1,EEIF  ;сброс флага прер.

			bsf        STATUS,RP0  ;  банк1. 
			bcf        EECON1,WREN ;запрет записи
			incf       EEADR,1     ; подготовка адресa для очередной записи
            bcf        STATUS,RP0  ; банк0
			return


;-----------------------------------------------------------------------------



;============================================================================
; ПОДПРОГРАММА УСТАНОВОК
; Переменные: ind_per, off_time, butt_time.  temp - временная 
;             temp+1 - в качестве пер-ной меню
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
            movwf     flash_flags ; моргание 3-х мл. разр.(цифр) 

			call      wait_butt__
			xorlw     0h
			btfsc     STATUS,Z
			goto      ts_2  ; без нажатия 8 с - выход из ПП

			call      push_butt__ ;если кнопка нажата, проверить какая
			xorlw     0h
			btfsc     STATUS,Z
			goto      ts_3      ; 1-я - изменение индицируемого режима
			xorlw     1h
			btfss     STATUS,Z
			goto      ts_1     ; оба или ни одна - на начало
                              ; ниже - если 2-я кнопка нажата

            btfss     temp,3
            goto      ts_4
            call      auth__
            call      wait_nobutt__
            return
ts_4
			movlw     .1
			bcf       STATUS,C
			rlf       temp+1,f   ;сдвиг
			btfsc     temp+1,4   ;по кругу
			movwf     temp+1     ;-->0..3,0.. 

			goto      ts_1

			     
ts_3		
            movf      temp+1,w  ;
            btfsc     temp,0    ;
            movwf     ind_per   ;
            btfsc     temp,1    ;
            movwf     off_time  ;
            btfsc     temp,2    ;
            movwf     butt_time ; запись нового знач. тек. уст.

			movlw     .1
			bcf       STATUS,C
			rlf       temp,f   ;сдвиг
			btfsc     temp,4   ;по кругу
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
            movwf     butt_time ; запись нового знач. тек. уст.

            bsf       STATUS,RP0 ;bank1 ......................
            movlw     31h
            movwf     EEADR  ;adr = 31h
            bcf       STATUS,RP0 ;bank0
            movf      ind_per,w
            call      EE_write__  
            movf      off_time,w
            call      EE_write__  
            movf      butt_time,w
            call      EE_write__  ;....запись установок в EEprom

            clrf      flash_flags        
			return

;--------------------------------------------------------------------------------


;======================================================================================
;    ПОДПРОГРАММА ИНДИКАЦИИ РЕЖИМОВ SET
;    Параметр - temp
;======================================================================================
ind_set__
			btfsc   temp,0
			movlw   .10    
			btfsc   temp,1
			movlw   .11    
			btfsc   temp,2
			movlw   .12    
			btfsc   temp,3
			movlw   .18     ; Начальная позиция названия режима SET .....................

			call    out_word__ ; вывод на инд. обозн. режима SET
            call    out_set__  ; вывод знач. текущ. кстановки

            btfss   temp,3
            bsf     LED_OUT+7,3 ; запятая в 1-м разр. кроме 'Author'

			return

;--------------------------------------------------------------------------------------



;======================================================================================
;    ПОДПРОГРАММА ИНДИКАЦИИ ЗНАЧЕНИЯ ТЕКУЩЕЙ УСТАНОВКИ
;    Параметр - temp, temp+1
;======================================================================================
out_set__
			btfss   temp,0
            goto    os_1

            movlw   _O; 0  ;----- для уст. 1-го бита---------
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
            bsf     LED_OUT+2,3 ; запятая
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
; ПОДПРОГРАММА ПРОВЕРКИ ИСТЕЧЕНИЯ ВРЕМЕНИ ДО ВЫКЛЮЧЕНИЯ В SLEEP
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
; ПОДПРОГРАММА 
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
; ПОДПРОГРАММА ОБРАБОТКИ НАЖАТИЯ 2-Й КНОПКИ (ЗАПИСИ,ЧТЕНИЯ ЗНАЧЕНИЯ В EEPROM)
;============================================================================
EE_ls__
			movlw      b'00000111'
			andwf      fflags_,f    ; cброс всех флагов обычного част-ра

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
            goto      els_2   ; нажата 1-я (обе) кнопка
			movlw     .5
			call      pause__  ; =10ms
			btfsc     butt_flags,7
			goto      els_1 ; ожидание ненажатой кнопки 
			movlw     .25
			call      pause__  ; =50ms
			call      button__
			btfsc     butt_flags,7  ; ожидание ненажатой в течении >0.1 сек. кнопки 
			goto      els_1

         ;.............. была нажата только 2-я кнопка .................

            movlw      LED_OUT  ;...................................
            movwf      FSR
            movlw      .8
            movwf      count_
els_3
            call       EE_read__
            movwf      INDF
            incf       FSR,f
            decfsz     count_,f
            goto       els_3   ;...... на инд. - сохраненное знач. ....
            
            movlw      0ffh
            movwf      flash_flags ; моргание всех разр.

            clrf       pause_H    ;
els_5                             ;
            btfss      pause_H,4  ;
            goto       els_5      ; пауза 8 сек.

            clrf       flash_flags
            return
            
els_2    ;...............нажаты две кнопки одновременно.................
            movlw      .24
            call       out_word__ ; ' -SAUE- '
            call       wait_nobutt__
            movlw      0ffh
            movwf      flash_flags ; моргание всех разр.

            movlw      L_out  ;...................................
            movwf      FSR
            movlw      .8
            movwf      count_
els_6
            movf       INDF,w
            call       EE_write__
            incf       FSR,f
            decfsz     count_,f
            goto       els_6   ;...... на инд. - сохраненное знач. ....

            clrf       pause_H    ;
els_7                             ;
            btfss      pause_H,3  ;
            goto       els_7      ; пауза 4 сек.

            clrf       flash_flags
            return

;------------------------------------------------------------------------------


;=====================================================================================
;       ПОДПРОГРАММА УСТАНОВОК И ВЫКЛЮЧЕНИЯ
;=====================================================================================

off_set__    
    		clrf      reg_temp

ofs_1		
			movlw     6h
			btfss     reg_temp,0
			movlw     .25        ; Начальная позиция названия режима 

			call      out_word__ ; вывод на инд. обозн. режима

			call      wait_nobutt__

			call      wait_butt__
			xorlw     0h
			btfsc     STATUS,Z
			goto      ofs_5     ; без нажатия  3/6/8/10 с - выход из ПП

			call      push_butt__ ;если кнопка нажата, проверить какая
			xorlw     0h
			btfss     STATUS,Z
			goto      ofs_2 
                         ; 1-я - изменение индицируемого режима
            comf      reg_temp,f
            goto      ofs_1            
ofs_2
			xorlw     1h
			btfss     STATUS,Z
			goto      ofs_1    ; оба или ни одна - на начало
                              ; ниже - если 2-я кнопка нажата

			clrw
			call      out_word__   ;W=0    Индикация изменения словом "--YES-- "
			call      wait_nobutt__ ;ожидание отжатия

            btfsc     reg_temp,0 ; 
            call      to_sets__ ; установки
ofs_5
            btfss     reg_temp,0 ; 
            call      to_Sleep__; Sleep

            movlw     8h
            call      out_word__ ; вывод на инд. слова "-COUNt--"

			return



;--------------------------------------------------------------------------------------



;======================================================================================
; ПОДПРОГРАММА ОБРАБОТКИ НАЖАТИЯ 1-ОЙ КНОПКИ
;======================================================================================
put_butt_1__
			movlw      b'00000111'
			andwf      fflags_,f    ; cброс всех флагов обычного част-ра

            movlw      .100
            call       pause__ ; 0.2 s
            call       ind_re__

            movlw     .30
            movwf     count_
pb_1   
			call      button__
			movlw     .50
			call      pause__  ; =100ms
			btfsc     butt_flags,2  ; 2-я кн.?
			return 
    		btfss     butt_flags,7
			goto      pb_2 ; вых. при ненажатых кнопках 
            decfsz    count_,f
            goto      pb_1

            call      off_set__
            return
pb_2
            call      regime__
            return

;---------------------------------------------------------------------------



;===========================================================================
;  ПОДПРОГРАММА ПРОВЕРКИ КОРРЕКТНОСТИ СЧИТЫВАЕМОЙ ИЗ EEPROM ПЕРЕМЕННОЙ
;  В случае некорректности - замена на стандартное значение (1)
;  вход, выход - W
;===========================================================================
var_test__
            andlw     b'00011111'
            btfss     regime_,7 ; пропустить, если пер. - regime_
            andlw     b'00001111'
            movwf     var_temp   ; сохр. 
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
                    ; при корректном значении  w=1
            xorlw     1h
            btfss     STATUS,Z
            retlw     1h  ;   w<>1 - замена на 1
            movf      var_temp,w ; восстановление
            return

;------------------------------------------------------------------------------






			end



