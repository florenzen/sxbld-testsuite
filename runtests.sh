#!/bin/bash


# Usage: runtests.sh [names of testcases]
# The name of the testcase is the name of the directory
# If no testcases are given all are run

sugarj="$HOME/scratch/sugarj"


function info_message {
    echo -e "\033[34mINFO:\033[0m $1"
    echo "INFO: $1" >> "$outputdir/log"
}

function abort {
    echo -e "\033[97;41mABORT:\033[0m $1" > /dev/stderr
    echo "ABORT: $1" >> "$outputdir/log"
    exit 1
}

function log_message {
    echo -n "$1"
    echo -n "$1" >> "$outputdir/log"
}

function log_message_ln {
    echo "$1"
    echo "$1" >> "$outputdir/log"
}

function log_success {
    echo -e '[ \033[32mSUCCESS\033[0m ]'
    echo "[ SUCCESS ]" >> "$outputdir/log"
}

function log_failed {
    echo -e '[ \033[31mFAILED\033[0m  ]'
    echo "[ FAILED  ]" >> "$outputdir/log"
}

function check_files {
    if diff "$1/bin/$2.sdf" "$1/expected/$2.sdf" >& "$1/sdf.diff"; then
        # no difference in SDF
        if diff "$1/bin/$2.str" "$1/expected/$2.str" >& "$1/str.diff"; then
            # no difference in STR
            log_success
            inc_success_testcases
        else
            # difference in STR
            log_failed
            inc_failed_testcases
            log_message_ln "    Stratego files differ"
        fi
    else
        # difference in SDF
        log_failed
        inc_failed_testcases
        log_message_ln "    SDF2 files differ"

        if diff "$1/bin/$2.str" "$1/expected/$2.str" >& "$1/str.diff"; then
            # no difference in STR
            :
        else
            # difference in STR
            log_message_ln "    Stratego files differ"
        fi

    fi
}

function check_error_messages {
    grep -A 1 "^error:" "$1/sugarj.log" > "$1/error-messages.txt"
    if diff "$1/error-messages.txt" "$1/expected/error-messages.txt" >& "$1/messages.diff"; then
        # no difference
        log_success
        inc_success_testcases
    else
        # some difference
        log_failed
        inc_failed_testcases
        log_message_ln "    error messages differ"
        log_message_ln "    expected:"
        while read line; do
            log_message_ln "        $line"
        done < "$1/expected/error-messages.txt"
        log_message_ln "    received:"
                while read line; do
            log_message_ln "        $line"
        done < "$1/error-messages.txt"
    fi
}

# 1st arg: testcase dir
# 2nd arg: input file name
function run_sugarj {
    rm -rf $cachedir/*
    $sugarj -d "$1/bin" \
            --cache "$cachedir" \
            --gen-files \
            -l sxbld \
            --sourcepath "$1/input" \
            "$2" >& "$1/sugarj.log"
}

function inc_failed_testcases {
    testcases_total=$((testcases_total + 1))
    testcases_failure=$((testcases_failure + 1))
}

function inc_success_testcases {
    testcases_total=$((testcases_total + 1))
    testcases_success=$((testcases_success + 1))
}

testcases_total=0
testcases_failure=0
testcases_success=0

testsuitedir="`pwd`/${0%/*}"

time=`date "+%Y-%m-%d-%H-%M-%S"`
outputdir="`mktemp -d -t sxbld-testsuite-$time`"
info_message "Output directory $outputdir"

cachedir="$outputdir/sugarjcache"

info_message "Copy testcases to output directory"
cp -r "$testsuitedir/testcases"/* "$outputdir"

cd "$outputdir"

if [ $# -ne 0 ]; then
    testcases="$@"
else
    testcases=`ls -d [0-9][0-9][0-9][0-9]_*`
fi

for testcasedir in $testcases; do
    if [ ! -d "$testcasedir" ]; then
        abort "$testcasedir: not found (name misspelled?)"
    fi

    # Find input file
    numinputfiles=`ls "$testcasedir/input" | wc -l`
    if [ $numinputfiles -ne 1 ]; then
        abort "$testcasedir: there must be exactly one input file"
    fi
    inputfile=`ls "$testcasedir/input"`
    inputfilemodule=`basename "$inputfile" .sxbld`

    # Find expected exit code
    if [ ! -f $testcasedir/expected/exitcode ]; then
        abort "$testcasedir: there must be an expected/exitcode file"
    fi
    expected_exitcode=`cat "$testcasedir/expected/exitcode"`

    # Find expected outcome
    if [ -f "$testcasedir/expected/fail" -a ! -f "$testcasedir/expected/success" ]; then
        outcome="fail"
    elif [ ! -f "$testcasedir/expected/fail" -a -f "$testcasedir/expected/success" ]; then
        outcome="success"
    else
        abort "$testcasedir: there must be either an expected/fail or an expected/success file"
    fi

    # Start logging
    namelen=`echo -n $testcasedir | wc -c`
    if [ $namelen -gt 40 ]; then
        padded="${testcasedir:0:37}..."
    else
        padlen=$((40-namelen))
        # from http://stackoverflow.com/questions/5349718/how-can-i-repeat-a-character-in-bash
        padding=`head -c $padlen < /dev/zero | tr '\0' ' '`
        padded="$testcasedir$padding"
    fi
    log_message "TEST CASE: $padded "
    
    run_sugarj "$testcasedir" "$inputfile"
    exitcode=$?

    if [ $exitcode -ne $expected_exitcode ]; then
        log_failed
        log_message_ln "    exit code failure"
        log_message_ln "    expected: $expected_exitcode"
        log_message_ln "    received: $exitcode"
        inc_failed_testcases
        continue
    fi

    if [ "$outcome" = "success" ]; then
        check_files "$testcasedir" "$inputfilemodule"
    elif [ "$outcome" = "fail" ]; then
        check_error_messages "$testcasedir"
    fi
done

info_message "Summary:"
info_message "    testcases total:     $testcases_total"
info_message "    testcases failed:    $testcases_failure"
info_message "    testcases succeeded: $testcases_success"

if [ $testcases_failure -gt 0 ]; then
    info_message "Keep temporary directory for inspection of failure"
    info_message "  $outputdir"
    exit 2
else
    info_message "Deleting temporary directory"
    rm -rf $outputdir
    exit 0
fi
