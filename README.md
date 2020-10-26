# DA - Mainframe Disassembler in REXX

## FUNCTION

The DA REXX procedure disassembles the AMBLIST output (or indeed any printable hex) that you are currently editing with ISPF/EDIT. 

The DAB REXX procedure does the same thing but does not use ISPF/EDIT, so it can be run in TSO, batch, or even on Linux or Windows.

This can be very handy for mainframe sites that have somehow lost the source code to an important executable. All you need to do is run DA or DAB against the output from an AMBLIST module listing of the executable. It is an iterative process, but at the end of the day you will have an assembler source file that, when assembled, should recreate the executable load module.


## OVERVIEW

DA is the interactive version of the disassembler and DAB is the batch version. The interactive version uses ISPF/EDIT and is generally more convenient to use on z/OS. DAB can be run in TSO or batch and, because it does not use ISPF/EDIT, it can also be run on Linux and Windows.

*   If DA is invoked outside of the ISPF editor then it
    will generate and edit an AMBLIST job that you can
    submit to produce a module listing that can be read
    by the DA macro. For example, the following command
    will generate JCL to list module IEFBR14:

    `TSO DA SYS1.LPALIB(IEFBR14)`

*   If DA is invoked in an ISPF edit session with the TEST
    option, for example:
    
    `DA (TEST`
    
    ...then an assembler source file
    is generated containing one valid assembler statement
    for each instruction. This can be assembled into a
    load module, printed with AMBLIST and used to check
    that DA can disassemble all instructions correctly.

*   If DA is invoked in an ISPF edit session with the ASM
    option, for example:
    
    `DA (ASM`
    
    ...then JCL to assemble the file being edited is 
    generated.

*   If DA is invoked in an ISPF edit session with no
    options, for example:

    `DA`
 
    ...then it will disassemble the file being edited and edit 
    the temporary dataset created as a result.

*   If DA is invoked with hex on the command line then 
    that hex will be disassembled, for example:

    `DA 58100010 07FE`

*   DAB can be run in batch, for example:

    ```
    //        EXEC PGM=IKJEFT01
    //SYSEXEC   DD DISP=SHR,DSN=SYS1.MY.EXECLIB
    //IN        DD DISP=SHR,DSN=SYS1.MY.AMBLIST.OUTPUT
    //OUT       DD DISP=SHR,DSN=SYS1.MY.ASM(MEM)
    //SYSTSIN   DD *
    TSO DAB DD:IN DD:OUT
    /*
    ```
*   DAB can be run in TSO (but DA is easier), for example:

    `TSO DAB sys1.my.amblist.output sys1.my.asm(mem)`

*   DAB can be run on Linux and Windows once you have downloaded the
    AMBLIST output, for example:

    `rexx dab.rex my.amblist.output my.asm`


## WORKFLOW

Disassembly is usually an iterative process:

1.  Run DA on the AMBLIST output. This will help to
    identify which areas are data and which are code.

    If you see a comment in the output like `<-- TODO
    (not code)` it means that the disassembler was in
    CODE parsing mode but detected an invalid instruction. You should insert a dot (`.`) to switch the disassembler into DATA parsing mode at that point, and
    then insert a comma (`,`) to revert to CODE mode at the end
    of that block of data.

1.  Mark the beginning of areas known to be code with a
    comma (`,`) and those known to be data with a dot (`.`).
    
    *Remember: Comma-for-Code, Dot-for-Data.*
    
    Run DA again until no TODO comments are seen.

1.  Optionally, tag the AMBLIST output. There is much more detail on tagging in the [USAGE](#usage) section below.
    
    Tags are strings enclosed in parentheses and can be used to:

    * Mark data areas as having particular data types.

        For example:

        `(F) 00000010 (H) 00220023 (X) 0102(P)19365C (B)8F`

        Generates:
        ```
                 DC    F'16'
                 DC    H'34'
                 DC    H'35'
                 DC    XL2'0102'
                 DC    PL3'19365'
                 DC    B'10001111'
        ```
    * Assign a label at an offset into the code.

        For example:
        
        `18CF(myLabel)47F0C010`

        Generates:
        ```
                 LR    R12,R15
        myLabel  B     16(,R12)
        ```

    * Explicitly assign a label to a code offset:

        For example:

        `(myLabel=2,myData=6)18CF47F0C010.1234`

        Generates:
        ```
                 LR    R12,R15
        myLabel  B     16(,R12)
        myData   DC    XL2'1234'
        ```

    * Specify and/or drop a base register for the subsequent code.

        For example:
        
        `(R12)18CF47F0C002(R12=)`

        Generates:
        ```
                 USING *,R12
                 LR    R12,R15
        L2       B     L2
                 DROP  R12
        ```

    * Specify a base register for a named DSECT. 
    
        This is very powerful because it causes a DSECT to
        be built containing fields for each displacement
        off that base register that is referenced by the
        code. The name of each field is derived from the
        displacement.

        For example:
        
        `(R13=>WA)5810D010 5010D044 (R13=)`

        Generates:
        ```
                 USING WA,R13
                 L     R1,WA_10
                 ST    R1,WA_44
                 DROP  R13

        WA       DSECT
                 DS    XL16
        WA_10    DS    XL4
                 DS    XL48
        WA_44    DS    XL4
        ```

    * Do some other useful things (see the [TAGS](#tags) section below)

1.  Assemble the disassembled source file. 

    You will likely see some assembly error messages like:

    `** ASMA044E Undefined symbol - L12C`

    ...which is easily resolved by going back to the
    AMBLIST output and inserting a "." (for data) at
    offset +12C. That will create the missing label
    (L12C) at that offset.

    Rerun DA and reassemble the output until all
    assembly errors are resolved.

## EXAMPLE 

Some samples of input and output files can be found in the /samples folder of this repository.

A sample input file (with DA markup highlighted) is:

<pre>
A7F4000E <b style="color:red;">.</b> C7C5E3C3 D4C44040 F2F0F2F0 61F1F061 F2F140F1 F67AF5F5 <b style="color:red;">,</b> 90ECD00C
18CF <b style="color:red;">(R12=0)</b> 1841 <b style="color:red;">(R4=>PLIST 'Parameter List')</b> 47F0C030 <b style="color:red;">(F)</b> 0000004C 00000012 <b style="color:red;">,</b> 5800C028 58F0C02C 58E00010 58EE0304
58EE00A0 B218E000 12FFA774 006C50D0 10045010 D00818D1 <b style="color:red;">(R13=>WA 'Work Area')</b> 1244A784 005D9180
4008A7E4 00594180 D0484110 C1305081 00009201 10089200 10090A28 5880D048
58708000 58104008 50701000 58704000 92007000 58704004 D7FF7000 70005870
80041277 A784002F 58904000 95447004 A7740006 92C69000 A7F40012 95407004
A7740006 92D79000 A7F4000A 95047004 A7740015 92E29000 A7F40002 4850700E
06501255 A744000B 58904004 D2009000 70104450 C0ECA7F4 00021117 41008004
0A224110 00051111 41008004 11000A22 A7F40006 41F0000C A7F40003 1FFF58D0
D00458E0 D00C980C D01407FE <b style="color:red;">('').</b> 00000000 00000000 00000000 00000000
</pre>

The meaning of the inserted markup is:

Markup | Meaning
---|---
<b style="color:red;">.</b>|Decode the following hex as data (the data type is automatic)
<b style="color:red;">,</b>|Decode the following hex as code
<b style="color:red;">(R12=0)</b>|Assume that R12 points to offset 0 (insert a USING statement for R12)
<b style="color:red;">(R4=>PLIST 'Parameter List')</b>|Assume that R4 points to a DSECT called PLIST, and insert a section heading 'Parameter List' before the DSECT definition. Subsequent storage references based on R4 will be added to the DSECT.
<b style="color:red;">(F)</b>|Decode the following hex as data (type is fullword)
<b style="color:red;">(R13=>WA 'Work Area')</b>|Assume that R13 points to a DSECT called WA, and insert a section heading 'Work Area' before the DSECT definition.  Subsequent storage references based on R13 will be added to the DSECT.
<b style="color:red;">('').</b>|Insert an empty comment and treat the following hex as data


The result of disassembling this input is:

```
@        START
*Label   Op    Operands                Comment                                                     Location Hex          Format

***********************************************************************
*                                                                     *
*                               GETCMD                                *
*                                                                     *
***********************************************************************
         
         ORG   @+X'00000000'

GETCMD   J     L1C                                                                                 1 00000000 A7F4000E     RIc       
         DC    CL24'GETCMD  2020/10/21 16:55'                                                      0 00000004 

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

L130     DC    XL12'000000000000000000000000'                                                      0 00000130 

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
```

## SYNTAX

### DA (z/OS only)
On z/OS you can use the DA edit macro (which needs ISPF/EDIT). The syntax is:

`DA [dsn | hex] [(options...]`


* When DA is invoked from TSO it creates an AMBLIST job to print the specified load module:

    `TSO DA [dsn]`
    
    Where,

    * `dsn` - Identifies the load module to be printed using AMBLIST. The
                dataset name must be fully qualified, without quotation marks, and
                include the module name in parentheses. The default dsn is SYS1.LPALIB(IEFBR14).

        For example:

        `TSO DA SYS1.LPALIB(IEFBR14)`

* When DA is invoked in an ISPF/EDIT session it disassembles AMBLIST output being edited:

    `DA [hex] [(options...]`

    Where,

    * `hex` - Optional hex to be disassembled directly from the command line.
    * `options` are specified after a single left parenthesis:

        `STAT`    - Generate instruction format and mnemonic usage statistics and append them as comments to the generated source file.

        `TEST`    - Generate a source file containing one instance of every instruction. When assembled into a module, the
                    result can be used to test the disassembler.

        `ASM`     - Generate JCL to assemble the file being edited.

### DAB (z/OS, Linux or Windows)
On z/OS (TSO or batch), Linux or Windows you can use the DAB exec. The syntax is:

`DAB [[filein | hex] [fileout | -]] [--options...]`


Where,

* `filein` - Identifies the input file to be disassembled. For z/OS it must be either a fully qualified dataset name (for example, `sys1.my.pds(mymem)`) or a DD name (for example, `DD:mydd`).
* `hex` - Hex to be disassembled directly from the command line. For example, `DAB 90ECD00C07FE`.
* `fileout` - Identifies the disassembled output file to be created. 
              The default is the path and file name of the input file with a `.asm` extension appended.
              If `-` is specified then the output is written to the console.
* `options` are specified after a double-dash:

    `STAT`    - Generate instruction format and mnemonic usage statistics and append them as comments to the generated source file.

    `TEST`    - Generate a source file called `test.asm` containing one instance of every instruction. 
                When assembled into a module, the result can be used to test the disassembler.

    `ASM`     - Wrap the disassembled output in JCL to assemble the source

    `AMBLIST` - Generate JCL in `fileout` to print the module identified by `filein`.


    Note that when an instruction refers to a storage location that does not currently have a label assigned to it we have an unresolved storage reference. Any unresolved storage references will be written to a file called `[filein].tags` so that they will be automatically resolved the next time you run DAB. These tags files can be deleted at any time because they will be recreated when needed.

## NOTES

1. As new instructions are added to the z/Series instruction set, it will be necessary to define them in
    the comments of the DA and DAB REXX procedures marked by BEGIN-xxx and END-xxx
    comments. Otherwise the new instructions will be
    treated as data.

1. To run DAB on Linux or windows, you will need to install a REXX interpreter such as:
    1. Regina REXX      (http://regina-rexx.sourceforge.net)
    1. Open Object REXX (http://www.oorexx.org/)
    
    On Linux, there is usually a REXX package that you can install using your package manager, for example:
    ```
    sudo apt install regina-rexx
    ```
   
    The interpreter can then be invoked in a command window by issuing, for example:
    ```
    rexx dab.rex input.hex output.asm
    ```

## USAGE

To disassemble a load module:

1. Run TSO DA to generate and edit an AMBLIST job. For example:

   `TSO DA SYS1.LPALIB(IEFBR14)`

1. Submit the AMBLIST job to print a dump of the selected module

1. Edit the SYSPRINT output (for example, issue SE in SDSF)

1. Optionally, exclude areas that you do not want disassembled.
   That may help speed up disassembly of large modules.

1. Optionally, mark blocks of hex using **action markers**.

   Action markers are single characters that mark blocks of hex as being
   either CODE or DATA.

   The following action markers can be inserted:

    | Action | Meaning |
    |   ---  | ---     |
    | `,`    | Scan following hex as CODE. <br/>*Remember: Comma=Code* |
    | `.`    | Scan following hex as DATA. <br/>*Remember: Dot=Data* |
    | `/`    |  Clear all tags and scan the following hex as DATA. This is equivalent to specifying a null tag `()` but saves a keystroke |

1. Optionally, tag the hex more rigorously using **tags** (see the [TAGS](#tags) section below). 
   
   Tags are a way to further clarify how CODE or DATA blocks should be interpreted. Zero or more tags can be enclosed in parentheses and separated by commas as follows:

   `(tag,tag,tag,...)` 
   
   For example:
   
   `(MYCSECT,R12) 90ECD00C` 
   <br/>...means label the following hex MYCSECT and assume that R12 points to it at runtime.

   `(R12=,F) 00000001`
   <br/>...means that R12 no longer points to anything and that the following hex should be interpreted as fullword constants.


1. Issue DA to disassemble the AMBLIST output being edited.
   * Spaces in the hex input are not significant - with one
     exception explained next.

   * The DA edit macro will disassemble AMBLIST output that has the
     following format:
     ```
             Everything after 3 consecutive spaces is ignored
             (to work around a bug in versions of AMBLIST prior
             to z/OS v2.3) -----------.
                                      |
                                      V
     00000000 xxxxxxxx ... xxxxxxxx   *aaaaaaaaaaaaaaaa*
     |offset| |------hex data-----|   |---ignored----->
     ```
     See [APAR OA58170](https://www-01.ibm.com/support/docview.wss?uid=isg1OA58170) for more information about the AMBLIST bug.
    
    * If AMBLIST output is not detected, then the input is
    considered to be free form printable hex with no offset.
    For example:

        `18CF 5820C008 07FE 0000000A`

   * The first 80 columns of the disassembly are valid assembler
     statements and can be pasted into an FB80 file to be processed by 
     the HLASM assembler. That is, you can paste all the
     disassembled lines and ignore the truncation warning.

   * The remaining columns contain the following information that is useful during disassembly:
     
     location counter, instruction in hex, instruction format and
     the target operand length if any.

1. Examine the "Undefined labels" report at the end of the disassembly to help you 
   identify where to insert CODE and DATA action markers. 
   Labels will be created at each location referenced by a machine
   instruction or address constant.

1. Press F3 to quit editing the disassembly and return to the
   AMBLIST output - where you can adjust the tags as described
   above and try again.

1. Issue `DA (ASM` to generate JCL to assemble the file being edited. Submit this job to verify that the disassembled code
   assembles cleanly.

## TAGS

Zero or more of the following tags can be specified (inside parentheses and separated by commas) 
immediately before the hex to which they apply:


* ## ('*comment*')
  Inserts a comment into the generated source file with the format:

    ```
    *----------------------------------------------------------------------*
    * comment
    *----------------------------------------------------------------------*
    ```
  A good use for this is to mark the end of subroutines by making a global change to the hex input data  as follows:

    `C 07FE 07FE('') ALL`

  ...which will cause an empty comment to be inserted after every `BR R14` instruction. 
  You may wish to apply this change to `PR` instructions too.


* ## ("*comment*")
  Inserts a section comment into the generated source file with the format:

    ```
    ************************************************************************
    *                                                                      *
    *                               comment                                *
    *                                                                      *
    ************************************************************************
    ```
    A good use for this is to mark the start of subroutines by making a global change to the hex input data
    as follows:
    
    `C 90EC ("")90EC ALL`
    
    ...which will cause an empty section heading to be
    inserted before each `STM R14,R12,xxxx` instruction.


* ## (*t*)
    Converts subsequent hex to data type *t*, where *t* can be one of the following:
    | t   | Type      | Length | Generates (for example) |
    | --- | ---       | --- | --- |
    | `A` | Address   |4| `AL4(L304)` |
    | `AD`| Address (Long)  |8| `AD(L304)` |
    | `B` | Binary    |n| `B'10110011'` |
    | `C` | Character |n| `CL9'Some text'` |
    | `D` | Long Hex Float |8| `D'+3.141592653589793'` |
    | `DH`| Long Hex Float |8| `DH'+3.141592653589793'` |
    | `DB`| Long Bin Float |8| `DB'+3.141592653589793'` |
    | `DD`| Long Dec Float |8| `DD'+3.141592653589793'` |
    | `E` | Short Hex Float |4| `E'+3.1415926'` |
    | `EH`| Short Hex Float |4| `EH'+3.1415926'` |
    | `EB`| Short Bin Float |4| `EB'+3.1415926'` |
    | `ED`| Short Dec Float |4| `ED'+3.1415926'` |
    | `FD`| Doubleword Binary |8| `FD'304'` |
    | `F` | Fullword Binary |4| `F'304'` |
    | `H` | Halfword Binary |2| `H'304'` |
    | `P` | Packed Decimal |n| `PL2'304'` |
    | `S` | Storage Reference |2| `S(X'020'(R12))` |
    | `X` | Hex       |n| `XL2'0304'` |

* ## (%*formatspec*)
    Parses the subsequent hex as formatted rows of table data. The end of the table data is indicated
    by either a `/` action marker, or an empty tag list `()`, or an empty *formatspec* tag: `(%)`.
    Each row of table data is parsed according to the *formatspec*.
    The *formatspec* consists of zero or more space delimited assembler storage
    type declarations each having the format: 
    ```
    [duplication_factor][type][length_modifier]
    ```
    or
    ```
    [type][length_modifier]=variable_name
    ```
    or
    ```
    [type]L[length_expression]
    ```

    ...for example, `4XL3`.
    The default *duplication_factor* (the repetition count for the field) is 1.
    The default *type* is X (hexadecimal).
    The default *length_modifier* depends on the *type* as follows:
    | t   | Type      | Length |
    | --- | ---       | --- |
    | `A` | Address   |4|
    | `AD`| Address (long)  |8|
    | `B` | Binary    |1|
    | `C` | Character |1|
    | `D` | Long Hex Float |8|
    | `DH`| Long Hex Float |8|
    | `DB`| Long Bin Float |8|
    | `DD`| Long Dec Float |8|
    | `E` | Short Hex Float |4|
    | `EH`| Short Hex Float |4|
    | `EB`| Short Bin Float |4|
    | `ED`| Short Dec Float |4|
    | `FD`| Doubleword Binary |8|
    | `F` | Fullword Binary |4|
    | `H` | Halfword Binary |2|
    | `P` | Packed Decimal |1|
    | `S` | Storage Reference |2|
    | `X` | Hex       |1|

    If you specify an unsupported data type then the default format of `X` is used. As
    a happy side effect, specifying `3 3 3 3` or even just `4x3` (which you could read as "four by three bytes"), is equivalent to `4XL3` or `XL3 XL3 XL3 XL3`. If you specify
    just a number then that number is treated as a length of a type `X` field.

    For example<sup>1</sup>,

    ```
    (%CL3 X PL4).
    C1C3E3 02 0426709C  D5E2E6 01 8089526C  D5E340 02 0245869C
    D8D3C4 01 5095100C  E2C140 01 1751693C  E3C1E2 01 0534281C
    E5C9C3 01 6594804C  E6C140 01 2621680C
    ```

    ...(spaces inserted for clarity) will be disassembled as:

    ```
    L0       DC    CL3'ACT'
             DC    XL1'02'
             DC    PL4'426709'
             DC    CL3'NSW'
             DC    XL1'01'
             DC    PL4'8089526'
             DC    CL3'NT'
             DC    XL1'02'
             DC    PL4'245869'
             DC    CL3'QLD'
             DC    XL1'01'
             DC    PL4'5095100'
             DC    CL3'SA'
             DC    XL1'01'
             DC    PL4'1751693'
             DC    CL3'TAS'
             DC    XL1'01'
             DC    PL4'534281'
             DC    CL3'VIC'
             DC    XL1'01'
             DC    PL4'6594804'
             DC    CL3'WA'
             DC    XL1'01'
             DC    PL4'2621680'
    ```
    <sup>1</sup><sub>Australian state and territory population data (June 2019)</sub>

    By using the `=variable_name` and `:length_expression` syntax, you can parse variable
    length data. 
    
    When `=variable_name` is specified, a REXX variable is created called `$variable_name` 
    containing the contents of the associated field converted to decimal.
    
    When `length_expression` is specified, the expression can be any simple REXX 
    expression that results in a positive whole number. The expression must not contain
    parentheses. You should use variable names you created (using `=variable_name`) prefixed with a `$` sign, else the result will be unpredictable.
    
    For example, the following table entries contain string length fields which are
    one less than the actual length of each string:

    ```
    (%AL1=len CL$len+1).
    1B C1E4E2E3 D9C1D3C9 C1D540C3 C1D7C9E3 C1D340E3 C5D9D9C9 E3D6D9E8
    0E D5C5E640 E2D6E4E3 C840E6C1 D3C5E2
    11 D5D6D9E3 C8C5D9D5 40E3C5D9 D9C9E3D6 D9E8
    09 D8E4C5C5 D5E2D3C1 D5C4
    0E E2D6E4E3 C840C1E4 E2E3D9C1 D3C9C1
    07 E3C1E2D4 C1D5C9C1
    07 E5C9C3E3 D6D9C9C1
    10 E6C5E2E3 C5D9D540 C1E4E2E3 D9C1D3C9 C1
    ```
    ...(spaces again inserted for clarity) will be disassembled as:
    ```
    L0       DC    AL1(27)
             DC    CL28'AUSTRALIAN CAPITAL TERRITORY'
             DC    AL1(14)
             DC    CL15'NEW SOUTH WALES'
             DC    AL1(17)
             DC    CL18'NORTHERN TERRITORY'
             DC    AL1(9)
             DC    CL10'QUEENSLAND'
             DC    AL1(14)
             DC    CL15'SOUTH AUSTRALIA'
             DC    AL1(7)
             DC    CL8'TASMANIA'
             DC    AL1(7)
             DC    CL8'VICTORIA'
             DC    AL1(16)
             DC    CL17'WESTERN AUSTRALIA'
    ```
    Note: if you specify invalid variable names or expressions then expect pain.

* ## ()
    Resets the data type tag so that automatic data type
    detection is enabled. 
    You can instead use the "`/`" action marker to do this.
    
    Automatic data type detection
    splits the data into either printable text or binary.
    
    Binary data is defined:
    * as fullwords (`F`) if aligned on a fullword boundary, 
    * as halfwords (`H`) if aligned on a halfword boundary, 
    * else is output as hexadecimal (`X`).
    
    Printable text is defined:
    * as character constants (`C`).

* ## (@*xxx*)
    Specifies that the current location counter is to be
    set to the hex address specified by *xxx*.
    By default the initial location counter is 0.
    
    The equivalent assembler directive is:
    
    `ORG   @+X'xxx'`

* ## (R*n*)
    Specifies that register *n* (where *n* = 0 to 15) points
    to the immediately following code or data.
    
    The equivalent assembler directive is:

    `USING *,Rn`

    For example:
    ```
    Register 12 points to offset 0
    |   Code                Data
    |   |                   |
    V   V                   V
    (R12)18CF 5820C008 07FE . 0000000A
         code..............   data....
    ```
    The above would be disassembled as:
    ```
             USING *,R12
    L0       LR    R12,R15
             L     R2,L8
             BR    R14
    L8       DC    F'10'
    ```

* ## (R*n*+R*m*+...)
    Specifies that register *n* points to the immediately
    following code or data, and that register *m* points
    4096 bytes past register *n* (for as many registers as
    you specify). Each additional register extends the
    coverage by a further 4096 bytes.
    
    The equivalent assembler directive is:

    ```
             USING *,Rn,Rm
    ```

* ## (R*n*+R*m*+...=Ry)
    Similar to the `(R*n*+R*m*+...)` tag described above except that register
    *n* points to the location currently declared for register *y* instead of
    the location immediately after the tag.

    The equivalent assembler directives are:

    ```
             DROP  Ry
             USING *,Rn,Rm
    ```

    For example:
    ```
    (MYCSECT,R15)47F0F00C .C8C940E3 C8C5D9C5 ,18CF 18AF 
    A7AA1000(R12+R10=R15) 5820C014 07FE . 0000000A
    ```
    The above would be disassembled as:
    ```
            USING MYCSECT,R15
    *       -----------------
    MYCSECT B     LC

    L4      DC    CL8'HI THERE'

    LC      LR     R12,R15
            LR     R10,R15
            AHI    R10,4096
            DROP   R15
    *       ----------
            USING  MYCSECT,R12,R10
    *       ----------------------

    LE      L      R2,L14
            BR     R14

    L14     DC     F'10'

    ```

* ## (R*n*=>*name* '*desc*')
    Specifies that register *n* (where *n* = 0 to 15) points
    to (`=>`) a dummy section (DSECT) called *name*.
    Optionally, associate a short description *desc* to document the DSECT.
    A DSECT is then built to cover subsequent address
    references for that base register until a `(Rn=)` tag
    is encountered which DROPs that register.
    
    All DSECTs so generated will be appended to the end
    of the disassembled source.
    
    The equivalent assembler directive is:

    ```
             USING name,Rn
    ```
    For example:
    ```
    18D1 (R13=>WA 'Work Area') 4110D004 4120D010 5020D008
    ```
    The above would be disassembled as:
    ```
            LR     R13,R1
            USING  WA,R13
    *       -------------
            LA     R1,WA_4
            LA     R2,WA_10
            ST     R2,WA_8

    ************************************************************************
    *                                                                      *
    *                            Work Area                                 *
    *                                                                      *
    ************************************************************************
    
    WA      DSECT
            DS     XL4
    WA_4    DS     0X
            DS     XL4
    WA_8    DS     XL4
            DS     XL4
    WA_10   DS     0X
    ```
* ## (R*n*=*xxx*)
    Specifies that register *n* (where *n* = 0 to 15) points
    to location *xxx* in hexadecimal.
    
    The equivalent assembler directive is:

    ```
             USING @+xxx,Rn
    ```

    ...where `@` is the label assigned to offset 0.

* ## (R*n*=*label*)
    Specifies that register *n* (where *n* = 0 to 15) points
    to location identified by label *label*.
    
    The equivalent assembler directive is:

    ```
            USING label,Rn
    ```

* ## (R*n*=)
    Resets a base register tag. Any displacements off that register will now be generated explicitly (for example, `12(R13)`) instead of an offset from a generated label (for example, `L1B0+12`).

    The equivalent assembler directive is:

    ```
            DROP  Rn
    ```

* ## (*label*)
    Assigns an assembler label to the following code or
    data. You may use it to name a CSECT for example.
    The label cannot be `R0` to `R15`, or `A`, `B`, `C`, `D`, `DB`, `DD`, `E`, `EB`, `ED`, `F`, `H`, `P`, `S` or
    `X` as those have special meanings as described above.

    For example:
    ```
        Dot for Data    Comma for Code
        | Data label    | Code label
        | |             | |
        V V             V V
    07FE.(nSize)0000000A,(getCVT)58200010
    code        data....         code....
    ```
    The above would be disassembled as:
    ```
             BR    R14
    nSize    DC    X'0000000A'
    getCVT   L     R2,16
    ```

* ## (*label*=*x*) 
    Assigns the assembler label *label* to the location *x* in
    hexadecimal. Use this if you know in advance the
    offset of particular CSECTs. For example,

    `(MAIN=0,CSECTA=1C0,CSECTB=280)`

    Any address constants encountered will then use the
    specified name instead of a literal. For example,
    ```
             DC    A(448)
    ```
    ...will be generated as:
    ```
             DC    A(CSECTA)         X'000001C0'
    ```
    Some labels will be automatically created from the
    External Symbol Dictionary of the AMBLIST output.

* ## (.*xxx*)
    Assigns an automatically named assembler label to
    location *xxx* in hexadecimal. 
    
    Use this if you know in
    advance which locations are referenced by machine
    instructions so that the location can be represented
    by a label instead of a displacement off a register.
    
    DA will automatically insert one of these tags into
    the hex input (AMBLIST output) for each location
    referenced by a machine instruction that does not
    already have a label defined for it. The inserted
    tags will be taken into account the next time DA is 
    run. 
    
    This is equivalent to you manually
    inserting '.' action characters to create
    labels that are referenced by machine instructions.

* ## (.*xxx*=*t*)
    Assigns an automatically named assembler label and
    data type *t* to location *xxx* in hexadecimal. The
    type can be any of those described above for the (t) tag.

    If any unresolved storage references are detected during
    disassembly, they will be written to a `.tags` file which will be 
    loaded on subsequent runs so that they are automatically accounted 
    for. You can delete this file at any time.
