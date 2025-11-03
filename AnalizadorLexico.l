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

/* Fin del archivo fuente - main */
int main(int argc, char **argv) {
    FILE *g = fopen("errores.txt", "w");
    fclose(g);
    if (argc < 2) { fprintf(stderr, "Uso: %s <archivo_fuente>\n", argv[0]); return 1; }
    FILE *f = fopen(argv[1],"r");
    if (!f) { perror("fopen"); return 1; }
    yyin = f;
    yylex();
    fclose(f);
    return 0;
}
