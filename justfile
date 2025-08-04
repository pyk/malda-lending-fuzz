repomix:
    rm -f repomix-output.xml
    npx repomix . --style xml --ignore lib

coverage:
    rm -rf coverage
    mkdir -p coverage
    forge coverage --report lcov --lcov-version 2.2 -r coverage/lcov.info
    lcov --branch-coverage --ignore-errors inconsistent --list coverage/lcov.info
    genhtml coverage/lcov.info --ignore-errors inconsistent --flat --branch-coverage --output-directory coverage
    open coverage/index.html
