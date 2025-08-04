repomix:
    rm -f repomix-output.xml
    npx repomix . --style xml --ignore lib

coverage:
    forge coverage --report lcov -r coverage/lcov.info
    lcov --branch-coverage --ignore-errors inconsistent --list coverage/lcov.info
    genhtml coverage/lcov.info --ignore-errors inconsistent --flat --branch-coverage --output-directory coverage
    open coverage/index.html
