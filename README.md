# DA - Mainframe Disassembler in REXX

## FUNCTION

The DA rexx procedure disassembles the AMBLIST output (or indeed any printable hex) that you are currently editing with ISPF/EDIT. 

This can be very handy for mainframe sites that have somehow lost the source code to an important executable. All you need to do is run the DA edit macro against the output from an AMBLIST module listing of the executable. It is an iterative process, but at the end of the day you will have an assembler source file that, when assembled, should recreate the executable load module. With some effort it should also be possible to reconstruct an equivalent high level language (COBOL, PLI, etc) source file from the assembly language source.


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

## OVERVIEW

Disassembly is usually an iterative process:

1.  Run DA on the AMBLIST output. This will help to
    identify which areas are data and which are code.

    If you see a comment in the output like `<-- TODO
    (not code)` it means that the dissassembler was in
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


## SYNTAX

* When invoked from TSO to create an AMBLIST job:

   `TSO DA [dsn]`

   Where,

   * `dsn` - Identifies the load module to be printed using AMBLIST. The
            dataset name must be fully qualified, without quotation marks, and
            include the module name in parentheses.

    For example:

    `TSO DA SYS1.LPALIB(IEFBR14)`

* When invoked from ISPF/EDIT to dissassemble AMBLIST output:

   `DA [(options...]`

   Where,

   * `options` are:

     `STAT`    - Generate instruction format and mnemonic usage statistics and append them as comments to the end of the generated source file.

     `TEST`    - Generate a source file containing one instance of every instruction to exercise the assembler. When assembled into a module, the
     result can be used to test the disassembler.

     `ASM`     - Generate JCL to assemble the file being edited.

## NOTES

1. As new instructions are added to the z/Series instruction set, it will be necessary to define them in
    the comments of the DA rexx procedure marked by BEGIN-xxx and END-xxx
    comments. Otherwise the new instructions will be
    treated as data.

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
    | `,`    | Scan following hex as CODE and generate a label. <br/>*Remember: Comma=Code* |
    | `.`    | Scan following hex as DATA and generate a label. <br/>*Remember: Dot=Data* |
    | <code>&#124;</code>    | Scan following hex as DATA but do NOT generate a label. This can be used to break up data into logical  pieces that do not need to be addressed individually via a label. <br/>*Remember: Bar=Break* |
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
     dissassembled lines and ignore the truncation warning.

   * The remaining columns contain the following information that is useful during disassembly:
     
     location counter, instruction in hex, instruction format and
     the target operand length if any.

1. Examine the "Undefined labels" report at the end of the disassembly to help you 
   identify where to insert CODE and DATA action markers. 
   Labels will be created at each action marker location 
   (except for the `|` action marker).

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
  Inserts a comment into the generated source file with the format:

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


* ## (*x*)
    Converts subsequent hex to data type *x*, where *x* can be one of the following:
    | x   | Type      | Length | Generates (for example) |
    | --- | ---       | --- | --- |
    | `A` | Address   |4| `AL4(L304)` |
    | `B` | Binary    |1| `B'10110011'` |
    | `C` | Character |n| `CL9'Some text'` |
    | `F` | Fullword  |4| `F'304'` |
    | `H` | Halfword  |2| `H'304'` |
    | `P` | Packed    |n| `PL2'304'` |
    | `S` | S-type    |2| `S(X'020'(R12))` |
    | `X` | Hex       |n| `XL2'0304'` |

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
    The label cannot be `R0` to `R15`, or `A`, `B`, `C`, `D`, `F`, `H`, `P`, `S` or
    `X` as those have special meanings as described above.
    The maximum length of a label assigned in this way
    is 8 (for pragmatic reasons).

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

* ## (.=*xxx*)    
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
