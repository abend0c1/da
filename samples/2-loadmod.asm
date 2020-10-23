@        START
*Label   Op    Operands                Comment                                                     Location Hex          Format

***********************************************************************
*                                                                     *
*                               GETCMD                                *
*                                                                     *
***********************************************************************
         
         ORG   @+X'00000000'

GETCMD   J     L1C                                                                                 1 00000000 A7F4000E     RIc       
         DC    CL24'GETCMD  2020/10/21 16:17'                                                      0 00000004 

L1C      STM   R14,R12,12(R13)         Store Multiple (32)                                         1 0000001C 90ECD00C     RSA    60 (,F)
         LR    R12,R15                 Load (32)                                                   1 00000020 18CF         RR        
         USING GETCMD,R12
*        ----------------
         LR    R4,R1                   Load (32)                                                   1 00000022 1841         RR        
         USING PLIST,R4
*        --------------
         B     L30                                                                                 1 00000024 47F0C030     RXb       

L28      DC    F'76'                                                                               0 00000028 0000004C

L2C      DC    F'18'                                                                               0 0000002C 00000012

L30      L     R0,L28                  Load (32)                                                   1 00000030 5800C028     RXa     4 (,F)
         L     R15,L2C                 Load (32)                                                   1 00000034 58F0C02C     RXa     4 (,F)
         L     R14,16                  Load (32) -> CVT                                            1 00000038 58E00010     RXa     4 (,F)
         L     R14,X'304'(R14)         Load (32)                                                   1 0000003C 58EE0304     RXa     4 (,F)
         L     R14,X'0A0'(R14)         Load (32)                                                   1 00000040 58EE00A0     RXa     4 (,F)
         PC    0(R14)                  Program Call                                                1 00000044 B218E000     S         

         LTR   R15,R15                 Load and Test (32)                                          1 00000048 12FF         RR        
         JNZ   L122                    Branch if Not Zero                                          1 0000004A A774006C     RIc       
         ST    R13,4(,R1)              Store (32)                                                  1 0000004E 50D01004     RXa     4 (,F)
         ST    R1,8(,R13)              Store (32)                                                  1 00000052 5010D008     RXa     4 (,F)
         LR    R13,R1                  Load (32)                                                   1 00000056 18D1         RR        
         USING WA,R13
*        ------------
         LTR   R4,R4                   Load and Test (32)                                          1 00000058 1244         RR        
         JZ    L114                    Branch if Zero                                              1 0000005A A784005D     RIc       
         TM    PLIST_8,B'10000000'     Test under Mask (8)                                         1 0000005E 91804008     SI0       
         JNO   L114                    Branch if Not Ones                                          1 00000062 A7E40059     RIc       
         LA    R8,WA_48                Load Address                                                1 00000066 4180D048     RXa       
         LA    R1,L130                 Load Address                                                1 0000006A 4110C130     RXa       
         ST    R8,0(R1)                Store (32)                                                  1 0000006E 50810000     RXa     4 (,F)
         MVI   8(R1),1                 Move Immediate (8)                                          1 00000072 92011008     SI      1 
         MVI   9(R1),0                 Move Immediate (8)                                          1 00000076 92001009     SI      1 
         SVC   40                      EXTRACT                                                     1 0000007A 0A28         I         

         L     R8,WA_48                Load (32)                                                   1 0000007C 5880D048     RXa     4 (,F)
         L     R7,0(,R8)               Load (32)                                                   1 00000080 58708000     RXa     4 (,F)
         L     R1,PLIST_8              Load (32)                                                   1 00000084 58104008     RXa     4 (,F)
         ST    R7,0(,R1)               Store (32)                                                  1 00000088 50701000     RXa     4 (,F)
         L     R7,PLIST_0              Load (32)                                                   1 0000008C 58704000     RXa     4 (,F)
         MVI   0(R7),0                 Move Immediate (8)                                          1 00000090 92007000     SI      1 
         L     R7,PLIST_4              Load (32)                                                   1 00000094 58704004     RXa     4 (,F)
         XC    0(256,R7),0(R7)         Exclusive-Or Character                                      1 00000098 D7FF70007000 SSa   256 (,X)
         L     R7,4(,R8)               Load (32)                                                   1 0000009E 58708004     RXa     4 (,F)
         LTR   R7,R7                   Load and Test (32)                                          1 000000A2 1277         RR        
         JZ    L102                    Branch if Zero                                              1 000000A4 A784002F     RIc       
         L     R9,PLIST_0              Load (32)                                                   1 000000A8 58904000     RXa     4 (,F)
         CLI   4(R7),X'44'             Compare Logical Immediate (8)                               1 000000AC 95447004     SI      1 
         JNE   LBC                     Branch if Not Equal                                         1 000000B0 A7740006     RIc       
         MVI   0(R9),C'F'              Move Immediate (8)                                          1 000000B4 92C69000     SI      1 
         J     LDC                                                                                 1 000000B8 A7F40012     RIc       

LBC      CLI   4(R7),C' '              Compare Logical Immediate (8)                               1 000000BC 95407004     SI      1 
         JNE   LCC                     Branch if Not Equal                                         1 000000C0 A7740006     RIc       
         MVI   0(R9),C'P'              Move Immediate (8)                                          1 000000C4 92D79000     SI      1 
         J     LDC                                                                                 1 000000C8 A7F4000A     RIc       

LCC      CLI   4(R7),4                 Compare Logical Immediate (8)                               1 000000CC 95047004     SI      1 
         JNE   LFA                     Branch if Not Equal                                         1 000000D0 A7740015     RIc       
         MVI   0(R9),C'S'              Move Immediate (8)                                          1 000000D4 92E29000     SI      1 
         J     LDC                                                                                 1 000000D8 A7F40002     RIc       

LDC      LH    R5,14(,R7)              Load Halfword (32<-16)                                      1 000000DC 4850700E     RXa     2 (,H)
         BCTR  R5,R0                   Branch on Count                                             1 000000E0 0650         RR        
         LTR   R5,R5                   Load and Test (32)                                          1 000000E2 1255         RR        
         JM    LFA                     Branch if Minus                                             1 000000E4 A744000B     RIc       
         L     R9,PLIST_4              Load (32)                                                   1 000000E8 58904004     RXa     4 (,F)

LEC      MVC   0(1,R9),16(R7)          Move Character                                              1 000000EC D20090007010 SSa     1 
         EX    R5,LEC                  Execute MVC 0(1,R9),16(R7)                                  1 000000F2 4450C0EC     RXa       
         J     LFA                                                                                 1 000000F6 A7F40002     RIc       

LFA      LNR   R1,R7                   Load Negative (32)                                          1 000000FA 1117         RR        
         LA    R0,4(,R8)               Load Address                                                1 000000FC 41008004     RXa       
         SVC   34                      MGCR/MGCRE/QEDIT                                            1 00000100 0A22         I         

L102     LA    R1,5                    Load Address                                                1 00000102 41100005     RXa       
         LNR   R1,R1                   Load Negative (32)                                          1 00000106 1111         RR        
         LA    R0,4(,R8)               Load Address                                                1 00000108 41008004     RXa       
         LNR   R0,R0                   Load Negative (32)                                          1 0000010C 1100         RR        
         SVC   34                      MGCR/MGCRE/QEDIT                                            1 0000010E 0A22         I         

         J     L11C                                                                                1 00000110 A7F40006     RIc       

L114     LA    R15,12                  Load Address                                                1 00000114 41F0000C     RXa       
         J     L11E                                                                                1 00000118 A7F40003     RIc       

L11C     SLR   R15,R15                 Subtract Logical (32)                                       1 0000011C 1FFF         RR        

L11E     L     R13,WA_4                Load (32)                                                   1 0000011E 58D0D004     RXa     4 (,F)

L122     L     R14,WA_C                Load (32)                                                   1 00000122 58E0D00C     RXa     4 (,F)
         LM    R0,R12,WA_14            Load Multiple (32)                                          1 00000126 980CD014     RSA    52 (,F)
         BR    R14                                                                                 1 0000012A 07FE         RRm       

*---------------------------------------------------------------------*
*                                                                      
*---------------------------------------------------------------------*

         DC    F'0'                    X'00000000'                                                 0 0000012C 00000000

L130     DC    XL16'00000000000000000000000000000000'                                              0 00000130 

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
         END
