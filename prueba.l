%{
/*
  Analizador Léxico + Sintáctico Descendente Recursivo
  Proyecto: Analizador Sintáctico
  Autores: Franco Ramirez Christian, Pérez Paitán Brent Armando
  Fecha : 2025-11-08

  Descripción:
  - Analizador léxico en Flex que genera tokens y tablas (identificadores,
    literales enteras, reales y cadenas).
  - Genera la cadena de átomos (atoms[]) que alimenta el parser recursivo.
  - Contiene un parser descendente recursivo que informa errores sintácticos
    indicando el átomo/token donde aparecieron.
  - Resultado final: impresión de tablas, tokens, cadena de átomos y si el
    programa fuente es sintácticamente correcto.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* ---------- Definición de estructuras de tokens/tablas ---------- */
#define MAX_TOKENS 10000
#define MAX_IDENTS 1000
#define MAX_LITSTR 1000
#define MAX_LITREAL 1000

typedef struct {
    int clase;      /* clase léxica */
    char *valor;    /* valor semántico (índice en tabla o literal) */
    char *etm;      /* lexema original */
} Token;

Token tokens[MAX_TOKENS];
int n_tokens = 0;

/* Tablas */
char *idents[MAX_IDENTS];
int n_idents = 0;

char *litstr[MAX_LITSTR];
int n_litstr = 0;

char *litreal[MAX_LITREAL];
int n_litreal = 0;

char *litint_arr[MAX_LITREAL];
int n_litint = 0;

/* Clases léxicas */
enum {
    C_PALRES=0,  /* palabra reservada -> valor será número de clave (string) */
    C_INT=1,
    C_ID=2,
    C_OPASIG=3,
    C_SIMB=4,
    C_OPLOG=5,
    C_REAL=6,
    C_CAD=7,
    C_OPARIT=8,
    C_OPREL=9,
};

/* función auxiliar para clonar strings */
char *strdup_safe(const char *s) {
    if (!s) return NULL;
    char *r = malloc(strlen(s)+1);
    strcpy(r,s);
    return r;
}

/* Añadir identificador a tabla y devolver índice */
char *add_ident(const char *s) {
    for (int i=0;i<n_idents;i++) if (strcmp(idents[i], s)==0) {
        char tmp[32]; sprintf(tmp, "%d", i); return strdup_safe(tmp);
    }
    if (n_idents >= MAX_IDENTS) { fprintf(stderr,"Demasiados identificadores\n"); exit(1); }
    idents[n_idents] = strdup_safe(s);
    char tmp[32]; sprintf(tmp, "%d", n_idents);
    n_idents++;
    return strdup_safe(tmp);
}

/* Añadir literal cadena */
char *add_litstr(const char *s) {
    for (int i=0;i<n_litstr;i++) if (strcmp(litstr[i], s)==0) {
        char tmp[32]; sprintf(tmp, "%d", i); return strdup_safe(tmp);
    }
    if (n_litstr >= MAX_LITSTR) { fprintf(stderr,"Demasiados literales cadena\n"); exit(1); }
    litstr[n_litstr] = strdup_safe(s);
    char tmp[32]; sprintf(tmp, "%d", n_litstr);
    n_litstr++;
    return strdup_safe(tmp);
}

/* Añadir literal real */
char *add_litreal(const char *s) {
    for (int i=0;i<n_litreal;i++) if (strcmp(litreal[i], s)==0) {
        char tmp[32]; sprintf(tmp, "%d", i); return strdup_safe(tmp);
    }
    if (n_litreal >= MAX_LITREAL) { fprintf(stderr,"Demasiados literales reales\n"); exit(1); }
    litreal[n_litreal] = strdup_safe(s);
    char tmp[32]; sprintf(tmp, "%d", n_litreal);
    n_litreal++;
    return strdup_safe(tmp);
}

/* Añadir literal entero */
char *add_litint(const char *s) {
    for (int i=0;i<n_litint;i++) if (strcmp(litint_arr[i], s)==0) {
        char tmp[32]; sprintf(tmp, "%d", i); return strdup_safe(tmp);
    }
    if (n_litint >= MAX_LITREAL) { fprintf(stderr,"Demasiados literales enteros\n"); exit(1); }
    litint_arr[n_litint] = strdup_safe(s);
    char tmp[32]; sprintf(tmp, "%d", n_litint);
    n_litint++;
    return strdup_safe(tmp);
}

/* Añadir token genérico */
void add_token_int(int clase, const char *valor, const char *lex) {
    if (n_tokens >= MAX_TOKENS) { fprintf(stderr,"Demasiados tokens\n"); exit(1); }
    tokens[n_tokens].clase = clase;
    tokens[n_tokens].valor = valor? strdup_safe(valor) : strdup_safe("");
    tokens[n_tokens].etm = lex? strdup_safe(lex) : strdup_safe("");
    n_tokens++;
}

/* Tablas/Impresión de tokens */
void print_tables() {
    printf("\n=== TOKENS (%d) ===\n", n_tokens);
    for (int i=0;i<n_tokens;i++) {
        printf("%4d) clase=%d  valor='%s'  lex='%s'\n", i, tokens[i].clase, tokens[i].valor, tokens[i].etm);
    }
    printf("\n=== IDENTIFICADORES (%d) ===\n", n_idents);
    for (int i=0;i<n_idents;i++) printf("%4d) %s\n", i, idents[i]);
    printf("\n=== LITERALES CADENA (%d) ===\n", n_litstr);
    for (int i=0;i<n_litstr;i++) printf("%4d) \"%s\"\n", i, litstr[i]);
    printf("\n=== LITERALES REALES (%d) ===\n", n_litreal);
    for (int i=0;i<n_litreal;i++) printf("%4d) %s\n", i, litreal[i]);
    printf("\n=== LITERALES ENTEROS (%d) ===\n", n_litint);
    for (int i=0;i<n_litint;i++) printf("%4d) %s\n", i, litint_arr[i]);
}

/* ---------- CADENA DE ÁTOMOS (se creará después del lex) ---------- */
char *atoms = NULL;   /* atoms[i] es char átomo */
int atom_count = 0;

/* convertidor token -> átomo char:
   Ajusta los caracteres de átomo para que coincidan con el enunciado.
   He usado letras legibles: e=entero, f=real/float, c=cadena, v=vacio,
   y=si, h=hacer, m=mientras, p=para, q=select, k=caso, t=predet, x=salir, o=ocaso.
   opasig: '=' y letras especiales: d (+=), j (-=), u (*=), w (/=), etc.
   operadores relacionales: g (:: igual), D (!=) etc.
*/
char token_to_atom(int clase, const char *valor, const char *lex) {
    if (clase == C_PALRES) {
        int code = atoi(valor);
        switch(code) {
            case 0: return 'c'; /* cadena */
            case 1: return 'k'; /* caso */
            case 2: return 'e'; /* entero */
            case 3: return 'f'; /* flotante/real */
            case 4: return 'h'; /* hacer */
            case 5: return 'm'; /* mientras */
            case 6: return 'o'; /* ocaso */
            case 7: return 'p'; /* para */
            case 8: return 't'; /* predet */
            case 9: return 'x'; /* salir */
            case 10: return 'q';/* select */
            case 11: return 'y';/* si */
            case 12: return 'v';/* vacio */
            default: return '?';                                                                    /* Revisar si se puede hacer eso */
        }
    } else if (clase == C_INT) return 'i';
    else if (clase == C_ID) return 'a';
    else if (clase == C_REAL) return 'r';
    else if (clase == C_CAD) return 's';
    else if (clase == C_SIMB) {
        /* símbolos: operadores y punción */
        return lex[0];                                                                              /* revisar que es lex[0] */
    } else if (clase == C_OPARIT) {
        int code = atoi(valor);
        switch(code) {
            case 0: return '+'; case 1: return '-'; case 2: return '*';
            case 3: return '/'; case 4: return '¬'; case 5: return '%';                             /*Ojo en el caso 4 --> CORREGIDO*/
            default: return '?';
        }
    } else if (clase == C_OPASIG) {
        int code = atoi(valor);
        /* mapear códigos de op asignación que usamos abajo en el lexer */
        switch(code) {
            case 0: return '=';   /* asignación simple */                                           /*Revisar las letras mayúsculas --> CORREGIDO*/
            case 1: return 'u';   /* += */
            case 2: return '¡';   /* -= */
            case 3: return 'd';   /* *= */
            case 4: return 'j';   /* /= */
            case 5: return 'w';   /* %= */
            case 6: return '<';   /* <<= */
            case 7: return '>';   /* >>= */
            case 8: return '&';   /* &= */
            case 9: return '^';   /* ^= */
            case 10: return '|';  /* |= */
            default: return '?';                                                                    /* revisar si es posible */
        }
    } else if (clase == C_OPREL) {
        int code = atoi(valor);
        /* códigos: 0::,1¿=,2> ,3<,4>:,5<: */
        switch(code) {
            case 0: return 'g'; case 1: return '¿'; case 2: return 'z';                             /*Revisar los átomos --> CORREGIDO*/
            case 3: return 'l'; case 4: return '!'; case 5: return 'n';
            default: return '?';
        }
    } else if (clase == C_OPLOG) {
        int code = atoi(valor);
        /* 0 AND,1 OR,2 NOT */
        switch(code) {
            case 0: return '\'; case 1: return 'b'; case 2: return '#'; default: return '?';        /*revisar si es posible el default*/
        }
    }
    return '?';
}

/* Construye atoms[] a partir de tokens[] */
void build_atom_array() {
    if (n_tokens == 0) { atoms = strdup_safe(""); atom_count = 0; return; }
    atoms = malloc(n_tokens + 1);
    for (int i=0;i<n_tokens;i++) {
        atoms[i] = token_to_atom(tokens[i].clase, tokens[i].valor, tokens[i].etm);
    }
    atoms[n_tokens] = '\0';
    atom_count = n_tokens;
}

/* ---------- Analizador sintáctico descendente recursivo ---------- */
/* Variables de control del parser */
int atom_pos = 0;
int syntax_errors = 0;

/* prototipos */
void parse_driver();
void Program();
void Func();
void otraFunc();
void listaDec();
void props();
void Sent();
void asig();
void expr(); /* E */
void E(); void Ep();
void T(); void Tp();
void F();
void exprLog(); /* expresiones lógicas (simplificadas) */
void expRel();  /* expresiones relacionales (simplificadas) */
void LlamaFunc();
void select_stmt();
void si_stmt();
void caso_block();
void ocaso_block();

/* mostrar token en posición para errores */
void print_error_loc(int pos) {
    if (pos < 0 || pos >= n_tokens) {
        fprintf(stderr,"(posición fuera de rango %d)\n", pos);
        return;
    }
    fprintf(stderr,"[Token %d: '%s']\n", pos, tokens[pos].etm);
}

/* match básico con mensaje de error */
void match_atom(char expected) {
    if (atom_pos >= atom_count) {
        fprintf(stderr,"Error sintáctico: se esperaba '%c' pero fin de átomos (pos %d)\n", expected, atom_pos);
        syntax_errors++;
        return;
    }
    char cur = atoms[atom_pos];
    if (cur == expected) {
        atom_pos++;
    } else {
        fprintf(stderr,"Error sintáctico: se esperaba '%c' en átomo %d pero se encontró '%c'. ", expected, atom_pos, cur);
        print_error_loc(atom_pos);
        syntax_errors++;
        /* intento de recuperación básico: saltar hasta encontrar expected o ';' o ']' o '}' */
        int start = atom_pos;
        while (atom_pos < atom_count && atoms[atom_pos] != expected && atoms[atom_pos] != ';' && atoms[atom_pos] != ']' && atoms[atom_pos] != '}' ) atom_pos++;
        if (atom_pos < atom_count && atoms[atom_pos] == expected) atom_pos++;
        else {
            /* si no encontramos, avanza uno para evitar bucle infinito */
            if (atom_pos == start) atom_pos++;
        }
    }
}

/* PARSER */

/* Program -> Func otraFunc */
void Program() {
    if (atom_pos < atom_count && (atoms[atom_pos]=='e' || atoms[atom_pos]=='f' || atoms[atom_pos]=='c' || atoms[atom_pos]=='v')) {
        Func();
        otraFunc();
    } else {
        fprintf(stderr,"Error sintáctico en Program: se esperaba una función (tipo) al inicio.\n");
        syntax_errors++;
    }
}

/* otraFunc -> Func otraFunc | eps */
void otraFunc() {
    while (atom_pos < atom_count && (atoms[atom_pos]=='e' || atoms[atom_pos]=='f' || atoms[atom_pos]=='c' || atoms[atom_pos]=='v')) {
        Func();
    }
}

/* Func -> tipo a ( listArg ) [ listaDec props ]  */
void Func() {
    /* tipo */
    if (atom_pos < atom_count && (atoms[atom_pos]=='e' || atoms[atom_pos]=='f' || atoms[atom_pos]=='c' || atoms[atom_pos]=='v')) atom_pos++;
    else { fprintf(stderr,"Func: se esperaba tipo en átomo %d\n", atom_pos); syntax_errors++; return; }
    /* id */
    match_atom('a');
    /* '(' listArg ')' */
    match_atom('(');
    /* listArg -> (tipo a (, tipo a)*) | eps */
    if (atom_pos < atom_count && (atoms[atom_pos]=='e' || atoms[atom_pos]=='f' || atoms[atom_pos]=='c' || atoms[atom_pos]=='v')) {
        while (1) {
            if (atom_pos < atom_count && (atoms[atom_pos]=='e' || atoms[atom_pos]=='f' || atoms[atom_pos]=='c' || atoms[atom_pos]=='v')) atom_pos++;
            else { syntax_errors++; break; }
            match_atom('a');
            if (atom_pos < atom_count && atoms[atom_pos]==',') { atom_pos++; continue; }
            else break;
        }
    }
    match_atom(')');
    /* cuerpo entre '[' ']' */
    match_atom('[');
    listaDec();
    props();
    match_atom(']');
}

/* listaDec -> ( tipo lista-id . )*  */
void listaDec() {
    while (atom_pos < atom_count && (atoms[atom_pos]=='e' || atoms[atom_pos]=='f' || atoms[atom_pos]=='c' || atoms[atom_pos]=='v')) {
        /* tipo */
        atom_pos++;
        /* lista-id: a ( = constante ) ( ; a ( = constante) )* . */
        match_atom('a');
        if (atom_pos < atom_count && atoms[atom_pos] == '=') {
            match_atom('=');
            if (atom_pos < atom_count && (atoms[atom_pos]=='i' || atoms[atom_pos]=='r' || atoms[atom_pos]=='s')) atom_pos++;
            else { fprintf(stderr,"listaDec: se esperaba constante en %d\n", atom_pos); syntax_errors++; }
        }
        while (atom_pos < atom_count && atoms[atom_pos]==';') {
            match_atom(';');
            match_atom('a');
            if (atom_pos < atom_count && atoms[atom_pos]=='=') {
                match_atom('=');
                if (atom_pos < atom_count && (atoms[atom_pos]=='i' || atoms[atom_pos]=='r' || atoms[atom_pos]=='s')) atom_pos++;
                else { fprintf(stderr,"listaDec (resto): se esperaba constante en %d\n", atom_pos); syntax_errors++; }
            }
        }
        match_atom('.'); /* terminó declaración */
    }
}

/* props -> (Sent)* */
void props() {
    while (atom_pos < atom_count) {
        char a = atoms[atom_pos];
        if (a=='a' || a=='h' || a=='y' || a=='p' || a=='x' || a=='q') {
            Sent();
        } else {
            /* no es inicio de sentencia; salir (epsilon) */
            break;
        }
    }
}

/* Sent -> asig | hacer | si | para | salir | select */
void Sent() {
    if (atom_pos >= atom_count) return;
    char a = atoms[atom_pos];
    if (a == 'a') asig();
    else if (a == 'h') {
        match_atom('h');
        match_atom('{');
        props();
        match_atom('}');
        match_atom('m'); /* mientras final */
        /* condición después de m (puede ser [ expRel ] o exprLog ) */
        if (atom_pos < atom_count && atoms[atom_pos]=='[') { /* expRel */
            match_atom('[');
            expr(); expRel(); match_atom(']');
        } else { exprLog(); }
        match_atom('.');
    }
    else if (a == 'y') si_stmt();
    else if (a == 'p') {
        /* para ( expr ; cond ; expr ) { props } */
        match_atom('p'); match_atom('(');
        expr(); match_atom(';');
        /* condicion: expRel o exprLog */
        if (atom_pos < atom_count && atoms[atom_pos]=='[') { match_atom('['); expr(); expRel(); match_atom(']'); }
        else exprLog();
        match_atom(';');
        expr(); match_atom(')'); match_atom('{'); props(); match_atom('}');
    }
    else if (a == 'x') {
        match_atom('x');
        /* valRet -> E | eps */
        if (atom_pos < atom_count && (atoms[atom_pos]=='a' || atoms[atom_pos]=='i' || atoms[atom_pos]=='r' || atoms[atom_pos]=='(')) expr();
        match_atom('.');
    }
    else if (a == 'q') {
        select_stmt();
    }
    else {
        fprintf(stderr,"Sent: inicio de sentencia inesperado '%c' en átomo %d\n", a, atom_pos);
        print_error_loc(atom_pos);
        syntax_errors++;
        atom_pos++;
    }
}

/* asig -> a opAsig E . */
void asig() {
    match_atom('a');
    if (atom_pos < atom_count && (atoms[atom_pos]=='=' || atoms[atom_pos]=='D' || atoms[atom_pos]=='J' || atoms[atom_pos]=='U' || atoms[atom_pos]=='W' || atoms[atom_pos]=='A')) {
        atom_pos++;
    } else {
        fprintf(stderr,"asig: se esperaba operador de asignación en átomo %d\n", atom_pos);
        syntax_errors++;
    }
    expr();
    match_atom('.');
}

/* expr -> E (soporta llamadas a funciones y literales) */
void expr() { E(); }

/* E -> T E' */
void E() { T(); Ep(); }
void Ep() {
    while (atom_pos < atom_count && (atoms[atom_pos] == '+' || atoms[atom_pos] == '-')) {
        atom_pos++; T();
    }
}
/* T -> F T' */
void T() { F(); Tp(); }
void Tp() {
    while (atom_pos < atom_count && (atoms[atom_pos] == '*' || atoms[atom_pos] == '/' || atoms[atom_pos] == '%' || atoms[atom_pos] == '^')) {
        atom_pos++; F();
    }
}
/* F -> ( E ) | a | i | r | s | LlamaFunc */
void F() {
    if (atom_pos >= atom_count) { syntax_errors++; return; }
    char a = atoms[atom_pos];
    if (a == '(') { match_atom('('); E(); match_atom(')'); }
    else if (a == 'a' || a == 'i' || a == 'r' || a == 's') { atom_pos++; }
    else if (a == '$') { LlamaFunc(); }
    else {
        fprintf(stderr,"F: símbolo no esperado '%c' en átomo %d\n", a, atom_pos);
        print_error_loc(atom_pos);
        syntax_errors++; atom_pos++;
    }
}

/* LlamaFunc -> $ a ( listP ) */
void LlamaFunc() {
    match_atom('$'); match_atom('a'); match_atom('(');
    /* listP -> ( E ( ; E )* ) | eps */
    if (atom_pos < atom_count && (atoms[atom_pos]=='a' || atoms[atom_pos]=='i' || atoms[atom_pos]=='r' || atoms[atom_pos]=='(')) {
        expr();
        while (atom_pos < atom_count && atoms[atom_pos]==';') { match_atom(';'); expr(); }
    }
    match_atom(')');
}

/* exprLog -> expr (opLog expr)* | ( opLog expr ) etc. (versión simplificada) */
void exprLog() {
    /* manejamos operandos sencillos y operadores &,|,! */
    if (atom_pos < atom_count && atoms[atom_pos]=='!') { match_atom('!'); expr(); return; }
    expr();
    while (atom_pos < atom_count && (atoms[atom_pos]=='&' || atoms[atom_pos]=='|')) {
        atom_pos++; expr();
    }
}

/* expRel -> opRel E (interpretación: hay una opRel en medio) */
void expRel() {
    if (atom_pos < atom_count && (atoms[atom_pos]=='g' || atoms[atom_pos]=='G' || atoms[atom_pos]=='z' || atoms[atom_pos]=='l' || atoms[atom_pos]=='q' || atoms[atom_pos]=='n')) {
        atom_pos++; E();
    } else {
        /* si no hay operador relacional, no es necesariamente error: puede ser que
           expRel se llame después de haber consumido parte. No hacemos nada. */
    }
}

/* si -> y ( condicion ) { props } ( o ocaso ) .   (armonizado con átomos) */
void si_stmt() {
    match_atom('y');
    /* condición: [ expRel ] o exprLog — aquí aceptamos ambas */
    if (atom_pos < atom_count && atoms[atom_pos]=='[') {
        match_atom('['); expr(); expRel(); match_atom(']');
    } else {
        exprLog();
    }
    match_atom('{'); props(); match_atom('}');
    /* finalsi -> eps | o (y | { props } ) */
    if (atom_pos < atom_count && atoms[atom_pos]=='o') {
        match_atom('o');
        if (atom_pos < atom_count && atoms[atom_pos]=='y') {
            si_stmt(); /* 'ocaso' seguido de 'si' (else if) -> parsear si otra vez */
        } else {
            match_atom('{'); props(); match_atom('}');
        }
    }
}

/* select -> q ( a ) { (k i { props })* ( t { props } )? } */
void select_stmt() {
    match_atom('q'); match_atom('('); match_atom('a'); match_atom(')'); match_atom('{');
    while (atom_pos < atom_count && atoms[atom_pos]=='k') {
        match_atom('k'); match_atom('i'); match_atom('{'); props(); match_atom('}');
    }
    if (atom_pos < atom_count && atoms[atom_pos]=='t') {
        match_atom('t'); match_atom('{'); props(); match_atom('}');
    }
    match_atom('}');
}

/* conductor del parser */
void parse_driver() {
    build_atom_array();
    printf("\n=== CADENA DE ÁTOMOS ===\n");
    if (atoms) printf("%s\n", atoms);
    atom_pos = 0;
    syntax_errors = 0;
    Program();
    if (atom_pos < atom_count) {
        printf("Advertencia: no se consumieron todos los átomos; posición %d de %d\n", atom_pos, atom_count);
        printf("Resto de átomos: ");
        for (int i=atom_pos;i<atom_count;i++) putchar(atoms[i]);
        putchar('\n');
    }
    if (syntax_errors == 0) {
        printf("\nEl programa fuente está sintácticamente correcto.\n");
    } else {
        printf("\nSe encontraron %d errores sintácticos.\n", syntax_errors);
    }
}

/* ---------- LEXER (Flex rules) ---------- */
/* Reglas: keywords, identificadores, enteros, reales, strings, operadores y símbolos */

%}

/* Definiciones de patrones */
DIGIT       [0-9]
LETTER      [A-Za-z_]
ID          {LETTER}({LETTER}|{DIGIT})*
INT         {DIGIT}+
REAL        {DIGIT}+"."{DIGIT}+
STRING      \"([^"\n]|\\\")*\"

/* Reglas */
%%
[ \t\r\n]+                  { /* ignorar espacios y nueva línea */ }

"//".*                      { /* comentario línea */ }

"/*"([^*]|\*+[^*/])*\*+ "/" { /* comentario multi-línea (simple) */ }

"entero"                    { add_token_int(C_PALRES, "2", yytext); }
"cadena"                    { add_token_int(C_PALRES, "0", yytext); }
"flotante"|"real"           { add_token_int(C_PALRES, "3", yytext); }
"hacer"                     { add_token_int(C_PALRES, "4", yytext); }
"mientras"                  { add_token_int(C_PALRES, "5", yytext); }
"ocaso"                     { add_token_int(C_PALRES, "6", yytext); }
"para"                      { add_token_int(C_PALRES, "7", yytext); }
"predet"                    { add_token_int(C_PALRES, "8", yytext); }
"salir"                     { add_token_int(C_PALRES, "9", yytext); }
"select"                    { add_token_int(C_PALRES, "10", yytext); }
"si"                        { add_token_int(C_PALRES, "11", yytext); }
"vacio"                     { add_token_int(C_PALRES, "12", yytext); }
"caso"                      { add_token_int(C_PALRES, "1", yytext); }

"\\$"                       { add_token_int(C_DOLLAR, NULL, yytext); } /* llamada a función marcada por $ */

/* operadores de asignación: mapeamos códigos para el parser */
"+="                        { add_token_int(C_OPASIG, "1", yytext); }
"-="                        { add_token_int(C_OPASIG, "2", yytext); }
"*="                        { add_token_int(C_OPASIG, "3", yytext); }   /* /="/" */
"/="                        { add_token_int(C_OPASIG, "4", yytext); }
"&="                        { add_token_int(C_OPASIG, "5", yytext); }
"="                         { add_token_int(C_OPASIG, "0", yytext); }

/* operadores aritméticos simples */
"+"                         { add_token_int(C_OPARIT, "0", yytext); }
"-"                         { add_token_int(C_OPARIT, "1", yytext); }
"*"                         { add_token_int(C_OPARIT, "2", yytext); }
"/"                         { add_token_int(C_OPARIT, "3", yytext); }
"^"                         { add_token_int(C_OPARIT, "4", yytext); }
"%"                         { add_token_int(C_OPARIT, "5", yytext); }

/* operadores relacionales: =:= o :: para igual (enunciado varia; mapeo razonable) */
"::"                        { add_token_int(C_OPREL, "0", yytext); } /* igual (g) */
"!="                        { add_token_int(C_OPREL, "1", yytext); }
">="                        { add_token_int(C_OPREL, "4", yytext); }
"<="                        { add_token_int(C_OPREL, "5", yytext); }
">"                         { add_token_int(C_OPREL, "2", yytext); }
"<"                         { add_token_int(C_OPREL, "3", yytext); }

/* operadores lógicos */
"&&"                        { add_token_int(C_OPLOG, "0", yytext); }
"\\|\\|"                    { add_token_int(C_OPLOG, "1", yytext); }
"!"                         { add_token_int(C_OPLOG, "2", yytext); }

/* símbolos y puntuación (se usan como sus mismos átomos) */
"("                         { add_token_int(C_SIMB, NULL, yytext); }
")"                         { add_token_int(C_SIMB, NULL, yytext); }
"{"                         { add_token_int(C_SIMB, NULL, yytext); }
"}"                         { add_token_int(C_SIMB, NULL, yytext); }
"["                         { add_token_int(C_SIMB, NULL, yytext); }
"]"                         { add_token_int(C_SIMB, NULL, yytext); }
","                         { add_token_int(C_SIMB, NULL, yytext); }
"."                         { add_token_int(C_SIMB, NULL, yytext); }
";"                         { add_token_int(C_SIMB, NULL, yytext); }

/* literales */
{REAL}                      {
                                char *idx = add_litreal(yytext);
                                add_token_int(C_REAL, idx, yytext);
                            }
{INT}                       {
                                char *idx = add_litint(yytext);
                                add_token_int(C_INT, idx, yytext);
                            }
{STRING}                    {
                                /* quitar comillas al almacenar */
                                int L = yyleng;
                                char *tmp = malloc(L-1);
                                strncpy(tmp, yytext+1, L-2); tmp[L-2]='\0';
                                char *idx = add_litstr(tmp);
                                free(tmp);
                                add_token_int(C_CAD, idx, yytext);
                            }

/* identificadores (cuidado con palabras reservadas ya capturadas) */
{ID}                        {
                                /* como palabras reservadas fueron reconocidas antes, aquí son IDs */
                                char *idx = add_ident(yytext);
                                add_token_int(C_ID, idx, yytext);
                            }

/* cualquier otro caracter no reconocido: reportar error léxico pero seguir */
.                           { fprintf(stderr,"ERROR LEX: caracter no reconocido '%s' (se ignora)\n", yytext); }

%%

/* main y funciones de arranque */
int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr,"Uso: %s <archivo_fuente>\n", argv[0]);
        return 1;
    }
    FILE *f = fopen(argv[1],"r");
    if (!f) { perror("abrir archivo fuente"); return 1; }
    yyin = f;
    /* ejecutar lexer y llenar tablas */
    yylex();
    fclose(f);

    /* imprimir tablas iniciales y tokens */
    print_tables();

    /* construir cadena de átomos y ejecutar parser */
    parse_driver();

    return 0;
}

/* Fin del archivo */
