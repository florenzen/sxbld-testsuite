#!/bin/bash

function usage {
    echo "usage: $0 <input> <testcasename>" > /dev/stderr
    exit 1
}

if [ "$1" = "" ]; then
    usage
fi

if [ "$2" = "" ]; then
    usage
fi

inputfile="$1"
testcasename="$2"

sugarj="$HOME/scratch/sugarj"

testsuitedir="`pwd`/${0%/*}"

cd "$testsuitedir"

numtestcases=`ls -d testcases/[0-9][0-9][0-9][0-9]_* | wc -l`

numnew=$((numtestcases + 1))

numnewpadded=`printf "%04d" $numnew`

testcasedir="testcases/${numnewpadded}_$testcasename"
echo $testcasedir

echo "Create directory $testcasedir"
mkdir "$testcasedir"
mkdir "$testcasedir/expected"
mkdir "$testcasedir/input"

cp "$inputfile" "$testcasedir/input"

inputfilemodule=`basename "$inputfile" .sxbld`

tempdir=`mktemp -d -t maketestcase`
echo "Temporary directory $tempdir"


$sugarj -d "$tempdir/bin" \
        --cache "$tempdir/sugarjcache" \
        --gen-files \
        -l sxbld \
        --sourcepath "$testcasedir/input" \
        "$inputfilemodule.sxbld" >& "$tempdir/sugarj.log"
exitcode=$?

echo $exitcode > "$testcasedir/expected/exitcode"

if [ $exitcode -eq 0 ]; then
    # successful testcase
    touch "$testcasedir/expected/success"
    echo "Create a success testcase"
    cp "$tempdir/bin/$inputfilemodule.sdf" "$testcasedir/expected"
    cp "$tempdir/bin/$inputfilemodule.str" "$testcasedir/expected"
    rm -rf "$tempdir"
elif [ $exitcode -eq 2 ]; then
    # fail testcase
    touch "$testcasedir/expected/fail"
    echo "Create a fail testcase"
    grep -A 1 "^error:" "$tempdir/sugarj.log" > "$testcasedir/expected/error-messages.txt"
    rm -rf "$tempdir"
else
    # unknown exit code
    echo "Unknown exit code $exitcode"
    echo "Do not generate a testcase"
    echo "Inspect the output in $tempdir for the reason"
    rm -rf "$testcasedir"
fi
