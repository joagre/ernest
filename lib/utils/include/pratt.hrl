-ifndef(PRATT_HRL).
-define(PRATT_HRL, true).

-record(token, {
          name,
          line,
          value,
          children,
          lbp = 0, % left binding power
          nud, % null denotation
          led, % left denotation
          op
         }).

-endif.
