#!/usr/bin/env bash
#
# Copyright (C) 2015 Philipp Rosenkranz <philipp.rosenkranz@fu-berlin.de>
#
# This file is subject to the terms and conditions of the GNU Lesser
# General Public License v2.1. See the file LICENSE in the top level
# directory for more details.
#

set -e

set_result() {
    NEW_RESULT=$1
    LAST_RESULT=$2

    if [ $LAST_RESULT -ne 0 ] && [ $NEW_RESULT -eq 0 ]
    then
        NEW_RESULT=$LAST_RESULT
    fi

    echo $NEW_RESULT
}

if [[ $BUILDTEST_MCU_GROUP ]]
then

    if [ "$BUILDTEST_MCU_GROUP" == "static-tests" ]
    then
        RESULT=0
        RECALL="$1"

        if git diff master HEAD -- .travis.yml &> /dev/null; then
            # check if .travis.yml was changed in the current PR and skip if so
            if ! git diff --name-only $(git merge-base HEAD master)..HEAD -- \
                .travis.yml &> 1; then
                echo "==============================================================" >&2
                echo -e "\033[1;31m.travis.yml differs in upstream.\033[0m"
                echo -e "\033[1;31mPlease rebase your PR to current upstream or expect errors!!!!\033[0m" >&2
                echo "    git fetch https://github.com/RIOT-OS/RIOT master" >&2
                echo "    git rebase FETCH_HEAD" >&2
                echo "    git push -f origin $(git rev-parse --abbrev-ref HEAD)" >&2
                echo "==============================================================" >&2
                return 1
            fi
        fi

        if [ "$RECALL" != "recall" ]; then
            if git diff master HEAD -- "$0" &> /dev/null; then
                git rebase master || git rebase --abort

                "$0" "recall"
                exit $?
            fi
        fi

        git rebase master || git rebase --abort
        RESULT=$(set_result $? $RESULT)

        ./dist/tools/whitespacecheck/check.sh master
        RESULT=$(set_result $? $RESULT)

        ./dist/tools/licenses/check.sh master --diff-filter=MR --error-exitcode=0
        RESULT=$(set_result $? $RESULT)

        ./dist/tools/licenses/check.sh master --diff-filter=AC
        RESULT=$(set_result $? $RESULT)

        ./dist/tools/doccheck/check.sh master
        RESULT=$(set_result $? $RESULT)

        ./dist/tools/externc/check.sh master
        RESULT=$(set_result $? $RESULT)

        # TODO:
        #   Remove all but `master` parameters to cppcheck (and remove second
        #   invocation) once all warnings of cppcheck have been taken care of
        #   in master.
        ./dist/tools/cppcheck/check.sh master --diff-filter=MR --error-exitcode=0
        RESULT=$(set_result $? $RESULT)

        ./dist/tools/cppcheck/check.sh master --diff-filter=AC
        RESULT=$(set_result $? $RESULT)

        ./dist/tools/pr_check/pr_check.sh master
        RESULT=$(set_result $? $RESULT)

        exit $RESULT
    fi

    if [ "$BUILDTEST_MCU_GROUP" == "x86" ]
    then
        make -C ./tests/unittests all test BOARD=native || exit
        # TODO:
        #   Reenable once https://github.com/RIOT-OS/RIOT/issues/2300 is
        #   resolved:
        #   - make -C ./tests/unittests all test BOARD=qemu-i386 || exit
    fi
    ./dist/tools/compile_test/compile_test.py $TRAVIS_BRANCH
fi
