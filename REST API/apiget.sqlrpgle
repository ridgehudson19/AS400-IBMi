**FREE
//MAKE SURE YOU INCLUDE LIBRARY 'LIBHTTP' and 'YAJL' BEFORE COMPILING
ctl-opt dftactgrp (*no) bnddir('HTTPAPI');
ctl-opt bnddir('YAJL') DECEDIT('0.');

      /include qrpglesrc,httpapi_h

dcl-s URL char(300);
dcl-s jsonData char(100000);
dcl-s i int(10);

//dcl-ds holiday dim(20) qualified;
    //date char(10);
    //localName char(50);
    //name char(50);
    //countryCode char(2);
    //fixed ind;
    //global ind;
    //num_counties int(10);
    //counties char(5) dim(50);
    //launchYear packed(4:0);
    //type char(10);
//end-ds;

dcl-ds pgmStat psds;
    numElements int(20) pos(372);
end-ds;

dcl-ds Holiday dim(30) qualified;
    date char(10);
    localName char(30);
    name char(30);
    countryCode char(2);
    fixed ind;
    global ind;
    num_counties int(10);
    counties char(5) dim(50);
    launchYear char(5);
    type char(20);
end-ds;

http_debug(*ON);

URL = 'http://pub400.com:3030/url';
jsonData = http_string( 'GET' : URL);
data-into Holiday %data(jsonData:'case=any countprefix=num_ allowextra=yes')
                  %parser('YAJLINTO');


for i=1 to numElements;
    if Holiday(i).Type = 'Public';
        dsply Holiday(i).localName;
        dsply Holiday(i).date;
    endif;
endfor;


*inlr = *on;

