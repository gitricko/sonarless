#!/bin/bash

function hello-world() {
    echo "Hello ${INPUT_NAME}"
    docker ps -a
}

$*