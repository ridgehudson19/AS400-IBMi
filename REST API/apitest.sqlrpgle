      *
     H DFTACTGRP(*NO) BNDDIR('HTTPAPI')
      *
      /include qrpglesrc,httpapi_h
      *
     D rc              s             10I 0
     D msg             s             52A
     D URL             s            300A   varying
     D IFS             s            256A   varying

     c                   callp     http_debug(*ON)
      *
     c                   eval      URL = 'https://httpbin.org/get'
     c                   eval      IFS = '/home/RHUDSON19/Currency.Txt'
      *
     c                   callp     http_stmf('GET':URL:IFS)
      *
     c                   eval      *inlr = *on

