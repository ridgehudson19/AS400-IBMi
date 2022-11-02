      //MAKE SURE YOU INCLUDE LIBRARY 'LIBHTTP' BEFORE COMPILING

     H DFTACTGRP(*NO) BNDDIR('HTTPAPI')

      /include qrpglesrc,httpapi_h

      * Note: The BNDDIR, above, tells ILE how to find the HTTPAPIR4
      *       service program which contains the routines.
      *       The /COPY directive provides prototypes and constants
      *       needed to call the routines.

     D URL             S            300A    varying
     D IFS             S            256A    varying

      *********************************************************
      *  Turning on debugging.
      *
      *     Calling http_debug and passing *ON will turn on
      *     HTTPAPI's debugging support.  It will write a debug
      *     log file to the IFS in /tmp/httpapi_debug.txt
      *     with loads of tech info about the HTTP transaction.
      *
      *     The debug file is crucial if you have problems!
      *********************************************************
     c                   callp     http_debug(*ON)

      /FREE
        URL = 'http://pub400.com:3060/url';
        IFS = '/home/RHUDSON19/testing.pdf';
      /END-FREE

     C* Now call HTTPAPI's routine that receives to a stream file
     C*  with the above variables as parameters. It will download
     C*  to the IFS.
     C*
     c                   callp     http_stmf('GET': URL: IFS)

     c                   eval      *inlr = *on
