/*-------------------------------------------------------------------------
 *
 * var.h
 *	  prototypes for var.c.
 *
 *
 * Portions Copyright (c) 1996-2001, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * $Id$
 *
 *-------------------------------------------------------------------------
 */
#ifndef VAR_H
#define VAR_H

#include "nodes/parsenodes.h"


extern List *pull_varnos(Node *node);
extern bool contain_var_reference(Node *node, int varno, int varattno,
					  int levelsup);
extern bool contain_whole_tuple_var(Node *node, int varno, int levelsup);
extern bool contain_var_clause(Node *node);
extern List *pull_var_clause(Node *node, bool includeUpperVars);
extern Node *flatten_join_alias_vars(Node *node, Query *root, int expandRTI);
extern void build_join_alias_subvars(Query *root, Var *aliasvar,
									 Var **leftsubvar, Var **rightsubvar);

#endif   /* VAR_H */
