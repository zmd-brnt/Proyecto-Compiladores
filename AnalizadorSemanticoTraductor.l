%{
/*
  Analizador Léxico + Sintáctico Descendente Recursivo + Semántico
  Proyecto: Analizador Sintáctico-Semántico
  Autores: Franco Ramírez Christian, Pérez Paitán Brent Armando
  Fecha: 2025-12-09

  Objetivo:
    Construir en un mismo programa, los analizadores Léxico, Sintáctico, Semántico y generar una
    cierta traducción de programas fuente escritos con el lenguaje elaborado en clase. 

  Etapas:
    - Análisis léxico, sintáctico y semántico
    - Actualización del campo tipo en tabla de símbolos
    - Traducción de asignaciones compuestas a simples
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

/* Tipos de datos */
#define TIPO_DESCONOCIDO -1
#define TIPO_ENTERO 0
#define TIPO_FLOTANTE 1
#define TIPO_CADENA 2
#define TIPO_VACIO 3

typedef struct {
    int clase;      /* clase léxica */
    char *valor;    /* valor semántico (índice en tabla o ascii) */
    char *etm;      /* lexema original */
} Token;

Token tokens[MAX_TOKENS];
int n_tokens = 0;

/* Tabla de identificadores CON TIPO */
typedef struct {
    char *nombre;
    int tipo;       /* -1: desconocido, 0: entero, 1: flotante, 2: cadena, 3: vacio */
} IdentEntry;

IdentEntry idents[MAX_IDENTS];
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
int sem_errors = 0;          /* Contador de errores semánticos */

/* funciones auxiliares del parser (prototipos) */
char peek_atom();
void advance_atom();
void syn_error(const char *msg);
void sem_error(const char *msg);
void print_error_loc(int pos);
void build_atom_array();
void parse_driver();

/* Funciones semánticas */
void asignar_tipo(int idx, int tipo);
int obtener_tipo(int idx);
void verificar_declarado(int idx, int pos_token);
void traducir_asignacion_compuesta(int pos_id, int pos_op, int inicio_expr, int fin_expr);
char *obtener_operador_simple(char *lexema);

/* prototipo de yylex/yyin (proporcionado por flex) */
extern int yylex();
extern FILE *yyin;
extern char *yytext;
extern int yyleng;

/* función auxiliar para clonar strings */
char *strdup_safe(const char *s) {
    if (!s) return NULL;
    char *r = malloc(strlen(s)+1);
    if (r) strcpy(r, s);
    return r;
}

/* Añadir identificador a tabla y devolver índice como string */
char *add_ident(const char *s) {
    for (int i=0;i<n_idents;i++)
        if (strcmp(idents[i].nombre, s)==0) {
            char tmp[32];
            sprintf(tmp, "%d", i);
            return strdup_safe(tmp);
        }
    if (n_idents >= MAX_IDENTS) {
        fprintf(stderr,"Demasiados identificadores\n");
        exit(1);
    }
    idents[n_idents].nombre = strdup_safe(s);
    idents[n_idents].tipo = TIPO_DESCONOCIDO;  /* Inicialmente desconocido */
    char tmp[32];
    sprintf(tmp, "%d", n_idents);
    n_idents++;
    return strdup_safe(tmp);
}

/* Añadir literal cadena */
char *add_litstr(const char *s) {
    for (int i=0;i<n_litstr;i++)
        if (strcmp(litstr[i], s)==0) {
            char tmp[32];
            sprintf(tmp, "%d", i);
            return strdup_safe(tmp);
        }
    if (n_litstr >= MAX_LITSTR) {
        fprintf(stderr,"Demasiados literales cadena\n");
        exit(1);
    }
    litstr[n_litstr] = strdup_safe(s);
    char tmp[32];
    sprintf(tmp, "%d", n_litstr);
    n_litstr++;
    return strdup_safe(tmp);
}

/* Añadir literal real */
char *add_litreal(const char *s) {
    for (int i=0;i<n_litreal;i++)
        if (strcmp(litreal[i], s)==0) {
            char tmp[32];
            sprintf(tmp, "%d", i);
            return strdup_safe(tmp);
        }
    if (n_litreal >= MAX_LITREAL) {
        fprintf(stderr,"Demasiados literales reales\n");
        exit(1);
    }
    litreal[n_litreal] = strdup_safe(s);
    char tmp[32];
    sprintf(tmp, "%d", n_litreal);
    n_litreal++;
    return strdup_safe(tmp);
}

/* Añadir token */
void add_token_int(int clase, const char *valor, const char *lex) {
    if (n_tokens >= MAX_TOKENS) {
        fprintf(stderr,"Demasiados tokens\n");
        exit(1);
    }
    tokens[n_tokens].clase = clase;
    tokens[n_tokens].valor = valor ? strdup_safe(valor) : strdup_safe("");
    tokens[n_tokens].etm = lex ? strdup_safe(lex) : strdup_safe("");
    n_tokens++;
}

/* ---------- FUNCIONES SEMÁNTICAS ---------- */

/* Asignar tipo a un identificador */
void asignar_tipo(int idx, int tipo) {
    if (idx < 0 || idx >= n_idents) {
        fprintf(stderr, "Error: índice de identificador inválido %d\n", idx);
        return;
    }
    if (idents[idx].tipo != TIPO_DESCONOCIDO && idents[idx].tipo != tipo) {
        fprintf(stderr, "Error semántico: identificador '%s' ya declarado con tipo diferente\n",
                idents[idx].nombre);
        sem_errors++;
        return;
    }
    idents[idx].tipo = tipo;
}

/* Obtener tipo de un identificador */
int obtener_tipo(int idx) {
    if (idx < 0 || idx >= n_idents) {
        return TIPO_DESCONOCIDO;
    }
    return idents[idx].tipo;
}

/* Verificar si un identificador está declarado */
void verificar_declarado(int idx, int pos_token) {
    if (idx < 0 || idx >= n_idents) {
        fprintf(stderr, "Error semántico (posición token %d): identificador no encontrado en tabla\n",
                pos_token);
        sem_errors++;
        return;
    }
    if (idents[idx].tipo == TIPO_DESCONOCIDO) {
        fprintf(stderr, "Error semántico (posición token %d): identificador '%s' no declarado\n",
                pos_token, idents[idx].nombre);
        sem_errors++;
    }
}

/* Traducir asignación compuesta */
void traducir_asignacion_compuesta(int pos_id, int pos_op, int inicio_expr, int fin_expr) {
    char *nombre = tokens[pos_id].etm;
    char *op = tokens[pos_op].etm;
    char *op_simple = obtener_operador_simple(op);

    printf("\n  [TRADUCCIÓN] %s = %s ¬%s¬ ", nombre, nombre, op_simple);
    for (int i = inicio_expr; i <= fin_expr; i++) {
        printf(" %s", tokens[i].etm);
    }
    printf("\n");
}

/* Obtener operador simple para traducción */
char *obtener_operador_simple(char *lexema) {
    if (strcmp(lexema, "*=") == 0) return "*";
    if (strcmp(lexema, "/=") == 0) return "/";
    if (strcmp(lexema, "+=") == 0) return "+";
    if (strcmp(lexema, "-=") == 0) return "-";
    if (strcmp(lexema, "%=") == 0) return "%";
    if (strcmp(lexema, "<<=") == 0) return "<<";
    if (strcmp(lexema, ">>=") == 0) return ">>";
    if (strcmp(lexema, "&=") == 0) return "&";
    if (strcmp(lexema, "^=") == 0) return "^";
    if (strcmp(lexema, "|=") == 0) return "|";
    return "?";
}

/* Reportar error semántico */
void sem_error(const char *msg) {
    fprintf(stderr, "Error semántico (pos %d): %s. ", atom_pos, msg);
    print_error_loc(atom_pos);
    sem_errors++;
}

/* Tablas/Impresión de tokens y tabla de símbolos */
void print_tables() {
    printf("\n=== TOKENS (%d) ===\n", n_tokens);
    for (int i=0;i<n_tokens;i++) {
        printf("%4d)\tclase=%d    valor='%s'\t lex='%s'\n",
               i, tokens[i].clase, tokens[i].valor, tokens[i].etm);
    }
}

/* Mostrar solo tabla de símbolos */
void print_symbol_table() {
    printf("\n=== TABLA DE SÍMBOLOS FINAL (%d) ===\n", n_idents);
    for (int i=0;i<n_idents;i++) {
        const char *tipo_str;
        switch(idents[i].tipo) {
            case TIPO_ENTERO: tipo_str = "entero"; break;
            case TIPO_FLOTANTE: tipo_str = "flotante"; break;
            case TIPO_CADENA: tipo_str = "cadena"; break;
            case TIPO_VACIO: tipo_str = "vacio"; break;
            default: tipo_str = "???";
        }
        printf("%4d) %-20s tipo: %s\n", i, idents[i].nombre, tipo_str);
    }

    printf("\n=== LITERALES CADENA (%d) ===\n", n_litstr);
    for (int i=0;i<n_litstr;i++)
        printf("%4d) \"%s\"\n", i, litstr[i]);

    printf("\n=== LITERALES REALES (%d) ===\n", n_litreal);
    for (int i=0;i<n_litreal;i++)
        printf("%4d) %s\n", i, litreal[i]);
}

/* ---------- convertidor token -> átomo char ---------- */
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
        if (lex && lex[0]) return lex[0];
    } else if (clase == C_OPARIT) {
        int code = atoi(valor);
        switch(code) {
            case 0: return '+'; case 1: return '-'; case 2: return '*';
            case 3: return '/'; case 4: return '¬'; case 5: return '%';
        }
    } else if (clase == C_OPASIG) {
        int code = atoi(valor);
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
        switch(code) {
            case 0: return 'g'; case 1: return '¿'; case 2: return 'z';
            case 3: return 'l'; case 4: return '!'; case 5: return 'n';
        }
    } else if (clase == C_OPLOG) {
        int code = atoi(valor);
        switch(code) {
            case 0: return '\\'; case 1: return 'b'; case 2: return '#';
        }
    }
    return '?';
}

/* Construye atoms[] a partir de tokens[] */
void build_atom_array() {
    if (n_tokens == 0) {
        atoms = strdup_safe("");
        atom_count = 0;
        return;
    }
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
void cuerpo(); void listaDec(); void sent_decl(); int tipo_fn();  /* Cambiado a retornar int */
void lista_id(int tipo); void resto_lista_id(int tipo); void asig_val(); void constante_fn();
void E(); void Eprime(); void T(); void Tprime(); void F(); void LlamaFunc();
void asig(); void opAsig_fn(); void expRel(); void opRel_fn(); void exprLog();
void exprV(); void opLog_fn(); void Sent_fn(); void props_fn(); void hacerM();
void condicion_fn(); void si_fn(); void finalsi(); void ocaso_fn(); void para_fn();
void expr_fn(); void salir_fn(); void valRet_fn(); void select_fn(); void siguiente_fn();
void listP_fn(); void Param_fn();

/* ------------------ Implementación de las funciones del parser --------------- */

/* Obtener tipo (retorna código de tipo) */
int tipo_fn() {
    char p = peek_atom();
    int tipo;
    switch(p) {
        case 'e': tipo = TIPO_ENTERO; break;
        case 'f': tipo = TIPO_FLOTANTE; break;
        case 'c': tipo = TIPO_CADENA; break;
        case 'v': tipo = TIPO_VACIO; break;
        default:
            syn_error("tipo (e/f/c/v esperado)");
            return TIPO_DESCONOCIDO;
    }
    advance_atom();
    return tipo;
}

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
        return;
    }
}

void Func() {
    int tipo = tipo_fn();
    if (tipo == TIPO_DESCONOCIDO) return;

    if (peek_atom()=='a') {
        int id_pos = atom_pos;  /* Guardar posición del token del identificador */
        advance_atom();

        /* Asignar tipo al identificador de función */
        int idx = atoi(tokens[id_pos].valor);
        asignar_tipo(idx, tipo);

        if (peek_atom()=='(') advance_atom(); else syn_error("'(' en Func");
        listArg();
        if (peek_atom()==')') advance_atom(); else syn_error("')' en Func");
        if (peek_atom()=='[') advance_atom(); else syn_error("'[' inicio cuerpo");
        cuerpo();
        if (peek_atom()==']') advance_atom(); else syn_error("']' fin cuerpo");
    } else {
        syn_error("Func (identificador 'a' esperado)");
    }
}

void listArg() {
    char p = peek_atom();
    if (p=='e' || p=='f' || p=='c' || p=='v') {
        int tipo = tipo_fn();
        if (tipo == TIPO_DESCONOCIDO) return;

        if (peek_atom()=='a') {
            int id_pos = atom_pos;
            advance_atom();
            /* Asignar tipo al argumento */
            int idx = atoi(tokens[id_pos].valor);
            asignar_tipo(idx, tipo);
            otroArg();
        } else syn_error("'a' en listArg");
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
        int tipo = tipo_fn();
        if (tipo == TIPO_DESCONOCIDO) return;

        if (peek_atom()=='a') {
            int id_pos = atom_pos;
            advance_atom();
            int idx = atoi(tokens[id_pos].valor);
            asignar_tipo(idx, tipo);
            otroArg();
        } else syn_error("'a' en otroArg");
    } else if (p==')') {
        return;
    } else {
        return;
    }
}

void cuerpo() {
    listaDec();
    props_fn();
}

void listaDec() {
    char p = peek_atom();
    if (p=='e' || p=='f' || p=='c' || p=='v') {
        sent_decl();
        listaDec();
    } else {
        return;
    }
}

void sent_decl() {
    int tipo = tipo_fn();
    if (tipo == TIPO_DESCONOCIDO) {
        syn_error("sent_decl (tipo inválido)");
        return;
    }
    lista_id(tipo);
    if (peek_atom()=='.') advance_atom(); else syn_error("'.' despues de declaracion");
}

/* lista_id ahora recibe el tipo como parámetro */
void lista_id(int tipo) {
    if (peek_atom()=='a') {
        int id_pos = atom_pos;
        advance_atom();
        /* Asignar tipo a este identificador */
        int idx = atoi(tokens[id_pos].valor);
        asignar_tipo(idx, tipo);

        asig_val();
        resto_lista_id(tipo);
    } else {
        syn_error("lista_id (se esperaba 'a')");
    }
}

/* resto_lista_id también recibe el tipo */
void resto_lista_id(int tipo) {
    char p = peek_atom();
    if (p==';') {
        advance_atom();
        lista_id(tipo);
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
    } else if (p=='¬') {
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
        /* Verificar que el identificador esté declarado */
        int id_pos = atom_pos;
        advance_atom();
        int idx = atoi(tokens[id_pos].valor);
        verificar_declarado(idx, id_pos);
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
        if (peek_atom()=='a') {
            int id_pos = atom_pos;
            advance_atom();
            int idx = atoi(tokens[id_pos].valor);
            verificar_declarado(idx, id_pos);
        } else syn_error("'a' despues de $ en llamada");
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
        int id_pos = atom_pos;      /* Posición del identificador */
        advance_atom();
        int op_pos = atom_pos;      /* Posición del operador */
        opAsig_fn();
        int inicio_expr = atom_pos; /* Inicio de la expresión */
        E();
        int fin_expr = atom_pos - 1; /* Fin de la expresión */
        if (peek_atom()=='.') advance_atom(); else syn_error("'.' al final de asignacion");

        /* Verificación semántica: ¿el identificador está declarado? */
        int idx = atoi(tokens[id_pos].valor);
        verificar_declarado(idx, id_pos);

        /* Si el operador es compuesto, mostrar traducción */
        Token op_token = tokens[op_pos];
        if (op_token.clase == C_OPASIG && atoi(op_token.valor) != 0) {
            traducir_asignacion_compuesta(id_pos, op_pos, inicio_expr, fin_expr);
        }
    } else {
        syn_error("asig (a esperado)");
    }
}

void opAsig_fn() {
    char p = peek_atom();
    if (p=='='||p=='d'||p=='j'||p=='u'||p=='¡'||p=='w'||p=='<'||p=='>'||p=='&'||p=='^'||p=='|') {
        advance_atom();
    } else {
        syn_error("operador asignacion (=, d, j, u, ¡, w, <, >, &, ^, |)");
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
    if (p == 'g' || p == '¿' || p == 'z' || p == 'l' || p == '!' || p == 'n') {
        advance_atom();
    } else syn_error("opRel (g,¿,z,l,!,n)");
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
        int id_pos = atom_pos;
        advance_atom();
        int op_pos = atom_pos;
        opAsig_fn();
        int inicio_expr = atom_pos;
        E();
        int fin_expr = atom_pos - 1;

        /* Verificación semántica */
        int idx = atoi(tokens[id_pos].valor);
        verificar_declarado(idx, id_pos);

        /* Traducción si es compuesto */
        Token op_token = tokens[op_pos];
        if (op_token.clase == C_OPASIG && atoi(op_token.valor) != 0) {
            traducir_asignacion_compuesta(id_pos, op_pos, inicio_expr, fin_expr);
        }
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
%option yylineno
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

.                           {
                                fprintf(stderr, "ERROR LÉXICO (línea %d): carácter no reconocido '%s'\n",
                                        yylineno, yytext);
                            }

%%

/* ---------- Driver del Parser / main ---------- */

void parse_driver() {
    /* construir atoms y lanzar parser */
    build_atom_array();
    atom_pos = 0;
    syntax_errors = 0;
    sem_errors = 0;

    printf("\n=== CADENA DE ATOMOS (length = %d) ===\n", atom_count);
    for (int i = 0; i < atom_count; ++i) printf("%c", atoms[i]);
    printf("\n\n=== INICIO ANALIZADOR SINTÁCTICO-SEMÁNTICO ===\n");

    Program();

    /* Mostrar tabla de símbolos final */
    print_symbol_table();

    if (syntax_errors == 0 && sem_errors == 0 && atom_pos >= atom_count) {
        printf("\nEl programa es sintácticamente CORRECTO y no tiene errores semánticos.\n");
    } else {
        printf("\nAnálisis finalizado con %d errores sintácticos y %d errores semánticos.\n",
               syntax_errors, sem_errors);
        printf("   Posición actual: %d, Total átomos: %d\n", atom_pos, atom_count);
    }
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr,"Uso: %s <archivo_fuente>\n", argv[0]);
        return 1;
    }
    FILE *f = fopen(argv[1],"r");
    if (!f) {
        perror("Error al abrir archivo fuente");
        return 1;
    }
    yyin = f;

    /* ejecutar lexer y llenar tablas */
    printf("======== INICIO DEL ANALIZADOR LÉXICO ========\n");
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