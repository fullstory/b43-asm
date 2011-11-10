%{

/*
 *   Copyright (C) 2006-2010  Michael Buesch <m@bues.ch>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License version 2
 *   as published by the Free Software Foundation.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 */

#include "main.h"
#include "initvals.h"
#include "util.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>

extern char *yytext;
extern void yyerror(char *);
extern int yyparse(void);
extern int yylex(void);

static struct operand * store_oper_sanity(struct operand *oper);
static void assembler_assertion_failed(void);

/* The current .section */
extern int section;
/* Pointer to the current initvals section data structure. */
extern struct initvals_sect *cur_initvals_sect;

%}

%token SECTION_TEXT SECTION_IVALS

%token ASM_ARCH ASM_START ASM_ASSERT SPR GPR OFFR LR COMMA SEMICOLON BRACK_OPEN BRACK_CLOSE PAREN_OPEN PAREN_CLOSE HEXNUM DECNUM ARCH_NEWWORLD ARCH_OLDWORLD LABEL IDENT LABELREF

%token EQUAL NOT_EQUAL LOGICAL_OR LOGICAL_AND PLUS MINUS MULTIPLY DIVIDE BITW_OR BITW_AND BITW_XOR BITW_NOT LEFTSHIFT RIGHTSHIFT

%token OP_MUL OP_ADD OP_ADDSC OP_ADDC OP_ADDSCC OP_SUB OP_SUBSC OP_SUBC OP_SUBSCC OP_SRA OP_OR OP_AND OP_XOR OP_SR OP_SRX OP_SL OP_RL OP_RR OP_NAND OP_ORX OP_MOV OP_JMP OP_JAND OP_JNAND OP_JS OP_JNS OP_JE OP_JNE OP_JLS OP_JGES OP_JGS OP_JLES OP_JL OP_JGE OP_JG OP_JLE OP_JZX OP_JNZX OP_JEXT OP_JNEXT OP_JDN OP_JDPZ OP_JDP OP_JDNZ OP_CALL OP_CALLS OP_RET OP_RETS OP_TKIPH OP_TKIPHS OP_TKIPL OP_TKIPLS OP_NAP RAW_CODE

%token IVAL_MMIO16 IVAL_MMIO32 IVAL_PHY IVAL_RADIO IVAL_SHM16 IVAL_SHM32 IVAL_TRAM

%start line

%%

line	: line_terminator {
		/* empty */
	  }
	| line statement line_terminator {
		struct statement *s = $2;
		if (s) {
			if (section != SECTION_TEXT)
				yyerror("Microcode text instruction in non .text section");
			memcpy(&s->info, &cur_lineinfo, sizeof(struct lineinfo));
			list_add_tail(&s->list, &infile.sl);
		}
	  }
	| line section_switch line_terminator {
	  }
	| line ivals_write line_terminator {
		struct initval_op *io = $2;
		if (section != SECTION_IVALS)
			yyerror("InitVals write in non .initvals section");
		memcpy(&io->info, &cur_lineinfo, sizeof(struct lineinfo));
		INIT_LIST_HEAD(&io->list);
		list_add_tail(&io->list, &cur_initvals_sect->ops);
	  }
	;

/* Allow terminating lines with the ";" char */
line_terminator : /* Nothing */
		| SEMICOLON line_terminator
		;

section_switch	: SECTION_TEXT {
			section = SECTION_TEXT;
		  }
		| SECTION_IVALS PAREN_OPEN identifier PAREN_CLOSE {
			const char *sectname = $3;
			struct initvals_sect *s;
			cur_initvals_sect = NULL;
			/* Search if there already is a section by that name. */
			list_for_each_entry(s, &infile.ivals, list) {
				if (strcmp(sectname, s->name) == 0)
					cur_initvals_sect = s;
			}
			if (!cur_initvals_sect) {
				/* Not found, create a new one. */
				s = xmalloc(sizeof(struct initvals_sect));
				s->name = sectname;
				INIT_LIST_HEAD(&s->ops);
				INIT_LIST_HEAD(&s->list);
				list_add_tail(&s->list, &infile.ivals);
				cur_initvals_sect = s;
			}
			section = SECTION_IVALS;
		  }
		;

ivals_write	: IVAL_MMIO16 imm_value COMMA imm_value {
			struct initval_op *iop = xmalloc(sizeof(struct initval_op));
			iop->type = IVAL_W_MMIO16;
			iop->args[0] = (unsigned int)(unsigned long)$2;
			iop->args[1] = (unsigned int)(unsigned long)$4;
			$$ = iop;
		  }
		| IVAL_MMIO32 imm_value COMMA imm_value {
			struct initval_op *iop = xmalloc(sizeof(struct initval_op));
			iop->type = IVAL_W_MMIO32;
			iop->args[0] = (unsigned int)(unsigned long)$2;
			iop->args[1] = (unsigned int)(unsigned long)$4;
			$$ = iop;
		  }
		| IVAL_PHY imm_value COMMA imm_value {
			struct initval_op *iop = xmalloc(sizeof(struct initval_op));
			iop->type = IVAL_W_PHY;
			iop->args[0] = (unsigned int)(unsigned long)$2;
			iop->args[1] = (unsigned int)(unsigned long)$4;
			$$ = iop;
		  }
		| IVAL_RADIO imm_value COMMA imm_value {
			struct initval_op *iop = xmalloc(sizeof(struct initval_op));
			iop->type = IVAL_W_RADIO;
			iop->args[0] = (unsigned int)(unsigned long)$2;
			iop->args[1] = (unsigned int)(unsigned long)$4;
			$$ = iop;
		  }
		| IVAL_SHM16 imm_value COMMA imm_value COMMA imm_value {
			struct initval_op *iop = xmalloc(sizeof(struct initval_op));
			iop->type = IVAL_W_SHM16;
			iop->args[0] = (unsigned int)(unsigned long)$2;
			iop->args[1] = (unsigned int)(unsigned long)$4;
			iop->args[2] = (unsigned int)(unsigned long)$6;
			$$ = iop;
		  }
		| IVAL_SHM32 imm_value COMMA imm_value COMMA imm_value {
			struct initval_op *iop = xmalloc(sizeof(struct initval_op));
			iop->type = IVAL_W_SHM32;
			iop->args[0] = (unsigned int)(unsigned long)$2;
			iop->args[1] = (unsigned int)(unsigned long)$4;
			iop->args[2] = (unsigned int)(unsigned long)$6;
			$$ = iop;
		  }
		| IVAL_TRAM imm_value COMMA imm_value {
			struct initval_op *iop = xmalloc(sizeof(struct initval_op));
			iop->type = IVAL_W_TRAM;
			iop->args[0] = (unsigned int)(unsigned long)$2;
			iop->args[1] = (unsigned int)(unsigned long)$4;
			$$ = iop;
		  }
		;

statement	: asmdir {
			struct asmdir *ad = $1;
			if (ad) {
				struct statement *s = xmalloc(sizeof(struct statement));
				INIT_LIST_HEAD(&s->list);
				s->type = STMT_ASMDIR;
				s->u.asmdir = $1;
				$$ = s;
			} else
				$$ = NULL;
		  }
		| label {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_LABEL;
			s->u.label = $1;
			$$ = s;
		  }
		| insn_mul {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_add {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_addsc {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_addc {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_addscc {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_sub {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_subsc {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_subc {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_subscc {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_sra {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_or {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_and {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_xor {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_sr {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_srx {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_sl {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_rl {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_rr {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_nand {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_orx {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_mov {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jmp {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jand {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jnand {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_js {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jns {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_je {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jne {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jls {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jges {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jgs {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jles {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jdn {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jdpz {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jdp {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jdnz {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jl {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jge {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jg {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jle {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jzx {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jnzx {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jext {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_jnext {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_call {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_calls {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_ret {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_rets {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_tkiph {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_tkiphs {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_tkipl {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_tkipls {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_nap {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		| insn_raw {
			struct statement *s = xmalloc(sizeof(struct statement));
			INIT_LIST_HEAD(&s->list);
			s->type = STMT_INSN;
			s->u.insn = $1;
			$$ = s;
		  }
		;

/* ASM directives */
asmdir		: ASM_ARCH hexnum_decnum {
			struct asmdir *ad = xmalloc(sizeof(struct asmdir));
			ad->type = ADIR_ARCH;
			ad->u.arch = (unsigned int)(unsigned long)$2;
			$$ = ad;
		  }
		| ASM_START identifier {
			struct asmdir *ad = xmalloc(sizeof(struct asmdir));
			struct label *label = xmalloc(sizeof(struct label));
			label->name = $2;
			label->direction = LABELREF_ABSOLUTE;
			ad->type = ADIR_START;
			ad->u.start = label;
			$$ = ad;
		  }
		| asm_assert {
			$$ = NULL;
		  }
		;

asm_assert	: ASM_ASSERT assertion {
			unsigned int ok = (unsigned int)(unsigned long)$2;
			if (!ok)
				assembler_assertion_failed();
			$$ = NULL;
		  }
		;

assertion	: PAREN_OPEN assert_expr PAREN_CLOSE {
			$$ = $2;
		  }
		| PAREN_OPEN assertion LOGICAL_OR assertion PAREN_CLOSE {
			unsigned int a = (unsigned int)(unsigned long)$2;
			unsigned int b = (unsigned int)(unsigned long)$4;
			unsigned int result = (a || b);
			$$ = (void *)(unsigned long)result;
		  }
		| PAREN_OPEN assertion LOGICAL_AND assertion PAREN_CLOSE {
			unsigned int a = (unsigned int)(unsigned long)$2;
			unsigned int b = (unsigned int)(unsigned long)$4;
			unsigned int result = (a && b);
			$$ = (void *)(unsigned long)result;
		  }
		;

assert_expr	: imm_value EQUAL imm_value {
			unsigned int a = (unsigned int)(unsigned long)$1;
			unsigned int b = (unsigned int)(unsigned long)$3;
			unsigned int result = (a == b);
			$$ = (void *)(unsigned long)result;
		  }
		| imm_value NOT_EQUAL imm_value {
			unsigned int a = (unsigned int)(unsigned long)$1;
			unsigned int b = (unsigned int)(unsigned long)$3;
			unsigned int result = (a != b);
			$$ = (void *)(unsigned long)result;
		  }
		;

label		: LABEL {
			struct label *label = xmalloc(sizeof(struct label));
			char *l;
			l = xstrdup(yytext);
			l[strlen(l) - 1] = '\0';
			label->name = l;
			$$ = label;
		  }
		;

/* multiply */
insn_mul	: OP_MUL operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_MUL;
			insn->operands = $2;
			$$ = insn;
		  }
		;

/* add */
insn_add	: OP_ADD operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_ADD;
			insn->operands = $2;
			$$ = insn;
		  }
		;

/* add. */
insn_addsc	: OP_ADDSC operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_ADDSC;
			insn->operands = $2;
			$$ = insn;
		  }
		;

/* addc */
insn_addc	: OP_ADDC operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_ADDC;
			insn->operands = $2;
			$$ = insn;
		  }
		;

/* addc. */
insn_addscc	: OP_ADDSCC operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_ADDSCC;
			insn->operands = $2;
			$$ = insn;
		  }
		;

/* sub */
insn_sub	: OP_SUB operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_SUB;
			insn->operands = $2;
			$$ = insn;
		  }
		;

/* sub. */
insn_subsc	: OP_SUBSC operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_SUBSC;
			insn->operands = $2;
			$$ = insn;
		  }
		;

/* subc */
insn_subc	: OP_SUBC operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_SUBC;
			insn->operands = $2;
			$$ = insn;
		  }
		;

/* subc. */
insn_subscc	: OP_SUBSCC operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_SUBSCC;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_sra	: OP_SRA operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_SRA;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_or		: OP_OR operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_OR;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_and	: OP_AND operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_AND;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_xor	: OP_XOR operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_XOR;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_sr		: OP_SR operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_SR;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_srx	: OP_SRX extended_operlist {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_SRX;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_sl		: OP_SL operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_SL;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_rl		: OP_RL operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_RL;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_rr		: OP_RR operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_RR;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_nand	: OP_NAND operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_NAND;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_orx	: OP_ORX extended_operlist {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_ORX;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_mov	: OP_MOV operlist_2 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_MOV;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jmp	: OP_JMP labelref {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			struct operlist *ol = xmalloc(sizeof(struct operlist));
			ol->oper[0] = $2;
			insn->op = OP_JMP;
			insn->operands = ol;
			$$ = insn;
		  }
		;

insn_jand	: OP_JAND operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JAND;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jnand	: OP_JNAND operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JNAND;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_js		: OP_JS operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JS;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jns	: OP_JNS operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JNS;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_je		: OP_JE operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JE;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jne	: OP_JNE operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JNE;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jls	: OP_JLS operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JLS;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jges	: OP_JGES operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JGES;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jgs	: OP_JGS operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JGS;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jles	: OP_JLES operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JLES;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jl		: OP_JL operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JL;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jge	: OP_JGE operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JGE;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jg		: OP_JG operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JG;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jle	: OP_JLE operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JLE;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jzx	: OP_JZX extended_operlist {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JZX;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jnzx	: OP_JNZX extended_operlist {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JNZX;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jdn	: OP_JDN operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JDN;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jdpz	: OP_JDPZ operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JDPZ;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jdp	: OP_JDP operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JDP;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jdnz	: OP_JDNZ operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JDNZ;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jext	: OP_JEXT external_jump_operands {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JEXT;
			insn->operands = $2;
			$$ = insn;
		  }
		;

insn_jnext	: OP_JNEXT external_jump_operands {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = OP_JNEXT;
			insn->operands = $2;
			$$ = insn;
		  }
		;

linkreg		: LR regnr {
			$$ = $2;
		  }
		;

insn_call	: OP_CALL linkreg COMMA labelref {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			struct operlist *ol = xmalloc(sizeof(struct operlist));
			struct operand *oper_lr = xmalloc(sizeof(struct operand));
			struct operand *oper_zero = xmalloc(sizeof(struct operand));
			oper_zero->type = OPER_RAW;
			oper_zero->u.raw = 0;
			oper_lr->type = OPER_RAW;
			oper_lr->u.raw = (unsigned long)$2;
			ol->oper[0] = oper_lr;
			ol->oper[1] = oper_zero;
			ol->oper[2] = $4;
			insn->op = OP_CALL;
			insn->operands = ol;
			$$ = insn;
		  }
		;

insn_calls	:  OP_CALLS labelref {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			struct operlist *ol = xmalloc(sizeof(struct operlist));
			struct operand *oper_r0 = xmalloc(sizeof(struct operand));
			struct registr *r0 = xmalloc(sizeof(struct registr));
			r0->type = GPR;
			r0->nr = 0;
			oper_r0->type = OPER_REG;
			oper_r0->u.reg = r0;
			ol->oper[0] = oper_r0;
			ol->oper[1] = oper_r0;
			ol->oper[2] = $2;
			insn->op = OP_CALLS;
			insn->operands = ol;
			$$ = insn;
		  }
		;

insn_ret	: OP_RET linkreg COMMA linkreg {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			struct operlist *ol = xmalloc(sizeof(struct operlist));
			struct operand *oper_lr0 = xmalloc(sizeof(struct operand));
			struct operand *oper_lr1 = xmalloc(sizeof(struct operand));
			struct operand *oper_zero = xmalloc(sizeof(struct operand));
			oper_zero->type = OPER_RAW;
			oper_zero->u.raw = 0;
			oper_lr0->type = OPER_RAW;
			oper_lr0->u.raw = (unsigned long)$2;
			oper_lr1->type = OPER_RAW;
			oper_lr1->u.raw = (unsigned long)$4;
			ol->oper[0] = oper_lr0;
			ol->oper[1] = oper_zero;
			ol->oper[2] = oper_lr1;
			insn->op = OP_RET;
			insn->operands = ol;
			$$ = insn;
		  }
		;

insn_rets	: OP_RETS {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			struct operlist *ol = xmalloc(sizeof(struct operlist));
			struct operand *oper_r0 = xmalloc(sizeof(struct operand));
			struct operand *oper_zero = xmalloc(sizeof(struct operand));
			struct registr *r0 = xmalloc(sizeof(struct registr));
			oper_zero->type = OPER_RAW;
			oper_zero->u.raw = 0;
			r0->type = GPR;
			r0->nr = 0;
			oper_r0->type = OPER_REG;
			oper_r0->u.reg = r0;
			ol->oper[0] = oper_r0;
			ol->oper[1] = oper_r0;
			ol->oper[2] = oper_zero;
			insn->op = OP_RETS;
			insn->operands = ol;
			$$ = insn;
		  }
		;

insn_tkiph	: OP_TKIPH operlist_2 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			struct operlist *ol = $2;
			struct operand *flags = xmalloc(sizeof(struct operand));
			struct immediate *imm = xmalloc(sizeof(struct immediate));
			imm->imm = 0x1;
			flags->type = OPER_IMM;
			flags->u.imm = imm;
			ol->oper[2] = ol->oper[1];
			ol->oper[1] = flags;
			insn->op = OP_TKIPH;
			insn->operands = ol;
			$$ = insn;
		  }
		;

insn_tkiphs	: OP_TKIPHS operlist_2 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			struct operlist *ol = $2;
			struct operand *flags = xmalloc(sizeof(struct operand));
			struct immediate *imm = xmalloc(sizeof(struct immediate));
			imm->imm = 0x1 | 0x2;
			flags->type = OPER_IMM;
			flags->u.imm = imm;
			ol->oper[2] = ol->oper[1];
			ol->oper[1] = flags;
			insn->op = OP_TKIPH;
			insn->operands = ol;
			$$ = insn;
		  }
		;

insn_tkipl	: OP_TKIPL operlist_2 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			struct operlist *ol = $2;
			struct operand *flags = xmalloc(sizeof(struct operand));
			struct immediate *imm = xmalloc(sizeof(struct immediate));
			imm->imm = 0x0;
			flags->type = OPER_IMM;
			flags->u.imm = imm;
			ol->oper[2] = ol->oper[1];
			ol->oper[1] = flags;
			insn->op = OP_TKIPH;
			insn->operands = ol;
			$$ = insn;
		  }
		;

insn_tkipls	: OP_TKIPLS operlist_2 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			struct operlist *ol = $2;
			struct operand *flags = xmalloc(sizeof(struct operand));
			struct immediate *imm = xmalloc(sizeof(struct immediate));
			imm->imm = 0x0 | 0x2;
			flags->type = OPER_IMM;
			flags->u.imm = imm;
			ol->oper[2] = ol->oper[1];
			ol->oper[1] = flags;
			insn->op = OP_TKIPH;
			insn->operands = ol;
			$$ = insn;
		  }
		;

insn_nap	: OP_NAP {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			struct operlist *ol = xmalloc(sizeof(struct operlist));
			struct operand *regop = xmalloc(sizeof(struct operand));
			struct operand *zeroop = xmalloc(sizeof(struct operand));
			struct registr *r0 = xmalloc(sizeof(struct registr));
			r0->type = GPR;
			r0->nr = 0;
			regop->type = OPER_REG;
			regop->u.reg = r0;
			zeroop->type = OPER_RAW;
			zeroop->u.raw = 0x000;
			ol->oper[0] = regop;
			ol->oper[1] = regop;
			ol->oper[2] = zeroop;
			insn->op = OP_NAP;
			insn->operands = ol;
			$$ = insn;
		  }
		;

insn_raw	: raw_code operlist_3 {
			struct instruction *insn = xmalloc(sizeof(struct instruction));
			insn->op = RAW_CODE;
			insn->operands = $2;
			insn->opcode = (unsigned long)$1;
			$$ = insn;
		  }
		;

raw_code	: RAW_CODE {
			yytext++; /* skip @ */
			$$ = (void *)(unsigned long)strtoul(yytext, NULL, 16);
		  }
		;

extended_operlist : imm_value COMMA imm_value COMMA operand COMMA operand COMMA operand {
			struct operlist *ol = xmalloc(sizeof(struct operlist));
			struct operand *mask_oper = xmalloc(sizeof(struct operand));
			struct operand *shift_oper = xmalloc(sizeof(struct operand));
			mask_oper->type = OPER_RAW;
			mask_oper->u.raw = (unsigned long)$1;
			shift_oper->type = OPER_RAW;
			shift_oper->u.raw = (unsigned long)$3;
			ol->oper[0] = mask_oper;
			ol->oper[1] = shift_oper;
			ol->oper[2] = $5;
			ol->oper[3] = $7;
			ol->oper[4] = store_oper_sanity($9);
			$$ = ol;
		  }
		;

external_jump_operands : imm COMMA labelref {
			struct operlist *ol = xmalloc(sizeof(struct operlist));
			struct operand *cond = xmalloc(sizeof(struct operand));
			cond->type = OPER_IMM;
			cond->u.imm = $1;
			ol->oper[0] = cond;
			ol->oper[1] = $3;
			$$ = ol;
		  }
		;

operlist_2	: operand COMMA operand {
			struct operlist *ol = xmalloc(sizeof(struct operlist));
			ol->oper[0] = $1;
			ol->oper[1] = store_oper_sanity($3);
			$$ = ol;
		  }
		;

operlist_3	: operand COMMA operand COMMA operand {
			struct operlist *ol = xmalloc(sizeof(struct operlist));
			ol->oper[0] = $1;
			ol->oper[1] = $3;
			ol->oper[2] = store_oper_sanity($5);
			$$ = ol;
		  }
		;

operand		: reg {
			struct operand *oper = xmalloc(sizeof(struct operand));
			oper->type = OPER_REG;
			oper->u.reg = $1;
			$$ = oper;
		  }
		| mem {
			struct operand *oper = xmalloc(sizeof(struct operand));
			oper->type = OPER_MEM;
			oper->u.mem = $1;
			$$ = oper;
		  }
		| raw_code {
			struct operand *oper = xmalloc(sizeof(struct operand));
			oper->type = OPER_RAW;
			oper->u.raw = (unsigned long)$1;
			$$ = oper;
		  }
		| imm {
			struct operand *oper = xmalloc(sizeof(struct operand));
			oper->type = OPER_IMM;
			oper->u.imm = $1;
			$$ = oper;
		  }
		| labelref {
			$$ = $1;
		  }
		;

reg		: GPR regnr {
			struct registr *reg = xmalloc(sizeof(struct registr));
			reg->type = GPR;
			reg->nr = (unsigned long)$2;
			$$ = reg;
		  }
		| SPR {
			struct registr *reg = xmalloc(sizeof(struct registr));
			reg->type = SPR;
			yytext += 3; /* skip "spr" */
			reg->nr = strtoul(yytext, NULL, 16);
			$$ = reg;
		  }
		| OFFR regnr {
			struct registr *reg = xmalloc(sizeof(struct registr));
			reg->type = OFFR;
			reg->nr = (unsigned long)$2;
			$$ = reg;
		  }
		;

mem		: BRACK_OPEN imm BRACK_CLOSE {
			struct memory *mem = xmalloc(sizeof(struct memory));
			struct immediate *offset_imm = $2;
			mem->type = MEM_DIRECT;
			mem->offset = offset_imm->imm;
			free(offset_imm);
			$$ = mem;
		  }
		| BRACK_OPEN imm COMMA OFFR regnr BRACK_CLOSE {
			struct memory *mem = xmalloc(sizeof(struct memory));
			struct immediate *offset_imm = $2;
			mem->type = MEM_INDIRECT;
			mem->offset = offset_imm->imm;
			free(offset_imm);
			mem->offr_nr = (unsigned long)$5;
			$$ = mem;
		  }
		;

imm		: imm_value {
			struct immediate *imm = xmalloc(sizeof(struct immediate));
			imm->imm = (unsigned long)$1;
			$$ = imm;
		  }
		;

imm_value	: hexnum_decnum {
			$$ = $1;
		  }
		| complex_imm {
			$$ = $1;
		  }
		;

complex_imm	: PAREN_OPEN complex_imm_arg complex_imm_oper complex_imm_arg PAREN_CLOSE {
			unsigned long a = (unsigned long)$2;
			unsigned long b = (unsigned long)$4;
			unsigned long operation = (unsigned long)$3;
			unsigned long res = 31337;
			switch (operation) {
			case PLUS:
				res = a + b;
				break;
			case MINUS:
				res = a - b;
				break;
			case MULTIPLY:
				res = a * b;
				break;
			case DIVIDE:
				res = a / b;
				break;
			case BITW_OR:
				res = a | b;
				break;
			case BITW_AND:
				res = a & b;
				break;
			case BITW_XOR:
				res = a ^ b;
				break;
			case LEFTSHIFT:
				res = a << b;
				break;
			case RIGHTSHIFT:
				res = a >> b;
				break;
			default:
				yyerror("Internal parser BUG. complex_imm oper unknown");
			}
			$$ = (void *)res;
		  }
		| PAREN_OPEN complex_imm PAREN_CLOSE {
			$$ = $2;
		  }
		| PAREN_OPEN asm_assert PAREN_CLOSE {
			/* Inline assertion. Always return zero */
			$$ = (void *)(unsigned long)(unsigned int)0;
		  }
		| PAREN_OPEN BITW_NOT complex_imm PAREN_CLOSE {
			unsigned long n = (unsigned long)$3;
			n = ~n;
			$$ = (void *)n;
		  }
		| PAREN_OPEN complex_imm_const PAREN_CLOSE {
			$$ = $2;
		  }
		;

complex_imm_oper : PLUS {
			$$ = (void *)(unsigned long)PLUS;
		  }
		| MINUS {
			$$ = (void *)(unsigned long)MINUS;
		  }
		| MULTIPLY {
			$$ = (void *)(unsigned long)MULTIPLY;
		  }
		| DIVIDE {
			$$ = (void *)(unsigned long)DIVIDE;
		  }
		| BITW_OR {
			$$ = (void *)(unsigned long)BITW_OR;
		  }
		| BITW_AND {
			$$ = (void *)(unsigned long)BITW_AND;
		  }
		| BITW_XOR {
			$$ = (void *)(unsigned long)BITW_XOR;
		  }
		| LEFTSHIFT {
			$$ = (void *)(unsigned long)LEFTSHIFT;
		  }
		| RIGHTSHIFT {
			$$ = (void *)(unsigned long)RIGHTSHIFT;
		  }
		;

complex_imm_arg	: complex_imm_const {
			$$ = $1;
		  }
		| complex_imm {
			$$ = $1;
		  }
		;

complex_imm_const : hexnum_decnum {
			$$ = $1;
		  }
		| BITW_NOT hexnum_decnum {
			unsigned long n = (unsigned long)$2;
			n = ~n;
			$$ = (void *)n;
		  }
		;

hexnum		: HEXNUM {
			while (yytext[0] != 'x') {
				if (yytext[0] == '\0')
					yyerror("Internal HEXNUM parser error");
				yytext++;
			}
			yytext++;
			$$ = (void *)(unsigned long)strtoul(yytext, NULL, 16);
		  }
		;

decnum		: DECNUM {
			$$ = (void *)(unsigned long)strtol(yytext, NULL, 10);
		  }
		;

hexnum_decnum	: hexnum {
			$$ = $1;
		  }
		| decnum {
			$$ = $1;
		  }
		;

labelref	: identifier {
			struct operand *oper = xmalloc(sizeof(struct operand));
			struct label *label = xmalloc(sizeof(struct label));
			label->name = $1;
			label->direction = LABELREF_ABSOLUTE;
			oper->type = OPER_LABEL;
			oper->u.label = label;
			$$ = oper;
		  }
		| identifier MINUS {
			struct operand *oper = xmalloc(sizeof(struct operand));
			struct label *label = xmalloc(sizeof(struct label));
			label->name = $1;
			label->direction = LABELREF_RELATIVE_BACK;
			oper->type = OPER_LABEL;
			oper->u.label = label;
			$$ = oper;
		  }
		| identifier PLUS {
			struct operand *oper = xmalloc(sizeof(struct operand));
			struct label *label = xmalloc(sizeof(struct label));
			label->name = $1;
			label->direction = LABELREF_RELATIVE_FORWARD;
			oper->type = OPER_LABEL;
			oper->u.label = label;
			$$ = oper;
		  }
		;

regnr		: DECNUM {
			$$ = (void *)(unsigned long)strtoul(yytext, NULL, 10);
		  }
		;

identifier	: IDENT {
			$$ = xstrdup(yytext);
		  }
		;

%%

int section = SECTION_TEXT; /* default to .text section */
struct initvals_sect *cur_initvals_sect;

void yyerror(char *str)
{
	unsigned int i;

	fprintf(stderr,
		"Parser ERROR (file \"%s\", line %u, col %u):\n",
		cur_lineinfo.file,
		cur_lineinfo.lineno,
		cur_lineinfo.column);
	fprintf(stderr, "%s\n", cur_lineinfo.linecopy);
	for (i = 0; i < cur_lineinfo.column - 1; i++)
		fprintf(stderr, " ");
	fprintf(stderr, "^\n");
	fprintf(stderr, "%s\n", str);
	exit(1);
}

static struct operand * store_oper_sanity(struct operand *oper)
{
	if (oper->type == OPER_IMM &&
	    oper->u.imm->imm != 0) {
		yyerror("Only 0x000 Immediate is allowed for "
			"Output operands");
	}
	return oper;
}

static void assembler_assertion_failed(void)
{
	yyerror("Assembler %assert failed");
}
