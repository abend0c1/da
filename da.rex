/*REXX*/
/* DA - z/OS Disassembler Edit Macro v3.0

Copyright (c) 2019-2020, Andrew J. Armstrong
All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Author:
Andrew J. Armstrong <androidarmstrong@gmail.com> 
*/
/*REXX*****************************************************************
**                                                                   **
** NAME     - DA                                                     **
**                                                                   **
** TITLE    - DISASSEMBLER EDIT MACRO                                **
**                                                                   **
** FUNCTION - Disassembles the AMBLIST output (or printable hex)     **
**            that is currently being edited.                        **
**                                                                   **
**            This is usually an iterative process:                  **
**                                                                   **
**            1. Run DA on the AMBLIST output. This will help to     **
**               identify which areas are data and which are code.   **
**                                                                   **
**               If you see a comment in the output like "<-- TODO   **
**               (not code)" it means that the disassembler was in   **
**               CODE parsing mode but detected an invalid instruc-  **
**               tion. You should insert a "." to switch the dis-    **
**               assembler into DATA parsing mode at that point, and **
**               then insert a "," to revert to CODE mode at the end **
**               of that block of data.                              **
**                                                                   **
**            2. Mark the beginning of areas known to be code with a **
**               "," and those known to be data with a "." (i.e.     **
**               Comma-for-Code, Dot-for-Data).                      **
**               Run DA again until no 'TODO' comments are seen.     **
**                                                                   **
**            3. Tag the AMBLIST output (much more detail below).    **
**               Run DA again until the result is satisfactory.      **
**               Tags are enclosed in parentheses and can be used    **
**               to:                                                 **
**                                                                   **
**               - Mark data areas as having particular data types.  **
**                                                                   **
**                 For example:                                      **
**                 (F) 00000010 (H) 00220023 (X) 0102(P)19365C (B)8F **
**                                                                   **
**                 Generates:                                        **
**                           DC    F'16'                             **
**                           DC    H'34'                             **
**                           DC    H'35'                             **
**                           DC    XL2'0102'                         **
**                           DC    PL3'19365'                        **
**                           DC    B'10001111'                       **
**                                                                   **
**               - Assign a label at an offset into the code.        **
**                                                                   **
**                 For example:                                      **
**                 18CF(myLabel)47F0C010                             **
**                                                                   **
**                 Generates:                                        **
**                          LR    R12,R15                            **
**                 myLabel  B     16(,R12)                           **
**                                                                   **
**               - Explicitly assign a label to a code offset:       **
**                                                                   **
**                 For example:                                      **
**                 (myLabel=2,myData=6)18CF47F0C010.1234             **
**                                                                   **
**                 Generates:                                        **
**                          LR    R12,R15                            **
**                 myLabel  B     16(,R12)                           **
**                 myData   DC    XL2'1234'                          **
**                                                                   **
**               - Specify/drop a base register for the subsequent   **
**                 code.                                             **
**                                                                   **
**                 For example:                                      **
**                 (R12)18CF47F0C002(R12=)                           **
**                                                                   **
**                 Generates:                                        **
**                          USING *,R12                              **
**                          LR    R12                                **
**                 L2       B     L2                                 **
**                          DROP  R12                                **
**                                                                   **
**               - Specify a base register for a named DSECT. This   **
**                 is very powerful because it causes a DSECT to     **
**                 be built containing fields for each displacement  **
**                 off that base register that is referenced by the  **
**                 code. The name of each field is derived from the  **
**                 displacement.                                     **
**                                                                   **
**                 For example:                                      **
**                 (R13=>WA)5810D010 5010D044 (R13=)                 **
**                                                                   **
**                 Generates:                                        **
**                          USING WA,R13                             **
**                          L     R1,WA_10                           **
**                          ST    R1,WA_44                           **
**                          DROP  R13                                **
**                 WA       DSECT                                    **
**                          DS    XL16                               **
**                 WA_10    DS    XL4                                **
**                          DS    XL48                               **
**                 WA_44    DS    XL4                                **
**                                                                   **
**               - Do some other useful things (see below)           **
**                                                                   **
**            4. Assemble the disassembled source file. You will     **
**               likely see some assembly error messages like:       **
**                                                                   **
**               ** ASMA044E Undefined symbol - L12C                 **
**                                                                   **
**               ...which is easily resolved by going back to the    **
**               AMBLIST output and inserting a "." (for data) at    **
**               offset +12C. That will create the missing label     **
**               (L12C) at that offset.                              **
**                                                                   **
**               Rerun DA and reassemble the output until all        **
**               assembly errors are resolved.                       **
**                                                                   **
**                                                                   **
**                                                                   **
**            If DA is invoked outside of the ISPF editor then it    **
**            will generate and edit an AMBLIST job that you can     **
**            submit to produce a module listing that can be read    **
**            by the DA macro. For example, the following command    **
**            will generate JCL to list module IEFBR14:              **
**                                                                   **
**            TSO DA SYS1.LPALIB(IEFBR14)                            **
**                                                                   **
**            If DA is invoked in an ISPF edit session with the TEST **
**            option, e.g. "DA (TEST", then an assembler source file **
**            is generated containing one valid assembler statement  **
**            for each instruction. This can be assembled into a     **
**            load module, printed with AMBLIST and used to check    **
**            that DA can disassemble all instructions correctly.    **
**                                                                   **
** SYNTAX   - DA [dsn | hex] [(options...]                           **
**                                                                   **
**            Where,                                                 **
**            dsn     = Load module to be printed using AMBLIST. The **
**                      dataset name must be fully qualified and     **
**                      include the module name in parentheses.      **
**                                                                   **
**            hex     = Hex to be disassembled. If this is omitted   **
**                      then the hex is read from the file being     **
**                      edited.                                      **
**                                                                   **
**                                                                   **
**            options =                                              **
**                                                                   **
**            STAT    - Generate instruction format and mnemonic     **
**                      usage statistics.                            **
**                                                                   **
**            TEST    - Generate a source file to exercise the       **
**                      assembler. When assembled into a module, the **
**                      result can be used to test the disassembler. **
**                                                                   **
**            ASM     - Generate an assembly job that you can submit **
**                      to verify the disassembled source is valid.  **
**                                                                   **
**            360     - Disassemble using the System/360 instruction **
**                      set.                                         **
**                                                                   **
**            370     - Disassemble using the System/370 instruction **
**                      set.                                         **
**                                                                   **
**            390     - Disassemble using the System/390 instruction **
**                      set.                                         **
**                                                                   **
**            Z       - Disassemble using the z/Architecture         **
**                      instruction set (this is the default).       **
**                                                                   **
**                                                                   **
** LOGIC    - 1. Read the hex input file and extract the hex and any **
**               tags describing the hex. Create tags to label each  **
**               CSECT name found (if any).                          **
**                                                                   **
**            2. Disassemble the hex producing a list of machine     **
**               instructions (code) or Define Constant (DC)         **
**               directives (data) - along with the corresponding    **
**               hex offset of each. If the user has specified tags  **
**               of the format (Rnn=>dsect) then build a DSECT for   **
**               each offset from the associated base register(s).   **
**                                                                   **
**            3. Build a list of references to storage locations     **
**               with the data type and length either inferred from  **
**               the machine instruction, or explicitly specified by **
**               the user having supplied a tag for that location.   **
**                                                                   **
**            4. Cycle through the statement list and apply a label  **
**               if a statement is referenced. The label can be      **
**               either explicitly specified by the user via a tag,  **
**               or automatically generated based on the location.   **
**                                                                   **
**            5. Cycle through the storage reference list, and for   **
**               each referenced location that has no label, emit a  **
**               comment saying that an undefined label was detect-  **
**               ed and insert a (.xxx) tag in the original hex      **
**               input file to account for the missing label. Warn   **
**               the user to rerun DA to pick up the extra inserted  **
**               tags.                                               **
**                                                                   **
**            6. For labels that cannot be assigned by this process, **
**               for example self-modifying code, emit an EQU        **
**               statement for each undefined label in order to      **
**               avoid assembly errors.                              **
**                                                                   **
**                                                                   **
**                                                                   **
** NOTES    - 1. As new instructions are added to the z/Series inst- **
**               ruction set, it will be necessary to define them in **
**               the comments below marked by BEGIN-xxx and END-xxx  **
**               comments. Otherwise the new instructions will be    **
**               treated as data.                                    **
**                                                                   **
**            2. A handy way to initially tag the AMBLIST output is  **
**               to issue the following EDIT commands:               **
**                                                                   **
**               C 90EC ("")90EC ALL; C 07FE 07FE('') ALL            **
**                                                                   **
**               This will highlight subroutines bounded by the      **
**               usual STM R14,R12,12(R13) and BR R14 instructions.  **
**                                                                   **
**                                                                   **
**                                                                   **
** USAGE    -                                                        **
**                                                                   **
BEGIN-JCL-COMMENTS
** To disassemble a load module:                                     **
**                                                                   **
** 0. Run TSO DA to generate and edit an AMBLIST job. For example:   **
**    TSO DA SYS1.LPALIB(IEFBR14)                                    **
**                                                                   **
** 1. Submit the AMBLIST job to print a dump of the selected module  **
**                                                                   **
** 2. Edit the SYSPRINT output (e.g. issue SE in SDSF)               **
**                                                                   **
** 3. Optionally, exclude areas that you do not want disassembled.   **
**    That may help speed up disassembly of large modules.           **
**                                                                   **
** 4. Optionally, mark blocks of hex using action markers.           **
**                                                                   **
**    Action markers are a quick way to mark blocks of hex as being  **
**    either CODE or DATA.                                           **
**                                                                   **
**    The following action markers can be inserted:                  **
**                                                                   **
**    Action    Meaning                                              **
**    --------- ---------------------------------------------------- **
**    ,         Scan following hex as CODE.                          **
**              Remember: Comma=Code                                 **
**                                                                   **
**    .         Scan following hex as DATA.                          **
**              Remember: Dot=Data                                   **
**                                                                   **
**    /         Reset to automatic data type detection and scan the  **
**              following hex as DATA. This is equivalent to speci-  **
**              fying a null tag () but saves a keystroke.           **
**                                                                   **
** 5. Optionally, tag the hex more rigorously:                       **
**                                                                   **
**    Tags are a way to further clarify how CODE or DATA blocks      **
**    should be interpreted. The syntax for a tag is:                **
**                                                                   **
**    (tag,...) One or more case sensitive tags separated by commas  **
**              and enclosed in parentheses. For example:            **
**                                                                   **
**              (MYCSECT,R12)                                        **
**                                                                   **
**              ...means label the data following MYCSECT and assume **
**              that R12 points to it at runtime.                    **
**                                                                   **
**              (R12=,F)                                             **
**                                                                   **
**              ...means that R12 no longer points to anything and   **
**              that the data following should be interpreted as     **
**              fullword constants.                                  **
**                                                                   **
**    The following tags can be inserted:                            **
**                                                                   **
**    (tag)     Meaning                                              **
**    --------- ---------------------------------------------------- **
**                                                                   **
**    ('comment') Inserts a comment into the generated source file   **
**              with the format:                                     **
**                                                                   **
**              *--------------------------------------------------* **
**              * comment                                            **
**              *--------------------------------------------------* **
**                                                                   **
**              A good use for this is to mark the end of subrout-   **
**              ines by making a global change to the hex input data **
**              as follows:                                          **
**              C 07FE 07FE('') ALL                                  **
**              ...which will cause an empty comment to be inserted  **
**              after every BR R14 instruction.                      **
**                                                                   **
**                                                                   **
**    ("comment") Inserts a comment into the generated source file   **
**              with the format:                                     **
**                                                                   **
**              **************************************************** **
**              *                                                  * **
**              *                    comment                       * **
**              *                                                  * **
**              **************************************************** **
**                                                                   **
**              A good use for this is to mark the start of subrout- **
**              ines by making a global change to the hex input data **
**              as follows:                                          **
**              C 90EC ("")90EC ALL                                  **
**              ...which will cause an empty section heading to be   **
**              inserted before each STM R14,R12,x(Rn) instruction.  **
**                                                                   **
**                                                                   **
**    (t)       Converts the following data to data type t, where    **
**              t can be one of the following:                       **
**                                                                   **
**              t  Type              Length Generates (for example)  **
**              -- -------           ------ ------------------------ **
**              A  Address           4      AL4(L304)                **
**              AD Address (Long)    8      AD(L304)                 **
**              B  Binary            1      B'10110011'              **
**              C  Character         n      CL9'Some text'           **
**              CA Character (ASCII) n      CL9'Some ASCII text'     **
**              D  Long Hex Float    8      D'3.141592653589793'     **
**              DH Long Hex Float    8      DH'3.141592653589793'    **
**              DB Long Bin Float    8      DB'3.141592653589793'    **
**              DD Long Dec Float    8      DD'3.141592653589793'    **
**              E  Short Hex Float   4      E'3.1415926'             **
**              EH Short Hex Float   4      EH'3.1415926'            **
**              EB Short Bin Float   4      EB'3.1415926'            **
**              ED Short Dec Float   4      ED'3.1415926'            **
**              FD Doubleword Binary 8      FD'304'                  **
**              F  Fullword Binary   4      F'304'                   **
**              H  Halfword Binary   2      H'304'                   **
**              P  Packed Decimal    n      PL2'304'                 **
**              S  Storage Reference 2      S(X'020'(R12))           **
**              X  Hexadecimal       n      XL2'0304'                **
**                                                                   **
**    (%formatspec)                                                  **
**                                                                   **
**              Parses the subsequent hex as formatted rows of table **
**              data. The end of the table data is indicated by      **
**              either a "/" action marker, or an empty tag list (), **
**              or an empty formatspec tag: (%). Each row of table   **
**              data is parsed according to the formatspec. The      **
**              formatspec consists of zero or more space delimited  **
**              assembler storage type declarations each having the  **
**              format:                                              **
**                      <duplication_factor><type><length_modifier>  **
**                  or: <type><length_modifier>=<variable_name>      **
**                  or: <type>L<length_expression>                   **
**                                                                   **
**              ...for example, 4XL3. The default duplication_factor **
**              (the repetition count for the field) is 1. The       **
**              default type is X (hexadecimal). The default length_ **
**              modifier depends on the type as follows:             **
**                                                                   **
**              t  Type              Length                          **
**              -- -------           ------                          **
**              A  Address           4                               **
**              AD Address (long)    8                               **
**              B  Binary            1                               **
**              C  Character         1                               **
**              CA Character (ASCII) 1                               **
**              D  Long Hex Float    8                               **
**              DH Long Hex Float    8                               **
**              DB Long Bin Float    8                               **
**              DD Long Dec Float    8                               **
**              E  Short Hex Float   4                               **
**              EH Short Hex Float   4                               **
**              EB Short Bin Float   4                               **
**              ED Short Dec Float   4                               **
**              FD Doubleword Binary 8                               **
**              F  Fullword Binary   4                               **
**              H  Halfword Binary   2                               **
**              P  Packed Decimal    1                               **
**              S  Storage Reference 2                               **
**              X  Hexadecimal       1                               **
**                                                                   **
**              If you specify an unsupported data type then the     **
**              default format of X is used. As a happy side effect, **
**              specifying "3 3 3 3" or even just "4x3" (which you   ** 
**              could read as "four by three bytes") is equivalent   ** 
**              to "4XL3" or "XL3 XL3 XL3 XL3". If you specify       **
**              just a number then that number is treated as the     **
**              length of a type X field (e.g. "3" is the same as    **
**              "XL3").                                              **
**                                                                   **
**              For example,                                         **
**                                                                   **
**              (%CL3 X PL4).                                        **
**              C1C3E3 02 0426709C  D5E2E6 01 8089526C /             **
**                                                                   **
**              ...(spaces inserted for clarity) will be disassembled**
**              as:                                                  **
**                                                                   **
**              L0       DC   CL3'ACT'        <-- Table row 1        **
**                       DC   XL1'02'                                **
**                       DC   PL4'426709'                            **
**                       DC   CL3'NSW'        <-- Table row 2        **
**                       DC   XL1'01'                                **
**                       DC   PL4'8089526'                           **
**                                                                   **
**              By using the =variable_name and length_expression    **
**              syntax, you can parse variable length data.          **
**                                                                   **
**              When =variable_name is specified, a rexx variable is **
**              created called $variable_name - to avoid clashes with**
**              variables already used by the DA Rexx procedure -    **
**              containing the contents of the associated field      **
**              converted to decimal.                                **
**                                                                   **
**              When length_expression is specified, the expression  **
**              can be any simple Rexx expression that results in a  **
**              positive whole number. The expression must not cont- **
**              ain parentheses. You should use variable names you   **
**              created with a $ sign prepended, else the result will**
**              be unpredictable.                                    **
**                                                                   **
**              For example,                                         **
**                                                                   **
**              (%AL1=n CL$n+1).                                     **
**              00 C1 01 C1C2 04 C1C2C34040                          **
**                                                                   **
**              ...will be disassembled as:                          **
**                                                                   **
**              L0       DC   AL1(0)          <-- Variable string 1  **
**                       DC   CL1'A'          <-- Length is 0+1      **
**                       DC   AL1(1)          <-- Variable string 2  **
**                       DC   CL2'AB'         <-- Length is 1+1      **
**                       DC   AL1(4)          <-- Variable string 3  **
**                       DC   CL5'ABC'        <-- Length is 4+1      **
**                                                                   **
**    ()        Resets the data type tag so that automatic data type **
**              detection is enabled. Automatic data type detection  **
**              splits the data into either printable text or binary.**
**              Binary data is defined as fullwords if aligned on a  **
**              fullword boundary, as halfwords if aligned on a      **
**              halfword boundary, or else is output as hexadecimal. **
**              Printable text is defined as character constants.    **
**              You can instead use the "/" action marker to do this.**
**                                                                   **
**    (@xxx)    Specifies that the current location counter is to be **
**              set to the hex address specified by xxx.             **
**              By default the initial location counter is 0.        **
**              The equivalent assembler directive is:               **
**              ORG   @+X'xxx'                                       **
**                                                                   **
**    (Rn)      Specifies that register n (where n = 0 to 15) points **
**              to the immediately following code or data.           **
**              The equivalent assembler directive is:               **
**              USING *,Rn                                           **
**                                                                   **
**              For example:                                         **
**                                                                   **
**               Register 12 points to offset 0                      **
**               |   Code               Data                         **
**               |   |                  |                            **
**               V   V                  V                            **
**              (R12)18CF 5820C008 07FE . 0000000A                   **
**                   code..............   data....                   **
**                                                                   **
**              The above would be disassembled as:                  **
**                                                                   **
**                        USING *,R12                                **
**              *         -----------                                **
**              L0        LR    R12,R15                              **
**                        L     R2,L8                                **
**                        BR    R14                                  **
**              L8        DC    F'10'                                **
**                                                                   **
**    (Rn+Rm)   Specifies that register n points to the immediately  **
**              following code or data, and that register m points   **
**              4096 bytes past register n (for as many registers as **
**              you specify - each additional register extends the   **
**              coverage by a further 4096 bytes).                   **
**              The equivalent assembler directive is:               **
**              USING *,Rn,Rm                                        **
**                                                                   **
**    (Rn+Rm=Ry) Same as (Rn+Rm) except that Rn+Rm points to the     **
**              location currently declared for Ry.                  **
**              The equivalent assembler directive is:               **
**              DROP  Ry                                             **
**              USING *,Rn,Rm                                        **
**                                                                   **
**    (Rn=>name'desc')                                               **
**              Specifies that register n (where n = 0 to 15) points **
**              to (=>) a dummy section (DSECT) called "name".       **
**              Optionally, associate a short description "desc".    **
**              A DSECT is then built to cover subsequent address    **
**              references for that base register until a (Rn=) tag  **
**              is encountered which DROPs that register.            **
**              All DSECTs so generated will be appended to the end  **
**              of the disassembled source.                          **
**              The equivalent assembler directive is:               **
**              USING name,Rn                                        **
**                                                                   **
**    (Rn=xxx)  Specifies that register n (where n = 0 to 15) points **
**              to location xxx in hexadecimal.                      **
**              The equivalent assembler directive is:               **
**              USING @+xxx,Rn                                       **
**                                                                   **
**              ...where "@" is the label assigned to offset 0.      **
**                                                                   **
**    (Rn=label)Specifies that register n (where n = 0 to 15) points **
**              to location identified by label "label".             **
**              The equivalent assembler directive is:               **
**              USING label,Rn                                       **
**                                                                   **
**    (Rn=)     Resets a base register tag.                          **
**              The equivalent assembler directive is:               **
**              DROP  Rn                                             **
**                                                                   **
**    (label)   Assigns an assembler label to the following code or  **
**              data. You may use it to name a CSECT for example.    **
**              The label cannot be R0 to R15, or A to F, H, P, S or **
**              X as those have special meanings as described above. **
**              The maximum length of a label assigned in this way   **
**              is 8 (for pragmatic reasons).                        **
**                                                                   **
**              For example:                                         **
**                                                                   **
**                  Data            Code                             **
**                  | Data label    | Code label                     **
**                  | |             | |                              **
**                  V V             V V                              **
**              07FE.(nSize)0000000A,(getCVT)58200010                **
**              code        data....         code....                **
**                                                                   **
**              The above would be disassembled as:                  **
**                                                                   **
**                        BR    R14                                  **
**              nSize     DC    X'0000000A'                          **
**              getCVT    L     R2,16                                **
**                                                                   **
**    (label=x) Assigns an assembler label to the location x in      **
**              hexadecimal. Use this if you know in advance the     **
**              offset of particular CSECTs. For example,            **
**                                                                   **
**              (MAIN=0,CSECTA=1C0,CSECTB=280)                       **
**                                                                   **
**              Any address constants encountered will then use the  **
**              specified name instead of a literal. For example,    **
**                                                                   **
**                        DC    A(448)                               **
**                                                                   **
**              will be generated as:                                **
**                                                                   **
**                        DC    A(CSECTA)         X'000001C0'        **
**                                                                   **
**              Some labels will be automatically created from the   **
**              External Symbol Dictionary of the AMBLIST output.    **
**                                                                   **
**    (.xxx)    Assigns an automatically named assembler label to    **
**              location xxx in hexadecimal. Use this if you know in **
**              advance which locations are referenced by machine    **
**              instructions so that the location can be represented **
**              by a label instead of a displacement off a register. **
**              DA will automatically insert one of these tags into  **
**              the hex input (AMBLIST output) for each location     **
**              referenced by a machine instruction that does not    **
**              already have a label defined for it. The inserted    **
**              tags will be taken into account the next time DA is  **
**              run.                                                 **
**                                                                   **
**    (.xxx=t)  Assigns an automatically named assembler label and   **
**              data type "t" to location xxx. The type can be any   **
**              of those described above for the (t) tag.            **
**                                                                   **
** 6. Issue DA to disassemble the AMBLIST output being edited.       **
**    - Spaces in the hex input are not significant (with one        **
**      exception explained below).                                  **
**    - The DA macro will disassemble AMBLIST output that has the    **
**      following format:                                            **
**                                                                   **
**              Everything after 3 consecutive spaces is ignored     **
**              (to accommodate a bug in versions of AMBLIST prior   **
**              to z/OS v2.3 - see APAR OA58170).                    **
**                                     |                             **
**                                     V                             **
**      xxxxxxxx xxxxxxxx ... xxxxxxxx   *aaaaa...aaaa*              **
**      |offset| |------hex data-----|   |---ignored----->           **
**                                                                   **
**      If AMBLIST output is not detected, then the input is         **
**      considered to be free form printable hex with no offset.     **
**      For example:                                                 **
**        18CF 5820C008 07FE 0000000A                                **
**                                                                   **
**    - The first 80 columns of the disassembly are valid assembler  **
**      statements and can be pasted into an FB80 file to be proc-   **
**      essed by the HLASM assembler. That is, you can paste all the **
**      disassembled lines and ignore the truncation warning.        **
**                                                                   **
**    - The remaining columns contain the following information:     **
**      location counter, instruction in hex, instruction format and **
**      the target operand length if any.                            **
**                                                                   **
** 7. Examine the "Undefined labels" report at the end of the dis-   **
**    assembly to help you identify where to insert CODE and DATA    **
**    action markers. Labels will be created at each location that   **
**    is referenced by a machine instruction or an address constant. **
**                                                                   **
** 8. Press F3 to quit editing the disassembly and return to the     **
**    AMBLIST output - where you can adjust the tags as described    **
**    above and try again.                                           **
**                                                                   **
** 9. Submit an assembly job to verify that the disassembled code    **
**    assembles cleanly.                                             **
**                                                                   **
**                                                                   **
** AUTHOR   - Andrew J. Armstrong <androidarmstrong@gmail.com>       **
**                                                                   **
END-JCL-COMMENTS
**                                                                   **
** HISTORY  - Date     By  Reason (most recent at the top please)    **
**            -------- --- ----------------------------------------- **
**            20201106 AA  Added System/370 Vector Facility opcodes. **
**            20201106 AA  Changed the TEST option output such that  **
**                         the opcode of each instruction is emitted **
**                         as a label (e.g. LR -> X18  LR).          **
**            20201104 AA  Added options: 360, 370, 390 and Z        **
**                         to disassemble System/360, System/370,    **
**                         System/390 and z/Architecture modules.    **
**                         z/Architecture is the default. 
**            20201027 AA  Added CA tag for ASCII text.              **
**            20200825 AA  Allowed hex to be supplied on the command **
**                         line.                                     **
**            20200605 AA  Major redesign for version 3.0.           **
**            20200525 AA  Implemented equates for Element Size and  **
**                         Floating Point Format in vector instruc-  **
**                         tions.                                    **
**            20200522 AA  Added ED and DD tags for Decimal Floating **
**                         Point (DFP) constants.                    **
**            20200511 AA  Major overhaul for version 2.0.           **
**                         Reworked the way that opcodes are deter-  **
**                         mined.                                    **
**                         Applied storage formats to instruction    **
**                         operands instead of treating them all as  **
**                         type X.                                   **
**            20200508 AA  Renamed the hint() function to t() to     **
**                         save space in the definition data.        **
**            20200507 AA  Added onSyntax trap to help identify the  **
**                         location of the error in the input hex.   **
**            20200506 AA  Tidied up address handling a little.      **
**                         Extended the '%' tag to handle parsing    **
**                         of variable length table entries. This is **
**                         useful for parsing error message tables.  **
**            20200505 AA  Miscellaneous bug fixes.                  **
**            20200501 AA  Emit A(label) if label is known.          **
**            20200501 AA  Added '(Rnn[+Rnn...]=Rnn) tag.            **
**            20200430 AA  Handle 31-bit addresses better.           **
**            20200429 AA  Switch to data parsing mode on % tag.     **
**            20200427 AA  Emit EQU for each undefined label.        **
**            20200424 AA  Improved '%' tag parsing.                 **
**            20200421 AA  Added '%' tag for printing formatted      **
**                         table entries.                            **
**            20200420 AA  Insert a blank line before each label     **
**                         more reliably.                            **
**            20200420 AA  TR/TRT now has fixed table length of 256. **
**            20200417 AA  Added ASM option to create assembly JCL.  **
**            20200407 AA  Sort by mnemonic in instruction stats.    **
**            20200407 AA  Insert only *new* undefined labels in the **
**                         original AMBLIST output.                  **
**            20200407 AA  Show the target of an EX or EXRL as a     **
**                         comment.                                  **
**            20200401 AA  Added '(.=xxx)' tag so that data labels   **
**                         can be applied in advance. Inserted one   **
**                         of these tags for each undefined label    **
**                         into the original AMBLIST output just     **
**                         before the first CSECT. DA will take      **
**                         these into account the next time it is    **
**                         run. This is equivalent to you manually   **
**                         inserting '.' action characters to create **
**                         labels that are referenced by machine     **
**                         instructions.                             **
**            20200316 AA  Fixed length hints for SS-a/b formats.    **
**            20200305 AA  Fixed handling of (label) tag that begins **
**                         with the letter R. For example (Return).  **
**            20200106 AA  Reworked operand length hints.            **
**            20191213 AA  Allowed dsn to be specified on DA command.**
**            20191212 AA  Added description to the "=>" tag.        **
**            20191209 AA  Displayed TODO count message.             **
**            20191206 AA  Added '/' action marker and updated doc.  **
**            20191205 AA  Fixed processing of tags after the end of **
**                         the hex input.                            **
**            20191204 AA  Allocated edit dataset based on the size  **
**                         of the input hex to be decoded.           **
**            20191203 AA  Fixed (Rn=xxx) tag processing.            **
**                         Added reference support for DC A(label).  **
**            20191203 AA  Fixed implicit operand lengths.           **
**            20191202 AA  Added length to undefined labels report.  **
**            20191125 AA  Detected undefined labels.                **
**            20191119 AA  Added support for S-type addresses. They  **
**                         are commonly used for patch areas.        **
**            20191113 AA  Set flag 'c' on all instructions that set **
**                         the condition code.                       **
**            20191031 AA  Added support for DSECTs (Rn=>name) tag   **
**                     AA  Added support for comments ('comment')    **
**                     AA  Added support for sections ("comment")    **
**                     AA  Fixed extended mnemonics                  **
**            20191023 AA  Fixed operand construction by adding      **
**                         "hard" blank translation                  **
**            20191014 AA  Added z/OS SVC descriptions               **
**            20191014 AA  Added multiple register USING support     **
**            20191008 AA  Added new z15 instructions                **
**            20190625 AA  Initial version                           **
**                                                                   **
**********************************************************************/
trace o
  signal on syntax name onSyntax
  parse arg xData'('sOptions
  xData = space(xData,0)
  if \isHex(xData)
  then do
    parse arg sDsn sOptions
    parse var sDsn sDsn'('sMod')'
    parse var sOptions '('sOptions
    sDsn = strip(sDSN,'BOTH',"'")
  end
  parse source . . me .
  address ISPEXEC 'CONTROL ERRORS RETURN'
  numeric digits 22
  g. = ''

  call getOptions sOptions
  call prolog
  address ISREDIT
  '(state) = USER_STATE'      /* Save current editor state           */

  if g.0OPTION.TEST = 1       /* Generate test assembler source?     */
  then do
    call generateTestBed
    call epilog
    exit 0
  end
 
  if g.0OPTION.ASM = 1        /* Generate assembly JCL?              */
  then do
    call generateAsm
    call epilog
    exit 0
  end

  call emit '@        START'
  call emit '*Label   Op    Operands                'left('Comment',59),
            'Location Hex          Format'

  /*
   *-------------------------------------------------------------------
   * 1. Extract the hex input
   *-------------------------------------------------------------------
  */

  if \isHex(xData)        /* If hex not supplied on the command line */
  then do
    xMeta = readMeta()          /* Determine the input format          */
    if g.0AMBLIST
    then do
      if g.0PGMOBJ
      then xData = readProgramObject()
      else xData = readModule()
    end
    else   xData = readRawHex()
  end

  /*
   *-------------------------------------------------------------------
   * 2. Disassemble hex
   *-------------------------------------------------------------------
  */
  g.0ISCODE = 1       /* Set hex parsing mode (1=Code, 0=Data) */
  do while xData <> '' /* Disassemble the extracted hex data */
    parse var xData xChunk '('sTags')' xData
    xChunk = space(xChunk,0)
    /* Decode any hex before the next tag */
    nPos = verify(xChunk,'.,/','MATCH') /* first action character */
    if nPos = 0       /* If no dots, commas or slashes found */
    then do
      call decodeChunk xChunk
    end
    else do while xChunk <> ''
      nPos = verify(xChunk,'.,/','MATCH') /* next dot, comma or slash */
      if nPos > 0
      then do /* decode up until the next action character */
        sAction = substr(xChunk,nPos,1) /* Get the action character */
        parse var xChunk xChunklet (sAction) xChunk
      end
      else do /* decode the complete chunk */
        xChunklet = xChunk
        sAction = ''
        xChunk = ''
      end
      if xChunklet <> ''
      then call decodeChunk xChunklet
      select
        when sAction = ',' then do /* If we are switching to code mode */
          g.0ISCODE = 1            /* Decode subsequent hex as code    */
          g.0TYPE = ''             /* Reset data type to automatic     */
        end
        when sAction = '.' then do
          g.0ISCODE = 0            /* Decode subsequent hex as data    */
                                   /* Using the existing data type     */
        end
        when sAction = '/' then do
          g.0ISCODE = 0            /* Decode subsequent hex as data    */
          g.0TYPE = ''             /* Reset data type to automatic     */
          g.0FIELD.0 = 0           /* Reset table entry generation     */
        end
        otherwise nop              /* Use existing mode and data type  */
      end
    end
    /* Now process the tag, if any */
    call handleTags sTags
  end

  /* The following is a hack to ensure that any tags or action characters
     appended to the very end of the hex input data are actually processed  */
  if pos(sAction,'.,/') > 0 & isReferenced(g.0XLOC) /* If trailing action   */
  then call saveStmt 'DS','0X'    /* Emit a label and any directives        */
  else call save ''               /* Emit only directives for this location */
  call nextLoc +1 /* Prevent repeating any directives on the last statement */

  if g.0DIAG   /* If a DIAGNOSE instruction was encountered */
  then do      /* Emit a DIAG macro to avoid assembly error */
    call emit '         MACRO'
    call emit '&label   DIAG  &O1,&O2'
    call emit '         DS    0h'
    call emit "&label   DC    X'83',AL1(&O1*16),S(&O2.)"
    call emit '         MEND'
  end

  /*
   *-------------------------------------------------------------------
   * 3. Apply labels to all referenced storage locations
   *-------------------------------------------------------------------
  */
  do n = 1 to g.0LINE
    parse var g.0STMT.n sOp sOperand sDesc 100 bIsCode +1 102 xLoc8 +8 .
    if xLoc8 <> '' /* Only interested in code and data */
    then do
      xLoc = stripx(xLoc8)
      bIsReferenced = isReferenced(xLoc)
      if bIsReferenced
      then do
        call emit ''          /* Then insert a blank line before it */
        sLabel = getLabel(xLoc)
        nLoc = x2d(xLoc)
        g.0ASS.nLoc = 1       /* Indicate present in disassembly */
      end
      else sLabel = ''
      /* g.0CLENG.xLoc is the longest length actually used in an instruction
         that references this location. If it is longer than the data length
         assigned to this location then a 'DC 0XLnn' directive will be
         inserted to cover the entire field referenced by the instruction.
      */
      select
        when sOp = 'DC' &,       /* A constant, and...                     */
             g.0CLENG.xLoc <> '' /* An instruction specified its length    */
        then do
          if pos('(',sOperand) > 0
          then parse var sOperand sType'('sValue')'   /* A() style syntax  */
          else parse var sOperand sType"'"sValue"'"   /* X'' style syntax  */
          parse var sType sType'L'nLen
          nPos = verify(nLen,'0123456789','NOMATCH')
          if nPos > 0                   /* If a non-numeric is present     */
          then nLen = left(nLen,nPos-1) /* Keep only length digits         */
          if nLen = ''                  /* If length modifier is absent    */
          then nLen = g.0MAXLEN.sType   /* Use default length for this type*/
          if g.0CLENG.xLoc \= nLen
          then do
            /* Use the label from the existing statement */
            sLocType = g.0CTYPE.xLoc
            if sLocType = '' then sLocType = 'X'
            call emitStmt sLabel,'DC    0'tl(sLocType,g.0CLENG.xLoc)
            call emitStmt       ,substr(g.0STMT.n,10)
          end
          else do
            call emitStmt sLabel,substr(g.0STMT.n,10)
          end
        end
        when inSet(sOp,'EX EXRL') then do /* An Execute instruction */
                                 /* Show the execute target in the comment */
          parse var sOperand sReg','sExLabel
          xLocInst = getLocation(sExLabel)
          nEx = g.0STMT#.xLocInst
          parse var g.0STMT.nEx sExOp sExOperand .
          sStmt = overlay(strip(sDesc) sExOp sExOperand,g.0STMT.n,40)
          call emitStmt sLabel,substr(sStmt,10)
        end
        when inSet(sOp,'BALR BASSM BASR BAL BAS BAKR PC SVC') then do
          call emitStmt sLabel,substr(g.0STMT.n,10)
          call emit ''          /* Insert a blank line after */
        end
        otherwise do
          call emitStmt sLabel,substr(g.0STMT.n,10)
        end
      end
    end
    else call emit g.0STMT.n
  end
  nHWM = n /* High Water Mark */

  /*
   *-------------------------------------------------------------------
   * 4. Save all non-addressable statements
   *-------------------------------------------------------------------
  */

  call saveRegisterEquates

  call saveDSECTs

  if g.0OPTION.STAT then call saveStatistics

  /*
   *-------------------------------------------------------------------
   * 5. Process undefined labels
   *-------------------------------------------------------------------
  */

  nUndefinedLabels = saveUndefinedLabels()

  call save '         END'

  do n = nHWM to g.0LINE
    call emit g.0STMT.n
  end

  /*
   *-------------------------------------------------------------------
   * Termination
   *-------------------------------------------------------------------
  */

  say 'DIS0009I Generated' g.0LINE 'statements ('g.0INST 'instructions)'
  if g.0TODO > 0
  then say 'DIS0010W There are' g.0TODO 'lines marked: TODO (not code)'
  if nUndefinedLabels > 0
  then say 'DIS0011W There are' nUndefinedLabels 'references to undefined',
           'labels (see end of listing)'
  if g.0NEWDOTS > 0
  then say 'DIS0013I Rerun DA to process' g.0NEWDOTS 'new references'
  else say 'DIS0014I DA processing complete'

  'USER_STATE = (state)'      /* Restore editor state                */
  call epilog
  /* Insert tags for any undefined labels before the first CSECT */
  if g.0NEWDOTS > 0
  then do
    do i = sorted.0 to 1 by -1 /* Reverse order so they appear in order! */
      n = sorted.i
      nLoc = g.0REFLOC.n    /* A referenced storage location */
      xLoc = d2x(nLoc)
      if g.0ASS.nLoc = '',  /* Label not in disassembly listing */
       & g.0DOTS.xLoc = ''  /* Not already in the input (.xxx) tags */
      then do
        sType = g.0CTYPE.xLoc
        if sType = ''
        then 'LINE_AFTER' g.0FIRSTCSECT '= "' g.0TAGPREFIX '(.'xLoc')"'
        else 'LINE_AFTER' g.0FIRSTCSECT '= "' g.0TAGPREFIX '(.'xLoc'='sType')"'
      end
    end
  end
return 1

saveStatistics: procedure expose g.
  call saveCommentBlock 'Statistics'
  call save '* Instruction format frequency ('g.0FC.0 'formats used)'
  call save '*'
  call save '*   Format     Count Mnemonics'
  call save '*   ------     ----- ---------'
  call sortStem 'g.0FC.',0
  do i = 1 to sorted.0
    n = sorted.i
    sFormat = g.0FN.n
    sMnemonics = sortWords(g.0ML.sFormat)
    if length(sMnemonics) <= 50
    then call save '*   'left(g.0FN.n,6) right(g.0FC.n,9) sMnemonics
    else do
      sForm = sFormat
      nFreq = g.0FC.n
      do while length(sMnemonics) > 50
        nPos = lastpos(' ',sMnemonics,50)
        if nPos = 0
        then do
          sChunk = sMnemonics
          sMnemonics = ''
        end
        else parse var sMnemonics sChunk +(nPos) sMnemonics
        call save '*   'left(sForm,6) right(nFreq,9) sChunk
        sForm = ''
        nFreq = ''
      end
      if sMnemonics \= ''
      then call save '*   'left(sForm,6) right(nFreq,9) sMnemonics
    end
  end
  call save '*'
  call save '* Instruction mnemonic frequency ('g.0MC.0 'mnemonics used)'
  call save '*'
  call save '*   Mnemonic   Count Format Description'
  call save '*   --------   ----- ------ -----------'
  call sortStem 'g.0MC.',0
  do i = 1 to g.0MC.0
    n = sorted.i
    sMnemonic = g.0MN.n
    call save '*   'left(g.0MN.n,6) right(g.0MC.n,9),
                      left(g.0MF.n,6) g.0DESC.sMnemonic
  end
return

onSyntax:
  sSourceLine = strip(sourceline(sigl))
  say 'DIS0099I' errortext(rc) 'at line' sigl':' sSourceLine
  parse upper var sSourceLine sInst . . sExpr
  if sInst = 'INTERPRET'
  then say 'DIS0100E Invalid input at location' g.0XLOC8': "'value(sExpr)'"'
  else say 'DIS0101E Invalid input at location' g.0XLOC8
return ''

readMeta: procedure expose g.
  /* Determine whether we are scanning AMBLIST output  */
  nRow = seek('*****  M O D U L E   S U M M A R Y  *****','FIRST')
  g.0AMBLIST = (nRow <> 0)
  /* Determine whether we are scanning a Program Object
     listing or a traditional module listing and then extract
     the list of CSECT names and their locations. This will be
     used to assign useful names to the assembly listing.
     If no names are extracted the assembly listing will still
     be produced, but without useful names assigned.
  */
  nRow = seek('21 PGM OBJ','FIRST')
  g.0PGMOBJ = (nRow <> 0)
  if g.0PGMOBJ
  then do
  /*
  A sample Program Object listing is as follows:
1                             ** NUMERICAL MAP OF PROGRAM OBJECT PLITST

0-------------------------------------------------------------------------------
0RESIDENT CLASS:           B_TEXT
0      CLAS LOC   ELEM LOC    LENGTH  TYPE  RMODE    ALIGNMENT             NAME
0        0                        7C   ED      31    DOUBLE WORD           CEEST
        80                       1B8   ED      31    DOUBLE WORD           **WOR
             C8         48             LD                                    WOR
       238                        28   ED      31    DOUBLE WORD           **WOR
       260                         C   ED      31    DOUBLE WORD           CEEMA
         .                         .   .       .     .                     .
         .                         .   .       .     .                     .
         .                         .   .       .     .                     .
0      CLASS LENGTH             175B
0-------------------------------------------------------------------------------
  */
    nRow = seek('NUMERICAL MAP OF PROGRAM OBJECT','FIRST')
    if nRow \= 0
    then do
      xLoc = ''
      '(nRow,nCol) = CURSOR'
      nRC = rc
      do i = nRow+3 while nRC = 0 & left(xLoc,8) <> '--------'
        '(sLine) = LINE' i
        nRC = rc
        parse var sLine 2 xLoc    . sType . 70 sName .
        if sType = 'ED'
        then do
          call attachSection xLoc,sName
          sName = translate(sName,'##','@*')
          call refLabel sName,xLoc
        end
      end
    end
  end
  else do
  /*
  A sample traditional module listing is as follows:
0RECORD# 1     TYPE 20 - CESD     ESDID 1                      ESD SIZE 48
0               CESD#    SYMBOL    TYPE     ADDRESS     R/R/A    ID/LENGTH(DEC)
                   1    IEFUTL    00(SD)     000000      0E            992
                   2    IEFUTLG   00(SD)     0003E0      06           3832
                   3    SMFCOM    00(SD)     0012D8      06           4256
  */
    nRow = seek('TYPE 20 - CESD','FIRST')
    do while nRow \= 0
      xLoc = ''
      nRC = 0
      nCESD = ''
      do i = nRow+1 while nRC = 0 & nCESD <> 'RECORD#' /* CLASS LENGTH */
        '(sLine) = LINE' i
        nRC = rc
        parse var sLine 2 nCESD sName . '('sType')' xLoc .
        if sType = 'SD' | sType = 'LR'
        then do
          sName = translate(sName,'##','@*') /* @*xxxxxx --> ##xxxxxx */
          call attachSection xLoc,sName
          call refLabel sName,xLoc
        end
      end
      nRow = seek('TYPE 20 - CESD','NEXT')
    end
  end
return ''

readProgramObject: procedure expose g.
  /* Parse the output from AMBLIST */
  /* This is a rather unfriendly format to navigate:
          .
          .
          CONTROL SECTION: <csectname>             <-- BEGIN CSECT
          CONTROL SECTION: <csectname>
     ===== TEXT =====
     <hex for csectname>                           <-- HEX OF INTEREST
     ===== TEXT =====
     <hex for csectname>                           <-- HEX OF INTEREST
          CONTROL SECTION: <nextcsectname>         <-- END CSECT
          .
          .
  */
  xData = ''
  nTop = seek('CONTROL SECTION:','FIRST NX')
  nRow = nextCSECT()
  g.0FIRSTCSECT = nRow
  g.0TAGPREFIX = '00000000 '
  do while nRow \= 0 /* for each TEXT block found */
    bSeekingLoc = 1
    do i = nRow+1 to nEnd-1
      '(sLine) = LINE' i
      '(sStatus) = XSTATUS' i
      if sStatus = 'NX' /* If this line is not excluded */
      then do
        parse var sLine 2 xLoc +8 sLine /* Ignore carriage control */
        xLoc = strip(xLoc)
        sLine = strip(sLine)
        parse var sLine sLine '*'   /* Discard dump on right */
        parse var sLine sLine '   ' /* ...or anything after 3 spaces */
        if length(xLoc) = 8 & isHex(xLoc)
        then do
          if bSeekingLoc
          then do
            bSeekingLoc = 0
            xData = xData'(@'xLoc')' /* Indicate where following hex starts */
          end
          xData = xData || sLine /* Append hex and/or tags */
        end
      end
    end
    nRow = nextCSECT()
  end
return xData

nextCSECT: procedure expose nBeg nEnd sCSECT
  '(r,c) = CURSOR'
  'CURSOR =' r 1
  nBeg = seek('CONTROL SECTION:','NEXT NX')
  if nBeg > 0
  then do
    '(sLine) = LINE' nBeg
    parse var sLine 'CONTROL SECTION:' sCSECT .
     nBeg = seek('===== TEXT =====','NEXT')
    nLast = seek('CONTROL SECTION:  'sCSECT,'LAST')
     nEnd = seek('CONTROL SECTION:','NEXT')
    if nEnd = 0
    then nEnd = seek('END OF PROGRAM OBJECT LISTING')
  end
return nBeg

readModule: procedure expose g.
  /* Parse the output from AMBLIST */
  xData = ''
  nRow = seek('T E X T','FIRST NX')
  g.0FIRSTCSECT = nRow
  g.0TAGPREFIX = '000000   '
  nEnd = seek('******END OF LOAD MODULE LISTING')
  bSeekingLoc = 1
  if nRow \= 0
  then do i = nRow+1 to nEnd-1
    '(sLine) = LINE' i
    nRC = rc
    '(sStatus) = XSTATUS' i
    if sStatus = 'NX' /* If this line is not excluded */
    then do
      parse var sLine 2 xLoc sLine /* Ignore carriage control */
      sLine = strip(sLine)
      parse var sLine sLine '*'   /* Discard dump on right */
      parse var sLine sLine '   ' /* ...or anything after 3 spaces */
      xLoc = strip(xLoc)
      if length(xLoc) = 6 & isHex(xLoc)
      then do
        if bSeekingLoc
        then do
          bSeekingLoc = 0
          xData = xData'(@'xLoc')' /* Indicate where following hex starts */
        end
        xData = xData || sLine /* Append hex and/or tags */
      end
    end
  end
return xData

readRawHex: procedure expose g.
  xData = ''
  /* Parse raw hex with no location offsets */
  g.0FIRSTCSECT = 0
  g.0TAGPREFIX = ''
  '(sStatus) = XSTATUS 1'
  '(sLine) = LINE 1'
  do i = 2 while rc = 0
    if sStatus = 'NX'
    then do
      sLine = strip(sLine)
      parse var sLine sLine '*'   /* Discard dump on right */
      parse var sLine sLine '   ' /* ...or anything after 3 spaces */
      xData = xData || sLine
    end
    '(sStatus) = XSTATUS' i
    '(sLine) = LINE' i
  end
return xData

seek: procedure expose g.
  parse arg sString,sOptions
  'SEEK "'sString'"' sOptions
  '(nStrings,nLines) = SEEK_COUNTS'
  if nStrings > 0
  then '(nRow,nCol) = CURSOR' /* Line number on which string was found */
  else nRow = 0               /* Indicate string not found             */
return nRow

setLoc: procedure expose g.
  arg xLoc
  g.0LOC = x2d(xLoc)
  call nextLoc +0
return

nextLoc: procedure expose g.
  arg nIncrement
  g.0LOC = g.0LOC + nIncrement
  g.0XLOC = d2x(g.0LOC)
  g.0XLOC8 = right(g.0XLOC,8,0)
return

generateTestBed: procedure expose g.
   select 
    when g.0ARCH = '6' then do
      call emit '*PROCESS FLAG(8)'
      call emit '*'
      call emit '* System/360 Instructions'
      call emit '*'
    end
    when g.0ARCH = '7' then do
      call emit '*PROCESS FLAG(8),MACHINE(S370XA)'
      call emit '*'
      call emit '* System/370 Instructions'
      call emit '*'
    end
    when g.0ARCH = '9' then do 
      call emit '*PROCESS FLAG(8),MACHINE(S390E)'
      call emit '*'
      call emit '* System/390 Instructions'
      call emit '*'
    end
    when g.0ARCH = 'Z' then do
      call emit '*PROCESS FLAG(8),MACHINE(Z15)'
      call emit '*'
      call emit '* z/Architecture Instructions'
      call emit '*'
    end
    otherwise do
      call emit '*PROCESS FLAG(8)'
    end
  end
  /* Hack to workaround HLASM refusing to assemble DIAG/PGIN/PGOUT */
  call emit '         MACRO'
  call emit '         DIAG'
  call emit "         DC    X'83000000'"
  call emit '         MEND'
  if pos(g.0ARCH,'9Z') > 0 
  then do
    call emit '         MACRO'
    call emit '         PGIN'
    call emit "         DC    X'B22E0000'"
    call emit '         MEND'
    call emit '         MACRO'
    call emit '         PGOUT'
    call emit "         DC    X'B22F0000'"
    call emit '         MEND'
  end
  call emit '         START'
  call emit '         USING *,R0,R1'
  do i = 1 while sourceline(i) <> 'BEGIN-INSTRUCTION-DEFINITIONS'
  end
  do i = i+3 while sourceline(i) <> 'END-INSTRUCTION-DEFINITIONS'
    sLine = sourceline(i)
    parse var sLine sMnemonic xOpCode sFormat sFlag sArch sDesc '='sHint
    if pos(g.0ARCH,sArch) > 0 & left(sMnemonic,1) <> '*'
    then call genInst xOpCode,sMnemonic,sFormat,sDesc
  end
  call emit '*'
  call emit '* General purpose register equates'
  call emit '*'
  do i = 0 to 15
    call emit left('R'i,8) 'EQU   'i
  end
  select
    when g.0ARCH = '6' then nop
    when g.0ARCH = '7' then do
      call emit '*'
      call emit '* Vector register equates'
      call emit '*'
      do i = 0 to 15
        call emit left('V'i,8) 'EQU   'i
      end
    end
    otherwise do
      call emit '*'
      call emit '* Vector register equates'
      call emit '*'
      do i = 0 to 31
        call emit left('V'i,8) 'EQU   'i
      end
      call emit '*'
      call emit '* Vector element size equates'
      call emit '*'
      do i = 0 to 15
        x = d2x(i)
        sEquate = g.0VES.x
        if sEquate <> ''
        then do
          call emit left(sEquate,12) 'EQU   'i
        end
      end
      call emit '*'
      call emit '* Vector floating point format equates'
      call emit '*'
      do i = 0 to 15
        x = d2x(i)
        sEquate = g.0FPF.x
        if sEquate <> ''
        then do
          call emit left(sEquate,13) 'EQU   'i
        end
      end
    end
  end
  call emit '         END'
  call epilog
return

generateAsm: procedure expose g.
  '(dataset) = DATASET' /* Dataset currently being edited */
  '(lines) = LINENUM .ZLAST' /* Number of lines being edited */
  sJob = left(userid()'A',8)
  queue '//'sJob   "JOB ,'ASM',CLASS=U,MSGCLASS=T,NOTIFY=&SYSUID"
  queue '//ASM     EXEC PGM=ASMA90,'
  queue "//             PARM=('NOOBJECT,NODECK,LINECOUNT(0)')"
  queue '//SYSLIB    DD DISP=SHR,DSN=SYS1.MACLIB'
  queue '//          DD DISP=SHR,DSN=SYS1.MODGEN'
  queue '//SYSPRINT  DD SYSOUT=*,RECFM=V'
  queue '//SYSIN     DD *'
  do i = 1 to lines
    '(sLine) = LINE' i
    queue left(sLine,72)
  end
  queue '/*'
  call epilog
return

decodeChunk: procedure expose g.
  parse arg xChunk
  nPos = verify(xChunk,'0123456789ABCDEFabcdef','NOMATCH')
  select
    when length(xChunk)//2 = 1 then do /* If it is a runt hex string */
      call ignoreChunk xChunk,,
           'DIS0007E Ignored hex with odd length at' g.0XLOC8
      call nextLoc +length(xChunk)%2+1
    end
    when nPos = 0 then do /* Valid hex with an even number of digits */
      if g.0ISCODE
      then call decodeCode xChunk
      else call decodeData xChunk
    end
    otherwise do          /* Invalid hex digit found                  */
      if nPos//2 = 0       /* If the second nibble is the invalid one */
      then nPos = nPos - 1 /* Then point to the start of the byte     */
      sWindow = substr(xChunk,nPos,8)
      xOffset = d2x(g.0LOC+(nPos-1)/2,8)
      call ignoreChunk xChunk,,
           'DIS0006E Ignored invalid hex at' xOffset
      call nextLoc +length(xChunk)%2
    end
  end
return

ignoreChunk: procedure expose g.
  parse arg xChunk,sMessage
  say sMessage
  call saveComment '*' sMessage':'
  call saveComment '* Location    +0       +4       +8       +C'
  nLoc = g.0LOC
  do i = 1 to length(xChunk) by 32
    xChunklet = substr(xChunk,i,32)
    parse var xChunklet x1 +8 x2 +8 x3 +8 x4 +8
    call saveComment '*' d2x(nLoc,8) '  ' x1 x2 x3 x4,
                     '   *'xc(x1)xc(x2)xc(x3)xc(x4)'*'
    nLoc = nLoc + 16
  end
return

xc: procedure expose g.
  arg xData
  if isHex(xData)
  then return toPrintable(xData)
return '....'

toPrintable: procedure expose g.
  parse arg xData .
  sData = x2c(xData)
return translate(sData,g.0EBCDIC,g.0EBCDIC||xrange('00'x,'ff'x),'.')

handleTags: procedure expose g.
  parse arg sTags
  sTags = translate(sTags,g.0HARDBLANK,' ')
  sTags = translate(sTags,'',',')
  if sTags = ''
  then call handleTag
  else do i = 1 to words(sTags)
    call handleTag word(sTags,i)
  end
return

handleTag: procedure expose g.
  parse arg sTag1 +1 0 sTag
  sTag = translate(sTag,' ',g.0HARDBLANK) /* Soften hard blanks */
  if sTag1 = 'R'                       /* If it is a register tag       */
  then do 
    parse var sTag 'R'nn'='sLabel
    sRegisters = getRegisterList('R'nn) /* Will be null if no registers */
    nRegisters = words(sRegisters)
  end
  select
    when sTag = '',                           /* ()  ...reset data type */
      | inSet(sTag,'A B C D E F H P S X AD FD EH DH EB ED DB DD CA') then do
      g.0TYPE = sTag
      g.0ISCODE = 0            /* Decode subsequent hex as data    */
      g.0FIELD.0 = 0           /* Reset table entry generation     */
    end
    when sTag1 = '"' then do           /* "section" */
      sTag = strip(sTag,'BOTH','"')
      call attachSection g.0XLOC,sTag
    end
    when sTag1 = "'" then do           /* 'comment' */
      sTag = strip(sTag,'BOTH',"'")
      call attachComment g.0XLOC,sTag
    end
    when sTag1 = '%' then do           /* %AL4 2F 3H CL14 (for example) */
      parse var sTag '%'sTableEntry
      g.0ISCODE = 0            /* Decode subsequent hex as data    */
      g.0FIELD.0 = 0           /* Reset table entry generation     */
      do nToken = 1 to words(sTableEntry)
        sToken = word(sTableEntry,nToken)
        sToken = translate(sToken)     /* Convert to upper case */
        sVar = ''
        sExp = ''
        select
          when pos('=',sToken) > 0 then do  /* token=var */
            parse var sToken sToken'='sVar
          end
          when pos('$',sToken) > 0 then do  /* tokenLexpression */
            parse var sToken sToken'L'sExp
          end
          otherwise nop
        end
/*
        sToken  Meaning
        ------- ------------------------------------
                Reset table entry template
        A       Data type A with implicit length of 4
        AL3     Data type A with explicit length of 3
        2A      2 x data type A with implicit length of 4
        2AL1    2 x data type A with explicit length of 1
        2       Data type X (default) of length 2     (type not specified)
        2x3     2 x data type X (default) of length 3 (when x is invalid type)
        AL1=n   Parse 1 byte and assign it to variable $n
        CL$n+1  Parse $n+1 bytes of data type C
*/        
        nRep = ''
        sTyp = ''
        nLen = ''
        do nChar = 1 to length(sToken)
          c = substr(sToken,nChar,1)
          if pos(c,'0123456789') = 0 then leave
          nRep = nRep || c
        end
        do nChar = nChar to length(sToken)
          c = substr(sToken,nChar,1)
          if pos(c,'0123456789') > 0 then leave
          sTyp = sTyp || c
        end
        nLen = substr(sToken,nChar)
        if sTyp = '' & nLen = ''
        then do /* 3 --> XL3, not 3XL1 */
          nLen = nRep
          nRep = 1
        end
        sTyp = left(sTyp,1)
        if pos(sTyp,'ABCFHPSX') = 0 then sTyp = 'X'
        if nRep = '' then nRep = 1
        if nLen = '' then nLen = g.0LEN.sTyp
        n = g.0FIELD.0 + 1
        g.0FIELD.0 = n
        g.0FIELD.n = nRep sTyp nLen
        g.0FIELDVAR.n = sVar           /* Assign content of field to var */
        g.0FIELDEXP.n = sExp           /* Parse field of length 'expr' */
      end
    end
    when sTag1 = '@' then do           /* @addr */
      parse var sTag '@'xLoc
      if isHex(xLoc)
      then do
        call setLoc xLoc               /* Set the current location */
        xLoc = g.0XLOC                 /* Remove leading zeros */
        if g.0ORG.xLoc = ''
        then do
          g.0ORG.xLoc = 1              /* Prevent duplicate ORG statements */
          call attachDirective g.0XLOC,''
          call attachDirective g.0XLOC,'ORG   @+'||x(g.0XLOC8)
        end
      end
    end
    when sTag1 = 'R' & sRegisters <> '' then do  /* (Rnn[+Rmm...][=[label]]) */
      parse var sLabel sLabel"'"sDesc"'" /* Peel off the label description */
      sLabel = strip(sLabel)
      select
        when left(sLabel,1) = '>' then do /* Rnn[+Rmm...]=>dsect */
          /* USING dsect,Rnn[,Rmm...] */
          sLabel = substr(sLabel,2)    /* Extract DSECT name */
          if g.0DSECT.sLabel = ''      /* If this is a new DSECT */
          then do
            n = g.0DSECT.0             /* Get DSECT count */
            if n = '' then n = 0       /* If none so far the count = 0 */
            n = n + 1                  /* Increment DSECT count */
            g.0DSECT.n = sLabel        /* Add this DSECT name to the array */
            g.0DSECT.sLabel = n        /* Remember DSECT has been seen */
            g.0DSECT.0 = n             /* Remember DSECT count so far */
            g.0DDESC.n = sDesc         /* Remember DSECT description */
          end
          dLoc = 0                     /* Displacement of first base register */
          do i = 1 to nRegisters
            nn = word(sRegisters,i)
            x = d2x(nn)                /* Base register (0 to F) */
            g.0DBASE.x = sLabel        /* DSECT this base points to */
            g.0DLOCN.x = dLoc          /* Offset into DSECT of this base */
            dLoc = dLoc + 4096
          end
          call attachDirective g.0XLOC,'USING' sLabel','using(sRegisters),1
        end
        when pos('=',sTag) = 0 then do /* (Rnn[+Rmm...])           */
          /* USING *,Rnn[,Rmm...] */
          xLoc = g.0XLOC               /* Get current location */
          sLabel = getLabel(xLoc)      /* Get label from location if any */
          if sLabel = '' then sLabel = '*' /* If unnamed then use '*' */
          dLoc = x2d(xLoc)             /* Displacement of first base register */
          do i = 1 to nRegisters
            nn = word(sRegisters,i)
            x = d2x(nn)                /* Base register (0 to F) */
            g.0CBASE.x = d2x(dLoc)     /* Set base register to location */
            dLoc = dLoc + 4096
          end
          call attachDirective g.0XLOC,'USING' sLabel','using(sRegisters),1
          call refLabel label(xLoc),g.0XLOC /* Define and reference label */
        end
        when sLabel = '' then do       /* (Rnn[+Rmm...]=)          */
          /* DROP Rnn[,Rmm...] */
          sDrop = ''
          do i = 1 to nRegisters
            nn = word(sRegisters,i)
            x = d2x(nn)                /* Base register (0 to F) */
            g.0CBASE.x = ''
            g.0DBASE.x = ''
            sDrop = sDrop',R'nn
          end
          call attachDirective g.0XLOC,'DROP  'substr(sDrop,2),1
        end
        otherwise do                   /* (Rnn[+Rnn...]=label)     
                                       or (Rnn[+Rnn...]=offset)
                                       or (Rnn[+Rnn...]=Rnn)       */
          /* USING label,Rnn[,Rmm...] */
          nReg = getRegisterList(sLabel) /* Is nn when sLabel is Rnn */
          select
            when isHex(sLabel) then do   /* (Rnn[+Rnn...]=offset)    */
              xLoc = stripx(sLabel)      /* Remove leading zeros     */
              if getLabel(xLoc) = ''     /* If location has no label */
              then call refLabel label(xLoc),xLoc
              sLabel = getLabel(xLoc)    /* Get label from location  */
              dLoc = x2d(xLoc)
            end
            when isNum(nReg) then do     /* (Rnn[+Rnn...]=Rnn) */
              x = d2x(nReg)              /* Base register (0 to F) */
              xLoc = g.0CBASE.x          /* Get location from base register */
              sLabel = getLabel(xLoc)    /* ...as a label */
              dLoc = x2d(xLoc)           /* ...as a decimal */
              g.0CBASE.x = ''            /* Drop =Rnn to avoid overlaps */
              g.0DBASE.x = ''
              call attachDirective g.0XLOC,'DROP  R'nReg,1
            end
            otherwise do
              xLoc = getLocation(sLabel) /* Get location from label */
              dLoc = x2d(xLoc)
            end
          end
          do i = 1 to nRegisters
            nn = word(sRegisters,i)
            x = d2x(nn)                /* Base register (0 to F) */
            g.0CBASE.x = d2x(dLoc)     /* Set base register to location */
            dLoc = dLoc + 4096
          end
          call attachDirective g.0XLOC,'USING' sLabel','using(sRegisters),1
          call refLabel sLabel,xLoc    /* Define and reference label */
        end
      end
    end
    when sTag1 = '.' then do        /* (.offset[=type]) */
      parse var sTag '.'xLoc'='sType .
      if isHex(xLoc)
      then call addDot xLoc sType
      else say 'DIS0012W Invalid tag ('sTag') ignored at offset' g.0XLOC8
    end
    otherwise do                    /* (label[=offset]) */
      parse var sTag sLabel'='xLoc .
      if isHex(xLoc)                /* If hex is valid                     */
      then xLoc = stripx(xLoc)      /* Then strip leading zeros            */
      else xLoc = g.0XLOC           /* Else use the current location       */
      call setLabel sLabel,xLoc     /* Set user-defined label              */
      call refLabel sLabel,xLoc     /* Refer to it so it is not pruned     */
    end
  end
return

stripx: procedure /* Strip leading zeros from a hex string */
  parse arg xLoc
  xLoc = strip(xLoc,'LEADING',0)
  if xLoc = '' then return 0
return xLoc

addDot: procedure expose g.
  parse arg xLoc sType .
  xLoc = stripx(xLoc)  /* normalise hex */
  if g.0DOTS.xLoc = '' /* If (.xxx) tag is not a duplicate in input file */
  then do
    n = g.0DOT.0 + 1
    g.0DOTS.xLoc = n
    g.0DOT.0 = n
    g.0DOT.n = x2d(xLoc)
    g.0DOTSORT = 1 /* Indicate sort is needed */
    if sType <> ''
    then do
      g.0CTYPE.xLoc = sType           /* Set pre-defined field type */
      g.0CLENG.xLoc = g.0MAXLEN.sType /* Set pre-defined field length */
    end
  end
return

using: procedure
  parse arg sRegisters
  sUsing = 'R'word(sRegisters,1) /* Rnn */
  do i = 2 to words(sRegisters)
    nn = word(sRegisters,i)
    sUsing = sUsing',R'nn        /* Rnn,Rmm,... */
  end
return sUsing

getRegisterList: procedure
  /* Convert a base register list of the form 'Rxx+Ryy+...'
     to just the numeric register numbers 'xx yy ...'
     else return an empty string
  */
  parse arg sRegisters
  sRegisters = translate(sRegisters,' ','+')
  sRegisterList = ''
  do i = 1 to words(sRegisters)
    sRegister = word(sRegisters,i)
    parse var sRegister 'R'nn
    if isNum(nn) & nn >= 0 & nn <= 15
    then sRegisterList = sRegisterList nn
    else return ''
  end
return strip(sRegisterList)

attachDirective: procedure expose g. /* Attach a directive to a location */
  parse arg xLoc,sDirective,bUnderline
  if g.0DIRECTIVE.xLoc.sDirective = '' /* Already added this directive? */
  then do
    g.0DIRECTIVE.xLoc.sDirective = 1   /* Prevent future duplicates */
    call attachLine xLoc,'         'sDirective
    if bUnderline <> ''
    then call attachLine xLoc,'*        'copies('-',length(sDirective))
  end
return

attachSection: procedure expose g. /* Attach a section comment to a location */
  parse arg xLoc,sComment
  call attachLine xLoc,''
  call attachLine xLoc,'*'copies('*',69)'*'
  call attachLine xLoc,'*'copies(' ',69)'*'
  call attachLine xLoc,'*' center(sComment,67) '*'
  call attachLine xLoc,'*'copies(' ',69)'*'
  call attachLine xLoc,'*'copies('*',69)'*'
return

attachComment: procedure expose g. /* Attach a comment to a location */
  parse arg xLoc,sComment
  call attachLine xLoc,''
  call attachLine xLoc,'*'copies('-',69)'*'
  call attachLine xLoc,'*' left(sComment,69)
  call attachLine xLoc,'*'copies('-',69)'*'
  call attachLine xLoc,''
return

attachLine: procedure expose g. /* Attach text to a location */
  parse arg xLoc,sLine
  xLoc = strip(xLoc,'LEADING',0)
  if xLoc = '' then xLoc = 0
  n = g.0DIRECTIVE.xLoc.0          /* Get directive count for this loc */
  if n = ''
  then n = 1
  else n = n + 1
  g.0DIRECTIVE.xLoc.n = sLine
  g.0DIRECTIVE.xLoc.0 = n
return

saveRegisterEquates:
  call saveBanner 'R E G I S T E R S'
  call saveCommentBlock 'General purpose register equates'
  do i = 0 to 15
    call save left('R'i,8) 'EQU   'i
  end
  if g.0VECTOR
  then do
    call saveCommentBlock 'Vector register equates'
    do i = 0 to 31
      call save left('V'i,8) 'EQU   'i
    end
    call saveCommentBlock 'Vector element size equates'
    do i = 0 to 15
      x = d2x(i)
      sEquate = g.0VES.x
      if sEquate <> ''
      then do
        call save left(sEquate,12) 'EQU   'i
      end
    end
    call saveCommentBlock 'Vector floating point format equates'
    do i = 0 to 15
      x = d2x(i)
      sEquate = g.0FPF.x
      if sEquate <> ''
      then do
        call save left(sEquate,13) 'EQU   'i
      end
    end
  end
return

saveDSECTs:
  if g.0DSECT.0 > 0
  then do
    call saveBanner 'D S E C T S'
    do i = 1 to g.0DSECT.0
      sDsectName = g.0DSECT.i
      call saveCommentBlock g.0DDESC.i
      call save asm(sDsectName,'DSECT')
      call sortStem 'g.0DDISP.'sDsectName'.' /* Sort by displacement */
      nLastDisp = 0
      do j1 = 1 to sorted.0
        j2 = j1 + 1
        n1 = sorted.j1
        n2 = sorted.j2
        sLabel  = g.0DSECT.sDsectName.n1
        sType   = g.0DTYPE.sLabel
        if sType = ''
        then sType = 'X'
        nLength = g.0DLENG.sLabel
        d1      = g.0DDISP.sDsectName.n1
        d2      = g.0DDISP.sDsectName.n2
        if d2 = '' then d2 = d1 + nLength
        nGap = d1 - nLastDisp
        if nGap > 0
        then call save asm(,'DS XL'nGap)
        if nLength = 0
        then sFormat = '0'sType
        else do
          if nLength <= (d2 - d1)
          then do
            sFormat = dtl(sType,nLength)
            d1 = d1 + nLength
          end
          else do
            if sType = 'X'
            then sFormat = '0XL'nLength
            else sFormat = '0XL'nLength dtl(sType,nLength)
          end
        end
        call save asm(sLabel,'DS' sFormat)
        nLastDisp = d1
      end
    end
  end
return

dtl: procedure expose g. /* Duplication Type Length (e.g. 2AL4) */
  arg sType,nLen                            /* sType nLen nMax             */
  if nLen = 0 then return '0'sType          /*   A     0    4  --> 0A      */
  nMax = g.0MAXLEN.sType
  if nMax = '' then return sType'L'nLen     /*   C    23       --> CL23    */
  if nLen = nMax then return sType          /*   A     4    4  --> A       */
  if nLen < nMax then return sType'L'nLen   /*   A     3    4  --> AL3     */
  nRem = nLen // nMax
  if nRem > 0 then return 'XL'nLen          /*   A     7    4  --> XL7     */
  nDup = nLen % nMax
return nDup || sType                        /*   A     8    4  --> 2A      */

tl: procedure expose g. /* Type Length (e.g. AL4) */
  arg sType,nLen                            /* sType nLen nMax             */
  if nLen = 0 then return sType             /*   A     0    4  --> A       */
  nMax = g.0MAXLEN.sType
  if nMax = '' then return sType'L'nLen     /*   C    23       --> CL23    */
  if nLen = nMax then return sType          /*   A     4    4  --> A       */
  if nLen < nMax then return sType'L'nLen   /*   A     3    4  --> AL3     */
  nRem = nLen // nMax
  if nRem > 0 then return 'XL'nLen          /*   A     7    4  --> XL7     */
return sType                                /*   A     8    4  --> A       */

asm: procedure
  arg sLabel,sOp sOperands sComment
  nLabel = max(length(sLabel),8)
  nOp    = max(length(sOp),5)
  nOperands = max(length(sOperands),23)
  sStmt = left(sLabel,nLabel) left(sOp,nOp) left(sOperands,nOperands) sComment
return left(sStmt,71)

saveUndefinedLabels:
  call sortStem 'g.0REFLOC.'
  /* First, detect if there are any undefined labels */
  g.0NEWDOTS = 0
  nUndefinedLabels = 0
  do i = 1 to sorted.0
    n = sorted.i
    nLoc = g.0REFLOC.n      /* A referenced storage location */
    if g.0ASS.nLoc = ''     /* Label not in disassembly listing */
    then do
      nUndefinedLabels = nUndefinedLabels + 1
      xLoc = d2x(nLoc)
      if g.0DOTS.xLoc = ''  /* Not already in the input (.xxx) tags */
      then g.0NEWDOTS = g.0NEWDOTS + 1
    end
  end
  if nUndefinedLabels > 0
  then do
    call saveCommentBlock 'Undefined labels'
    call save '* Label    At       Length Ref from By instruction'
    call save '* -------- -------- ------ --------' copies('-',35)
    g.0EQU.0 = 0
    do i = 1 to sorted.0
      n = sorted.i
      nLoc = g.0REFLOC.n
      if g.0ASS.nLoc = ''
      then do
        xLoc = d2x(nLoc)
        sLabel = left(getLabel(xLoc),8)
        xLocRef = g.0REF.nLoc
        n = g.0STMT#.xLocRef
        parse var g.0STMT.n sInst sOperands .
        call save '*' sLabel left(xLoc,8),
                  right(g.0CLENG.xLoc,6) right(xLocRef,8),
                  left(sInst,6) sOperands
        n = g.0EQU.0 + 1
        g.0EQU.0 = n
        g.0EQU.n = sLabel "EQU   @+X'"xLoc"'," ||,
                   g.0CLENG.xLoc",C'X',X'DEC0DE'"
      end
    end
    if g.0EQU.0 > 0
    then do
      call saveCommentBlock 'Equates for undefined labels'
      do i = 1 to g.0EQU.0
        call save g.0EQU.i
      end
    end
  end
return nUndefinedLabels

saveBanner:
  parse arg sComment
  call save ''
  call save copies('*',71)
  call save '*'copies(' ',69)'*'
  call save '*' centre(sComment,67) '*'
  call save '*'copies(' ',69)'*'
  call save copies('*',71)
  call save ''
return

saveCommentBlock:
  parse arg sComment
  call save ''
  call save '*'copies('-',69)'*'
  call save '*' left(sComment,69)
  call save '*'copies('-',69)'*'
  call save ''
return

save: procedure expose g.
  parse arg sStmt
  xLoc = g.0XLOC
  n = getNextStmtNumber()
  nDirectives = g.0DIRECTIVE.xLoc.0
  if isNum(nDirectives) /* If there are any directives for */
  then do /* this location, then include them before the statement */
    do i = 1 to nDirectives
      g.0STMT.n = g.0DIRECTIVE.xLoc.i
      n = getNextStmtNumber()
    end
  end
  g.0STMT#.xLoc = n
  g.0STMT.n = sStmt
  g.0LOC.n = xLoc
return

saveComment: procedure expose g.
  parse arg sStmt
  n = getNextStmtNumber()
  g.0STMT.n = sStmt
return

getNextStmtNumber: procedure expose g.
  n = g.0LINE + 1
  g.0DELTA = g.0DELTA + 1
  if g.0DELTA >= 1000
  then do
    say 'DIS0008I Generated' n 'statements'
    g.0DELTA = 0
  end
  g.0LINE = n
return n

emitStmt: procedure expose g.
  parse arg sLabel,sStmt
  if length(sLabel) > 8
  then do
    call emit sLabel    'ds 0x'
    call emit '        ' sStmt
  end
  else call emit left(sLabel,8) sStmt
return

emit: procedure expose g.
  parse arg sLine 1 s71 +71 sRest 100 sInfo
  if sLine = ''
  then do
    if g.0BLANK = 1 then return /* Suppress multiple blank lines */
    g.0BLANK = 1
  end
  else g.0BLANK = 0
  if sRest = ''  /* if nothing to continue onto the next line */
  then queue sLine
  else do
    queue s71'-                           'sInfo
    queue left('',15)sRest
  end
return


decodeData: procedure expose g.
  arg xData
  if length(xData) = 0 then return
  g.0SLICE.0 = 1
  g.0SLICE.1 = x2c(xData)
  nSlices = getSlices(g.0LOC,g.0LOC+length(g.0SLICE.1)-1)
  do nSlice = 1 to g.0SLICE.0
    sData = g.0SLICE.nSlice
    do until length(sData) = 0
      if nSlices > 1            /* i.e. |----|--|------|...               */
      then do                   /*       1   |2  3                        */
        xLoc = d2x(g.0LOC)      /*           |                            */
        sLabel = getLabel(xLoc) /*           x (here, and onward...)      */
        if sLabel = ''
        then call setLabel label(xLoc),xLoc     /* Assign a label to location */
      end
      if g.0FIELD.0 > 0        /* If parsing fields in a table row       */
      then do                  /* Emit each field in this table row      */
        sSaveType = g.0TYPE
        /* For each field in this table row... */
        do nField = 1 to g.0FIELD.0 while length(sData) <> 0
          parse var g.0FIELD.nField nRep sTyp nLen
          g.0TYPE = sTyp                  /* Set the field type */
          select
            when g.0FIELDVAR.nField \= '' then do /* Assign field to variable */
              parse var sData sField +(nLen) sData /* Get field*/
              s = decodeDataField(sField) /* Decode the field as g.0TYPE */
              interpret '$'g.0FIELDVAR.nField '=' c2d(sField)
            end
            when g.0FIELDEXP.nField \= '' then do /* Compute field length */
              interpret 'nLen =' g.0FIELDEXP.nField
              parse var sData sField +(nLen) sData /* Get variable field*/
              s = decodeDataField(sField) /* Decode the field as g.0TYPE */
            end
            otherwise do
              /* For each repetition of this data type... */
              do nRep while length(sData) <> 0
                parse var sData sField +(nLen) sData /* Get field */
                s = decodeDataField(sField) /* Decode the field as g.0TYPE */
              end
            end
          end
        end
        g.0TYPE = sSaveType
      end
      else sData = decodeDataField(sData) /* Decode the data as g.0TYPE */
    end
  end
return

getSlices: procedure expose g.
  arg nLo,nHi
  if g.0DOTSORT = 1
  then do
    call sortStem 'g.0DOT.'
    do i = 1 to sorted.0
      n = sorted.i
      temp.i = g.0DOT.n
    end
    do i = 1 to g.0DOT.0
      g.0DOT.i = temp.i
    end
    drop temp.
    g.0DOTSORT = 0
  end
  sData = g.0SLICE.1
  j = 0
  nAbsLo = nLo
  nAbsHi = nHi
  nRelLo = 1
  do i = 1 to g.0DOT.0 while g.0DOT.i <= nLo
    /* Ignore dots before this window */
  end
  do i = i to g.0DOT.0 while g.0DOT.i <= nHi
    /* Process any dots inside the window */
    nAbsHi = g.0DOT.i
    /* Example:  List of (.=xxx) tags:
                    .
                    .
                 g.0DOT.6=2222
                 g.0DOT.7=4300
                 g.0DOT.8=4304
                 g.0DOT.9=5555
                    .
                    .
                         4300              4316
                          nLo              nHi
                            |              |
                         4300   4304       |
                        nAbsLo  nAbsHi     |
                            |   |          |
    INPUT:       g.0SLICE.1=xxxxyyyyyyyyyyyy    len=17
                            |   |
                        nRelLo  nRelHi
                            1   5
                            <-->  nLen = 4
    OUTPUT:      g.0SLICE.0=2                   Number of slices
                 g.0SLICE.1=xxxx                len=4
                 g.0SLICE.2=yyyyyyyyyyyyy       len=13
    */
    nLen = nAbsHi - nAbsLo
    if nLen > 0
    then do
      nRelLo = nAbsLo-nLo+1
      j = j + 1
      g.0SLICE.0 = j
      g.0SLICE.j = substr(sData,nRelLo,nLen)
      nAbsLo = nAbsHi
    end
  end
  /* Process the last (or only) part of this window */
  nLen = nHi - nAbsLo + 1
  if nLen > 0
  then do
    nRelLo = nAbsLo-nLo+1
    j = j + 1
    g.0SLICE.0 = j
    g.0SLICE.j = substr(sData,nRelLo,nLen)
    nAbsLo = nAbsHi
  end
return g.0SLICE.0

decodeDataField: procedure expose g.
  parse arg sData
  xLoc = g.0XLOC
  if g.0TYPE = ''            /* If no explicit tag */
  then sType = g.0CTYPE.xLoc /* Then use type for this location if any */
  else sType = g.0TYPE
  select
    when sType = 'A'  then sData = doAddress(sData)
    when sType = 'B'  then sData = doBit(sData)
    when sType = 'C'  then sData = doText(sData)
    when sType = 'F'  then sData = doFullword(sData)
    when sType = 'H'  then sData = doHalfword(sData)
    when sType = 'P'  then sData = doPacked(sData)
    when sType = 'S'  then sData = doSCON(sData)
    when sType = 'X'  then sData = doHex(sData)
    when sType = 'E'  then sData = doShortHexFloat(sData)
    when sType = 'D'  then sData = doLongHexFloat(sData)
    when sType = 'AD' then sData = doAddress8(sData)
    when sType = 'FD' then sData = doFullword8(sData)
    when sType = 'EH' then sData = doShortHexFloat(sData)
    when sType = 'DH' then sData = doLongHexFloat(sData)
    when sType = 'EB' then sData = doShortBinFloat(sData)
    when sType = 'DB' then sData = doLongBinFloat(sData)
    when sType = 'ED' then sData = doShortDecFloat(sData)
    when sType = 'DD' then sData = doLongDecFloat(sData)
    when sType = 'CA' then sData = doASCII(sData)
    otherwise              sData = doUnspecified(sData)
  end
return sData

doAddress: procedure expose g.
  if isFullwordBoundary()
  then do
    parse arg sField +4 sData
    nField = length(sField)        /* 1 to 4 bytes on fullword boundary */
    xField = c2x(sField)
    select
      when nField = 4 then do    /* Generate A(label) or AL4(label)     */
        xLoc = xField
        sLoc = right(x2c(xLoc),4,'00'x)
        b31  = bitand(sLoc,'80000000'x) = '80000000'x
        sLoc = bitand(sLoc,'7FFFFFFF'x)
        xLoc = stripx(c2x(sLoc)) /* Remove leading zeros */
        sLabel = refLabel(getLabel(xLoc),xLoc)
        if b31 
        then sLabel = sLabel"+X'80000000'"
        call saveStmt 'DC',a(sLabel),x(xField),g.0XLOC8 xField
      end
      when nField = 3 then do   /* Generate AL3(label)                 */
        xLoc = stripx(xField)   /* Remove leading zeros */
        sLabel = refLabel(getLabel(xLoc),xLoc)
        call saveStmt 'DC',al(sLabel,3),x(xField),g.0XLOC8 xField
      end
      otherwise do              /* Generate ALn(decimal)               */
        call saveStmt 'DC',ald(xField),x(xField),g.0XLOC8 xField
      end
    end
  end
  else do
    parse arg sField +3 sData
    nField = length(sField)        /* 1 to 3 bytes not fullword aligned */
    xField = c2x(sField)
    select
      when nField = 3 then do   /* Generate AL3(label)                  */
        xLoc = stripx(xField)   /* Remove leading zeros */
        sLabel = refLabel(getLabel(xLoc),xLoc)
        call saveStmt 'DC',al(sLabel,3),x(xField),g.0XLOC8 xField
      end
      otherwise do              /* Generate ALn(decimal)                */
        call saveStmt 'DC',ald(xField),x(xField),g.0XLOC8 xField
      end
    end
  end
  call nextLoc +nField
return sData

doAddress8: procedure expose g.
  parse arg sField +8 sData
  nField = length(sField)
  xField = c2x(sField)
  select
    when nField = 8 then do    /* Generate AD(label) or ADL8(label)     */
      xLoc = xField
      xLoc = stripx(xLoc)      /* Remove leading zeros */
      sLabel = refLabel(getLabel(xLoc),xLoc)
      if isDoublewordBoundary()
      then call saveStmt 'DC',ad(sLabel),x(xField),g.0XLOC8 xField
      else call saveStmt 'DC',adl(sLabel,8),x(xField),g.0XLOC8 xField
    end
    otherwise do              /* Generate ADLn(decimal)               */
      call saveStmt 'DC',adld(xField),x(xField),g.0XLOC8 xField
    end
  end
  call nextLoc +nField
return sData

doBit: procedure expose g.
  parse arg sField +1 sData
  xField = c2x(sField)
  nField = length(sField)
  call saveStmt 'DC',m(xField),,g.0XLOC8 xField
  call nextLoc nField
return sData

doText: procedure expose g.
  parse arg sData
  if \isText(sData)
  then return doHex(sData)
  do while length(sData) > 0
    parse var sData sField +50 sData
    nField = length(sField)
    if nField <= 6
    then xField = c2x(sField)
    else xField = ''
    if sField = ''       /* For all blanks, show CLnnn' ' */
    then call saveStmt 'DC',cl(' ',nField),,g.0XLOC8 xField
    else do
      sShort = strip(sField,'TRAILING')
      nShort = length(sShort)
      if nShort < nField /* For trailing blanks, show CLnnn'text' */
      then call saveStmt 'DC',cl(sShort,nField),,g.0XLOC8 xField
      else call saveStmt 'DC',cl(sField),,g.0XLOC8 xField
    end
    call nextLoc +length(sField)
  end
return ''

doASCII: procedure expose g.
  parse arg sData
  if \isASCII(sData)
  then return doHex(sData)
  do while length(sData) > 0
    parse var sData sField +50 sData
    nField = length(sField)
    if nField <= 6
    then xField = c2x(sField)
    else xField = ''
    sField = toEBCDIC(sField)
    if sField = ''       /* For all blanks, show CALnnn' ' */
    then call saveStmt 'DC',cal(' ',nField),,g.0XLOC8 xField
    else do
      sShort = strip(sField,'TRAILING')
      nShort = length(sShort)
      if nShort < nField /* For trailing blanks, show CLnnn'text' */
      then call saveStmt 'DC',cal(sShort,nField),,g.0XLOC8 xField
      else call saveStmt 'DC',cal(sField),,g.0XLOC8 xField
    end
    call nextLoc +length(sField)
  end
return ''

doFullword: procedure expose g.
  parse arg sField +4 sData
  nField = length(sField)
  xField = c2x(sField)
  select
    when isText(sField),       /* Rarely:      L R1,=CL4'BLAH' */
      then call saveStmt 'DC',cl(sField),x(xField),g.0XLOC8 xField
    when adcon(sField) <> '',  /* Quite often: L R1,=A(blah)   */
      then call saveStmt 'DC',adcon(sField),x(xField),g.0XLOC8 xField
    otherwise do               /* But mostly:  L R1,=F'123'    */
      if isFullwordBoundary() & nField = 4
      then call saveStmt 'DC',f(xField),,g.0XLOC8 xField
      else call saveStmt 'DC',fl(xField),,g.0XLOC8 xField
    end
  end
  call nextLoc +nField
return sData

doFullword8: procedure expose g.
  parse arg sField +8 sData
  xField = c2x(sField)
  nField = length(sField)
  if isDoublewordBoundary() & nField = 8
  then call saveStmt 'DC',fd(xField),,g.0XLOC8 xField
  else call saveStmt 'DC',fdl(xField),,g.0XLOC8 xField
  call nextLoc +nField
return sData

doHalfword: procedure expose g.
  parse arg sField +2 sData
  xField = c2x(sField)
  nField = length(sField)
  if isHalfwordBoundary() & nField = 2
  then call saveStmt 'DC',h(xField),,g.0XLOC8 xField
  else call saveStmt 'DC',hl(xField),,g.0XLOC8 xField
  call nextLoc +nField
return sData

doPacked: procedure expose g.
  parse arg sData 0 sField +16          /* No more than 16 bytes     */
  xField = c2x(sField)
  nField = getPackedLen(xField)         /* Size of valid packed dec  */
  if nField = 0                         /* If position is no good    */
  then sData = doHex(sData)             /* Then not packed decimal   */
  else do                               /* Valid packed decimal      */
    parse var sData sField +(nField) sData
    xField = c2x(sField)
    call saveStmt 'DC',p(xField),,g.0XLOC8 xField
    call nextLoc +nField
  end
return sData

getPackedLen: procedure
  arg xData
  nPos = verify(xData,'ABCDEF','MATCH') /* Position of sign nibble  */
  if nPos < 1 | nPos > 16 | nPos//2 = 1 /* If position is no good   */
  then return 0
return nPos/2

doSCON: procedure expose g.
  parse arg sData
  xData = c2x(sData)
  nData = length(sData)
  /* If the S-type address constants are adjacent                 */
  /* Then emit: DC   nS(*)                                        */
  /* Else emit: DC   S(X'xxx'(Rnn))                               */
  dLoc = x2d(g.0XLOC)
  nDup = 0
  do i = 1 to length(xData) by 4
    xBaseDisp = substr(xData,i,4)
    nLoc = sLoc(xBaseDisp)
    if nLoc = dLoc /* If this S-type address refers to the current location */
    then do
      nDup = nDup + 1
      if nDup = 1
      then xSconLo = xBaseDisp
    end
    else do /* We have a discontiguity */
      if nDup > 0
      then do /* Emit the S-type address list so far */
        if nDup = 1
        then call saveStmt 'DC','S(*)',x(xBaseDisp),g.0XLOC8 xBaseDisp
        else call saveStmt 'DC',nDup'S(*)',x(xSconLo)'-'||x(xSconHi),g.0XLOC8
        call nextLoc +nDup*2
        nDup = 0
      end
      /* Now emit this discontiguous S-type address */
      call saveStmt 'DC',s(xBaseDisp),x(xBaseDisp),g.0XLOC8 xBaseDisp
      call nextLoc +2
    end
    dLoc = dLoc + 2
    xSconHi = xBaseDisp
  end
  if nDup > 0
  then do
    call saveStmt 'DC',nDup'S(*)',x(xSconLo)'-'||x(xSconHi),g.0XLOC8
    call nextLoc +nDup*2
  end
return ''

s: procedure             /* S-type address constant */
  arg xBaseReg +1 xDisp +3
return 'S('||x(xDisp)'('r(xBaseReg)'))'

sLoc: procedure expose g.
  arg xBaseReg +1 xDisp .
  xBase = g.0CBASE.xBaseReg
  if xBase = ''
  then nLoc = 0
  else nLoc = x2d(xBase) + x2d(xDisp)
return nLoc

doHex: procedure expose g.
  parse arg sData
  do while length(sData) > 0
    parse var sData sField +24 sData /* 24 bytes at a time */
    xField = c2x(sField)
    nField = length(sField)
    call saveStmt 'DC',xl(xField),,g.0XLOC8 ox(xField)
    call nextLoc +(nField)
  end
return sData

doShortHexFloat: procedure expose g.
  parse arg sField +4 sData
  nField = length(sField)
  if nField = 4
  then do
    xField = c2x(sField)
    sSpecialValue = g.0EH.xField
    if sSpecialValue = ''
    then call saveStmt 'DC',eh(sField),x(xField),g.0XLOC8 xField
    else call saveStmt 'DC',"EH'"sSpecialValue"'",x(xField),g.0XLOC8 xField
    call nextLoc +4
  end
  else sData = doHex(sField)
return sData

eh: procedure expose g.
  parse arg sExp +1 sFraction
  if sFraction = '000000'x
  then return x(c2x(sExp)'000000')
  if bitand(sExp,'10000000'b) = '10000000'b
  then sSign = '-'
  else sSign = '+'
  nExp = c2d(bitand(sExp,'01111111'b))-64
  xFraction = c2x(sFraction)
  nScale = verify(xFraction,'0','NOMATCH') - 1
  if nScale < 0 then nScale = 6
  if nScale > 0
  then sScale = 'S'nScale
  else sScale = ''
  nValue = c2d(sFraction)*(16**(nExp-6))
  sValue = sSign || strip(format(nValue,,8,2,0))
return 'EH'sScale"'"sValue"'"

doLongHexFloat: procedure expose g.
  parse arg sField +8 sData
  nField = length(sField)
  if nField = 8
  then do
    xField = c2x(sField)
    sSpecialValue = g.0DH.xField
    if sSpecialValue = ''
    then call saveStmt 'DC',dh(sField),x(xField),g.0XLOC8 xField
    else call saveStmt 'DC',"DH'"sSpecialValue"'",x(xField),g.0XLOC8 xField
    call nextLoc +8
  end
  else sData = doHex(sField)
return sData

dh: procedure expose g.
  parse arg sExp +1 sFraction
  if sFraction = '00000000000000'x
  then return x(c2x(sExp)'00000000000000')
  if bitand(sExp,'10000000'b) = '10000000'b
  then sSign = '-'
  else sSign = '+'
  nExp = c2d(bitand(sExp,'01111111'b))-64
  xFraction = c2x(sFraction)
  nScale = verify(xFraction,'0','NOMATCH') - 1
  if nScale < 0 then nScale = 14
  if nScale > 0
  then sScale = 'S'nScale
  else sScale = ''
  nValue = c2d(sFraction)*(16**(nExp-14))
  sValue = sSign || strip(format(nValue,,18,2,0))
return 'DH'sScale"'"sValue"'"

doShortBinFloat: procedure expose g.
  parse arg sData 0 sField +4 sRest
  if length(sField) = 4
  then do
    xField = c2x(sField)
    call saveStmt 'DC',bfp(xField,'EB'),x(xField),g.0XLOC8 xField
    call nextLoc +4
    sData = sRest
  end
  else sData = doHex(sData)
return sData

doLongBinFloat: procedure expose g.
  parse arg sData 0 sField +8 sRest
  if length(sField) = 8
  then do
    xField = c2x(sField)
    call saveStmt 'DC',bfp(xField,'DB'),x(xField),g.0XLOC8 xField
    call nextLoc +8
    sData = sRest
  end
  else sData = doHex(sData)
return sData

bfp: procedure expose g. /* Binary Floating Point */
  parse arg xField,sType
  sStem = '0'sType
  sSpecialValue = g.sStem.xField
  if sSpecialValue <> ''
  then return sType"'"sSpecialValue"'"
  nField = length(xField)
  select
    when nField = 8 then do  /* Short */
      nExpBits = 8
      nFracBits = 23
      nBias = 127
      nPrec = 6
    end
    when nField = 16 then do /* Long */
      nExpBits = 11
      nFracBits = 52
      nBias = 1023
      nPrec = 14
    end
    otherwise do             /* Extended */
      nExpBits = 15
      nFracBits = 112
      nBias = 16383
      nPrec = 28
    end
  end
  bField = x2b(xField)
  parse var bField bSign +1 bBiasedExp +(nExpBits) bFrac
  nBiasedExp = b2d(bBiasedExp)
  bAllOnes = pos('0',bBiasedExp) = 0
  if nBiasedExp \= 0 & \bAllOnes
  then bFrac = '1'bFrac
  nExp = nBiasedExp-nBias
  nValue = b2d(bFrac) * 2**(nExp-nFracBits)
  sValue = translate(bSign,'+-','01')format(nValue,,nPrec,,0)
return sType"'"sValue"'"

c2b: procedure
  parse arg sValue
return x2b(c2x(sValue))

b2d: procedure
  parse arg bValue
return x2d(b2x(bValue))

doShortDecFloat: procedure expose g.
  parse arg sData 0 sField +4 sRest
  if length(sField) = 4
  then do
    xField = c2x(sField)
    call saveStmt 'DC',dfp(xField,'ED'),x(xField),g.0XLOC8 xField
    call nextLoc +4
    sData = sRest
  end
  else sData = doHex(sData)
return sData

doLongDecFloat: procedure expose g.
  parse arg sData 0 sField +8 sRest
  if length(sField) = 8
  then do
    xField = c2x(sField)
    call saveStmt 'DC',dfp(xField,'DD'),x(xField),g.0XLOC8 xField
    call nextLoc +8
    sData = sRest
  end
  else sData = doHex(sData)
return sData

dfp: procedure expose g. /* Decimal Floating Point */
  parse arg xField,sType
  sStem = '0'sType
  sSpecialValue = g.sStem.xField
  if sSpecialValue <> ''
  then return sType"'"sSpecialValue"'"
  nField = length(xField)
  select
    when nField = 8 then do  /* Short */
      nRBE = 6               /* Remaining Biased Exponent bits */
      nBias = 101            /* Right-Units View (RUV) exponent bias */
    end
    when nField = 16 then do /* Long */
      nRBE = 8
      nBias = 398
    end
    otherwise do             /* Extended */
      nRBE = 11
      nBias = 12287
    end
  end
  bField = x2b(xField)
  parse var bField bSign +1 b12 +2 b34 +2 4 b345 +3 bRBE +(nRBE) bSignificand
  if b12 = '11'
  then do
    nBiasedExp = b2d(b34 || bRBE)
    if right(b345,1) = 0
    then nLMD = 8            /* Left Most Digit is 8 */
    else nLMD = 9            /* Left Most Digit is 9 */
  end
  else do
    nBiasedExp = b2d(b12 || bRBE)
    nLMD = b2d(b345)         /* Left Most Digit is encoded in bits 3-5 */
  end
  nExp = nBiasedExp-nBias
  nDeclets = declets(bSignificand)
  nValue = (nLMD||nDeclets) * 10**nExp
  sValue = translate(bSign,'+-','01')format(nValue)
return sType"'"sValue"'"

declets: procedure
  parse arg bSignificand
  nValue = ''
  do i = 1 to length(bSignificand) by 10
    nDeclet = declet(substr(bSignificand,i,10))
    nValue = nValue || nDeclet
  end
return nValue

declet: procedure /* Convert 10 bits into three decimal digits */
  /* This unpacks the IEEE754 decimal floating point "Densely Packed Decimal"
     format as tabulated in Figure 20-33 "DPD-to-Decimal Mapping" of the IBM
     z/Architecture Principles of Operations manual (SA22-7832-12).
  */
  parse arg abc +3 def +3 ghij 3 c +1 6 f +1 10 j +1
  select
    when ghij <= '1001' then sDeclet = b2d(abc)b2d(def)b2d(ghij) /* nnn */
    when ghij = '1010' then do
      if f = '1'
      then sDeclet = b2d(abc)'9'b2d(def)-1                 /*  n9n */
      else sDeclet = b2d(abc)'8'b2d(def)                   /*  n8n */
    end
    when ghij = '1011' then do
      if f = '1'
      then sDeclet = b2d(abc)'9'b2d(def)                   /*  n9n */
      else sDeclet = b2d(abc)'8'b2d(def)+1                 /*  n8n */
    end
    when ghij = '1100' then do
      if c = '1'
      then sDeclet = '9'b2d(def)b2d(abc)-1                 /*  9nn */
      else sDeclet = '8'b2d(def)b2d(abc)                   /*  8nn */
    end
    when ghij = '1101' then do
      if c = '1'
      then sDeclet = '9'b2d(def)b2d(abc)                   /*  9nn */
      else sDeclet = '8'b2d(def)b2d(abc)+1                 /*  8nn */
    end
    otherwise do
      parse arg 1 ab +2 4 de +2
      select
        when de = '00' then sDeclet = 8+c||8+f||b2d(ab||j) /* [89][89]n    */
        when de = '01' then sDeclet = 8+c||b2d(ab||f)8+j   /* [89]n[89]    */
        when de = '10' then sDeclet = b2d(abc)8+f||8+j     /* n[89][89]    */
        otherwise           sDeclet = 8+c||8+f||8+j        /* [89][89][89] */
      end
    end
  end
return sDeclet

doUnspecified: procedure expose g.
  parse arg sData 0 s4 +4
  /* Prioritise a leading 4-byte address constant - which happens quite
     often. This avoids say 0000C4D4 being decoded as
     XL2'0000',C'DM' when, if location C4D4 already has a label assigned,
     A(LC4D4) would be more appropriate
  */
  if isFullwordBoundary() & length(s4) = 4
  then do
    sAdCon = adcon(s4) /* Returns A(somelabel) if possible, else null */
    if sAdCon \= ''
    then do
      x4 = c2x(s4)
      call saveStmt 'DC',sAdCon,x(x4),g.0XLOC8 x4 /* Emit A(somelabel) */
      call nextLoc +4
      parse var sData . +4 sData
    end
  end
  xLoc = g.0XLOC
  sType = g.0CTYPE.xLoc
  if sType <> '' & g.0MAXLEN.sType <> ''
  then do
    nField = g.0CLENG.xLoc
    nData = length(sData)
    if nField <= nData
    then do
      nField = min(g.0MAXLEN.sType,nField)
      parse var sData sField +(nField) sData
      sTemp = doType(sType,sField)
    end
  end

  nFirstNonText = verify(sData,g.0EBCDIC,'NOMATCH')
  nFirstText    = verify(sData,g.0EBCDIC,'MATCH')
/*
              nFirstNonText nFirstText
  ABC.EF      4             1
  .BCDEF      1             2
  ABCDEF      0             1
  ......      1             0

*/
  select
    when nFirstText = 0 then do     /* All binary */
      sData = doBinary(sData)
    end
    when nFirstNonText = 0 then do  /* All text */
      sData = doText(sData)
    end
    when nFirstText = 1 then do     /* Text then binary             */
      if length(sData) <= 4         /* It's probably all binary     */
      then sData = doBinary(sData)  /* tbbb or ttbb or tttb         */
      else do
        sField = left(sData,nFirstNonText-1)
        sTemp = doText(sField)
        sData = substr(sData,nFirstNonText)
      end
    end
    when nFirstNonText = 1 then do  /* Binary then text             */
      if length(sData) <= 4         /* It's probably all binary     */
      then sData = doBinary(sData)  /* bttt or bbtt or bbbt         */
      else do
        sField = left(sData,nFirstText-1)
        sTemp = doBinary(sField)
        sData = substr(sData,nFirstText)
      end
    end
    otherwise do                    /* WTF? */
      say 'DIS0001E Could not parse data "'xData'" at offset' g.0XLOC8
      sData = ''
    end
  end
return sData

doType: procedure expose g.
  parse arg sType,sField
  select
    when sType = 'A'  then sResidual = doAddress(sField)
    when sType = 'B'  then sResidual = doBit(sField)
    when sType = 'C'  then sResidual = doText(sField)
    when sType = 'F'  then sResidual = doFullword(sField)
    when sType = 'H'  then sResidual = doHalfword(sField)
    when sType = 'P'  then sResidual = doPacked(sField)
    when sType = 'S'  then sResidual = doSCON(sField)
    when sType = 'X'  then sResidual = doHex(sField)
    when sType = 'E'  then sResidual = doShortHexFloat(sField)
    when sType = 'D'  then sResidual = doLongHexFloat(sField)
    when sType = 'AD' then sResidual = doAddress8(sField)
    when sType = 'FD' then sResidual = doFullword8(sField)
    when sType = 'EH' then sResidual = doShortHexFloat(sField)
    when sType = 'DH' then sResidual = doLongHexFloat(sField)
    when sType = 'EB' then sResidual = doShortBinFloat(sField)
    when sType = 'DB' then sResidual = doLongBinFloat(sField)
    when sType = 'ED' then sResidual = doShortDecFloat(sField)
    when sType = 'DD' then sResidual = doLongDecFloat(sField)
    when sType = 'CA' then sResidual = doASCII(sField)
    otherwise              sResidual = doHumanFriendly(sField)
  end
return sResidual

doHumanFriendly: procedure expose g.
  parse arg sField
  nField = length(sField)
  xField = c2x(sField)
  nBoundary = g.0LOC//4
  select
    when nField = 4 & nBoundary = 0 then do
      call saveStmt 'DC',fh(xField),x(xField),g.0XLOC8 ox(xField)
    end
    when nField = 2 & (nBoundary = 0 | nBoundary = 2) then do
      call saveStmt 'DC',h(xField),x(xField),g.0XLOC8 ox(xField)
    end
    when nField = 1 then do
      call saveStmt 'DC',ald(xField),x(xField),g.0XLOC8 ox(xField)
    end
    otherwise do
      call saveStmt 'DC',xl(xField),,g.0XLOC8 ox(xField)
    end
  end
  call nextLoc +nField
return ''

ox: procedure            /* Optional hex */
  parse arg xData
  if length(xData) <= 12 /* If no longer than the longest instruction */
  then return xData
return ''                /* Reduce clutter */

fh: procedure           /* Fullword, or two halfwords */
  parse arg xData 0  xH1 +4 xH2 +4  1 x1 +2  3 x2 +2  5 x3 +2  7 x4 +2
  select
    when xH1 = '0000'          then return f(xData)          /* 0000xxxx */
    when xH2 = '0000'          then return h(xH1)','h(xH2)   /* xxxx0000 */
    when x1 = '00' & x3 = '00' then return h(xH1)','xl(xH2)  /* 00xx00xx */
    when x2 = '00' & x4 = '00' then return xl(xH1)','xl(xH2) /* xx00xx00 */
    when x1 = '00' & x4 = '00' then return h(xH1)','xl(xH2)  /* 00xxxx00 */
    when x2 = '00'             then return xl(xH1)','h(xH2)  /* xx00xxxx */
    otherwise nop                                            /* xxxxxxxx */
  end
return f(xData)

doBinary: procedure expose g.
  parse arg sData
  if isFullwordBoundary()     /* Scan for address constants */
  then do while length(sData) > 0       
    parse var sData s.1 +4 s.2 +4 s.3 +4 s.4 +4 sData /* Four words at a time */
    sBin = ''
    do i = 1 to 4 while length(s.i) > 0 /* For each fullword... */
      s4 = s.i                /* 1 to 4 bytes */
      sAdCon = adcon(s4)      /* Convert to a named address if one exists */
      if sAdCon = ''
      then sBin = sBin || s4  /* Accumulate this binary chunk */
      else do
        sBin = doResidual(sBin)    /* Emit any preceeding binary chunk */
        x4 = c2x(s4)
        call saveStmt 'DC',sAdCon,x(x4),g.0XLOC8 x4 /* Emit A(somelabel) */
        call nextLoc +length(s4)
      end
    end
    sBin = doResidual(sBin)        /* Emit any residual binary */
  end
  else do                          /* Not fullword aligned */
    do while length(sData) > 0
      parse var sData sChunk +16 sData /* 16 bytes at a time */
      do while length(sChunk) > 0
        sChunk = doResidual(sChunk)
      end
    end
  end
return ''

doResidual: procedure expose g.
  parse arg sField
  do while length(sField) > 0
    xLoc = g.0XLOC
    sLocType = g.0CTYPE.xLoc
    sField = doType(sLocType,sField)
  end
return ''

adcon: procedure expose g. /* Named address e.g. A(FIELD) */
  parse arg sAddr
  if length(sAddr) \= 4 then return ''
  if sAddr = '00000000'x then return ''
  b31 = bitand(sAddr,'80000000'x) = '80000000'x
  sLoc = bitand(sAddr,'7FFFFFFF'x)
  if sLoc = '00000000'x then return ''
  xLoc = stripx(c2x(sLoc))  /* Remove leading zeros */
  sLabel = getLabel(xLoc)
  if sLabel = '' then return ''
  call refLabel sLabel,xLoc
  if b31
  then sLabel = sLabel"+X'80000000'"
return 'A('sLabel')'

isOddBoundary: procedure expose g.
return g.0LOC//2

isFullwordBoundary: procedure expose g.
return g.0LOC//4 = 0

isDoublewordBoundary: procedure expose g.
return g.0LOC//8 = 0

isHalfwordBoundary: procedure expose g.
return g.0LOC//2 = 0

a: procedure             /* Address (aligned on a fullword boundary) */
  arg sLabel .
return 'A('sLabel')'

al: procedure            /* Address (unaligned) */
  arg sLabel,nLen
return 'AL'nLen'('sLabel')'

ad: procedure            /* Address (double, aligned on doubleword) */
  arg sLabel .
return 'AD('sLabel')'

adl: procedure           /* Address (double, unaligned) */
  arg sLabel,nLen
return 'ADL'nLen'('sLabel')'

ald: procedure           /* Address (as a decimal) */
  arg xData
return 'AL'length(xData)/2'('x2d(xData)')'

adld: procedure          /* Address (double, as a decimal) */
  arg xData
return 'ADL'length(xData)/2'('x2d(xData)')'

cl: procedure expose g.  /* Character with length */
  parse arg s,n
  if n = '' then n = length(s)
return 'CL'n||quote(s)

cal: procedure expose g.  /* ASCII character with length */
  parse arg s,n
  if n = '' then n = length(s)
return 'CAL'n||quote(s)

f: procedure             /* Binary fullword */
  arg xData .
return "F'"x2d(xData,8)"'"

fl: procedure            /* Binary fullword with length */
  arg xData .
return 'FL'length(xData)/2"'"x2d(xData,8)"'"

fd: procedure            /* Binary doubleword */
  arg xData .
return "FD'"x2d(xData,16)"'"

fdl: procedure           /* Binary doubleword with length */
  arg xData .
return 'FDL'length(xData)/2"'"x2d(xData,16)"'"

h: procedure             /* Halfword */
  arg xData .
return "H'"x2d(xData,4)"'"

hl: procedure            /* Halfword with length */
  arg xData .
return 'HL'length(xData)/2"'"x2d(xData,4)"'"

p: procedure             /* Packed decimal */
  arg xData .                      /* 19365F */
  nData = length(xData)
  xSign = right(xData,1)           /*      F */
  xData = left(xData,nData-1)      /* 19365  */
  if pos(xSign,'BD') > 0           /* Indicates negative packed decimal */
  then n = -xData
  else n =  xData
return 'PL'nData/2"'"format(n)"'"  /* Number with leading zeros removed */

xl: procedure            /* Hex with length */
  arg xData .
return 'XL'length(xData)/2"'"xData"'"

quote: procedure expose g.
  parse arg s
  if pos(g.0APOST,s) > 0 then s = replace(g.0APOST,g.0APOST2,s)
  if pos(g.0AMP,s) > 0 then s = replace(g.0AMP,g.0AMP2,s)
  if \g.0EBCDIC_ENVIRONMENT then s = toASCII(s)
return "'"s"'"

toASCII: procedure expose g.
  parse arg s
return translate(s,g.0ASCII,g.0EBCDIC)

toEBCDIC: procedure expose g.
  parse arg s
return translate(s,g.0EBCDIC,g.0ASCII)

replace: procedure
  parse arg sFrom,sTo,sText
  nTo = length(sTo)
  n = pos(sFrom,sText)
  do while n > 0
    sText = delstr(sText,n,length(sFrom))
    sText = insert(sTo,sText,n-1)
    n = pos(sFrom,sText,n+nTo)
  end
return sText

decodeCode: procedure expose g.
  arg xData
  nData = length(xData)
  i = 1
  do while i < nData
    xInst = substr(xData,i,12)
    nLen = decodeInst(xInst)
    call nextLoc +trunc(nLen/2)
    i = i + nLen
  end
return

decodeInst: procedure expose g.
  arg 1 aa +2 1 bbbb +4 4 c +1 11 dd +2 0 xInst
/*
   Opcodes can only come from certain places in an instruction:
   Instruction   Type (for the purposes of this disassembler)
   ------------  ---- 
   aa..........   1
   bbbb........   2
   cc.c........   3
   dd........dd   4

   So, given 6 bytes of hex, we need to check if there is valid opcode
   for each of these sources. If not, then return a 2-byte constant and move
   the 6-byte instruction window forward by 2.
*/
  ccc  = aa || c
  dddd = aa || dd
  select
    when g.0INST.1.aa   <> '' then xOpCode = aa
    when g.0INST.2.bbbb <> '' then xOpCode = bbbb
    when g.0INST.3.ccc  <> '' then xOpCode = ccc
    when g.0INST.4.dddd <> '' then xOpCode = dddd
    otherwise xOpCode = '.' /* Unrecognised opcode: treat as constant  */
  end
  if xOpCode <> '.'
  then g.0INST = g.0INST + 1              /* Instruction count      */
  else g.0TODO = g.0TODO + 1              /* "Bad Instruction" count*/
  sFormat   = g.0FORM.xOpCode             /* Instruction format     */
  nType     = g.0OPCD.sFormat             /* Opcode type            */
  sMnemonic = g.0INST.nType.xOpCode       /* Instruction mnemonic   */
  sFlag     = g.0FLAG.xOpCode             /* Instruction flags      */
  sDesc     = g.0DESC.xOpCode             /* Instruction description*/
  sHint     = g.0HINT.xOpCode             /* Operand length hint    */
  nLen      = g.0LENG.sFormat             /* Instruction length     */
  sParser   = g.0PARS.sFormat             /* Instruction parser     */
  sEmitter  = g.0EMIT.sFormat             /* Instruction generator  */
  parse value '' with ,  /* Clear operand fields:                   */
                      B1 B2 B3 B4,        /* Base register          */
                      DH1 DH2,            /* Displacement (high)    */
                      DL1 DL2,            /* Displacement (low)     */
                      D1 D2 D3 D4,        /* Displacement           */
                      I1 I2 I3 I4 I5 I6,  /* Immediate              */
                      L1 L2,              /* Length                 */
                      M1 M2 M3 M4 M5 M6,  /* Mask                   */
                      O1 O2,              /* Operation Code         */
                      RI1 RI2 RI3 RI4,    /* Relative Immediate     */
                      RS2 RT2,            /* S/370 Vector Facility  */
                      RXB,                /* Vector register MSBs   */
                      R1 R2 R3,           /* Register               */
                      V1 V2 V3 V4,        /* Vector register LSBs   */
                      X1 X2,              /* Index register         */
                      Z                   /* Zero remaining bits    */
  interpret 'parse var xInst' sParser /* 1. Parse the instruction          */
  if RXB <> '' /* If this is a Vector instruction */
  then do      /* Each Vector register is 5-bits wide: 32 registers */
    parse value x2b(RXB) with RXB1 +1 RXB2 +1 RXB3 +1 RXB4 +1
    V1 = RXB1||V1 /* Prepend high order bit to the V1 operand */
    V2 = RXB2||V2 /* Prepend high order bit to the V2 operand */
    V3 = RXB3||V3 /* Prepend high order bit to the V3 operand */
    V4 = RXB4||V4 /* Prepend high order bit to the V4 operand */
  end
  interpret 'TL =' sHint              /* 2. Get length hint from xOpCode   */
  parse var TL TL T1 T2               /*    TL=length Tn=nTh operand type  */
  if T1 = '.' then T1 = ''
  if T2 = '.' then T2 = ''
  if T1||T2 <> ''
  then TX = '('T1','T2')'
  else TX = ''
  interpret 'o =' sEmitter            /* 3. Generate instruction operands  */
  sOperands = space(o,,',')           /* Put commas between operands    */
  sOperands = translate(sOperands,' ',g.0HARDBLANK) /* Soften blanks :) */
  xCode     = left(xInst,nLen)
  sOverlay  = g.0XLOC8 left(xCode,12) left(sFormat,5) right(TL,3) TX

  /* Post decode tweaking: extended mnemonics are a bit easier to read  */
  if inSet(sFlag,'A C C8 c M')
  then g.0CC = left(sFlag,1) /* Instruction type that sets condition code */

  select
    when sMnemonic = 'DIAG' then do
      g.0DIAG = 1                     /* Insert a DIAG macro (for z/OS) */
               /* ...because HLASM does not support a DIAGNOSE mnemonic */
      call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end      
    when sMnemonic = 'L' & X2=0 & B2=0 & D2 = '010' then do
      sDesc = sDesc '-> CVT'
      call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
    when sMnemonic = 'SVC' then do
      if g.0SVC.I1 \= ''
      then sDesc = g.0SVC.I1
      call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
    when sFlag = 'B' then do          /* Branch on condition            */
      sExt = getExt(sMnemonic,g.0CC,M1)
      if sExt <> ''                   /* If an extended mnemonic exists */
      then do
        sUse = g.0CC
        sDesc = g.0DESC.sUse.sExt
        parse var sOperands ','sTarget  /* Discard M1 field               */
        call saveStmt sExt,sTarget,sDesc,sOverlay
      end
      else call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
    when sFlag = 'R' then do          /* Branch relative on condition   */
      sTarget = getLabelRel(RI2)
      sExt = getExt(sMnemonic,g.0CC,M1)
      if sExt <> ''                   /* If an extended mnemonic exists */
      then do
        sUse = g.0CC
        sDesc = g.0DESC.sUse.sExt
        call saveStmt sExt,sTarget,sDesc,sOverlay
      end
      else call saveStmt sMnemonic,m(M1)','sTarget,sDesc,sOverlay
    end
    when sFlag = 'S' then do          /* Select (SELR, SELGR, SELFHR)   */
      sExt = getExt(sMnemonic,g.0CC,M4)
      if sExt <> ''                   /* If an extended mnemonic exists */
      then do
        sUse = g.0CC
        sDesc = g.0DESC.sUse.sExt
        nComma = lastpos(',',sOperands)
        sOps = left(sOperands,nComma-1) /* Discard M4 field             */
        call saveStmt sExt,sOps,sDesc,sOverlay
      end
      else call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
    when sFlag = 'R4' then do         /* Relative 4-nibble offset       */
      sTarget = getLabelRel(RI2)
      call saveStmt sMnemonic,r(R1)','sTarget,sDesc,sOverlay
    end
    when inSet(sFlag,'R8 C8') then do /* Relative 8-nibble offset       */
      sTarget = getLabelRel(RI2)
      call saveStmt sMnemonic,r(R1)','sTarget,sDesc,sOverlay
    end
    when sFlag = 'CJ' then do         /* Compare and Jump               */
      select
        when sFormat = 'RIEb'  then sTarget = getLabelRel(RI4)
        when sFormat = 'RIEc'  then sTarget = getLabelRel(RI4)
        when sFormat = 'RIS'   then sTarget = getLabelRel(I2)
        when sFormat = 'RRS'   then sTarget = db(D4,B4)
        otherwise sTarget = ''
      end
      sExt = g.0EXTC.M3 /* Convert mask to extended mnemonic suffix     */
      if sExt <> ''    /* If an extended mnemonic exists for this inst  */
      then do          /* Then rebuild operands without the M3 mask     */
        if sFormat = 'RIEc'  
        then o = r(R1) u(I2) sTarget
        else o = r(R1) r(R2) sTarget
      end
      else do
        if sFormat = 'RIEc'  
        then o = r(R1) u(I2) m(M3) sTarget
        else o = r(R1) r(R2) m(M3) sTarget
      end
      sMnemonic = sMnemonic||sExt
      call saveStmt sMnemonic,space(o,,','),sDesc,sOverlay
    end
    when sFlag = 'O' then do          /* Load/Store on Condition        */
      sExt = g.0EXTO.M3 /* Convert mask to extended mnemonic suffix     */
      if sExt <> ''    /* If an extended mnemonic exists for this inst  */
      then do          /* Then rebuild operands without the M3 mask     */
        select         /* These are the only Load/St on Cond formats:   */
          when sFormat = 'RIEg'  then o = r(R1) s4(I2)
          when sFormat = 'RRFc'  then o = r(R1) r(R2)
          when sFormat = 'RRFc3' then o = r(R1) r(R2)
          when sFormat = 'RSYb'  then o = r(R1) db(DH2||DL2,B2)
          otherwise nop
        end
        sMnemonic = sMnemonic||sExt
        call saveStmt sMnemonic,space(o,,','),sDesc,sOverlay
      end
      else call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
    when sFlag = 'RO' then do         /* Rotate (RIEf format)           */
      x345 = I3 || I4 || I5         /* Operands 3, 4 and 5 together     */
      sExt = g.0EXTR.sMnemonic.x345 /* Convert operands to ext mnemonic */
      if sExt <> ''    /* If an extended mnemonic exists                */
      then do          /* Then rebuild operands using the mnemonic      */
        sDesc = g.0DESC.sMnemonic.x345
        call saveStmt sExt,r(R1)','r(R2),sDesc,sOverlay
        sMnemonic = sExt
      end
      else do
        d4 = s2(I4)                  /* Get the 4th operand in decimal */
        if d4 < 0                    /* If the zero flag bit is set    */
        then do                      /* Append Z to the mnemonic...    */
          d4 = d4 + 128                  /* Remove zero flag bit */
          o = r(R1) r(R2) s2(I3) d4 s2(I5) /* Rebuild the operands */
          call saveStmt sMnemonic'Z',space(o,,','),sDesc,sOverlay
        end
        else call saveStmt sMnemonic,sOperands,sDesc,sOverlay
      end
    end
    otherwise do
      call saveStmt sMnemonic,sOperands,sDesc,sOverlay
    end
  end
  if g.0OPTION.STAT
  then call doStats sFormat,sMnemonic,xOpCode
return nLen

/* Target operand length hint calculations */
hM: procedure expose R1 R3 /* Target length for multiple register load/store */
  arg n
  nR1 = x2d(R1)
  nR3 = x2d(R3)
  if nR1 <= nR3
  then nLM = ( 1 + nR3 - nR1) * n /* LM R2,R4,xxx   -> 3 registers  = 12 */
  else nLM = (17 + nR3 - nR1) * n /* LM R14,R12,xxx -> 15 registers = 60 */
return nLM

doStats: procedure expose g.
  parse arg sFormat,sMnemonic,xOpCode
  if xOpCode \= '.' /* If it is a valid instruction */
  then do
    /* Instruction format statistics */
    if g.0FI.sFormat = ''   /* If format not seen before */
    then do
      n = g.0FN.0 + 1       /* Increment format count */
      g.0FN.0 = n
      g.0FC.0 = n
      g.0FN.n = sFormat     /* This format's name  */
      g.0FI.sFormat = n     /* This format's index */
      g.0FC.n = 1           /* This format's count */
    end
    else do
      n = g.0FI.sFormat     /* Get this format's index */
      g.0FC.n = g.0FC.n + 1 /* Increment format count */
    end
    /* Instruction mnemonic statistics */
    if g.0MI.sMnemonic = '' /* If mnemonic not seen before */
    then do
      n = g.0MN.0 + 1       /* Increment mnemonic name count */
      g.0MN.0 = n
      g.0MC.0 = n
      g.0MN.n = sMnemonic   /* This mnemonic's name  */
      g.0MI.sMnemonic = n   /* This mnemonic's index */
      g.0MC.n = 1           /* This mnemonic's count */
      g.0MF.n = sFormat     /* This mnemonic's format */
      g.0ML.sFormat = g.0ML.sFormat sMnemonic /* List of mnemonics */
    end
    else do
      n = g.0MI.sMnemonic   /* Get this mnemonic's index */
      g.0MC.n = g.0MC.n + 1 /* Increment mnemonic count */
    end
  end
return

inSet: procedure
  parse arg sArg,sSet
return wordpos(sArg,sSet) > 0

saveStmt: procedure expose g.
  parse arg sMnemonic,sOperands,sComment,sOverlay
  nMnemonic = max(length(sMnemonic),5)
  sInst = left(sMnemonic,nMnemonic) sOperands
  nInst = max(length(sInst),29)
  sStmt = '        ' left(sInst,nInst) sComment
  call save overlay(g.0ISCODE sOverlay,sStmt,100)
return

db: procedure expose g.       /* Unsigned 12-bit displacement off base */
  arg xDisp,xBaseReg
  sLabel = getLabelDisp(xDisp,xBaseReg)
  if sLabel = ''
  then do /* No known label found, so return explicit operands */
    if xBaseReg = 0
    then return u(xDisp) /* Base register defaults to 0 */
    else return u(xDisp)'('r(xBaseReg)')'
  end
return sLabel

ldb: procedure expose g.      /* Signed 20-bit displacement off base */
  arg xDisp,xBaseReg
  sLabel = getLabelDisp(xDisp,xBaseReg)
  if sLabel = ''
  then do /* No known label found, so return explicit operands */
    if xBaseReg = 0
    then return s5(xDisp) /* Base register defaults to 0 */
    else return s5(xDisp)'('r(xBaseReg)')'
  end
return sLabel

dbs: procedure expose g.      /* Signed 12-bit shift */
  arg xDisp,xBaseReg
  if xBaseReg = 0
  then return s3(xDisp)                  /* Displacement only */
  else return s3(xDisp)'('r(xBaseReg)')' /* Displacement off a base register */
return

ldbs: procedure expose g.     /* Signed 20-bit shift */
  arg xDisp,xBaseReg
  if xBaseReg = 0
  then return s5(xDisp)                  /* Displacement only */
  else return s5(xDisp)'('r(xBaseReg)')' /* Displacement off a base register  */
return

dlb: procedure expose g. /* 12-bit displacement off base register with length */
  arg xDisp,xLength,xBaseReg
  sLabel = getLabelDisp(xDisp,xBaseReg,xLength)
  if sLabel = '' /* No known label found, so return explicit operands */
  then return u(xDisp)'('l(xLength)','r(xBaseReg)')'
return sLabel'('l(xLength)')'

dvb: procedure /* Displacement off a base register with vector register */
  arg xDisp,xVectorReg,xBaseReg
return x(xDisp)'('v(xVectorReg)','r(xBaseReg)')'

dxb: procedure expose g. /* 12-bit displacement off base reg with index reg */
  arg xDisp,xIndexReg,xBaseReg
  if xIndexReg = 0 & xBaseReg = 0 /* it's a displacement only */
  then return u(xDisp)
  if xBaseReg  = 0 /* it's a displacement from an index register only */
  then do
    sLabel = getLabelDisp(xDisp,xIndexReg)
    if sLabel = ''
    then return u(xDisp)'('xr(xIndexReg)')' /* LA Rn,X'xxx'(Rx)             */
    else return sLabel                      /* LA Rn,label                  */
  end
  /* A base register is specified: either CSECT or DSECT */
  sLabel = getLabelDisp(xDisp,xBaseReg)
  if xIndexReg = 0 /* it's a displacement from a base register only */
  then do
    if sLabel = ''
    then return u(xDisp)'(,'r(xBaseReg)')'  /* LA Rn,X'xxx'(,Rb)            */
    else return sLabel                      /* LA Rn,label                  */
  end
                   /* it's a displacement from a base WITH index register */
  if sLabel = ''
  then return u(xDisp)'('xr(xIndexReg)','r(xBaseReg)')' /* LA Rn,X'xxx'(Rx,Rb)*/
return sLabel'('xr(xIndexReg)')'            /* LA Rn,label(Rx)              */

ldxb: procedure expose g. /* 20-bit displacement off base reg with index reg */
  arg xDisp,xIndexReg,xBaseReg
  if xIndexReg = 0 & xBaseReg = 0 /* it's a displacement only */
  then return s5(xDisp)
  if xBaseReg  = 0 /* it's a displacement from an index register */
  then return s5(xDisp)'('xr(xIndexReg)')'
  /* A base register is specified: either CSECT or DSECT */
  sLabel = getLabelDisp(xDisp,xBaseReg)
  if xIndexReg = 0 /* it's a displacement from a base register only */
  then do
    if sLabel = ''
    then return s5(xDisp)'(,'r(xBaseReg)')'
    else return sLabel
  end
                   /* it's a displacement from a base with index register */
  if sLabel = ''
  then return s5(xDisp)'('xr(xIndexReg)','r(xBaseReg)')'
return sLabel'('xr(xIndexReg)')'

getLabelDisp: procedure expose g.
  arg xDisp,xBaseReg,xLength
  /* xDisp is a positive offset in bytes from xBaseReg */
  sLabel = ''
  select
    when g.0CBASE.xBaseReg \= '' then do /* This is a CSECT base register */
      xLoc = g.0CBASE.xBaseReg
      nTarget = x2d(xLoc) + x2d(xDisp)
      xTarget = d2x(nTarget)
      sLabel = refLabel(label(xTarget),xTarget)
    end
    when g.0DBASE.xBaseReg \= '' then do /* This is a DSECT base register */
      sLabel = getDsectLabel(xDisp,xBaseReg,xLength)
      if xLength \= ''
      then do
        nLength = l(xLength)           /* Proposed length of this field */
        if nLength > g.0DLENG.sLabel   /* If proposed > current length */
        then g.0DLENG.sLabel = nLength /* Then use the larger length */
      end
    end
    otherwise nop                /* Unnamed base+displacement */
  end
return sLabel

getDsectLabel: procedure expose g.
  arg xDisp,xBaseReg,xLength
  sDsectName = g.0DBASE.xBaseReg       /* DSECT name for this base register */
  nLocn = g.0DLOCN.xBaseReg            /* Offset into DSECT for this base reg */
  xDisp = d2x(x2d(xDisp)+nLocn)        /* Offset into DSECT of this label */
  sLabel = g.0DSLAB.sDsectName.xDisp   /* Get existing DSECT label if any */
  if sLabel = ''
  then do                              /* Create a label for this field */
    sLabel = sDsectName'_'xDisp        /* Label format: dsect_xxx */
    g.0DSLAB.sDsectName.xDisp = sLabel /* Remember label by DSECT and disp */
    if xLength \= ''                   /* If instruction has length operand */
    then g.0DLENG.sLabel = l(xLength)  /* Assign known field length */
    else g.0DLENG.sLabel = 0           /* Else it becomes "name DS 0X" */
    n = g.0DSECT.sDsectName.0          /* Number of fields in this DSECT */
    if n = '' then n = 0               /* If no fields yet then count = 0 */
    n = n + 1                          /* Increment number of fields */
    g.0DSECT.sDsectName.n = sLabel     /* Set label for field n */
    g.0DSECT.sDsectName.0 = n          /* Number of fields */
    g.0DDISP.sDsectName.n = x2d(xDisp) /* Decimal displacement of field */
    g.0DDISP.sDsectName.0 = n          /* Number of fields for sorting later */
  end
return sLabel


t: procedure expose g. /* Operand length hint */
  /* This function is called as each instruction is being parsed and sets the */
  /* length in bytes of the field referenced by base+disp.  It always */
  /* returns '' so as not to add spurious characters to the generated */
  /* assembler instruction */
  arg nLength,xBaseReg,xDisp,sType
  select
    when g.0CBASE.xBaseReg \= '' then do /* Base+Disp addresses CSECT */
      xBase = g.0CBASE.xBaseReg
      nOffset = x2d(xDisp)
      nTarget = x2d(xBase) + nOffset
      xTarget = d2x(nTarget)
      sTarget = getLabel(xTarget)
      if nLength \= ''      /* If instruction has an implicit operand length */
      then do
        if g.0CLENG.xTarget = ''
        then g.0CLENG.xTarget = nLength
        else g.0CLENG.xTarget = max(g.0CLENG.xTarget,nLength)
        if g.0CTYPE.xTarget = '' 
        then g.0CTYPE.xTarget = sType
        call refLabel ,xTarget
      end
    end
    when g.0DBASE.xBaseReg \= '' then do /* Base+Disp addresses DSECT */
      if nLength \= ''      /* If instruction has an implicit operand length */
      then sLabel = getDsectLabel(xDisp,xBaseReg,d2x(nLength))
      else sLabel = getDsectLabel(xDisp,xBaseReg)
      if nLength > g.0DLENG.sLabel   /* If proposed > current length */
      then g.0DLENG.sLabel = nLength /* Then use the larger length */
      if g.0DTYPE.sLabel = '' & sType \= ''
      then g.0DTYPE.sLabel = sType
    end
    otherwise nop                        /* No USING for this base register */
  end
return ''

l: procedure   /* Length */
  arg xData .
  n = x2d(xData)
return n+1

ml: procedure expose g.  /* Mask Length e.g. '0111' length is 3 */
  arg xData .
return g.0MASK.xData

m: procedure   /* 1-nibble bit mask */
  arg xData .
return "B'"x2b(xData)"'"

om: procedure  /* Optional 1-nibble bit mask */
  arg xData .
  if xData = '0'
  then return ''
return "B'"x2b(xData)"'"

r: procedure   /* 1-nibble register R0 to R15 */
  arg xData .
return 'R'x2d(xData)

r3: procedure expose g.   /* Relative 12-bit signed offset (3 nibbles) */
  arg xData .
return getLabelRel(xData)

r4: procedure expose g.   /* Relative 16-bit signed offset (4 nibbles) */
  arg xData .
return getLabelRel(xData)

r6: procedure expose g.   /* Relative 24-bit signed offset (6 nibbles) */
  arg xData .
return getLabelRel(xData)

r8: procedure expose g.   /* Relative 32-bit signed offset (8 nibbles) */
  arg xData .
return getLabelRel(xData)

s2: procedure  /* Signed 8-bit integer (2 nibbles) */
  arg xData .
return x2d(xData,2)

s3: procedure  /* Signed 12-bit integer (3 nibbles) */
  arg xData .
return x2d(xData,3)

s4: procedure  /* Signed 16-bit integer (4 nibbles) */
  arg xData .
return x2d(xData,4)

s5: procedure expose g.  /* Signed 20-bit integer (5 nibbles) */
  arg xData .
return x2d(xData,5)

st: procedure   /* System/370 Vector Facility operand  */
  arg s,t       /* s=Address register, t=Stride register */
return r(s)'('r(t)')'

u: procedure expose g.  /* Unsigned integer */
  arg xData .
  n = x2d(xData)
  if n < 64 then return n       /* 00 to 3F: return a decimal        */
  if n = 64 then return "C'"g.0HARDBLANK"'" /* 40: return hard blank */
  sData = x2c(xData)            /* 41 to FF                          */
  if isText(sData)
  then return 'C'quote(sData)   /* Return character if text          */
return "X'"xData"'"             /* else return hex                   */

v: procedure expose g.  /* 1-nibble vector register V0 to V31        */
  arg xData .     /* Already has the most significant bit prepended  */
  g.0VECTOR = 1   /* Remember to emit vector register equates later  */
return 'V'x2d(xData)

ves: procedure expose g.  /* Vector element size */
  arg xData .
  sEquate = g.0VES.xData
  if sEquate = ''
  then sEquate = x2d(xData)
return sEquate

fpf: procedure expose g.  /* Vector floating point format */
  arg xData .
  sEquate = g.0FPF.xData
  if sEquate = ''
  then sEquate = x2d(xData)
return sEquate

x: procedure   /* Hexadecimal */
  arg xData .
return "X'"xData"'"

xr: procedure  /* Index register */
  arg xData .
  n = x2d(xData)
  if n = 0
  then return ''
return 'R'n

getLabelRel: procedure expose g.
  arg xHalfwords . /* xHalfwords is a signed displacement in halfwords */
  if length(xHalfwords) > 4
  then nOffset = 2 * x2d(xHalfwords,8)  /* xxxxxxxx */
  else nOffset = 2 * x2d(xHalfwords,4)  /* xxxx     */
  nTarget = g.0LOC + nOffset
  if nTarget < 0 then nTarget = 0
  xTarget = d2x(nTarget)
  sLabel = refLabel(label(xTarget),xTarget)
return sLabel  

getLabel: procedure expose g.    /* Label name for this hex location */
  arg xLoc
return g.0LABEL.xLoc

getLocation: procedure expose g. /* Hex location for this label */
  arg sLabel
return g.0XLOC.sLabel

isReferenced: procedure expose g.
  parse arg xLoc
  nLoc = x2d(xLoc)
return g.0REF.nLoc \= ''

refLabel: procedure expose g. /* Implicitly define a referenced label */
  parse arg sLabel,xLoc
  nLoc = x2d(xLoc)
  xLoc = d2x(nLoc)            /* Remove leading zeros from xLoc */
  if sLabel = ''
  then sLabel = label(xLoc)
  if getLabel(xLoc) = ''
  then call setLabel sLabel,xLoc   /* Assign a label to location */
  sLabel = getLabel(xLoc)
  if g.0REF.nLoc = ''
  then do                     /* Add to list of locations referred to */
    g.0REF.nLoc = g.0XLOC     /* Remember this location was referenced */
    n = g.0REFLOC.0 + 1
    g.0REFLOC.n = nLoc        /* Location in decimal so it can be sorted */
    g.0REFLOC.0 = n
  end
return sLabel

setLabel: procedure expose g.
  parse arg sLabel,xLoc
  g.0LABEL.xLoc = sLabel      /* Assign a label to this location */
  g.0XLOC.sLabel = xLoc       /* Facilitate retrieving location of a label */
return

label: procedure expose g.
  parse arg xLoc
return 'L'xLoc

isText: procedure expose g.
  parse arg sData
return verify(sData,g.0EBCDIC,'NOMATCH') = 0

isASCII: procedure expose g.
  parse arg sData
return verify(sData,g.0ASCII,'NOMATCH') = 0

isHex: procedure expose g.
  parse arg xData
return xData \= '' & datatype(xData,'X')

isNum: procedure expose g.
  parse arg nData
return datatype(nData,'WHOLE')

sortWords: procedure
  parse arg sWords,bAscending
  array.0 = words(sWords)
  do i = 1 to array.0
    array.i = word(sWords,i)
  end
  call sortStem 'array.',bAscending
  sSorted = ''
  do i = 1 to sorted.0
    n = sorted.i
    sSorted = sSorted word(sWords,n)
  end
return strip(sSorted)

sortStem:
  parse arg stem,ascending
return quickSort(stem,ascending)

quickSort: procedure expose (stem) sorted. g.
  /* Perform a quick sort without modifying the passed stem.
     Instead, return a fixed "sorted." stem containing indexes
     into the passed stem that, if traversed, would access the
     passed stem in the desired order.
     For example:
       in.0 = 3      -->   sorted.0 = 3 (number of items)
       in.1 = 'the'        sorted.1 = 2 (cat)
       in.2 = 'cat'        sorted.2 = 3 (sat)
       in.3 = 'sat'        sorted.3 = 1 (the)
  */
  parse arg array,ascending
  ascending = (ascending <> 0)
  bAlreadySorted = 1
  /* Initialise sorted. array indexes */
  drop sorted.
  sorted.0 = value(array'0') /* Number of items to be sorted */
  if \datatype(sorted.0,'WHOLE') then sorted.0 = 0
  do i = 1 to sorted.0
    sorted.i = i
  end
  if sorted.0 <= 1
  then return bAlreadySorted
  /* Push (1,number of items) onto stack  */
  s = 1               /* Stack pointer      */
  L.1 = 1             /* Left window bound  */
  R.1 = sorted.0      /* Right window bound */
  do while s <> 0
    /* Pop (L,R) from stack */
    L = L.s
    R = R.s
    s = s - 1
    do until L >= R
      i = L
      j = R
      mid = (L + R) % 2
      middleItem = value(array||sorted.mid)
      do until i > j
        if ascending
        then do
          do while value(array||sorted.i) < middleItem
            i = i + 1
          end
          do while middleItem < value(array||sorted.j)
            j = j - 1
          end
        end
        else do
          do while value(array||sorted.i) > middleItem
            i = i + 1
          end
          do while middleItem > value(array||sorted.j)
            j = j - 1
          end
        end
        if i <= j
        then do /* Swap i and j items */
          bAlreadySorted = 0
          p = sorted.i
          sorted.i = sorted.j
          sorted.j = p
          i = i + 1
          j = j - 1
        end
      end
      if i < R
      then do /* Push i and R onto stack */
        s = s + 1
        L.s = i
        R.s = R
      end
      R = j
    end
  end
return bAlreadySorted

prolog:
  call setLoc 0       /* Location counter from start of module (integer) */
  g.0INST.0 = 0       /* Number of instructions in the architecture      */
  g.0INST   = 0       /* Number of instructions emitted                  */
  g.0TODO   = 0       /* Number of bad instructions (TODO's) emitted     */
  g.0HARDBLANK = 'ff'x /* Hard blank to help with parsing                */
  g.0DELTA  = 0       /* Progress counter                                */
  g.0VECTOR = 0       /* Assume no vector register equates are required  */
  g.0FN.0   = 0       /* Instruction format count                        */
  g.0MN.0   = 0       /* Instruction mnemonic count                      */
  g.0DSECT.0 = 0      /* DSECT count                                     */
  g.0REFLOC.0 = 0     /* Number of referenced locations                  */
  g.0ISCODE = 1       /* 1=Code 0=Data                                   */
  g.0DOT.0 = 0        /* Number of dots to be inserted                   */
  g.0FIELD.0 = 0      /* Number of fields when parsing a table entry     */
  g.0DIAG     = 0       /* DIAG macro is to be inserted                    */
  do i = 1 until sourceline(i) = 'BEGIN-FORMAT-DEFINITIONS'
  end
  do i = i+1 while sourceline(i) <> 'END-FORMAT-DEFINITIONS'
    sLine = sourceline(i)
    parse var sLine sType nLen sTemplate
    call addFormat sType,nLen,sTemplate
  end
  do i = i while sourceline(i) <> 'BEGIN-INSTRUCTION-DEFINITIONS'
  end
  do i = i+1 while sourceline(i) <> 'END-INSTRUCTION-DEFINITIONS'
    sLine = sourceline(i)
    parse var sLine sMnemonic xOpCode sFormat sFlag sArch sDesc '='sHint
    if left(sMnemonic,1) <> '*'
    then call addInst sMnemonic,xOpCode,sFormat,sFlag,sArch,sDesc,sHint
  end
  say 'DIS0000I Loaded' g.0INST.0 g.0ARCHNAME 'instructions'
  do i = i while sourceline(i) <> 'BEGIN-EXTENDED-BRANCH-MNEMONICS'
  end
  do i = i+1 while sourceline(i) <> 'END-EXTENDED-BRANCH-MNEMONICS'
    sLine = sourceline(i)
    parse var sLine sUse xMask sBC sBCR sBIC sBRC sBRCL sDesc
    call addExt sUse,xMask,sBC,sBCR,sBIC,sBRC,sBRCL,sDesc
  end
  do i = i while sourceline(i) <> 'BEGIN-EXTENDED-SELECT-MNEMONICS'
  end
  do i = i+1 while sourceline(i) <> 'END-EXTENDED-SELECT-MNEMONICS'
    sLine = sourceline(i)
    parse var sLine sUse xMask sSELR sSELGR sSELFHR sDesc
    call addExtSelect sUse,xMask,sSELR,sSELGR,sSELFHR,sDesc
  end
  do i = i while sourceline(i) <> 'BEGIN-SVC-LIST'
  end
  do i = i+1 while sourceline(i) <> 'END-SVC-LIST'
    sLine = sourceline(i)
    parse var sLine xSVC sZOSSVC
    call addSVC xSVC,sZOSSVC
  end
  do i = i while sourceline(i) <> 'BEGIN-FP-CONSTANTS'
  end
  do i = i+1 while sourceline(i) <> 'END-FP-CONSTANTS'
    sLine = sourceline(i)
    parse var sLine sType xValue sValue .
    interpret 'g.0'sType'.xValue = sValue'
  end
  /* Vector element size equates */
  g.0VES.0 = 'V_BYTE'
  g.0VES.1 = 'V_HALFWORD'
  g.0VES.2 = 'V_WORD'
  g.0VES.3 = 'V_DOUBLEWORD'
  g.0VES.4 = 'V_QUADWORD'
  g.0VES.6 = 'V_WORD_LEFT'
  /* Vector floating point format equates */
  g.0FPF.2 = 'V_SHORT_FP'
  g.0FPF.3 = 'V_LONG_FP'
  g.0FPF.4 = 'V_EXTENDED_FP'
  /* Default length of assembler data types */
  g.0LEN.A = 4
  g.0LEN.B = 1
  g.0LEN.C = 1
  g.0LEN.F = 4
  g.0LEN.H = 2
  g.0LEN.P = 1
  g.0LEN.S = 2
  g.0LEN.X = 1
  /* Number of 1 bits in a 4-bit mask */
  g.0MASK.0 = 0
  g.0MASK.1 = 1
  g.0MASK.2 = 1
  g.0MASK.3 = 2
  g.0MASK.4 = 1
  g.0MASK.5 = 2
  g.0MASK.6 = 2
  g.0MASK.7 = 3
  g.0MASK.8 = 1
  g.0MASK.9 = 2
  g.0MASK.A = 2
  g.0MASK.B = 3
  g.0MASK.C = 2
  g.0MASK.D = 3
  g.0MASK.E = 3
  g.0MASK.F = 4
  /* Maximum data type lengths in bytes (else unlimited) */
  /* ...that this disassembler handles */
  call addType 'H',2
  call addType 'F',4
  call addType 'FD',8
  call addType 'P',16
  call addType 'A',4
  call addType 'AD',8
  call addType 'D',8
  call addType 'E',4
  call addType 'DH',8
  call addType 'EH',4
  call addType 'DB',8
  call addType 'EB',4
  call addType 'DD',8
  call addType 'ED',4
  /* Compare Immediate and Branch extended mnemonic suffixes */
                                /* Equal             */
                                /* |Low              */
                                /* ||High            */
                                /* |||Ignored        */
                                /* ||||              */
                                /* VVVV              */
  call addExtCompare '2','H'    /* 0010              */
  call addExtCompare '4','L'    /* 0100              */
  call addExtCompare '6','NE'   /* 0110              */
  call addExtCompare '8','E'    /* 1000              */
  call addExtCompare 'A','NL'   /* 1010              */
  call addExtCompare 'C','NH'   /* 1100              */

  /* Load/Store on Condition extended mnemonic suffixes      */
                                /* Equal             */
                                /* |Low              */
                                /* ||High            */
                                /* |||One|Overflow   */
                                /* ||||              */
                                /* VVVV              */
  call addExtOnCond  '1','O'    /* 0001              */
  call addExtOnCond  '2','H'    /* 0010              */
  call addExtOnCond  '4','L'    /* 0100              */
  call addExtOnCond  '7','NE'   /* 0111              */
  call addExtOnCond  '8','E'    /* 1000              */
  call addExtOnCond  'B','NL'   /* 1011              */
  call addExtOnCond  'D','NH'   /* 1101              */
  call addExtOnCond  'E','NH'   /* 1110              */

  /* Extended mnemonics for Rotate instrucions               */
  /*           ---Mnemonic---   --Operands--                 */
  /*           Extended Base    I3     I4 I5  Desc           */
  call addRot 'NHHR'  ,'RNSBG' ,00,    31,00,'And High (H<-H)'
  call addRot 'NHLR'  ,'RNSBG' ,00,    31,32,'And High (H<-L)'
  call addRot 'NLHR'  ,'RNSBG' ,32,    63,32,'And High (L<-H)'
  call addRot 'XHHR'  ,'RXSBG' ,00,    31,00,'Exclusive-Or High (H<-H)'
  call addRot 'XHLR'  ,'RXSBG' ,00,    31,32,'Exclusive-Or High (H<-L)'
  call addRot 'XLHR'  ,'RXSBG' ,32,    63,32,'Exclusive-Or High (L<-H)'
  call addRot 'OHHR'  ,'ROSBG' ,00,    31,00,'Or High (H<-H)'
  call addRot 'OHLR'  ,'ROSBG' ,00,    31,32,'Or High (H<-L)'
  call addRot 'OLHR'  ,'ROSBG' ,32,    63,32,'Or High (L<-H)'
  call addRot 'LHHR'  ,'RISBHG',00,128+31,00,'Load (H<-H)'
  call addRot 'LHLR'  ,'RISBHG',00,128+31,32,'Load (H<-L)'
  call addRot 'LLHFR' ,'RISBLG',00,128+31,32,'Load (L<-H)'
  call addRot 'LLHHHR','RISBHG',16,128+31,00,'Load Logical Halfword (H<-H)'
  call addRot 'LLHHLR','RISBHG',16,128+31,32,'Load Logical Halfword (H<-L)'
  call addRot 'LLHLHR','RISBLG',16,128+31,32,'Load Logical Halfword (L<-H)'
  call addRot 'LLCHHR','RISBHG',24,128+31,00,'Load Logical Character (H<-H)'
  call addRot 'LLCHLR','RISBHG',24,128+31,32,'Load Logical Character (H<-L)'
  call addRot 'LLCLHR','RISBLG',24,128+31,32,'Load Logical Character (L<-H)'

  /* EBCDIC characters that can typically be displayed by ISPF EDIT */
  g.0EBCDIC  = '40'x                   ||, /*            */
               '4A4B4C4D4E4F50'x       ||, /* ¢.<(+|&    */
               '5A5B5C5D5E5F6061'x     ||, /* !$*);^-/   */
               '6A6B6C6D6E6F'x         ||, /* |,%_>?     */
               '7A7B7C7D7E7F'x         ||, /* :#@'="     */
               '818283848586878889'x   ||, /* abcdefghi  */
               '919293949596979899'x   ||, /* jklmnopqr  */
               'A1A2A3A4A5A6A7A8A9'x   ||, /* ~stuvwxyz  */
               'ADBA'x                 ||, /* [[         */
               'BDBB'x                 ||, /* ]]         */
               'C0C1C2C3C4C5C6C7C8C9'x ||, /* {ABCDEFGHI */
               'D0D1D2D3D4D5D6D7D8D9'x ||, /* }JKLMNOPQR */
               'E0'x                   ||, /* \          */
               'E2E3E4E5E6E7E8E9'x     ||, /* STUVWXYZ   */
               'F0F1F2F3F4F5F6F7F8F9'x     /* 0123456789 */

  /* The above EBCDIC characters translated to ASCII */
  g.0ASCII   = '20'x                   ||, /*            */
               'A22E3C282B7C26'x       ||, /* ¢.<(+|&    */
               '21242A293B5E2D2F'x     ||, /* !$*);^-/   */
               '4F2C255F3E3F'x         ||, /* |,%_>?     */
               '3A2340273D22'x         ||, /* :#@'="     */
               '616263646566676869'x   ||, /* abcdefghi  */
               '6A6B6C6D6E6F707172'x   ||, /* jklmnopqr  */
               '7E737475767778797A'x   ||, /* ~stuvwxyz  */
               '5B5B'x                 ||, /* [[         */
               '5D5D'x                 ||, /* ]]         */
               '7B414243444546474849'x ||, /* {ABCDEFGHI */
               '7A4A4B4C4D4E4F505152'x ||, /* }JKLMNOPQR */
               '5C'x                   ||, /* \          */
               '535455565758595A'x     ||, /* STUVWXYZ   */
               '30313233343536373839'x     /* 0123456789 */

  /* EBCDIC characters that are duplicated in character constants */
  g.0APOST  = '7D'x                        /* '          */
  g.0APOST2 = '7D7D'x                      /* ''         */
  g.0AMP    = '50'x                        /* &          */
  g.0AMP2   = '5050'x                      /* &&         */
  
  address TSO 'SUBCOM ISREDIT'
  g.0EDITENV = rc = 0
  if g.0EDITENV
  then do /* Direct output to a temporary dataset and then edit it */
    address ISREDIT
    'MACRO (sArgs)'
    if rc <> 0 & \isHex(xData) /* If not already editing a file */
               /* and hex data was not supplied on the command line   */
    then do    /* Then edit a temporary file and insert an AMBLIST job */
      sTempFile = getTempFileName()'E'
      call quietly 'ALLOCATE FILE(OUT) DATASET('sTempFile')',
                   'RECFM(V B) BLKSIZE(27920) LRECL(259)',
                   'SPACE(1,1) TRACKS REUSE'
      call buildJob sDsn sMod
      address ISPEXEC 'EDIT DATASET('sTempFile')'
      call quietly 'DELETE' sTempFile
      exit
    end
    '(member) = MEMBER'   /* Member currently being edited */
    '(dataset) = DATASET' /* Dataset currently being edited */
    '(lines) = LINENUM .ZLAST' /* Number of lines being edited */
    if \isNum(lines) then lines = 1
    nPri = lines * 10
    nSec = lines
    address ISPEXEC 'CONTROL ERRORS RETURN'
    g.0TEMPDSN = getTempFileName()
    call quietly 'ALLOCATE FILE(OUT) DATASET('g.0TEMPDSN')',
                 'RECFM(V B) BLKSIZE(27920) LRECL(259)',
                 'SPACE('nPri','nSec') AVBLOCK(130) REUSE'
    g.0LINE = 0
    g.0ARGS = translate(sArgs)
    call getOptions
  end
return

getOptions:
  parse var g.0ARGS xArgs'('sOptions
  xArgs = space(xArgs,0) /* Save any hex data supplied on the command line */
  if \isHex(xData) then xData = xArgs
  g.0OPTION.TEST = 0
  g.0OPTION.STAT = 0
  g.0OPTION.ASM = 0
  g.0OPTION.360 = 0 /* Disassemble System/360 instruction set */
  g.0OPTION.370 = 0 /* Disassemble System/370 instruction set */
  g.0OPTION.390 = 0 /* Disassemble System/390 instruction set */
  g.0OPTION.Z   = 0 /* Disassemble z/Architecture instruction set */
  do i = 1 to words(sOptions)
    sOption = word(sOptions,i)
    g.0OPTION.sOption = 1
  end
  select
    when g.0OPTION.360 then do
      g.0ARCH = '6'
      g.0ARCHNAME = 'System/360'
    end
    when g.0OPTION.370 then do
      g.0ARCH = '7'
      g.0ARCHNAME = 'System/370'
    end
    when g.0OPTION.390 then do
      g.0ARCH = '9'
      g.0ARCHNAME = 'System/390'
    end
    otherwise do
      g.0ARCH = 'Z'
      g.0ARCHNAME = 'z/Architecture'
    end
  end
return

buildJob:
  arg sDsn sMod .
  if sDsn = '' then sDsn = 'SYS1.LPALIB'
  if sMod = '' then sMod = 'IEFBR14'
  sJob = left(userid()'A',8)
  queue '//'sJob "JOB ,'AMBLIST" sMod"',CLASS=U,MSGCLASS=T,NOTIFY=&SYSUID"
  queue '//STEP1   EXEC PGM=AMBLIST'
  queue '//SYSPRINT  DD SYSOUT=*'
  queue '//SYSLIB    DD DISP=SHR,DSN='sDsn
  queue '//SYSIN     DD *'
  queue '  LISTLOAD  DDN=SYSLIB,OUTPUT=BOTH,MEMBER='sMod
  queue '/*'
  queue '//'
  do i = 1 until sourceline(i) = 'BEGIN-JCL-COMMENTS'
  end
  do i = i+1 while sourceline(i) <> 'END-JCL-COMMENTS'
    sLine = sourceline(i)
    parse var sLine 4 sComment +66 .
    queue '//*' sComment
  end
  address TSO 'EXECIO' queued() 'DISKW OUT (FINIS'
return

Epilog:
  address TSO 'EXECIO' queued() 'DISKW OUT (FINIS'
  if g.0EDITENV
  then do
    call quietly 'FREE FILE(OUT)'
    address ISPEXEC 'EDIT DATASET('g.0TEMPDSN')'
    call quietly 'DELETE' g.0TEMPDSN
  end
  'RESET FIND'
return

getTempFileName: procedure expose g.
  yymmdd = substr(date('STANDARD'),3)
  parse value time('LONG') with hh':'mm':'ss'.'uuuuuu
return 'DA.D'yymmdd'.T'hh||mm||ss'.S'uuuuuu

quietly: procedure expose g. o.
  parse arg sCommand
  rc = outtrap('o.')
  address TSO sCommand
  g.0RC = rc
  rc = outtrap('off')
return

addType: procedure expose g.
  arg sType,nMaxLen
  g.0MAXLEN.sType = nMaxLen
return

addFormat: procedure expose g.
  parse arg sFormat,nLength,sParseTemplate
  if left(sFormat,1) = '*'
  then return
  sParseTemplate = space(sParseTemplate)
  if isNum(nLength)
  then do
    g.0LENG.sFormat = nLength
    g.0PARS.sFormat = sParseTemplate
/*
   Opcodes can only come from certain places in an instruction:
   Instruction   Type Opcode comprises O1 concatenated with O2
   ------------  ---- ----------------------------------------
   aa..........   1   O1 is 2 nibbles
   bbbb........   2   O1 is 4 nibbles
   cc.c........   3   O1 is 2 nibbles and O2 is 1 nibble
   dd........dd   4   O1 is 2 nibbles and O2 is 2 nibbles
*/
    if g.0OPCD.sFormat = ''
    then do
      select
        when pos('O1 +4',sParseTemplate) > 0 then nOpCodeType = 2
        when pos('O2 +1',sParseTemplate) > 0 then nOpCodeType = 3
        when pos('O2 +2',sParseTemplate) > 0 then nOpCodeType = 4
        otherwise nOpCodeType = 1
      end
      g.0OPCD.sFormat = nOpCodeType
    end
    /* Validate the template format */
    nSum = 0
    do i = 1 to words(sParseTemplate)
      sToken = word(sParseTemplate,i)
      if left(sToken,1) = '+'
      then nSum = nSum + sToken
    end
    if nLength <> nSum
    then do
      say 'DIS0002E Format' sFormat':' sParseTemplate
      say '         Template length ('nSum') does not match',
                   'instruction length ('nLength')'
    end
  end
  else do
    g.0EMIT.sFormat = sParseTemplate
  end
return

addInst: procedure expose g.
  parse arg sMnemonic,xOpCode,sFormat,sFlag,sArch,sDesc,sHint
  if pos(g.0ARCH,sArch) > 0 
  then do /* Instruction is implemented in this architecture */
    g.0INST.0 = g.0INST.0 + 1
    if g.0MNEM.sMnemonic <> ''
    then say 'DIS0003E Already defined:' sMnemonic 'as' g.0MNEM.sMnemonic
    g.0MNEM.sMnemonic = xOpCode
    nOpCodeType = g.0OPCD.sFormat
    if g.0INST.nOpCodeType.xOpCode <> ''
    then say 'DIS0004E Already defined:' xOpCode sMnemonic sFormat sFlag sDesc
    if g.0LENG.sFormat = ''
    then say 'DIS0005E Format' sFormat 'is not defined (opcode='xOpCode')'
    g.0INST.nOpCodeType.xOpCode = sMnemonic
    g.0FORM.xOpCode = sFormat
    g.0FLAG.xOpCode = sFlag
    sDesc = strip(sDesc)
    g.0DESC.xOpCode = sDesc
    g.0DESC.sMnemonic = sDesc
    if sHint = ''
    then g.0HINT.xOpCode = "''"             /* No target length hint */
    else g.0HINT.xOpCode = sHint            /* Target length hint expression */
  end
return

addRot: procedure expose g.
  parse arg sExt,sBaseMnemonic,I3,I4,I5,sDesc
  x345 = d2x(I3,2)d2x(I4,2)d2x(I5,2)
  g.0EXTR.sBaseMnemonic.x345 = sExt
  g.0DESC.sBaseMnemonic.x345 = sDesc
return

genInst: procedure expose g.
  parse arg xOpCode,sMnemonic,sFormat,sDesc
  nLen      = g.0LENG.sFormat / 2         /* Instruction length     */
  /* Generate test harness instruction */
  parse value '' with ,                   /* Clear operand fields:  */
                      B1 B2 B3 B4,        /* Base register          */
                      DH1 DH2,            /* Displacement (high)    */
                      DL1 DL2,            /* Displacement (low)     */
                      D1 D2 D3 D4,        /* Displacement           */
                      I1 I2 I3 I4 I5 I6,  /* Immediate              */
                      L1 L2,              /* Length                 */
                      M1 M2 M3 M4 M5 M6,  /* Mask                   */
                      O1 O2,              /* Operation Code         */
                      RI1 RI2 RI3 RI4,    /* Relative Immediate     */
                      RS2 RT2,            /* S/370 Vector Facility  */
                      RXB,                /* Vector register MSBs   */
                      R1 R2 R3,           /* Register               */
                      V1 V2 V3 V4,        /* Vector register LSBs   */
                      X1 X2               /* Index register         */
  xInst = '000000000000' /* Pseudo instruction hex */
  interpret 'parse var xInst' g.0PARS.sFormat   /* Parse the instruction */
  /* Fix-ups for those instructions that cannot have all zero operands */
  select
    when wordpos(sMnemonic,'KMA KMCTR') > 0 then do
      R1 = 2
      R2 = 4
      R3 = 6
    end
    when wordpos(sMnemonic,'KIMD KLMD') > 0 then do
      R2 = 2
    end
    when left(sMnemonic,2) = 'KM' | sMnemonic = 'PRNO' then do
      R1 = 2
      R2 = 2
    end
    when sMnemonic = 'KDSA' then do
      R1 = 2
      R2 = 4
    end
    when wordpos(sMnemonic,'PKU') > 0 then do
      L2 = 1
    end
    when wordpos(sMnemonic,'UNPKU') > 0 then do
      L1 = 1
    end
    when wordpos(sMnemonic,'DP MP') > 0 then do
      L1 = 2
      L2 = 1
    end
    when wordpos(sMnemonic,'DIDBR DIEBR') > 0 then do
      R1 = 1
      R2 = 2
    end
    when sMnemonic = 'DFLTCC' then do
      R1 = 2
      R2 = 4
      R3 = 6
    end
    otherwise nop
  end
  call setLabel 'X'xOpCode,g.0XLOC
  interpret 'o =' g.0EMIT.sFormat     /* Generate instruction operands  */
  sOperands = space(o,,',')
  nMnemonic = max(length(sMnemonic),5)
  sLabel = getLabel(g.0XLOC)
  sInst = left(sMnemonic,nMnemonic) sOperands
  nInst = max(length(sInst),29)
  sStmt = left(sLabel,8),
          left(sInst,nInst),
          sDesc
  call emit sStmt
  call nextLoc +nLen
return

addSVC: procedure expose g.
  parse arg xSVC,sZOSSVC
  g.0SVC.xSVC   = strip(sZOSSVC)
return

addExt: procedure expose g.
  parse arg sUse,xMask,sBC,sBCR,sBIC,sBRC,sBRCL,sDesc
  g.0EXT.BC.sUse.xMask  = sBC    /* Branch on Condition               */
  g.0EXT.BCR.sUse.xMask = sBCR   /* Branch Register on Condition      */
  g.0EXT.BIC.sUse.xMask = sBIC   /* Branch Immediate on Condition     */
  g.0EXT.BRC.sUse.xMask = sBRC   /* Branch Relative on Condition      */
  g.0EXT.BRCL.sUse.xMask = sBRCL /* Branch Relative on Condition Long */
  sDesc = strip(sDesc)
  g.0DESC.sUse.sBC   = sDesc
  g.0DESC.sUse.sBCR  = sDesc
  g.0DESC.sUse.sBIC  = sDesc
  g.0DESC.sUse.sBRC  = sDesc
  g.0DESC.sUse.sBRCL = sDesc
return

addExtSelect: procedure expose g.
  parse arg sUse,xMask,sSELR,sSELGR,sSELFHR,sDesc
  g.0EXT.SELR.sUse.xMask   = sSELR   /* Select (32)                       */
  g.0EXT.SELGR.sUse.xMask  = sSELGR  /* Select (64)                       */
  g.0EXT.SELFHR.sUse.xMask = sSELFHR /* Select High                       */
  sDesc = strip(sDesc)
  g.0DESC.sUse.sSELR   = sDesc
  g.0DESC.sUse.sSELGR  = sDesc
  g.0DESC.sUse.sSELFHR = sDesc
return

addExtCompare: procedure expose g.
  arg xMask,sExt
  g.0EXTC.xMask = sExt
return

addExtOnCond: procedure expose g.
  arg xMask,sExt
  g.0EXTO.xMask = sExt
return

getExt: procedure expose g.
  parse arg sMnemonic,sUse,xMask
  if xMask = 'F' | xMask = '0' /* If mask is unconditional or no-op   */
  then sUse = '.'              /* Preceding instruction is irrelevant */
return g.0EXT.sMnemonic.sUse.xMask

/*
The instruction formats are defined below. There are two lines per instruction
format:

1. The first line is the PARSER. It specifies:
  a. The name of the instruction format
  b. The length (in 4-bit nibbles) of an instruction having this format
  c. The Rexx parsing template to be used to parse an instruction with this
     format.

  For example:

   RR     4 O1 +2 R1 +1    R2 +1

  ...the opcode O1 is 2 nibbles (1 byte), followed by the 1-nibble R1
     operand and the 1-nibble R2 operand.

2. The second line is the GENERATOR. It specifies:
  a. The name of the instruction format (again)
  b. A '.' in the instruction length column to identify this as the GENERATOR
  c. The right hand side of a Rexx assignment statement used to generate the
     Assembler operands of the instruction that was parsed using the parsing
     template.

  For example:

   RR     . r(R1) r(R2)

  Note: Operands are separated by spaces (rather than commas) in order to
        simplify the table definition. Commas are inserted later.

  The GENERATOR can also use the t() rexx function to compute the lengths
  of the operands if that is possible. It is not possible for MVCL, for
  example, because MVCL length values are computed at run time. The t()
  function always returns '' so it has no impact on the GENERATOR other than
  to assign length values to the operands.

Parsing works as follows, using the instruction hex 18CF as an example:

1. The opcode 18 is extracted from the 18CF instruction. Opcodes can appear
   in only a few positions:

   aa..........
   bbbb........
   cc.c........
   dd........dd

   In this case, the opcode is found in position 'aa' (because the other
   combinations do not yield a known instruction).

2. The 18 instruction data is retrieved from the instruction table. In this
   case the instruction data is:

   code mnemonic fmt   f desc
   ---- -------- ----  - -------------------------------------
   18   LR       RR    . Load (32)

   From this, we can see that the 18 instruction is 'Load (32)' and has the
   LR assembler mnemonic and the RR (Register Register) instruction format.

3. The RR instruction format data is retrieved from the format table.
   The RR format data consists of the PARSER and GENERATOR lines:

   Name Len PARSER and GENERATOR (in nibble units)
   ----- -- --------------------------------------
   RR     4 O1 +2 R1 +1    R2 +1                  <-- PARSER template
   RR     . r(R1) r(R2)                           <-- GENERATOR function list

4. The hex instruction 18CF is PARSED using the template "O1 +2 R1 +1 R2 +1"
   which causes the following variables to be set:

   O1 = '18'                                      <-- Op code byte 1
   R1 = 'C'                                       <-- Operand 1
   R2 = 'F'                                       <-- Operand 2

5. The operands are GENERATED using the template "r(R1) r(R2)" which invokes
   the "r" function twice: once with the value in R1 ('C') and again with the
   value in R2 ('F'). When assigned to the Rexx variable 'o' the result is:

   o = 'R12 R15'

6. The assembler instruction is now built by combining the instruction
   mnemonic ('LR') with the operands ('R12 R15') as follows:

   Mnemonic                      Current
   |     Operands   Comment      Offset  Hex           Format
   |     |          |            |       |             |
   V     V          V            V       V             V
   LR    R12,R15    Load (32)    0000000 18CF          RR


Tip:  Because the PARSER and GENERATOR templates are executed using the
      Rexx "interpret" instruction, you can debug individual formats by
      appending Rexx instructions (delimited by ';') to the templates.
      For example:

I      4 O1 +2 I1 +2; say 'Heh dude, we just parsed an I format:'xOpCode
I      . u(I1)

       .--- Instruction length in nibbles (4, 8 or 12)
       |
       V
Name Len PARSER and GENERATOR (in nibble units)
----- -- --------------------------------------
BEGIN-FORMAT-DEFINITIONS
.      4 X1 +4
.      . x(X1)
E      4 O1 +4
E      .
I      4 O1 +2 I1 +2
I      . x2d(I1)
IE     8 O1 +4  . +2    I1 +1  I2 +1
IE     . u(I1) u(I2)
MII   12 O1 +2 M1 +1   RI2 +3 RI3 +6
MII    . u(M1) r3(RI2) r6(RI3)
RIa    8 O1 +2 R1 +1    O2 +1  I2 +4
RIa    . r(R1) s4(I2)
RIax   8 O1 +2 R1 +1    O2 +1  I2 +4
RIax   . r(R1) x(I2)
RIb    8 O1 +2 R1 +1    O2 +1 RI2 +4
RIb    . r(R1) s4(RI2)
RIc    8 O1 +2 M1 +1    O2 +1 RI2 +4
RIc    . m(M1) s4(RI2)
RIEa  12 O1 +2 R1 +1     . +1  I2 +4  M3 +1   . +1       O2 +2
RIEa   . r(R1) s4(I2) m(M3)
RIEb  12 O1 +2 R1 +1    R2 +1 RI4 +4  M3 +1   . +1       O2 +2
RIEb   . r(R1) r(R2) m(M3) s4(RI4)
RIEc  12 O1 +2 R1 +1    M3 +1 RI4 +4  I2 +2              O2 +2
RIEc   . r(R1) u(I2) m(M3) s4(RI4)
RIEd  12 O1 +2 R1 +1    R3 +1  I2 +4   . +2              O2 +2
RIEd   . r(R1) r(R3) s4(I2)
RIEe  12 O1 +2 R1 +1    R3 +1 RI2 +4   . +2              O2 +2
RIEe   . r(R1) r(R3) r4(RI2)
RIEf  12 O1 +2 R1 +1    R2 +1  I3 +2  I4 +2  I5 +2       O2 +2
RIEf   . r(R1) r(R2) s2(I3) s2(I4) s2(I5)
RIEg  12 O1 +2 R1 +1    M3 +1  I2 +4   . +2              O2 +2
RIEg   . r(R1) s4(I2) m(M3)
RILa  12 O1 +2 R1 +1    O2 +1  I2 +8
RILa   . r(R1) u(I2)
RILax 12 O1 +2 R1 +1    O2 +1  I2 +8
RILax  . r(R1) x(I2)
RILb  12 O1 +2 R1 +1    O2 +1 RI2 +8
RILb   . r(R1) r8(RI2)
RILc  12 O1 +2 M1 +1    O2 +1 RI2 +8
RILc   . m(M1) r8(I2)
RIS   12 O1 +2 R1 +1    M3 +1  B4 +1  D4 +3  I2 +2       O2 +2
RIS    . r(R1) r(R2) m(M3) s2(I2)
RR     4 O1 +2 R1 +1    R2 +1
RR     . r(R1) r(R2)
RR1    4 O1 +2 R1 +1     . +1
RR1    . r(R1)
RRm    4 O1 +2 M1 +1    R2 +1
RRm    . m(M1) r(R2)
RRD    8 O1 +4 R1 +1     . +1  R3 +1  R2 +1
RRD    . r(R1) r(R3) r(R2)
RRE    8 O1 +4  . +2    R1 +1  R2 +1
RRE    . r(R1) r(R2)
RRE0   8 O1 +4  . +4
RRE0   . ''
RRE1   8 O1 +4  . +2    R1 +1   . +1
RRE1   . r(R1)
RRFa   8 O1 +4 R3 +1    M4 +1  R1 +1  R2 +1
RRFa   . r(R1) r(R2) r(R3) om(M4)
RRFa4  8 O1 +4 R3 +1    M4 +1  R1 +1  R2 +1
RRFa4  . r(R1) r(R2) r(R3) m(M4)
RRFb   8 O1 +4 R3 +1    .  +1  R1 +1  R2 +1
RRFb   . r(R1) r(R2) r(R3)
RRFc   8 O1 +4 M3 +1     . +1  R1 +1  R2 +1
RRFc   . r(R1) r(R2) om(M3)
RRFc3  8 O1 +4 M3 +1     . +1  R1 +1  R2 +1
RRFc3  . r(R1) r(R2) m(M3)
RRFd   8 O1 +4  . +1    M4 +1  R1 +1  R2 +1
RRFd   . r(R1) r(R2) m(M4)
RRFe   8 O1 +4 M3 +1     . +1  R1 +1  R2 +1
RRFe   . r(R1) m(M3) r(R2)
RRFe4  8 O1 +4 M3 +1    M4 +1  R1 +1  R2 +1
RRFe4  . r(R1) u(M3) r(R2) m(M4)
RRFb4  8 O1 +4 R3 +1    M4 +1  R1 +1  R2 +1
RRFb4  . r(R1) r(R2) r(R3) u(M4)
RRS   12 O1 +2 R1 +1    R2 +1  B4 +1  D4 +3  M3 +1  . +1 O2 +2
RRS    . r(R1) r(R2) m(M3) db(D4,B4)
RSa    8 O1 +2 R1 +1    .  +1  B2 +1  D2 +3
RSa    . r(R1)       dbs(D2,B2)
RSb    8 O1 +2 R1 +1    M3 +1  B2 +1  D2 +3
RSb    . r(R1) m(M3) db(D2,B2)          t(ml(M3),B2,D2,T2)
RSA    8 O1 +2 R1 +1    R3 +1  B2 +1  D2 +3
RSA    . r(R1) r(R3) db(D2,B2)          t(TL,B2,D2,T2)
RSI    8 O1 +2 R1 +1    R3 +1 RI2 +4
RSI    . r(R1) r(R3) r4(RI2)
RSLa  12 O1 +2 L1 +1     . +1  B1 +1  D1 +3   . +1  . +1 O2 +2
RSLa   . dlb(D1,L1,B1)                  t(L1,B1,D1,T1)
RSLb  12 O1 +2 L2 +2           B2 +1  D2 +3  R1 +1 M3 +1 O2 +2
RSLb   . r(R1) dlb(D2,L2,B2) m(M3)      t(L2,B2,D2,T2)
RSYa  12 O1 +2 R1 +1    R3 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RSYa   . r(R1) r(R3) ldb(DH2||DL2,B2)   t(TL,B2,DH2||DL2,T2)
RSYas 12 O1 +2 R1 +1    R3 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RSYas  . r(R1) r(R3) ldbs(DH2||DL2,B2)
RSYb  12 O1 +2 R1 +1    M3 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RSYb   . r(R1) m(M3) ldb(DH2||DL2,B2)   t(TL,B2,DH2||DL2,T2)
RSYbm 12 O1 +2 R1 +1    M3 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RSYbm  . r(R1) m(M3) ldb(DH2||DL2,B2)   t(ml(M3),B2,DH2||DL2)
RXa    8 O1 +2 R1 +1    X2 +1  B2 +1  D2 +3
RXa    . r(R1) dxb(D2,X2,B2)            t(TL,B2,D2,T2)
RXb    8 O1 +2 M1 +1    X2 +1  B2 +1  D2 +3
RXb    . m(M1) dxb(D2,X2,B2)
RXE   12 O1 +2 R1 +1    X2 +1  B2 +1  D2 +3   . +1  . +1 O2 +2
RXE    . r(R1) dxb(D2,X2,B2)            t(TL,B2,D2,T2)
RXE3  12 O1 +2 R1 +1    X2 +1  B2 +1  D2 +3  M3 +1  . +1 O2 +2
RXE3   . r(R1) dxb(D2,X2,B2) m(M3)      t(TL,B2,D2,T2)
RXF   12 O1 +2 R3 +1    X2 +1  B2 +1  D2 +3  R1 +1  . +1 O2 +2
RXF    . r(R1) r(R3) dxb(D2,X2,B2)      t(TL,B2,D2,T2)
RXYa  12 O1 +2 R1 +1    X2 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RXYa   . r(R1) ldxb(DH2||DL2,X2,B2)     t(TL,B2,DH2||DL2,T2)
RXYb  12 O1 +2 M1 +1    X2 +1  B2 +1 DL2 +3 DH2 +2       O2 +2
RXYb   . m(M1) ldxb(DH2||DL2,X2,B2)
S      8 O1 +4 B2 +1    D2 +3
S      . db(D2,B2)                      t(TL,B2,D2)
SI     8 O1 +2 I2 +2    B1 +1  D1 +3
SI     . db(D1,B1) u(I2)                t(TL,B1,D1)
SI0    8 O1 +2 I2 +2    B1 +1  D1 +3
SI0    . db(D1,B1) m(I2)                t(1,B1,D1,T1)
SI1    8 O1 +2  . +2    B1 +1  D1 +3
SI1    . db(D1,B1)                      t(TL,B1,D1,T1)
SI2    8 O1 +4          B1 +1  D1 +3
SI2    . db(D1,B1)                      t(TL,B1,D1,T1)
SIL   12 O1 +4 B1 +1    D1 +3  I2 +4
SIL    . db(D1,B1) s2(I2)               t(TL,B1,D1,T1)
SIY   12 O1 +2 I2 +2    B1 +1 DL1 +3 DH1 +2              O2 +2
SIY    . ldb(DH1||DL1,B1) s2(I2)        t(TL,B1,DH1||DL1,T1)
SIYm  12 O1 +2 I2 +2    B1 +1 DL1 +3 DH1 +2              O2 +2
SIYm   . ldb(DH1||DL1,B1) m(I2)         t(1,B1,DH1||DL1)
SIYx  12 O1 +2 I2 +2    B1 +1 DL1 +3 DH1 +2              O2 +2
SIYx   . ldb(DH1||DL1,B1) x(I2)         t(1,B1,DH1||DL1)
SIYu  12 O1 +2 I2 +2    B1 +1 DL1 +3 DH1 +2              O2 +2
SIYu   . ldb(DH1||DL1,B1) u(I2)         t(1,B1,DH1||DL1)
SMI   12 O1 +2 M1 +1     . +1  B3 +1  D3 +3 RI2 +4
SMI    . m(M1) r4(RI2) db(D3,B3)
SSa   12 O1 +2 L1 +2           B1 +1  D1 +3  B2 +1  D2 +3
SSa    . dlb(D1,L1,B1) db(D2,B2)        t(l(L1),B1,D1)    t(l(L1),B2,D2,T2)
SSa1  12 O1 +2 L1 +2           B1 +1  D1 +3  B2 +1  D2 +3
SSa1   . dlb(D1,L1,B1) db(D2,B2)        t(l(L1),B1,D1)    t(256,B2,D2)
SSb   12 O1 +2 L1 +1    L2 +1  B1 +1  D1 +3  B2 +1  D2 +3
SSb    . dlb(D1,L1,B1) dlb(D2,L2,B2)    t(l(L1),B1,D1,T1) t(l(L2),B2,D2,T2)
SSc   12 O1 +2 L1 +1    I3 +1  B1 +1  D1 +3  B2 +1  D2 +3
SSc    . dlb(D1,L1,B1) db(D2,B2) u(I3)  t(TL,B1,D1,T1)
SSd   12 O1 +2 R1 +1    R3 +1  B1 +1  D1 +3  B2 +1  D2 +3
SSd    . db(D1,B1) db(D2,B2) r(R3)
SSe   12 O1 +2 R1 +1    R3 +1  B2 +1  D2 +3  B4 +1  D4 +3
SSe    . r(R1) r(R3) db(D2,B2) db(D4,B4) t(TL,B2,D2,T2)    t(TL,B4,D4,T1)
SSe1  12 O1 +2 R1 +1    R3 +1  B2 +1  D2 +3  B4 +1  D4 +3
SSe1   . r(R1) r(R3) db(D2,B2) db(D4,B4)
SSf   12 O1 +2 L2 +2           B1 +1  D1 +3  B2 +1  D2 +3
SSf    . db(D1,B1) dlb(D2,L2,B2)         t(16,B1,D1,T1)    t(L2,B2,D2)
SSE   12 O1 +4                 B1 +1  D1 +3  B2 +1  D2 +3
SSE    . db(D1,B1) db(D2,B2)             t(TL,B2,D2,T2)
SSF   12 O1 +2 R3 +1    O2 +1  B1 +1  D1 +3  B2 +1  D2 +3
SSF    . db(D1,B1) db(D2,B2) r(R3)       t(TL,B2,D2,T2)
*
* z/Architecture vector instruction formats:
*
VRIa  12 O1 +2 V1 +1     . +1  I2 +4   . +1                    RXB +1 O2 +2
VRIa   . v(V1) u(I2)
VRIa3 12 O1 +2 V1 +1     . +1  I2 +4  M3 +1                    RXB +1 O2 +2
VRIa3  . v(V1) s4(I2) u(M3)
VRIb  12 O1 +2 V1 +1     . +1  I2 +2  I3 +2  M4 +1             RXB +1 O2 +2
VRIb   . v(V1) u(I2) u(I3) ves(M4)
VRIc  12 O1 +2 V1 +1    V3 +1  I2 +4         M4 +1             RXB +1 O2 +2
VRIc   . v(V1) v(V3) u(I2) m(M4)
VRId  12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  I4 +2  . +1       RXB +1 O2 +2
VRId   . v(V1) v(V2) v(V3) u(I4)
VRId5 12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  I4 +2 M5 +1       RXB +1 O2 +2
VRId5  . v(V1) v(V2) v(V3) u(I4) ves(M5)
VRIe  12 O1 +2 V1 +1    V2 +1  I3 +3         M5 +1 M4 +1       RXB +1 O2 +2
VRIe   . v(V1) v(V2) u(I3) fpf(M4) m(M5)
VRIf  12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  M5 +1 I4 +2       RXB +1 O2 +2
VRIf   . v(V1) v(V2) v(V3) u(I4) m(M5)
VRIg  12 O1 +2 V1 +1    V2 +1  I4 +2  M5 +1        I3 +2       RXB +1 O2 +2
VRIg   . v(V1) v(V2) u(I3) m(I4) m(M5)
VRIh  12 O1 +2 V1 +1     . +1  I2 +4  I3 +1                    RXB +1 O2 +2
VRIh   . v(V1) x(I2) u(I3)
VRIi  12 O1 +2 V1 +1    R2 +1   . +2  M4 +1  I3 +2             RXB +1 O2 +2
VRIi   . v(V1) r(R2) u(I3) m(M4)
VRRa  12 O1 +2 V1 +1    V2 +1   . +5                           RXB +1 O2 +2
VRRa   . v(V1) v(V2)
VRRa2 12 O1 +2 V1 +1    V2 +1   . +2  M5 +1   . +1 M3 +1       RXB +1 O2 +2
VRRa2  . v(V1) v(V2) m(M3)      om(M5)
VRRa3 12 O1 +2 V1 +1    V2 +1   . +4               M3 +1       RXB +1 O2 +2
VRRa3  . v(V1) v(V2) m(M3)
VRRa4 12 O1 +2 V1 +1    V2 +1   . +3         M4 +1 M3 +1       RXB +1 O2 +2
VRRa4  . v(V1) v(V2) fpf(M3) m(M4)
VRRa5 12 O1 +2 V1 +1    V2 +1   . +2  M5 +1  M4 +1 M3 +1       RXB +1 O2 +2
VRRa5  . v(V1) v(V2) fpf(M3) m(M4) u(M5)
VRRb  12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  M5 +1  . +1 M4 +1 RXB +1 O2 +2
VRRb   . v(V1) v(V2) v(V3) ves(M4) m(M5)
VRRb4 12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  M5 +1  . +1 M4 +1 RXB +1 O2 +2
VRRb4  . v(V1) v(V2) v(V3) ves(M4) om(M5)
VRRc3 12 O1 +2 V1 +1    V2 +1  V3 +1   . +4                    RXB +1 O2 +2
VRRc3  . v(V1) v(V2) v(V3)
VRRc4 12 O1 +2 V1 +1    V2 +1  V3 +1   . +3              M4 +1 RXB +1 O2 +2
VRRc4  . v(V1) v(V2) v(V3) ves(M4)
VRRc5 12 O1 +2 V1 +1    V2 +1  V3 +1   . +2        M5 +1 M4 +1 RXB +1 O2 +2
VRRc5  . v(V1) v(V2) v(V3) fpf(M4) m(M5)
VRRc6 12 O1 +2 V1 +1    V2 +1  V3 +1   . +1  M6 +1 M5 +1 M4 +1 RXB +1 O2 +2
VRRc6  . v(V1) v(V2) v(V3) ves(M4) m(M5) m(M6)
VRRd  12 O1 +2 V1 +1    V2 +1  V3 +1  M5 +1   . +2       V4 +1 RXB +1 O2 +2
VRRd   . v(V1) v(V2) v(V3) v(V4) ves(M5)
VRRd5 12 O1 +2 V1 +1    V2 +1  V3 +1  M5 +1  M6 +1  . +1 V4 +1 RXB +1 O2 +2
VRRd5  . v(V1) v(V2) v(V3) v(V4) ves(M5) om(M6)
VRRd6 12 O1 +2 V1 +1    V2 +1  V3 +1  M5 +1  M6 +1  . +1 V4 +1 RXB +1 O2 +2
VRRd6  . v(V1) v(V2) v(V3) v(V4) ves(M5) m(M6)
VRRe  12 O1 +2 V1 +1    V2 +1  V3 +1   . +3              V4 +1 RXB +1 O2 +2
VRRe   . v(V1) v(V2) v(V3) v(V4)
VRRe6 12 O1 +2 V1 +1    V2 +1  V3 +1  M6 +1   . +1 M5 +1 V4 +1 RXB +1 O2 +2
VRRe6  . v(V1) v(V2) v(V3) v(V4) m(M5) fpf(M6)
VRRf  12 O1 +2 V1 +1    R2 +1  R3 +1   . +4                    RXB +1 O2 +2
VRRf   . v(V1) r(R2) r(R3)
VRRg  12 O1 +2  . +1    V1 +1   . +5                           RXB +1 O2 +2
VRRg   . v(V1)
VRRh  12 O1 +2  . +1    V1 +1  V2 +1   . +1  M3 +1  . +2       RXB +1 O2 +2
VRRh   . v(V1) v(V2) m(M3)
VRRi  12 O1 +2 R1 +1    V2 +1   . +2  M3 +1   . +2             RXB +1 O2 +2
VRRi   . r(R1) v(V2) m(M3)
VRSa  12 O1 +2 V1 +1    V2 +1  B2 +1  D2 +3  M4 +1             RXB +1 O2 +2
VRSa   . v(V1) v(V3) db(D2,B2) ves(M4)
VRSb  12 O1 +2 V1 +1    R3 +1  B2 +1  D2 +3   . +1             RXB +1 O2 +2
VRSb   . v(V1) r(R3) db(D2,B2)
VRSb4 12 O1 +2 V1 +1    R3 +1  B2 +1  D2 +3  M4 +1             RXB +1 O2 +2
VRSb4  . v(V1) r(R3) db(D2,B2) ves(M4)
VRSc  12 O1 +2 R1 +1    V3 +1  B2 +1  D2 +3  M4 +1             RXB +1 O2 +2
VRSc   . r(R1) v(V3) db(D2,B2) ves(M4)
VRSd  12 O1 +2  . +1    R3 +1  B2 +1  D2 +3  V1 +1             RXB +1 O2 +2
VRSd   . v(V1) r(R3) db(D2,B2)
VRV   12 O1 +2 V1 +1    V2 +1  B2 +1  D2 +3  M3 +1             RXB +1 O2 +2
VRV    . v(V1) dvb(D2,V2,B2) m(M3)
VRX   12 O1 +2 V1 +1    X2 +1  B2 +1  D2 +3   . +1             RXB +1 O2 +2
VRX    . v(V1) dxb(D2,X2,B2)
VRX3  12 O1 +2 V1 +1    X2 +1  B2 +1  D2 +3  M3 +1             RXB +1 O2 +2
VRX3   . v(V1) dxb(D2,X2,B2) u(M3)
VSI   12 O1 +2 I3 +2           B2 +1  D2 +3  v1 +1             RXB +1 O2 +2
VSI    . v(V1) db(D2,B2) u(I3)
*
* System/370 Vector Facility instruction formats:
*
QST    8 O1 +4  R3 +1   RT2 +1  V1 +1  RS2 +1
QST    . v(V1) r(R3) st(RS2,RT2)
QSTm   8 O1 +4  R3 +1   RT2 +1  M1 +1  RS2 +1
QSTm   . m(M1) r(R3) st(RS2,RT2)
QV     8 O1 +4  R3 +1     . +1  V1 +1   V2 +1
QV     . v(V1) r(R3) v(V2)
QVm    8 O1 +4  R3 +1     . +1  M1 +1   V2 +1
QVm    . m(M1)  r(R3) v(V2)
QV2    8 O1 +4 QR2 +1     . +1  V1 +1    . +1
QV2    . v(V1) r(QR2)
VST    8 O1 +4  V3 +1   RT2 +1  V1 +1  RS2 +1
VST    . v(V1) v(V3) st(RS2,RT2)
VST2   8 O1 +4   . +1   RT2 +1  V1 +1  RS2 +1
VST2   . v(V1) st(RS2,RT2)
VSTm   8 O1 +4  V3 +1   RT2 +1  M1 +1  RS2 +1
VSTm   . m(M1) v(V3) st(RS2,RT2)
VV     8 O1 +4  V3 +1     . +1  V1 +1   V2 +1
VV     . v(V1) v(V3) v(V2)
VVm    8 O1 +4  V3 +1     . +1  M1 +1   V2 +1
VVm    . m(M1)  v(V3) v(V2)
VV1    8 O1 +4  V3 +1     . +1  V1 +1    . +1
VV1    . v(V1)
VV2    8 O1 +4            . +2  V1 +1   V2 +1
VV2    . v(V1) v(V2)
RSE   12 O1 +4  R3 +1     . +1  V1 +1    . +1 B2 +1 D2 +3
RSE    . v(V1) r(R3) db(D2,B2)
VR     8 O1 +4  R3 +1     . +1  V1 +1   R2 +1
VR     . v(V1) r(R2) r(R3)
VR1   8 O1 +4             . +2  V1 +1    . +1
VR1    . v(V1)
VS     8 O1 +4   . +3                  RS2 +1
VS     . r(RS2)
END-FORMAT-DEFINITIONS


The instructions are defined below. There is one line per instruction, each
specifying:
  a. The assembler mnemonic
  b. The instruction opcode
  c. The instruction format
  d. A flag used to modify the processing for certain instructions (for
     example, to convert mnemonics to extended mnemonics)
  e. The instruction description as specified in Principles of Operations
     manual.
  f. An expression (prefixed by '=') that generates the target operand
     length. This is called a "hint". For example, the STC target operand
     length is always 1, but for LM it depends on the operands.
     So, the STC instruction hint is "=1", and the LM instruction hint
     is "=hM(4)"...which takes the M1 value from the LM instruction
     and computes the actual length from the number of 4-byte registers loaded
     by the instruction.
     The length computed in this way is stored in variable TL and can be used
     at the instruction format level yet apply to this specific instruction.

                    .- Flag for determining extended mnemonics:
                    |    A = Arithmetic instruction
                    |    B = Branch on condition instruction (Bxx)
                    |    C = Compare instructions (A:B)
                    |   C8 = Compare relative (8-nibble offset)
                    |   CJ = Compare and Jump
                    |    M = Test under mask instruction
                    |    O = Load/Store-on-Condition instruction
                    |    R = Relative branch on condition (Jxx)
                    |   RO = Rotate
                    |   R4 = Relative 4-nibble offset
                    |   R8 = Relative 8-nibble offset
                    |    S = Select instructions
                    |    c = Sets condition code
                    |    . = Does not set condition code
                    |  
                    | .- Instruction is valid on architecture:
                    | |  6 = System/360
                    | |  7 = System/370
                    | |  9 = ESA/390
                    | |  Z = z/Architecture
                    | |  . = Place holder
                    V V
mnemonic cde fmt    f arch desc [=hint]
------- ---- ----- -- ---- -----------------------------------------------------
BEGIN-INSTRUCTION-DEFINITIONS
DC      .    .      . 679Z <-- TODO (not code)
PR      0101 E      c ..9Z Program Return
UPT     0102 E      c ..9Z Update Tree
PTFF    0104 E      c ..9Z Perform Timing Facility Function
CMSG    0105 E      c ..9Z Coupling Facility: Clear Message
TMSG    0106 E      c ..9Z Coupling Facility: Test Message
SCKPF   0107 E      . ..9Z Set Clock Programmable Field
TMPS    0108 E      c ..9Z Coupling Facility: Test Message Path State
CMPS    0109 E      c ..9Z Coupling Facility: Clear Message Path State
PFPO    010A E      c ..9Z Perform Floating Point Operation
TAM     010B E      c ..9Z Test Addressing Mode
SAM24   010C E      . ..9Z Set Addressing Mode (24)
SAM31   010D E      . ..9Z Set Addressing Mode (31)
SAM64   010E E      . ...Z Set Addressing Mode (64)
TRAP2   01FF E      . ..9Z Trap
SPM     04   RR1    c 679Z Set Program Mask
BALR    05   RR     . 679Z Branch And Link
BCTR    06   RR     . 679Z Branch on Count
BCR     07   RRm    B 679Z Branch on Condition
SSK     08   RR     . 6... Set Storage Key
ISK     09   RR     . 6... Insert Storage Key
SVC     0A   I      . 679Z Supervisor Call
BSM     0B   RR     . ..9Z Branch and Set Mode
BASSM   0C   RR     . ..9Z Branch And Save and Set Mode
BASR    0D   RR     . ..9Z Branch And Save
MVCL    0E   RR     c .79Z Move Character Long
CLCL    0F   RR     C .79Z Compare Logical Character Long
LPR     10   RR     A 679Z Load Positive (32)
LNR     11   RR     A 679Z Load Negative (32)
LTR     12   RR     A 679Z Load and Test (32)
LCR     13   RR     A 679Z Load Complement (32)
NR      14   RR     A 679Z And (32)
CLR     15   RR     C 679Z Compare Logical (32)
OR      16   RR     A 679Z Or (32)
XR      17   RR     A 679Z Exclusive-Or (32)
LR      18   RR     . 679Z Load (32)
CR      19   RR     C 679Z Compare (32)
AR      1A   RR     A 679Z Add (32)
SR      1B   RR     A 679Z Subtract (32)
MR      1C   RR     A 679Z Multiply (64<-32)
DR      1D   RR     A 679Z Divide (32<-64)
ALR     1E   RR     A 679Z Add Logical (32)
SLR     1F   RR     A 679Z Subtract Logical (32)
LPDR    20   RR     A 679Z Load Positive (LH)
LNDR    21   RR     A 679Z Load Negative (LH)
LTDR    22   RR     A 679Z Load and Test (LH)
LCDR    23   RR     A 679Z Load Complement (LH)
HDR     24   RR     . 679Z Halve (LH)
LRDR    25   RR     . 67.. Load Rounded (LH<-EH)
LDXR    25   RR     . ..9Z Load Rounded (LH<-EH)
MXR     26   RR     A 679Z Multiply (EH)
MXDR    27   RR     A 679Z Multiply (EH<-LH)
LDR     28   RR     . 679Z Load (Long)
CDR     29   RR     C 679Z Compare (LH)
ADR     2A   RR     A 679Z Add (LH)
SDR     2B   RR     A 679Z Subtract (LH)
MDR     2C   RR     A 679Z Multiply (LH)
DDR     2D   RR     A 679Z Divide (LH)
AWR     2E   RR     A 679Z Add Unnormalized (LH)
SWR     2F   RR     A 679Z Subtract Unnormalized (LH)
LPER    30   RR     A 679Z Load Positive (SH)
LNER    31   RR     A 679Z Load Negative (SH)
LTER    32   RR     A 679Z Load and Test (SH)
LCER    33   RR     A 679Z Load Complement (SH)
HER     34   RR     . 679Z Halve Short (SH)
LRER    35   RR     . 67.. Load Rounded (SH<-LH)
LEDR    35   RR     . ..9Z Load Rounded (SH<-LH)
AXR     36   RR     A 679Z Add Normalized (EH)
SXR     37   RR     A 679Z Subtract Normalized (EH)
LER     38   RR     . 679Z Load (SH)
CER     39   RR     C 679Z Compare (SH)
AER     3A   RR     A 679Z Add Normalized (SH)
SER     3B   RR     A 679Z Subtract Normalized (SH)
MER     3C   RR     A 679Z Multiply Normalized (LH<-SH)
DER     3D   RR     A 679Z Divide Normalized (SH)
AUR     3E   RR     A 679Z Add Unnormalized (SH)
SUR     3F   RR     A 679Z Subtract Unnormalized (SH)
STH     40   RXa    . 679Z Store Halfword (16) =2 . H
LA      41   RXa    . 679Z Load Address
STC     42   RXa    . 679Z Store Character (8) =1
IC      43   RXa    . 679Z Insert Character (8) =1
EX      44   RXa    . 679Z Execute
BAL     45   RXa    . 679Z Branch And Link
BCT     46   RXa    . 679Z Branch on Count
BC      47   RXb    B 679Z Branch on Condition
LH      48   RXa    . 679Z Load Halfword (32<-16) =2 . H
CH      49   RXa    C 679Z Compare Halfword (32<-16) =2 . H
AH      4A   RXa    A 679Z Add Halfword (32<-16) =2 . H
SH      4B   RXa    A 679Z Subtract Halfword (32<-16) =2 . H
MH      4C   RXa    A 679Z Multiply Halfword (32<-16) =2 . H
BAS     4D   RXa    . 679Z Branch And Save
CVD     4E   RXa    . 679Z Convert to Decimal (32) =8 . P
CVB     4F   RXa    . 679Z Convert to Binary (32) =8 . P
ST      50   RXa    . 679Z Store (32) =4 . F
LAE     51   RXa    . 679Z Load Address Extended
N       54   RXa    A 679Z And (32) =4 . X
CL      55   RXa    C 679Z Compare Logical (32) =4 . F
O       56   RXa    A 679Z Or (32) =4 . X
X       57   RXa    A 679Z Exclusive-Or (32) =4 . X
L       58   RXa    . 679Z Load (32) =4 . F
C       59   RXa    C 679Z Compare (32) =4 . F
A       5A   RXa    A 679Z Add (32) =4 . F
S       5B   RXa    A 679Z Subtract (32) =4 . F
M       5C   RXa    A 679Z Multiply (64<-32) =4 . F
D       5D   RXa    A 679Z Divide (32<-64) =4 . F
AL      5E   RXa    A 679Z Add Logical (32) =4 . F
SL      5F   RXa    A 679Z Subtract Logical (32) =4 . F
STD     60   RXa    . 679Z Store (Long) =8 . D
MXD     67   RXa    A 679Z Multiply (EH<-LH) =8 . D
LD      68   RXa    . 679Z Load (Long) =8 . D
CD      69   RXa    C 679Z Compare (LH) =8 . D
AD      6A   RXa    A 679Z Add Normalized (LH) =8 . D
SD      6B   RXa    A 679Z Subtract Normalized (LH) =8 . D
MD      6C   RXa    A 679Z Multiply (LH) =8 . D
DD      6D   RXa    A 679Z Divide (LH) =8 . D
AW      6E   RXa    A 679Z Add Unnormalized (LH) =8 . D
SW      6F   RXa    A 679Z Subtract Unnormalized (LH) =8 . D
STE     70   RXa    . 679Z Store (Short) =4 . E
MS      71   RXa    A .79Z Multiply Single (32) =4 . F
LE      78   RXa    . 679Z Load (Short) =4 . E
CE      79   RXa    C 679Z Compare (SH) =4 . E
AE      7A   RXa    A 679Z Add Normalized (SH) =4 . E
SE      7B   RXa    A 679Z Subtract Normalized (SH) =4 . E
ME      7C   RXa    A 679Z Multiply (LH<-SH) =4 . E
DE      7D   RXa    A 679Z Divide (SH) =4 . E
AU      7E   RXa    A 679Z Add Unnormalized (SH) =4 . E
SU      7F   RXa    A 679Z Subtract Unnormalized (SH) =4 . E
SSM     80   SI1    . 679Z Set System Mask
LPSW    82   SI1    c 679Z Load Program Status Word =8
DIAG    83   SI     . 679Z Diagnose
WRD     84   SI     . 67.. Write Direct
JXH     84   RSI    . ..9Z Branch Relative on Index High (32)
RDD     85   SI     . 67.. Read Direct
JXLE    85   RSI    . ..9Z Branch Relative on Index Low or Equal (32)
BXH     86   RSA    . 679Z Branch on Index High (32)
BXLE    87   RSA    . 679Z Branch on Index Low or Equal (32)
SRL     88   RSa    . 679Z Shift Right Single Logical (32)
SLL     89   RSa    . 679Z Shift Left Single Logical (32)
SRA     8A   RSa    A 679Z Shift Right Single Arithmetic (32)
SLA     8B   RSa    A 679Z Shift Left Single Arithmetic (32)
SRDL    8C   RSa    . 679Z Shift Right Double Logical (64)
SLDL    8D   RSa    . 679Z Shift Left Double Logical (64)
SRDA    8E   RSa    A 679Z Shift Right Double Arithmetic (64)
SLDA    8F   RSa    A 679Z Shift Left Double Arithmetic (64)
STM     90   RSA    . 679Z Store Multiple (32) =hM(4) . F
TM      91   SI0    M 679Z Test under Mask (8)
MVI     92   SI     . 679Z Move Immediate (8) =1
TS      93   SI1    c 679Z Test And Set (8) =1
NI      94   SI0    A 679Z And Immediate (8)
CLI     95   SI     C 679Z Compare Logical Immediate (8) =1
OI      96   SI0    A 679Z Or Immediate (8)
XI      97   SI0    A 679Z Exclusive-Or Immediate (8)
LM      98   RSA    . 679Z Load Multiple (32) =hM(4) . F
TRACE   99   RSA    . ..9Z Trace (32)
LAM     9A   RSA    . .79Z Load Access Multiple =hM(4) . F
STAM    9B   RSA    . .79Z Store Access Multiple =hM(4) . F
SIO     9C00 SI2    c 67.. Start I/O
SIOF    9C01 SI2    c .79. Start I/O Fast Release
RIO     9C02 SI2    c .79. Resume I/O
TIO     9D00 SI2    c 67.. Test I/O
CLRIO   9D01 SI2    c .79. Clear I/O
HIO     9E00 SI2    c 67.. Halt I/O
HDV     9E01 SI2    c .79. Halt Device
TCH     9F00 SI2    c .79Z Test Channel
CLRCH   9F01 SI2    c ..9Z Clear Channel
VAE     A400 VST    . .7.. Vector Add [Vec+Stg] (SH)
VSE     A401 VST    . .7.. Vector Subtract [Vec-Stg] (SH)
VME     A402 VST    . .7.. Vector Multiply [Vec*Stg] (LH<-SH)
VDE     A403 VST    . .7.. Vector Divide [Vec/Stg] (SH)
VMAE    A404 VST    . .7.. Vector Multiply and Add [Vec*Stg] (LH<-SH)
VMSE    A405 VST    . .7.. Vector Multiply and Subtract [Vec*Stg] (LH<-SH)
VMCE    A406 VST    . .7.. Vector Multiply and Accumulate [Vec*Stg] (LH<-SH)
VACE    A407 VST2   . .7.. Vector Accumulate [Stg] (SH)
VCE     A408 VSTm   . .7.. Vector Compare [Vec:Stg] (SH)
VL      A409 VST2   . .7.. Vector Load [Vec<-Stg] (32)
*VLE    A409 VST2   . .7.. Vector Load [Vec<-Stg] (SH)
VLM     A40A VST2   . .7.. Vector Load Matched [Vec<-Stg] (32)
*VLME   A40A VST2   . .7.. Vector Load Matched [Vec<-Stg] (SH)
VLY     A40B VST2   . .7.. Vector Load Expanded (32)
*VLYE   A40B VST2   . .7.. Vector Load Expanded (SH)
VST     A40D VST2   . .7.. Vector Store [Stg<-Vec] (32)
*VSTE   A40D VST2   . .7.. Vector Store [Stg<-Vec] (SH)
VSTM    A40E VST2   . .7.. Vector Store Matched [Stg<-Vec] (32)
*VSTM   A40E VST2   . .7.. Vector Store Matched [Stg<-Vec] (SH)
VSTK    A40F VST2   . .7.. Vector Store Compressed [Stg<-Vec] (32)
*VSTK   A40F VST2   . .7.. Vector Store Compressed [Stg<-Vec] (SH)
VAD     A410 VST    . .7.. Vector Add [Vec+Stg] (LH)
VSD     A411 VST    . .7.. Vector Subtract [Vec-Stg] (LH)
VMD     A412 VST    . .7.. Vector Multiply [Vec*Stg] (LH)
VDD     A413 VST    . .7.. Vector Divide [Vec/Stg] (LH)
VMAD    A414 VST    . .7.. Vector Multiply and Add [Vec*Stg] (LH)
VMSD    A415 VST    . .7.. Vector Multiply and Subtract [Vec*Stg] (LH)
VMCD    A416 VST    . .7.. Vector Multiply and Accumulate [Vec*Stg] (LH)
VACD    A417 VST2   . .7.. Vector Accumulate [Stg] (LH)
VCD     A418 VSTm   . .7.. Vector Compare [Vec:Stg] (LH)
VLD     A419 VST2   . .7.. Vector Load [Vec<-Stg] (LH)
VLMD    A41A VST2   . .7.. Vector Load Matched [Vec<-Stg] (LH)
VLYD    A41B VST2   . .7.. Vector Load Expanded (LH)
VSTD    A41D VST2   . .7.. Vector Store [Stg<-Vec] (LH)
VSTMD   A41E VST2   . .7.. Vector Store Matched [Stg<-Vec] (LH)
VSTKD   A41F VST2   . .7.. Vector Store Compressed [Stg<-Vec] (LH)
VA      A420 VST    . .7.. Vector Add [Vec+Stg] (32)
VS      A421 VST    . .7.. Vector Subtract [Vec-Stg] (32)
VM      A422 VST    . .7.. Vector Multiply [Vec*Stg] (32)
VN      A424 VST    . .7.. Vector AND [Vec&Stg] (32)
VO      A425 VST    . .7.. Vector OR [Vec&Stg] (32)
VX      A426 VST    . .7.. Vector Exclusive OR [Vec&Stg] (32)
VC      A428 VSTm   . .7.. Vector Compare [Vec:Stg] (32)
VLH     A429 VST2   . .7.. Vector Load Halfword [Vec<-Stg] (16)
VLINT   A42A VST2   . .7.. Vector Load Integer Vector
VSTH    A42D VST2   . .7.. Vector Store Halfword [Stg<-Vec] (16)
VAES    A480 QST    . .7.. Vector Add [Reg+Stg] (SH)
VSES    A481 QST    . .7.. Vector Subtract [Reg-Stg] (SH)
VMES    A482 QST    . .7.. Vector Multiply [Reg*Stg] (LH<-SH)
VDES    A483 QST    . .7.. Vector Divide [Reg/Stg] (SH)
VMAES   A484 QST    . .7.. Vector Multiply and Add [Reg*Stg] (LH<-SH)
VMSES   A485 QST    . .7.. Vector Multiply and Subtract [Reg*Stg] (LH<-SH)
VCES    A488 QSTm   . .7.. Vector Compare [Reg:Stg] (SH)
VADS    A490 QST    . .7.. Vector Add [Reg+Stg] (LH)
VSDS    A491 QST    . .7.. Vector Subtract [Reg-Stg] (LH)
VMDS    A492 QST    . .7.. Vector Multiply [Reg*Stg] (LH)
VDDS    A493 QST    . .7.. Vector Divide [Reg/Stg] (LH)
VMADS   A494 QST    . .7.. Vector Multiply and Add [Reg*Stg] (LH)
VMSDS   A495 QST    . .7.. Vector Multiply and Subtract [Reg*Stg] (LH)
VCDS    A498 QSTm   . .7.. Vector Compare [Reg:Stg] (LH)
VAS     A4A0 QST    . .7.. Vector Add [Reg+Stg] (32)
VSS     A4A1 QST    . .7.. Vector Subtract [Reg-Stg] (32)
VMS     A4A2 QST    . .7.. Vector Multiply [Reg*Stg] (32)
VNS     A4A4 QST    . .7.. Vector AND [Reg&Stg] (32)
VOS     A4A5 QST    . .7.. Vector OR [Reg&Stg] (32)
VXS     A4A6 QST    . .7.. Vector Exclusive OR [Reg&Stg] (32)
VCS     A4A8 QSTm   . .7.. Vector Compare [Reg:Stg] (32)
IIHH    A50  RIax   . ...Z Insert Immediate High High (0-15)
VAER    A500 VV     . .7.. Vector Add [Vec+Vec] (SH)
VSER    A501 VV     . .7.. Vector Subtract [Vec-Vec] (SH)
VMER    A502 VV     . .7.. Vector Multiply [Vec*Vec] (LH<-SH)
VDER    A503 VV     . .7.. Vector Divide [Vec/Vec] (SH)
VMCER   A506 VV     . .7.. Vector Multiply and Accumulate [Vec*Vec] (LH<-SH)
VACER   A507 VV2    . .7.. Vector Accumulate [Vec] (SH)
VCER    A508 VVm    . .7.. Vector Compare [Vec:Vec] (SH)
VLR     A509 VV2    . .7.. Vector Load [Vec<-Vec] (32)
*VLER   A509 VV2    . .7.. Vector Load [Vec<-Vec] (SH)
VLMR    A50A VV2    . .7.. Vector Load Matched [Vec<-Vec] (32)
*VLME   A50A VV2    . .7.. Vector Load Matched [Vec<-Vec] (SH)
VLZR    A50B VV     . .7.. Vector Load Zero (32)
*VLZE   A50B VV     . .7.. Vector Load Zero (SH)
IIHL    A51  RIax   . ...Z Insert Immediate High Low (16-31)
VADR    A510 VV     . .7.. Vector Add [Vec+Vec] (LH)
VSDR    A511 VV     . .7.. Vector Subtract [Vec-Vec] (LH)
VMDR    A512 VV     . .7.. Vector Multiply [Vec*Vec] (LH)
VDDR    A513 VV     . .7.. Vector Divide [Vec/Vec] (LH)
VMCDR   A516 VV     . .7.. Vector Multiply and Accumulate [Vec*Vec] (LH)
VACDR   A517 VV2    . .7.. Vector Accumulate [Vec] (LH)
VCDR    A518 VVm    . .7.. Vector Compare [Vec:Vec] (LH)
VLDR    A519 VV2    . .7.. Vector Load [Vec<-Vec] (LH)
VLMDR   A51A VV2    . .7.. Vector Load Matched [Vec<-Vec] (LH)
VLZDR   A51B VV     . .7.. Vector Load Zero (LH)
IILH    A52  RIax   . ...Z Insert Immediate Low High (32-47)
VAR     A520 VV     . .7.. Vector Add [Vec+Vec] (32)
VSR     A521 VV     . .7.. Vector Subtract [Vec-Vec] (32)
VMR     A522 VV     . .7.. Vector Multiply [Vec*Vec] (32)
VNR     A524 VV     . .7.. Vector AND [Vec&Vec] (32)
VOR     A525 VV     . .7.. Vector OR [Vec&Vec] (32)
VXR     A526 VV     . .7.. Vector Exclusive OR [Vec&Vec] (32)
VCR     A528 VVm    . .7.. Vector Compare [Vec:Vec] (32)
IILL    A53  RIax   . ...Z Insert Immediate Low Low (48-63)
NIHH    A54  RIax   A ...Z And Immediate High High (0-15)
VLPER   A540 VV2    . .7.. Vector Load Positive [Vec<-Vec] (SH)
VLNER   A541 VV2    . .7.. Vector Load Negative [Vec<-Vec] (SH)
VLCER   A542 VV2    . .7.. Vector Load Complement (SH)
NIHL    A55  RIax   A ...Z And Immediate High Low (16-31)
VLPDR   A550 VV2    . .7.. Vector Load Positive [Vec<-Vec] (LH)
VLNDR   A551 VV2    . .7.. Vector Load Negative [Vec<-Vec] (LH)
VLCDR   A552 VV2    . .7.. Vector Load Complement (LH)
NILH    A56  RIax   A ...Z And Immediate Low High (32-47)
VLPR    A560 VV2    . .7.. Vector Load Positive [Vec<-Vec] (32)
VLNR    A561 VV2    . .7.. Vector Load Negative [Vec<-Vec] (32)
VLCR    A562 VV2    . .7.. Vector Load Complement (32)
NILL    A57  RIax   A ...Z And Immediate Low Low (48-63)
OIHH    A58  RIax   A ...Z Or Immediate High High (0-15)
VAEQ    A580 QV     . .7.. Vector Add [Reg+Vec] (SH)
VSEQ    A581 QV     . .7.. Vector Subtract [Reg-Vec] (SH)
VMEQ    A582 QV     . .7.. Vector Multiply [Reg*Vec] (LH<-SH)
VDEQ    A583 QV     . .7.. Vector Divide [Reg/Vec] (SH)
VMAEQ   A584 QV     . .7.. Vector Multiply and Add [Reg*Vec] (LH<-SH)
VMSEQ   A585 QV     . .7.. Vector Multiply and Subtract [Reg*Vec] (LH<-SH)
VCEQ    A588 QVm    . .7.. Vector Compare [Reg:Vec] (SH)
VLEQ    A589 QV2    . .7.. Vector Load [Reg<-Vec] (SH)
VLMEQ   A58A QV2    . .7.. Vector Load Matched [Reg<-Vec] (SH)
OIHL    A59  RIax   A ...Z Or Immediate High Low (16-31)
VADQ    A590 QV     . .7.. Vector Add [Reg+Vec] (LH)
VSDQ    A591 QV     . .7.. Vector Subtract [Reg-Vec] (LH)
VMDQ    A592 QV     . .7.. Vector Multiply [Reg*Vec] (LH)
VDDQ    A593 QV     . .7.. Vector Divide [Reg/Vec] (LH)
VMADQ   A594 QV     . .7.. Vector Multiply and Add [Reg*Vec] (LH)
VMSDQ   A595 QV     . .7.. Vector Multiply and Subtract [Reg*Vec] (LH)
VCDQ    A598 QVm    . .7.. Vector Compare [Reg:Vec] (LH)
VLDQ    A599 QV2    . .7.. Vector Load [Reg<-Vec] (LH)
VLMDQ   A59A QV2    . .7.. Vector Load Matched [Reg<-Vec] (LH)
OILH    A5A  RIax   A ...Z Or Immediate Low High (32-47)
VAQ     A5A0 QV     . .7.. Vector Add [Reg+Vec] (32)
VSQ     A5A1 QV     . .7.. Vector Subtract [Reg-Vec] (32)
VMQ     A5A2 QV     . .7.. Vector Multiply [Reg*Vec] (32)
VNQ     A5A4 QV     . .7.. Vector AND [Reg&Vec] (32)
VOQ     A5A5 QV     . .7.. Vector OR [Reg&Vec] (32)
VXQ     A5A6 QV     . .7.. Vector Exclusive OR [Reg&Vec] (32)
VCQ     A5A8 QVm    . .7.. Vector Compare [Reg:Vec] (32)
VLQ     A5A9 QV2    . .7.. Vector Load [Reg<-Vec] (32)
VLMQ    A5AA QV2    . .7.. Vector Load Matched [Reg<-Vec] (32)
OILL    A5B  RIax   A ...Z Or Immediate Low Low (48-63)
LLIHH   A5C  RIax   . ...Z Load Logical Immediate High High (0-15)
LLIHL   A5D  RIax   . ...Z Load Logical Immediate High Low (16-31)
LLILH   A5E  RIax   . ...Z Load Logical Immediate Low High (32-47)
LLILL   A5F  RIax   . ...Z Load Logical Immediate Low Low (48-63)
VMXSE   A600 VR     . .7.. Vector Maximum Signed (SH)
VMNSE   A601 VR     . .7.. Vector Minimum Signed (SH)
VMXAE   A602 VR     . .7.. Vector Maximum Absolute (SH)
VLELE   A608 VR     . .7.. Vector Load Element (SH)
VXELE   A609 VR     . .7.. Vector Extract Element (SH)
VMXSD   A610 VR     . .7.. Vector Maximum Signed (LH)
VMNSD   A611 VR     . .7.. Vector Minimum Signed (LH)
VMXAD   A612 VR     . .7.. Vector Maximum Absolute (LH)
VLELD   A618 VR     . .7.. Vector Load Element (LH)
VXELD   A619 VR     . .7.. Vector Extract Element (LH)
VSPSD   A61A VR     . .7.. Vector Sum Partial Sums (LH)
VZPSD   A61B VR1    . .7.. Vector Zero Partial Sums
VLEL    A628 VR     . .7.. Vector Load Element (32)
VXEL    A629 VR     . .7.. Vector Extract Element (32)
VTVM    A640 RRE0   c .7.. Vector Test VMR
VCVM    A641 RRE0   . .7.. Vector Complement VMR
VCZVM   A642 RRE1   c .7.. Vector Count Left Zeros in VMR
VCOVM   A643 RRE1   c .7.. Vector Count Ones in VMR
VXVC    A644 RRE1   . .7.. Vector Extract VCT
VLVCU   A645 RRE1   c .7.. Vector Load VCT and Update
VXVMM   A646 RRE1   . .7.. Vector Extract Vector Mask Mode
VRRS    A648 RRE1   c .7.. Vector Restore VR
VRSVC   A649 RRE1   c .7.. Vector Save Changed VR
VRSV    A64A RRE1   c .7.. Vector Save VR
VLVM    A680 VS     . .7.. Vector Load VMR
VLCVM   A681 VS     . .7.. Vector Load VMR Complement
VSTVM   A682 VS     . .7.. Vector Store VMR
VNVM    A684 VS     . .7.. Vector AND to VMR
VOVM    A685 VS     . .7.. Vector OR to VMR
VXVM    A686 VS     . .7.. Vector Exclusive OR to VMR
VSRSV   A6C0 S      . .7.. Vector Save VSR
VMRSV   A6C1 S      . .7.. Vector Save VMR
VSRRS   A6C2 S      . .7.. Vector Restore VSR
VMRRS   A6C3 S      . .7.. Vector Restore VMR
VLVCA   A6C4 S      c .7.. Vector Load VCT from Address
VRCL    A6C5 S      . .7.. Vector Clear VR
VSVMM   A6C6 S      . .7.. Vector Set Vector Mask Mode
VSTVP   A6C8 S      . .7.. Vector Store Vector Parameters
VACSV   A6CA S      . .7.. Vector Save VAC
VACRS   A6CB S      . .7.. Vector Restore VAC
TMLH    A70  RIax   M ..9Z Test under Mask Low High (32-47)
TMLL    A71  RIax   M ..9Z Test under Mask Low Low (48-63)
TMHH    A72  RIax   M ..9Z Test under Mask High High (0-15)
TMHL    A73  RIax   M ..9Z Test under Mask High Low (16-31)
BRC     A74  RIc    R ..9Z Branch Relative on Condition
JAS     A75  RIb   R4 ..9Z Branch Relative And Save
JCT     A76  RIb   R4 ..9Z Branch Relative on Count (32)
JCTG    A77  RIb   R4 ...Z Branch Relative on Count (64)
LHI     A78  RIa    . ..9Z Load Halfword Immediate (32<-16)
LGHI    A79  RIa    . ...Z Load Halfword Immediate (64<-16)
AHI     A7A  RIa    A ..9Z Add Halfword Immediate (32<-16)
AGHI    A7B  RIa    A ...Z Add Halfword Immediate (64<-16)
MHI     A7C  RIa    A ..9Z Multiply Halfword Immediate (32<-16)
MGHI    A7D  RIa    A ...Z Multiply Halfword Immediate (64<-16)
CHI     A7E  RIa    C ..9Z Compare Halfword Immediate (32<-16)
CGHI    A7F  RIa    C ...Z Compare Halfword Immediate (64<-16)
MVCLE   A8   RSA    c ..9Z Move Long Extended
CLCLE   A9   RSA    C ..9Z Compare Logical Long Extended
STNSM   AC   SI     . .79Z Store Then And System Mask =1
STOSM   AD   SI     . .79Z Store Then Or System Mask =1
SIGP    AE   RSA    c .79Z Signal Processor
MC      AF   SI     . .79Z Monitor Call
LRA     B1   RXa    c .79Z Load Real Address (32) =4 . A
CONCS   B200 S      . .7.. Connect Channel Set
DISCS   B201 S      . .7.. Disconnect Channel Set
STIDP   B202 S      . .79Z Store CPU ID =8
STIDC   B203 S      c .79Z Store Channel ID (370) =4
SCK     B204 S      c .79Z Set Clock =8
STCK    B205 S      c .79Z Store Clock =8
SCKC    B206 S      . .79Z Set Clock Comparator =8
STCKC   B207 S      . .79Z Store Clock Comparator =8
SPT     B208 S      . .79Z Set CPU Timer =8
STPT    B209 S      . .79Z Store CPU Timer =8
SPKA    B20A S      . .79Z Set PSW Key From Address
IPK     B20B S      . .79Z Insert PSW Key
PTLB    B20D S      . ..9Z Purge TLB
SPX     B210 S      . .79Z Set Prefix =4
STPX    B211 S      . .79Z Store Prefix =4
STAP    B212 S      . .79Z Store CPU Address =2
RRB     B213 S      . .79. Reset Reference Bit
SIE     B214 S      . .79. Start Interpretive Execution
PC      B218 S      . ..9Z Program Call
SAC     B219 S      . ..9Z Set Address Space Control
CFC     B21A S      C ..9Z Compare And Form Codeword
IPTE    B221 RRFa   . ..9Z Invalidate Page Table Entry
IPM     B222 RRE1   . ..9Z Insert Program Mask
IVSK    B223 RRE    . ..9Z Insert Virtual Storage Key
IAC     B224 RRE1   c ..9Z Insert Address Space Control
SSAR    B225 RRE1   . ..9Z Set Secondary ASN
EPAR    B226 RRE1   . ..9Z Extract Primary ASN
ESAR    B227 RRE1   . ..9Z Extract Secondary ASN
PT      B228 RRE    . ..9Z Program Transfer
ISKE    B229 RRE    . ..9Z Insert Storage Key Extended
RRBE    B22A RRE    . ..9Z Reset Storage Key Extended
SSKE    B22B RRFc   c ..9Z Set Storage Key Extended
TB      B22C RRE    c ..9Z Test Block
DXR     B22D RRE    A ..9Z Divide
PGIN    B22E RRE    c ..9Z Page In
PGOUT   B22F RRE    c ..9Z Page Out
CSCH    B230 S      c ..9Z Clear Subchannel
HSCH    B231 S      c ..9Z Halt Subchannel
MSCH    B232 S      c ..9Z Modify Subchannel
SSCH    B233 S      c ..9Z Start Subchannel
STSCH   B234 S      c ..9Z Store Subchannel
TSCH    B235 S      c ..9Z Test Subchannel
TPI     B236 S      c ..9Z Test Pending Interruption
SAL     B237 S      . ..9Z Set Address Limit
RSCH    B238 S      c ..9Z Resume Subchannel
STCRW   B239 S      c ..9Z Store Channel Report Word
STCPS   B23A S      . ..9Z Store Channel Path Status
RCHP    B23B S      c ..9Z Reset Channel Path
SCHM    B23C S      . ..9Z Set Channel Monitor
BAKR    B240 RRE    . ..9Z Branch And Stack
CKSM    B241 RRE    c ..9Z Checksum
addfrr  B242 RRE    . .7.. MVS Assist: Add FRR
SQDR    B244 RRE    . ..9Z Square Root (LH)
SQER    B245 RRE    . ..9Z Square Root (SH)
STURA   B246 RRE    . ..9Z Store Using Real Address (32)
MSTA    B247 RRE1   . ..9Z Modify Stacked state
PALB    B248 RRE    . ..9Z Purge ALB
EREG    B249 RRE    . ..9Z Extract Stacked Registers (32)
ESTA    B24A RRE    c ..9Z Extract Stacked State
LURA    B24B RRE    . ..9Z Load Using Real Address (32)
TAR     B24C RRE    c ..9Z Test Access
CPYA    B24D RRE    . ..9Z Copy Access
SAR     B24E RRE    . ..9Z Set Access
EAR     B24F RRE    . ..9Z Extract Access
CSP     B250 RRE    C ..9Z Compare And Swap And Purge (32)
MSR     B252 RRE    A ..9Z Multiply Single (32)
MVPG    B254 RRE    c ..9Z Move Page
MVST    B255 RRE    c ..9Z Move String
CUSE    B257 RRE    C ..9Z Compare Until Substring Equal
BSG     B258 RRE    . ..9Z Branch in Subspace Group
BSA     B25A RRE    . ..9Z Branch And Set Authority
CLST    B25D RRE    C ..9Z Compare Logical String
SRST    B25E RRE    c ..9Z Search String
CMPSC   B263 RRE    c ..9Z Compression Call
XSCH    B276 S      c ..9Z Cancel Subchannel
RP      B277 S      . ..9Z Resume Program
STCKE   B278 S      c ..9Z Store Clock Extended =16
SACF    B279 S      . ..9Z Set Address Space Control Fast
STCKF   B27C S      c ..9Z Store Clock Fast =8
STSI    B27D S      c ..9Z Store System Information
SRNM    B299 S      . ..9Z Set BFP Rounding Mode (2 bit)
STFPC   B29C S      . ..9Z Store Floating Point Control =4
LFPC    B29D S      . ..9Z Load Floating Point Control =4
TRE     B2A5 RRE    c ..9Z Translate Extended
CU21    B2A6 RRFc   c ..9Z Convert UTF-16 to UTF-8
CU12    B2A7 RRFc   c ..9Z Convert UTF-8 to UTF-16
STFLE   B2B0 S      c ..9Z Store Facility List Extended
STFL    B2B1 S      . ..9Z Store Facility List
LPSWE   B2B2 S      c ..9Z Load PSW Extended =16
SRNMB   B2B8 S      . ..9Z Set BFP Rounding Mode (3 bit)
SRNMT   B2B9 S      . ..9Z Set DFP Rounding Mode
LFAS    B2BD S      . ..9Z Load Floating Point Control And Signal =4
PPA     B2E8 RRFc3  . ..9Z Perform Processor Assist
ETND    B2EC RRE1   . ..9Z Extract Transaction Nesting Depth
TEND    B2F8 S      . ..9Z Transaction End
NIAI    B2FA IE     . ..9Z Next Instruction Access Intent
TABORT  B2FC S      . ..9Z Transaction Abort
TRAP4   B2FF S      . ..9Z Trap
LPEBR   B300 RRE    A ..9Z Load Positive (SB)
LNEBR   B301 RRE    A ..9Z Load Negative (SB)
LTEBR   B302 RRE    A ..9Z Load and Test (SB)
LCEBR   B303 RRE    A ..9Z Load Complement (SB)
LDEBR   B304 RRE    . ..9Z Load Lengthened (LB<-SB)
LXDBR   B305 RRE    . ..9Z Load Lengthened (EB<-LB)
LXEBR   B306 RRE    . ..9Z Load Lengthened (EB<-SB)
MXDBR   B307 RRE    A ..9Z Multiply (EB<-LB)
KEBR    B308 RRE    C ..9Z Compare And Signal (SB)
CEBR    B309 RRE    C ..9Z Compare (SB)
AEBR    B30A RRE    A ..9Z Add (SB)
SEBR    B30B RRE    A ..9Z Subtract (SB)
MDEBR   B30C RRE    A ..9Z Multiply (LB<-SB)
DEBR    B30D RRE    A ..9Z Divide (SB)
MAEBR   B30E RRD    A ..9Z Multiply And Add (SB)
MSEBR   B30F RRD    A ..9Z Multiply And Subtract (SB)
LPDBR   B310 RRE    A ..9Z Load Positive (LB)
LNDBR   B311 RRE    A ..9Z Load Negative (LB)
LTDBR   B312 RRE    A ..9Z Load and Test (LB)
LCDBR   B313 RRE    A ..9Z Load Complement (LB)
SQEBR   B314 RRE    . ..9Z Square Root (SB)
SQDBR   B315 RRE    . ..9Z Square Root (LB)
SQXBR   B316 RRE    . ..9Z Square Root (EB)
MEEBR   B317 RRE    A ..9Z Multiply (LB)
KDBR    B318 RRE    C ..9Z Compare And Signal (LB)
CDBR    B319 RRE    C ..9Z Compare (LB)
ADBR    B31A RRE    A ..9Z Add (LB)
SDBR    B31B RRE    A ..9Z Subtract (LB)
MDBR    B31C RRE    A ..9Z Multiply (LB)
DDBR    B31D RRE    A ..9Z Divide (LB)
MADBR   B31E RRD    A ..9Z Multiply And Add (LB)
MSDBR   B31F RRD    A ..9Z Multiply And Subtract (LB)
LDER    B324 RRE    . ..9Z Load Lengthened (LH<-SH)
LXDR    B325 RRE    . ..9Z Load Lengthened (EH<-LH)
LXER    B326 RRE    . ..9Z Load Lengthened (EH<-SH)
MAER    B32E RRD    A ..9Z Multiply And Add (SH)
MSER    B32F RRD    A ..9Z Multiply And Subtract (SH)
SQXR    B336 RRE    . ..9Z Square Root Extended (EH)
MEER    B337 RRE    A ..9Z Multiply And Subtract (SH)
MAYLR   B338 RRD    A ..9Z Multiply And Add Unnormalized (EHL<-LH)
MYLR    B339 RRD    A ..9Z Multiply Unnormalized (EHL<-LH)
MAYR    B33A RRD    A ..9Z Multiply And Add Unnormalized (EH<-LH)
MYR     B33B RRD    A ..9Z Multiply Unnormalized (EH<-LH)
MAYHR   B33C RRD    A ..9Z Multiply And Add Unnormalized (EHH<-LH)
MYHR    B33D RRD    A ..9Z Multiply Unnormalized (LH)
MADR    B33E RRD    A ..9Z Multiply And Add (LH)
MSDR    B33F RRD    A ..9Z Multiply And Subtract (LH)
LPXBR   B340 RRE    A ..9Z Load Positive (EB)
LNXBR   B341 RRE    A ..9Z Load Negative (EB)
LTXBR   B342 RRE    A ..9Z Load and Test (EB)
LCXBR   B343 RRE    A ..9Z Load Complement (EB)
LEDBR   B344 RRE    . ..9Z Load Rounded (SB<-LB)
LDXBR   B345 RRE    . ..9Z Load Rounded (LB<-EB)
LEXBR   B346 RRE    . ..9Z Load Rounded (SB<-EB)
FIXBR   B347 RRFe   . ..9. Load FP Integer (EB)
FIXBRA  B347 RRFe4  . ...Z Load FP Integer (EB)
KXBR    B348 RRE    C ..9Z Compare And Signal (EB)
CXBR    B349 RRE    C ..9Z Compare (EB)
AXBR    B34A RRE    A ..9Z Add (EB)
SXBR    B34B RRE    A ..9Z Subtract (EB)
MXBR    B34C RRE    A ..9Z Multiply (EB)
DXBR    B34D RRE    A ..9Z Divide (EB)
TBEDR   B350 RRFe   A ..9Z Convert HFP to BFP (SB<-LH)
TBDR    B351 RRFe   A ..9Z Convert HFP to BFP (LB<-LH)
DIEBR   B353 RRFb4  A ..9Z Divide to Integer (SB)
FIEBR   B357 RRFe   . ..9. Load FP Integer (SB)
FIEBRA  B357 RRFe4  . ...Z Load FP Integer (SB)
THDER   B358 RRE    A ..9Z Convert BFP to HFP (LH<-SB)
THDR    B359 RRE    A ..9Z Convert BFP to HFP (LH<-LB)
DIDBR   B35B RRFb4  A ..9Z Divide to Integer (LB)
FIDBR   B35F RRFb   . ..9Z Load FP Integer (LB)
LPXR    B360 RRE    A ..9Z Load Positive (EH)
LNXR    B361 RRE    A ..9Z Load Negative (EH)
LTXR    B362 RRE    A ..9Z Load and Test (EH)
LCXR    B363 RRE    A ..9Z Load Complement (EH)
LXR     B365 RRE    . ..9Z Load (EH)
LEXR    B366 RRE    . ..9Z Load Rounded (SH<-EH)
FIXR    B367 RRE    . ..9Z Load FP Integer (EH)
CXR     B369 RRE    C ..9Z Compare (EH)
LPDFR   B370 RRE    A ..9Z Load Positive (Long)
LNDFR   B371 RRE    A ..9Z Load Negative (Long)
CPSDR   B372 RRFb   . ..9Z Copy Sign (Long)
LCDFR   B373 RRE    A ..9Z Load Complement (Long)
LZER    B374 RRE1   . ..9Z Load Zero (Short)
LZDR    B375 RRE1   . ..9Z Load Zero (Long)
LZXR    B376 RRE1   . ..9Z Load Zero (E)
FIER    B377 RRE    . ..9Z Load FP Integer (SH)
FIDR    B37F RRE    . ..9Z Load FP Integer (LH)
SFPC    B384 RRE1   . ..9Z Set Floating Point Control
SFASR   B385 RRE1   . ..9Z Set Floating Point Control and Signal
EFPC    B38C RRE1   . ..9Z Extract Floating Point Control
CELFBR  B390 RRFe4  . ...Z Convert from Logical (SB<-32)
CDLFBR  B391 RRFe4  . ...Z Convert from Logical (LB<-32)
CXLFBR  B392 RRFe4  . ...Z Convert from Logical (SB<-32)
CEFBR   B394 RRE    . ..9. Convert from Logical (EB<-32)
CEFBRA  B394 RRFe4  . ...Z Convert from Logical (EB<-32)
CDFBR   B395 RRE    . ..9Z Convert from Fixed (LB<-32)
CXFBR   B396 RRE    . ..9Z Convert from Fixed (EB<-32)
CFEBR   B398 RRFe   A ..9. Convert to Fixed (32<-SB)
CFEBRA  B398 RRFe4  A ...Z Convert to Fixed (32<-SB)
CFDBR   B399 RRFe   A ..9. Convert to Fixed (32<-LB)
CFDBRA  B399 RRFe4  A ...Z Convert to Fixed (32<-LB)
CFXBR   B39A RRFe   A ..9. Convert to Fixed (32<-EB)
CFXBRA  B39A RRFe4  A ...Z Convert to Fixed (32<-EB)
CLFEBR  B39C RRFe4  A ...Z Convert to Logical (32<-SB)
CLFDBR  B39D RRFe4  A ...Z Convert to Logical (32<-LB)
CLFXBR  B39E RRFe4  A ...Z Convert to Logical (32<-EB)
CELGBR  B3A0 RRFe4  . ...Z Convert from Locical (SB<-64)
CDLGBR  B3A1 RRFe4  . ...Z Convert from Locical (LB<-64)
CXLGBR  B3A2 RRFe4  . ...Z Convert from Locical (EB<-64)
CEGBR   B3A4 RRE    . ...Z Convert from Fixed (SB<-64)
CDGBR   B3A5 RRE    . ...Z Convert from Fixed (LB<-64)
CXGBR   B3A6 RRE    . ...Z Convert from Fixed (EB<-64)
CGEBRA  B3A8 RRFe4  A ...Z Convert to Fixed (64<-SB)
CGDBRA  B3A9 RRFe4  A ...Z Convert to Fixed (64<-LB)
CGXBRA  B3AA RRFe4  A ...Z Convert to Fixed (64<-EB)
CLGEBR  B3AC RRFe4  A ...Z Convert to Logical (64<-SB)
CLGDBR  B3AD RRFe4  A ...Z Convert to Logical (64<-LB)
CLGXBR  B3AE RRFe4  A ...Z Convert to Logical (64<-BB)
CEFR    B3B4 RRE    . ..9Z Convert from Fixed (SH<-32)
CDFR    B3B5 RRE    . ..9Z Convert from Fixed (LH<-32)
CXFR    B3B6 RRE    . ..9Z Convert from Fixed (EH<-32)
CFER    B3B8 RRFe   A ..9Z Convert to Fixed (32<-SH)
CFDR    B3B9 RRFe   A ..9Z Convert to Fixed (32<-LH)
CFXR    B3BA RRFe   A ..9Z Convert to Fixed (32<-EH)
LDGR    B3C1 RRE    . ..9Z Load FPR from GR (L<-64)
CEGR    B3C4 RRE    . ...Z Convert from Fixed (SH<-64)
CDGR    B3C5 RRE    . ...Z Convert from Fixed (LH<-64)
CXGR    B3C6 RRE    . ...Z Convert from Fixed (EH<-64)
CGER    B3C8 RRFe   A ...Z Convert to Fixed (64<-SH)
CGDR    B3C9 RRFe   A ...Z Convert to Fixed (64<-LH)
CGXR    B3CA RRFe   A ...Z Convert to Fixed (64<-EH)
LGDR    B3CD RRE    . ..9Z Load GR from FPR (64<-L)
MDTR    B3D0 RRFa   A ..9Z Multiply (LD)
DDTR    B3D1 RRFa   A ..9Z Divide (LD)
ADTR    B3D2 RRFa   A ..9Z Add (LD)
SDTR    B3D3 RRFa   A ..9Z Subtract (LD)
LDETR   B3D4 RRFd   . ..9Z Load Lengthened (LD<-SD)
LEDTR   B3D5 RRFe4  . ..9Z Load Rounded (SD<-LD)
LTDTR   B3D6 RRE    A ..9Z Load and Test (LD)
FIDTR   B3D7 RRFe4  . ..9Z Load FP Integer (LD)
MXTR    B3D8 RRFa   A ..9Z Multiply (ED)
DXTR    B3D9 RRFa   A ..9Z Divide (ED)
AXTR    B3DA RRFa   A ..9Z Add (ED)
SXTR    B3DB RRFa   A ..9Z Subtract (ED)
LXDTR   B3DC RRFd   . ..9Z Load Lengthened (ED<-LD)
LDXTR   B3DD RRFe4  . ..9Z Load Rounded (LD<-ED)
LTXTR   B3DE RRE    A ..9Z Load and Test (ED)
FIXTR   B3DF RRFe4  . ..9Z Load FP Integer (ED)
KDTR    B3E0 RRE    C ..9Z Compare and Signal (LD)
CGDTRA  B3E1 RRFe4  A ...Z Convert to Fixed (64<-LD)
CUDTR   B3E2 RRE    . ..9Z Convert to Unsigned Packed (64<-LD)
CSDTR   B3E3 RRFd   . ..9Z Convert to Signed Packed (64<-LD)
CDTR    B3E4 RRE    C ..9Z Compare (LD)
EEDTR   B3E5 RRE    . ..9Z Extract Biased Exponent (64<-LD)
ESDTR   B3E7 RRE    . ..9Z Extract Significance (64<-LD)
KXTR    B3E8 RRE    C ..9Z Compare and Signal (ED)
CGXTRA  B3E9 RRFe4  A ...Z Convert to Fixed (64<-ED)
CUXTR   B3EA RRE    . ...Z Convert to Unsigned Packed (128<-ED)
CSXTR   B3EB RRFd   . ...Z Convert to Signed Packed (128<-ED)
CXTR    B3EC RRE    C ..9Z Compare (ED)
EEXTR   B3ED RRE    . ...Z Extract Biased Exponent (64<-ED)
ESXTR   B3EF RRE    . ...Z Extract Significance (64<-ED)
CDGTR   B3F1 RRE    . ...Z Convert from Fixed (LD<-64)
CDUTR   B3F2 RRE    . ..9Z Convert from Unsigned Packed (LD<-64)
CDSTR   B3F3 RRE    . ..9Z Convert from Signed Packed (LD<-64)
CEDTR   B3F4 RRE    C ..9Z Compare Biased Exponent (LD)
QADTR   B3F5 RRFb4  . ..9Z Quantize (LD)
IEDTR   B3F6 RRFb   . ..9Z Insert Biased Exponent (LD<-64)
RRDTR   B3F7 RRFb4  . ..9Z Reround (LD)
CXGTR   B3F9 RRE    . ...Z Convert from Fixed (ED<-64)
CXUTR   B3FA RRE    . ...Z Convert from Unsigned Packed (ED<-128)
CXSTR   B3FB RRE    . ...Z Convert from Signed Packed (ED<-128)
CEXTR   B3FC RRE    C ...Z Compare Biased Exponent (ED)
QAXTR   B3FD RRFb4  . ..9Z Quantize (ED)
IEXTR   B3FE RRFb   . ..9Z Insert Biased Exponent (ED<-64)
RRXTR   B3FF RRFb4  . ..9Z Reround (ED)
STCTL   B6   RSA    . .79Z Store Control (32) =hM(4) . F
LCTL    B7   RSA    . .79Z Load Control (32) =hM(4) . F
LMC     B8   RSA    . ..9. Load Multiple Control (32) =hM(4) . F
LPGR    B900 RRE    A ...Z Load Positive (64)
LNGR    B901 RRE    A ...Z Load Negative (64)
LTGR    B902 RRE    A ...Z Load and Test (64)
LCGR    B903 RRE    A ...Z Load Complement (64)
LGR     B904 RRE    . ...Z Load (64)
LURAG   B905 RRE    . ...Z Load Using Real Address (64)
LGBR    B906 RRE    . ...Z Load Byte (64<-8)
LGHR    B907 RRE    . ...Z Load Halfword (64<-16)
AGR     B908 RRE    A ...Z Add (64)
SGR     B909 RRE    A ...Z Subtract (64)
ALGR    B90A RRE    A ...Z Add Logical (64)
SLGR    B90B RRE    A ...Z Subtract Logical (64)
MSGR    B90C RRE    A ...Z Multiply Single (64)
DSGR    B90D RRE    A ...Z Divide Single (64)
EREGG   B90E RRE    . ...Z Extract Stacked Registers (64)
LRVGR   B90F RRE    . ...Z Load Reversed (64)
LPGFR   B910 RRE    A ...Z Load Positive (64<-32)
LNGFR   B911 RRE    A ...Z Load Negative (64<-32)
LTGFR   B912 RRE    A ...Z Load and Test (64<-32)
LCGFR   B913 RRE    A ...Z Load Complement (64<-32)
LGFR    B914 RRE    . ...Z Load (64<-32)
LLGFR   B916 RRE    . ...Z Load Logical (64<-32)
LLGTR   B917 RRE    . ...Z Load Logical 31-Bits (64<-31)
AGFR    B918 RRE    A ...Z Add (64<-32)
SGFR    B919 RRE    A ...Z Subtract (64<-32)
ALGFR   B91A RRE    A ...Z Add Logical (64<-32)
SLGFR   B91B RRE    A ...Z Subtract Logical (64<-32)
MSGFR   B91C RRE    A ...Z Multiply Single (64<-32)
DSGFR   B91D RRE    A ...Z Divide Single (64<-32)
KMAC    B91E RRE    c ...Z Compute Message Authentication Code
LRVR    B91F RRE    . ..9Z Load Reversed (32)
CGR     B920 RRE    C ...Z Compare (64)
CLGR    B921 RRE    C ...Z Compare Logical (64)
STURG   B925 RRE    . ..9Z Store Using Real Address (64)
LBR     B926 RRE    . ..9Z Load Byte (32<-8)
LHR     B927 RRE    . ...Z Load Halfword (32<-16)
PCKMO   B928 RRE    . ...Z Perform Crypto Key Management Operations
KMA     B929 RRFb   c ...Z Cipher Message with Authentication
KMF     B92A RRE    c ...Z Cipher Message with Cipher Feedback
KMO     B92B RRE    c ...Z Cipher Message with Output Feedback
PCC     B92C RRE0   c ...Z Perform Crypto Computation
KMCTR   B92D RRFb   c ...Z Cipher Message with Counter
KM      B92E RRE    c ...Z Cipher Message
KMC     B92F RRE    c ...Z Cipher Message with Chaining
CGFR    B930 RRE    C ...Z Compare (64<-32)
CLGFR   B931 RRE    C ...Z Compare Logical (64<-32)
DFLTCC  B939 RRFa   c ...Z Deflate Conversion Call
KDSA    B93A RRE    c ...Z Compute Digital Signature Authentication
PRNO    B93C RRE    c ...Z Perform Random Number Operation
KIMD    B93E RRE    c ...Z Compute Intermediate Message Digest
KLMD    B93F RRE    c ...Z Compute Last Message Digest
CFDTR   B941 RRFe4  A ...Z Convert to Fixed (32<-LD)
CLGDTR  B942 RRFe4  A ...Z Convert to Logical (64<-LD)
CLFDTR  B943 RRFe4  A ...Z Convert to Logical (32<-LD)
BCTGR   B946 RRE    . ...Z Branch on Count (64)
CFXTR   B949 RRFe4  A ...Z Convert to Fixed (32<-ED)
CLGXTR  B94A RRFe4  A ...Z Convert to Logical (64<-ED)
CLFXTR  B94B RRFe4  A ...Z Convert to Logical (32<-ED)
CDFTR   B951 RRFe4  . ...Z Convert from Fixed (LD<-32)
CDLGTR  B952 RRFe4  . ...Z Convert from Logical (LD<-64)
CDLFTR  B953 RRFe4  . ...Z Convert from Logical (LD<-32)
CXFTR   B959 RRFe4  . ...Z Convert from Fixed (ED<-32)
CXLGTR  B95A RRFe4  . ...Z Convert from Logical (ED<-64)
CXLFTR  B95B RRFe4  . ...Z Convert from Logical (ED<-32)
CGRT    B960 RRFc3  c ...Z Compare and Trap (64)
CLGRT   B961 RRFc3  c ...Z Compare Logical and Trap (64)
NNGRK   B964 RRFa   A ...Z Not And (64)
OCGRK   B965 RRFa   A ...Z Or with Complement (64)
NOGRK   B966 RRFa   A ...Z Not Or (64)
NXGRK   B967 RRFa   A ...Z Not Exlusive Or (64)
CRT     B972 RRFc3  c ...Z Compare and Trap (32)
CLRT    B973 RRFc3  c ...Z Compare Logical and Trap (32)
NNRK    B974 RRFa   A ...Z Not And (32)
OCRK    B975 RRFa   A ...Z Or with Complement (32)
NORK    B976 RRFa   A ...Z Not Or (32)
NXRK    B977 RRFa   A ...Z Not Exlusive Or (32)
NGR     B980 RRE    A ...Z And (64)
OGR     B981 RRE    A ...Z Or (64)
XGR     B982 RRE    A ...Z Exclusive Or (64)
FLOGR   B983 RRE    c ...Z Find Leftmost One
LLGCR   B984 RRE    . ...Z Load Logical Character (64<-8)
LLGHR   B985 RRE    . ...Z Load Logical Halfword (64<-16)
MLGR    B986 RRE    A ...Z Multiply Logical (128<-64)
DLGR    B987 RRE    A ...Z Divide Logical (64<-128)
ALCGR   B988 RRE    A ...Z Add Logical with Carry (64)
SLBGR   B989 RRE    A ...Z Subtract Logical with Borrow (64)
CSPG    B98A RRE    C ...Z Compare and Swap and Purge (64)
EPSW    B98D RRE    . ..9Z Extract PSW
IDTE    B98E RRFb4  . ..9Z Invalidate DAT Table Entry
CRDTE   B98F RRFb4  C ...Z Compare and Replace DAT Table Entry
TRTT    B990 RRFc   c ..9Z Translate Two to Two
TRTO    B991 RRFc   c ..9Z Translate Two to One
TROT    B992 RRFc   c ..9Z Translate One to Two
TROO    B993 RRFc   c ..9Z Translate One to One
LLCR    B994 RRE    . ..9Z Load Logical Character (32<-8)
LLHR    B995 RRE    . ..9Z Load Logical Halfword (32<-16)
MLR     B996 RRE    A ...Z Multiply Logical (64<-32)
DLR     B997 RRE    A ...Z Divide Logical (32<-64)
ALCR    B998 RRE    A ..9Z Add Logical with Carry (32)
SLBR    B999 RRE    A ..9Z Subtract Logical with Borrow (32)
EPAIR   B99A RRE1   . ...Z Extract Primary ASN and Instance
ESAIR   B99B RRE1   . ...Z Extract Secondary ASN and Instance
ESEA    B99D RRE1   . ..9Z Extract and Set Extended authority
PTI     B99E RRE    . ...Z Program Transfer with Instance
SSAIR   B99F RRE1   . ...Z Set Secondary ASN with Instance
TPEI    B9A1 RRE    c ...Z Test Pending External Interruption
PTF     B9A2 RRE1   c ...Z Perform Topology Function
LPTEA   B9AA RRFb4  c ...Z Load Page Table Entry Address
IRBM    B9AC RRE    . ...Z Insert Reference Bits Multiple
RRBM    B9AE RRE    . ...Z Reset Reference Bits Multiple
PFMF    B9AF RRE    . ...Z Perform Frame Management Function
CU14    B9B0 RRFc   c ...Z Convert UTF-8 to UTF-32
CU24    B9B1 RRFc   c ...Z Convert UTF-16 to UTF-32
CU41    B9B2 RRE    c ...Z Convert UTF-32 to UTF-8
CU42    B9B3 RRE    c ...Z Convert UTF-32 to UTF-16
TRTRE   B9BD RRFc   c ...Z Translate and Test Reverse Extended
SRSTU   B9BE RRE    c ...Z Search String UNICODE
TRTE    B9BF RRFc   c ...Z Translate and Test Extended
SELFHR  B9C0 RRFa4  S ...Z Select High (32)
AHHHR   B9C8 RRFa   A ...Z Add High (32)
SHHHR   B9C9 RRFa   A ...Z Subtract High (32)
ALHHHR  B9CA RRFa   A ...Z Add Logical High (32)
SLHHHR  B9CB RRFa   A ...Z Subtract Logical High (32)
CHHR    B9CD RRE    C ...Z Compare High (32)
CLHHR   B9CF RRE    C ...Z Compare Logical High (32)
AHHLR   B9D8 RRFa   A ...Z Add High (32)
SHHLR   B9D9 RRFa   A ...Z Subtract High (32)
ALHHLR  B9DA RRFa   A ...Z Add Logical High (32)
SLHHLR  B9DB RRFa   A ...Z Subtract Logical High (32)
CHLR    B9DD RRE    C ...Z Compare High (32)
CLHLR   B9DF RRE    C ...Z Compare Logical High (32)
LOCFHR  B9E0 RRFc3  O ...Z Load High on Condition (32)
POPCNT  B9E1 RRFc   c ...Z Population Count
LOCGR   B9E2 RRFc3  O ...Z Load on Condition (64)
SELGR   B9E3 RRFa4  S ...Z Select (64)
NGRK    B9E4 RRFa   A ...Z And (64)
OGRK    B9E6 RRFa   A ...Z Or (64)
XGRK    B9E7 RRFa   A ...Z Exclusive Or (64)
AGRK    B9E8 RRFa   A ...Z Add (64)
SGRK    B9E9 RRFa   A ...Z Subtract (64)
ALGRK   B9EA RRFa   A ...Z Add Logical (64)
SLGRK   B9EB RRFa   A ...Z Subtract Logical (64)
MGRK    B9EC RRFa   A ...Z Multiply (128<-64)
MSGRKC  B9ED RRFa   A ...Z Multiply Single (64)
SELR    B9F0 RRFa4  S ...Z Select (32)
LOCR    B9F2 RRFc3  O ...Z Load on Condition (32)
NRK     B9F4 RRFa   A ...Z And (32)
ORK     B9F6 RRFa   A ...Z Or (32)
XRK     B9F7 RRFa   A ...Z Exclusive Or (32)
ARK     B9F8 RRFa   A ...Z Add (32)
SRK     B9F9 RRFa   A ...Z Subtract (32)
ALRK    B9FA RRFa   A ...Z Add Logical (32)
SLRK    B9FB RRFa   A ...Z Subtract Logical (32)
MSRKC   B9FD RRFa   A ...Z Multiply Single (32)
CS      BA   RSA    C .79Z Compare And Swap =4 . F
CDS     BB   RSA    C .79Z Compare Double And Swap =8
CLM     BD   RSb    C .79Z Compare Logical Char. under Mask (low)
STCM    BE   RSb    . .79Z Store Characters under Mask
ICM     BF   RSb    A .79Z Insert Characters under Mask
LARL    C00  RILb  R8 ..9Z Load Address Relative Long
LGFI    C01  RILa   . ...Z Load Immediate (64<-32)
BRCL    C04  RILc   R ..9Z Branch Relative on Condition Long
JASL    C05  RILb  R8 ..9Z Branch Relative and Save Long
XIHF    C06  RILax  A ..9Z Exclusive-Or Immediate (high) (0-31)
XILF    C07  RILax  A ..9Z Exclusive-Or Immediate (low) (32-63)
IIHF    C08  RILax  . ..9Z Insert Immediate (high) (0-31)
IILF    C09  RILax  . ..9Z Insert Immediate (low) (32-63)
NIHF    C0A  RILax  A ..9Z And Immediate (high) (0-31)
NILF    C0B  RILax  A ..9Z And Immediate (low) (32-63)
OIHF    C0C  RILax  A ..9Z Or Immediate (high) (0-31)
OILF    C0D  RILax  A ..9Z Or Immediate (low) (32-63)
LLIHF   C0E  RILa   . ..9Z Load Logical Immediate (high) (0-31)
LLILF   C0F  RILa   . ..9Z Load Logical Immediate (low) (32-63)
MSGFI   C20  RILa   A ...Z Multiply Single Immediate (64<-32)
MSFI    C21  RILa   A ...Z Multiply Single Immediate (32)
SLGFI   C24  RILa   A ...Z Subtract Logical Immediate (64<-32)
SLFI    C25  RILa   A ...Z Subtract Logical Immediate (32)
AGFI    C28  RILa   A ...Z Add Immediate (64<-32)
AFI     C29  RILa   A ...Z Add Immediate (32)
ALGFI   C2A  RILa   A ...Z Add Logical Immediate (64<-32)
ALFI    C2B  RILa   A ...Z Add Logical Immediate (32)
CGFI    C2C  RILa   C ...Z Compare Immediate (64<-32)
CFI     C2D  RILa   C ...Z Compare Immediate (32)
CLGFI   C2E  RILa   C ...Z Compare Logical Immediate (64<-32)
CLFI    C2F  RILa   C ...Z Compare Logical Immediate (32)
LLHRL   C42  RILb  R8 ..9Z Load Logical Halfword Relative Long (32<-16) =2
LGHRL   C44  RILb  R8 ...Z Load Halfword Relative Long (64<-16) =2
LHRL    C45  RILb  R8 ...Z Load Halfword Relative Long (32<-16) =2
LLGHRL  C46  RILb  R8 ...Z Load Logical Halfword Relative Long (64<-16) =2
STHRL   C47  RILb  R8 ...Z Store Halfword Relative Long (16) =2
LGRL    C48  RILb  R8 ...Z Load Relative Long (64) =8
STGRL   C4B  RILb  R8 ...Z Store Relative Long (64) =8
LGFRL   C4C  RILb  R8 ...Z Load Relative Long (64<-32) =4
LRL     C4D  RILb  R8 ...Z Load Relative Long (32) =4
LLGFRL  C4E  RILb  R8 ...Z Load Logical Relative Long (64<-32) =4
STRL    C4F  RILb  R8 ..9Z Store Relative Long (32) =4
BPRP    C5   MII    . ...Z Branch Prediction Relative Preload
EXRL    C60  RILb  R8 ..9Z Execute
PFDRL   C62  RILc   . ..9Z Prefetch Data Relative Long
CGHRL   C64  RILb  C8 ...Z Compare Halfword Relative Long (64<-16) =2
CHRL    C65  RILb  C8 ..9Z Compare Halfword Relative Long (32<-16) =2
CLGHRL  C66  RILb  C8 ...Z Compare Logical Relative Long (64<-16) =2
CLHRL   C67  RILb  C8 ..9Z Compare Logical Relative Long (32<-16) =2
CGRL    C68  RILb  C8 ...Z Compare Relative Long (64) =8
CLGRL   C6A  RILb  C8 ...Z Compare Logical Relative Long (64) =8
CGFRL   C6C  RILb  C8 ...Z Compare Relative Long (64<-32) =4
CRL     C6D  RILb  C8 ..9Z Compare Relative Long (32) =4
CLGFRL  C6E  RILb  C8 ...Z Compare Logical Relative Long (64<-32) =4
CLRL    C6F  RILb  C8 ..9Z Compare Logical Relative Long (32) =4
BPP     C7   SMI    . ...Z Branch Prediction Preload
MVCOS   C80  SSF    c ..9Z Move with Optional Specifications
ECTG    C81  SSF    . ..9Z Extract CPU Time =8
CSST    C82  SSF    C ..9Z Compare and Swap and Store
LPD     C84  SSF    . ...Z Load Pair Disjoint (32) =4 F F
LPDG    C85  SSF    . ...Z Load Pair Disjoint (64) =8 FD FD
BRCTH   CC6  RILb  R8 ...Z Branch Relative on Count High (32)
AIH     CC8  RILa   A ...Z Add Immediate High (32)
ALSIH   CCA  RILa   A ...Z Add Logical with Signed Immediate High (32)
ALSIHN  CCB  RILa   A ...Z Add Logical with Signed Immediate High (32)
CIH     CCD  RILa   C ...Z Compare Immediate High (32)
CLIH    CCF  RILa   C ...Z Compare Logical Immediate High (32)
TRTR    D0   SSa1   c ...Z Translate and Test Reverse =l(L1)
MVN     D1   SSa    . 679Z Move Numerics =l(L1)
MVC     D2   SSa    . 679Z Move Character =l(L1)
MVZ     D3   SSa    . 679Z Move Zones =l(L1)
NC      D4   SSa    A 679Z And Character =l(L1) . X
CLC     D5   SSa    C 679Z Compare Logical Character =l(L1)
OC      D6   SSa    A 679Z Or Character =l(L1) . X
XC      D7   SSa    A 679Z Exclusive-Or Character =l(L1) . X
MVCK    D9   SSd    c .79Z Move with Key
MVCP    DA   SSd    c .79Z Move to Primary
MVCS    DB   SSd    c .79Z Move to Secondary
TR      DC   SSa1   . 679Z Translate =l(L1)
TRT     DD   SSa1   c 679Z Translate and Test =l(L1)
ED      DE   SSa    A 679Z Edit =l(L1) . P
EDMK    DF   SSa    A 679Z Edit and MarK =l(L1) . P
PKU     E1   SSf    . ..9Z Pack Unicode =16 P
UNPKU   E2   SSa    c ..9Z Unpack Unicode =l(L1) . P
LTG     E302 RXYa   A ...Z Load and Test (64) =8 . FD
LRAG    E303 RXYa   c ..9Z Load Real Address (64) =8 . AD
LG      E304 RXYa   . ...Z Load (64) =8 . FD
CVBY    E306 RXYa   . ...Z Convert to Binary (32) =8 . P
AG      E308 RXYa   A ...Z Add (64) =8 . FD
SG      E309 RXYa   A ...Z Subtract (64) =8 . FD
ALG     E30A RXYa   A ...Z Add Logical (64) =8 . FD
SLG     E30B RXYa   A ...Z Subtract Logical (64) =8 . FD
MSG     E30C RXYa   A ..9Z Multiply Single (64) =8 . FD
DSG     E30D RXYa   A ..9Z Divide Single (64) =8 . FD
CVBG    E30E RXYa   . ..9Z Convert to Binary (64) =16 . P
LRVG    E30F RXYa   . ..9Z Load Reversed (64) =8 . FD
LT      E312 RXYa   A ..9Z Load and Test (32) =4 . F
LRAY    E313 RXYa   c ..9Z Load Real Address (32) =4 . A
LGF     E314 RXYa   . ...Z Load (64<-32) =4 . F
LGH     E315 RXYa   . ...Z Load Halfword (64<-16) =2 . H
LLGF    E316 RXYa   . ...Z Load Logical (64<-32) =4 . F
LLGT    E317 RXYa   . ...Z Load Logical 31-Bits (64<-31) =4 . F
AGF     E318 RXYa   A ...Z Add (64<-32) =4 . F
SGF     E319 RXYa   A ...Z Subtract (64<-32) =4 . F
ALGF    E31A RXYa   A ...Z Add Logical (64<-32) =4 . F
SLGF    E31B RXYa   A ...Z Subtract Logical (64<-32) =4 . F
MSGF    E31C RXYa   A ...Z Multiply Single (64<-32) =4 . F
DSGF    E31D RXYa   A ...Z Divide Single (64<-32) =4 . F
LRV     E31E RXYa   . ...Z Load Reversed (32) =4
LRVH    E31F RXYa   . ..9Z Load Reversed (16) =2
CG      E320 RXYa   C ...Z Compare (64) =8 . FD
CLG     E321 RXYa   C ...Z Compare Logical (64) =8 . FD
STG     E324 RXYa   . ...Z Store (64) =8 . FD
NTSTG   E325 RXYa   . ...Z NonTransactional Store (64)
CVDY    E326 RXYa   . ...Z Convert to Decimal (32) =8 . P
LZRG    E32A RXYa   . ...Z Load and Zero Rightmost Byte (64) =8 . FD
CVDG    E32E RXYa   . ...Z Convert to Decimal (64) =16 . P
STRVG   E32F RXYa   . ...Z Store Reversed (64) =8 . FD
CGF     E330 RXYa   C ...Z Compare (64<-32) =4 . F
CLGF    E331 RXYa   C ...Z Compare Logical (64<-32) =4 . F
LTGF    E332 RXYa   A ...Z Load and Test (64<-32) =4 . F
CGH     E334 RXYa   C ...Z Compare Halfword (64<-16) =2 . H
PFD     E336 RXYb   . ..9Z PreFetch Data
AGH     E338 RXYa   A ...Z Add Halfword (64<-16) =2 . H
SGH     E339 RXYa   A ...Z Subtract Halfword (64<-16) =2 . H
LLZRGF  E33A RXYa   . ...Z Load Logical and Zero Rightmost Byte (64<-32) =4 . F
LZRF    E33B RXYa   . ...Z Load and Zero Rightmost Byte (32) =4 . F
MGH     E33C RXYa   A ...Z Multiply Halfword (64<-16) =2 . H
STRV    E33E RXYa   . ..9Z Store Reversed (32) =4 . F
STRVH   E33F RXYa   . ..9Z Store Reversed (16) =2 . H
BCTG    E346 RXYa   . ...Z Branch on Count (64) =8
BIC     E347 RXYb   . ...Z Branch Indirect on Condition
LLGFSG  E348 RXYa   . ...Z Load Logical and Shift Guarded (64<-32) =4 . F
STGSC   E349 RXYa   . ...Z Store Guarded Storage Controls
LGG     E34C RXYa   . ...Z Load Guarded (64) =8 . FD
LGSC    E34D RXYa   . ...Z Load Guarded Storage Controls
STY     E350 RXYa   . ...Z Store (32) =4 . F
MSY     E351 RXYa   A ...Z Multiply Single (32) =4 . F
MSC     E353 RXYa   A ...Z Multiply single (32) =4 . F
NY      E354 RXYa   A ...Z And (32) =4 . X
CLY     E355 RXYa   C ...Z Compare Logical (32) =4 . F
OY      E356 RXYa   A ...Z Or (32) =4 . X
XY      E357 RXYa   A ...Z Exclusive-Or (32) =4 . X
LY      E358 RXYa   . ...Z Load (32) =4 . F
CY      E359 RXYa   C ...Z Compare (32) =4 . F
AY      E35A RXYa   A ...Z Add (32) =4 . F
SY      E35B RXYa   A ...Z Subtract (32) =4 . F
MFY     E35C RXYa   A ...Z Multiply (64<-32) =4 . F
ALY     E35E RXYa   A ...Z Add Logical (32) =4 . F
SLY     E35F RXYa   A ...Z Subtract Logical (32) =4 . F
STHY    E370 RXYa   . ...Z Store Halfword (16) =2 . H
LAY     E371 RXYa   . ..9Z Load Address
STCY    E372 RXYa   . ...Z Store Character =1
ICY     E373 RXYa   . ...Z Insert Character =1
LAEY    E375 RXYa   . ..9Z Load Address Extended
LB      E376 RXYa   . ..9Z Load Byte (32<-8) =1
LGB     E377 RXYa   . ...Z Load Byte (64<-8) =1
LHY     E378 RXYa   . ...Z Load Halfword (32<-16) =2 . H
CHY     E379 RXYa   C ...Z Compare Halfword (32<-16) =2 . H
AHY     E37A RXYa   A ...Z Add Halfword (32<-16) =2 . H
SHY     E37B RXYa   A ...Z Subtract Halfword (32<-16) =2 . H
MHY     E37C RXYa   A ...Z Multiply Halfword (32<-16) =2 . H
NG      E380 RXYa   A ...Z And (64) =8 . X
OG      E381 RXYa   A ...Z Or (64) =8 . X
XG      E382 RXYa   A ...Z Exclusive-Or (64) =8 . X
MSGC    E383 RXYa   A ...Z Multiply Single (64) =8 . FD
MG      E384 RXYa   A ...Z Multiply (128<-64) =8 . FD
LGAT    E385 RXYa   . ...Z Load and Trap (64) =8 . FD
MLG     E386 RXYa   A ...Z Multiply Logical (128<-64) =8 . FD
DLG     E387 RXYa   A ...Z Divide Logical (64<-128) =8 . FD
ALCG    E388 RXYa   A ...Z Add Logical with Carry (64) =8 . FD
SLBG    E389 RXYa   A ...Z Subtract Logical with Borrow (64) =8 . FD
STPQ    E38E RXYa   . ...Z Store Pair to Quadword =16
LPQ     E38F RXYa   . ...Z Load Pair from Quadword (64+64<-128) =16
LLGC    E390 RXYa   . ...Z Load Logical Character (64<-8) =1
LLGH    E391 RXYa   . ...Z Load Logical Halfword (64<-16) =2
LLC     E394 RXYa   . ..9Z Load Logical Character (32<-8) =1
LLH     E395 RXYa   . ..9Z Load Logical Halfword (32<-16) =2
ML      E396 RXYa   A ..9Z Multiply Logical (64<-32) =4 . F
DL      E397 RXYa   A ..9Z Divide Logical (32<-64) =4 . F
ALC     E398 RXYa   A ..9Z Add Logical with Carry (32) =4 . F
SLB     E399 RXYa   A ..9Z Subtract Logical with Borrow (32) =4 . F
LLGTAT  E39C RXYa   . ...Z Load Logical 31-Bits and Trap (64<-31) =4 . F
LLGFAT  E39D RXYa   . ...Z Load Logical and Trap (64<-32) =4 . F
LAT     E39F RXYa   . ...Z Load and Trap (32L<-32) =4 . F
LBH     E3C0 RXYa   . ...Z Load Byte High (32<-8) =1
LLCH    E3C2 RXYa   . ...Z Load Logical Character High (32<-8) =1
STCH    E3C3 RXYa   . ...Z Store Character High (8) =1
LHH     E3C4 RXYa   . ...Z Load Halfword High (32<-16) =2 . H
LLHH    E3C6 RXYa   . ...Z Load Logical Halfword High (32<-16) =2 . H
STHH    E3C7 RXYa   . ...Z Store Halfword High (16) =2 . H
LFHAT   E3C8 RXYa   . ...Z Load High and Trap (32H<-16) =2 . H
LFH     E3CA RXYa   . ...Z Load High (32) =4 . F
STFH    E3CB RXYa   . ...Z Store High (32) =4 . F
CHF     E3CD RXYa   C ...Z Compare High (32) =4 . F
CLHF    E3CF RXYa   C ...Z Compare Logical High (32) =4 . F
VLI     E400 RSE    . .7.. Vector Load Indirect (32)
*VLIE   E400 RSE    . .7.. Vector Load Indirect (32)
VSTI    E401 RSE    . .7.. Vector Store Indirect (32)
*VSTI   E401 RSE    . .7.. Vector Store Indirect (32)
VLID    E410 RSE    . .7.. Vector Load Indirect (LH)
VSTID   E411 RSE    . .7.. Vector Store Indirect (LH)
VSRL    E424 RSE    . .7.. Vector Shift Right Single Logical
VSLL    E425 RSE    . .7.. Vector Shift Left Single Logical
VLBIX   E428 RSE    c .7.. Vector Load Bit Index
LASP    E500 SSE    c .79Z Load Address Space Parameters
TPROT   E501 SSE    c .79Z Test Protection
STRAG   E502 SSE    . ..9Z Store Real Address =8
fixpg   E502 SSE    . .7.. MVS Assist: Fix Page
svcas   E503 SSE    . .7.. MVS Assist: SVC Assist
olcll   E504 SSE    . .7.. MVS Assist: Obtain Local Lock
rlcll   E505 SSE    . .7.. MVS Assist: Release Local Lock
ocmsl   E506 SSE    . .7.. MVS Assist: Obtain CMS Lock
rcmsl   E507 SSE    . .7.. MVS Assist: Release CMS Lock
tsvci   E508 SSE    . .7.. MVS Assist: Trace SVC Interruption
tpgmi   E509 SSE    . .7.. MVS Assist: Trace Program Interruption
tsrbd   E50A SSE    . .7.. MVS Assist: Trace Initial SRB Dispatch
tioi    E50B SSE    . .7.. MVS Assist: Trace I/O Interruption
ttskd   E50C SSE    . .7.. MVS Assist: Trace Task Dispatch
tsvcr   E50D SSE    . .7.. MVS Assist: Trace SVC Return
MVCSK   E50E SSE    . .79Z Move with Source Key
MVCDK   E50F SSE    . .79Z Move with Destination Key
MVHHI   E544 SIL    . ...Z Move (16<-16) =2 H
MVGHI   E548 SIL    . ...Z Move (64<-16) =8 FD
MVHI    E54C SIL    . ...Z Move (32<-16) =4 F
CHHSI   E554 SIL    C ...Z Compare Halfword Immediate (16<-16) =2 H
CLHHSI  E555 SIL    C ...Z Compare Logical Immediate (16<-16) =2 H
CGHSI   E558 SIL    C ...Z Compare Halfword Immediate (64<-16) =8 FD
CLGHSI  E559 SIL    C ...Z Compare Logical Immediate (64<-16) =8 FD
CHSI    E55C SIL    C ...Z Compare Halfword Immediate (32<-16) =4 F
CLFHSI  E55D SIL    C ...Z Compare Logical Immediate (32<-16) =4 F
TBEGIN  E560 SIL    c .79Z Transaction Begin (nonconstrained)
TBEGINC E561 SIL    c .79Z Transaction Begin (constrained)
VPKZ    E634 VSI    . ...Z Vector Pack Zoned
VLRL    E635 VSI    . ...Z Vector Load Rightmost with Length
VLRLR   E637 VRSd   . ...Z Vector Load Rightmost with Length
VUPKZ   E63C VSI    . ...Z Vector Unpack Zoned
VSTRL   E63D VSI    . ...Z Vector Store Rightmost with Length
VSTRLR  E63F VRSd   . ...Z Vector Store Rightmost with Length
VLIP    E649 VRIh   . ...Z Vector Load Immediate Decimal
VCVB    E650 VRRi   c ...Z Vector Convert to Binary
VCVBG   E652 VRRi   c ...Z Vector Convert to Binary
VCVD    E658 VRIi   c ...Z Vector Convert to Decimal
VSRP    E659 VRIg   c ...Z Vector Shift and Round Decimal
VCVDG   E65A VRIi   c ...Z Vector Convert to Decimal
VPSOP   E65B VRIg   c ...Z Vector Perform Sign Operation Decimal
VTP     E65F VRRg   c ...Z Vector Test Decimal
VAP     E671 VRIf   c ...Z Vector Add Decimal
VSP     E673 VRIf   c ...Z Vector Subtract Decimal
VCP     E677 VRRh   c ...Z Vector Compare Decimal
VMP     E678 VRIf   c ...Z Vector Multiply Decimal
VMSP    E679 VRIf   c ...Z Vector Multiply and Shift Decimal
VDP     E67A VRIf   c ...Z Vector Divide Decimal
VRP     E67B VRIf   c ...Z Vector Remainder Decimal
VSDP    E67E VRIf   c ...Z Vector Shift and Divide Decimal
VLEB    E700 VRX3   . ...Z Vector Load Element (8)
VLEH    E701 VRX3   . ...Z Vector Load Element (16)
VLEG    E702 VRX3   . ...Z Vector Load Element (64)
VLEF    E703 VRX3   . ...Z Vector Load Element (32)
VLLEZ   E704 VRX3   . ...Z Vector Load Logical Element and ZERO
VLREP   E705 VRX3   . ...Z Vector Load and Replicate
VL      E706 VRX    . ...Z Vector Load
VLBB    E707 VRX3   . ...Z Vector Load to Block Boundary
VSTEB   E708 VRX3   . ...Z Vector Store Element (8)
VSTEH   E709 VRX3   . ...Z Vector Store Element (16)
VSTEG   E70A VRX3   . ...Z Vector Store Element (64)
VSTEF   E70B VRX3   . ...Z Vector Store Element (32)
VST     E70E VRX    . ...Z Vector Store
VGEG    E712 VRV    . ...Z Vector Gather Element (64)
VGEF    E713 VRV    . ...Z Vector Gather Element (32)
VSCEG   E71A VRV    . ...Z Vector Scatter Element (64)
VSCEF   E71B VRV    . ...Z Vector Scatter Element (32)
VLGV    E721 VRSc   . ...Z Vector Load GR from VR Element
VLVG    E722 VRSb4  . ...Z Vector Load VR Element from GR
LCBB    E727 RXE3   c ...Z Load Count to Block Boundary
VESL    E730 VRSa   . ...Z Vector Element Shift Left
VERLL   E733 VRSa   . ...Z Vector Element Rotate Left Logical
VLM     E736 VRSa   . ...Z Vector Load Multiple
VLL     E737 VRSb   . ...Z Vector Load with Length
VESRL   E738 VRSa   . ...Z Vector Element Shift Right Logical
VESRA   E73A VRSa   . ...Z Vector Element Shift Right Arithmetic
VSTM    E73E VRSa   . ...Z Vector Store Multiple
VSTL    E73F VRSb   . ...Z Vector Store with Length
VLEIB   E740 VRIa3  . ...Z Vector Load Element Immediate (8)
VLEIH   E741 VRIa3  . ...Z Vector Load Element Immediate (16)
VLEIG   E742 VRIa3  . ...Z Vector Load Element Immediate (64)
VLEIF   E743 VRIa3  . ...Z Vector Load Element Immediate (32)
VGBM    E744 VRIa   . ...Z Vector Generate Byte Mask
VREPI   E745 VRIa3  . ...Z Vector Replicate Immediate
VGM     E746 VRIb   . ...Z Vector Generate Mask
VFTCI   E74A VRIe   c ...Z Vector FP Test Data Class Immediate
VREP    E74D VRIc   . ...Z Vector Replicate
VPOPCT  E750 VRRa3  . ...Z Vector Population Count
VCTZ    E752 VRRa3  . ...Z Vector Count Trailing Zeros
VCLZ    E753 VRRa3  . ...Z Vector Count Leading Zeros
VLR     E756 VRRa   . ...Z Vector Load
VISTR   E75C VRRa2  c ...Z Vector Isolate String
VSEG    E75F VRRa3  . ...Z Vector Sign Extend to Doubleword
VMRL    E760 VRRc4  . ...Z Vector Merge Low
VMRH    E761 VRRc4  . ...Z Vector Merge High
VLVGP   E762 VRRf   . ...Z Vector Load VR from GRS Disjoint
VSUM    E764 VRRc4  . ...Z Vector Sum Across Word
VSUMG   E765 VRRc4  . ...Z Vector Sum Across Doubleword
VCKSM   E766 VRRc3  . ...Z Vector Checksum
VSUMQ   E767 VRRc4  . ...Z Vector Sum Across Quadword
VN      E768 VRRc3  . ...Z Vector and
VNC     E769 VRRc3  . ...Z Vector and with COMPLEMENT
VO      E76A VRRc3  . ...Z Vector Or
VNO     E76B VRRc3  . ...Z Vector Nor
VNX     E76C VRRc3  . ...Z Vector Not Exclusive Or
VX      E76D VRRc3  . ...Z Vector Exclusive Or
VNN     E76E VRRc3  . ...Z Vector Nand
VOC     E76F VRRc3  . ...Z Vector Or with Complement
VESLV   E770 VRRc4  . ...Z Vector Element Shift Left
VERIM   E772 VRId5  . ...Z Vector Element Rotate and Insert Under Mask
VERLLV  E773 VRRc4  . ...Z Vector Element Rotate Left Logical
VSL     E774 VRRc3  . ...Z Vector Shift Left
VSLB    E775 VRRc3  . ...Z Vector Shift Left by Byte
VSLDB   E777 VRId   . ...Z Vector Shift Left Double by Byte
VESRLV  E778 VRRc4  . ...Z Vector Element Shift Right Logical
VESRAV  E77A VRRc4  . ...Z Vector Element Shift Right Arithmetic
VSRL    E77C VRRc3  . ...Z Vector Shift Right Logical
VSRLB   E77D VRRc3  . ...Z Vector Shift Right Logical by Byte
VSRA    E77E VRRc3  . ...Z Vector Shift Right Arithmetic
VSRAB   E77F VRRc3  . ...Z Vector Shift Right Arithmetic by Byte
VFEE    E780 VRRb4  c ...Z Vector Find Element Equal
VFENE   E781 VRRb4  c ...Z Vector Find Element Not Equal
VFAE    E782 VRRb4  c ...Z Vector Find Any Element Equal
VPDI    E784 VRRc4  . ...Z Vector Permute Doubleword Immediate
VBPERM  E785 VRRc3  . ...Z Vector Bit Permute
VSTRC   E78A VRRd5  c ...Z Vector String Range Compare
VSTRS   E78B VRRd5  c ...Z Vector String Search
VPERM   E78C VRRe   . ...Z Vector Permute
VSEL    E78D VRRe   . ...Z Vector Select
VFMS    E78E VRRe6  . ...Z Vector FP Multiply and Subtract
VFMA    E78F VRRe6  . ...Z Vector FP Multiply and Add
VPK     E794 VRRc4  . ...Z Vector Pack
VPKLS   E795 VRRb   c ...Z Vector Pack Logical Saturate
VPKS    E797 VRRb   c ...Z Vector Pack Saturate
VFNMS   E79E VRRe6  . ...Z Vector FP Negative Multiply and Subtract
VFNMA   E79F VRRe6  . ...Z Vector FP Negative Multiply and Add
VMLH    E7A1 VRRc4  . ...Z Vector Multiply Logical High
VML     E7A2 VRRc4  . ...Z Vector Multiply Low
VMH     E7A3 VRRc4  . ...Z Vector Multiply High
VMLE    E7A4 VRRc4  . ...Z Vector Multiply Logical Even
VMLO    E7A5 VRRc4  . ...Z Vector Multiply Logical Odd
VME     E7A6 VRRc4  . ...Z Vector Multiply Even
VMO     E7A7 VRRc4  . ...Z Vector Multiply Odd
VMALH   E7A9 VRRd   . ...Z Vector Multiply and Add Logical High
VMAL    E7AA VRRd   . ...Z Vector Multiply and Add Low
VMAH    E7AB VRRd   . ...Z Vector Multiply and Add High
VMALE   E7AC VRRd   . ...Z Vector Multiply and Add Logical Even
VMALO   E7AD VRRd   . ...Z Vector Multiply and Add Logical Odd
VMAE    E7AE VRRd   . ...Z Vector Multiply and Add Even
VMAO    E7AF VRRd   . ...Z Vector Multiply and Add Odd
VGFM    E7B4 VRRc4  . ...Z Vector Galois Field Multiply Sum
VMSL    E7B8 VRRd6  . ...Z Vector Multiply Sum Logical
VACCC   E7B9 VRRd   . ...Z Vector Add with Carry Compute Carry
VAC     E7BB VRRd   . ...Z Vector Add with Carry
VGFMA   E7BC VRRd   . ...Z Vector Galois Field Multiply Sum and Accumulate
VSBCBI  E7BD VRRd   . ...Z Vector Subtract with Borrow Compute Borrow Indication
VSBI    E7BF VRRd   . ...Z Vector Subtract with Borrow Indication
VCLGD   E7C0 VRRa5  . ...Z Vector FP Convert to Logical 64-bit
VCDLG   E7C1 VRRa5  . ...Z Vector FP Convert from Logical 64-bit
VCGD    E7C2 VRRa5  . ...Z Vector FP Convert to Fixed 64-bit
VCDG    E7C3 VRRa5  . ...Z Vector FP Convert from Fixed 64-bit
VFLL    E7C4 VRRa4  . ...Z Vector FP Load Lengthened
VFLR    E7C5 VRRa5  . ...Z Vector FP Load Rounded
VFI     E7C7 VRRa5  . ...Z Vector Load FP Integer
WFK     E7CA VRRa4  c ...Z Vector FP Compare and Signal Scalar
WFC     E7CB VRRa4  c ...Z Vector FP Compare Scalar
VFPSO   E7CC VRRa5  . ...Z Vector FP Perform Sign Operation
VFSQ    E7CE VRRa4  . ...Z Vector FP Square Root
VUPLL   E7D4 VRRa3  . ...Z Vector Unpack Logical Low
VUPLH   E7D5 VRRa3  . ...Z Vector Unpack Logical High
VUPL    E7D6 VRRa3  . ...Z Vector Unpack Low
VUPH    E7D7 VRRa3  . ...Z Vector Unpack High
VTM     E7D8 VRRa   M ...Z Vector Test Under Mask
VECL    E7D9 VRRa3  c ...Z Vector Element Compare Logical
VEC     E7DB VRRa3  c ...Z Vector Element Compare
VLC     E7DE VRRa3  . ...Z Vector Load Complement
VLP     E7DF VRRa3  . ...Z Vector Load Positive
VFS     E7E2 VRRc5  . ...Z Vector FP Subtract
VFA     E7E3 VRRc5  . ...Z Vector FP Add
VFD     E7E5 VRRc5  . ...Z Vector FP Divide
VFM     E7E7 VRRc5  . ...Z Vector FP Multiply
VFCE    E7E8 VRRc6  c ...Z Vector FP Compare Equal
VFCHE   E7EA VRRc6  c ...Z Vector FP Compare High or Equal
VFCH    E7EB VRRc6  . ...Z Vector FP Compare High
VFMIN   E7EE VRRc6  . ...Z Vector FP Minimum
VFMAX   E7EF VRRc6  . ...Z Vector FP Maximum
VAVGL   E7F0 VRRc4  . ...Z Vector Average Logical
VACC    E7F1 VRRc4  . ...Z Vector Add Compute Carry
VAVG    E7F2 VRRc4  . ...Z Vector Average
VA      E7F3 VRRc4  . ...Z Vector Add
VSCBI   E7F5 VRRc4  . ...Z Vector Subtract Compute Borrow Indication
VS      E7F7 VRRc4  . ...Z Vector Subtract
VCEQ    E7F8 VRRb   c ...Z Vector Compare Equal
VCHL    E7F9 VRRb   c ...Z Vector Compare High Logical
VCH     E7FB VRRb   c ...Z Vector Compare High
VMNL    E7FC VRRc4  . ...Z Vector Minimum Logical
VMXL    E7FD VRRc4  . ...Z Vector Maximum Logical
VMN     E7FE VRRc4  . ...Z Vector Minimum
VMX     E7FF VRRc4  . ...Z Vector Maximum
MVCIN   E8   SSa    . .79Z Move Inverse =l(L1)
PKA     E9   SSf    . ..9Z Pack ASCII =16 P
UNPKA   EA   SSa    c .79Z UnPacK ASCII =l(L1) . P
LMG     EB04 RSYa   . ...Z Load Multiple (64)  =hM(8) . FD
SRAG    EB0A RSYas  A ...Z Shift Right Single (64)
SLAG    EB0B RSYas  A ...Z Shift Left Single (64)
SRLG    EB0C RSYas  . ...Z Shift Right Single Logical (64)
SLLG    EB0D RSYas  . ...Z Shift Left Single Logical (64)
TRACG   EB0F RSYa   . ...Z Trace (64)
CSY     EB14 RSYa   C ...Z Compare and Swap (32) =4 . F
RLLG    EB1C RSYas  . ...Z Rotate Left Single Logical (64)
RLL     EB1D RSYas  . ...Z Rotate Left single Logical
CLMH    EB20 RSYbm  C ...Z Compare Logical Char. under Mask (high)
CLMY    EB21 RSYbm  C ...Z Compare Logical Char. under Mask (low)
CLT     EB23 RSYb   c ..9Z Compare Logical and Trap (32) =4 . F
STMG    EB24 RSYa   . ...Z Store Multiple (64) =hM(8) . FD
STCTG   EB25 RSYa   . ...Z Store Control (64) =hM(8) . FD
STMH    EB26 RSYa   . ...Z Store Multiple High (32) =hM(4) . F
CLGT    EB2B RSYb   c ...Z Compare Logical and Trap (64) =8 . FD
STCMH   EB2C RSYbm  . ...Z Store Characters under Mask (high)
STCMY   EB2D RSYbm  . ...Z Store Characters under Mask (low)
LCTLG   EB2F RSYa   . ...Z Load Control (64) =hM(8) . FD
CSG     EB30 RSYa   C ...Z Compare and Swap (64) =8 . FD
CDSY    EB31 RSYa   C ...Z Compare Double and Swap (32) =4 . F
CDSG    EB3E RSYa   C ...Z Compare Double and Swap (64) =8 . FD
BXHG    EB44 RSYa   . ...Z Branch on Index High (64)
BXLEG   EB45 RSYa   . ...Z Branch on Index Low or Equal (64)
ECAG    EB4C RSYa   . ...Z Extract CPU Attribute
TMY     EB51 SIYm   M ...Z Test under Mask
MVIY    EB52 SIYu   . ...Z Move Immediate
NIY     EB54 SIYx   A ...Z And Immediate
CLIY    EB55 SIYu   C ...Z Compare Logical Immediate
OIY     EB56 SIYx   A ...Z Or Immediate
XIY     EB57 SIYx   A ...Z Exclusive-Or Immediate
ASI     EB6A SIY    A ...Z Add Immediate (32<-8) =4 F
ALSI    EB6E SIY    A ...Z Add Logical with Signed Immediate (32<-8) =4 F
AGSI    EB7A SIY    A ...Z Add Immediate (64<-8) =8 FD
ALGSI   EB7E SIY    A ...Z Add Logical with Signed Immediate (64<-8) =8 FD
ICMH    EB80 RSYbm  . ..9Z Insert Characters under Mask (high)
ICMY    EB81 RSYbm  . ...Z Insert Characters under Mask (low)
MVCLU   EB8E RSYa   c ..9Z Move Long Unicode
CLCLU   EB8F RSYa   C ..9Z Compare Logical Long Unicode
STMY    EB90 RSYa   . ...Z Store Multiple (32) =hM(4) . F
LMH     EB96 RSYa   . ..9Z Load Multiple High (32) =hM(4) . F
LMY     EB98 RSYa   . ..9Z Load Multiple (32) =hM(4) . F
LAMY    EB9A RSYa   . ...Z Load Access Multiple =hM(4) . F
STAMY   EB9B RSYa   . ...Z Store Access Multiple =hM(4) . F
TP      EBC0 RSLa   c ..9Z Test Decimal =l(L1) P
SRAK    EBDC RSYas  A ..9Z Shift Right Single (32)
SLAK    EBDD RSYas  A ..9Z Shift Left Single (32)
SRLK    EBDE RSYas  . ..9Z Shift Right Single Logical (32)
SLLK    EBDF RSYas  . ..9Z Shift Left Single Logical (32)
LOCFH   EBE0 RSYb   O ...Z Load High On Condition (32) =4 . F
STOCFH  EBE1 RSYb   O ...Z Store High On Condition (32) =4 . F
LOCG    EBE2 RSYb   O ..9Z Load On Condition (64) =8 . FD
STOCG   EBE3 RSYb   O ...Z Store On Condition (64) =8 . FD
LANG    EBE4 RSYa   . ...Z Load and And (64) =8 . X
LAOG    EBE6 RSYa   A ...Z Load and Or (64) =8 . X
LAXG    EBE7 RSYa   A ...Z Load and Exclusive-Or (64) =8 . X
LAAG    EBE8 RSYa   A ...Z Load and Add (64) =8 . FD
LAALG   EBEA RSYa   A ...Z Load and Add Logical (64) =8 . FD
LOC     EBF2 RSYb   O ...Z Load On Condition (32) =4 . F
STOC    EBF3 RSYb   O ...Z Store On Condition (32) =4 . F
LAN     EBF4 RSYa   . ...Z Load and And (32) =4 . X
LAO     EBF6 RSYa   A ...Z Load and Or (32) =4 . X
LAX     EBF7 RSYa   A ...Z Load and Exclusive-Or (32) =4 . X
LAA     EBF8 RSYa   A ...Z Load and Add (32) =4 . F
LAAL    EBFA RSYa   A ...Z Load and Add Logical (32) =4 . F
LOCHI   EC42 RIEg   O ...Z Load Halfword Immediate On Condition (32<-16)
JXHG    EC44 RIEe   . ..9Z Branch Relative on Index High (64)
JXLEG   EC45 RIEe   . ..9Z Branch Relative on Index Low or Equal (64)
LOCGHI  EC46 RIEg   O ...Z Load Halfword Immediate On Condition (64<-16)
LOCHHI  EC4E RIEg   O ...Z Load Halfword High Immediate On Condition (32<-16)
RISBLG  EC51 RIEf  RO ...Z Rotate then Insert Selected Bits Low (64)
RNSBG   EC54 RIEf  RO ..9Z Rotate then And Selected Bits (64)
RISBG   EC55 RIEf  RO ..9Z Rotate then Insert Selected Bits (64)
ROSBG   EC56 RIEf  RO ..9Z Rotate then Or Selected Bits (64)
RXSBG   EC57 RIEf  RO ..9Z Rotate then Exlusive-Or Selected Bits (64)
RISBGN  EC59 RIEf  RO ...Z Rotate then Insert Selected Bits (64)
RISBHG  EC5D RIEf  RO ...Z Rotate then Insert Selected Bits High (64)
CGRJ    EC64 RIEb  CJ ..9Z Compare and Branch Relative (64)
CLGRJ   EC65 RIEb  CJ ..9Z Compare Logical and Branch Relative (64)
CGIT    EC70 RIEa   c ..9Z Compare Immediate and Trap (64<-16)
CLGIT   EC71 RIEa   c ..9Z Compare Logical Immediate and Trap (64<-16)
CIT     EC72 RIEa   c ..9Z Compare Immediate and Trap (32<-16)
CLFIT   EC73 RIEa   c ..9Z Compare Logical Immediate and Trap (32<-16)
CRJ     EC76 RIEb  CJ ..9Z Compare and Branch Relative (32)
CLRJ    EC77 RIEb  CJ ..9Z Compare Logical and Branch Relative (32)
CGIJ    EC7C RIEc  CJ ..9Z Compare Immediate and Branch Relative (64<-8)
CLGIJ   EC7D RIEc  CJ ..9Z Compare Logical Immediate and Branch Relative (64<-8)
CIJ     EC7E RIEc  CJ ..9Z Compare Immediate and Branch Relative (32<-8)
CLIJ    EC7F RIEc  CJ ..9Z Compare Logical Immediate and Branch Relative (32<-8)
AHIK    ECD8 RIEd   A ...Z Add Immediate (32<-16)
AGHIK   ECD9 RIEd   A ...Z Add Immediate (64<-16)
ALHSIK  ECDA RIEd   A ...Z Add Logical with Signed Immediate (32<-16)
ALGHSIK ECDB RIEd   A ...Z Add Logical with Signed Immediate (64<-16)
CGRB    ECE4 RRS   CJ ..9Z Compare and Branch (64)
CLGRB   ECE5 RRS   CJ ..9Z Compare Logical and Branch (64)
CRB     ECF6 RRS   CJ ..9Z Compare and Branch (32)
CLRB    ECF7 RRS   CJ ..9Z Compare Logical and Branch (32)
CGIB    ECFC RIS   CJ ..9Z Compare Immediate and Branch (64<-8)
CLGIB   ECFD RIS   CJ ..9Z Compare Logical Immediate and Branch (64<-8)
CIB     ECFE RIS   CJ ..9Z Compare Immediate and Branch (32<-8)
CLIB    ECFF RIS   CJ ..9Z Compare Logical Immediate and Branch (32<-8)
LDEB    ED04 RXE    . ..9Z Load Lengthened (LB<-SB) =4 . EB
LXDB    ED05 RXE    . ..9Z Load Lengthened (EB<-LB) =8 . DB
LXEB    ED06 RXE    . ..9Z Load Lengthened (EB<-SB) =4 . EB
MXDB    ED07 RXE    A ..9Z Multiply (EB<-LB) =8 . DB
KEB     ED08 RXE    C ..9Z Compare and Signal (SB) =4 . EB
CEB     ED09 RXE    C ..9Z Compare (SB) =4 . EB
AEB     ED0A RXE    A ..9Z Add (SB) =4 . EB
SEB     ED0B RXE    A ..9Z Subtract (SB) =4 . EB
MDEB    ED0C RXE    A ..9Z Multiply (LB<-SB) =4 . EB
DEB     ED0D RXE    A ..9Z Divide (SB) =4 . EB
MAEB    ED0E RXF    A ..9Z Multiply and Add (SB) =4 . EB
MSEB    ED0F RXE3   A ..9Z Multiply and Subtract (SB) =4 . EB
TCEB    ED10 RXE    c ..9Z Test Data Class (SB)
TCDB    ED11 RXE    c ..9Z Test Data Class (LB)
TCXB    ED12 RXE    c ..9Z Test Data Class (EB)
SQEB    ED14 RXE    . ..9Z Square Root (SB) =4 . EB
SQDB    ED15 RXE    . ..9Z Square Root (LB) =8 . DB
MEEB    ED17 RXE    A ..9Z Multiply (SB) =4 . EB
KDB     ED18 RXE    C ..9Z Compare and Signal (LB) =8 . DB
CDB     ED19 RXE    C ..9Z Compare (LB) =8 . DB
ADB     ED1A RXE    A ..9Z Add (LB) =8 . DB
SDB     ED1B RXE    A ..9Z Subtract (LB) =8 . DB
MDB     ED1C RXE    A ..9Z Multiply (LB) =8 . DB
DDB     ED1D RXE    A ..9Z Divide (LB) =8 . DB
MADB    ED1E RXE3   A ..9Z Multiply and Add (LB) =8 . DB
MSDB    ED1F RXF    A ..9Z Multiply and Subtract (LB) =8 . DB
LDE     ED24 RXE    . ..9Z Load Lengthened (LH<-SH) =4 . E
LXD     ED25 RXE    . ..9Z Load Lengthened (EH<-LH) =8 . D
LXE     ED26 RXE    . ..9Z Load Lengthened (EH<-SH) =4 . E
MAE     ED2E RXF    A ..9Z Multiply and Add (SH) =4 . E
MSE     ED2F RXF    A ..9Z Multiply and Subtract (SH) =4 . E
SQE     ED34 RXE    . ..9Z Square Root (SH) =4 . E
SQD     ED35 RXE    . ..9Z Square Root (LH) =8 . D
MEE     ED37 RXE    A ..9Z Multiply (SH) =4 . E
MAYL    ED38 RXF    A ...Z Multiply and Add Unnormalized (EHL<-LH) =8 . D
MYL     ED39 RXF    A ...Z Multiply Unnormalized (EHL<-LH) =8 . D
MAY     ED3A RXF    A ...Z Multiply and Add Unnormalized (EH<-LH) =8 . D
MY      ED3B RXF    A ...Z Multiply Unnormalized (EH<-LH) =8 . D
MAYH    ED3C RXF    A ...Z Multiply and Add Unnormalized (EHH<-LH) =8 . D
MYH     ED3D RXF    A ...Z Multiply Unnormalized (EHH<-LH) =8 . D
MAD     ED3E RXF    A ..9Z Multiply and Add (LH) =8 . D
MSD     ED3F RXF    A ..9Z Multiply and Subtract (LH) =8 . D
SLDT    ED40 RXF    . ..9Z Shift Significand Left (LD)
SRDT    ED41 RXF    . ..9Z Shift Significand Right (LD)
SLXT    ED48 RXF    . ..9Z Shift Significand Left (ED)
SRXT    ED49 RXF    . ..9Z Shift Significand Right (ED)
TDCET   ED50 RXE    c ...Z Test Data Class (SD)
TDGET   ED51 RXE    c ...Z Test Data Group (SD)
TDCDT   ED54 RXE    c ...Z Test Data Class (LD)
TDGDT   ED55 RXE    c ...Z Test Data Group (LD)
TDCXT   ED58 RXE    c ...Z Test Data Class (ED)
TDGXT   ED59 RXE    c ...Z Test Data Group (ED)
LEY     ED64 RXYa   . ...Z Load (Short) =4 . E
LDY     ED65 RXYa   . ...Z Load (Long) =8 . D
STEY    ED66 RXYa   . ...Z Store (Short) =4
STDY    ED67 RXYa   . ...Z Store (Long) =8
CZDT    EDA8 RSLb   A ..9Z Convert to Zoned (from LD) =l(L2)
CZXT    EDA9 RSLb   A ..9Z Convert to Zoned (from ED) =l(L2)
CDZT    EDAA RSLb   . ..9Z Convert from Zoned (to LD) =l(L2)
CXZT    EDAB RSLb   . ..9Z Convert from Zoned (to ED) =l(L2)
CPDT    EDAC RSLb   A ...Z Convert to Packed (from LD) =l(L2) . P
CPXT    EDAD RSLb   A ...Z Convert to Packed (from ED) =l(L2) . P
CDPT    EDAE RSLb   . ...Z Convert from Packed (to LD) =l(L2) . P
CXPT    EDAF RSLb   . ...Z Convert from Packed (to ED) =l(L2) . P
PLO     EE   SSe1   c ..9Z Perform Locked Operation
LMD     EF   SSe    . ..9Z Load Multiple Disjoint (64<-32+32) =hM(4) F F
SRP     F0   SSc    A 679Z Shift and Round Decimal =l(L1) P
MVO     F1   SSb    . 679Z Move with Offset =l(L1)
PACK    F2   SSb    . 679Z Pack             =l(L1) P
UNPK    F3   SSb    c 679Z Unpack           =l(L1) . P
ZAP     F8   SSb    A 679Z Zero and Add     =l(L1) P P
CP      F9   SSb    C 679Z Compare Decimal  =l(L1) P P
AP      FA   SSb    A 679Z Add Decimal      =l(L1) P P
SP      FB   SSb    A 679Z Subtract Decimal =l(L1) P P
MP      FC   SSb    A 679Z Multiply Decimal =l(L1) P P
DP      FD   SSb    A 679Z Divide Decimal   =l(L1) P P
END-INSTRUCTION-DEFINITIONS


The following table is used to convert branch instructions to extended
mnemonics. This makes the generated instruction more human friendly by
translating the mask (M1 field) into the extended mnemonic name. For
example:

     BRC   B'1000',somewhere

...will be converted to either:

     JE    somewhere    (if present after a comparison instruction)
or:
     JZ    somewhere    (if present after an arithmetic instruction)
or:
     JO    somewhere    (if present after a Test Under Mask instruction)

.-- C = Preceding instruction was a comparison instruction
|   A = Preceding instruction was an arithmetic instruction
|   M = Preceding instruction was a Test Under Mask instruction
|   . = Preceding instruction is irrelevant
|
|     .-- Mask field (M1) value in this conditional branch instruction
|     |
|     |  ---Extended Mnemonic for----
|     |  .-------------------------- Branch on Condition
|     |  |     .-------------------- Branch on Condition Register
|     |  |     |     .-------------- Branch Indirect on Condition
|     |  |     |     |     .-------- Branch Relative on Condition
|     |  |     |     |     |     .-- Branch Relative on Condition Long
|     |  |     |     |     |     |
V     V  V     V     V     V     V
Usage M1 BC    BCR   BIC   BRC   BRCL  Meaning
----- -- ----- ----- ----- ----- ----- ----------------------------
BEGIN-EXTENDED-BRANCH-MNEMONICS
.     F  B     BR    BI    J     JLU   Unconditional branch
.     0  NOP   NOPR  -     JNOP  JLNOP No operation
C     2  BH    BHR   BIH   JH    JLH   Branch if High
C     4  BL    BLR   BIL   JL    JLL   Branch if Low
C     8  BE    BER   BIE   JE    JLE   Branch if Equal
C     D  BNH   BNHR  BINH  JNH   JLNH  Branch if Not High
C     B  BNL   BNLR  BINL  JNL   JLNL  Branch if Not Low
C     7  BNE   BNER  BINE  JNE   JLNE  Branch if Not Equal
A     2  BP    BPR   BIP   JP    JLP   Branch if Plus
A     4  BM    BMR   BIM   JM    JLM   Branch if Minus
A     8  BZ    BZR   BIZ   JZ    JLZ   Branch if Zero
A     1  BO    BOR   BIO   JO    JLO   Branch if Overflow
A     D  BNP   BNPR  BINP  JNP   JLNP  Branch if Not Plus
A     B  BNM   BNMR  BINM  JNM   JLNM  Branch if Not Minus
A     7  BNZ   BNZR  BINZ  JNZ   JLNZ  Branch if Not Zero
A     E  BNO   BNOR  BINO  JNO   JLNO  Branch if Not Overflow
M     1  BO    BOR   BIO   JO    JLO   Branch if Ones
M     4  BM    BMR   BIM   JM    JLM   Branch if Mixed
M     8  BZ    BZR   BIZ   JZ    JLZ   Branch if Zeros
M     E  BNO   BNOR  BINO  JNO   JLNO  Branch if Not Ones
M     B  BNM   BNMR  BINM  JNM   JLNM  Branch if Not Mixed
M     7  BNZ   BNZR  BINZ  JNZ   JLNZ  Branch if Not Zeros
END-EXTENDED-BRANCH-MNEMONICS

.-- C = Preceding instruction was a comparison instruction
|   A = Preceding instruction was an arithmetic instruction
|   M = Preceding instruction was a Test Under Mask instruction
|   . = Preceding instruction is irrelevant
|
|     .-- Mask field (M4) value in this Select instruction
|     |
|     |  ---Extended Mnemonic for----
|     |  .------------------ Select (32)
|     |  |       .---------- Select (64)
|     |  |       |       .-- Select High
|     |  |       |       |
|     |  |       |       |
|     |  |       |       |
V     V  V       V       V
Usage M4 SELR    SELGR   SELFHR        Meaning
----- -- -----   -----   -----         ----------------------------
BEGIN-EXTENDED-SELECT-MNEMONICS
C     2  SELRH   SELGRH  SELFHRH       Select if High
C     4  SELRL   SELGRL  SELFHRL       Select if Low
C     8  SELRE   SELGRE  SELFHRE       Select if Equal
C     D  SELRNH  SELGRNH SELFHRNH      Select if Not High
C     B  SELRNL  SELGRNL SELFHRNL      Select if Not Low
C     7  SELRNE  SELGRNE SELFHRNE      Select if Not Equal
A     2  SELRP   SELGRP  SELFHRP       Select if Plus
A     4  SELRM   SELGRM  SELFHRM       Select if Minus
A     8  SELRZ   SELGRZ  SELFHRZ       Select if Zero
A     1  SELRO   SELGRO  SELFHRO       Select if Overflow
A     D  SELRNP  SELGRNP SELFHRNP      Select if Not Plus
A     B  SELRNM  SELGRNM SELFHRNM      Select if Not Minus
A     7  SELRNZ  SELGRNZ SELFHRNZ      Select if Not Zero
A     E  SELRNO  SELGRNO SELFHRNO      Select if Not Overflow
M     1  SELRO   SELGRO  SELFHRO       Select if Ones
M     4  SELRM   SELGRM  SELFHRM       Select if Mixed
M     8  SELRZ   SELGRZ  SELFHRZ       Select if Zeros
M     E  SELRNO  SELGRNO SELFHRNO      Select if Not Ones
M     B  SELRNM  SELGRNM SELFHRNM      Select if Not Mixed
M     7  SELRNZ  SELGRNZ SELFHRNZ      Select if Not Zeros
END-EXTENDED-SELECT-MNEMONICS


The following table is used to give a hint as to what some SVCs are used for
on z/OS. This helps to understand the function of the disassembled machine code.

BEGIN-SVC-LIST
.-- Supervisor call number in hex
|
V
SVC ZOS
--- --------
00  EXCP/XDAP
01  WAIT/WAITR/PRTOV
02  POST
03  EXIT
04  GETMAIN
05  FREEMAIN
06  LINK
07  XCTL
08  LOAD
09  DELETE
0A  GETMAIN/FREEMAIN
0B  TIME
0C  SYNCH
0D  ABEND
0E  SPIE
0F  ERREXCP
10  PURGE
11  RESTORE
12  BLDL/FIND
13  OPEN
14  CLOSE
15  STOW
16  OPEN
17  CLOSE
18  DEVTYPE
19  TRKBAL
1A  CATALOG/INDEX/LOCATE
1B  OBTAIN
1D  SCRATCH
1E  RENAME
1F  FEOV
20  REALLOC
21  IOHALT
22  MGCR/MGCRE/QEDIT
23  WTO/WTOR
24  WTL
25  SEGLD/SEGWT
27  LABEL
28  EXTRACT
29  IDENTIFY
2A  ATTACH/ATTACHX
2B  CIRB
2C  CHAP
2D  OVLYBRCH
2E  TTIMER/STIMERM(TEST/CANCEL)
2F  STIMER/STIMERM(SET)
30  DEQ
33  SNAP/SNAPX/SDUMP/SDUMPX
34  RESTART
35  RELEX
36  DISABLE
37  EOV
38  ENQ/RESERVE
39  FREEDBUF
3A  RELBUF/REQBUF
3B  OLTEP
3C  STAE/ESTAE
3E  DETACH
3F  CHKPT
40  RDJFCB
42  BTAMTEST
44  SYNADAF/SYNADRLS
45  BSP
46  GSERV
47  ASGNBFR/BUFINQ/RLSEBFR
48  IEAVVCTR
49  SPAR
4A  DAR
4B  DQUEUE
4C  IFBSVC76
4E  LSPACE
4F  STATUS
51  SETPRT/SETDEV
53  SMFWTM/SMFEWTM
54  GRAPHICS
55  IGC0008E
56  ATLAS
57  DOM
5B  VOLSTAT
5C  TCBEXCP
5D  TGET/TPG/TPUT
5E  STCC
5F  SYSEVENT
60  STAX
61  IGC0009G
62  PROTECT
63  DYNALLOC
64  IKJEFF00
65  QTIP
66  AQCTL
67  XLATE
68  TOPCTL
69  IMGLIB
6B  MODESET
6D  IGC0010F
6F  IGC111
70  PGRLSE
71  PGFIX/PGFREE/PGLOAD/PGOUT/PGANY
72  EXCPVR
74  IECTSVC
75  DEBCHK
77  TESTAUTH
78  GETMAIN/FREEMAIN
79  VSAM
7A  Extended LOAD/LINK/XCTL
7B  PURGEDQ
7C  TPIO
7D  EVENTS
82  RACHECK
83  RACINIT
84  RACLIST
85  RACDEF
89  IEAVEDS0
8A  PGSER
8B  CVAF
8F  GENKEY/RETKEY/CIPHER/EMK
92  BPESVC
CA  z/VM CMS Command
CB  z/VM CMS Command
CC  z/VM CMSCALL
END-SVC-LIST

The following table is used to translate floating point special values into
nominal values that can be assembled by HLASM. Strictly, +/-0 are not special
values, but they are common enough to translate directly rather than perform
an elaborate conversion.

.-- Type (t) and Type Extension (e)
|   EH = Short Hex Floating Point (HFP)
|   EB = Short Binary Floating Point (BFP)
|   ED = Short Decimal Floating Point (DFP)
|   DH = Long Hex Floating Point (HFP)
|   DB = Long Binary Floating Point (BFP)
|   DD = Long Decimal Floating Point (DFP)
|
V
te  Value             Nominal value
--  ----------------  -------------
BEGIN-FP-CONSTANTS
EH  00000000          +0
EH  00000001          +(DMIN)        Minimum denormalized HFP number
EH  00100000          +(MIN)         Minimum HFP number
EH  7FFFFFFF          +(MAX)         Maximum HFP number
EH  80000000          -0
EH  80000001          -(DMIN)
EH  80100000          -(MIN)
EH  FFFFFFFF          -(MAX)
EB  00000000          +0
EB  00000001          +(DMIN)        Minimum subnormal BFP number
EB  00800000          +(MIN)
EB  7F7FFFFF          +(MAX)
EB  7F800000          +(INF)         Infinity
EB  7FA00000          +(SNAN)        Signaling Not-A-Number
EB  7FC00000          +(NAN)         Not-A-Number
EB  7FE00000          +(QNAN)        Quiet Not-A-Number
EB  80000000          -0
EB  80000001          -(DMIN)
EB  80800000          -(MIN)
EB  FF7FFFFF          -(MAX)
EB  FF800000          -(INF)
EB  FFA00000          -(SNAN)
EB  FFC00000          -(NAN)
EB  FFE00000          -(QNAN)
ED  22500000          +0
ED  00000001          +(DMIN)        Minimum subnormal DFP number
ED  04000000          +(MIN)
ED  77F3FCFF          +(MAX)
ED  78000000          +(INF)
ED  7C000000          +(NAN)
ED  7E000000          +(SNAN)
ED  A2500000          -0
ED  80000001          -(DMIN)
ED  84000000          -(MIN)
ED  F7F3FCFF          -(MAX)
ED  F8000000          -(INF)
ED  FC000000          -(NAN)
ED  FE000000          -(SNAN)
DH  0000000000000000  +0
DH  0000000000000001  +(DMIN)
DH  0010000000000000  +(MIN)
DH  7FFFFFFFFFFFFFFF  +(MAX)
DH  8000000000000000  -0
DH  8000000000000001  -(DMIN)
DH  8010000000000000  -(MIN)
DH  FFFFFFFFFFFFFFFF  -(MAX)
DB  0000000000000000  +0
DB  0000000000000001  +(DMIN)
DB  0010000000000000  +(MIN)
DB  7FEFFFFFFFFFFFFF  +(MAX)
DB  7FF0000000000000  +(INF)
DB  7FF4000000000000  +(SNAN)
DB  7FF8000000000000  +(NAN)
DB  7FFC000000000000  +(QNAN)
DB  8000000000000000  -0
DB  8000000000000001  -(DMIN)
DB  8010000000000000  -(MIN)
DB  FFEFFFFFFFFFFFFF  -(MAX)
DB  FFF0000000000000  -(INF)
DB  FFF4000000000000  -(SNAN)
DB  FFF8000000000000  -(NAN)
DB  FFFC000000000000  -(QNAN)
DD  2238000000000000  +0
DD  0000000000000001  +(DMIN)
DD  0400000000000000  +(MIN)
DD  77FCFF3FCFF3FCFF  +(MAX)
DD  7800000000000000  +(INF)
DD  7C00000000000000  +(NAN)
DD  7E00000000000000  +(SNAN)
DD  A238000000000000  -0
DD  8000000000000001  -(DMIN)
DD  8400000000000000  -(MIN)
DD  F7FCFF3FCFF3FCFF  -(MAX)
DD  F800000000000000  -(INF)
DD  FC00000000000000  -(NAN)
DD  FE00000000000000  -(SNAN)
END-FP-CONSTANTS
*/