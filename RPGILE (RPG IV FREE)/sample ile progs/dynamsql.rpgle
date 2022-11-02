        dcl-s sqlstmt char(100);
        dcl-s myname char(10);
      /free

         sqlstmt = 'insert into mytable values (?)';
         myname = 'bob';

             exec sql
                prepare dynSQLstmt
                   from :sqlstmt;


              dsply sqlcod;

              exec sql
                execute dynSQLstmt
                    using :myname;


             dsply sqlcod;


         *inlr=*on;
         return;
      /end-free
