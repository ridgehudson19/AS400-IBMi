**FREE

dcl-f usmcap printer oflind(*IN99);
dcl-f usmcad workstn sfile(MAINSFL:RRN#);

dcl-s RRN#         zoned(6); //rrn# used for subfile program
dcl-s count        zoned(6); //generic variable used for counting
dcl-s certpages    zoned(3); //certification of origin number of pages count
dcl-s nonorigpages zoned(3); //non-originating goods number of pages count
dcl-s tempemail    char(70); //temporary work variable for email

dcl-s errorsfound ind;

//number of item lines on first page of:
dcl-c CERT_PAGE1_LINE_COUNT     20; //certification of origin
dcl-c NONORIG_PAGE1_LINE_COUNT  35; //non-originating goods statement
dcl-c CONT_PAGE_LINE_COUNT      55; //continuation page

//input parameters
//printcode    = E(for email) or blank(for print)
//loadcustcode = L(for load) or C(for customer)
//load#        = load# - already validated in DOC2011R

dcl-pi *N;
    printcode     char(1); //E for email, BLANK for no email
    loadcustcode  char(1); //L for Load, C for Customer
    load#         zoned(6);
end-pi;

exec sql
    set option commit=*none;

//**** Begin main program ****

 if loadcustcode='L';
        EXEC SQL
            SELECT LHCUSN, SUBSTR(LHWHSE,1,2)
            INTO :CUST#, :COMPANY#
            FROM LLH
            WHERE LHLOAD=:LOAD#
            LIMIT 1;

    exfmt load;
elseif loadcustcode='C';
    exsr GetSummary;
endif;


if (printcode='E' or printcode='B') and not *in03 and not *in12;
    exsr GetEmails;
endif;




if not *in03 and not *in12;
    exsr CalculateDates;
    exsr CalculateNumPages;

    //Write Certificate of Origin Page
    if certpages>0;
        formcode='O';
        titleline='CERTIFICATION OF ORIGIN';
        exsr WriteUSMCA;
    endif;

    //Write Non-Originating Goods Statement
    if nonorigpages>0;
        formcode='N';
        titleline='NON-ORIGINATING GOODS';
        exsr WriteUSMCA;
    endif;
endif;

*inlr=*on;
return;
//**** End main program ****

begsr GetSummary;
    bshipd=%dec(%date()-%years(1));
    eshipd=%dec(%date());

    bblanketd=bshipd;
    eblanketd=eshipd;

    errorsfound=*on;

   DoW errorsfound=*on and not *in03 and not *in12;
        exfmt summary;
            *in51=*off;
            *in52=*off;
            *in53=*off;
            *in54=*off;
            errmsg='';

        select;
            when *in05=*on;
                cust#=0;
                shipto#=0;
                itaxid='';

                bshipd=%dec(%date()-%years(1));
                eshipd=%dec(%date());

                bblanketd=bshipd;
                eblanketd=eshipd;
            other;
            EXEC SQL
                SELECT COUNT(*)
                  INTO :COUNT
                  FROM RCML01
                  WHERE CCUST=:CUST#;

            if sqlcod<>0;
                count=0;
            endif;


            if count=0;
                errmsg='Customer #' + %char(cust#) + ' does not exist';
                *in51=*on;
            else;
                EXEC SQL
                    SELECT COUNT(*)
                      INTO :COUNT
                      FROM ESTL01
                      WHERE TCUST=:CUST#
                        AND TSHIP=:SHIPTO#;

                if sqlcod<>0;
                    count=0;
                endif;

                if count=0 and *in51=*off and shipto#<>0;
                    errmsg='Customer ship to #' + %char(shipto#) +
                           ' does not exist';
                    *in52=*on;
                endif;
            endif;

            EXEC SQL
                SELECT CCOMP
                INTO :COMPANY#
                FROM RCML01
                WHERE CCUST=:CUST#;


            monitor;
            if %date(bshipd) > %date(eshipd)
              and *in51=*off and *in52=*off;
             errmsg='Begin ship date cannot be greater than the end ship date.';
              *in53=*on;
           endif;
           on-error;
              errmsg='Ship dates must be a valid date. ' +
                     'Example: 20220131.';
              *in53=*on;
           endmon;

           exsr CalculateNumPages;
           if numpages=0 and *in51=*off and *in52=*off and *in53=*off;
              errmsg='This date range has 0 items. ' +
                     'Enter a date range with shipments.';
              *in53=*on;
           endif;

            monitor;
            if (%date(bblanketd)+%years(1)) < %date(eblanketd)
              and *in51=*off and *in52=*off and *in53=*off ;
              errmsg='Blanket date period cannot be greater ' +
                     'than a 12 month period.';
              *in54=*on;
           endif;
           on-error;
              errmsg='Blanket dates must be a valid date. ' +
                     'Example: 20220131.';
              *in54=*on;
           endmon;

           if *in51=*on or *in52=*on or *in53=*on or *in54=*on;
             errorsfound=*on;
           else;
             errorsfound=*off;
           endif;

        endsl;
  enddo;
endsr;

begsr CalculateNumPages;
    count=0;
    numpages=0;


    if loadcustcode='L';
    //calculate numpages - certification of origin
    EXEC SQL
        SELECT COUNT(*)
            INTO :COUNT
            FROM (
                SELECT SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2),
                LLPROD, IFNULL(IXITEM,''),
                CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END,
                IORIGN, 'B'
                FROM LLL
                LEFT JOIN IIML01 ON LLPROD = IPROD
                LEFT JOIN EIXL01 ON LLCUSN=IXCUST AND LLPROD=IXPROD
                LEFT JOIN ZCCL01 ON IREF04 = CCCODE AND CCTABL = 'AP_NAFTA'
                WHERE IORIGN IN ('US','MX','CA') AND LLLOAD = :LOAD#
                GROUP BY SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2),
                LLPROD, IFNULL(IXITEM,''),
                CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END,
                IORIGN, 'B'
                );

    if sqlcod<>0;
        count=0;
    endif;

    if count>0 and count<=CERT_PAGE1_LINE_COUNT;
       numpages=1;
    elseif count>CERT_PAGE1_LINE_COUNT;
       numpages=%dec((count-CERT_PAGE1_LINE_COUNT)/CONT_PAGE_LINE_COUNT:3:0)+1;
       if %rem(count-CERT_PAGE1_LINE_COUNT:CONT_PAGE_LINE_COUNT)>0;
           numpages=numpages+1;
       endif;
    endif;

    certpages=numpages;

    //calculate numpages - non-originating goods
    EXEC SQL
        SELECT COUNT(*)
            INTO :COUNT
            FROM (
                SELECT SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2),
                LLPROD, IFNULL(IXITEM,''),
                CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END,
                IORIGN, 'B'
                FROM LLL
                LEFT JOIN IIML01 ON LLPROD = IPROD
                LEFT JOIN EIXL01 ON LLCUSN=IXCUST AND LLPROD=IXPROD
                LEFT JOIN ZCCL01 ON IREF04 = CCCODE AND CCTABL = 'AP_NAFTA'
                WHERE IORIGN NOT IN ('US','MX','CA') AND LLLOAD = :LOAD#
                GROUP BY SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2),
                LLPROD, IFNULL(IXITEM,''),
                CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END,
                IORIGN, 'B'
                );

    if sqlcod<>0;
        count=0;
    endif;

    if count>0 and count<=NONORIG_PAGE1_LINE_COUNT;
        numpages=numpages+1;
    elseif count>NONORIG_PAGE1_LINE_COUNT;
        numpages=numpages +
         %dec((count-NONORIG_PAGE1_LINE_COUNT)/CONT_PAGE_LINE_COUNT:3:0) + 1;

        if %rem(count-NONORIG_PAGE1_LINE_COUNT:CONT_PAGE_LINE_COUNT)>0;
            numpages=numpages+1;
        endif;
    endif;

    nonorigpages=numpages-certpages;


    elseif loadcustcode='C';
      EXEC SQL
        SELECT COUNT(*)
        INTO :COUNT
        FROM (
            SELECT SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2),
                     ILPROD, IFNULL(IXITEM,''),
                     CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END,
                     IORIGN,'B'
            FROM SIL
            LEFT JOIN SIH ON SIINVN=ILINVN AND SIORD=ILORD AND SICUST=ILCUST
            LEFT JOIN IIML01 ON IPROD=ILPROD
            LEFT JOIN EIXL01 ON ILCUST=IXCUST AND ILPROD=IXPROD
            LEFT JOIN ZCCL01 ON IREF04 = CCCODE AND CCTABL='AP_NAFTA'
            WHERE ILDATE BETWEEN :BSHIPD AND :ESHIPD
            AND ILCUST=:CUST#
            AND IORIGN IN ('US','MX','CA')
            AND 1 =  CASE WHEN :SHIPTO#=0
                     THEN 1
                     WHEN :SHIPTO#<>0 AND SISTN=:SHIPTO#
                     THEN 1
                     ELSE 0
                     END
            GROUP BY SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2),
                     ILPROD, IFNULL(IXITEM,''),
                     CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END,
                     IORIGN,'B'
               );

    if sqlcod<>0;
        count=0;
    endif;

    if count>0 and count<=CERT_PAGE1_LINE_COUNT;
       numpages=1;
    elseif count>CERT_PAGE1_LINE_COUNT;
       numpages=%dec((count-CERT_PAGE1_LINE_COUNT)/CONT_PAGE_LINE_COUNT:3:0)+1;
       if %rem(count-CERT_PAGE1_LINE_COUNT:CONT_PAGE_LINE_COUNT)>0;
           numpages=numpages+1;
       endif;
    endif;

    certpages=numpages;

    //calculate numpages - non-originating goods
      EXEC SQL
        SELECT COUNT(*)
        INTO :COUNT
        FROM (
            SELECT SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2),
                     ILPROD, IFNULL(IXITEM,''),
                     CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END,
                     IORIGN,'B'
            FROM SIL
            LEFT JOIN SIH ON SIINVN=ILINVN AND SIORD=ILORD AND SICUST=ILCUST
            LEFT JOIN IIML01 ON IPROD=ILPROD
            LEFT JOIN EIXL01 ON ILCUST=IXCUST AND ILPROD=IXPROD
            LEFT JOIN ZCCL01 ON IREF04 = CCCODE AND CCTABL='AP_NAFTA'
            WHERE ILDATE BETWEEN :BSHIPD AND :ESHIPD
            AND ILCUST=:CUST#
            AND IORIGN NOT IN ('US','MX','CA')
            AND 1 =  CASE WHEN :SHIPTO#=0
                     THEN 1
                     WHEN :SHIPTO#<>0 AND SISTN=:SHIPTO#
                     THEN 1
                     ELSE 0
                     END
            GROUP BY SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2),
                     ILPROD, IFNULL(IXITEM,''),
                     CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END,
                     IORIGN,'B'
               );

    if sqlcod<>0;
        count=0;
    endif;

    if count>0 and count<=NONORIG_PAGE1_LINE_COUNT;
        numpages=numpages+1;
    elseif count>NONORIG_PAGE1_LINE_COUNT;
        numpages=numpages +
         %dec((count-NONORIG_PAGE1_LINE_COUNT)/CONT_PAGE_LINE_COUNT:3:0) + 1;

        if %rem(count-NONORIG_PAGE1_LINE_COUNT:CONT_PAGE_LINE_COUNT)>0;
            numpages=numpages+1;
        endif;
    endif;

    nonorigpages=numpages-certpages;



    endif;

endsr;

begsr clearsfl;
    *in50=*off;
    write mainctl;
    *in50=*on;

    rrn#=0;
endsr;

begsr loadsfl;
    dow RRN# < 20;
        rrn#+=1;
        write mainsfl;
    enddo;

    write footer;
    exfmt mainctl;
endsr;

begsr GetEmails;
    exsr clearsfl;
    exsr loadsfl;

    if not *in03 and not *in12;
        EXEC SQL
            CREATE TABLE QTEMP/EMAILS (
                EMAIL CHAR(70));


            exsr WriteEmailsToQTEMPEMAILS;

        if count>0;
            exsr WriteAPIPage;
        endif;

        EXEC SQL
            DROP TABLE QTEMP/EMAILS;
    endif;
endsr;


begsr CalculateDates;
    todaydte = %char(%subdt(%date():*MONTHS)) + '-' +
               %char(%subdt(%date():*DAYS)) + '-' +
               %char(%subdt(%date():*YEARS));

    if loadcustcode='L';
        EXEC SQL
            SELECT SUBSTR(LHSDTE,5,2)||'-'||
                   SUBSTR(LHSDTE,7,2)||'-'||
                   SUBSTR(LHSDTE,1,4) BEGIN_BLANKET_DTE
              INTO :BLANKTLINE
              FROM LLH
              WHERE LHLOAD=:LOAD#
                AND LHCUSN=:CUST#
                LIMIT 1;

        blanktline = 'ESSENTRA LOAD #' + %char(load#) +
                     '. SHIP DATE ' + %trim(blanktline) + '.';

    elseif loadcustcode='C';

        blanktline = 'SHIPMENTS FROM ' +
                      %subst(%char(bblanketd):5:2) + '-' +
                      %subst(%char(bblanketd):7:2) + '-' +
                      %subst(%char(bblanketd):1:4) +
                      ' TO ' +
                      %subst(%char(eblanketd):5:2) + '-' +
                      %subst(%char(eblanketd):7:2) + '-' +
                      %subst(%char(eblanketd):1:4) + '.';
    endif;
endsr;



begsr WriteEmailsToQTEMPEMAILS;
    count=0;
    DoW count=0 and not *in03 and not *in12;
        readc mainsfl;

        DoW not %eof();
            EXEC SQL
                INSERT INTO QTEMP/EMAILS VALUES (:SEMAIL);
            readc mainsfl;
        enddo;

        EXEC SQL
            DELETE FROM QTEMP/EMAILS WHERE EMAIL='';

        EXEC SQL
            SELECT COUNT(*)
            INTO: COUNT
            FROM QTEMP/EMAILS;

       if sqlcod<>0;
           count=0;
       endif;

       if count=0;
             errmsg='Email address cannot be blank.';
             write footer;
             exfmt mainctl;
        endif;
    EndDo;
endsr;

begsr WriteAPIPage;

    //email recipients
    EXEC SQL
        DECLARE EMAILS CURSOR FOR
            SELECT EMAIL FROM QTEMP/EMAILS;

    EXEC SQL
        OPEN EMAILS;

    EXEC SQL
        FETCH EMAILS INTO :TEMPEMAIL;

    dow sqlcod <> 100;
        apiline='*DSE *EM' + %trim(tempemail); //+ ' *FCEssentra';
        write api;

        EXEC SQL
            FETCH EMAILS INTO :TEMPEMAIL;
    enddo;

    EXEC SQL
        CLOSE EMAILS;

    //email sender
    apiline='*UP' + 'CXJ';
    write api;

    //email subject
    apiline='*EU USMCA Cust #' + %char(cust#);
    if shipto#<>0;
    apiline=%trim(apiline) + '-' + %char(shipto#);
    endif;

    if loadcustcode='L';
        apiline = %trim(apiline) + ' Load #' + %char(load#);
    elseif loadcustcode='C';
        apiline = %trim(apiline) + ' Shipments ' +
                      %subst(%char(bblanketd):5:2) + '-' +
                      %subst(%char(bblanketd):7:2) + '-' +
                      %subst(%char(bblanketd):1:4) +
                      ' to ' +
                      %subst(%char(eblanketd):5:2) + '-' +
                      %subst(%char(eblanketd):7:2) + '-' +
                      %subst(%char(eblanketd):1:4);
    endif;
    write api;

    //attachment name
    apiline='*EN USMCA Cust #' + %char(cust#);
    if shipto#<>0;
        apiline=%trim(apiline) + '-' + %char(shipto#);
    endif;

    if loadcustcode='L';
        apiline = %trim(apiline) + ' Load #' + %char(load#);
    elseif loadcustcode='C';
        apiline = %trim(apiline) + ' Shipments ' +
                      %subst(%char(bblanketd):5:2) + '-' +
                      %subst(%char(bblanketd):7:2) + '-' +
                      %subst(%char(bblanketd):1:4) +
                      ' to ' +
                      %subst(%char(eblanketd):5:2) + '-' +
                      %subst(%char(eblanketd):7:2) + '-' +
                      %subst(%char(eblanketd):1:4);
    endif;
    write api;

    write endpage;
endsr;

begsr WriteUSMCA;
    write title;

    //get company (EXPORTER) information
    if company#=11;
    EXEC SQL
        SELECT 'ESSENTRA COMPONENTS', UPPER(LADD1) WADDRESSA,
        TRIM(UPPER(LADD2))||TRIM(UPPER(LADD3))||' '||TRIM(WMSTE)||', '||
        TRIM(LPOAS)||' '||LCOUN WADDRESSB,LPHON WPHONE
        INTO :ECMPNAME, :EADDRESSA, :EADDRESSB, :EPHONE
        FROM IWML01
        WHERE LWHS LIKE '%A'
        AND SUBSTR(LWHS,1,2)=:COMPANY#;

    else;
    EXEC SQL
        SELECT 'ESSENTRA COMPONENTS', UPPER(CMPAD1),
              TRIM(UPPER(COADR4))||case when :company#  in (40,50) then' CA'
              else ' US' end, '1-'||COADR3, UPPER(CODATN)
        INTO :ECMPNAME, :EADDRESSA, :EADDRESSB, :EPHONE
        FROM RCOL01
        WHERE CMPNY=:COMPANY#;
    endif;

    //get company (EXPORTER) email and tax ID
            EXEC SQL
                SELECT CASE WHEN CODATN=''
                            THEN 'SALESUS@ESSENTRACOMPONENTS.COM'
                            ELSE UPPER(CODATN) END, CVATNM
                INTO :EEMAIL, :ETAXID
                FROM RCOL01
                WHERE CMPNY=:COMPANY#;

//ticket #467692 - remove importer details for company 45. 7/17/2020.
if company# <> 45;

    if shipto#=0;
        //get customer (IMPORTER) information
        //if addline2=blank, set addline2=addline3 and addline3=blank.
        EXEC SQL
            SELECT UPPER(CNME), UPPER(CAD1),
            CASE WHEN CAD2<>'' THEN UPPER(CAD2) ELSE
            TRIM(UPPER(CMAD6))||CASE WHEN CMAD6<>'' THEN ', ' ELSE '' END
            ||CSTE||' '||TRIM(CZIP)||' '||CCOUN END ADDRESS2B,
            CASE WHEN CAD2='' THEN '' ELSE
            TRIM(UPPER(CMAD6))||CASE WHEN CMAD6<>'' THEN ', ' ELSE '' END
            ||CSTE||' '||TRIM(CZIP)||' '||CCOUN END ADDRESS2C
            INTO :ICMPNAME, :IADDRESSA, :IADDRESSB, :IADDRESSC
            FROM RCML01
            WHERE CCUST=:CUST#;

        //get customer (IMPORTER) phone
        EXEC SQL
            SELECT NMTELP
            INTO :IPHONE
            FROM RNML01
            WHERE NMDEPT = 'Y'
            AND NMTELP<>''
            AND NMCUST=:CUST#
            LIMIT 1;

        //get customer (IMPORTER) email
        EXEC SQL
            SELECT UPPER(NMDATN)
            INTO :IEMAIL
            FROM RNML01
            WHERE NMDEPT = 'Y'
            AND SUBSTR(NMEXTF,1,1) = '1'
            AND NMDATN LIKE '%@%'
            AND NMCUST=:CUST#
            LIMIT 1;
    else;
        EXEC SQL
           SELECT UPPER(TNAME) NAME,UPPER(TADR1) ADDRESS2A,
           CASE WHEN TADR2='' THEN TRIM(UPPER(STAD6))||', '
           ||TRIM(UPPER(TSTE))||' '||TRIM(TPOST)||' '||TRIM(UPPER(TCOUN))
           ELSE UPPER(TADR2) END ADDRESS2B,
           CASE WHEN TADR2='' THEN '' ELSE
           TRIM(UPPER(STAD6))||', '||TRIM(UPPER(TSTE))||' '
           ||TRIM(TPOST)||' '||TRIM(UPPER(TCOUN)) END ADDRESS2C,
           TPHONE PHONE,STDATN EMAIL
           INTO :ICMPNAME, :IADDRESSA, :IADDRESSB, :IADDRESSC, :IPHONE, :IEMAIL
           FROM ESTL01
           WHERE TCUST=:CUST#
             AND TSHIP=:SHIPTO#;
    endif;

endif;


    //get warehouse details
    EXEC SQL
        SELECT UPPER(LDESC) WNAME, UPPER(LADD1) WADDRESSA,
        TRIM(UPPER(LADD2))||TRIM(UPPER(LADD3))||' '||TRIM(WMSTE)||', '||
        TRIM(LPOAS)||' '||LCOUN WADDRESSB,LPHON WPHONE
        INTO :WNAME,:WADDRESSA,:WADDRESSB,:WPHONE
        FROM IWML01
        WHERE LWHS LIKE '%A'
        AND SUBSTR(LWHS,1,2)=:COMPANY#;

    //get newest invoice # (if USMCA is ran by load)
    if loadcustcode='L';
        EXEC SQL
            SELECT MAX(ILINVN)
            INTO: INVOICE#
            FROM SIL
            WHERE ILLOAD=:LOAD#;
    endif;

    //get certifier details
    EXEC SQL
        SELECT CCSDSC,CCNOT1,CCNOT2
          INTO :SIGFILE, :WEMAIL, :CERTNAME
          FROM ZCCL01
          WHERE CCTABL='AP_TWWHS'
          AND CCCODE =:COMPANY#||'A';

    write Header;
    exsr WriteItemLines;

endsr;

begsr WriteItemLines;
    write itemtitle;

    if loadcustcode='L';
    EXEC SQL
          DECLARE ITEMLINES_L CURSOR FOR
            SELECT SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2) TARIFF,
            LLPROD ITEM#, IFNULL(IXITEM,'') CUST_ITEM#,
            CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END DESC,
            IORIGN ORIGIN, 'B' CRITERION
            FROM LLL
            LEFT JOIN IIML01 ON LLPROD = IPROD
            LEFT JOIN EIXL01 ON LLCUSN=IXCUST AND LLPROD=IXPROD
            LEFT JOIN ZCCL01 ON IREF04 = CCCODE AND CCTABL = 'AP_NAFTA'
            WHERE LLLOAD = :LOAD#
                  AND 1= CASE WHEN :FORMCODE='O' AND IORIGN IN ('US','MX','CA')
                          THEN 1
                          WHEN :FORMCODE='N' AND IORIGN NOT IN ('US','MX','CA')
                          THEN 1
                          ELSE 0
                          END
            GROUP BY SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2),
            LLPROD, IFNULL(IXITEM,''),
            CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END,
            IORIGN, 'B'
            ORDER BY LLPROD, IFNULL(IXITEM,'');
       EXEC SQL
        OPEN ITEMLINES_L;

       EXEC SQL
        FETCH ITEMLINES_L
         INTO :HSTARIFF, :ITEM#, :CITEM#, :ITEMDESC, :ORIGIN, :CRITERION;

       count=0;
       DoW sqlcod=0 and
           ((count<CERT_PAGE1_LINE_COUNT and formcode='O') or
            (count<NONORIG_PAGE1_LINE_COUNT and formcode='N'));
           WRITE itemline;
           count=count+1;
           EXEC SQL
               FETCH ITEMLINES_L
                INTO :HSTARIFF, :ITEM#, :CITEM#, :ITEMDESC, :ORIGIN, :CRITERION;
       enddo;

       write endpage;

       if sqlcod=0 and
           ((count=CERT_PAGE1_LINE_COUNT and formcode='O') or
            (count=NONORIG_PAGE1_LINE_COUNT and formcode='N'));
            formcode='C';
            write title;
            write itemtitle;

            count=0;

            DoW sqlcod=0;
                WRITE itemline;
                count=count+1;
                EXEC SQL
                FETCH ITEMLINES_L
                INTO :HSTARIFF, :ITEM#, :CITEM#, :ITEMDESC, :ORIGIN, :CRITERION;

                if sqlcod=0 and count=CONT_PAGE_LINE_COUNT;
                    write endpage;
                    write title;
                    write itemtitle;
                    count=0;
                endif;
            enddo;

            write endpage;
       endif;

       EXEC SQL
           CLOSE ITEMLINES_L;


    elseif loadcustcode='C';
    EXEC SQL
          DECLARE ITEMLINES_C CURSOR FOR
            SELECT SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2) TARIFF,
            ILPROD ITEM#, IFNULL(IXITEM,'') CUST_ITEM#,
            CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END DESC,
            IORIGN ORIGIN, 'B' CRITERION
            FROM SIL
            LEFT JOIN SIH ON SIINVN=ILINVN AND SIORD=ILORD AND SICUST=ILCUST
            LEFT JOIN IIML01 ON IPROD=ILPROD
            LEFT JOIN EIXL01 ON ILCUST=IXCUST AND ILPROD=IXPROD
            LEFT JOIN ZCCL01 ON IREF04 = CCCODE AND CCTABL='AP_NAFTA'
            WHERE ILDATE BETWEEN :BSHIPD AND :ESHIPD
            AND ILCUST=:CUST#
            AND 1 = CASE WHEN :FORMCODE='O' AND IORIGN IN ('US','MX','CA')
                         THEN 1
                         WHEN :FORMCODE='N' AND IORIGN NOT IN ('US','MX','CA')
                         THEN 1
                         ELSE 0
                         END
            AND 1 = CASE WHEN :SHIPTO#=0
                         THEN 1
                         WHEN :SHIPTO#<>0 AND SISTN=:SHIPTO#
                         THEN 1
                         ELSE 0
                         END
            GROUP BY SUBSTR(IMHRMN,1,4)||'.'||SUBSTR(IMHRMN,5,2),
                     ILPROD, IFNULL(IXITEM,''),
                     CASE WHEN CCDESC IS NOT NULL THEN CCDESC ELSE IDESC END,
                     IORIGN,'B';
                            EXEC SQL
        OPEN ITEMLINES_C;

       EXEC SQL
        FETCH ITEMLINES_C
         INTO :HSTARIFF, :ITEM#, :CITEM#, :ITEMDESC, :ORIGIN, :CRITERION;

       count=0;
       DoW sqlcod=0 and
           ((count<CERT_PAGE1_LINE_COUNT and formcode='O') or
            (count<NONORIG_PAGE1_LINE_COUNT and formcode='N'));
           WRITE itemline;
           count=count+1;
           EXEC SQL
               FETCH ITEMLINES_C
                INTO :HSTARIFF, :ITEM#, :CITEM#, :ITEMDESC, :ORIGIN, :CRITERION;
       enddo;

       write endpage;

       if sqlcod=0 and
           ((count=CERT_PAGE1_LINE_COUNT and formcode='O') or
            (count=NONORIG_PAGE1_LINE_COUNT and formcode='N'));
            formcode='C';
            write title;
            write itemtitle;

            count=0;

            DoW sqlcod=0;
                WRITE itemline;
                count=count+1;
                EXEC SQL
                FETCH ITEMLINES_C
                INTO :HSTARIFF, :ITEM#, :CITEM#, :ITEMDESC, :ORIGIN, :CRITERION;

                if sqlcod=0 and count=CONT_PAGE_LINE_COUNT;
                    write endpage;
                    write title;
                    write itemtitle;
                    count=0;
                endif;
            enddo;

            write endpage;
       endif;

       EXEC SQL
           CLOSE ITEMLINES_C;
    endif;

endsr;
