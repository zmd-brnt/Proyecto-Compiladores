%{
/*
  Analizador Léxico + Sintáctico Descendente Recursivo
  Proyecto: Analizador Sintáctico
  Autores: Franco Ramírez Christian, Pérez Paitán Brent Armando
  Fecha : 2025-11-08

  Objetivo
    Construir, en un mismo programa, los analizadores Léxico y Sintáctico Descendente
    Recursivo que revisen programas escritos en el lenguaje definido por la gramática 
    del Anexo A del documento.

  Descripción:
  - Analizador léxico en Flex que genera tokens y tablas (identificadores,
    literales reales y cadenas).
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
    char *valor;    /* valor semántico (índice en tabla o ascii) */
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

/* Clases léxicas */
enum {
    C_PALRES=0,  
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

/* variables para los átomos / parser */
char *atoms = NULL;   
int atom_count = 0;
int atom_pos = 0;
int syntax_errors = 0;

/* funciones auxiliares del parser (prototipos) */
char peek_atom();
void advance_atom();
void syn_error(const char *msg);
void print_error_loc(int pos);
void build_atom_array();
void parse_driver();

/* prototipo de yylex/yyin (proporcionado por flex) */
extern int yylex();
extern FILE *yyin;
extern char *yytext;
extern int yyleng;

/* función auxiliar para clonar strings */
char *strdup_safe(const char *s) {
    if (!s) return NULL;
    char *r = malloc(strlen(s)+1);
    strcpy(r,s);
    return r;
}

/* Añadir identificador a tabla y devolver índice como string */
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

/* Añadir token */
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
        printf("%4d)\tclase=%d    valor='%s'\t lex='%s'\n", i, tokens[i].clase, tokens[i].valor, tokens[i].etm);
    }
    printf("\n=== IDENTIFICADORES (%d) ===\n", n_idents);
    for (int i=0;i<n_idents;i++) printf("%4d) %s\n", i, idents[i]);
    printf("\n=== LITERALES CADENA (%d) ===\n", n_litstr);
    for (int i=0;i<n_litstr;i++) printf("%4d) \"%s\"\n", i, litstr[i]);
    printf("\n=== LITERALES REALES (%d) ===\n", n_litreal);
    for (int i=0;i<n_litreal;i++) printf("%4d) %s\n", i, litreal[i]);
}

/* ---------- convertidor token -> átomo char ---------- */
/* Ajusta los caracteres de átomo para que coincidan con el enunciado. */
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
        }
    } else if (clase == C_INT) return 'i';
    else if (clase == C_ID) return 'a';
    else if (clase == C_REAL) return 'r';
    else if (clase == C_CAD) return 's';
    else if (clase == C_SIMB) {
        /* símbolos: operadores y puntuación: usamos el primer carácter del lexema */
        if (lex && lex[0]) return lex[0];
    } else if (clase == C_OPARIT) {
        int code = atoi(valor);
        switch(code) {
            case 0: return '+'; case 1: return '-'; case 2: return '*';
            case 3: return '/'; case 4: return '¬'; case 5: return '%';
        }
    } else if (clase == C_OPASIG) {
        int code = atoi(valor);
        /* mapear códigos de op asignación  */
        switch(code) {
            case 0: return '=';   /* = */
            case 1: return 'd';   /* *= */
            case 2: return 'j';   /* /= */
            case 3: return 'u';   /* += */
            case 4: return '¡';   /* -= */
            case 5: return 'w';   /* %= */
            case 6: return '<';   /* <<= */
            case 7: return '>';   /* >>= */
            case 8: return '&';   /* &= */
            case 9: return '^';   /* ^= */
            case 10: return '|';  /* |= */
        }
    } else if (clase == C_OPREL) {
        int code = atoi(valor);
        /* códigos: 0::,1¿:,2> ,3<,4>:,5<: */
        switch(code) {
            case 0: return 'g'; case 1: return '¿'; case 2: return 'z';
            case 3: return 'l'; case 4: return '!'; case 5: return 'n';
        }
    } else if (clase == C_OPLOG) {
        int code = atoi(valor);
        /* 0 AND,1 OR,2 NOT  */
        switch(code) {
            case 0: return '\\'; case 1: return 'b'; case 2: return '#';
        }
    }
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

/* ---------- apoyo para el parser (peek/advance/errores) ---------- */
char peek_atom() {
    if (!atoms) return 0;
    if (atom_pos >= atom_count) return 0;
    return atoms[atom_pos];
}
void advance_atom() {
    if (atom_pos < atom_count) atom_pos++;
}
void syn_error(const char *msg) {
    fprintf(stderr,"Error sintáctico (pos %d): %s. ", atom_pos, msg);
    print_error_loc(atom_pos);
    syntax_errors++;
    /* intento de recuperación básico: avanzar uno */
    if (atom_pos < atom_count) atom_pos++;
}
void print_error_loc(int pos) {
    if (pos < 0 || pos >= n_tokens) {
        fprintf(stderr,"(posición fuera de rango %d)\n", pos);
        return;
    }
    fprintf(stderr,"[Token %d: '%s']\n", pos, tokens[pos].etm);
}

/* ------------------ Prototipos de todas las funciones del parser -------------- */

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
    char p = peek_atom();
    if (p=='c' || p=='e' || p=='f' || p=='v') {
        Func();
        otraFunc();
    } else {
        syn_error("inicio de Program (se esperaba c/e/f/v)");
    }
}

void otraFunc() {
    char p = peek_atom();
    if (p=='c' || p=='e' || p=='f' || p=='v') {
        Func();
        otraFunc();
    } else {
        /* epsilon/fin */
        return;
    }
}

void Func() {
    char p = peek_atom();
    if (p=='c' || p=='e' || p=='f' || p=='v') {
        tipo_fn();
        if (peek_atom()=='a') advance_atom(); else syn_error("identificador 'a' en Func");
        if (peek_atom()=='(') advance_atom(); else syn_error("'(' en Func");
        listArg();
        if (peek_atom()==')') advance_atom(); else syn_error("')' en Func");
        if (peek_atom()=='[') advance_atom(); else syn_error("'[' inicio cuerpo");
        cuerpo();
        if (peek_atom()==']') advance_atom(); else syn_error("']' fin cuerpo");
    } else {
        syn_error("Func (tipo esperado)");
    }
}

void listArg() {
    char p = peek_atom();
    if (p=='c' || p=='e' || p=='f' || p=='v') {
        tipo_fn();
        if (peek_atom()=='a') advance_atom(); else syn_error("'a' en listArg");
        otroArg();
    } else if (p==')') {
        return;
    } else {
        syn_error("listArg (tipo o ')')");
    }
}

void otroArg() {
    char p = peek_atom();
    if (p==';') {
        advance_atom();
        tipo_fn();
        if (peek_atom()=='a') advance_atom(); else syn_error("'a' en otroArg");
        otroArg();
    } else if (p==')') {
        return;
    } else {
        /* epsilon */
        return;
    }
}

void cuerpo() {
    listaDec();
    props_fn();
}

void listaDec() {
    char p = peek_atom();
    if (p=='c' || p=='e' || p=='f' || p=='v') {
        sent_decl();
        listaDec();
    } else {
        return;
    }
}

void sent_decl() {
    if (peek_atom()=='c' || peek_atom()=='e' || peek_atom()=='f' || peek_atom()=='v') {
        tipo_fn();
        lista_id();
        if (peek_atom()=='.') advance_atom(); else syn_error("'.' despues de declaracion");
    } else {
        syn_error("sent_decl (tipo esperado)");
    }
}

void tipo_fn() {
    char p = peek_atom();
    if (p=='e' || p=='f' || p=='c' || p=='v') {
        advance_atom();
    } else {
        syn_error("tipo (e/f/c/v)");
    }
}

void lista_id() {
    if (peek_atom()=='a') {
        advance_atom();
        asig_val();
        resto_lista_id();
    } else {
        syn_error("lista_id (se esperaba 'a')");
    }
}

void resto_lista_id() {
    char p = peek_atom();
    if (p==';') {
        advance_atom();
        lista_id();
    } else {
        return;
    }
}

void asig_val() {
    char p = peek_atom();
    if (p=='=') {
        advance_atom();
        constante_fn();
    } else {
        return;
    }
}

void constante_fn() {
    char p = peek_atom();
    if (p=='i' || p=='r' || p=='s') advance_atom();
    else syn_error("constante (i,r,s)");
}

/* ---------------- EXPRESIONES ---------------- */

void E() {
    char p = peek_atom();
    if (p==0) { syn_error("E (fin inesperado)"); return; }
    if (p=='(' || p=='a' || p=='i' || p=='r' || p=='s' || p=='$') {
        T();
        Eprime();
    } else {
        syn_error("inicio de expresion (E)");
    }
}

void Eprime() {
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
        return;
    }
}

void T() {
    char p = peek_atom();
    if (p=='(' || p=='a' || p=='i' || p=='r' || p=='s' || p=='$') {
        F();
        Tprime();
    } else {
        syn_error("inicio de termino (T)");
    }
}

void Tprime() {
    char p = peek_atom();
    if (p=='*') {
        advance_atom(); F(); Tprime();
    } else if (p=='/') {
        advance_atom(); F(); Tprime();
    } else if (p=='%') {
        advance_atom(); F(); Tprime();
    } else if (p=='^') {
        advance_atom(); F(); Tprime();
    } else {
        return;
    }
}

void F() {
    char p = peek_atom();
    if (p=='(') {
        advance_atom(); E();
        if (peek_atom()==')') advance_atom(); else syn_error("')' despues de (E)");
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
    if (peek_atom()=='$') {
        advance_atom();
        if (peek_atom()=='a') advance_atom(); else syn_error("'a' despues de $ en llamada");
        if (peek_atom()=='(') advance_atom(); else syn_error("'(' en llamada");
        listP_fn();
        if (peek_atom()==')') advance_atom(); else syn_error("')' fin llamada");
    } else {
        syn_error("LlamaFunc ($ esperado)");
    }
}

/* ---------------- ASIGNACIONES y OPERADORES ---------------- */

void asig() {
    if (peek_atom()=='a') {
        advance_atom();
        opAsig_fn();
        E();
        if (peek_atom()=='.') advance_atom(); else syn_error("'.' al final de asignacion");
    } else {
        syn_error("asig (a esperado)");
    }
}

void opAsig_fn() {
    char p = peek_atom();
    if (p=='='||p=='d'||p=='j'||p=='u'||p=='v'||p=='w'||p=='<'||p=='>'||p=='&'||p=='^'||p=='|') {
        advance_atom();
    } else {
        syn_error("operador asignacion (=, d, j, u, v, w, <, >, &, ^, |)");
    }
}

/* ---------------- RELACIONALES / LOGICOS ---------------- */

void expRel() {
    if (peek_atom()=='[') {
        advance_atom();
        E();
        opRel_fn();
        E();
        if (peek_atom()==']') advance_atom(); else syn_error("']' en expRel");
    } else {
        syn_error("'[' inicio expRel");
    }
}

void opRel_fn() {
    char p = peek_atom();
    if (p == 'g' || p == 'z' || p == 'l' || p == '!' || p == 'n' || (unsigned char)p == 0xBF)    advance_atom();
    else syn_error("opRel (g,¿,z,l,!,n)");
}

void exprLog() {
    char p = peek_atom();
    if (p=='#') {
        advance_atom();
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' despues de #");
        exprV();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' despues de exprV");
    } else if (p=='{') {
        advance_atom();
        expRel();
        opLog_fn();
        expRel();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' fin exprLog");
    } else {
        syn_error("exprLog (# o {)");
    }
}

void exprV() {
    char p = peek_atom();
    if (p=='(' || p=='a' || p=='i' || p=='r' || p=='s' || p=='$') {
        E();
    } else if (p=='[') {
        expRel();
    } else {
        syn_error("exprV (E o expRel)");
    }
}

void opLog_fn() {
    char p = peek_atom();
    if (p=='\\' || p=='b') advance_atom();
    else syn_error("opLog (\\ o b)");
}

/* ---------------- SENTENCIAS / BLOQUES ---------------- */

void Sent_fn() {
    char p = peek_atom();
    if (p=='a') { asig(); }
    else if (p=='h') { hacerM(); }
    else if (p=='y') { si_fn(); }
    else if (p=='p') { para_fn(); }
    else if (p=='x') { salir_fn(); }
    else if (p=='q') { select_fn(); }
    else { syn_error("inicio de Sent (a/h/y/p/x/q)"); }
}

void props_fn() {
    char p = peek_atom();
    if (p=='a' || p=='h' || p=='y' || p=='p' || p=='x' || p=='q') {
        Sent_fn();
        props_fn();
    } else {
        return;
    }
}

void hacerM() {
    if (peek_atom()=='h') {
        advance_atom();
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' despues de h");
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' en hacerM");
        if (peek_atom()=='m') advance_atom(); else syn_error("'m' despues del bloque de hacer");
        condicion_fn();
        if (peek_atom()=='.') advance_atom(); else syn_error("'.' despues de hacerM");
    } else syn_error("hacerM (h esperado)");
}

void condicion_fn() {
    char p = peek_atom();
    if (p=='[') expRel();
    else if (p=='#' || p=='{') exprLog();
    else syn_error("condicion ([ o # o {)");
}

void si_fn() {
    if (peek_atom()=='y') {
        advance_atom();
        condicion_fn();
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' despues de condicion en si");
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' fin bloque si");
        finalsi();
    } else syn_error("si (y esperado)");
}

void finalsi() {
    char p = peek_atom();
    if (p=='o') {
        advance_atom();
        ocaso_fn();
    } else {
        return;
    }
}

void ocaso_fn() {
    char p = peek_atom();
    if (p=='y') si_fn();
    else if (p=='{') {
        advance_atom();
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' en ocaso");
    } else syn_error("ocaso (y o {)");
}

void para_fn() {
    if (peek_atom()=='p') {
        advance_atom();
        if (peek_atom()=='(') advance_atom(); else syn_error("'(' despues de p");
        expr_fn();
        if (peek_atom()==';') advance_atom(); else syn_error("';' despues de expr en para");
        condicion_fn();
        if (peek_atom()==';') advance_atom(); else syn_error("';' despues de condicion en para");
        expr_fn();
        if (peek_atom()==')') advance_atom(); else syn_error("')' en para");
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' inicio bloque para");
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' fin para");
    } else syn_error("para (p esperado)");
}

void expr_fn() {
    if (peek_atom()=='a') {
        advance_atom();
        opAsig_fn();
        E();
    } else syn_error("expr (a esperado)");
}

void salir_fn() {
    if (peek_atom()=='x') {
        advance_atom();
        valRet_fn();
        if (peek_atom()=='.') advance_atom(); else syn_error("'.' despues de salir");
    } else syn_error("salir (x esperado)");
}

void valRet_fn() {
    char p = peek_atom();
    if (p=='(' || p=='a' || p=='i' || p=='r' || p=='s' || p=='$') E();
    else return;
}

void select_fn() {
    if (peek_atom()=='q') {
        advance_atom();
        if (peek_atom()=='(') advance_atom(); else syn_error("'(' en select");
        if (peek_atom()=='a') advance_atom(); else syn_error("'a' en select");
        if (peek_atom()==')') advance_atom(); else syn_error("')' en select");
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' inicio select");
        if (peek_atom()=='k') {
            advance_atom();
            if (peek_atom()=='i') advance_atom(); else syn_error("'i' despues de k en select");
            if (peek_atom()=='{') advance_atom(); else syn_error("'{' en caso select");
            props_fn();
            if (peek_atom()=='}') advance_atom(); else syn_error("'}' fin caso");
            siguiente_fn();
        } else syn_error("'k' en select");
    } else syn_error("select (q esperado)");
}

void siguiente_fn() {
    char p = peek_atom();
    if (p=='k') {
        advance_atom();
        if (peek_atom()=='i') advance_atom(); else syn_error("'i' despues de k en siguiente");
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' en siguiente");
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' fin siguiente");
        siguiente_fn();
    } else if (p=='}') {
        advance_atom();
        return;
    } else if (p=='t') {
        advance_atom();
        if (peek_atom()=='{') advance_atom(); else syn_error("'{' despues de t en siguiente");
        props_fn();
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' despues de t");
        if (peek_atom()=='}') advance_atom(); else syn_error("'}' cierre select");
        return;
    } else {
        syn_error("siguiente (k, } o t)");
    }
}

void listP_fn() {
    char p = peek_atom();
    if (p==')') return;
    else if (p=='(' || p=='a' || p=='i' || p=='r' || p=='s' || p=='$') {
        E();
        Param_fn();
    } else syn_error("listP (parametros)");
}

void Param_fn() {
    char p = peek_atom();
    if (p==';') {
        advance_atom();
        E();
        Param_fn();
    } else return;
}

%}

/* ---------- REGLAS DE FLEX -> ANALIZADOR LEXICO ---------- */

DIGIT       [0-9]
LETTER      [a-z]
UNDER       _
ID          {LETTER}(({LETTER}|{UNDER})*{DIGIT}+|{LETTER}({LETTER}|{UNDER})*{LETTER}|{LETTER}*)
INT         ([+-])?{DIGIT}+
REAL        ([+-])?{DIGIT}+@{DIGIT}+(@@([+-])?{DIGIT}+)? 
STRING      ¿[^¿\?\n]*\?

%%
[ \t\r\n]+                  { /* ignorar espacios y nueva línea */ }

\"([^\\"]|\\n)*\"           { /* comentario: ignorar */ }  

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

"*="                        { add_token_int(C_OPASIG, "1", yytext); }
"/="                        { add_token_int(C_OPASIG, "2", yytext); }
"+="                        { add_token_int(C_OPASIG, "3", yytext); }
"-="                        { add_token_int(C_OPASIG, "4", yytext); }
"%="                        { add_token_int(C_OPASIG, "5", yytext); }
"<<="                       { add_token_int(C_OPASIG, "6", yytext); }
">>="                       { add_token_int(C_OPASIG, "7", yytext); }
"&="                        { add_token_int(C_OPASIG, "8", yytext); }
"^="                        { add_token_int(C_OPASIG, "9", yytext); }
"|="                        { add_token_int(C_OPASIG, "10", yytext); }
"="                         { add_token_int(C_OPASIG, "0", yytext); }

"¬+¬"                       { add_token_int(C_OPARIT, "0", yytext); } 
"¬-¬"                       { add_token_int(C_OPARIT, "1", yytext); } 
"¬*¬"                       { add_token_int(C_OPARIT, "2", yytext); } 
"¬/¬"                       { add_token_int(C_OPARIT, "3", yytext); } 
"¬^¬"                       { add_token_int(C_OPARIT, "4", yytext); } 
"¬%¬"                       { add_token_int(C_OPARIT, "5", yytext); } 

"::"                        { add_token_int(C_OPREL, "0", yytext); } 
"¿:"                        { add_token_int(C_OPREL, "1", yytext); } 
">"                         { add_token_int(C_OPREL, "2", yytext); }
"<"                         { add_token_int(C_OPREL, "3", yytext); }
">:"                        { add_token_int(C_OPREL, "4", yytext); } 
"<:"                        { add_token_int(C_OPREL, "5", yytext); } 

"\\\\"                      { add_token_int(C_OPLOG, "0", yytext); } 
"//"                        { add_token_int(C_OPLOG, "1", yytext); } 
"\|\|"                      { add_token_int(C_OPLOG, "2", yytext); } 

"("                         { add_token_int(C_SIMB, "40", yytext); }
")"                         { add_token_int(C_SIMB, "41", yytext); }
"{"                         { add_token_int(C_SIMB, "123", yytext); }
"}"                         { add_token_int(C_SIMB, "125", yytext); }
"["                         { add_token_int(C_SIMB, "91", yytext); }
"]"                         { add_token_int(C_SIMB, "93", yytext); }
"$"                         { add_token_int(C_SIMB, "36", yytext); }
"."                         { add_token_int(C_SIMB, "46", yytext); }
";"                         { add_token_int(C_SIMB, "59", yytext); }

{REAL}                      {
                                char *idx = add_litreal(yytext);
                                add_token_int(C_REAL, idx, yytext);
                            }
{INT}                       {
                                add_token_int(C_INT, yytext, yytext);
                            }
{STRING}                    {
                                /* quitar los simbolos de cadena (¿,?) al almacenar */
                                int L = yyleng;
                                char *tmp = malloc(L-1);
                                if (!tmp) { fprintf(stderr,"malloc fallo\n"); exit(1); }
                                strncpy(tmp, yytext+1, L-2); tmp[L-2]='\0';
                                char *idx = add_litstr(tmp);
                                free(tmp);
                                add_token_int(C_CAD, idx, yytext);
                            }

{ID}                        {
                                char *idx = add_ident(yytext);
                                add_token_int(C_ID, idx, yytext);
                            }

.                           { fprintf(stderr,"ERROR LEX: caracter no reconocido '%s' (se ignora)\n", yytext); }

%%

/* ---------- Driver del Parser / main ---------- */

void parse_driver() {
    /* construir atoms y lanzar parser */
    build_atom_array();
    atom_pos = 0;
    syntax_errors = 0;

    printf("\n=== CADENA DE ATOMOS (length=%d) ===\n", atom_count);
    for (int i = 0; i < atom_count; ++i) printf("%c", atoms[i]);
    printf("\n\n=== INICIO PARSE ===\n");

    Program();

    if (syntax_errors == 0 && atom_pos >= atom_count) {
        printf("\nEl programa es sintácticamente correcto (sin errores detectados).\n");
    } else {
        printf("\nParse finalizado con %d errores sintácticos. atom_pos=%d atom_count=%d\n", syntax_errors, atom_pos, atom_count);
    }
}

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

/* ---------- CORRECCIÓN DE WARNING yywrap ---------- */
int yywrap(void) {
    return 1;
}
