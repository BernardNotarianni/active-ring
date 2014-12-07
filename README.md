EXTREME FORGE

http://extremeforge.net

This open source software aims to make it simple to use test-driven
development with Erlang. Just start Extreme Forge at the root of your
project and it will compile all Erlang source files and run all the
tests, continuously, automatically detecting when any files are changed.

## Requirements

Erlang/OTP R12B-3 or above (http://erlang.org).

## Installation

Download the tarball, unpack to any convenient location.
Change to the directory to which you unpacked.
From the shell, run the `install` script:

    % ./install

This script compiles Extreme Forge source code, then uses it
to test itself on your platform. It should print out some lines,
ending with "Installation successful".

The *.beam files needed to run Extreme Forge are now located in
the ebin directory below where you unpacked the tarball. That
directory is referred to in the following instructions as
`/path/to/install/ebin`.

## Usage

To use Extreme Forge interactively (for continuous compiling and testing
of your project as you develop):

    % cd /path/to/your/project
    % erl -sname extremeforge -pa /path/to/install/ebin
    
    Erlang (BEAM) emulator version 5.6.3 [source] [smp:2]
    Eshell V5.6.3  (abort with ^G)

    (extremeforge@bill)1> extremeforge:start().

To stop:

    (extremeforge@bill)2> extremeforge:stop().

To use Extreme Forge in a continuous integration tool (from the command
line, with a single run of compilation and tests, and an exit code):

    % cd /path/to/your/project
    % erl -sname extremeforge -pa /path/to/install/ebin -noinput \
    > -run extremeforge run > extremeforge.log

This provides an exit code of 0 if all modules compiled and all tests
passed, 1 otherwise.

## Emacs

The text output of extremeforge is designed to allow direct navigation
to source files on compile errors, warnings or test failures, when run
from within Emacs.

To achieve this add the following to your `.emacs`:

```
(add-hook 'erlang-mode-hook
	  (function (lambda ()
		      (unless (or (file-exists-p "makefile")
				  (file-exists-p "Makefile"))
			(set
			 (make-local-variable 'compile-command)
			 (concat
			  "erl -sname forge -noinput "
			  "-pa /path/to/install/ebin "
			  " -run extremeforge start"))))))
```

From an Erlang source file buffer (in erlang-mode), you can now call
`M-x compile` to start Extreme Forge in a compilation buffer where it
will keep running. It will compile and test all Erlang source files in
or below the directory of the current buffer. Every time a source file
is saved, modifications will be recompiled and tests re-run.
Compilation-mode commands may be used to navigate directly to errors.

## Writing tests

Test functions can be in any module and must have have arity 0.

Add a `-test(exports).` attribute to designate all exported functions
of a module to be tests.

Add a `-test(myfunction).` attribute to designate a specific function
as a test.

Test functions that do not crash are considered to pass. See
`src/*_test.erl` for examples.

## Note

Saving a file without modifications (or using `touch`) is not
sufficient to trigger a recompile: Extreme Forge only recompiles if
the content has changed.

## Known issues

Extreme Forge currently does not detect that source files need to be
recompiled when a file that they include has been modified.

## LEGAL MATTERS

Copyright (c) 2004-2010 Dominic Williams, Nicolas Charpentier,
Virgile Delecolle, Fabrice Nourisson and Jacques Couvreur.
All rights reserved.

This software is licensed under the new (2-clause) BSD licence.
See the file COPYING located in the src directory.
