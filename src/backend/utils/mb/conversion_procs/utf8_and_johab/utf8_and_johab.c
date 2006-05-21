/*-------------------------------------------------------------------------
 *
 *	  JOHAB <--> UTF8
 *
 * Portions Copyright (c) 1996-2005, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * IDENTIFICATION
 *	  $PostgreSQL$
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"
#include "fmgr.h"
#include "mb/pg_wchar.h"
#include "../../Unicode/johab_to_utf8.map"
#include "../../Unicode/utf8_to_johab.map"

PG_FUNCTION_INFO_V1(johab_to_utf8);
PG_FUNCTION_INFO_V1(utf8_to_johab);

extern Datum johab_to_utf8(PG_FUNCTION_ARGS);
extern Datum utf8_to_johab(PG_FUNCTION_ARGS);

/* ----------
 * conv_proc(
 *		INTEGER,	-- source encoding id
 *		INTEGER,	-- destination encoding id
 *		CSTRING,	-- source string (null terminated C string)
 *		CSTRING,	-- destination string (null terminated C string)
 *		INTEGER		-- source string length
 * ) returns VOID;
 * ----------
 */
Datum
johab_to_utf8(PG_FUNCTION_ARGS)
{
	unsigned char *src = (unsigned char *) PG_GETARG_CSTRING(2);
	unsigned char *dest = (unsigned char *) PG_GETARG_CSTRING(3);
	int			len = PG_GETARG_INT32(4);

	Assert(PG_GETARG_INT32(0) == PG_JOHAB);
	Assert(PG_GETARG_INT32(1) == PG_UTF8);
	Assert(len >= 0);

	LocalToUtf(src, dest, LUmapJOHAB,
			   sizeof(LUmapJOHAB) / sizeof(pg_local_to_utf), PG_JOHAB, len);

	PG_RETURN_VOID();
}

Datum
utf8_to_johab(PG_FUNCTION_ARGS)
{
	unsigned char *src = (unsigned char *) PG_GETARG_CSTRING(2);
	unsigned char *dest = (unsigned char *) PG_GETARG_CSTRING(3);
	int			len = PG_GETARG_INT32(4);

	Assert(PG_GETARG_INT32(0) == PG_UTF8);
	Assert(PG_GETARG_INT32(1) == PG_JOHAB);
	Assert(len >= 0);

	UtfToLocal(src, dest, ULmapJOHAB,
			   sizeof(ULmapJOHAB) / sizeof(pg_utf_to_local), PG_JOHAB, len);

	PG_RETURN_VOID();
}
