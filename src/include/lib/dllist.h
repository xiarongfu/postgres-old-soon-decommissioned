/*-------------------------------------------------------------------------
 *
 * dllist.h
 *		simple doubly linked list primitives
 *		the elements of the list are void* so the lists can contain
 *		anything
 *		Dlelem can only be in one list at a time
 *
 *
 *	 Here's a small example of how to use Dllist's :
 *
 *	 Dllist *lst;
 *	 Dlelem *elt;
 *	 void	*in_stuff;	  -- stuff to stick in the list
 *	 void	*out_stuff
 *
 *	 lst = DLNewList();				   -- make a new dllist
 *	 DLAddHead(lst, DLNewElem(in_stuff)); -- add a new element to the list
 *											 with in_stuff as the value
 *	  ...
 *	 elt = DLGetHead(lst);			   -- retrieve the head element
 *	 out_stuff = (void*)DLE_VAL(elt);  -- get the stuff out
 *	 DLRemove(elt);					   -- removes the element from its list
 *	 DLFreeElem(elt);				   -- free the element since we don't
 *										  use it anymore
 *
 * Portions Copyright (c) 1996-2000, PostgreSQL, Inc
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * $Id$
 *
 *-------------------------------------------------------------------------
 */

#ifndef DLLIST_H
#define DLLIST_H


struct Dllist;
struct Dlelem;

typedef struct Dlelem
{
	struct Dlelem *dle_next;	/* next element */
	struct Dlelem *dle_prev;	/* previous element */
	void	   *dle_val;		/* value of the element */
	struct Dllist *dle_list;	/* what list this element is in */
} Dlelem;

typedef struct Dllist
{
	Dlelem	   *dll_head;
	Dlelem	   *dll_tail;
} Dllist;

extern Dllist *DLNewList(void); /* initialize a new list */
extern void DLFreeList(Dllist *);		/* free up a list and all the
										 * nodes in it */
extern Dlelem *DLNewElem(void *val);
extern void DLFreeElem(Dlelem *);
extern Dlelem *DLGetHead(Dllist *);
extern Dlelem *DLGetTail(Dllist *);
extern Dlelem *DLRemTail(Dllist *l);
extern Dlelem *DLGetSucc(Dlelem *);		/* get successor */
extern void DLRemove(Dlelem *); /* removes node from list */
extern void DLAddHead(Dllist *list, Dlelem *node);
extern void DLAddTail(Dllist *list, Dlelem *node);
extern Dlelem *DLRemHead(Dllist *list); /* remove and return the head */
extern void DLMoveToFront(Dlelem *);	/* move node to front of its list */

#define DLE_VAL(x)	(x->dle_val)

#endif	 /* DLLIST_H */
