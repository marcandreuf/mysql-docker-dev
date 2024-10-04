#!/bin/bash


get_new_files() {
    local lindex="$#"    
    local cnt=1
    local newFiles
    for arg in "$@"
    do
       if [[ $cnt -lt $lindex ]]; then
            filename=$(basename $arg)
            if [[ $filename > ${!lindex} ]]; then
                newFiles+="$arg "
            fi
       fi
       let "cnt+=1"
    done
    echo $newFiles
}

new_list=$(get_new_files db-models/* 004-load_dept_manager.sql)

if [ "$new_list" = "" ]; then
    printf "NO new DB models found. Not processing more init files."
else
    printf "Processing new DB models '$new_list'"
fi
