#!/usr/bin/env bash
# -*- sh -*-

erl -pa deps/*/ebin -noshell -sname extremeforge -s extremeforge start src test
