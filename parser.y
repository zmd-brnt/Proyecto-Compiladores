%{
/* Prologo C: tablas globales y funciones que usa el lexer */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_IDENTS 2000
#define MAX_LITS   2000
#define MAX_TOKS   10000
#define MAX_ATOMS  20000
#define MAX_TRAD   20000

/* Identificadores */
char *idents[MAX_IDENTS];
int ident_type[MAX_IDENTS]; /* 0=undef,1=entero,2=flotante,3=cadena,4=vacio */
int n_idents = 0;

/* Literales */
char *lit_real[MAX_LITS];
int n_real = 0;
char *lit_str[MAX_LITS];
int n_str = 0;

/* Tokens (rellenados por el lexer via add_token) */
typedef struct { char clase[32]; char valor[256]; } Tok;
Tok tok_table[MAX_TOKS];
int n_toks = 0;

/* Atomos (cadena) (rellenada por lexer via add_atom) */
char atoms[MAX_ATOMS];
int n_atoms = 0;

/* Traducciones (temporal) */
char trad_buf[MAX_TRAD];

/* funciones accesibles desde lexer (implementadas aquí) */
int add_ident(const char *s) {
    for (int i=0;i<n_idents;i++) if (strcmp(idents[i], s)==0) return i;
    if (n_idents >= MAX_IDENTS) { fprintf(stderr,"ERROR: demasiados idents\n"); exit(1); }
    idents[n_idents] = strdup(s);
    ident_type[n_idents] = 0;
    return n_idents++;
}
int add_litreal(const char *s) {
    if (n_real >= MAX_LITS) { fprintf(stderr,"ERROR: demasiados reales\n"); exit(1); }
    lit_real[n_real] = strdup(s);
    return n_real++;
}
int add_litstr(const char *s) {
    if (n_str >= MAX_LITS) { fprintf(stderr,"ERROR: demasiadas cadenas\n"); exit(1); }
    lit_str[n_str] = strdup(s);
    return n_str++;
}
void add_token(const char *c,const char *v) {
    if (n_toks >= MAX_TOKS) return;
    strncpy(tok_table[n_toks].clase, c, sizeof(tok_table[n_toks].clase)-1);
    strncpy(tok_table[n_toks].valor, v, sizeof(tok_table[n_toks].valor)-1);
    tok_table[n_toks].clase[sizeof(tok_table[n_toks].clase)-1]=0;
    tok_table[n_toks].valor[sizeof(tok_table[n_toks].valor)-1]=0;
    n_toks++;
}
void add_atom(char c) {
    if (n_atoms+2 >= MAX_ATOMS) return;
    atoms[n_atoms++] = c;
    atoms[n_atoms] = '\0';
}

/* utilidades para traducción */
void reset_trad() { trad_buf[0]=0; }
void emit(const char *s) { strncat(trad_buf, s, MAX_TRAD - strlen(trad_buf) - 1); }
void emit_char(char c) { int L=strlen(trad_buf); if (L+2<MAX_TRAD) { trad_buf[L]=c; trad_buf[L+1]=0; } }

/* impresión final */
void print_all() {
    printf("\n--- TOKENS (%d) ---\n", n_toks);
    for (int i=0;i<n_toks;i++) printf("%3d) %-10s : %s\n", i, tok_table[i].clase, tok_table[i].valor);

    printf("\n--- LITERALES REALES (%d) ---\n", n_real);
    for (int i=0;i<n_real;i++) printf("%3d) %s\n", i, lit_real[i]);

    printf("\n--- LITERALES CADENA (%d) ---\n", n_str);
    for (int i=0;i<n_str;i++) printf("%3d) %s\n", i, lit_str[i]);

    printf("\n--- CADENA DE ATOMOS (len=%d) ---\n%s\n", n_atoms, atoms);

    printf("\n--- IDENTIFICADORES (%d) ---\n", n_idents);
    for (int i=0;i<n_idents;i++){
        const char *t = "undef";
        if (ident_type[i]==1) t="entero";
        if (ident_type[i]==2) t="flotante";
        if (ident_type[i]==3) t="cadena";
        if (ident_type[i]==4) t="vacio";
        printf("%3d) %-20s : %s\n", i, idents[i], t);
    }
}

/* Prototipos Bison/Flex */
void yyerror(const char *s);
int yylex(void);
extern FILE *yyin;

/* tipo actual (para declaraciones) */
int current_type = 0;

/* helper para identificar operador aritmético por lexema OPARIT (lexema provisto por lexer en yylval.str) */
int op_is_add(const char *lex) {
    if (!lex) return 0;
    /* lexer uses lexemes like "¬+¬", "¬-¬", "¬*¬", etc. We check for presence of '+' or '-' in it */
    return (strchr(lex, '+') || strchr(lex, '-')) ? 1 : 0;
}
int op_is_mul(const char *lex) {
    if (!lex) return 0;
    return (strchr(lex, '*') || strchr(lex, '/') || strchr(lex, '%') || strchr(lex,'¬')) ? 1 : 0;
}

%}

/* union para valores semánticos */
%union {
    int idx;
    char *str;
}

/* tokens (coinciden con el lexer que me pasaste) */
%token ENTERO FLOTANTE CADENA VACIO
%token HACER MIENTRAS OCASO PARA PREDET SALIR SELECT SI CASO

%token <str> C_INT C_REAL C_CAD
%token <idx> C_ID
%token <str> OPASIG OPARIT OPREL OPLOG

/* no terminales con tipo string (representación textual de expresiones y listP) */
%type <str> E Eprime T Tprime F Expr LlamaFunc listP Param constante asig_val valRet
%type <str> listArg otroArg



%%

/* ----------------- Producciones (siguen exactamente tus reglas) ----------------- */

Program:
      Func otraFunc
    ;

otraFunc:
      Func otraFunc
    | /* epsilon */
    ;

Func:
      tipo C_ID '(' listArg ')' '[' cuerpo ']'
    ;

listArg:
      tipo C_ID otroArg {
            $$ = strdup("");
      }
    | /* epsilon */ { $$ = strdup(""); }
    ;


otroArg:
      ';' tipo C_ID otroArg {
            $$ = strdup("");
      }
    | /* epsilon */ { $$ = strdup(""); }
    ;


cuerpo:
      listaDec props
    ;

listaDec:
      /* epsilon */
    | sent_decl listaDec
    ;

sent_decl:
      tipo lista_id '.' { /* acciones hechas en lista_id */ }
    ;

tipo:
      ENTERO   { current_type = 1; }
    | FLOTANTE { current_type = 2; }
    | CADENA   { current_type = 3; }
    | VACIO    { current_type = 4; }
    ;

/* 17: lista-id -> a asig-val resto-lista-id */
lista_id:
      C_ID asig_val resto_lista_id
    {
        /* Asignamos tipo al identificador declarado */
        ident_type[$1] = current_type;
    }
    ;

resto_lista_id:
      ';' lista_id { }
    | /* epsilon */ { }
    ;

asig_val:
      '=' constante { }
    | /* epsilon */ { }
    ;

constante:
      C_INT  { $$ = strdup($1); }
    | C_REAL { $$ = strdup($1); }
    | C_CAD  { $$ = strdup($1); }
    ;

/* ---------------- EXPRESIONES (25-39): E -> T E' ; E' -> +T E' | -T E' | epsilon
   Implementado usando OPARIT token y filtrando por lexema dentro de las acciones. */

/* E => T E' where E' returns a suffix string (like " + right ...") */
E:
      T Eprime
      {
          if ($2 && strlen($2)>0) {
              int L = strlen($1) + 1 + strlen($2) + 1;
              char *s = malloc(L);
              snprintf(s, L, "%s%s", $1, $2);
              free($1); free($2);
              $$ = s;
          } else {
              $$ = $1;
          }
      }
    ;

/* E' produces suffix starting with " op right ...", or empty string */
Eprime:
      OPARIT T Eprime
      {
          /* only accept + or - here; OPARIT lexeme is in $1 */
          if (op_is_add($1)) {
              /* build suffix: " <op> <T> <rest>" */
              int L = strlen($1) + 1 + strlen($2) + 1 + strlen($3) + 3;
              char *suffix = malloc(L);
              snprintf(suffix, L, " %s %s%s", $1, $2, $3 ? $3 : "");
              /* free temporaries */
              free($2); if ($3) free($3);
              $$ = suffix;
          } else {
              /* operator not allowed in E' (e.g. *,/) -> treat as syntax error */
              yyerror("Operador aritmético no válido en E' (se esperaba + o -)");
              $$ = strdup("");
          }
      }
    | /* epsilon */ { $$ = strdup(""); }
    ;

/* T -> F T' */
T:
      F Tprime
      {
          if ($2 && strlen($2)>0) {
              int L = strlen($1) + 1 + strlen($2) + 1;
              char *s = malloc(L);
              snprintf(s, L, "%s%s", $1, $2);
              free($1); free($2);
              $$ = s;
          } else {
              $$ = $1;
          }
      }
    ;

/* T' processes multiplicative / power / mod / unary-¬ as suffix */
Tprime:
      OPARIT F Tprime
      {
          if (op_is_mul($1)) {
              int L = strlen($1) + 1 + strlen($2) + 1 + ( $3 ? strlen($3) : 0 ) + 4;
              char *suf = malloc(L);
              snprintf(suf, L, " %s %s%s", $1, $2, $3 ? $3 : "");
              free($2); if ($3) free($3);
              $$ = suf;
          } else {
              yyerror("Operador aritmético no válido en T' (se esperaba *, /, %, ¬)");
              $$ = strdup("");
          }
      }
    | /* epsilon */ { $$ = strdup(""); }
    ;

/* F: (E) | identifier | int | real | string | LlamaFunc */
F:
      '(' E ')'    { $$ = $2; }
    | C_ID         { $$ = strdup(idents[$1]); }
    | C_INT        { $$ = strdup($1); }
    | C_REAL       { $$ = strdup($1); }
    | C_CAD        { $$ = strdup($1); }
    | LlamaFunc    { $$ = $1; }
    ;

/* Expr is alias for E in some productions */
Expr:
      E { $$ = $1; }
    | F { $$ = $1; }
    ;

/* ---------------- ASIGNACIONES (41-52) ---------------- */
asig:
      C_ID OPASIG E '.'
    {
        /* generar traducción: id = id <op> expr . */
        reset_trad();
        emit(idents[$1]);
        emit(" = ");
        emit(idents[$1]);
        emit(" ");
        /* mapear lexema OPASIG a notación interna */
        if (strcmp($2,"*=")==0) emit("¬*¬ ");
        else if (strcmp($2,"/=")==0) emit("¬/¬ ");
        else if (strcmp($2,"+=")==0) emit("¬+¬ ");
        else if (strcmp($2,"-=")==0) emit("¬-¬ ");
        else if (strcmp($2,"%=")==0) emit("¬%¬ ");
        else if (strcmp($2,"=")==0) emit("= ");
        else {
            /* otros compuestos: mapear tal cual */
            emit($2); emit(" ");
        }
        if ($3) emit($3);
        emit(" .");
        printf("\nTRADUCCION: %s\n", trad_buf);
        /* liberar cadenas temporales */
        if ($3) free($3);
    }
    ;

/* ---------------- RELACIONALES / LOGICOS / SENTENCIAS ---------------- */

expRel:
      '[' E OPREL E ']' { /* nada por ahora */ }
    ;

exprLog:
      '#' '{' Expr '}'    { }
    | '{' expRel OPLOG expRel '}' { }
    ;

exprV:
      E
    | expRel
    ;

/* Sentencias (66-71) */
Sent:
      asig
    | HACER '{' props '}' MIENTRAS expRel '.'
    | SI condicion '{' props '}' finalsi
    | PARA '(' Expr ';' condicion ';' Expr ')' '{' props '}'
    | SALIR valRet '.'
    | SELECT '(' C_ID ')' '{' CASOS '}'
    ;

props:
      Sent props
    | /* epsilon */
    ;

condicion:
      expRel
    | exprLog
    ;

/* si / ocaso */
finalsi:
      /* epsilon */
    | OCASO '{' props '}'
    ;

/* casos / select */
CASOS:
      CASOS caso
    | caso
    | /* epsilon */
    ;

caso:
      CASO C_INT '{' props '}'
    | PREDET '{' props '}'
    ;

/* valRet: E | epsilon */
valRet:
      E { $$ = $1; }
    | /* epsilon */ { $$ = strdup(""); }
    ;

/* Llamada a función: $ a ( listP )  (producción 91) */
LlamaFunc:
      '$' C_ID '(' listP ')'
    {
        if ($4 && strlen($4) > 0) {
            int L = strlen(idents[$2]) + 3 + strlen($4) + 1;
            char *s = malloc(L);
            snprintf(s, L, "%s(%s)", idents[$2], $4);
            $$ = s;
            free($4);
        } else {
            int L = strlen(idents[$2]) + 4;
            char *s = malloc(L);
            snprintf(s, L, "%s()", idents[$2]);
            $$ = s;
        }
    }
    ;

/* listP -> epsilon | E Param */
listP:
      /* epsilon */ { $$ = strdup(""); }
    | E Param {
          if ($2 && strlen($2)>0) {
              int L = strlen($1) + 1 + strlen($2) + 2;
              char *s = malloc(L);
              snprintf(s, L, "%s;%s", $1, $2);
              free($1); free($2);
              $$ = s;
          } else $$ = $1;
      }
    ;

/* Param -> ; E Param | epsilon */
Param:
      ';' E Param {
          if ($3 && strlen($3)>0) {
              int L = strlen($2) + 1 + strlen($3) + 2;
              char *s = malloc(L);
              snprintf(s, L, "%s;%s", $2, $3);
              free($2); free($3);
              $$ = s;
          } else $$ = $2;
      }
    | /* epsilon */ { $$ = strdup(""); }
    ;

%%

/* ---------------- código auxiliar ---------------- */

void yyerror(const char *s) {
    fprintf(stderr, "Error sintáctico: %s\n", s);
}

/* al final del parse imprimimos las tablas y la cadena de átomos */
int main(int argc, char **argv) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) { perror("abrir archivo"); return 1; }
    }
    if (yyparse() == 0) {
        /* imprimir tablas y átomos (funciones definidas en el prólogo) */
        print_all();
        printf("\nParse terminado sin errores aparentes.\n");
    } else {
        fprintf(stderr, "Parse terminó con errores.\n");
    }
    return 0;
}
