#!/bin/sh
#
# $Header$

# ----------
# Check call syntax
# ----------
if [ $# -eq 0 ]
then
    echo "Syntax: $0 <hostname> [extra-tests]"
    exit 1
fi

# ----------
# Change to the regression test directory explicitly
# ----------
cd `dirname $0`

# ----------
# Some paths used during the test
# ----------
PWD=`pwd`
CHKDIR="$PWD/tmp_check"
PGDATA="$CHKDIR/data"
LIBDIR="$CHKDIR/lib"
BINDIR="$CHKDIR/bin"
LOGDIR="$CHKDIR/log"
TIMDIR="$CHKDIR/timestamp"
PGPORT="65432"
PGLIB="$LIBDIR"
PMPID=""

export CHKDIR
export PGDATA
export PGLIB
export LOGDIR
export TIMDIR
export PGPORT


# ----------
# Get the commandline parameters
# ----------
hostname=$1
shift
extratests="$*"

# ----------
# Special setting for Windows (no unix domain sockets)
# ----------
if [ "x$hostname" = "xwin" ]
then
    HOSTLOC="-h localhost"
else
    HOSTLOC=""
fi

# ----------
# Determine if echo -n works
# ----------
if echo '\c' | grep -s c >/dev/null 2>&1
then
    ECHO_N="echo -n"
    ECHO_C=""
else
    ECHO_N="echo"
    ECHO_C='\c'
fi

# ----------
# Set timezone and datestyle explicitly
# ----------
PGTZ="PST8PDT"; export PGTZ
PGDATESTYLE="Postgres,US"; export PGDATESTYLE

# ----------
# The SQL shell to use during this test
# ----------
FRONTEND="$BINDIR/psql $HOSTLOC -n -e -q"

# ----------
# Prepare temp file holding combined test script.
# ----------
TESTLIST="/tmp/testlist.$$"
TESTS=./sql/run_check.tests
(
	cat $TESTS 
	for name in $extratests ; do
		echo "test $name"
	done
) > $TESTLIST

# ----------
# Catch SIGINT and SIGTERM to shutdown the postmaster
# ----------
trap '	echo ""
		echo ""
		echo "user abort ..."
		if [ ! -z "$PMPID" ]
		then
			echo "Signalling postmaster with PID $PMPID to shutdown immediately"
			kill -2 $PMPID
			wait $PMPID
			echo ""
		fi
		echo ""
		rm $TESTLIST
		exit 1
' 2 15

# ----------
# Prepare a clean check directory
# ----------
if [ -d $CHKDIR ]
then
	echo "=============== Removing old ./tmp_check directory ... ================"
	rm -rf $CHKDIR
fi

echo "=============== Create ./tmp_check directory           ================"
mkdir -p $CHKDIR
mkdir -p $LOGDIR


# ----------
# Install this build into ./tmp/check
# ----------
echo "=============== Installing new build into ./tmp_check  ================"
${MAKE:-gmake} -C ../.. POSTGRESDIR=$CHKDIR install >$LOGDIR/install.log 2>&1

if [ $? -ne 0 ]
then
	echo ""
	echo "ERROR: Check installation failed - cannot continue"
	echo "Please examine $LOGDIR/install.log"
	echo "for the reason."
	echo ""
	exit 2
fi


# ----------
# Change the path so that all binaries from the current
# build are first candidates
# ----------
PATH=$CHKDIR/bin:$PATH
export PATH


# ----------
# Run initdb to initialize a database system in ./tmp_check
# ----------
echo "=============== Initializing check database instance   ================"
initdb --pglib=$LIBDIR --pgdata=$PGDATA >$LOGDIR/initdb.log 2>&1

if [ $? -ne 0 ]
then
	echo ""
	echo "ERROR: Check initdb failed - cannot continue"
	echo "Please examine $LOGDIR/initdb.log"
	echo "for the reason."
	echo ""
	exit 3
fi


# ----------
# Start a postmaster for the check instance and give
# him some time to pass the WAL recovery code. 
#----------
echo "=============== Starting regression postmaster         ================"
postmaster -D $PGDATA -p $PGPORT -o -F >$LOGDIR/postmaster.log 2>&1 &
PMPID=$!
sleep 2

if kill -0 $PMPID >/dev/null 2>&1
then
	echo "Regression postmaster is running - PID=$PMPID PGPORT=$PGPORT"
else
	echo ""
	echo "ERROR: Regression postmaster did not startup."
	echo "Please examine $LOGDIR/postmaster.log"
	echo "for the reason."
	echo ""
	exit 4
fi


# ----------
# Create the regression database
# ----------
echo "=============== Creating regression database...        ================"
if [ -n "$MULTIBYTE" ];then
    mbtests=`echo $MULTIBYTE | tr "[A-Z]" "[a-z]"`
    PGCLIENTENCODING="$MULTIBYTE"
    export PGCLIENTENCODING
    ENCODINGOPT="-E $MULTIBYTE"
else
    mbtests=""
    unset PGCLIENTENCODING
    ENCODINGOPT=""
fi
createdb $ENCODINGOPT $HOSTLOC regression
if [ $? -ne 0 ]; then
     echo createdb failed
	 kill -15 $PMPID
     exit 1
fi


# ----------
# Install the PL/pgSQL language in it
# ----------
echo "=============== Installing PL/pgSQL...                 ================"
createlang $HOSTLOC plpgsql regression
if [ $? -ne 0 -a $? -ne 2 ]; then
     echo createlang failed
	 kill -15 $PMPID
     exit 1
fi


# ----------
# Run the regression tests specified in the $TESTLIST file
# ----------
echo "=============== Running regression queries...          ================"
echo "" > regression.diffs
echo "" > regress.out

lno=0
while read line
do
	# ----------
	# Count line numbers and skip comments and empty lines
	# ----------
	lno=`expr $lno + 1`
	line=`echo $line | sed -e 's/[ 	]*#.*//'`
	if [ -z "$line" ]
	then
		continue
	fi

	# ----------
	# Extract the type keyword and the name
	# ----------
	type=`echo $line | awk '{print $1;}'`
	name=`echo $line | awk '{print $2;}'`

	case $type in
		parallel)	# ----------
					# This is the beginning of a new group of
					# tests that should be executed in parallel.
					# ----------
					parlist=
					parlno=$lno
					pargroup=$name
					parntests=0
					parpar=0
					while read line
					do
						# ----------
						# Again count line numbers and skip comments
						# ----------
						lno=`expr $lno + 1`
						line=`echo $line | sed -e 's/[ 	]*#.*//'`
						if [ -z "$line" ]
						then
							continue
						fi

						# ----------
						# Collect and count the number of tests to
						# execute parallel
						# ----------
						type=`echo $line | awk '{print $1;}'`
						name=`echo $line | awk '{print $2;}'`

						if [ "$type" = "endparallel" ]
						then
							parend=1
							break
						fi
						if [ "$type" = "parallel" ]
						then
							echo ""
							echo "$TESTS line $lno: parallel cannot be nested"
							echo ""
							exit 5
						fi
						if [ "$type" != "test" ]
						then
							echo ""
							echo "$TESTS line $lno: syntax error"
							echo ""
							exit 5
						fi

						if [ ! -z "$parlist" ]
						then
							parlist="$parlist "
						fi

						parlist="${parlist}$name"
						parntests=`expr $parntests + 1`
					done

					# ----------
					# Check that we found a matching 'endparallel'
					# ----------
					if [ $parend -eq 0 ]
					then
						echo ""
						echo "$TESTS at EOF: missing endparallel for line $parlno"
						echo ""
						exit 5
					fi

					# ----------
					# Tell what we're doing and then start them all, using
					# a subshell for each one.  The subshell is just there
					# to print the test name when it finishes, so one can
					# see which tests finish fastest.  We do NOT run the
					# ok/failed comparison tests in the parallel subshells,
					# because we want the diffs (if any) to come out in a
					# predictable order --- and certainly not interleaved!
					# ----------
					gnam=`echo "$pargroup ($parntests tests)" | awk '{printf "%-26.26s", $0;}'`
					echo "parallel $gnam  ..."

					for name in $parlist
					do
						(
							$FRONTEND regression < sql/${name}.sql			\
								> results/${name}.out 2>&1
							$ECHO_N " $name" $ECHO_C
						) &
					done </dev/null
					wait
					echo ""

					# ----------
					# Setup status information for the diff check below
					# ----------
					checklist=$parlist
					checkpname=1
					;;

		test)		# ----------
					# This is a test that must be executed serialized
					# ----------
					pnam=`echo $name | awk '{printf "%-20.20s", $1;}'`
					$ECHO_N "sequential test $pnam ... " $ECHO_C

					$FRONTEND regression < sql/${name}.sql					\
						> results/${name}.out 2>&1

					# ----------
					# Setup status information for the diff check below
					# ----------
					checklist=$name
					checkpname=0
					;;

		*)			# ----------
					# And this is space for extensions
					# ----------
					echo ""
					echo "$TESTS line $lno: syntax error"
					echo ""
					exit 5
					;;
	esac

	# ----------
	# One single or a group of parallel tests has been completed.
	# Check the output against the expected results.
	#
	# On the fly we create run_check.out and regress.out in the
	# old format, so checkresults will still find the proper
	# information.
	# ----------
	for tst in $checklist ; do
		if [ $checkpname -ne 0 ]
		then
			pnam=`echo $tst | awk '{printf "%-20.20s", $1;}'`
			$ECHO_N "           test $pnam ... " $ECHO_C
		fi

		#
		# Check resultmap to see if we should compare to a
		# system-specific result file.  The format of the file is
		#	testname/hostname=substitutefile
		# There shouldn't be multiple matches, but take the last if there are.
		#
		EXPECTED="expected/${tst}.out"
		SUBST=`grep "^$tst/$hostname=" resultmap | sed 's/^.*=//' | tail -1`
		if test "$SUBST"
		then EXPECTED="expected/${SUBST}.out"
		else
		    # Next look for a .similar entry that is a prefix of $hostname.
		    # If there are multiple matches, take the last one.
		    while read LINE
		    do
			SIMHOST=`expr "$LINE" : '\(.*\)='`
			MATCH=`expr "$tst/$hostname" : "$SIMHOST"`
			echo "$LINE $SIMHOST $MATCH"
			if test "$MATCH" != 0
			then SUBST=`echo "$LINE" | sed 's/^.*=//'`
			fi
		    done <resultmap
		    if test "$SUBST"
		    then EXPECTED="expected/${SUBST}.out"
		    fi
		fi

		if [ `diff -w ${EXPECTED} results/${tst}.out | wc -l` -ne 0 ]
		then
			(	diff -wC3 ${EXPECTED} results/${tst}.out	; \
				echo ""										; \
				echo "----------------------"				; \
				echo ""										; \
			) >> regression.diffs
			echo "FAILED"
			echo "$tst .. failed" >> regress.out
		else
			echo "ok"
			echo "$tst .. ok" >> regress.out
		fi
	done
done <$TESTLIST | tee run_check.out 2>&1

# ----------
# Finally kill the postmaster we started
# ----------
echo "=============== Terminating regression postmaster      ================"
kill -15 $PMPID

rm $TESTLIST

exit 0
