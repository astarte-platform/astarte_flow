Nonterminals topology blocks block with_props with_prop value array array_elements object object_elements kv_pair.
Terminals '|' '.' ',' ':' '(' ')' '[' ']' '{' '}' identifier integer string.
Rootsymbol topology.

topology -> blocks : lists:reverse('$1').

blocks -> block : ['$1'].
blocks -> blocks '|' block : ['$3' | '$1'].

block -> identifier : {extract_token('$1'), []}.
block -> identifier with_props : {extract_token('$1'), lists:reverse('$2')}.

with_props -> with_prop : ['$1'].
with_props -> with_props with_prop : ['$2' | '$1'].

with_prop -> '.' identifier '(' value ')' : {extract_token('$2'), '$4'}.

value -> string : extract_token('$1').
value -> integer : extract_token('$1').
value -> array : '$1'.
value -> object : maps:from_list('$1').

array -> '[' ']' : [].
array -> '[' array_elements ']' : '$2'.

array_elements -> value : [ '$1' ].
array_elements -> value ',' array_elements : [ '$1' | '$3' ].

object -> '{' '}' : [].
object -> '{' object_elements '}' : '$2'.

object_elements -> kv_pair : [ '$1' ].
object_elements -> kv_pair ',' object_elements : [ '$1' | '$3' ].

kv_pair -> identifier ':' value : {extract_token('$1'), '$3'}.

Erlang code.

extract_token({_Token, _Line, Value}) -> Value.
