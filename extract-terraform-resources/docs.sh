#!/bin/bash

files=(*.tf)

for file in ${files[@]}; do
    echo "$file"
    echo "************"
    sed -n 's@resource "\([[:alpha:]_]*\)" "\([^{]*\)" {@\1 - \2@p' $file
    echo ""
#    sed -n 's/resource "\([[:alpha:]_]*\)" "\([^{]*\)"/\1 - \2/p' $fi
done 

echo ${#files[@]}
