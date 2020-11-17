@        START
*Label   Op    Operands                Comment                                                     Location Hex          Format

***********************************************************************
*                                                                     *
*                               GETCMD                                *
*                                                                     *
***********************************************************************
         
         ORG   @+X'00000000'

GETCMD   J     begin_program                                                                       00000000 A7F4000E     RIc       
         DC    CL24'GETCMD  2020/10/21 16:17'                                                      00000004 

begin_program equ *
         STM   R14,R12,12(R13)         Store Multiple (32)                                         0000001C 90ECD00C     RSA    60 (,F)
         LR    R12,R15                 Load (32)                                                   00000020 18CF         RR        
         USING GETCMD,R12
*        ----------------
         LR    R4,R1                   Load (32)                                                   00000022 1841         RR        
         USING PLIST,R4
*        --------------
         B     get_work_area                                                                       00000024 47F0C030     RXb       

workarea_size equ *
         DC    F'76'                                                                               00000028 0000004C

storage_flags equ *
         DC    F'18'                                                                               0000002C 00000012

get_work_area equ *
         L     R0,workarea_size        Load (32)                                                   00000030 5800C028     RXa     4 (,F)
         L     R15,storage_flags       Load (32)                                                   00000034 58F0C02C     RXa     4 (,F)
         L     R14,16                  Load (32) -> CVT                                            00000038 58E00010     RXa     4 (,F)
         L     R14,X'304'(R14)         Load (32)                                                   0000003C 58EE0304     RXa     4 (,F)
         L     R14,X'0A0'(R14)         Load (32)                                                   00000040 58EE00A0     RXa     4 (,F)
         PC    0(R14)                  Program Call                                                00000044 B218E000     S         

         LTR   R15,R15                 Load and Test (32)                                          00000048 12FF         RR        
         JNZ   return_to_caller        Branch if Not Zero                                          0000004A A774006C     RIc       
         ST    R13,4(,R1)              Store (32)                                                  0000004E 50D01004     RXa     4 (,F)
         ST    R1,8(,R13)              Store (32)                                                  00000052 5010D008     RXa     4 (,F)
         LR    R13,R1                  Load (32)                                                   00000056 18D1         RR        
         USING WA,R13
*        ------------
         LTR   R4,R4                   Load and Test (32)                                          00000058 1244         RR        
         JZ    set_rc12                Branch if Zero                                              0000005A A784005D     RIc       
         TM    PLIST_8,B'10000000'     Test under Mask (8)                                         0000005E 91804008     SI0       
         JNO   set_rc12                Branch if Not Ones                                          00000062 A7E40059     RIc       
         LA    R8,WA_48                Load Address                                                00000066 4180D048     RXa       
         LA    R1,extract_plist        Load Address                                                0000006A 4110C130     RXa       
         ST    R8,0(R1)                Store (32)                                                  0000006E 50810000     RXa     4 (,F)
         MVI   8(R1),1                 Move Immediate (8)                                          00000072 92011008     SI      1 
         MVI   9(R1),0                 Move Immediate (8)                                          00000076 92001009     SI      1 
         SVC   40                      EXTRACT                                                     0000007A 0A28         I         

         L     R8,WA_48                Load (32)                                                   0000007C 5880D048     RXa     4 (,F)
         USING COM,R8
*        ------------
         L     R7,COM_0                Load (32)                                                   00000080 58708000     RXa     4 (,F)
         L     R1,PLIST_8              Load (32)                                                   00000084 58104008     RXa     4 (,F)
         ST    R7,0(,R1)               Store (32)                                                  00000088 50701000     RXa     4 (,F)
         L     R7,PLIST_0              Load (32)                                                   0000008C 58704000     RXa     4 (,F)
         MVI   0(R7),0                 Move Immediate (8)                                          00000090 92007000     SI      1 
         L     R7,PLIST_4              Load (32)                                                   00000094 58704004     RXa     4 (,F)
         XC    0(256,R7),0(R7)         Exclusive-Or Character                                      00000098 D7FF70007000 SSa   256 (,X)
         L     R7,COM_4                Load (32)                                                   0000009E 58708004     RXa     4 (,F)
         USING CIB,R7
*        ------------
         LTR   R7,R7                   Load and Test (32)                                          000000A2 1277         RR        
         JZ    enable_modify           Branch if Zero                                              000000A4 A784002F     RIc       
         L     R9,PLIST_0              Load (32)                                                   000000A8 58904000     RXa     4 (,F)
         CLI   CIB_4,X'44'             Compare Logical Immediate (8)                               000000AC 95447004     SI      1 
         JNE   is_it_stop              Branch if Not Equal                                         000000B0 A7740006     RIc       
         MVI   0(R9),C'F'              Move Immediate (8)                                          000000B4 92C69000     SI      1 
         J     copy_params                                                                         000000B8 A7F40012     RIc       

is_it_stop equ *
         CLI   CIB_4,C' '              Compare Logical Immediate (8)                               000000BC 95407004     SI      1 
         JNE   is_it_start             Branch if Not Equal                                         000000C0 A7740006     RIc       
         MVI   0(R9),C'P'              Move Immediate (8)                                          000000C4 92D79000     SI      1 
         J     copy_params                                                                         000000C8 A7F4000A     RIc       

is_it_start equ *
         CLI   CIB_4,4                 Compare Logical Immediate (8)                               000000CC 95047004     SI      1 
         JNE   delete_command          Branch if Not Equal                                         000000D0 A7740015     RIc       
         MVI   0(R9),C'S'              Move Immediate (8)                                          000000D4 92E29000     SI      1 
         J     copy_params                                                                         000000D8 A7F40002     RIc       

copy_params equ *
         LH    R5,CIB_E                Load Halfword (32<-16)                                      000000DC 4850700E     RXa     2 (,H)
         BCTR  R5,R0                   Branch on Count                                             000000E0 0650         RR        
         LTR   R5,R5                   Load and Test (32)                                          000000E2 1255         RR        
         JM    delete_command          Branch if Minus                                             000000E4 A744000B     RIc       
         L     R9,PLIST_4              Load (32)                                                   000000E8 58904004     RXa     4 (,F)

move_params equ *
         MVC   0(1,R9),CIB_10          Move Character                                              000000EC D20090007010 SSa     1 
         EX    R5,move_params          Execute                                                     000000F2 4450C0EC     RXa       
         J     delete_command                                                                      000000F6 A7F40002     RIc       

delete_command equ *
         LNR   R1,R7                   Load Negative (32)                                          000000FA 1117         RR        
         LA    R0,COM_4                Load Address                                                000000FC 41008004     RXa       
         SVC   34                      MGCR/MGCRE/QEDIT                                            00000100 0A22         I         

enable_modify equ *
         LA    R1,5                    Load Address                                                00000102 41100005     RXa       
         LNR   R1,R1                   Load Negative (32)                                          00000106 1111         RR        
         LA    R0,COM_4                Load Address                                                00000108 41008004     RXa       
         LNR   R0,R0                   Load Negative (32)                                          0000010C 1100         RR        
         SVC   34                      MGCR/MGCRE/QEDIT                                            0000010E 0A22         I         

         J     set_rc0                                                                             00000110 A7F40006     RIc       

set_rc12 LA    R15,12                  Load Address                                                00000114 41F0000C     RXa       
         J     restore_registers                                                                   00000118 A7F40003     RIc       

set_rc0  SLR   R15,R15                 Subtract Logical (32)                                       0000011C 1FFF         RR        

restore_registers equ *
         L     R13,WA_4                Load (32)                                                   0000011E 58D0D004     RXa     4 (,F)

return_to_caller equ *
         L     R14,WA_C                Load (32)                                                   00000122 58E0D00C     RXa     4 (,F)
         LM    R0,R12,WA_14            Load Multiple (32)                                          00000126 980CD014     RSA    52 (,F)
         BR    R14                                                                                 0000012A 07FE         RRm       

*---------------------------------------------------------------------*
*                                                                      
*---------------------------------------------------------------------*

         DC    F'0'                    X'00000000'                                                 0000012C 00000000

extract_plist equ *
         DC    XL16'00000000000000000000000000000000'                                              00000130 

***********************************************************************
*                                                                     *
*                          R E G I S T E R S                          *
*                                                                     *
***********************************************************************

*---------------------------------------------------------------------*
* General purpose register equates                                     
*---------------------------------------------------------------------*

R0       EQU   0
R1       EQU   1
R2       EQU   2
R3       EQU   3
R4       EQU   4
R5       EQU   5
R6       EQU   6
R7       EQU   7
R8       EQU   8
R9       EQU   9
R10      EQU   10
R11      EQU   11
R12      EQU   12
R13      EQU   13
R14      EQU   14
R15      EQU   15

***********************************************************************
*                                                                     *
*                             D S E C T S                             *
*                                                                     *
***********************************************************************

*---------------------------------------------------------------------*
* Parameter List                                                       
*---------------------------------------------------------------------*

PLIST    DSECT                                                         
PLIST_0  DS    F                                                       
PLIST_4  DS    F                                                       
PLIST_8  DS    F                                                       

*---------------------------------------------------------------------*
* Work Area                                                            
*---------------------------------------------------------------------*

WA       DSECT                                                         
         DS    XL4                                                     
WA_4     DS    F                                                       
         DS    XL4                                                     
WA_C     DS    F                                                       
         DS    XL4                                                     
WA_14    DS    13F                                                     
WA_48    DS    F                                                       

*---------------------------------------------------------------------*
* Command Data Area                                                    
*---------------------------------------------------------------------*

COM      DSECT                                                         
COM_0    DS    F                                                       
COM_4    DS    F                                                       

*---------------------------------------------------------------------*
* Command Input Buffer                                                 
*---------------------------------------------------------------------*

CIB      DSECT                                                         
         DS    XL4                                                     
CIB_4    DS    XL1                                                     
         DS    XL9                                                     
CIB_E    DS    H                                                       
CIB_10   DS    XL1                                                     
         END
