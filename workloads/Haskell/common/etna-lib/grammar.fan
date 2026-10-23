# (T E (Key (-9)) (Val True) (T E (Key (-4)) (Val True) (T (T (T (T E (Key 0) (Val True) E) (Key 2) (Val True) E) (Key 3) (Val True) (T E (Key 4) (Val True) (T E (Key 7) (Val True) E))) (Key 8) (Val False) (T E (Key 9) (Val False) E))),Key 4,Key 4,Val False)

<decimal_integer> ::= <non_zero_digit> <digit>*
<non_zero_digit> ::= r'[1-9]'
<digit> ::= r'[0-9]'

<key> ::= "Key " <decimal_integer>
<value> ::= "Val " ("True" | "False")

<tree> ::= "T " ( "(" <tree> ")" | "E") " (" <key> ") (" <value> ") " ( "(" <tree> ")" | "E" )
