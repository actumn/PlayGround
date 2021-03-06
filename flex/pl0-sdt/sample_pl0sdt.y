/*
	SDT Parser for PL0 Language
*/
%{
#include <stdio.h>
#include <string.h>
void yyerror(char*);
int yylex();

#define CONST 	0
#define VAR 	1
#define PROC 	2
#define IDENT 	3  /* CONST + VAR */
#define TBSIZE 100	// symbol table size
#define LVLmax 20		// max. level depth
#define HASHSIZE 17

// symbol table
struct {
	char name[20];
	int type;		/* 0-CONST	1-VARIABLE	2-PROCEDURE */
	int lvl;
	int offst;
    int link;
	} table[TBSIZE];
int block[LVLmax]; // Data for Set/Reset symbol table. level table.
int hashBucket[HASHSIZE] = { -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 };

int Hash(char *);
int Lookup(char *, int);
void Enter(char *, int, int, int);
void SetBlock();
void ResetBlock();
void DisplayTable();
void GenLab(char *);
void EmitLab(char *);
void Emit1(char *, int, int);
void Emit2(char *, int, char *);
void Emit3(char *, char *);
void Emit(char *);

int ln=1, cp=0;
int lev=0; 
int tx=0, level=0;
int LDiff=0, Lno=0, OFFSET=0;
char Lname[10];

%}

%union {
	char ident[50];	// id lvalue
	int number;	// num lvalue
	}
%token TCONST TVAR TPROC TCALL TBEGIN TIF TTHEN TWHILE TDO TEND ODD NE LE GE ASSIGN
%token <ident> ID 
%token <number> NUM
%type <number> Dcl VarDcl Ident_list ProcHead
%left '+' '-'
%left '*' '/'
%left UM

%%
Program: Block '.'  { Emit("END"); printf(" ==== valid syntax ====\n"); } 
		;
Block: // { GenLab(Lname); Emit3("JMP", strcpy($<ident>$, Lname)); } 
	Dcl // { EmitLab($<ident>1); Emit1("INT", 0, $2); } 
	Statement  { DisplayTable(); } 
	;
Dcl: ConstDcl VarDcl ProcDef_list 	{ $$=$2; } ;
ConstDcl:
	| TCONST Constdef_list ';' ;
Constdef_list: Constdef_list ',' ID '=' NUM 	{ Enter($3, CONST, level, $5); }
	| ID '=' NUM 	 { Enter($1, CONST, level, $3); }  
	;
VarDcl: TVAR Ident_list ';'	{ $$=$2; }
	|		{ $$=3; }  ;
Ident_list: Ident_list ',' ID	{ Enter($3, VAR, level, $1); $$=$1+1; }
	| ID 		{  Enter($1, VAR, level, 3); $$=4; }  
	;
ProcDef_list: ProcDef_list ProcDef
	| 	 ;
ProcDef: ProcHead	Block ';' 	{ Emit("RET"); ResetBlock(); }  
		;
ProcHead: TPROC ID ';' { Enter($2, PROC, level++, 0); EmitLab($2); SetBlock(); }  
		;
Statement: ID ASSIGN Expression  { if (Lookup($1, VAR)) Emit1("STO", LDiff, OFFSET); 
			      //  else /* error: undefined var */ ; 
                  }
	| TCALL ID		{ if (Lookup($2, PROC)) Emit2("CAL", LDiff, $2); 
			//  else   /* error: undefined proc */ ; 
            }
	| TBEGIN Statement_list TEND
	| TIF Condition 		{ 		 }
		TTHEN Statement	// { EmitLab($<ident>3); }
	| TWHILE 		{		}
		Condition 	{    		}
		TDO Statement 	{  		}
	|	;
Statement_list: Statement_list ';' Statement
	| Statement ;
Condition: ODD Expression		//	{ Emit("ODD"); }
	| Expression '=' Expression	//	{ Emit("EQ"); }
	| Expression NE Expression	//	{ Emit("NE"); }
	| Expression '<' Expression	//	{ Emit("LT"); }
	| Expression '>' Expression	//	{ Emit("GT"); }
	| Expression GE Expression	//	{ Emit("GE"); }
	| Expression LE Expression	//	{ Emit("LE"); }  
	;
Expression: Expression '+' Term	//	{ Emit("ADD"); }
	| Expression '-' Term	//	{ Emit("SUB"); }
	| '+' Term %prec UM
	| '-' Term %prec UM	//	{Emit("NEG"); }
	| Term ;
Term: Term '*' Factor		//	{ Emit("MUL"); }
	| Term '/' Factor		//	{ Emit("DIV"); }
	| Factor ;
Factor: ID		//	{ 			 }
	| NUM		//	{ Emit1("LIT", 0, $1); }
	| '(' Expression ')' ;
	
%%
#include "lex.yy.c"
void yyerror(char* s) {
	printf("line: %d cp: %d %s\n", ln, cp, s);
}

int Hash(char *name) {
    unsigned long hash = 5381;
    int c;

    while (c = *name++)
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */

    return hash % HASHSIZE;
}


int Lookup(char *name, int type) { 
    // search name from Symbol Table
    int hash = Hash(name);
    int target = hashBucket[hash];

    while (1) {
        if (strcmp(name, table[target].name) == 0) {
            break;
        }

        target = table[target].link;

        if (target == -1) {
            yyerror("cannot find the symbol");
            break;
        }
    }

    return target;
}
void Enter(char *name, int type, int lvl, int offst) {
    int hash = Hash(name);
    int link = hashBucket[hash];
    hashBucket[hash] = tx;

    strcpy(table[tx].name, name);
    table[tx].type = type;
    table[tx].lvl = lvl;
    table[tx].offst = offst;
    table[tx].link = link;

    tx += 1;
}

void SetBlock() {
	block[level++]=tx;
	printf("Setblock: level=%d,  tindex=%d\n", level, tx);
}
void ResetBlock() { 
	tx=block[--level];
    for (int i = 0; i < HASHSIZE; i++) {
        int index = hashBucket[i];
        while(index > tx) {
            index = table[index].link;
        }
    }
	printf("Resetblock: level=%d,  tindex=%d\n", level, tx);
}

void DisplayTable() { 
	printf("DisplayTable - SymbolTable line: %d cp: %d\n", ln, cp);
    printf("name	type	lvl	offst	link\n");
    int idx=tx;
	while (--idx>=0) { 
		printf("%s	%d	%d	%d	%d\n", 
            table[idx].name, table[idx].type, table[idx].lvl, table[idx].offst, table[idx].link);
	}
    printf("DisplayTable - HashBucket, collision-chain\n");
    for (int i = 0; i < HASHSIZE; i++) {
        int idx = hashBucket[i];
        printf("Hash	Index - %d	%d\n", i, idx);
        while (idx != -1) {
            printf("Chain	Hash %d - %s	%d	%d	%d	%d\n", 
                i, table[idx].name, table[idx].type, table[idx].lvl, table[idx].offst, table[idx].link);
            idx = table[idx].link;
        }
    }
}
void GenLab(char *label) {
	Lno++;
	sprintf(label, "LAB%d", Lno);
}
void EmitLab(char *label) {
	printf("%s\n", label);
}
void Emit1(char *code, int ld, int offst) {
	printf("	%s	%d	%d\n", code, ld, offst);
}
void Emit2(char *code, int ld, char *name) {
	printf("	%s	%d	%s\n", code, ld, name);
}
void Emit3(char *code, char *label) {
	printf("	%s	%s\n", code, label);
}
void Emit(char *code) {
	printf("	%s\n", code);
}

int main() {
	return yyparse();
}
