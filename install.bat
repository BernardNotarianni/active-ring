@echo off

start /MIN erl -kernel error_logger "{file,\"tester.log\"}" -sname forgetester@localhost -noinput
cd ebin
erl -make
erl -kernel error_logger "{file,\"../forge.log\"}" -sname forgeinstaller@localhost -noinput -s shells install forgetester@localhost -s init stop
cd ..