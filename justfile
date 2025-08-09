
repomix:
    rm -f repomix-output.xml
    npx repomix . --style xml --ignore contracts/lib


repomix-risc0:
    rm -f repomix-risc0-v2.xml
    npx repomix --remote https://github.com/risc0/risc0 --include "website/api_versioned_docs/version-2.2" -o repomix-risc0-v2.xml

