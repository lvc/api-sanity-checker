API Sanity Checker 1.98.8
=========================

API Sanity Checker — an automatic generator of basic unit tests for a C/C++ library API.

Contents
--------

1. [ About      ](#about)
2. [ Install    ](#install)
3. [ Usage      ](#usage)
4. [ Test suite ](#test-suite)

About
-----

The tool is able to generate reasonable (in most, but unfortunately not all, cases) input data for parameters and compose simple ("sanity" or "shallow"-quality) test cases for every function in the API through the analysis of declarations in header files.

The quality of generated tests allows to check absence of critical errors in simple use cases. The tool is able to build and execute generated tests and detect crashes (segfaults), all kinds of emitted signals, non-zero program return code and program hanging.

The tool is developed by Andrey Ponomarenko.

Install
-------

    sudo make install prefix=/usr

###### Requires

* ABI Compliance Checker 1.99.24 or newer: https://github.com/lvc/abi-compliance-checker
* Perl 5
* G++
* GNU Binutils
* Ctags

Usage
-----

    api-sanity-checker -lib NAME -d VERSION.xml -gen -build -run

`VERSION.xml` is XML-descriptor:

    <version>
        1.0
    </version>

    <headers>
        /path/to/headers/
    </headers>

    <libs>
        /path/to/libraries/
    </libs>

###### Adv. usage

For advanced usage, see `doc/index.html` or output of `-help` option.

Test suite
----------

A small test to check that the tool works properly in your environment:

    api-sanity-checker -test
