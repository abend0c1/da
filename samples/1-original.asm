***********************************************************************
**                                                                   **
** NAME     - GETCMD                                                 **
**                                                                   **
** TITLE    - z/OS CONSOLE COMMAND INTERFACE                         **
**                                                                   **
** FUNCTION - This routine is an z/OS console command handler.       **
**                                                                   **
**                                                                   **
** ON ENTRY - R1  -> Return structure consisting of:                 **
**                   A(VERB) -> CL1'x'  Command verb (e.g. 'F')      **
**                   A(DATA) -> CL256'operands'                      **
**                   A(ECB)  -> ECB                                  **
**            R13 -> Register save area                              **
**            R14 -> Return point                                    **
**            R15 -> Entry point                                     **
**                                                                   **
** ON EXIT  - R15 =  0                                               **
**                                                                   **
** EXAMPLE  - The operator starts the address space:                 **
**                                                                   **
**            S stcname,,optional operands                           **
**                                                                   **
**            The FIRST time the calling program executes:           **
**              CALL GETCMD,(cVerb,sOperands,pECB),MF=E              **
**              ...the return values for the call will be:           **
**                 cVerb     = 'S'    ...for the START command       **
**                 sOperands = 'optional operands'                   **
**                 pECB      -> ECB to optionally wait upon          **
**                                                                   **
**            The operator issues: F stcname,STOP IMMEDIATE          **
**                                                                   **
**            The calling program, which may have been waiting on    **
**            the returned ECB, executes:                            **
**              CALL GETCMD,(cVerb,sOperands,pECB),MF=E              **
**              ...the return values for the call will be:           **
**                 cVerb     = 'F'                                   **
**                 sOperands = 'STOP IMMEDIATE'                      **
**                 pECB      -> ECB to optionally wait upon          **
**                                                                   **
**                                                                   **
**                                                                   **
** NOTES    - 1.  The first time this routine is called, the START   **
**                command and its parameters will be returned.       **
**                                                                   **
**            2.  This routine can be called at any time.  If one    **
**                or more commands are pending, then the first of    **
**                them is returned and then deleted from the queue.  **
**                If no command is pending then the command verb is  **
**                set to X'00'.                                      **
**                                                                   **
**            3.  After the first call to this routine, the ECB      **
**                address is set.  The calling program may choose to **
**                wait on this ECB, which is posted by z/OS when     **
**                an operator has issued a command to this address   **
**                space, and call this routine to obtain the command **
**                just issued.  Alternatively, the calling program   **
**                may simply check the command verb and, if it is    **
**                X'00', then there is no operator command to process.*
**                                                                   **
** AUTHOR   - Andrew J. Armstrong <androidarmstrong@gmail.com>       **
**                                                                   **
** HISTORY  - Date     By  Reason (most recent at the top please)    **
**            -------- --- ----------------------------------------- **
**            20011031 AJA Massage for a non-C calling program.      **
**            19951208 AJA Original version.                         **
**                                                                   **
***********************************************************************
         
***********************************************************************
*                                                                     *
*                         R E G I S T E R S                           *
*                                                                     *
***********************************************************************

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
*                            M A C R O S                              *
*                                                                     *
***********************************************************************

         MACRO
&sLabel  EYECATCH
         LCLC  &sYYYY,&sMM,&sDD,&sHR,&sMI
.*--------------------------------------------------------------------*
.*       Eye-catcher
.*--------------------------------------------------------------------*
&sYYYY   SETC  '&SYSDATC'(1,4)
&sMM     SETC  '&SYSDATC'(5,2)
&sDD     SETC  '&SYSDATC'(7,2)
&sHR     SETC  '&SYSTIME'(1,2)
&sMI     SETC  '&SYSTIME'(4,2)
         J     A&SYSNDX           Jump over eye-catcher
&sLabel  DC    CL8'&SYSECT'            CSECT name
         DC    CL10'&sYYYY/&sMM/&sDD'  Assembly date
         DC    CL6' &sHR:&sMI'         Assembly time
A&SYSNDX DS    0H
         MEND         

***********************************************************************
*                                                                     *
*                          M A I N L I N E                            *
*                                                                     *
***********************************************************************

GETCMD   CSECT
GETCMD   AMODE 31
GETCMD   RMODE ANY
EYECATCH EYECATCH                 Put eye-catcher in CSECT storage
         STM   R14,R12,12(R13)
         LR    R12,R15
         USING GETCMD,R12
*        -----------------

         LR    R4,R1              -> Parameter list
         USING PARMLIST,R4        Map parameter list
*        -----------------

         STORAGE OBTAIN,LENGTH=WORKAREA_LENGTH,LOC=BELOW
         LTR   R15,R15
         JNZ   Quit

         ST    R13,4(,R1)         Chain forward
         ST    R1,8(,R13)         Chain backward
         LR    R13,R1             -> My save area + work area
         USING WORKAREA,R13       Map work area
*        ------------------

*---------------------------------------------------------------------*
*        Validate parameters passed
*---------------------------------------------------------------------*

         LTR   R4,R4           Parameter passed?
         JZ    setRC12         No, jump

         TM    pLastParm,X'80'    Correct number of parameters?
         JNO   setRC12            No, jump

*---------------------------------------------------------------------*
*        Extract address of COM data area
*---------------------------------------------------------------------*

         LA    R8,pCOM            -> Fullword to store COM address
         EXTRACT (R8),FIELDS=COMM,MF=(E,ELIST)

*---------------------------------------------------------------------*
*        Initialise return values
*---------------------------------------------------------------------*

         L     R8,pCOM            -> COM data area
         USING COM,R8             Map command data area
*        ------------
         L     R7,COMECBPT        -> ECB supplied by z/OS
         L     R1,pECB            -> A(ECB) in callers parameter list
         ST    R7,0(,R1)          -> ECB

         L     R7,pcCommand       -> Command verb
         MVI   0(R7),0

         L     R7,psOperand       -> Command operands
         XC    0(256,R7),0(R7)

*---------------------------------------------------------------------*
*        Get the operator command and parameters
*---------------------------------------------------------------------*

         L     R7,COMCIBPT        -> First Command Input Buffer
         LTR   R7,R7              Are there any CIBs in the chain?
         JZ    continue           No, branch

         USING CIB,R7             Map Command Input Buffer
*        ------------
         L     R9,pcCommand       -> Command verb

         CLI   CIBVERB,CIBMODFY   Is this a MODIFY command CIB?
         JNE   checkStop
         MVI   0(R9),C'F'         Indicate MODIFY command
         J     copyData

checkStop DS   0H
         CLI   CIBVERB,CIBSTOP    Is this a STOP command CIB?
         JNE   checkStart
         MVI   0(R9),C'P'         Indicate STOP command
         J     copyData

checkStart DS   0H
         CLI   CIBVERB,CIBSTART   Is this a START command CIB?
         JNE   deleteCIB
         MVI   0(R9),C'S'         Indicate START command
         J     copyData

copyData DS    0H
         LH    R5,CIBDATLN        Get L'data (multiples of 8 bytes)
         BCTR  R5,*-*             -1 for EX
         LTR   R5,R5              Is there any command data?
         JM    deleteCIB          No, branch

         L     R9,psOperand       -> Command operands
copyOps  MVC   0(*-*,R9),CIBDATA Copy command data
         EX    R5,copyOps
         J     deleteCIB

*---------------------------------------------------------------------*
*        Delete this command from the Command Input Buffer chain
*---------------------------------------------------------------------*

deleteCIB DS   0H
         QEDIT ORIGIN=COMCIBPT,BLOCK=(R7)  Delete this CIB

*---------------------------------------------------------------------*
*        Ensure MODIFY commands are enabled
*---------------------------------------------------------------------*

continue DS    0H
         QEDIT ORIGIN=COMCIBPT,CIBCTR=5    Enable MODIFY commands
         J     setRC0
         DROP  R7,R8
*        -----------

*---------------------------------------------------------------------*
*        Return to caller
*---------------------------------------------------------------------*

setRC12  DS    0H
         LA    R15,12             R15 = 12
         J     return

setRC0   DS    0H
         SLR   R15,R15            R15 = 0

return   DS    0H
         L     R13,4(,R13)        -> Caller's save area
Quit     DS    0H
         RETURN (14,12),RC=(15)

*==========================END OF ROUTINE=============================*

***********************************************************************
*                                                                     *
*                          L I T E R A L S                            *
*                                                                     *
***********************************************************************

         LTORG ,
         
***********************************************************************
*                                                                     *
*                         C O N S T A N T S                           *
*                                                                     *
***********************************************************************

ELIST    EXTRACT MF=L
         
***********************************************************************
*                                                                     *
*                            D S E C T S                              *
*                                                                     *
***********************************************************************

*---------------------------------------------------------------------*
*         Parameter list passed on entry
*---------------------------------------------------------------------*

PARMLIST DSECT
pcCommand DS    A                 -> CL1'x'  Console command
psOperand DS    A                 -> CL256'command operands'
pECB      DS    A                 -> ECB to wait on
pLastParm EQU   *-4

*---------------------------------------------------------------------*
*        Map area returned by EXTRACT FIELDS=COMM
*---------------------------------------------------------------------*

COM      DSECT
         IEZCOM ,

*---------------------------------------------------------------------*
*        Map Command Input Buffer (CIB) chain entry
*---------------------------------------------------------------------*

CIB      DSECT
         IEZCIB ,
         
***********************************************************************
*                                                                     *
*                          W O R K A R E A                            *
*                                                                     *
***********************************************************************

WORKAREA DSECT
SAVEAREA DS    18F

pCOM     DS    A                  -> Area mapped by COM DSECT

WORKAREA_LENGTH EQU *-WORKAREA
         
         END
