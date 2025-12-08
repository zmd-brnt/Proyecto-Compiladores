%{
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int add_ident(const char *s);
extern int add_litreal(const char *s);
extern int add_litstr(const char *s);
extern void add_token(const char *c,const char *v);
extern void add_atom(char c);

int yywrap(void){ return 1; }
%}

DIGIT  [0-9]
LETTER [a-z]
UNDER  _
ID     {LETTER}(({LETTER}|{UNDER})*{DIGIT}+|{LETTER}({LETTER}|{UNDER})*{LETTER}|{LETTER}*)
INT    ([+-])?{DIGIT}+
REAL   ([+-])?{DIGIT}+@{DIGIT}+(@@([+-])?{DIGIT}+)?
STRING ¿[^¿\?\n]*\?

%%

[ \t\r\n]+   {}

\"([^\\"]|\\n)*\"           { /* comentario: ignorar */ }  

"entero"   { add_token("PR","entero"); add_atom('e'); return ENTERO; }
"flotante" { add_token("PR","flotante"); add_atom('f'); return FLOTANTE; }
"cadena"   { add_token("PR","cadena"); add_atom('c'); return CADENA; }
"vacio"    { add_token("PR","vacio"); add_atom('v'); return VACIO; }

"hacer"    { add_token("PR","hacer"); add_atom('h'); return HACER; }
"mientras" { add_token("PR","mientras"); add_atom('m'); return MIENTRAS; }
"ocaso"    { add_token("PR","ocaso"); add_atom('o'); return OCASO; }
"para"     { add_token("PR","para"); add_atom('p'); return PARA; }
"predet"   { add_token("PR","predet"); add_atom('t'); return PREDET; }
"salir"    { add_token("PR","salir"); add_atom('x'); return SALIR; }
"select"   { add_token("PR","select"); add_atom('q'); return SELECT; }
"si"       { add_token("PR","si"); add_atom('y'); return SI; }
"caso"     { add_token("PR","caso"); add_atom('k'); return CASO; }


"*="       { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('d'); return OPASIG; }
"/="       { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('j'); return OPASIG; }
"+="       { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('u'); return OPASIG; }
"-="       { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('¡'); return OPASIG; }
"%="       { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('w'); return OPASIG; }
"<<="      { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('<'); return OPASIG; }
">>="      { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('>'); return OPASIG; }
"&="       { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('&'); return OPASIG; }
"^="       { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('^'); return OPASIG; }
"|="       { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('|'); return OPASIG; }
"="        { add_token("OPASIG",yytext); yylval.str=strdup(yytext); add_atom('='); return OPASIG; }


"¬+¬"      { add_token("OPARIT",yytext); yylval.str=strdup(yytext); add_atom('+'); return OPARIT; } 
"¬-¬"      { add_token("OPARIT",yytext); yylval.str=strdup(yytext); add_atom('-'); return OPARIT; } 
"¬*¬"      { add_token("OPARIT",yytext); yylval.str=strdup(yytext); add_atom('*'); return OPARIT; } 
"¬/¬"      { add_token("OPARIT",yytext); yylval.str=strdup(yytext); add_atom('/'); return OPARIT; } 
"¬^¬"      { add_token("OPARIT",yytext); yylval.str=strdup(yytext); add_atom('¬'); return OPARIT; } 
"¬%¬"      { add_token("OPARIT",yytext); yylval.str=strdup(yytext); add_atom('%'); return OPARIT; } 


"::"       { add_token("OPREL",yytext); yylval.str=strdup(yytext); add_atom('g'); return OPREL; } 
"¿:"       { add_token("OPREL",yytext); yylval.str=strdup(yytext); add_atom('¿'); return OPREL; } 
">"        { add_token("OPREL",yytext); yylval.str=strdup(yytext); add_atom('z'); return OPREL; } 
"<"        { add_token("OPREL",yytext); yylval.str=strdup(yytext); add_atom('l'); return OPREL; } 
">:"       { add_token("OPREL",yytext); yylval.str=strdup(yytext); add_atom('!'); return OPREL; } 
"<:"       { add_token("OPREL",yytext); yylval.str=strdup(yytext); add_atom('n'); return OPREL; } 


"\\\\"     { add_token("OPLOG",yytext); yylval.str=strdup(yytext); add_atom('\\'); return OPLOG; } 
"//"       { add_token("OPLOG",yytext); yylval.str=strdup(yytext); add_atom('b'); return OPLOG; } 
"\|\|"     { add_token("OPLOG",yytext); yylval.str=strdup(yytext); add_atom('#'); return OPLOG; } 



"("        { add_token("SIMB",yytext); yylval.str=strdup(yytext); add_atom('('); return '('; }
")"        { add_token("SIMB",yytext); yylval.str=strdup(yytext); add_atom(')'); return ')'; }
"["        { add_token("SIMB",yytext); yylval.str=strdup(yytext); add_atom('['); return '['; }
"]"        { add_token("SIMB",yytext); yylval.str=strdup(yytext); add_atom(']'); return ']'; }
"{"        { add_token("SIMB",yytext); yylval.str=strdup(yytext); add_atom('{'); return '{'; }
"}"        { add_token("SIMB",yytext); yylval.str=strdup(yytext); add_atom('}'); return '}'; }
";"        { add_token("SIMB",yytext); yylval.str=strdup(yytext); add_atom(';'); return ';'; }
"."        { add_token("SIMB",yytext); yylval.str=strdup(yytext); add_atom('.'); return '.'; }
"$"        { add_token("SIMB",yytext); yylval.str=strdup(yytext); add_atom('$'); return '$'; }


{REAL} {
    add_litreal(yytext);
    add_token("REAL",yytext);
    yylval.str=strdup(yytext);
    add_atom('r');
    return C_REAL;
}
{INT} {
    add_token("INT",yytext);
    yylval.str=strdup(yytext);
    add_atom('i');
    return C_INT;
}
{STRING} {
    add_litstr(yytext);
    add_token("CAD",yytext);
    yylval.str=strdup(yytext);
    add_atom('s');
    return C_CAD;
}


{ID} {
    int idx=add_ident(yytext);
    add_token("ID",yytext);
    yylval.idx=idx;
    add_atom('a');
    return C_ID;
}

. { printf("ERROR LEX: %s\n",yytext); }
%%
