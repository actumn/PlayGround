#ifndef __MYAST_H__
#define __MYAST_H__
#include <stdio.h>
#include <stdlib.h>

typedef struct _myAst {
	int op;	// ������ ������ ���� +: 1, -: 2, *: 3, /: 4, ����:9
	int value;	// �͹̳��� ��� op = -1
	struct _myAst * left;	// �͹̳��� ��� NULL
	struct _myAst * right;
} myAstNode;

myAstNode * makeOperTree(myAstNode * left, int op, myAstNode * right);
myAstNode * makeNode(int value);
// myAstNode * addNonTerminal(int op, myAstNode * left);
void printTree(myAstNode * node, int depth);
int calculate(myAstNode * node);

extern myAstNode * root;
#endif
