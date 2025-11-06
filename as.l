%{
/* Analizador léxico para proyecto - Flex (.l)
   Autores: Franco Ramírez Christian , Pérez Paitán Brent Armando
   Fecha: 30 Septiembre 2025
*/

/* Bibliotecas útiles */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Contador de líneas */
int lineno = 1;

/* ------- Estructuras para tablas ------- */
typedef struct {
    int pos;
    char *name;
    int tipo; /* inicial = -1 */
} Ident;

typedef struct {
    int pos;
    char *valor;
} LitStr;

typedef struct {
    int pos;
    char *valor;
} LitReal;

/* vectores dinámicos simples */
Ident *idents = NULL; int n_idents = 0, cap_idents = 0;
LitStr *litstr = NULL; int n_litstr = 0, cap_litstr = 0;
LitReal *litreal = NULL; int n_litreal = 0, cap_litreal = 0;

/* Secuencia de tokens */
typedef struct {
    int clase;
    char valor[128]; 
    char etm[256];
} Token;
Token *tokens = NULL; int n_tokens = 0, cap_tokens = 0;

/* funciones auxiliares */
void add_token(int clase, const char *valor, const char *lex) {
    if (n_tokens == cap_tokens) {
        cap_tokens = cap_tokens ? cap_tokens*2 : 64;
        tokens = realloc(tokens, cap_tokens * sizeof(Token));
    }
    tokens[n_tokens].clase = clase;
    strncpy(tokens[n_tokens].valor, valor, sizeof(tokens[n_tokens].valor)-1);
    strncpy(tokens[n_tokens].etm, lex, sizeof(tokens[n_tokens].etm)-1);
    n_tokens++;
}

int find_ident(const char *s) {
    for (int i=0;i<n_idents;i++) if (strcmp(idents[i].name, s)==0) return idents[i].pos;
    return -1;
}

int add_ident(const char *s) {
    int f = find_ident(s);
    if (f!=-1) return f;
    if (n_idents==cap_idents) {
        cap_idents = cap_idents ? cap_idents*2 : 64;
        idents = realloc(idents, cap_idents * sizeof(Ident));
    }
    idents[n_idents].pos = n_idents;
    idents[n_idents].name = strdup(s);
    idents[n_idents].tipo = -1;
    n_idents++;
    return n_idents-1;
}

int add_litstr(const char *s) {
    if (n_litstr==cap_litstr) {
        cap_litstr = cap_litstr ? cap_litstr*2 : 64;
        litstr = realloc(litstr, cap_litstr * sizeof(LitStr));
    }
    litstr[n_litstr].pos = n_litstr;
    litstr[n_litstr].valor = strdup(s);
    n_litstr++;
    return n_litstr-1;
}

int add_litreal(const char *s) {
    if (n_litreal==cap_litreal) {
        cap_litreal = cap_litreal ? cap_litreal*2 : 64;
        litreal = realloc(litreal, cap_litreal * sizeof(LitReal));
    }
    litreal[n_litreal].pos = n_litreal;
    litreal[n_litreal].valor = strdup(s);
    n_litreal++;
    return n_litreal-1;
}

/* imprimir resultados al final */
void print_tables() {
    printf("\n==== Tabla de símbolos (identificadores) ====\n");
    printf("pos\tname\ttipo\n");
    for (int i=0;i<n_idents;i++) {
        printf("%d\t%s\t%d\n", idents[i].pos, idents[i].name, idents[i].tipo);
    }

    printf("\n==== Tabla literales (cadena) ====\n");
    printf("pos\tvalor\n");
    for (int i=0;i<n_litstr;i++) {
        printf("%d\t%s\n", litstr[i].pos, litstr[i].valor);
    }

    printf("\n==== Tabla literales (real) ====\n");
    printf("pos\tvalor\n");
    for (int i=0;i<n_litreal;i++) {
        printf("%d\t%s\n", litreal[i].pos, litreal[i].valor);
    }

    printf("\n==== Secuencia de tokens ====\n");
    printf("idx\tclase\tvalor\t\tetm\n");
    for (int i=0;i<n_tokens;i++) {
        printf("%d\t%d\t%s\t\t%s\n", i, tokens[i].clase, tokens[i].valor, tokens[i].etm);
    }
}

/* Manejo de errores recuperable */
void report_error(const char *msg, const char *etm) {
    fprintf(stderr, "Error en línea %d: %s -> '%s'\n", lineno, msg, etm);
    FILE *f = fopen("errores.txt", "a");
    if(f) {
        fprintf(f, "Error en línea %d: %s -> '%s'\n", lineno, msg, etm);
        fclose(f);
    }
}

/* manejar fin de archivo */
int yywrap() {
    print_tables();
    return 1;
}

%}

/* ---------- Definiciones léxicas ---------- */
/* caracteres básicos */
DIG     [0-9]
LETM    [a-z]
UND     _
SPC     [ \t\r\n]

/* Palabras reservadas (catalogadas con sus valores en la gramática) */
PALRES  cadena|caso|entero|flotante|hacer|mientras|ocaso|para|predet|salir|select|si|vacio

/* Constantes enteras con signo opcional */
CTEINT  ([+-])?{DIG}+

/* Identificadores:
   - empiezan con minúscula {LET}
   - pueden incluir '_' y letras minúsculas en el medio
   - dígitos sólo permitidos al final (cero o más dígitos)
   Ejemplos válidos: var, mi_var, abc_efg2, x_1
*/
IDENT  {LETM}(({LETM}|{UND})*{DIG}+|{LETM}({LETM}|{UND})*{LETM}|{LETM}*)

 /* Operadores de asignación (lista del catálogo) */
OPASIG  "<<" "=" | ">>" "=" | "*=" | "/=" | "+=" | "-=" | "%=" | "&=" | "^=" | "|=" | "="
/* Nota: se aceptan <<= y >>= como '<<=' y '>>=' */

/* Símbolos especiales */
SIMSPE  [$%()\{\}\[\];\.]

/* Operadores lógicos */
OPLOG "\\" | "//" | "||"

/* Constantes reales: parte entera@decimal (opcional)@@exponente
   Notación EXACTA según enunciado:
   ej: 15@85   0@61@@-17
*/
CTEREAL ([+-])?{DIG}+@{DIG}+(@@([+-])?{DIG}+)? 

/* Constantes cadena: inician con ¿ y terminan con ? sin saltos */
CTESTR  ¿[^¿\?\n]*\?

/* Operadores aritméticos según catálogo: ¬+¬ , ¬-¬, etc.
   Los ponemos entre comillas para capturarlos literalmente.
*/
OPART   "¬+¬"|"¬-¬"|"¬*¬"|"¬/¬"|"¬^¬"|"¬%¬"

/* Operadores relacionales */
OPREL   "::"|"¿:"|">:"|"<:"|">"|"<"

%%  

{SPC}       { if(yytext[0]=='\n') lineno++; }   /* Ignorar espacios y contar líneas */

\"([^\\"]|\\n)*\"      { /* comentario: ignorar */ }   /* Comentarios entre comillas dobles " " */

{PALRES}    {   /* Palabras reservadas */
                int val = -1;
                if (strcmp(yytext,"cadena")==0) val=0;
                else if (strcmp(yytext,"caso")==0) val=1;
                else if (strcmp(yytext,"entero")==0) val=2;
                else if (strcmp(yytext,"flotante")==0) val=3;
                else if (strcmp(yytext,"hacer")==0) val=4;
                else if (strcmp(yytext,"mientras")==0) val=5;
                else if (strcmp(yytext,"ocaso")==0) val=6;
                else if (strcmp(yytext,"para")==0) val=7;
                else if (strcmp(yytext,"predet")==0) val=8;
                else if (strcmp(yytext,"salir")==0) val=9;
                else if (strcmp(yytext,"select")==0) val=10;
                else if (strcmp(yytext,"si")==0) val=11;
                else if (strcmp(yytext,"vacio")==0) val=12;
                char buf[32]; snprintf(buf,sizeof(buf),"%d",val);
                add_token(0, buf, yytext);
            }


{CTEINT}    {   /* Constantes enteras */
                add_token(1, yytext, yytext); /* valor: número mismo */
            }


{IDENT}     {   /* Identificadores */
                int pos = add_ident(yytext);
                char buf[32]; snprintf(buf,sizeof(buf),"%d", pos);
                add_token(2, buf, yytext);
            }


"<<="      { add_token(3, "6", yytext); }   /* Operadores de asignación */
">>="      { add_token(3, "7", yytext); }
"*="       { add_token(3, "1", yytext); }
"/="       { add_token(3, "2", yytext); }
"+="       { add_token(3, "3", yytext); }
"-="       { add_token(3, "4", yytext); }
"%="       { add_token(3, "5", yytext); }
"&="       { add_token(3, "8", yytext); }
"^="       { add_token(3, "9", yytext); }
"|="       { add_token(3, "10", yytext); }
"="        { add_token(3, "0", yytext); }


{SIMSPE}   {    /* Símbolos especiales */
                add_token(4, yytext, yytext);
            }


"\\\\"     { add_token(5, "0", yytext); } /* Operadores lógicos AND OR NOT*/
"//"       { add_token(5, "1", yytext); } 
"||"       { add_token(5, "2", yytext); } 


{CTEREAL}  {    /* Constantes reales */
                int pos = add_litreal(yytext);
                char buf[32]; snprintf(buf,sizeof(buf),"%d", pos);
                add_token(6, buf, yytext);
           }


{CTESTR}   {    /* Constantes cadena */
                /* eliminar el delimitador inicial ¿ y final ? para almacenar */
                int L = strlen(yytext);
                char inner[512];
                if (L>=2) {
                    strncpy(inner, yytext+1, L-2);
                    inner[L-2]=0;
                } else inner[0]=0;
                int pos = add_litstr(inner);
                char buf[32]; snprintf(buf,sizeof(buf),"%d", pos);
                add_token(7, buf, yytext);
           }


"¬+¬"      { add_token(8, "0", yytext); }   /* Operadores aritméticos */
"¬-¬"      { add_token(8, "1", yytext); }
"¬*¬"      { add_token(8, "2", yytext); }
"¬/¬"      { add_token(8, "3", yytext); }
"¬^¬"      { add_token(8, "4", yytext); }
"¬%¬"      { add_token(8, "5", yytext); }


"::"       { add_token(9, "0", yytext); }   /* Operadores relacionales */
"¿:"       { add_token(9, "1", yytext); }
">:"       { add_token(9, "4", yytext); } /* mayor o igual */
"<:"       { add_token(9, "5", yytext); } /* menor o igual */
">"        { add_token(9, "2", yytext); }
"<"        { add_token(9, "3", yytext); }

.          { report_error("Símbolo no reconocido", yytext); }   /* Símbolos o caracteres no reconocidos */

%%

/* ----------------- PARSER INTEGRADO (descendente recursivo) ----------------- */

/* atoms[]: un átomo por token; usamos char para representar cada átomo.
   atoms[i] corresponde a tokens[i].
   Algunos átomos son caracteres no-ASCII como '¬' o '¡' — guardar el literal.
*/
char *atoms = NULL;
int n_atoms = 0;

/* posición actual en atoms para el parser */
int pos_at = 0;

/* almacenar errores sintácticos */
int n_synt_errors = 0;

/* Helper: obtener átomo actual (si se terminó devuelve '$' como EOF) */
char peek_atom() {
    if (pos_at >= n_atoms) return '$';
    return atoms[pos_at];
}

/* Helper: actualizar posición (consumir átomo esperado) */
void advance_atom() {
    if (pos_at < n_atoms) pos_at++;
}

/* reportar error sintáctico y avanzar 1 átomo para intentar recuperación */
void syn_error(const char *expected) {
    n_synt_errors++;
    int idx = pos_at;
    char found = peek_atom();
    const char *lex = (idx < n_tokens) ? tokens[idx].etm : "<EOF>";
    fprintf(stderr, "Error sintáctico: átomo idx=%d (lexema=\"%s\"): se esperaba %s, se encontró '%c' \n",
            idx, lex, expected, (found=='$' ? '\\' : found));
    /* intentar recuperar moviendo 1 átomo */
    advance_atom();
}

/* mapeo tokens[] -> atoms[] (usar valores según tu flex y correcciones) */
void build_atoms() {
    if (n_tokens == 0) {
        atoms = NULL; n_atoms = 0; return;
    }
    atoms = malloc(n_tokens + 2); /* suficiente */
    n_atoms = n_tokens;
    for (int i=0;i<n_tokens;i++) {
        Token *t = &tokens[i];
        char a = '?';
        switch (t->clase) {
            case 0: { /* palabras reservadas; t->valor contains "0".. "12" */
                int v = atoi(t->valor);
                switch (v) {
                    case 0: a = 'c'; break; /* cadena */
                    case 1: a = 'k'; break; /* caso */
                    case 2: a = 'e'; break; /* entero */
                    case 3: a = 'f'; break; /* flotante */
                    case 4: a = 'h'; break; /* hacer */
                    case 5: a = 'm'; break; /* mientras */
                    case 6: a = 'o'; break; /* ocaso */
                    case 7: a = 'p'; break; /* para */
                    case 8: a = 't'; break; /* predet */
                    case 9: a = 'x'; break; /* salir */
                    case 10: a = 'q'; break; /* select */
                    case 11: a = 'y'; break; /* si */
                    case 12: a = 'v'; break; /* vacio */
                    default: a = '?'; break;
                }
                break;
            }
            case 1: a = 'i'; break; /* const int */
            case 2: a = 'a'; break; /* identificador */
            case 3: { /* opAsig: t->valor has "0".."10" */
                int v = atoi(t->valor);
                switch (v) {
                    case 0: a = '='; break;
                    case 1: a = 'd'; break; /* *= */
                    case 2: a = 'j'; break; /* /= */
                    case 3: a = 'u'; break; /* += */
                    case 4: a = '¡'; break; /* -=  (según corrección) */
                    case 5: a = 'w'; break; /* %= */
                    case 6: a = '<'; break; /* <<=  mapped to '<' */
                    case 7: a = '>'; break; /* >>=  mapped to '>' */
                    case 8: a = '&'; break;
                    case 9: a = '^'; break;
                    case 10: a = '|'; break; /* |= maps to '|' */
                    default: a = '?'; break;
                }
                break;
            }
            case 4: { /* símbolos especiales: valor almacena el símbolo mismo */
                /* valor puede ser "(", ")", "{", "}", "[", "]", ";", ".", "$", "%" etc. */
                a = t->valor[0];
                break;
            }
            case 5: { /* operadores lógicos: t->valor "0","1","2" */
                int v = atoi(t->valor);
                switch (v) {
                    case 0: a = '\\'; break; /* "\\"  -> backslash atom */
                    case 1: a = 'b'; break;  /* "//"   -> 'b' */
                    case 2: a = '#'; break;  /* "||"   -> '#' per acuerdo */
                    default: a = '?'; break;
                }
                break;
            }
            case 6: a = 'r'; break; /* real literal */
            case 7: a = 's'; break; /* string literal */
            case 8: { /* op aritmético: t->valor "0".."5" */
                int v = atoi(t->valor);
                switch (v) {
                    case 0: a = '+'; break; /* "¬+¬" */
                    case 1: a = '-'; break; /* "¬-¬" */
                    case 2: a = '*'; break; /* "¬*¬" */
                    case 3: a = '/'; break; /* "¬/¬" */
                    case 4: a = '¬'; break; /* "¬^¬" -> atom '¬' (alt-170) */
                    case 5: a = '%'; break; /* "¬%¬" */
                    default: a = '?'; break;
                }
                break;
            }
            case 9: { /* operadores relacionales */
                int v = atoi(t->valor);
                switch (v) {
                    case 0: a = 'g'; break; /* "::" -> g */
                    case 1: a = '¿'; break; /* "¿:" -> ¿ */
                    case 2: a = 'z'; break; /* ">" -> z */
                    case 3: a = 'l'; break; /* "<" -> l */
                    case 4: a = '!'; break; /* ">:" -> !  (mayor o igual) */
                    case 5: a = 'n'; break; /* "<:" -> n  (menor o igual) */
                    default: a = '?'; break;
                }
                break;
            }
            default:
                a = '?';
        }
        atoms[i] = a;
    }
    atoms[n_tokens] = '\0';
}

/* ------------------ Prototipos de todas las funciones del parser -------------- */
/* He implementado una función por no-terminal principal. Cada una elige la alternativa
   usando los SELECT que calculamos. Si ocurre un error sintáctico se reporta y se avanza. */

void Program(); void otraFunc(); void Func(); void listArg(); void otroArg();
void cuerpo(); void listaDec(); void sent_decl(); void tipo_fn();
void lista_id(); void resto_lista_id(); void asig_val(); void constante_fn();
void E(); void Eprime(); void T(); void Tprime(); void F(); void LlamaFunc();
void asig(); void opAsig_fn(); void expRel(); void opRel_fn(); void exprLog();
void exprV(); void opLog_fn(); void Sent_fn(); void props_fn(); void hacerM();
void condicion_fn(); void si_fn(); void finalsi(); void ocaso_fn(); void para_fn();
void expr_fn(); void salir_fn(); void valRet_fn(); void select_fn(); void siguiente_fn();
void listP_fn(); void Param_fn();

/* ------------------ Implementación de las funciones del parser --------------- */

void Program() {
    /* SELECT(Program->Func otraFunc) = {c,e,f,v} */
    char p = peek_atom();
    if (p=='c' || p=='e' || p=='f' || p=='v') {
        Func();
        otraFunc();
    } else {
        syn_error("{c,e,f,v}");
    }
}

void otraFunc() {
    /* otraFunc -> Func otraFunc | ξ
       SELECT(Func otraFunc) = {c,e,f,v}, SELECT(ξ) = {$}
    */
    char p = peek_atom();
    if (p=='c' || p=='e' || p=='f' || p=='v') {
        Func();
        otraFunc();
    } else if (p=='$' || p=='}' || p==']' || p==0) {
        /* epsilon in contexts: accept */
        return;
    } else {
        /* epsilon alternative may be selected if FOLLOW includes $, ']' etc.
           If we are not in a place that expects Func, allow epsilon */
        return;
    }
}

void Func() {
    /* Func -> tipo a ( listArg ) [ cuerpo ] */
    char p = peek_atom();
    if (p=='c' || p=='e' || p=='f' || p=='v') {
        tipo_fn();
        if (peek_atom()=='a') advance_atom(); else syn_error("'a' (identifier)");
        if (peek_atom()=='(') advance_atom(); else syn_error("'('");
        listArg();
        if (peek_atom()==')') advance_atom(); else syn_error("')'");
        if (peek_atom()=='[') advance_atom(); else syn_error("'['");
        cuerpo();
        if (peek_atom()==']') advance_atom(); else syn_error("']'");
    } else {
        syn_error("{c,e,f,v}");
    }
}

void listArg() {
    /* listArg -> tipo a otroArg | ξ    SELECT={c,e,f,v} / {')'} */
    char p = peek_atom();
    if (p=='c' || p=='e' || p=='f' || p=='v') {
        tipo_fn();
        if (peek_atom()=='a') advance_atom(); else syn_error("'a' in listArg");
        otroArg();
    } else if (p==')') {
        /* epsilon */
        return;
    } else {
        syn_error("{c,e,f,v,')'}");
    }
}

void otroArg() {
    /* otroArg -> ; tipo a otroArg | ξ    SELECT={';'} / {')'} */
    char p = peek_atom();
    if (p==';') {
        advance_atom();
        tipo_fn();
        if (peek_atom()=='a') advance_atom(); else syn_error("'a' in otroArg");
        otroArg();
    } else if (p==')') {
        return;
    } else {
        syn_error("';' or ')'");
    }
}

void cuerpo() {
    /* cuerpo -> listaDec props */
    listaDec();
    props_fn();
}

void listaDec() {
    /* listaDec -> ξ | sent-decl listaDec   SELECT={c,e,f,v} / {']',...} */
    char p = peek_atom();
    if (p=='c' || p=='e' || p=='f' || p=='v') {
        sent_decl();
        listaDec();
    } else if (p==']' || p=='a' || p=='h' || p=='p' || p=='q' || p=='x' || p=='y') {
        /* epsilon */
        return;
    } else {
        /* allow epsilon in other contexts */
        return;
    }
}

void sent_decl() {
    /* sent-decl -> tipo lista-id . */
    if (peek_atom()=='c' || peek_atom()=='e' || peek_atom()=='f' || peek_atom()=='v') {
        tipo_fn();
        lista_id();
        if (peek_atom()=='.') advance_atom(); else syn_error("'.' after declaration");
    } else {
        syn_error("{c,e,f,v}");
    }
}

void tipo_fn() {
    /* tipo -> e|f|c|v */
    char p = peek_atom();
    if (p=='e' || p=='f' || p=='c' || p=='v') {
        advance_atom();
    } else {
        syn_error("tipo (e/f/c/v)");
    }
}

void lista_id() {
    /* lista-id -> a asig-val resto-lista-id */
    if (peek_atom()=='a') {
        advance_atom();
        asig_val();
        resto_lista_id();
    } else {
        syn_error("identifier 'a' in lista-id");
    }
}

void resto_lista_id() {
    /* resto-lista-id -> ; lista-id | ξ */
    char p = peek_atom();
    if (p==';') {
        advance_atom();
        lista_id();
    } else if (p=='.') {
        return;
    } else {
        /* epsilon acceptable */
        return;
    }
}

void asig_val() {
    /* asig-val -> = constante | ξ */
    char p = peek_atom();
    if (p=='=') {
        advance_atom();
        constante_fn();
    } else {
        /* epsilon */
        return;
    }
}

void constante_fn() {
    /* constante -> i | r | s */
    char p = peek_atom();
    if (p=='i' || p=='r' || p=='s') advance_atom();
    else syn_error("constante (i,r,s)");
}

/* ---------------- EXPRESIONES ---------------- */

void E() {
    /* E -> T E' */
    char p = peek_atom();
    if (p=='$' || p=='(' || p=='a' || p=='i' || p=='r' || p=='s') {
        T();
        Eprime();
    } else {
        syn_error("inicio de expresion (E)");
    }
}

void Eprime() {
    /* E' -> + T E' | - T E' | ξ */
    char p = peek_atom();
    if (p=='+') {
        advance_atom();
        T();
        Eprime();
    } else if (p=='-') {
        advance_atom();
        T();
        Eprime();
    } else {
        /* epsilon */
        return;
    }
}

void T() {
    /* T -> F T' */
    char p = peek_atom();
    if (p=='$' || p=='(' || p=='a' || p=='i' || p=='r' || p=='s') {
        F();
        Tprime();
    } else {
        syn_error("inicio de termino (T)");
    }
}

void Tprime() {
    /* T' -> * F T' | / F T' | % F T' | ¬ F T' | ξ */
    char p = peek_atom();
    if (p=='*') {
        advance_atom(); F(); Tprime();
    } else if (p=='/') {
        advance_atom(); F(); Tprime();
    } else if (p=='%') {
        advance_atom(); F(); Tprime();
    } else if (p=='¬') {
        advance_atom(); F(); Tprime();
    } else {
        /* epsilon */
        return;
    }
}

void F() {
    /* F -> ( E ) | a | i | r | s | LlamaFunc */
    char p = peek_atom();
    if (p=='(') {
        advance_atom(); E();
        if (peek_atom()==')') advance_atom(); else syn_error("')' after (E");
    } else if (p=='a') {
        advance_atom();
    } else if (p=='i' || p=='r' || p=='s') {
        advance_atom();
    } else if (p=='$') {
        LlamaFunc();
    } else {
        syn_error("factor F");
    }
}

void LlamaFunc() {
    /* LlamaFunc -> $ a ( listP ) */
    if (peek_atom()=='$') {
        advance_atom();
        if (peek_atom()=='a') advance_atom(); else syn_error("'a' after $ in call");
        if (peek_atom()=='(') advance_atom(); else syn_error("'(' in call");
        listP_fn();
        if (peek_atom()==')') advance_atom(); else syn_error("')' end call");
    } else {
        syn_error("'$' for function call");
    }
}

/* ---------------- ASIGNACIONES y operadores ---------------- */

void asig() {
    /* asig -> a opAsig E . */
    if (peek_atom()=='a') {
        advance_atom();
        opAsig_fn();
        E();
        if (peek_atom()=='.') advance_atom(); else syn_error("'.' at end of assignment");
    } else {
        syn_error("assignment starts with 'a'");
    }
}

void opAsig_fn() {
    /* opAsig -> one of: =, d, j, u, ¡, w, <, >, &, ^, | */
    char p = peek_atom();
    if (p=='='||p=='d'||p=='j'||p=='u'||p=='¡'||p=='w'||p=='<'||p=='>'||p=='&'||p=='^'||p=='|') {
        advance_atom();
    } else {
        syn_error("operator assignment (=, d, j, u, ¡, w, <, >, &, ^, |)");
    }
}

/* ---------------- RELACIONALES / LOGICOS ---------------- */

void expRel() {
    /* expRel -> [ E opRel E ] */
    if (peek_atom()=='[') {
        advance_atom();
        E();
        opRel_fn();
        E();
        if (peek_atom()==']') advance_atom(); else syn_error("']' in expRel");
    } else {
        syn_error("'[' start expRel");
    }
}

void opRel_fn() {
    /* opRel -> g | ¿ | z | l | ! | n */
    char p = peek_atom();
    if (p=='g' || p=='¿' || p=='z' || p=='l' || p=='!' || p=='n') advance_atom();
    else syn_error("opRel (g,¿,z,l,!,n)");
}

void exprLog() {
    /* exprLog -> # { exprV } | { expRel opLog expRel } */
    char p = peek_atom();
    if (p=='#') {
        advance_atom();
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' after #");
        exprV();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' after exprV");
    } else if (p=='{') {
        advance_atom();
        expRel();
        opLog_fn();
        expRel();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' end exprLog");
    } else {
        syn_error("exprLog (# or {)");
    }
}

void exprV() {
    /* exprV -> E | expRel */
    char p = peek_atom();
    if (p=='$' || p=='(' || p=='a' || p=='i' || p=='r' || p=='s') {
        E();
    } else if (p=='[') {
        expRel();
    } else {
        syn_error("exprV (E or expRel)");
    }
}

void opLog_fn() {
    /* opLog -> \ | b */
    char p = peek_atom();
    if (p=='\\' || p=='b') advance_atom();
    else syn_error("opLog (\\ or b)");
}

/* ---------------- SENTENCIAS / BLOQUES ---------------- */

void Sent_fn() {
    /* Sent -> asig | hacerM | si | para | salir | select */
    char p = peek_atom();
    if (p=='a') { asig(); }
    else if (p=='h') { hacerM(); }
    else if (p=='y') { si_fn(); }
    else if (p=='p') { para_fn(); }
    else if (p=='x') { salir_fn(); }
    else if (p=='q') { select_fn(); }
    else { syn_error("start of Sent (a/h/y/p/x/q)"); }
}

void props_fn() {
    /* props -> Sent props | ξ */
    char p = peek_atom();
    if (p=='a' || p=='h' || p=='y' || p=='p' || p=='x' || p=='q') {
        Sent_fn();
        props_fn();
    } else {
        /* epsilon */
        return;
    }
}

void hacerM() {
    /* hacerM -> h { props } m condicion . */
    if (peek_atom()=='h') {
        advance_atom();
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' after h");
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' in hacerM");
        if (peek_atom()=='m') advance_atom(); else syn_error("'m' after block");
        condicion_fn();
        if (peek_atom()=='.') advance_atom(); else syn_error("'.' after hacerM");
    } else syn_error("hacerM starts with 'h'");
}

void condicion_fn() {
    /* condicion -> expRel | exprLog */
    char p = peek_atom();
    if (p=='[') expRel();
    else if (p=='#' || p=='{') exprLog();
    else syn_error("condicion ([ or # or {)");
}

void si_fn() {
    /* si -> y condicion { props } finalsi */
    if (peek_atom()=='y') {
        advance_atom();
        condicion_fn();
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' after condicion in si");
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' end si block");
        finalsi();
    } else syn_error("si starts with 'y'");
}

void finalsi() {
    /* finalsi -> ξ | o ocaso */
    char p = peek_atom();
    if (p=='o') {
        advance_atom();
        ocaso_fn();
    } else {
        /* epsilon */
        return;
    }
}

void ocaso_fn() {
    /* ocaso -> si | { props } */
    char p = peek_atom();
    if (p=='y') si_fn();
    else if (p=='{') {
        advance_atom();
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' in ocaso");
    } else syn_error("ocaso (y or {)");
}

void para_fn() {
    /* para -> p ( expr ; condicion ; expr ) { props } */
    if (peek_atom()=='p') {
        advance_atom();
        if (peek_atom()=='(') advance_atom(); else syn_error("'(' after p");
        expr_fn();
        if (peek_atom()==';') advance_atom(); else syn_error("';' after expr in para");
        condicion_fn();
        if (peek_atom()==';') advance_atom(); else syn_error("';' after condicion in para");
        expr_fn();
        if (peek_atom()==')') advance_atom(); else syn_error("')' in para");
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' start para block");
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' end para block");
    } else syn_error("para starts with 'p'");
}

void expr_fn() {
    /* expr -> a opAsig E  (note: used in para's expr grammar and asig) */
    if (peek_atom()=='a') {
        advance_atom();
        opAsig_fn();
        E();
    } else syn_error("expr starts with 'a'");
}

void salir_fn() {
    /* salir -> x valRet . */
    if (peek_atom()=='x') {
        advance_atom();
        valRet_fn();
        if (peek_atom()=='.') advance_atom(); else syn_error("'.' after salir");
    } else syn_error("salir starts with 'x'");
}

void valRet_fn() {
    /* valRet -> E | ξ */
    char p = peek_atom();
    if (p=='$' || p=='(' || p=='a' || p=='i' || p=='r' || p=='s') E();
    else {
        /* epsilon */
        return;
    }
}

void select_fn() {
    /* select -> q ( a ) { k i { props } siguiente */
    if (peek_atom()=='q') {
        advance_atom();
        if (peek_atom()=='(') advance_atom(); else syn_error("'(' in select");
        if (peek_atom()=='a') advance_atom(); else syn_error("'a' in select paren");
        if (peek_atom()==')') advance_atom(); else syn_error("')' in select");
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' start select");
        /* expect: k i { props } siguiente  ... according to grammar */
        if (peek_atom()=='k') {
            advance_atom();
            if (peek_atom()=='i') advance_atom(); else syn_error("'i' after k in select");
            if (peek_atom()=='{') advance_atom(); else syn_error("'{' in select case");
            props_fn();
            if (peek_atom()=='}') advance_atom(); else syn_error("'}' end case");
            siguiente_fn();
        } else {
            syn_error("'k' expected in select");
        }
    } else syn_error("select starts with 'q'");
}

void siguiente_fn() {
    /* siguiente -> k i { props } siguiente
                   | }
                   | t { props } } */
    char p = peek_atom();
    if (p=='k') {
        advance_atom();
        if (peek_atom()=='i') advance_atom(); else syn_error("'i' after k in siguiente");
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' in siguiente block");
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' end siguiente case");
        siguiente_fn();
    } else if (p=='}') {
        advance_atom(); /* end of switch block */
        return;
    } else if (p=='t') {
        advance_atom();
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' after t in siguiente");
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' after t case");
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' closing select");
        return;
    } else {
        syn_error("siguiente (k, } or t)");
    }
}

void listP_fn() {
    /* listP -> ξ | E Param */
    char p = peek_atom();
    if (p==')') {
        /* epsilon */
        return;
    } else if (p=='$' || p=='(' || p=='a' || p=='i' || p=='r' || p=='s') {
        E();
        Param_fn();
    } else {
        syn_error("listP (param list)");
    }
}

void Param_fn() {
    /* Param -> ; E Param | ξ */
    char p = peek_atom();
    if (p==';') {
        advance_atom();
        E();
        Param_fn();
    } else if (p==')') {
        return;
    } else {
        /* epsilon acceptable */
        return;
    }
}

/* -------------------- MAIN integrador -------------------- */

int main(int argc, char **argv) {
    /* limpiar errores previos */
    FILE *g = fopen("errores.txt", "w");
    if (g) fclose(g);

    if (argc < 2) { fprintf(stderr, "Uso: %s <archivo_fuente>\n", argv[0]); return 1; }
    FILE *f = fopen(argv[1],"r");
    if (!f) { perror("fopen"); return 1; }
    yyin = f;

    /* ejecutar lexer para poblar tokens[] y las tablas */
    yylex();

    /* construir atoms[] usando tokens[] */
    build_atoms();

    /* mostrar cadena de átomos (útil para debug) */
    printf("\n==== Cadena de átomos ====\n");
    for (int i=0;i<n_atoms;i++) {
        char c = atoms[i];
        /* imprimir índice, átomo y lexema original para trazabilidad */
        printf("%3d: '%c'   lexema=\"%s\"\n", i, c, tokens[i].etm);
    }
    if (n_atoms==0) printf("(vacía)\n");

    /* ejecutar parser sobre atoms[] */
    pos_at = 0;
    n_synt_errors = 0;
    Program();

    /* Si quedaron átomos no consumidos y no eran EOF, reportarlos */
    if (pos_at < n_atoms) {
        fprintf(stderr, "Advertencia: quedaron %d atomos sin consumir (pos=%d, n_atoms=%d)\n",
                n_atoms - pos_at, pos_at, n_atoms);
        /* intentar reportarlos */
        while (pos_at < n_atoms) {
            int idx = pos_at;
            fprintf(stderr, "Residual átomo idx=%d lexema=\"%s\" átomo='%c'\n",
                    idx, tokens[idx].etm, atoms[idx]);
            pos_at++;
        }
    }

    /* resultado global */
    if (n_synt_errors == 0) {
        printf("\nPrograma sintácticamente correcto.\n");
    } else {
        printf("\nPrograma con %d errores sintácticos.\n", n_synt_errors);
    }

    fclose(f);
    return 0;
}
