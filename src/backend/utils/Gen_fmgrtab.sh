#! /bin/sh
#-------------------------------------------------------------------------
#
# Gen_fmgrtab.sh
#    shell script to generate fmgroids.h and fmgrtab.c from pg_proc.h
#
# Portions Copyright (c) 1996-2002, PostgreSQL Global Development Group
# Portions Copyright (c) 1994, Regents of the University of California
#
#
# IDENTIFICATION
#    $Header$
#
#-------------------------------------------------------------------------

CMDNAME=`basename $0`

: ${AWK='awk'}
: ${CPP='cc -E'}

cleanup(){
    [ x"$noclean" != x"t" ] && rm -f "$CPPTMPFILE" "$RAWFILE" "$$-$OIDSFILE" "$$-$TABLEFILE"
}

BKIOPTS=
noclean=

#
# Process command line switches.
#
while [ $# -gt 0 ]
do
    case $1 in
	-D)
            BKIOPTS="$BKIOPTS -D$2"
            shift;;
	-D*)
            BKIOPTS="$BKIOPTS $1"
            ;;
        --noclean)
            noclean=t
            ;;
        --help)
            echo "$CMDNAME generates fmgroids.h and fmgrtab.c from pg_proc.h."
            echo
            echo "Usage:"
            echo "  $CMDNAME [ -D define [...] ]"
            echo
            echo "The environment variables CPP and AWK determine which C"
            echo "preprocessor and Awk program to use. The defaults are"
            echo "\`cc -E' and \`awk'."
            echo
            echo "Report bugs to <pgsql-bugs@postgresql.org>."
            exit 0
            ;;
	--) shift; break;;
	-*)
            echo "$CMDNAME: invalid option: $1"
            exit 1
            ;;
        *)
            INFILE=$1
            ;;
    esac
    shift
done


if [ x"$INFILE" = x ] ; then
    echo "$CMDNAME: no input file"
    exit 1
fi

CPPTMPFILE="$$-fmgrtmp.c"
RAWFILE="$$-fmgr.raw"
OIDSFILE=fmgroids.h
TABLEFILE=fmgrtab.c


trap 'echo "Caught signal." ; cleanup ; exit 1' 1 2 15


#
# Generate the file containing raw pg_proc tuple data
# (but only for "internal" language procedures...).
#
# Unlike genbki.sh, which can run through cpp last, we have to
# deal with preprocessor statements first (before we sort the
# function table by oid).
#
# Note assumption here that prolang == $5 and INTERNALlanguageId == 12.
#
$AWK '
BEGIN		{ raw = 0; }
/^DATA/		{ print; next; }
/^BKI_BEGIN/	{ raw = 1; next; }
/^BKI_END/	{ raw = 0; next; }
raw == 1	{ print; next; }' $INFILE | \
sed 	-e 's/^.*OID[^=]*=[^0-9]*//' \
	-e 's/(//g' \
	-e 's/[ 	]*).*$//' | \
$AWK '
/^#/		{ print; next; }
$5 == "12"	{ print; next; }' > $CPPTMPFILE

if [ $? -ne 0 ]; then
    cleanup
    echo "$CMDNAME failed"
    exit 1
fi

$CPP $BKIOPTS $CPPTMPFILE | \
egrep '^[ ]*[0-9]' | \
sort -n > $RAWFILE

if [ $? -ne 0 ]; then
    cleanup
    echo "$CMDNAME failed"
    exit 1
fi


cpp_define=`echo $OIDSFILE | tr abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ | sed -e 's/[^A-Z]/_/g'`

#
# Generate fmgroids.h
#
cat > "$$-$OIDSFILE" <<FuNkYfMgRsTuFf
/*-------------------------------------------------------------------------
 *
 * $OIDSFILE
 *    Macros that define the OIDs of built-in functions.
 *
 * These macros can be used to avoid a catalog lookup when a specific
 * fmgr-callable function needs to be referenced.
 *
 * Portions Copyright (c) 1996-2002, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * NOTES
 *	******************************
 *	*** DO NOT EDIT THIS FILE! ***
 *	******************************
 *
 *	It has been GENERATED by $CMDNAME
 *	from $INFILE
 *
 *-------------------------------------------------------------------------
 */
#ifndef	$cpp_define
#define $cpp_define

/*
 *	Constant macros for the OIDs of entries in pg_proc.
 *
 *	NOTE: macros are named after the prosrc value, ie the actual C name
 *	of the implementing function, not the proname which may be overloaded.
 *	For example, we want to be able to assign different macro names to both
 *	char_text() and int4_text() even though these both appear with proname
 *	'text'.  If the same C function appears in more than one pg_proc entry,
 *	its equivalent macro will be defined with the lowest OID among those
 *	entries.
 */
FuNkYfMgRsTuFf

# Note assumption here that prosrc == $(NF-2).

tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' < $RAWFILE | \
$AWK '
BEGIN	{ OFS = ""; }
	{ if (seenit[$(NF-2)]++ == 0) print "#define F_", $(NF-2), " ", $1; }' >> "$$-$OIDSFILE"

if [ $? -ne 0 ]; then
    cleanup
    echo "$CMDNAME failed"
    exit 1
fi

cat >> "$$-$OIDSFILE" <<FuNkYfMgRsTuFf

#endif	/* $cpp_define */
FuNkYfMgRsTuFf

#
# Generate fmgr's built-in-function table.
#
# Print out the function declarations, then the table that refers to them.
#
cat > "$$-$TABLEFILE" <<FuNkYfMgRtAbStUfF
/*-------------------------------------------------------------------------
 *
 * $TABLEFILE
 *    The function manager's table of internal functions.
 *
 * Portions Copyright (c) 1996-2002, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * NOTES
 *
 *	******************************
 *	*** DO NOT EDIT THIS FILE! ***
 *	******************************
 *
 *	It has been GENERATED by $CMDNAME
 *	from $INFILE
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"

#include "utils/fmgrtab.h"

FuNkYfMgRtAbStUfF

# Note assumption here that prosrc == $(NF-2).

$AWK '{ print "extern Datum", $(NF-2), "(PG_FUNCTION_ARGS);"; }' $RAWFILE >> "$$-$TABLEFILE"

if [ $? -ne 0 ]; then
    cleanup
    echo "$CMDNAME failed"
    exit 1
fi


cat >> "$$-$TABLEFILE" <<FuNkYfMgRtAbStUfF

const FmgrBuiltin fmgr_builtins[] = {
FuNkYfMgRtAbStUfF

# Note: using awk arrays to translate from pg_proc values to fmgrtab values
# may seem tedious, but avoid the temptation to write a quick x?y:z
# conditional expression instead.  Not all awks have conditional expressions.
#
# Note assumptions here that prosrc == $(NF-2), pronargs == $11,
# proisstrict == $8, proretset == $9

$AWK 'BEGIN {
    Bool["t"] = "true"
    Bool["f"] = "false"
}
{ printf ("  { %d, \"%s\", %d, %s, %s, %s },\n"), \
	$1, $(NF-2), $11, Bool[$8], Bool[$9], $(NF-2)
}' $RAWFILE >> "$$-$TABLEFILE"

if [ $? -ne 0 ]; then
    cleanup
    echo "$CMDNAME failed"
    exit 1
fi

cat >> "$$-$TABLEFILE" <<FuNkYfMgRtAbStUfF
  /* dummy entry is easier than getting rid of comma after last real one */
  /* (not that there has ever been anything wrong with *having* a
     comma after the last field in an array initializer) */
  { 0, NULL, 0, false, false, (PGFunction) NULL }
};

/* Note fmgr_nbuiltins excludes the dummy entry */
const int fmgr_nbuiltins = (sizeof(fmgr_builtins) / sizeof(FmgrBuiltin)) - 1;

FuNkYfMgRtAbStUfF

# We use the temporary files to avoid problems with concurrent runs
# (which can happen during parallel make).
mv "$$-$OIDSFILE" $OIDSFILE
mv "$$-$TABLEFILE" $TABLEFILE

cleanup
exit 0
