Definitions.

IDENTIFIER  = [a-zA-Z_]+
WHITESPACE = [\s\t\n\r]
INTEGER = [0-9]+
STRING = \"[^"]*\"
SCRIPT = \"\"\"([^"]*(\"?\"?[^"]))*\"\"\"
JSON_PATH = \$\{[^}]*\}

Rules.

{IDENTIFIER}  : {token, {identifier,  TokenLine, list_to_binary(TokenChars)}}.
{INTEGER}  : {token, {integer,  TokenLine, list_to_integer(TokenChars)}}.
{STRING}  : {token, {string,  TokenLine, string_to_binary(TokenChars)}}.
{JSON_PATH} : {token, {json_path,  TokenLine, json_path_to_binary(TokenChars)}}.
{SCRIPT}  : {token, {string,  TokenLine, script_to_binary(TokenChars)}}.
\|            : {token, {'|',  TokenLine}}.
\.            : {token, {'.',  TokenLine}}.
\,            : {token, {',',  TokenLine}}.
\:            : {token, {':',  TokenLine}}.
\(            : {token, {'(',  TokenLine}}.
\)            : {token, {')',  TokenLine}}.
\[            : {token, {'[',  TokenLine}}.
\]            : {token, {']',  TokenLine}}.
\{            : {token, {'{',  TokenLine}}.
\}            : {token, {'}',  TokenLine}}.
{WHITESPACE}+ : skip_token.
{SCRIPT} : {token, {script,  TokenLine, list_to_binary(TokenChars)}}.

Erlang code.

string_to_binary(TokenChars) ->
    L1 = lists:droplast(TokenChars),
    [_ | L2] = L1,
    list_to_binary(L2).

script_to_binary(TokenChars) ->
    Len = length(TokenChars),
    {L1, _} = lists:split(Len - 3, TokenChars),
    [_, _, _ | L2] = L1,
    list_to_binary(L2).

json_path_to_binary(TokenChars) ->
    L1 = lists:droplast(TokenChars),
    [_, _ | L2] = L1,
    {json_path, list_to_binary(L2)}.
