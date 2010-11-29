@echo off

cd ebin
del *.beam
erl -make
cd ..
erl -pa ebin -kernel error_logger "{file,\"../install_errors.log\"}" -sname extremeforge_installer -noinput -run extremeforge run
