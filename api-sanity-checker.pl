#!/usr/bin/perl
###########################################################################
# API Sanity Checker 1.98.7
# An automatic generator of basic unit tests for a C/C++ library API
#
# Copyright (C) 2009-2011 Institute for System Programming, RAS
# Copyright (C) 2011-2015 Andrey Ponomarenko's ABI Laboratory
#
# Written by Andrey Ponomarenko
#
# PLATFORMS
# =========
#  Linux, FreeBSD, Mac OS X, MS Windows
#
# REQUIREMENTS
# ============
#  Linux
#    - ABI Compliance Checker (1.99 or newer)
#    - G++ (3.0-4.7, 4.8.3, 4.9 or newer)
#    - GNU Binutils (readelf, c++filt, objdump)
#    - Perl 5 (5.8 or newer)
#    - Ctags (5.8 or newer)
#
#  Mac OS X
#    - ABI Compliance Checker (1.99 or newer)
#    - Xcode (gcc, c++filt, nm)
#    - Ctags (5.8 or newer)
#
#  MS Windows
#    - ABI Compliance Checker (1.99 or newer)
#    - MinGW (3.0-4.7, 4.8.3, 4.9 or newer)
#    - MS Visual C++ (dumpbin, undname, cl)
#    - Active Perl 5 (5.8 or newer)
#    - Ctags (5.8 or newer)
#    - Add tool locations to the PATH environment variable
#    - Run vsvars32.bat (C:\Microsoft Visual Studio 9.0\Common7\Tools\)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License or the GNU Lesser
# General Public License as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# and the GNU Lesser General Public License along with this program.
# If not, see <http://www.gnu.org/licenses/>.
###########################################################################
use Getopt::Long;
Getopt::Long::Configure ("posix_default", "no_ignore_case");
use POSIX qw(setsid);
use File::Path qw(mkpath rmtree);
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use Cwd qw(abs_path cwd realpath);
use Config;

my $TOOL_VERSION = "1.98.7";
my $OSgroup = get_OSgroup();
my $ORIG_DIR = cwd();
my $TMP_DIR = tempdir(CLEANUP=>1);

my $ABI_CC = "abi-compliance-checker";
my $ABI_CC_VERSION = "1.99";

# Internal modules
my $MODULES_DIR = get_Modules();
push(@INC, get_dirname($MODULES_DIR));

my ($Help, $InfoMsg, $TargetLibraryName, $GenerateTests, $TargetInterfaceName,
$BuildTests, $RunTests, $CleanTests, $DisableReuse, $LongVarNames, %Descriptor,
$UseXvfb, $TestTool, $MinimumCode, $TestDataPath, $MaximumCode, $RandomCode,
$SpecTypes_PackagePath, $CheckReturn, $DisableDefaultValues, $ShowRetVal,
$CheckHeadersOnly, $Template2Code, $Standalone, $ShowVersion, $MakeIsolated,
$ParameterNamesFilePath, $CleanSources, $DumpVersion, $TargetHeaderName,
$RelativeDirectory, $TargetTitle, $TargetVersion, $StrictGen,
$StrictBuild, $StrictRun, $Strict, $Debug, $UseCache, $NoInline, $UserLang,
$OptimizeIncludes, $KeepInternal, $TargetCompiler, $GenerateAll,
$InterfacesListPath);

my $CmdName = get_filename($0);
my %OS_LibExt=(
    "linux"=>"so",
    "macos"=>"dylib",
    "windows"=>"dll",
    "symbian"=>"dso",
    "default"=>"so"
);

my %ERROR_CODE = (
    # Passed
    "Success"=>0,
    # Failed
    "Failed"=>1,
    # Undifferentiated error code
    "Error"=>2,
    # Cannot access input files
    "Access_Error"=>4,
    # Cannot find a module
    "Module_Error"=>9
);

my $HomePage = "http://lvc.github.com/api-sanity-checker/";

my $ShortUsage = "API Sanity Checker $TOOL_VERSION
Unit test generator for a C/C++ library
Copyright (C) 2015 Andrey Ponomarenko's ABI Laboratory
License: GNU LGPL or GNU GPL

Usage: $CmdName [options]
Example: $CmdName -lib NAME -d VER.xml -gen -build -run

VER.xml is XML-descriptor:

    <version>
        1.0
    </version>

    <headers>
        /path/to/headers/
    </headers>

    <libs>
        /path/to/libraries/
    </libs>

More info: $CmdName --help\n";

if($#ARGV==-1)
{
    print $ShortUsage;
    exit(0);
}

my @INPUT_OPTIONS = @ARGV;

GetOptions("h|help!" => \$Help,
  "info!" => \$InfoMsg,
  "v|version!" => \$ShowVersion,
  "dumpversion!" => \$DumpVersion,
# general options
  "l|lib|library=s" => \$TargetLibraryName,
  "d|descriptor=s" => \$Descriptor{"Path"},
  "gen|generate!" => \$GenerateTests,
  "build|make!" => \$BuildTests,
  "run!" => \$RunTests,
  "clean!" => \$CleanTests,
# extra options
  "vnum=s" =>\$TargetVersion,
  "s|symbol|f|function|i|interface=s" => \$TargetInterfaceName,
  "symbols-list|functions-list|interfaces-list=s" => \$InterfacesListPath,
  "header=s" => \$TargetHeaderName,
  "all!" => \$GenerateAll,
  "xvfb!" => \$UseXvfb,
  "t2c|template2code" => \$Template2Code,
  "strict-gen!" => \$StrictGen,
  "strict-build!" => \$StrictBuild,
  "strict-run!" => \$StrictRun,
  "strict!" => \$Strict,
  "r|random!" =>\$RandomCode,
  "min!" =>\$MinimumCode,
  "max!" =>\$MaximumCode,
  "show-retval!" => \$ShowRetVal,
  "check-retval!" => \$CheckReturn,
  "st|specialized-types=s" => \$SpecTypes_PackagePath,
  "td|test-data=s" => \$TestDataPath,
  "headers-only!" => \$CheckHeadersOnly,
  "no-inline!" => \$NoInline,
  "keep-internal!" => \$KeepInternal,
  "isolated!" => \$MakeIsolated,
  "view-only!" => \$CleanSources,
  "disable-default-values!" => \$DisableDefaultValues,
  "optimize-includes=s" => \$OptimizeIncludes,
  "p|params=s" => \$ParameterNamesFilePath,
  "title|l-full|lib-full=s" => \$TargetTitle,
  "relpath|reldir=s" => \$RelativeDirectory,
  "lang=s" => \$UserLang,
  "target=s" => \$TargetCompiler,
  "debug!" => \$Debug,
  "cache!" => \$UseCache,
# other options
  "test!" => \$TestTool,
  "disable-variable-reuse!" => \$DisableReuse,
  "long-variable-names!" => \$LongVarNames
) or ERR_MESSAGE();

sub ERR_MESSAGE()
{
    print $ShortUsage;
    exit(1);
}

my $LIB_EXT = $OS_LibExt{$OSgroup}?$OS_LibExt{$OSgroup}:$OS_LibExt{"default"};

my $HelpMessage="
NAME:
  API Sanity Checker ($CmdName)
  Generate basic unit tests for a C/C++ library API

DESCRIPTION:
  API Sanity Checker is an automatic generator of basic unit tests for a C/C++
  library. It helps to quickly generate simple (\"sanity\" or \"shallow\"
  quality) tests for every function in an API using their signatures, data type
  definitions and relationships between functions straight from the library
  header files (\"Header-Driven Generation\"). Each test case contains a function
  call with reasonable (in most, but unfortunately not all, cases) input
  parameters. The quality of generated tests allows to check absence of critical
  errors in simple use cases and can be greatly improved by involving of highly
  reusable specialized types for the library.

  The tool can execute generated tests and detect crashes, aborts, all kinds of
  emitted signals, non-zero program return code, program hanging and requirement
  failures (if specified). The tool can be considered as a tool for out-of-box
  low-cost sanity checking of library API or as a test development framework for
  initial generation of templates for advanced tests. Also it supports universal
  Template2Code format of tests, splint specifications, random test generation
  mode and other useful features.

  This tool is free software: you can redistribute it and/or modify it
  under the terms of the GNU LGPL or GNU GPL.

USAGE:
  $CmdName [options]

EXAMPLE:
  $CmdName -lib NAME -d VER.xml -gen -build -run

  VERSION.xml is XML-descriptor:

    <version>
        1.0
    </version>

    <headers>
        /path1/to/header(s)/
        /path2/to/header(s)/
         ...
    </headers>

    <libs>
        /path1/to/library(ies)/
        /path2/to/library(ies)/
         ...
    </libs>

INFORMATION OPTIONS:
  -h|-help
      Print this help.

  -info
      Print complete info.

  -v|-version
      Print version information.

  -dumpversion
      Print the tool version ($TOOL_VERSION) and don't do anything else.

GENERAL OPTIONS:
  -l|-lib|-library NAME
      Library name (without version).

  -d|-descriptor PATH
      Path to the library descriptor (VER.xml file):
      
        <version>
            1.0
        </version>

        <headers>
            /path1/to/header(s)/
            /path2/to/header(s)/
            ...
        </headers>

        <libs>
            /path1/to/library(ies)/
            /path2/to/library(ies)/
            ...
        </libs>

      For more information, please see:
        http://lvc.github.com/api-sanity-checker/Xml-Descriptor.html

  -gen|-generate
      Generate test(s). Options -l and -d should be specified.
      To generate test for the particular function use it with -f option.
      Exit code: number of test cases failed to build.

  -build|-make
      Build test(s). Options -l and -d should be specified.
      To build test for the particular function use it with -f option.
      Exit code: number of test cases failed to generate.

  -run
      Run test(s), create test report. Options -l and -d should be specified.
      To run test for the particular function use it with -f option.
      Exit code: number of failed test cases.

  -clean
      Clean test(s). Options -l and -d should be specified.
      To clean test for the particular function use it with -f option.\n";

sub HELP_MESSAGE() {
    print $HelpMessage."
MORE INFO:
     $CmdName --info\n\n";
}

sub INFO_MESSAGE()
{
    printMsg("INFO", "$HelpMessage
EXTRA OPTIONS:
  -vnum NUM
      Specify library version outside the descriptor.

  -s|-symbol NAME
      Generate/Build/Run test for the specified function
      (mangled name in C++).

  -symbols-list PATH
      This option allows to specify a file with a list of functions
      (one per line, mangled name in C++) that should be tested,
      other library functions will not be tested.

  -header NAME
      This option allows to restrict a list of functions that should be tested
      by providing a header file name in which they are declared. This option
      is intended for step-by-step tests development.
  
  -all
      Generate tests for all symbols recursively included
      in header file(s).

  -xvfb
      Use Xvfb-server instead of current X-server (default)
      for running tests.

  -t2c|-template2code
      Generate tests in the universal Template2Code format.
      For more information, please see:
        http://sourceforge.net/projects/template2code/

  -strict-gen
     Terminate the process of generating tests and return
     error code '1' if cannot generate at least one test case.

  -strict-build
     Terminate the process of building tesst and return
     error code '1' if cannot build at least one test case.

  -strict-run
     Terminate the process of running tests and return
     error code '1' if at least one test case failed.

  -strict
     This option enables all -strict-* options.

  -r|-random
      Random test generation mode.

  -min
      Generate minimun code, call functions with minimum number of parameters
      to initialize parameters of other functions.

  -max
      Generate maximum code, call functions with maximum number of parameters
      to initialize parameters of other functions.

  -show-retval
      Show the function return type in the report.

  -check-retval
      Insert requirements on return values (retval!=NULL) for each
      called function.

  -st|-specialized-types PATH
      Path to the file with the collection of specialized types.
      For more information, please see:
        http://lvc.github.com/api-sanity-checker/Specialized-Type.html

  -td|-test-data PATH
      Path to the directory with the test data files.
      For more information, please see:
        http://lvc.github.com/api-sanity-checker/Specialized-Type.html

  -headers-only
      If the library consists of inline functions only and has no shared
      objects then you should specify this option.
      
  -no-inline
      Don't generate tests for inline functions.
      
  -keep-internal
      Generate tests for internal symbols (functions with '__' prefix and
      methods of classes declared inside other classes).

  -isolated
      Allow to restrict functions usage by the lists specified by the
      -functions-list option or by the group devision in the descriptor.

  -view-only
      Remove all files from the test suite except *.html files. This option
      allows to create a lightweight html-index for all tests.

  -disable-default-values
      Disable usage of default values for function parameters.
      
  -optimize-includes LEVEL
      Enable optimization of the list of included headers in each test case.
      Available levels:
        High (default)
        Medium
        Low
        None - disable

  -p|-params PATH
      Path to file with the function parameter names. It can be used for
      improving generated tests if the library header files don't contain
      parameter names. File format:

            func1;param1;param2;param3 ...
            func2;param1;param2;param3 ...
            ...

  -title NAME
      The name of the library in the report title.

  -relpath|-reldir PATH
      Replace {RELPATH} in the library descriptor by PATH.
      
  -lang LANG
      Set library language (C or C++). You can use this option if the tool
      cannot auto-detect a language.
      
  -target COMPILER
      The compiler that should be used to build generated tests under Windows.
      Supported:
        gcc - GNU compiler
        cl - MS compiler (default)

  -debug
      Write extended log for debugging.
      
  -cache
      Cache the ABI dump and use it on the next run.

OTHER OPTIONS:
  -test
      Run internal tests. Create a simple library and run the tool on it.
      This option allows to check if the tool works correctly on the system.

  -disable-variable-reuse
      Disable reusing of previously created variables in the test.

  -long-variable-names
      Enable long (complex) variable names instead of short names.

EXIT CODES:
    0 - Successful tests. The tool has run without any errors.
    non-zero - Tests failed or the tool has run with errors.

MORE INFORMATION:
    $HomePage\n");
}

# Constants
my $BUFF_SIZE = 256;
my $DEFAULT_ARRAY_AMOUNT = 4;
my $MAX_PARAMS_INLINE = 3;
my $MAX_PARAMS_LENGTH_INLINE = 60;
my $HANGED_EXECUTION_TIME = 7;
my $MIN_PARAMS_MATRIX = 8;
my $MATRIX_WIDTH = 4;
my $MATRIX_MAX_ELEM_LENGTH = 7;
my $LIBRARY_PREFIX_MAJORITY = 10;

my %Operator_Indication = (
    "not" => "~",
    "assign" => "=",
    "andassign" => "&=",
    "orassign" => "|=",
    "xorassign" => "^=",
    "or" => "|",
    "xor" => "^",
    "addr" => "&",
    "and" => "&",
    "lnot" => "!",
    "eq" => "==",
    "ne" => "!=",
    "lt" => "<",
    "lshift" => "<<",
    "lshiftassign" => "<<=",
    "rshiftassign" => ">>=",
    "call" => "()",
    "mod" => "%",
    "modassign" => "%=",
    "subs" => "[]",
    "land" => "&&",
    "lor" => "||",
    "rshift" => ">>",
    "ref" => "->",
    "le" => "<=",
    "deref" => "*",
    "mult" => "*",
    "preinc" => "++",
    "delete" => " delete",
    "vecnew" => " new[]",
    "vecdelete" => " delete[]",
    "predec" => "--",
    "postinc" => "++",
    "postdec" => "--",
    "plusassign" => "+=",
    "plus" => "+",
    "minus" => "-",
    "minusassign" => "-=",
    "gt" => ">",
    "ge" => ">=",
    "new" => " new",
    "multassign" => "*=",
    "divassign" => "/=",
    "div" => "/",
    "neg" => "-",
    "pos" => "+",
    "memref" => "->*",
    "compound" => "," );

my %IsKeyword= map {$_=>1} (
    "delete",
    "if",
    "else",
    "for",
    "public",
    "private",
    "new",
    "protected",
    "main",
    "sizeof",
    "malloc",
    "return",
    "include",
    "true",
    "false",
    "const",
    "int",
    "long",
    "void",
    "short",
    "float",
    "unsigned",
    "char",
    "double",
    "class",
    "struct",
    "union",
    "enum",
    "volatile",
    "restrict"
);

my %ShortTokens=(
    "err"=>"error",
    "warn"=>"warning" );

# Global variables
my $ST_ID=0;
my $REPORT_PATH;
my $TEST_SUITE_PATH;
my $DEBUG_PATH;
my $CACHE_PATH;
my $LOG_PATH;
my %Interface_TestDir;
my %LibsDepend;
my $CompilerOptions_Libs;
my $CompilerOptions_Cflags;
my %Language;
my %Cache;
my $TestedInterface;
my $COMMON_LANGUAGE;
my %SubClass_Created;
my %Constants;
my $MaxTypeId_Start;
my $STAT_FIRST_LINE;
my $INSTALL_PREFIX;

# Mangling
my %tr_name;

# Types
my %TypeInfo;
my %OpaqueTypes;
my %TName_Tid;
my %StructUnionPName_Tid;
my %Class_Constructors;
my %Class_Destructors;
my %ReturnTypeId_Interface;
my %BaseType_PLevel_Return;
my %OutParam_Interface;
my %BaseType_PLevel_OutParam;
my %Interface_OutParam;
my %Interface_OutParam_NoUsing;
my %OutParamInterface_Pos;
my %OutParamInterface_Pos_NoUsing;
my %Class_SubClasses;
my %Type_Typedef;
my %Typedef_BaseName;
my %NameSpaces;
my %NestedNameSpaces;
my %EnumMembers;
my %SubClass_Instance;
my %SubClass_ObjInstance;
my %BaseType_PLevel_Type;
my %Struct_SubClasses;
my %Struct_Parent;
my %Library_Prefixes;
my %Struct_Mapping;

# Interfaces
my %SymbolInfo;
my %CompleteSignature;
my %SkipInterfaces;
my %SkipInterfaces_Pattern;
my %Library_Class;
my %Library_Symbol;
my %DepLibrary_Symbol;
my %Symbol_Library;
my %DepSymbol_Library;
my %UndefinedSymbols;
my %Library_Needed;
my %Class_PureVirtFunc;
my %Class_Method;
my %Class_PureMethod;
my %Interface_Overloads;
my %OverloadedInterface;
my %InterfacesList;
my %MethodNames;
my %FuncNames;
my %GlobalDataNames;
my %Func_TypeId;
my %Header_Interface;
my %SoLib_IntPrefix;
my $NodeInterface;
my %LibGroups;
my %Interface_LibGroup;
my %AddIntParams;
my %Func_ShortName_MangledName;
my %UserDefinedOutParam;
my $LibraryMallocFunc;
my %LibraryInitFunc;
my %LibraryExitFunc;

# Headers
my @Include_Preamble;
my %SpecTypeHeaders;
my %SkipWarnings;
my %SkipWarnings_Pattern;
my %Include_Order;
my %Include_RevOrder;
my $IncludeString;
my %IncludePrefix;
my %SkipHeaders;

my %RegisteredHeaders;
my %RegisteredHeaders_R;

my %RegisteredIncludes;
my %RegisteredIncludes_R;

my %DirectIncludes;
my %RecursiveIncludes;
my %RecursiveIncludes_R;
my %KnownHeaders;
my %Include_Redirect;

my $MAX_INC = 0;

# Shared objects
my %UsedSharedObjects;
my %RegisteredLibs;
my $LibString;
my %KnownLibs;

# Default paths
my @DefaultLibPaths = (); # /usr/lib
my @DefaultIncPaths = (); # /usr/include

# Test results
my %GenResult;
my %BuildResult;
my %RunResult;
my %ResultCounter;

#Signals
my %SigNo;
my %SigName;

# Recursion locks
my @RecurTypeId;
my @RecurInterface;
my @RecurSpecType;

# Global state
my (%ValueCollection, %Block_Variable, %UseVarEveryWhere, %SpecEnv, %Block_InsNum, $MaxTypeId, %Wrappers,
%Wrappers_SubClasses, %IntSubClass, %IntrinsicNum, %AuxType, %AuxFunc, %UsedConstructors,
%ConstraintNum, %RequirementsCatalog, %UsedProtectedMethods, %Create_SubClass, %SpecCode,
%SpecLibs, %UsedInterfaces, %OpenStreams, %IntSpecType, %Block_Param, %Class_SubClassTypedef, %AuxHeaders,
%Template2Code_Defines, %TraceFunc);

# Block initialization
my $CurrentBlock;

# Special types
my %SpecType;
my %InterfaceSpecType;
my %Common_SpecEnv;
my %Common_SpecType_Exceptions;
my %ProxyValue = ();

# Report
my $ContentSpanStart = "<span class=\"section\" onclick=\"javascript:showContent(this, 'CONTENT_ID')\"><span class='ext' style='padding-right:2px'>[+]</span>\n";
my $ContentSpanStart_Title = "<span class=\"section_title\" onclick=\"javascript:showContent(this, 'CONTENT_ID')\"><span class='ext_title' style='padding-right:2px'>[+]</span>\n";
my $ContentSpanEnd = "</span>\n";
my $ContentDivStart = "<div id=\"CONTENT_ID\" style=\"display:none;\">\n";
my $ContentDivEnd = "</div>\n";
my $ContentID = 1;
my $Content_Counter = 0;

# Test Case
my $TestFormat;

# Recursion Locks
my @RecurLib;

# Debug
my %DebugInfo;

sub get_Modules()
{
    my $TOOL_DIR = get_dirname($0);
    if(not $TOOL_DIR)
    { # patch for MS Windows
        $TOOL_DIR = ".";
    }
    my @SEARCH_DIRS = (
        # tool's directory
        abs_path($TOOL_DIR),
        # relative path to modules
        abs_path($TOOL_DIR)."/../share/api-sanity-checker",
        # install path
        'MODULES_INSTALL_PATH'
    );
    foreach my $DIR (@SEARCH_DIRS)
    {
        if(not is_abs($DIR))
        { # relative path
            $DIR = abs_path($TOOL_DIR)."/".$DIR;
        }
        if(-d $DIR."/modules") {
            return $DIR."/modules";
        }
    }
    exitStatus("Module_Error", "can't find modules");
}

my %LoadedModules = ();

sub loadModule($)
{
    my $Name = $_[0];
    if(defined $LoadedModules{$Name}) {
        return;
    }
    my $Path = $MODULES_DIR."/Internals/$Name.pm";
    if(not -f $Path) {
        exitStatus("Module_Error", "can't access \'$Path\'");
    }
    require $Path;
    $LoadedModules{$Name} = 1;
}

sub readModule($$)
{
    my ($Module, $Name) = @_;
    my $Path = $MODULES_DIR."/Internals/$Module/".$Name;
    if(not -f $Path) {
        exitStatus("Module_Error", "can't access \'$Path\'");
    }
    return readFile($Path);
}

sub is_abs($) {
    return ($_[0]=~/\A(\/|\w+:[\/\\])/);
}

sub get_abs_path($)
{ # abs_path() should NOT be called for absolute inputs
  # because it can change them
    my $Path = $_[0];
    if(not is_abs($Path)) {
        $Path = abs_path($Path);
    }
    return $Path;
}

sub get_OSgroup()
{
    if($Config{"osname"}=~/macos|darwin|rhapsody/i) {
        return "macos";
    }
    elsif($Config{"osname"}=~/freebsd|openbsd|netbsd/i) {
        return "bsd";
    }
    elsif($Config{"osname"}=~/haiku|beos/i) {
        return "beos";
    }
    elsif($Config{"osname"}=~/symbian|epoc/i) {
        return "symbian";
    }
    elsif($Config{"osname"}=~/win/i) {
        return "windows";
    }
    else {
        return $Config{"osname"};
    }
}

sub detectDisplay()
{
    my $DISPLAY_NUM = 9; # default display number
    # use xprop to get a free display number
    foreach my $DNUM (9, 8, 7, 6, 5, 4, 3, 2, 10, 11, 12)
    { # try these display numbers only
        system("xprop -display :$DNUM".".0 -root >$TMP_DIR/null 2>&1");
        if($? ne 0)
        { # no properties found for this display, guess it is free
            $DISPLAY_NUM = $DNUM;
            last;
        }
    }
    return ":$DISPLAY_NUM.0";
}

sub runXvfb()
{
    # Find a free display to use for Xvfb
    my $XT_DISPLAY = detectDisplay();
    my $TEST_DISPLAY = $XT_DISPLAY;
    my $running = `pidof Xvfb`;
    chomp($running);
    if(not $running or $OSgroup!~/\A(linux|bsd)\Z/)
    {
        printMsg("INFO", "starting X Virtual Frame Buffer on the display $TEST_DISPLAY");
        system("Xvfb -screen 0 1024x768x24 $TEST_DISPLAY -ac +bs +kb -fp /usr/share/fonts/misc/ >$TMP_DIR/null 2>&1 & sleep 1");
        if($?) {
            exitStatus("Error", "can't start Xvfb: $?");
        }
        $ENV{"DISPLAY"} = $TEST_DISPLAY;
        $ENV{"G_SLICE"} = "always-malloc";
        return 1;
    }
    else
    {
        # Xvfb is running, determine the display number
        my $CMD_XVFB = `ps -p "$running" -f | tail -n 1`;
        chomp($CMD_XVFB);
        $CMD_XVFB=~/(\:\d+\.0)/;
        $XT_DISPLAY = $1;
        $ENV{"DISPLAY"} = $XT_DISPLAY;
        $ENV{"G_SLICE"} = "always-malloc";
        printMsg("INFO", "Xvfb is already running (display: $XT_DISPLAY), so it will be used");
        return 0;
    }
}

sub stopXvfb($)
{
    if($_[0]==1)
    {
        my $pid = `pidof Xvfb`;
        chomp($pid);
        if($pid) {
            kill(9, $pid);
        }
    }
}

sub parseTag($$)
{
    my ($CodeRef, $Tag) = @_;
    return "" if(not $CodeRef or not ${$CodeRef} or not $Tag);
    if(${$CodeRef}=~s/\<\Q$Tag\E\>((.|\n)+?)\<\/\Q$Tag\E\>//)
    {
        my $Content = $1;
        $Content=~s/\A[\n]+//g;
        while($Content=~s/\A([ \t]+[\n]+)//g){}
        $Content=~s/\A[\n]+//g;
        $Content=~s/\s+\Z//g;
        if($Content=~/\n/) {
            $Content = alignSpaces($Content);
        }
        else {
            $Content=~s/\A[ \t]+//g;
        }
        return $Content;
    }
    else {
        return "";
    }
}

sub add_os_spectypes()
{
    if($OSgroup eq "beos")
    { # http://www.haiku-os.org/legacy-docs/bebook/TheKernelKit_Miscellaneous.html
        readSpecTypes("
        <spec_type>
            <name>
                disable debugger in Haiku
            </name>
            <kind>
                common_env
            </kind>
            <global_code>
                #include <kernel/OS.h>
            </global_code>
            <init_code>
                disable_debugger(1);
            </init_code>
            <libs>
                libroot.so
            </libs>
            <associating>
                <except>
                    disable_debugger
                </except>
            </associating>
        </spec_type>");
    }
}

sub register_out_param($$$$)
{
    my ($Interface, $ParamPos, $ParamName, $ParamTypeId) = @_;
    $OutParamInterface_Pos{$Interface}{$ParamPos}=1;
    $Interface_OutParam{$Interface}{$ParamName}=1;
    $BaseType_PLevel_OutParam{get_FoundationTypeId($ParamTypeId)}{get_PointerLevel($ParamTypeId)-1}{$Interface}=1;
    foreach my $TypeId (get_OutParamFamily($ParamTypeId, 0)) {
        $OutParam_Interface{$TypeId}{$Interface}=$ParamPos;
    }
}

sub cmpVersions($$)
{ # compare two versions in dotted-numeric format
    my ($V1, $V2) = @_;
    return 0 if($V1 eq $V2);
    my @V1Parts = split(/\./, $V1);
    my @V2Parts = split(/\./, $V2);
    for (my $i = 0; $i <= $#V1Parts && $i <= $#V2Parts; $i++)
    {
        return -1 if(int($V1Parts[$i]) < int($V2Parts[$i]));
        return 1 if(int($V1Parts[$i]) > int($V2Parts[$i]));
    }
    return -1 if($#V1Parts < $#V2Parts);
    return 1 if($#V1Parts > $#V2Parts);
    return 0;
}

sub numToStr($)
{
    my $Number = int($_[0]);
    if($Number>3) {
        return $Number."th";
    }
    elsif($Number==1) {
        return "1st";
    }
    elsif($Number==2) {
        return "2nd";
    }
    elsif($Number==3) {
        return "3rd";
    }
    else {
        return $Number;
    }
}

sub readSpecTypes($)
{
    my $Package = $_[0];
    return if(not $Package);
    $Package=~s/\/\*(.|\n)+?\*\///g; # remove C++ comments
    $Package=~s/<\!--(.|\n)+?-->//g; # remove XML comments
    if($Package!~/<collection>/ or $Package!~/<\/collection>/)
    { # add <collection> tag (support for old spectype packages)
        $Package = "<collection>\n".$Package."\n</collection>";
    }
    while(my $Collection = parseTag(\$Package, "collection"))
    {
        # import specialized types
        while(my $SpecType = parseTag(\$Collection, "spec_type"))
        {
            $ST_ID+=1;
            my (%Attr, %DataTypes) = ();
            $Attr{"Kind"} = parseTag(\$SpecType, "kind");
            $Attr{"Kind"} = "normal" if(not $Attr{"Kind"});
            foreach my $DataType (split(/\n/, parseTag(\$SpecType, "data_type")),
            split(/\n/, parseTag(\$SpecType, "data_types")))
            { # data_type==data_types, support of <= 1.5 versions
                $DataTypes{$DataType} = 1;
                if(not get_TypeIdByName($DataType)) {
                    printMsg("ERROR", "unknown data type \'$DataType\' in one of the \'".$Attr{"Kind"}."\' spectypes, try to define it more exactly");
                }
            }
            if(not keys(%DataTypes) and $Attr{"Kind"}=~/\A(normal|common_param|common_retval)\Z/)
            {
                printMsg("ERROR", "missed \'data_type\' attribute in one of the \'".$Attr{"Kind"}."\' spectypes");
                next;
            }
            $Attr{"Name"} = parseTag(\$SpecType, "name");
            $Attr{"Value"} = parseTag(\$SpecType, "value");
            $Attr{"PreCondition"} = parseTag(\$SpecType, "pre_condition");
            $Attr{"PostCondition"} = parseTag(\$SpecType, "post_condition");
            if(not $Attr{"PostCondition"})
            { # constraint==post_condition, support of <= 1.6 versions
                $Attr{"PostCondition"} = parseTag(\$SpecType, "constraint");
            }
            $Attr{"InitCode"} = parseTag(\$SpecType, "init_code");
            $Attr{"DeclCode"} = parseTag(\$SpecType, "decl_code");
            $Attr{"FinalCode"} = parseTag(\$SpecType, "final_code");
            $Attr{"GlobalCode"} = parseTag(\$SpecType, "global_code");
            foreach my $Lib (split(/\n/, parseTag(\$SpecType, "libs"))) {
                $Attr{"Libs"}{$Lib} = 1;
            }
            if($Attr{"Kind"} eq "common_env") {
                $Common_SpecEnv{$ST_ID} = 1;
            }
            while(my $Associating = parseTag(\$SpecType, "associating"))
            {
                my (%Interfaces, %Except) = ();
                foreach my $Interface (split(/\n/, parseTag(\$Associating, "interfaces")),
                split(/\n/, parseTag(\$Associating, "symbols")))
                {
                    $Interface=~s/\A\s+|\s+\Z//g;
                    $Interfaces{$Interface} = 1;
                    $Common_SpecType_Exceptions{$Interface}{$ST_ID} = 0;
                    if($Interface=~/\*/)
                    {
                        $Interface=~s/\*/.*/;
                        foreach my $Int (keys(%CompleteSignature))
                        {
                            if($Int=~/\A$Interface\Z/)
                            {
                                $Common_SpecType_Exceptions{$Int}{$ST_ID} = 0;
                                $Interfaces{$Interface} = 1;
                            }
                        }
                    }
                    elsif(not defined $CompleteSignature{$Interface}
                    or not $CompleteSignature{$Interface}{"ShortName"}) {
                        printMsg("ERROR", "unknown symbol $Interface");
                    }
                }
                foreach my $Interface (split(/\n/, parseTag(\$Associating, "except")))
                {
                    $Interface=~s/\A\s+|\s+\Z//g;
                    $Except{$Interface} = 1;
                    $Common_SpecType_Exceptions{$Interface}{$ST_ID} = 1;
                    if($Interface=~/\*/)
                    {
                        $Interface=~s/\*/.*/;
                        foreach my $Int (keys(%CompleteSignature))
                        {
                            if($Int=~/\A$Interface\Z/)
                            {
                                $Common_SpecType_Exceptions{$Int}{$ST_ID} = 1;
                                $Except{$Int} = 1;
                            }
                        }
                    }
                }
                if($Attr{"Kind"} eq "env")
                {
                    foreach my $Interface (keys(%Interfaces))
                    {
                        next if($Except{$Interface});
                        $InterfaceSpecType{$Interface}{"SpecEnv"} = $ST_ID;
                    }
                }
                else
                {
                    foreach my $Link (split(/\n/, parseTag(\$Associating, "links").parseTag(\$Associating, "param_num")))
                    {
                        $Link=~s/\A\s+|\s+\Z//g;
                        if(lc($Link)=~/\Aparam(\d+)\Z/)
                        {
                            my $Param_Num = $1;
                            foreach my $Interface (keys(%Interfaces))
                            {
                                next if($Except{$Interface});
                                if(defined $InterfaceSpecType{$Interface}{"SpecParam"}{$Param_Num - 1}) {
                                    printMsg("ERROR", "more than one spectypes have been linked to ".numToStr($Param_Num)." parameter of $Interface");
                                }
                                $InterfaceSpecType{$Interface}{"SpecParam"}{$Param_Num - 1} = $ST_ID;
                            }
                        }
                        elsif(lc($Link)=~/\Aobject\Z/)
                        {
                            foreach my $Interface (keys(%Interfaces))
                            {
                                next if($Except{$Interface});
                                if(defined $InterfaceSpecType{$Interface}{"SpecObject"}) {
                                    printMsg("ERROR", "more than one spectypes have been linked to calling object of $Interface");
                                }
                                $InterfaceSpecType{$Interface}{"SpecObject"} = $ST_ID;
                            }
                        }
                        elsif(lc($Link)=~/\Aretval\Z/)
                        {
                            foreach my $Interface (keys(%Interfaces))
                            {
                                next if($Except{$Interface});
                                if(defined $InterfaceSpecType{$Interface}{"SpecReturn"}) {
                                    printMsg("ERROR", "more than one spectypes have been linked to return value of $Interface");
                                }
                                $InterfaceSpecType{$Interface}{"SpecReturn"} = $ST_ID;
                            }
                        }
                        else {
                            printMsg("ERROR", "unrecognized link \'$Link\' in one of the \'".$Attr{"Kind"}."\' spectypes");
                        }
                    }
                    foreach my $Name (split(/\n/, parseTag(\$Associating, "param_name")))
                    {
                        $Name=~s/\A\s+|\s+\Z//g;
                        if(keys(%Interfaces))
                        {
                            foreach my $Interface (keys(%Interfaces))
                            {
                                next if($Except{$Interface});
                                foreach my $ParamPos (keys(%{$CompleteSignature{$Interface}{"Param"}}))
                                {
                                    if($Name eq $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"name"}) {
                                        $InterfaceSpecType{$Interface}{"SpecParam"}{$ParamPos} = $ST_ID;
                                    }
                                }
                            }
                        }
                        else
                        {
                            foreach my $Interface (keys(%CompleteSignature))
                            {
                                next if($Except{$Interface});
                                foreach my $ParamPos (keys(%{$CompleteSignature{$Interface}{"Param"}}))
                                {
                                    if($Name eq $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"name"})
                                    {
                                        my $TypeId_Param = $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"type"};
                                        my $FTypeId_Param = get_FoundationTypeId($TypeId_Param);
                                        my $FTypeType_Param = get_TypeType($FTypeId_Param);
                                        foreach my $DataType (keys(%DataTypes))
                                        {
                                            my $TypeId = get_TypeIdByName($DataType);
                                            if(my $FTypeId = get_FoundationTypeId($TypeId) and $FTypeId_Param)
                                            {
                                                if($FTypeType_Param eq "Intrinsic"?$TypeId==$TypeId_Param:$FTypeId==$FTypeId_Param) {
                                                    $InterfaceSpecType{$Interface}{"SpecParam"}{$ParamPos} = $ST_ID;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if($Attr{"Kind"}=~/\A(common_param|common_retval)\Z/)
            {
                foreach my $DataType (keys(%DataTypes))
                {
                    $Attr{"DataType"} = $DataType;
                    %{$SpecType{$ST_ID}} = %Attr;
                    $ST_ID+=1;
                }
            }
            elsif($Attr{"Kind"} eq "normal")
            {
                $Attr{"DataType"} = (keys(%DataTypes))[0];
                %{$SpecType{$ST_ID}} = %Attr;
            }
            else {
                %{$SpecType{$ST_ID}} = %Attr;
            }
        }
    }
}

sub join_P($$)
{
    my $S = "/";
    if($OSgroup eq "windows") {
        $S = "\\";
    }
    return join($S, @_);
}

sub registerHeader($$)
{
    my ($Path, $To) = @_;
    
    $Path = get_abs_path($Path);
    
    my $Name = get_filename($Path);
    if(not defined $To->{$Name})
    {
        $To->{$Name} = $Path;
        if(my $Prefix = getFilePrefix($Path)) {
            $To->{join_P($Prefix, $Name)} = $Path;
        }
    }
}

sub registerDir($)
{
    my $Path = $_[0];
    foreach my $P (sort {length($b)<=>length($a)} cmd_find($Path,"f","",""))
    { # NOTE: duplicated
        registerHeader($P, \%RegisteredHeaders);
        $RegisteredHeaders_R{$P} = 1;
    }
}

sub getFilePrefix($)
{
    if(my $Dir = get_dirname($_[0]))
    {
        if($Dir = get_filename($Dir))
        {
            if($Dir ne "include"
            and $Dir=~/\A[a-z]+\Z/i) {
                return $Dir;
            }
        }
    }
    return undef;
}

sub registerHeaders($)
{
    my $Path = $_[0];
    
    $Path = get_abs_path($Path);
    
    if(-d $Path) {
        registerDir($Path);
    }
    elsif(-f $Path)
    {
        registerHeader($Path, \%RegisteredHeaders);
        $RegisteredHeaders_R{$Path} = 1;
        
        if(my $Dir = get_dirname($Path)) {
            registerDir($Dir);
        }
    }
}

sub registerLibs($)
{
    my $Path = $_[0];
    $Path = get_abs_path($Path);
    if(-d $Path)
    {
        foreach my $P (cmd_find($Path,"f","","")) {
            $RegisteredLibs{get_filename($P)} = $P;
        }
    }
    elsif(-f $Path) {
        $RegisteredLibs{get_filename($Path)} = $Path;
    }
}

sub push_U($@)
{ # push unique
    if(my $Array = shift @_)
    {
        if(@_)
        {
            my %Exist = map {$_=>1} @{$Array};
            foreach my $Elem (@_)
            {
                if(not defined $Exist{$Elem})
                {
                    push(@{$Array}, $Elem);
                    $Exist{$Elem} = 1;
                }
            }
        }
    }
}

sub readDescriptor($)
{
    my $Path = $_[0];
    
    my $Content = readFile($Path);
    if(not $Content) {
        exitStatus("Error", "library descriptor is empty");
    }
    if($Content!~/\</) {
        exitStatus("Error", "incorrect descriptor (see -d option)");
    }
    $Content=~s/\/\*(.|\n)+?\*\///g;
    $Content=~s/<\!--(.|\n)+?-->//g;
    
    if($OSgroup!~/win/) {
        $Content=~s/([^\\])\\ /$1 /g;
    }
    
    $Descriptor{"Version"} = parseTag(\$Content, "version");
    $Descriptor{"Version"} = $TargetVersion if($TargetVersion);
    if(not $Descriptor{"Version"}) {
        exitStatus("Error", "version in the descriptor is not specified (section <version>)");
    }
    if($Content=~/{RELPATH}/)
    {
        if($RelativeDirectory)  {
            $Content =~ s/{RELPATH}/$RelativeDirectory/g;
        }
        else {
            exitStatus("Error", "you have not specified -relpath option, but the descriptor contains {RELPATH} macro");
        }
    }
    
    $Descriptor{"Headers"} = parseTag(\$Content, "headers");
    $Descriptor{"Libs"} = parseTag(\$Content, "libs");
    
    $Descriptor{"SkipHeaders"} = parseTag(\$Content, "skip_headers");
    $Descriptor{"SkipIncluding"} = parseTag(\$Content, "skip_including");
    
    foreach my $Header (split(/\s*\n\s*/, parseTag(\$Content, "test_include_preamble")))
    {
        push_U(\@Include_Preamble, $Header);
    }
    foreach my $Order (split(/\s*\n\s*/, parseTag(\$Content, "include_order")))
    {
        if($Order=~/\A(.+):(.+)\Z/) {
            $Include_Order{$2} = $1;
        }
    }
    # $Include_Order{"freetype.h"} = "ft2build.h";
    %Include_RevOrder = reverse(%Include_Order);
    
    foreach my $Interface_Name (split(/\s*\n\s*/, parseTag(\$Content, "skip_interfaces")),
    split(/\s*\n\s*/, parseTag(\$Content, "skip_symbols")))
    {
        if($Interface_Name=~s/\*/.*/g) {
            $SkipInterfaces_Pattern{$Interface_Name} = 1;
        }
        else {
            $SkipInterfaces{$Interface_Name} = 1;
        }
    }
    foreach my $Type_Name (split(/\s*\n\s*/, parseTag(\$Content, "opaque_types")))
    {
        $OpaqueTypes{$Type_Name} = 1;
    }
    foreach my $Warning (split(/\s*\n\s*/, parseTag(\$Content, "skip_warnings")))
    {
        if($Warning=~s/\*/.*/g) {
            $SkipWarnings_Pattern{$Warning} = 1;
        }
        else {
            $SkipWarnings{$Warning} = 1;
        }
    }
    
    while(my $LibGroupTag = parseTag(\$Content, "libgroup"))
    {
        my $LibGroupName = parseTag(\$LibGroupTag, "name");
        foreach my $Interface (split(/\s*\n\s*/, parseTag(\$LibGroupTag, "interfaces")),
        split(/\s*\n\s*/, parseTag(\$LibGroupTag, "symbols")))
        {
            $LibGroups{$LibGroupName}{$Interface} = 1;
            $Interface_LibGroup{$Interface}=$LibGroupName;
        }
    }
    if(keys(%Interface_LibGroup))
    {
        if(keys(%InterfacesList)) {
            %InterfacesList=();
        }
        foreach my $LibGroup (keys(%LibGroups))
        {
            foreach my $Interface (keys(%{$LibGroups{$LibGroup}})) {
                $InterfacesList{$Interface}=1;
            }
        }
    }
    
    my (@Opt_Libs, @Opt_Flags) = ();
    foreach my $Option (split(/\s*\n\s*/, parseTag(\$Content, "gcc_options")))
    {
        if($Option=~/\A\-(Wl|l|L)/
        or $Option=~/\.$LIB_EXT[0-9.]*\Z/)
        { # to linker
            push(@Opt_Libs, $Option);
        }
        else {
            push(@Opt_Flags, $Option);
        }
    }
    
    if(@Opt_Libs) {
        $CompilerOptions_Libs = join(" ", @Opt_Libs);
    }
    
    if(@Opt_Flags) {
        $CompilerOptions_Cflags = join(" ", @Opt_Flags);
    }
    
    if(my $DDefines = parseTag(\$Content, "test_defines"))
    {
        $Descriptor{"Defines"} .= "\n".$DDefines;
    }
    foreach my $Dep (split(/\s*\n\s*/, parseTag(\$Content, "libs_depend")))
    {
        if(not -f $Dep) {
            exitStatus("Access_Error", "can't access \'$Dep\': no such file");
        }
        $Dep = abs_path($Dep) if($Dep!~/\A(\/|\w+:[\/\\])/);
        $LibsDepend{$Dep} = 1;
    }
    foreach my $IntParam (split(/\s*\n\s*/, parseTag(\$Content, "out_params")))
    {
        if($IntParam=~/(.+)(:|;)(.+)/) {
            $UserDefinedOutParam{$1}{$3} = 1;
        }
    }
}

sub getArch()
{
    my $Arch = $ENV{"CPU"};
    if(not $Arch)
    {
        if($OSgroup=~/linux|bsd|macos/)
        {
            $Arch = `uname -m`;
            chomp($Arch);
            if(not $Arch)
            {
                $Arch = `uname -p`;
                chomp($Arch);
            }
        }
    }
    if(not $Arch) {
        $Arch = $Config{"archname"};
    }
    $Arch = "x86" if($Arch=~/i[3-7]86/);
    if($OSgroup eq "windows")
    {
        $Arch = "x86" if($Arch=~/win32/i);
        $Arch = "x86-64" if($Arch=~/win64/i);
    }
    $Arch=~s/\-multi\-thread(-|\Z)//g;
    return $Arch;
}

sub get_Summary()
{
    my $Summary = "<h2>Summary</h2><hr/>";
    $Summary .= "<table cellpadding='3' class='summary'>";
    my $Verdict = "";
    if($ResultCounter{"Run"}{"Fail"} > 0)
    {
        $Verdict = "<span style='color:Red;'><b>Test Failed</b></span>";
        $STAT_FIRST_LINE .= "verdict:failed;";
    }
    else
    {
        $Verdict = "<span style='color:Green;'><b>Test Passed</b></span>";
        $STAT_FIRST_LINE .= "verdict:passed;";
    }
    $Summary .= "<tr><th>Total tests</th><td>".($ResultCounter{"Run"}{"Success"}+$ResultCounter{"Run"}{"Fail"})."</td></tr>";
    $STAT_FIRST_LINE .= "total:".($ResultCounter{"Run"}{"Success"}+$ResultCounter{"Run"}{"Fail"}).";";
    my $Success_Tests_Link = "0";
    $Success_Tests_Link = $ResultCounter{"Run"}{"Success"} if($ResultCounter{"Run"}{"Success"}>0);
    $STAT_FIRST_LINE .= "passed:".$ResultCounter{"Run"}{"Success"}.";";
    my $Failed_Tests_Link = "0";
    $Failed_Tests_Link = "<a href='#Failed_Tests'>".$ResultCounter{"Run"}{"Fail"}."</a>" if($ResultCounter{"Run"}{"Fail"}>0);
    $STAT_FIRST_LINE .= "failed:".$ResultCounter{"Run"}{"Fail"}.";";
    $Summary .= "<tr><th>Passed / Failed tests</th><td>$Success_Tests_Link / $Failed_Tests_Link</td></tr>";
    if($ResultCounter{"Run"}{"Warnings"}>0)
    {
        my $Warnings_Link = "<a href='#Warnings'>".$ResultCounter{"Run"}{"Warnings"}."</a>";
        $Summary .= "<tr><th>Warnings</th><td>$Warnings_Link</td></tr>";
    }
    $STAT_FIRST_LINE .= "warnings:".$ResultCounter{"Run"}{"Warnings"};
    $Summary .= "<tr><th>Verdict</th><td>$Verdict</td></tr>";
    $Summary .= "</table>\n";
    return $Summary;
}

sub get_Problem_Summary()
{
    my $Problem_Summary = "";
    my %ProblemType_Interface = ();
    foreach my $Interface (keys(%RunResult))
    {
        next if($RunResult{$Interface}{"Warnings"});
        $ProblemType_Interface{$RunResult{$Interface}{"Type"}}{$Interface} = 1;
    }
    my $ColSpan = 1;
    my $SignalException = ($OSgroup eq "windows")?"Exception":"Signal";
    my $ProblemType = "Received_".$SignalException;
    if(keys(%{$ProblemType_Interface{$ProblemType}}))
    {
        my %SignalName_Interface = ();
        foreach my $Interface (keys(%{$ProblemType_Interface{"Received_$SignalException"}})) {
            $SignalName_Interface{$RunResult{$Interface}{"Value"}}{$Interface} = 1;
        }
        if(keys(%SignalName_Interface)==1)
        {
            my $SignalName = (keys(%SignalName_Interface))[0];
            my $Amount = keys(%{$SignalName_Interface{$SignalName}});
            my $Link = "<a href=\'#".$ProblemType."_".$SignalName."\'>$Amount</a>";
            $STAT_FIRST_LINE .= lc($ProblemType."_".$SignalName.":$Amount;");
            $Problem_Summary .= "<tr><th>Received ".lc($SignalException)." $SignalName</th><td>$Link</td></tr>";
        }
        elsif(keys(%SignalName_Interface)>1)
        {
            $Problem_Summary .= "<tr><th rowspan='".keys(%SignalName_Interface)."'>Received ".lc($SignalException)."</th>";
            my $num = 1;
            foreach my $SignalName (sort keys(%SignalName_Interface))
            {
                my $Amount = keys(%{$SignalName_Interface{$SignalName}});
                my $Link = "<a href=\'#".$ProblemType."_".$SignalName."\'>$Amount</a>";
                $STAT_FIRST_LINE .= lc($ProblemType."_".$SignalName.":$Amount;");
                $Problem_Summary .= (($num!=1)?"<tr>":"")."<th>$SignalName</th><td>$Link</td></tr>";
                $num+=1;
            }
            $ColSpan = 2;
        }
    }
    if(keys(%{$ProblemType_Interface{"Exited_With_Value"}}))
    {
        my %ExitValue_Interface = ();
        foreach my $Interface (keys(%{$ProblemType_Interface{"Exited_With_Value"}}))
        {
            $ExitValue_Interface{$RunResult{$Interface}{"Value"}}{$Interface} = 1;
        }
        if(keys(%ExitValue_Interface)==1)
        {
            my $ExitValue = (keys(%ExitValue_Interface))[0];
            my $Amount = keys(%{$ExitValue_Interface{$ExitValue}});
            my $Link = "<a href=\'#Exited_With_Value_$ExitValue\'>$Amount</a>";
            $STAT_FIRST_LINE .= lc("Exited_With_Value_$ExitValue:$Amount;");
            $Problem_Summary .= "<tr><th colspan=\'$ColSpan\'>Exited with value \"$ExitValue\"</th><td>$Link</td></tr>";
        }
        elsif(keys(%ExitValue_Interface)>1)
        {
            $Problem_Summary .= "<tr><th rowspan='".keys(%ExitValue_Interface)."'>Exited with value</th>";
            foreach my $ExitValue (sort keys(%ExitValue_Interface))
            {
                my $Amount = keys(%{$ExitValue_Interface{$ExitValue}});
                my $Link = "<a href=\'#Exited_With_Value_$ExitValue\'>$Amount</a>";
                $STAT_FIRST_LINE .= lc("Exited_With_Value_$ExitValue:$Amount;");
                $Problem_Summary .= "<th>\"$ExitValue\"</th><td>$Link</td></tr>";
            }
            $Problem_Summary .= "</tr>";
            $ColSpan = 2;
        }
    }
    if(keys(%{$ProblemType_Interface{"Hanged_Execution"}}))
    {
        my $Amount = keys(%{$ProblemType_Interface{"Hanged_Execution"}});
        my $Link = "<a href=\'#Hanged_Execution\'>$Amount</a>";
        $STAT_FIRST_LINE .= "hanged_execution:$Amount;";
        $Problem_Summary .= "<tr><th colspan=\'$ColSpan\'>Hanged execution</th><td>$Link</td></tr>";
    }
    if(keys(%{$ProblemType_Interface{"Requirement_Failed"}}))
    {
        my $Amount = keys(%{$ProblemType_Interface{"Requirement_Failed"}});
        my $Link = "<a href=\'#Requirement_Failed\'>$Amount</a>";
        $STAT_FIRST_LINE .= "requirement_failed:$Amount;";
        $Problem_Summary .= "<tr><th colspan=\'$ColSpan\'>Requirement failed</th><td>$Link</td></tr>";
    }
    if(keys(%{$ProblemType_Interface{"Other_Problems"}}))
    {
        my $Amount = keys(%{$ProblemType_Interface{"Other_Problems"}});
        my $Link = "<a href=\'#Other_Problems\'>$Amount</a>";
        $STAT_FIRST_LINE .= "other_problems:$Amount;";
        $Problem_Summary .= "<tr><th colspan=\'$ColSpan\'>Other problems</th><td>$Link</td></tr>";
    }
    if($Problem_Summary)
    {
        $Problem_Summary = "<h2>Problem Summary</h2><hr/>"."<table cellpadding='3' class='summary'>".$Problem_Summary."</table>\n";
        return $Problem_Summary;
    }
    else
    {
        return "";
    }
}

sub get_Report_Header()
{
    my $Report_Header = "<h1>Test results for the <span style='color:Blue;'>$TargetTitle</span>-<span style='color:Blue;'>".$Descriptor{"Version"}."</span> library on <span style='color:Blue;'>".getArch()."</span></h1>\n";
    return $Report_Header;
}

sub get_TestSuite_Header()
{
    my $Report_Header = "<h1>Test suite for the <span style='color:Blue;'>$TargetTitle</span>-<span style='color:Blue;'>".$Descriptor{"Version"}."</span> library on <span style='color:Blue;'>".getArch()."</span></h1>\n";
    return $Report_Header;
}

sub get_problem_title($$)
{
    my ($ProblemType, $Value) = @_;
    if($ProblemType eq "Received_Signal") {
        return "Received signal $Value";
    }
    elsif($ProblemType eq "Received_Exception") {
        return "Received exception $Value";
    }
    elsif($ProblemType eq "Exited_With_Value") {
        return "Exited with value \"$Value\"";
    }
    elsif($ProblemType eq "Requirement_Failed") {
        return "Requirement failed";
    }
    elsif($ProblemType eq "Hanged_Execution") {
        return "Hanged execution";
    }
    elsif($ProblemType eq "Unexpected_Output") {
        return "Unexpected Output";
    }
    elsif($ProblemType eq "Other_Problems") {
        return "Other problems";
    }
    else {
        return "";
    }
}

sub get_count_title($$)
{
    my ($Word, $Number) = @_;
    if($Number>=2 or $Number==0) {
        return "$Number $Word"."s";
    }
    elsif($Number==1) {
        return "1 $Word";
    }
}

sub get_TestView($$)
{
    my ($Test, $Interface) = @_;
    
    $Test = highlight_code($Test, $Interface);
    $Test = htmlSpecChars($Test, 1);
    
    $Test=~s/\@LT\@/</g;
    $Test=~s/\@GT\@/>/g;
    $Test=~s/\@SP\@/ /g;
    $Test=~s/\@NL\@/\n/g;
    
    my $Table = "";
    $Table .= "<table cellspacing='0' class='test_view'>\n";
    $Table .= "<tr><td colspan='2'>&nbsp;</td></tr>\n";
    
    my @Lines = split(/\n/, $Test);
    
    foreach my $N (0 .. $#Lines)
    {
        my $Line = $Lines[$N];
        
        $Table .= "<tr>";
        $Table .= "<th>".($N+1)."</th>";
        $Table .= "<td><pre>$Line</pre></td>";
        $Table .= "</tr>\n";
    }
    
    $Table .= "<tr><td colspan='2'>&nbsp;</td></tr>\n";
    $Table .= "</table>\n";
    
    return $Table;
}

sub rm_prefix($)
{
    my $Str = $_[0];
    $Str=~s/\A[_~]+//g;
    return $Str;
}

sub select_Symbol_NS($)
{
    my $Symbol = $_[0];
    return "" if(not $Symbol);
    my $NS = $CompleteSignature{$Symbol}{"NameSpace"};
    if(not $NS)
    {
        if(my $Class = $CompleteSignature{$Symbol}{"Class"}) {
            $NS = $TypeInfo{$Class}{"NameSpace"};
        }
    }
    if($NS)
    {
        if(defined $NestedNameSpaces{$NS}) {
            return $NS;
        }
        else
        {
            while($NS=~s/::[^:]+\Z//)
            {
                if(defined $NestedNameSpaces{$NS}) {
                    return $NS;
                }
            }
        }
    }
    
    return "";
}

sub get_TestSuite_List()
{
    my ($TEST_LIST, %LibGroup_Header_Interface);
    my $Tests_Num = 0;
    return "" if(not keys(%Interface_TestDir));
    foreach my $Interface (keys(%Interface_TestDir))
    {
        my $Header = get_filename($CompleteSignature{$Interface}{"Header"});
        my $SharedObject = get_filename($Symbol_Library{$Interface});
        $SharedObject = get_filename($DepSymbol_Library{$Interface}) if(not $SharedObject);
        $LibGroup_Header_Interface{$Interface_LibGroup{$Interface}}{$SharedObject}{$Header}{$Interface} = 1;
        $Tests_Num += 1;
    }
    foreach my $LibGroup (sort {lc($a) cmp lc($b)} keys(%LibGroup_Header_Interface))
    {
        foreach my $SoName (sort {($a eq "") cmp ($b eq "")} sort {lc($a) cmp lc($b)} keys(%{$LibGroup_Header_Interface{$LibGroup}}))
        {
            foreach my $HeaderName (sort {lc($a) cmp lc($b)} keys(%{$LibGroup_Header_Interface{$LibGroup}{$SoName}}))
            {
                my %NameSpace_Interface = ();
                foreach my $Interface (keys(%{$LibGroup_Header_Interface{$LibGroup}{$SoName}{$HeaderName}})) {
                    $NameSpace_Interface{select_Symbol_NS($Interface)}{$Interface} = 1;
                }
                
                foreach my $NameSpace (sort keys(%NameSpace_Interface))
                {
                    $TEST_LIST .= getTitle($HeaderName, $SoName, $LibGroup, $NameSpace);
                    
                    my @SortedSymbols = sort keys(%{$NameSpace_Interface{$NameSpace}});
                    
                    @SortedSymbols = sort {lc(rm_prefix($CompleteSignature{$a}{"ShortName"})) cmp lc(rm_prefix($CompleteSignature{$b}{"ShortName"}))} @SortedSymbols;
                    @SortedSymbols = sort {$CompleteSignature{$a}{"Destructor"} <=> $CompleteSignature{$b}{"Destructor"}} @SortedSymbols;
                    @SortedSymbols = sort {lc(get_TypeName($CompleteSignature{$a}{"Class"})) cmp lc(get_TypeName($CompleteSignature{$b}{"Class"}))} @SortedSymbols;
                    
                    foreach my $Symbol (@SortedSymbols)
                    {
                        my $RelPath = $Interface_TestDir{$Symbol};
                        $RelPath=~s/\A\Q$TEST_SUITE_PATH\E[\/\\]*//g;
                        my $Signature = get_Signature($Symbol);
                        if($NameSpace) {
                            $Signature=~s/(\W|\A)\Q$NameSpace\E\:\:(\w)/$1$2/g;
                        }
                        $RelPath=~s/:/\%3A/g;
                        $TEST_LIST .= "<a class='link' href=\'$RelPath/view.html\'><span class='int'>";
                        $TEST_LIST .= highLight_Signature_Italic_Color($Signature);
                        $TEST_LIST .= "</span></a><br/>\n";
                    }
                    $TEST_LIST .= "<br/>\n";
                }
            }
        }
    }
    $STAT_FIRST_LINE .= "total:$Tests_Num";
    return "<h2>Tests ($Tests_Num)</h2><hr/>\n".$TEST_LIST."<a style='font-size:11px;' href='#Top'>to the top</a><br/>\n";
}

sub getTitle($$$$)
{
    my ($Header, $Library, $LibGroup, $NameSpace) = @_;
    
    if($Library and $Library!~/\.\w+\Z/) {
        $Library .= " (.$LIB_EXT)";
    }
    
    my $Title = "";
    if($Header and $Library)
    {
        $Title .= "<span class='header'>$Header</span>";
        $Title .= ", <span class='lib_name'>$Library</span><br/>\n";
    }
    elsif($Library) {
        $Title .= "<span class='lib_name'>$Library</span><br/>\n";
    }
    elsif($Header) {
        $Title .= "<span class='header'>$Header</span><br/>\n";
    }
    if($LibGroup) {
        $Title .= "&nbsp;<span class='libgroup'>\"$LibGroup\"</span>\n";
    }
    if($NameSpace) {
        $Title .= "<span class='ns'>namespace <b>$NameSpace</b></span><br/>\n";
    }
    return $Title;
}

sub get_FailedTests($)
{
    my $Kind = $_[0];# Failures or Warnings
    my ($FAILED_TESTS, %Type_Value_LibGroup_Header_Interface);
    foreach my $Interface (keys(%RunResult))
    {
        if($Kind eq "Failures") {
            next if($RunResult{$Interface}{"Warnings"});
        }
        elsif($Kind eq "Warnings") {
            next if(not $RunResult{$Interface}{"Warnings"});
        }
        my $Header = get_filename($RunResult{$Interface}{"Header"});
        my $SharedObject = $RunResult{$Interface}{"SharedObject"};
        my $ProblemType = $RunResult{$Interface}{"Type"};
        my $ProblemValue = $RunResult{$Interface}{"Value"};
        $Type_Value_LibGroup_Header_Interface{$ProblemType}{$ProblemValue}{$Interface_LibGroup{$Interface}}{$SharedObject}{$Header}{$Interface} = 1;
    }
    foreach my $ProblemType ("Received_Signal", "Received_Exception", "Exited_With_Value", "Hanged_Execution", "Requirement_Failed", "Unexpected_Output", "Other_Problems")
    {
        next if(not keys(%{$Type_Value_LibGroup_Header_Interface{$ProblemType}}));
        foreach my $ProblemValue (sort keys(%{$Type_Value_LibGroup_Header_Interface{$ProblemType}}))
        {
            my $PROBLEM_REPORT = "<br/>\n";
            my $Problems_Count = 0;
            foreach my $LibGroup (sort {lc($a) cmp lc($b)} keys(%{$Type_Value_LibGroup_Header_Interface{$ProblemType}{$ProblemValue}}))
            {
                foreach my $SoName (sort {($a eq "") cmp ($b eq "")} sort {lc($a) cmp lc($b)} keys(%{$Type_Value_LibGroup_Header_Interface{$ProblemType}{$ProblemValue}{$LibGroup}}))
                {
                    foreach my $HeaderName (sort {lc($a) cmp lc($b)} keys(%{$Type_Value_LibGroup_Header_Interface{$ProblemType}{$ProblemValue}{$LibGroup}{$SoName}}))
                    {
                        next if(not $HeaderName or not $SoName);
                        my $HEADER_LIB_REPORT = "";
                        
                        my %NameSpace_Interface = ();
                        foreach my $Interface (keys(%{$Type_Value_LibGroup_Header_Interface{$ProblemType}{$ProblemValue}{$LibGroup}{$SoName}{$HeaderName}})) {
                            $NameSpace_Interface{$RunResult{$Interface}{"NameSpace"}}{$Interface} = 1;
                        }
                        foreach my $NameSpace (sort keys(%NameSpace_Interface))
                        {
                            $HEADER_LIB_REPORT .= getTitle($HeaderName, $SoName, $LibGroup, $NameSpace);
                            my @SortedInterfaces = sort {$RunResult{$a}{"Signature"} cmp $RunResult{$b}{"Signature"}} keys(%{$NameSpace_Interface{$NameSpace}});
                            foreach my $Interface (@SortedInterfaces)
                            {
                                my $Signature = $RunResult{$Interface}{"Signature"};
                                if($NameSpace) {
                                    $Signature=~s/(\W|\A)\Q$NameSpace\E\:\:(\w)/$1$2/g;
                                }
                                my $Info = $RunResult{$Interface}{"Info"};
                                my $Test = $RunResult{$Interface}{"Test"};
                                $HEADER_LIB_REPORT .= $ContentSpanStart;
                                if($Signature) {
                                    $HEADER_LIB_REPORT .= highLight_Signature_Italic_Color($Signature);
                                }
                                else {
                                    $HEADER_LIB_REPORT .= $Interface;
                                }
                                $HEADER_LIB_REPORT .= $ContentSpanEnd."<br/>\n";
                                $HEADER_LIB_REPORT .= $ContentDivStart;
                                my $RESULT_INFO = "<table class='test_result' cellpadding='2'><tr><td>".htmlSpecChars($Info)."</td></tr></table>";
                                $HEADER_LIB_REPORT .= $RESULT_INFO.$Test."<br/>".$ContentDivEnd;
                                $HEADER_LIB_REPORT = insertIDs($HEADER_LIB_REPORT);
                                $Problems_Count += 1;
                            }
                            $HEADER_LIB_REPORT .= "<br/>\n";
                        }
                        $PROBLEM_REPORT .= $HEADER_LIB_REPORT;
                    }
                }
            }
            if($PROBLEM_REPORT)
            {
                my $Title = "<a name=\'".$ProblemType.(($ProblemValue)?"_".$ProblemValue:"")."\'></a>";
                $Title .= $ContentSpanStart_Title;
                $Title .= get_problem_title($ProblemType, $ProblemValue)." <span class='ext_title'>(".get_count_title(($Kind eq "Failures")?"problem":"warning", $Problems_Count).")</span>";
                $Title .= $ContentSpanEnd."<br/>\n";
                $Title .= $ContentDivStart."\n";
                
                $PROBLEM_REPORT = insertIDs($Title).$PROBLEM_REPORT."<a style='font-size:11px;' href='#Top'>to the top</a><br/>\n".$ContentDivEnd;
                $FAILED_TESTS .= $PROBLEM_REPORT;
            }
        }
    }
    if($FAILED_TESTS)
    {
        if($Kind eq "Failures") {
            $FAILED_TESTS = "<a name='Failed_Tests'></a><h2>Failed Tests (".$ResultCounter{"Run"}{"Fail"}.")</h2><hr/>\n".$FAILED_TESTS;
        }
        elsif($Kind eq "Warnings") {
            $FAILED_TESTS = "<a name='Warnings'></a><h2>Warnings (".$ResultCounter{"Run"}{"Warnings"}.")</h2><hr/>\n".$FAILED_TESTS;
        }
    }
    return $FAILED_TESTS;
}

sub composeHTML_Head($$$$$)
{
    my ($Title, $Keywords, $Description, $Styles, $Scripts) = @_;
    return "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">
    <html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">
    <head>
    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />
    <meta name=\"keywords\" content=\"$Keywords\" />
    <meta name=\"description\" content=\"$Description\" />
    <title>
        $Title
    </title>
    <style type=\"text/css\">
    $Styles
    </style>
    <script type=\"text/javascript\" language=\"JavaScript\">
    <!--
    $Scripts
    -->
    </script>
    </head>";
}

sub create_Index()
{
    my $Title = $TargetTitle."-".$Descriptor{"Version"}.": Test suite";
    my $Keywords = "$TargetTitle, tests, API";
    my $Description = "Test suite for the $TargetTitle-".$Descriptor{"Version"}." library on ".getArch();
    
    my $Header = get_TestSuite_Header();
    my $CssStyles = readModule("Styles", "List.css");
    my $Report = get_TestSuite_List(); # initialized $STAT_FIRST_LINE variable
    
    $Report = "<!-- $STAT_FIRST_LINE -->\n".composeHTML_Head($Title, $Keywords, $Description, $CssStyles, "")."\n<body>\n<div><a name='Top'></a>\n$Header<br/>\n$Report</div>\n"."<br/><br/>".getReportFooter()."\n</body></html>";
    
    writeFile("$TEST_SUITE_PATH/view_tests.html", $Report);
}

sub createReport()
{
    my $Title = $TargetTitle."-".$Descriptor{"Version"}.": test results";
    my $Keywords = "$TargetTitle, test, API";
    my $Description = "Test results for the $TargetTitle-".$Descriptor{"Version"}." library on ".getArch();
    
    my $CssStyles = readModule("Styles", "Report.css");
    my $JScripts = readModule("Scripts", "Sections.js");
    
    my $Summary = get_Summary(); # initialized $STAT_FIRST_LINE variable
    my $Report = get_Report_Header()."<br/>\n$Summary<br/>\n".get_Problem_Summary()."<br/>\n".get_FailedTests("Failures")."<br/>\n".get_FailedTests("Warnings");
    $Report = "<!-- $STAT_FIRST_LINE -->\n".composeHTML_Head($Title, $Keywords, $Description, $CssStyles, $JScripts)."\n<body>\n<div><a name='Top'></a>\n".$Report."</div>\n"."<br/><br/>".getReportFooter()."\n</body></html>";
    
    writeFile("$REPORT_PATH/test_results.html", $Report);
}

sub check_Cmd($)
{
    my $Cmd = $_[0];
    foreach my $Path (sort {length($a)<=>length($b)} split(/:/, $ENV{"PATH"}))
    {
        if(-x $Path."/".$Cmd) {
            return 1;
        }
    }
    return 0;
}

sub cmd_find($;$$$$)
{ # native "find" is much faster than File::Find (~6x)
  # also the File::Find doesn't support --maxdepth N option
  # so using the cross-platform wrapper for the native one
    my ($Path, $Type, $Name, $MaxDepth, $UseRegex) = @_;
    return () if(not $Path or not -e $Path);
    if($OSgroup eq "windows")
    {
        $Path = get_abs_path($Path);
        $Path = path_format($Path, $OSgroup);
        my $Cmd = "dir \"$Path\" /B /O";
        if($MaxDepth!=1) {
            $Cmd .= " /S";
        }
        if($Type eq "d") {
            $Cmd .= " /AD";
        }
        elsif($Type eq "f") {
            $Cmd .= " /A-D";
        }
        my @Files = split(/\n/, `$Cmd 2>\"$TMP_DIR/null\"`);
        if($Name)
        {
            if(not $UseRegex)
            { # FIXME: how to search file names in MS shell?
              # wildcard to regexp
                $Name=~s/\*/.*/g;
                $Name='\A'.$Name.'\Z';
            }
            @Files = grep { /$Name/i } @Files;
        }
        my @AbsPaths = ();
        foreach my $File (@Files)
        {
            if(not is_abs($File)) {
                $File = join_P($Path, $File);
            }
            if($Type eq "f" and not -f $File)
            { # skip dirs
                next;
            }
            push(@AbsPaths, path_format($File, $OSgroup));
        }
        if($Type eq "d") {
            push(@AbsPaths, $Path);
        }
        return @AbsPaths;
    }
    else
    {
        $Path = get_abs_path($Path);
        if(-d $Path and -l $Path
        and $Path!~/\/\Z/)
        { # for directories that are symlinks
            $Path.="/";
        }
        my $Cmd = "find \"$Path\"";
        if($MaxDepth) {
            $Cmd .= " -maxdepth $MaxDepth";
        }
        if($Type) {
            $Cmd .= " -type $Type";
        }
        if($Name and not $UseRegex)
        { # wildcards
            $Cmd .= " -name \"$Name\"";
        }
        my $Res = `$Cmd 2>\"$TMP_DIR/null\"`;
        if($? and $!) {
            printMsg("ERROR", "problem with \'find\' utility ($?): $!");
        }
        my @Files = split(/\n/, $Res);
        if($Name and $UseRegex)
        { # regex
            @Files = grep { /$Name/ } @Files;
        }
        return @Files;
    }
}

sub get_filename($)
{ # much faster than basename() from File::Basename module
    return $Cache{"get_filename"}{$_[0]} if($Cache{"get_filename"}{$_[0]});
    if($_[0]=~/([^\/\\]+)\Z/) {
        return ($Cache{"get_filename"}{$_[0]} = $1);
    }
    return "";
}

sub get_dirname($)
{ # much faster than dirname() from File::Basename module
    if($_[0]=~/\A(.*)[\/\\]+([^\/\\]*)\Z/) {
        return $1;
    }
    return "";
}

sub get_depth($$)
{
    my ($Str, $Sym) = @_;
    return $Cache{"get_depth"}{$Str}{$Sym} if(defined $Cache{"get_depth"}{$Str}{$Sym});
    $Cache{"get_depth"}{$Str}{$Sym} = scalar ( ( ) = $Str=~/($Sym)/g );
    return $Cache{"get_depth"}{$Str}{$Sym};
}

sub getPrefix($)
{
    my $Str = $_[0];
    if($Str=~/\A[_]*(([a-z]|[A-Z])[a-z]+)[A-Z]/) {
        return $1;
    }
    elsif($Str=~/\A[_]*([A-Z]+)[A-Z][a-z]+([A-Z][a-z]+|\Z)/) {
        return $1;
    }
    elsif($Str=~/\A([a-z0-9]+_)[a-z]+/i) {
        return $1;
    }
    elsif($Str=~/\A(([a-z])\2{1,})/i)
    { # ffopen
        return $1;
    }
    else {
        return "";
    }
}

sub get_Type($)
{
    my $TypeId = $_[0];
    return "" if(not $TypeId or not $TypeInfo{$TypeId});
    return %{$TypeInfo{$TypeId}};
}

sub uncover_typedefs($)
{
    my $TypeName = $_[0];
    return "" if(not $TypeName);
    return $Cache{"uncover_typedefs"}{$TypeName} if(defined $Cache{"uncover_typedefs"}{$TypeName});
    my ($TypeName_New, $TypeName_Pre) = (formatName($TypeName, "T"), "");
    while($TypeName_New ne $TypeName_Pre)
    {
        $TypeName_Pre = $TypeName_New;
        my $TypeName_Copy = $TypeName_New;
        my %Words = ();
        while($TypeName_Copy=~s/(\W|\A)([a-z_][\w:]*)(\W|\Z)//io)
        {
            my $Word = $2;
            next if(not $Word or $Word=~/\A(true|false|const|int|long|void|short|float|unsigned|char|double|class|struct|union|enum)\Z/);
            $Words{$Word} = 1;
        }
        foreach my $Word (sort keys(%Words))
        {
            my $BaseType_Name = $Typedef_BaseName{$Word};
            next if($TypeName_New=~/(\W|\A)(class|struct|union|enum)\s+\Q$Word\E(\W|\Z)/);
            next if(not $BaseType_Name);
            if($BaseType_Name=~/\([\*]+\)/)
            {
                if($TypeName_New=~/\Q$Word\E(.*)\Z/)
                {
                    my $Type_Suffix = $1;
                    $TypeName_New = $BaseType_Name;
                    if($TypeName_New=~s/\(([\*]+)\)/($1 $Type_Suffix)/) {
                        $TypeName_New = formatName($TypeName_New, "T");
                    }
                }
            }
            else
            {
                if($TypeName_New=~s/(\W|\A)\Q$Word\E(\W|\Z)/$1$BaseType_Name$2/g) {
                    $TypeName_New = formatName($TypeName_New, "T");
                }
            }
        }
    }
    $Cache{"uncover_typedefs"}{$TypeName} = $TypeName_New;
    return $TypeName_New;
}

sub get_type_short_name($)
{
    my $TypeName = $_[0];
    $TypeName=~s/[ ]*<.*>[ ]*//g;
    $TypeName=~s/\Astruct //g;
    $TypeName=~s/\Aunion //g;
    $TypeName=~s/\Aclass //g;
    return $TypeName;
}

sub is_transit_function($)
{
    my $ShortName = $_[0];
    return 1 if($ShortName=~/(_|\A)dup(_|\Z)|(dup\Z)|_dup/i);
    return 1 if($ShortName=~/replace|merge|search|copy|append|duplicat|find|query|open|handle|first|next|entry/i);
    return grep(/\A(get|prev|last|from|of|dup)\Z/i, @{get_tokens($ShortName)});
}

sub get_TypeLib($)
{
    my $TypeId = $_[0];
    if(defined $Cache{"get_TypeLib"}{$TypeId}
    and not defined $AuxType{$TypeId}) {
        return $Cache{"get_TypeLib"}{$TypeId};
    }
    my $Header = $TypeInfo{$TypeId}{"Header"};
    foreach my $Interface (sort keys(%{$Header_Interface{$Header}}))
    {
        if(my $SoLib = get_filename($Symbol_Library{$Interface}))
        {
            $Cache{"get_TypeLib"}{$TypeId} = $SoLib;
            return $SoLib;
        }
        elsif(my $SoLib = get_filename($DepSymbol_Library{$Interface}))
        {
            $Cache{"get_TypeLib"}{$TypeId} = $SoLib;
            return $SoLib;
        }
    }
    $Cache{"get_TypeLib"}{$TypeId} = "unknown";
    return $Cache{"get_TypeLib"}{$TypeId};
}

sub detect_typedef($)
{
    my $Type_Id = $_[0];
    return "" if(not $Type_Id);
    my $Typedef_Id = get_base_typedef($Type_Id);
    if(not $Typedef_Id) {
        $Typedef_Id = get_type_typedef(get_FoundationTypeId($Type_Id));
    }
    return $Typedef_Id;
}

sub get_symbol_suffix($)
{
    my $Symbol = $_[0];
    my $Signature = $tr_name{$Symbol};
    my $Suffix = substr($Signature, find_center($Signature, "("));
    return $Suffix;
}

sub get_Signature($)
{
    my $Interface = $_[0];
    if(defined $Cache{"get_Signature"}{$Interface}) {
        return $Cache{"get_Signature"}{$Interface};
    }
    my $Func_Signature = "";
    my $ShortName = $CompleteSignature{$Interface}{"ShortName"};
    if($Interface=~/\A(_Z|\?)/)
    {
        if(my $ClassId = $CompleteSignature{$Interface}{"Class"})
        {
            if(get_TypeName($ClassId)=~/<|>|::/
            and my $Typedef_Id = detect_typedef($ClassId)) {
                $ClassId = $Typedef_Id;
            }
            $Func_Signature = get_TypeName($ClassId)."::".((($CompleteSignature{$Interface}{"Destructor"}))?"~":"").$ShortName;
        }
        elsif(my $NameSpace = $CompleteSignature{$Interface}{"NameSpace"}) {
            $Func_Signature = $NameSpace."::".$ShortName;
        }
        else {
            $Func_Signature = $ShortName;
        }
    }
    else {
        $Func_Signature = $Interface;
    }
    my @ParamArray = ();
    foreach my $Pos (sort {int($a) <=> int($b)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
    {
        next if($Pos eq "");
        my $ParamTypeId = $CompleteSignature{$Interface}{"Param"}{$Pos}{"type"};
        next if(not $ParamTypeId);
        my $ParamTypeName = get_TypeName($ParamTypeId);
        my $ParamFTypeId = get_FoundationTypeId($ParamTypeId);
        if($ParamTypeName=~/<|>|::/ and get_TypeType($ParamFTypeId)=~/\A(Class|Struct)\Z/)
        {
            if(my $Typedef_Id = detect_typedef($ParamTypeId)) {
                $ParamTypeName = cover_by_typedef($ParamTypeName, $ParamFTypeId, $Typedef_Id);
            }
        }
        if(my $ParamName = $CompleteSignature{$Interface}{"Param"}{$Pos}{"name"}) {
            push(@ParamArray, create_member_decl($ParamTypeName, $ParamName));
        }
        else {
            push(@ParamArray, $ParamTypeName);
        }
    }
    if(not $CompleteSignature{$Interface}{"Data"})
    {
        if($Interface=~/\A(_Z|\?)/)
        {
            if(my $ChargeLevel = get_ChargeLevel($Interface)) {
                $Func_Signature .= " [".$ChargeLevel."]";
            }
        }
        $Func_Signature .= " (".join(", ", @ParamArray).")";
        if($Interface=~/\A_ZNK/) {
            $Func_Signature .= " const";
        }
        if($CompleteSignature{$Interface}{"Static"}) {
            $Func_Signature .= " [static]";
        }
    }
    if(defined $ShowRetVal
    and my $ReturnTId = $CompleteSignature{$Interface}{"Return"})
    {
        my $ReturnTypeName = get_TypeName($ReturnTId);
        my $ReturnFTypeId = get_FoundationTypeId($ReturnTId);
        if($ReturnTypeName=~/<|>|::/ and get_TypeType($ReturnFTypeId)=~/\A(Class|Struct)\Z/)
        {
            if(my $Typedef_Id = detect_typedef($ReturnTId)) {
                $ReturnTypeName = cover_by_typedef($ReturnTypeName, $ReturnFTypeId, $Typedef_Id);
            }
        }
        $Func_Signature .= " :".$ReturnTypeName;
    }
    return ($Cache{"get_Signature"}{$Interface} = $Func_Signature);
}

sub get_ChargeLevel($)
{
    my $Symbol = $_[0];
    if($CompleteSignature{$Symbol}{"Constructor"})
    {
        if($Symbol=~/C1E/) {
            return "in-charge";
        }
        elsif($Symbol=~/C2E/) {
            return "not-in-charge";
        }
        elsif($Symbol=~/C3E/)
        { # complete object (in-charge) allocating constructor
            return "in-charge";
        }
        elsif($Symbol=~/C4E/)
        { # base object (not-in-charge) allocating constructor
            return "not-in-charge";
        }
    }
    elsif($CompleteSignature{$Symbol}{"Destructor"})
    {
        if($Symbol=~/D1E/) {
            return "in-charge";
        }
        elsif($Symbol=~/D2E/) {
            return "not-in-charge";
        }
        elsif($Symbol=~/D0E/) {
            return "in-charge-deleting";
        }
    }
    return "";
}

sub htmlSpecChars(@)
{
    my ($Str, $Sp) = @_;
    
    $Str=~s/\&/&amp;/g;
    $Str=~s/</&lt;/g;
    $Str=~s/>/&gt;/g;
    
    if(not $Sp)
    {
        $Str=~s/([^ ]) ([^ ])/$1\@SP1\@$2/g;
        $Str=~s/([^ ]) ([^ ])/$1\@SP1\@$2/g;
        $Str=~s/ /&nbsp;/g;
        $Str=~s/\@SP1\@/ /g;
        $Str=~s/\n/<br\/>/g;
    }
    
    return $Str;
}

sub highLight_Signature_Italic_Color($)
{
    my $Signature = $_[0];
    return highLight_Signature_PPos_Italic($Signature, "", 1, 1);
}

sub highLight_Signature_PPos_Italic($$$$)
{
    my ($Signature, $Param_Pos, $ItalicParams, $ColorParams) = @_;
    my ($Begin, $End, $Return) = (substr($Signature, 0, find_center($Signature, "(")), "", "");
    if($ShowRetVal and $Signature=~s/([^:])\s*:([^:].+?)\Z/$1/g) {
        $Return = $2;
    }
    if($Signature=~/\)((| const)(| \[static\]))\Z/) {
        $End = $1;
    }
    my @Parts = ();
    my @SParts = get_Signature_Parts($Signature, 1);
    foreach my $Pos (0 .. $#SParts)
    {
        my $Part = $SParts[$Pos];
        $Part=~s/\A\s+|\s+\Z//g;
        my ($Part_Styled, $ParamName) = (htmlSpecChars($Part), "");
        if($Part=~/\([\*]+(\w+)\)/i) {
            $ParamName = $1;#func-ptr
        }
        elsif($Part=~/(\w+)[\,\)]*\Z/i) {
            $ParamName = $1;
        }
        if(not $ParamName)
        {
            push(@Parts, $Part_Styled);
            next;
        }
        if($ItalicParams
        and not $TName_Tid{$Part})
        {
            my $Style = "param";
            if($Param_Pos ne ""
            and $Pos==$Param_Pos) {
                $Style = "focus_p";
            }
            elsif($ColorParams) {
                $Style = "color_p";
            }
            $Part_Styled =~ s!(\W)$ParamName([\,\)]|\Z)!$1<span class=\'$Style\'>$ParamName</span>$2!ig;
        }
        $Part_Styled=~s/,(\w)/, $1/g;
        push(@Parts, $Part_Styled);
    }
    if(@Parts)
    {
        foreach my $Num (0 .. $#Parts)
        {
            if($Num==$#Parts)
            { # add ")" to the last parameter
                $Parts[$Num] = "<span class='nowrap'>".$Parts[$Num]." )</span>";
            }
            elsif(length($Parts[$Num])<=45) {
                $Parts[$Num] = "<span class='nowrap'>".$Parts[$Num]."</span>";
            }
        }
        $Signature = htmlSpecChars($Begin)."<span class='sym_p'>(&#160;".join(" ", @Parts)."</span>".$End;
    }
    else {
        $Signature = htmlSpecChars($Begin)."<span class='sym_p'>(&#160;)</span>".$End;
    }
    if($Return and $ShowRetVal) {
        $Signature .= "<span class='sym_p nowrap'> &#160;<b>:</b>&#160;&#160;".htmlSpecChars($Return)."</span>";
    }
    $Signature=~s!\[\]![&#160;]!g;
    $Signature=~s!operator=!operator&#160;=!g;
    $Signature=~s!(\[in-charge\]|\[not-in-charge\]|\[in-charge-deleting\]|\[static\])!<span class='attr'>$1</span>!g;
    return $Signature;
}

sub get_Signature_Parts($$)
{
    my ($Signature, $Comma) = @_;
    my @Parts = ();
    my ($Bracket_Num, $Bracket2_Num) = (0, 0);
    my $Parameters = $Signature;
    my $ShortName = substr($Parameters, 0, find_center($Parameters, "("));
    $Parameters=~s/\A\Q$ShortName\E\(//g;
    $Parameters=~s/\)(| const)(| \[static\])\Z//g;
    my $Part_Num = 0;
    foreach my $Pos (0 .. length($Parameters) - 1)
    {
        my $Symbol = substr($Parameters, $Pos, 1);
        $Bracket_Num += 1 if($Symbol eq "(");
        $Bracket_Num -= 1 if($Symbol eq ")");
        $Bracket2_Num += 1 if($Symbol eq "<");
        $Bracket2_Num -= 1 if($Symbol eq ">");
        if($Symbol eq "," and $Bracket_Num==0 and $Bracket2_Num==0)
        {
            $Parts[$Part_Num] .= $Symbol if($Comma);
            $Part_Num += 1;
        }
        else
        {
            $Parts[$Part_Num] .= $Symbol;
        }
    }
    return @Parts;
}

sub isAnon($) {
    return (($_[0]=~/\.\_\d+/) or ($_[0]=~/anon-/));
}

sub formatName($$)
{ # type name correction
    if(defined $Cache{"formatName"}{$_[1]}{$_[0]}) {
        return $Cache{"formatName"}{$_[1]}{$_[0]};
    }
    
    my $N = $_[0];
    
    if($_[1] ne "S")
    {
        $N=~s/\A[ ]+//g;
        $N=~s/[ ]+\Z//g;
        $N=~s/[ ]{2,}/ /g;
    }
    
    $N=~s/[ ]*(\W)[ ]*/$1/g; # std::basic_string<char> const
    
    $N=~s/\bvolatile const\b/const volatile/g;
    
    $N=~s/\b(long long|short|long) unsigned\b/unsigned $1/g;
    $N=~s/\b(short|long) int\b/$1/g;
    
    $N=~s/([\)\]])(const|volatile)\b/$1 $2/g;
    
    while($N=~s/>>/> >/g) {};
    
    if($_[1] eq "S")
    {
        if(index($N, "operator")!=-1) {
            $N=~s/\b(operator[ ]*)> >/$1>>/;
        }
    }
    
    return ($Cache{"formatName"}{$_[1]}{$_[0]} = $N);
}

sub prepareInterfaces()
{
    foreach my $InfoId (keys(%SymbolInfo))
    {
        my $MnglName = $SymbolInfo{$InfoId}{"MnglName"};
        %{$CompleteSignature{$MnglName}} = %{$SymbolInfo{$InfoId}};
        delete($SymbolInfo{$InfoId});
    }
    %SymbolInfo = ();
}

sub setRegularities()
{
    foreach my $Symbol (keys(%CompleteSignature))
    {
        if(my $ClassId = $CompleteSignature{$Symbol}{"Class"})
        {
            if(not $CompleteSignature{$Symbol}{"Destructor"}
            and ($Symbol!~/C2E/ or not $CompleteSignature{$Symbol}{"Constructor"})) {
                $Interface_Overloads{$CompleteSignature{$Symbol}{"NameSpace"}}{get_ShortType($ClassId)}{$CompleteSignature{$Symbol}{"ShortName"}}{$Symbol} = 1;
            }
            if($CompleteSignature{$Symbol}{"PureVirt"}) {
                $Class_PureMethod{$ClassId}{$Symbol} = 1;
            }
            else {
                $Class_Method{$ClassId}{$Symbol} = 1;
            }
        }
        
        if(not $CompleteSignature{$Symbol}{"Private"})
        {
            setOutParams_Simple($Symbol);
            setOutParams_Complex($Symbol);
            setRelationships($Symbol);
        }
        
        if($CompleteSignature{$Symbol}{"Data"})
        {
            if($Symbol=~/\A(_Z|\?)/)
            {
                my $Name = $CompleteSignature{$Symbol}{"ShortName"};
                if(my $Class = $CompleteSignature{$Symbol}{"Class"}) {
                    $Name = get_TypeName($Class)."::".$Name;
                }
                $GlobalDataNames{$Name} = 1;
            }
            else {
                 $GlobalDataNames{$CompleteSignature{$Symbol}{"ShortName"}} = 1;
            }
        }
        else
        {
            if($Symbol=~/\A(_Z|\?)/) {
                $MethodNames{$CompleteSignature{$Symbol}{"ShortName"}} = 1;
            }
            else {
                $FuncNames{$CompleteSignature{$Symbol}{"ShortName"}} = 1;
            }
        }
        
        if(my $Prefix = getPrefix($CompleteSignature{$Symbol}{"ShortName"})) {
            $Library_Prefixes{$Prefix} += 1;
        }
    }
    foreach my $NameSpace (keys(%Interface_Overloads))
    {
        foreach my $ClassName (keys(%{$Interface_Overloads{$NameSpace}}))
        {
            foreach my $ShortName (keys(%{$Interface_Overloads{$NameSpace}{$ClassName}}))
            {
                if(keys(%{$Interface_Overloads{$NameSpace}{$ClassName}{$ShortName}})>1)
                {
                    foreach my $Symbol (keys(%{$Interface_Overloads{$NameSpace}{$ClassName}{$ShortName}})) {
                        $OverloadedInterface{$Symbol} = keys(%{$Interface_Overloads{$NameSpace}{$ClassName}{$ShortName}});
                    }
                }
                delete($Interface_Overloads{$NameSpace}{$ClassName}{$ShortName});
            }
        }
    }
    
    my %Struct_Mapping = ();
    
    foreach my $TypeId (keys(%TypeInfo))
    {
        my %Type = %{$TypeInfo{$TypeId}};
        my $BaseTypeId = get_FoundationTypeId($TypeId);
        my $PLevel = get_PointerLevel($TypeId);
        $BaseType_PLevel_Type{$BaseTypeId}{$PLevel}{$TypeId} = 1;
        
        if($Type{"Type"} eq "Struct")
        {
            
            next if(not keys(%{$Type{"Memb"}}));
            my $FirstId = $Type{"Memb"}{0}{"type"};
            if($Type{"Memb"}{0}{"name"}=~/parent/i
            and get_TypeType(get_FoundationTypeId($FirstId)) eq "Struct"
            and get_TypeName($FirstId)!~/gobject/i) {
                $Struct_Parent{$TypeId} = $FirstId;
            }
            my @Keys = ();
            foreach my $MembPos (sort {int($a)<=>int($b)} keys(%{$Type{"Memb"}})) {
                push(@Keys, $Type{"Memb"}{$MembPos}{"name"}.":".$Type{"Memb"}{$MembPos}{"type"});
            }
            init_struct_mapping($TypeId, \%Struct_Mapping, \@Keys);
        }
    }
    
    read_struct_mapping(\%Struct_Mapping);
}

sub init_struct_mapping($$$)
{
    my ($TypeId, $Ref, $KeysRef) = @_;
    my @Keys = @{$KeysRef};
    if($#Keys>=1)
    {
        my $FirstKey = $Keys[0];
        splice(@Keys, 0, 1);
        if(not defined $Ref->{$FirstKey}) {
            %{$Ref->{$FirstKey}} = ();
        }
        init_struct_mapping($TypeId, $Ref->{$FirstKey}, \@Keys);
    }
    elsif($#Keys==0) {
        $Ref->{$Keys[0]}{"Types"}{$TypeId} = 1;
    }
}

sub read_struct_mapping($)
{
    my $Ref = $_[0];
    my %LevelTypes = ();
    @LevelTypes{keys(%{$Ref->{"Types"}})} = values(%{$Ref->{"Types"}});
    foreach my $Key (keys(%{$Ref}))
    {
        next if($Key eq "Types");
        foreach my $SubClassId (read_struct_mapping($Ref->{$Key}))
        {
            $LevelTypes{$SubClassId} = 1;
            foreach my $ParentId (keys(%{$Ref->{"Types"}})) {
                $Struct_SubClasses{$ParentId}{$SubClassId} = 1;
            }
        }
    }
    return keys(%LevelTypes);
}

sub get_ShortType($)
{
    my $TypeId = $_;
    my $TypeName = uncover_typedefs($TypeInfo{$TypeId}{"Name"});
    if(my $NameSpace = $TypeInfo{$TypeId}{"NameSpace"}) {
        $TypeName=~s/\A$NameSpace\:\://g;
    }
    return $TypeName;
}

sub setRelationships($)
{
    my $Interface = $_[0];
    my $ShortName = $CompleteSignature{$Interface}{"ShortName"};
    
    if($Interface=~/\A(_Z|\?)/ and not $CompleteSignature{$Interface}{"Class"}) {
        $Func_ShortName_MangledName{$CompleteSignature{$Interface}{"ShortName"}}{$Interface}=1;
    }
    if(not $CompleteSignature{$Interface}{"PureVirt"})
    {
        if($CompleteSignature{$Interface}{"Constructor"}) {
            $Class_Constructors{$CompleteSignature{$Interface}{"Class"}}{$Interface} = 1;
        }
        elsif($CompleteSignature{$Interface}{"Destructor"}) {
            $Class_Destructors{$CompleteSignature{$Interface}{"Class"}}{$Interface} = 1;
        }
        else
        {
            if(get_TypeName($CompleteSignature{$Interface}{"Return"}) ne "void")
            {
                my $DoNotUseReturn = 0;
                if(is_transit_function($ShortName))
                {
                    my $Return_FId = get_FoundationTypeId($CompleteSignature{$Interface}{"Return"});
                    foreach my $Pos (keys(%{$CompleteSignature{$Interface}{"Param"}}))
                    {
                        next if($InterfaceSpecType{$Interface}{"SpecParam"}{$Pos});
                        my $Param_FId = get_FoundationTypeId($CompleteSignature{$Interface}{"Param"}{$Pos}{"type"});
                        if(($CompleteSignature{$Interface}{"Param"}{$Pos}{"type"} eq $CompleteSignature{$Interface}{"Return"})
                        or (get_TypeType($Return_FId)!~/\A(Intrinsic|Enum|Array)\Z/ and $Return_FId eq $Param_FId))
                        {
                            $DoNotUseReturn = 1;
                            last;
                        }
                    }
                }
                if(not $DoNotUseReturn)
                {
                    $ReturnTypeId_Interface{$CompleteSignature{$Interface}{"Return"}}{$Interface}=1;
                    my $Return_FId = get_FoundationTypeId($CompleteSignature{$Interface}{"Return"});
                    my $PLevel = get_PointerLevel($CompleteSignature{$Interface}{"Return"});
                    if(get_TypeType($Return_FId) ne "Intrinsic") {
                        $BaseType_PLevel_Return{$Return_FId}{$PLevel}{$Interface}=1;
                    }
                }
            }
        }
    }
    
    $Header_Interface{$CompleteSignature{$Interface}{"Header"}}{$Interface} = 1;
    if(not $CompleteSignature{$Interface}{"Class"} and not $LibraryMallocFunc
    and $Symbol_Library{$Interface} and $Interface ne "malloc"
    and $ShortName!~/try|slice|trim|\d\Z/i and $ShortName=~/(\A|_|\d)(malloc|alloc)(\Z|_|\d)/i
    and keys(%{$CompleteSignature{$Interface}{"Param"}})==1
    and isIntegerType(get_TypeName($CompleteSignature{$Interface}{"Param"}{0}{"type"}))) {
        $LibraryMallocFunc = $Interface;
    }
    if(not $CompleteSignature{$Interface}{"Class"} and $Symbol_Library{$Interface}
    and $ShortName=~/(\A[a-z]*_)(init|initialize|initializer|install)\Z/i) {
        $LibraryInitFunc{$Interface} = 1;
    }
    elsif(not $CompleteSignature{$Interface}{"Class"} and $Symbol_Library{$Interface}
    and $ShortName=~/\A([a-z]*_)(exit|finalize|finish|clean|close|deinit|shutdown|cleanup|uninstall|end)\Z/i) {
        $LibraryExitFunc{$Interface} = 1;
    }
}

sub setOutParams_Simple($)
{
    my $Interface = $_[0];
    my $ReturnType_Id = $CompleteSignature{$Interface}{"Return"};
    my $ReturnType_Name_Short = get_TypeName($ReturnType_Id);
    while($ReturnType_Name_Short=~s/(\*|\&)([^<>()]+|)\Z/$2/g){};
    my ($ParamName_Prev, $ParamTypeId_Prev) = ();
    foreach my $ParamPos (sort {int($a)<=>int($b)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
    { # detecting out-parameters by name
        if($CompleteSignature{$Interface}{"Param"}{$ParamPos}{"name"}=~/\Ap\d+\Z/
        and (my $NewParamName = $AddIntParams{$Interface}{$ParamPos}))
        { # names from the external file
            $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"name"} = $NewParamName;
        }
        my $ParamName = $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"name"};
        my $ParamTypeId = $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"type"};
        my $ParamPLevel = get_PointerLevel($ParamTypeId);
        my $ParamFTypeId = get_FoundationTypeId($ParamTypeId);
        my $ParamFTypeName = get_TypeName($ParamFTypeId);
        my $ParamTypeName = get_TypeName($ParamTypeId);
        
        if($UserDefinedOutParam{$Interface}{$ParamPos+1}
        or $UserDefinedOutParam{$Interface}{$ParamName})
        { # user defined by <out_params> section in the descriptor
            register_out_param($Interface, $ParamPos, $ParamName, $ParamTypeId);
            next;
        }
        
        # particular accept
        if($ParamPLevel>=2 and isCharType($ParamFTypeName)
        and not is_const_type($ParamTypeName) and $ParamName!~/argv/i and $ParamName!~/\A(s|str|string)\Z/i)
        { # soup_form_decode_multipart ( SoupMessage* msg, char const* file_control_name, char** filename, char** content_type, SoupBuffer** file )
          # direct_trim ( char** s )
            register_out_param($Interface, $ParamPos, $ParamName, $ParamTypeId);
            next;
        }
        if($ParamPLevel>=2 and not is_const_type($ParamTypeName) and $ParamName=~/handle/i and $CompleteSignature{$Interface}{"ShortName"}=~/_init\Z/i)
        { # gnutls_cipher_init ( gnutls_cipher_hd_t* handle, gnutls_cipher_algorithm_t cipher, gnutls_datum_t const* key, gnutls_datum_t const* iv )
            register_out_param($Interface, $ParamPos, $ParamName, $ParamTypeId);
            next;
        }
        if($ParamPLevel==1 and isNumericType($ParamFTypeName)
        and not is_const_type($ParamTypeName) and ($ParamName=~/((\A|_)(x|y|(lat|long|alt)itude)(\Z|_))|errnum|errcode|used|horizontal|vertical|width|height|error|length|count|time|status|state|min|max|weight|\An[_]*(row|col|axe|found|memb|key|space)|\An_/i or $ParamTypeName=~/bool/i
        or $ParamName=~/(\A|_)n(_|)(elem|item)/i or is_out_word($ParamName) or $ParamName=~/\Ais/i))
        { # gail_misc_get_origins ( GtkWidget* widget, gint* x_window, gint* y_window, gint* x_toplevel, gint* y_toplevel )
          # glXGetFBConfigs ( Display* dpy, int screen, int* nelements )
            register_out_param($Interface, $ParamPos, $ParamName, $ParamTypeId);
            next;
        }
        if(($ParamName=~/err/i and $ParamPLevel>=2 and $ParamTypeName=~/err/i)
        or ($ParamName=~/\A(error|err)(_|)(p|ptr)\Z/i and $ParamPLevel>=1))
        { # g_app_info_add_supports_type ( GAppInfo* appinfo, char const* content_type, GError** error )
          # rsvg_handle_new_from_data ( guint8 const* data, gsize data_len, GError** error )
            register_out_param($Interface, $ParamPos, $ParamName, $ParamTypeId);
            next;
        }
        
        # strong reject
        next if(get_TypeType(get_FoundationTypeId($ReturnType_Id))!~/\A(Intrinsic|Enum)\Z/
        or $CompleteSignature{$Interface}{"ShortName"}=~/\Q$ReturnType_Name_Short\E/
        or $CompleteSignature{$Interface}{"ShortName"}=~/$ParamName(_|)get(_|)\w+/i
        or $ReturnType_Name_Short=~/pointer|ptr/i);
        next if($ParamPLevel<=0);
        next if($ParamPLevel==1 and (isOpaque($ParamFTypeId)
        or get_TypeName($ParamFTypeId)=~/\A(((struct |)(_IO_FILE|__FILE|FILE))|void)\Z/));
        next if(is_const_type($ParamTypeName) and $ParamPLevel<=2);
        next if($CompleteSignature{$Interface}{"ShortName"}=~/memcpy|already/i);

        # allowed
        if((is_out_word($ParamName) and $CompleteSignature{$Interface}{"ShortName"}!~/free/i
        #! xmlC14NDocSaveTo (xmlDocPtr doc, xmlNodeSetPtr nodes, int exclusive, xmlChar** inclusive_ns_prefixes, int with_comments, xmlOutputBufferPtr buf)
        # XGetMotionEvents (Display* display, Window w, Time start, Time stop, int* nevents_return)
        
        and ($ParamTypeName=~/\*/ or $ParamTypeName!~/(ptr|pointer|p\Z)/i)
        
        # gsl_sf_bessel_il_scaled_array (int const lmax, double const x, double* result_array)
        and not grep(/\A(array)\Z/i, @{get_tokens($ParamName)})
        
        #! mysql_free_result ( MYSQL_RES* result )
        and not is_out_word($ParamTypeName))
        
        # snd_card_get_name (int card, char** name)
        # FMOD_Channel_GetMode (FMOD_CHANNEL* channel, FMOD_MODE* mode)
        or $CompleteSignature{$Interface}{"ShortName"}=~/(get|create)[_]*[0-9a-z]*$ParamName\Z/i
        
        # snd_config_get_ascii (snd_config_t const* config, char** value)
        or ($ParamPos==1 and $ParamName=~/value/i and $CompleteSignature{$Interface}{"ShortName"}=~/$ParamName_Prev[_]*get/i)
        
        # poptDupArgv (int argc, char const** argv, int* argcPtr, char const*** argvPtr)
        or ($ParamName=~/ptr|pointer|(p\Z)/i and $ParamPLevel>=3))
        {
            my $IsTransit = 0;
            foreach my $Pos (keys(%{$CompleteSignature{$Interface}{"Param"}}))
            {
                my $OtherParamTypeId = $CompleteSignature{$Interface}{"Param"}{$Pos}{"type"};
                my $OtherParamName = $CompleteSignature{$Interface}{"Param"}{$Pos}{"name"};
                next if($OtherParamName eq $ParamName);
                my $OtherParamFTypeId = get_FoundationTypeId($OtherParamTypeId);
                if($ParamFTypeId eq $OtherParamFTypeId)
                {
                    $IsTransit = 1;
                    last;
                }
            }
            if($IsTransit or get_TypeType($ParamFTypeId)=~/\A(Intrinsic|Enum|Array)\Z/)
            {
                $OutParamInterface_Pos_NoUsing{$Interface}{$ParamPos}=1;
                $Interface_OutParam_NoUsing{$Interface}{$ParamName}=1;
            }
            else {
                register_out_param($Interface, $ParamPos, $ParamName, $ParamTypeId);
            }
        }
        ($ParamName_Prev, $ParamTypeId_Prev) = ($ParamName, $ParamTypeId);
    }
}

sub setOutParams_Complex($)
{ # detect out-parameters by function name and parameter type
    my $Interface = $_[0];
    my $Func_ShortName = $CompleteSignature{$Interface}{"ShortName"};
    my $ReturnType_Id = $CompleteSignature{$Interface}{"Return"};
    my $ReturnType_Name_Short = get_TypeName($ReturnType_Id);
    while($ReturnType_Name_Short=~s/(\*|\&)([^<>()]+|)\Z/$2/g){};
    return if(get_TypeType(get_FoundationTypeId($ReturnType_Id))!~/\A(Intrinsic|Enum)\Z/
    or $Func_ShortName=~/\Q$ReturnType_Name_Short\E/);
    if(get_TypeName($ReturnType_Id) eq "void*" and $Func_ShortName=~/data/i)
    { # void* repo_sidedata_create ( Repo* repo, size_t size )
        return;
    }
    return if($Func_ShortName!~/(new|create|open|top|update|start)/i and not is_alloc_func($Func_ShortName)
    and ($Func_ShortName!~/init/i or get_TypeName($ReturnType_Id) ne "void") and not $UserDefinedOutParam{$Interface});
    return if($Func_ShortName=~/obsolete|createdup|updates/i);
    return if(not keys(%{$CompleteSignature{$Interface}{"Param"}}));
    return if($Func_ShortName=~/(already)/i);
    if(not detect_out_parameters($Interface, 1)) {
        detect_out_parameters($Interface, 0);
    }
}

sub detect_out_parameters($$)
{
    my ($Interface, $Strong) = @_;
    foreach my $ParamPos (sort{int($a)<=>int($b)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
    {
        my $ParamTypeId = $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"type"};
        my $ParamName = $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"name"};
        if(isOutParam($ParamTypeId, $ParamPos, $Interface, $Strong))
        {
            register_out_param($Interface, $ParamPos, $ParamName, $ParamTypeId);
            return 1;
        }
    }
    return 0;
}

sub get_outparam_candidate($$)
{
    my ($Interface, $Right) = @_;
    my $Func_ShortName = $CompleteSignature{$Interface}{"ShortName"};
    if($Right)
    {
        if($Func_ShortName=~/([a-z0-9]+)(_|)(new|open|init)\Z/i) {
            return $1;
        }
    }
    else
    {
        if($Func_ShortName=~/(new|open|init)(_|)([a-z0-9]+)/i) {
            return $3;
        }
    }
}

sub isOutParam($$$$)
{
    my ($Param_TypeId, $ParamPos, $Interface, $Strong) = @_;
    my $Param_Name = $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"name"};
    my $PLevel = get_PointerLevel($Param_TypeId);
    my $TypeName = get_TypeName($Param_TypeId);
    my $Param_FTypeId = get_FoundationTypeId($Param_TypeId);
    my $Param_FTypeName = get_TypeName($Param_FTypeId);
    $Param_FTypeName=~s/\A(struct|union) //g;
    my $Param_FTypeType = get_TypeType($Param_FTypeId);
    return 0 if($PLevel<=0);
    return 0 if($PLevel==1 and isOpaque($Param_FTypeId));
    return 0 if($Param_FTypeType!~/\A(Struct|Union|Class)\Z/);
    return 0 if(keys(%{$BaseType_PLevel_Return{$Param_FTypeId}{$PLevel}}));
    return 0 if(keys(%{$ReturnTypeId_Interface{$Param_TypeId}}));
    return 0 if(is_const_type($TypeName));
    my $Func_ShortName = $CompleteSignature{$Interface}{"ShortName"};
    return 1 if($Func_ShortName=~/\A\Q$Param_FTypeName\E(_|)init/);
    if($Strong)
    {
        if(my $Candidate = get_outparam_candidate($Interface, 1)) {
            return ($Param_Name=~/\Q$Candidate\E/i);
        }
    }
    if(my $Candidate = get_outparam_candidate($Interface, 0)) {
        return 0 if($Param_Name!~/\Q$Candidate\E/i);
    }
    return 1 if(($Func_ShortName=~/(new|create|open|start)/i and $Func_ShortName!~/get|restart|set|test/)
    or is_alloc_func($Func_ShortName));
    return 1 if($Func_ShortName=~/top/i and $PLevel==2);
    # snd_config_top
    return 1 if($UserDefinedOutParam{$Interface}{$Param_Name}
    or $UserDefinedOutParam{$Interface}{$ParamPos+1});
    return 1 if($Func_ShortName=~/update/i and $Func_ShortName!~/add|append/i
    and $Func_ShortName=~/$Param_Name/i and $PLevel>=1);
    if($Func_ShortName=~/init/i)
    {
        if(keys(%{$CompleteSignature{$Interface}{"Param"}})==1
        or number_of_simple_params($Interface)==keys(%{$CompleteSignature{$Interface}{"Param"}})-1) {
            return 1;
        }
    }
    
    return 0;
}

sub number_of_simple_params($)
{
    my $Interface = $_[0];
    return 0 if(not $Interface);
    my $Count = 0;
    foreach my $Pos (keys(%{$CompleteSignature{$Interface}{"Param"}}))
    {
        my $TypeId = $CompleteSignature{$Interface}{"Param"}{$Pos}{"type"};
        my $PName = $CompleteSignature{$Interface}{"Param"}{$Pos}{"name"};
        if(get_TypeType($TypeId)=~/\A(Intrinsic|Enum)\Z/
        or isString($TypeId, $PName, $Interface)) {
            $Count+=1;
        }
    }
    return $Count;
}

sub get_OutParamFamily($$)
{
    my ($TypeId, $IncludeOuter) = @_;
    my $FTypeId = get_FoundationTypeId($TypeId);
    if(get_TypeType($FTypeId)=~/Struct|Union|Class/)
    {
        my @Types = ($IncludeOuter and ($TypeId ne $FTypeId))?($TypeId, $FTypeId):($FTypeId);
        while(my $ReducedTypeId = reduce_pointer_level($TypeId))
        {
            push(@Types, $ReducedTypeId);
            $TypeId = $ReducedTypeId;
        }
        return @Types;
    }
    else
    {
        my @Types = ($IncludeOuter)?($TypeId):();
        my $ReducedTypeId = reduce_pointer_level($TypeId);
        if(get_TypeType($ReducedTypeId) eq "Typedef") {
            push(@Types, $ReducedTypeId);
        }
        return @Types;
    }
    return ();
}

sub is_alloc_func($)
{
    my $FuncName = $_[0];
    return ($FuncName=~/alloc/i and $FuncName!~/dealloc|realloc/i);
}

sub markAbstractClasses()
{
    foreach my $Interface (keys(%CompleteSignature))
    {
        if($CompleteSignature{$Interface}{"PureVirt"}) {
            markAbstractSubClasses($CompleteSignature{$Interface}{"Class"}, $Interface);
        }
    }
}

sub markAbstractSubClasses($$)
{
    my ($ClassId, $Interface) = @_;
    return if(not $ClassId or not $Interface);
    
    my $TargetSuffix = get_symbol_suffix($Interface);
    my $TargetShortName = $CompleteSignature{$Interface}{"ShortName"};
    foreach my $InterfaceCandidate (keys(%{$Class_Method{$ClassId}}))
    {
        if($TargetSuffix eq get_symbol_suffix($InterfaceCandidate))
        {
            if($CompleteSignature{$Interface}{"Constructor"})
            {
                if($CompleteSignature{$InterfaceCandidate}{"Constructor"}) {
                    return;
                }
            }
            elsif($CompleteSignature{$Interface}{"Destructor"})
            {
                if($CompleteSignature{$InterfaceCandidate}{"Destructor"}) {
                    return;
                }
            }
            else
            {
                if($TargetShortName eq $CompleteSignature{$InterfaceCandidate}{"ShortName"}) {
                    return;
                }
            }
        }
    }
    
    my $CName = get_TypeName($ClassId);
    $Class_PureVirtFunc{$CName}{$Interface} = 1;
    
    foreach my $SubClass_Id (keys(%{$Class_SubClasses{$ClassId}})) {
        markAbstractSubClasses($SubClass_Id, $Interface);
    }
}

sub cleanName($)
{
    my $Name = $_[0];
    return "" if(not $Name);
    foreach my $Token (sort keys(%Operator_Indication))
    {
        my $Token_Translate = $Operator_Indication{$Token};
        $Name=~s/\Q$Token_Translate\E/\_$Token\_/g;
    }
    $Name=~s/\,/_/g;
    $Name=~s/\./_p_/g;
    $Name=~s/\:/_/g;
    $Name=~s/\]/_rb_/g;
    $Name=~s/\[/_lb_/g;
    $Name=~s/\(/_/g;
    $Name=~s/\)/_/g;
    $Name=~s/ /_/g;
    while($Name=~/__/) {
        $Name=~s/__/_/g;
    }
    $Name=~s/\_\Z//;
    return $Name;
}

sub getTestName($)
{
    my $Interface = $_[0];
    $Interface=~s/\?//g;
    return $Interface;
}

sub getTestPath($)
{
    my $Interface = $_[0];
    my $TestPath = "";
    if($Interface_LibGroup{$Interface}) {
        $TestPath = $TEST_SUITE_PATH."/groups/".cleanGroup($Interface_LibGroup{$Interface})."/".getTestName($Interface);
    }
    else
    {
        my $ClassName = get_TypeName($CompleteSignature{$Interface}{"Class"});
        if($OSgroup eq "windows") {
            $ClassName = cleanName($ClassName);
        }
        my $Header = $CompleteSignature{$Interface}{"Header"};
        $Header=~s/(\.\w+)\Z//g;
        $TestPath = $TEST_SUITE_PATH."/groups/".get_filename($Header)."/".(($ClassName)?"classes/".get_type_short_name($ClassName):"functions")."/".getTestName($Interface);
    }
    return $TestPath;
}

sub getLibGroupPath($$$)
{
    my ($C1, $C2, $TwoComponets) = @_;
    return () if(not $C1);
    $C1 = cleanGroup($C1);
    if($TwoComponets)
    {
        if($C2) {
            return ($TEST_SUITE_PATH."/$TargetLibraryName-t2c/", $C1, $C2);
        }
        else {
            return ($TEST_SUITE_PATH."/$TargetLibraryName-t2c/", $C1, "functions");
        }
    }
    else {
        return ($TEST_SUITE_PATH."/$TargetLibraryName-t2c/", "", $C1);
    }
}

sub getLibGroupName($$)
{
    my ($C1, $C2) = @_;
    return "" if(not $C1);
    if($C2) {
        return $C2;
    }
    else {
        return $C1;
    }
}

sub cleanGroup($)
{
    my $Name = $_[0];
    $Name=~s/(\.\w+)\Z//g;
    $Name=~s/( |-)/_/g;
    $Name=~s/\([^()]+\)//g;
    $Name=~s/[_]{2,}/_/g;
    return $Name;
}

sub find_center($$)
{
    my ($Sign, $Target) = @_;
    my %B = ( "("=>0, "<"=>0, ")"=>0, ">"=>0 );
    my $Center = 0;
    if($Sign=~s/(operator([^\w\s\(\)]+|\(\)))//g)
    { # operators
        $Center+=length($1);
    }
    foreach my $Pos (0 .. length($Sign)-1)
    {
        my $S = substr($Sign, $Pos, 1);
        if($S eq $Target)
        {
            if($B{"("}==$B{")"}
            and $B{"<"}==$B{">"}) {
                return $Center;
            }
        }
        if(defined $B{$S}) {
            $B{$S}+=1;
        }
        $Center+=1;
    }
    return 0;
}

sub skipSymbol($)
{
    my $Symbol = $_[0];
    return 1 if($SkipInterfaces{$Symbol});
    foreach my $SkipPattern (keys(%SkipInterfaces_Pattern)) {
        return 1 if($Symbol=~/$SkipPattern/);
    }
    return 0;
}

sub symbolFilter($)
{
    my $Symbol = $_[0];
    
    return 0 if(skipSymbol($Symbol));
    return 0 if(index($Symbol, "_aux_")==0);
    
    return 0 if(not $CompleteSignature{$Symbol}{"Header"});
    return 0 if($CompleteSignature{$Symbol}{"Private"});
    return 0 if($CompleteSignature{$Symbol}{"Data"});
    
    if($CompleteSignature{$Symbol}{"Constructor"}) {
        return 0 if($Symbol=~/C[3-4]E/);
    }
    
    if($CompleteSignature{$Symbol}{"Destructor"}) {
        return 0 if($Symbol=~/D[3-4]E/);
    }
    
    my $ClassId = $CompleteSignature{$Symbol}{"Class"};
    
    if(not $TargetInterfaceName
    and not keys(%InterfacesList))
    {
        return 0 if($Symbol=~/\A(_ZS|_ZNS|_ZNKS)/); # stdc++ symbols
        if(not defined $KeepInternal)
        { # --keep-internal
            if(index($Symbol, "__")==0)
            { # __argz_count
                return 0;
            }
            if(index($CompleteSignature{$Symbol}{"ShortName"}, "__")==0)
            {
                return 0;
            }
            if($ClassId)
            {
                if(my $NameSpace = $TypeInfo{$ClassId}{"NameSpace"})
                {
                    if(my $NSId = $TName_Tid{$NameSpace})
                    {
                        if($TypeInfo{$NSId}{"Type"}=~/Struct|Class/)
                        { # internal classes
                            return 0;
                        }
                    }
                    
                }
            }
        }
        return 0 if($CompleteSignature{$Symbol}{"Weak"});
    }
    if(index($Symbol, "_ZN9__gnu_cxx")==0) {
        return 0;
    }
    if($CompleteSignature{$Symbol}{"Constructor"}) {
        return ( not ($Symbol=~/C1E/ and ($CompleteSignature{$Symbol}{"Protected"} or isAbstractClass($ClassId))) );
    }
    elsif($CompleteSignature{$Symbol}{"Destructor"}) {
        return ( not ($Symbol=~/D0E|D1E/ and ($CompleteSignature{$Symbol}{"Protected"} or isAbstractClass($ClassId))) );
    }
    return 1;
}

sub addHeaders($$)
{
    my ($NewHeaders, $OldHeaders) = @_;
    my (%Old, @Before, @After) = ();
    if($OldHeaders)
    {
        foreach (@{$OldHeaders})
        {
            if($_)
            {
                $Old{$_} = 1;
                push(@After, $_);
            }
        }
    }
    if($NewHeaders)
    {
        foreach (@{$NewHeaders})
        {
            if($_)
            {
                if(not defined $Old{$_}) {
                    push(@Before, $_);
                }
            }
        }
    }
    my @Result = (@Before, @After);
    return \@Result;
}

sub getTypeHeaders($)
{
    my $TypeId = $_[0];
    return [] if(not $TypeId);
    my %Type = delete_quals($TypeId);
    my $Headers = [$TypeInfo{$Type{"Tid"}}{"Header"}];
    if(defined $Type{"TParam"})
    { # template parameters
        foreach my $Pos (sort {int($a)<=>int($b)} keys(%{$Type{"TParam"}}))
        {
            if(my $Tid = $TName_Tid{$Type{"TParam"}{$Pos}}) {
                $Headers = addHeaders(getTypeHeaders($Tid), $Headers);
            }
        }
    }
    if(my $NS = $Type{"NameSpaceClassId"}) {
        $Headers = addHeaders(getTypeHeaders($NS), $Headers);
    }
    return $Headers;
}

sub get_TypeName($)
{
    my $TypeId = $_[0];
    return $TypeInfo{$TypeId}{"Name"};
}

sub get_TypeType($)
{
    my $TypeId = $_[0];
    return $TypeInfo{$TypeId}{"Type"};
}

sub get_TypeAttr($$)
{
    my ($TypeId, $Attr) = @_;
    return $TypeInfo{$TypeId}{$Attr};
}

sub isNotInCharge($)
{
    my $Interface = $_[0];
    return ($CompleteSignature{$Interface}{"Constructor"}
    and $Interface=~/C2E/);
}

sub isInCharge($)
{
    my $Interface = $_[0];
    return ($CompleteSignature{$Interface}{"Constructor"}
    and $Interface=~/C1E/);
}

sub replace_c2c1($)
{
    my $Interface = $_[0];
    if($CompleteSignature{$Interface}{"Constructor"}) {
        $Interface=~s/C2E/C1E/;
    }
    return $Interface;
}

sub getSubClassName($)
{
    my $ClassName = $_[0];
    return getSubClassBaseName($ClassName)."_SubClass";
}

sub getSubClassBaseName($)
{
    my $ClassName = $_[0];
    $ClassName=~s/\:\:|<|>|\(|\)|\[|\]|\ |,|\*/_/g;
    $ClassName=~s/[_][_]+/_/g;
    return $ClassName;
}

sub getNumOfParams($)
{
    my $Interface = $_[0];
    my @Params = keys(%{$CompleteSignature{$Interface}{"Param"}});
    return ($#Params + 1);
}

sub sort_byCriteria($$)
{
    my ($Interfaces, $Criteria) = @_;
    my (@NewInterfaces1, @NewInterfaces2) = ();
    foreach my $Interface (@{$Interfaces})
    {
        if(compare_byCriteria($Interface, $Criteria)) {
            push(@NewInterfaces1, $Interface);
        }
        else {
            push(@NewInterfaces2, $Interface);
        }
    }
    @{$Interfaces} = (@NewInterfaces1, @NewInterfaces2);
}

sub get_int_prefix($)
{
    if($_[0]=~/\A([a-z0-9]+)_[a-z0-9]/i) {
        return $1;
    }
    return "";
}

sub sort_byLibrary($$)
{
    my ($Interfaces, $Library) = @_;
    return if(not $Library);
    my $LibPrefix = $SoLib_IntPrefix{$Library};
    my (@NewInterfaces1, @NewInterfaces2, @NewInterfaces3) = ();
    foreach my $Interface (@{$Interfaces})
    {
        my $IntPrefix = get_int_prefix($Interface);
        if(get_filename($Symbol_Library{$Interface}) eq $Library
        or get_filename($DepSymbol_Library{$Interface}) eq $Library) {
            push(@NewInterfaces1, $Interface);
        }
        elsif(not $Symbol_Library{$Interface}
        and not $DepSymbol_Library{$Interface}) {
            push(@NewInterfaces1, $Interface);
        }
        elsif($Interface=~/environment/i)
        { # functions to set evironment should NOT be sorted
            push(@NewInterfaces1, $Interface);
        }
        elsif($LibPrefix and ($LibPrefix eq $IntPrefix)) {
            push(@NewInterfaces2, $Interface);
        }
        else {
            push(@NewInterfaces3, $Interface);
        }
    }
    @{$Interfaces} = (@NewInterfaces1, @NewInterfaces2, @NewInterfaces3);
}

sub get_tokens($)
{
    my $Word = $_[0];
    return $Cache{"get_tokens"}{$Word} if(defined $Cache{"get_tokens"}{$Word});
    my @Tokens = ();
    if($Word=~/\s+|[_]+/)
    {
        foreach my $Elem (split(/[_:\s]+/, $Word))
        {
            foreach my $SubElem (@{get_tokens($Elem)}) {
                push(@Tokens, $SubElem);
            }
        }
    }
    else
    {
        my $WCopy = $Word;
        while($WCopy=~s/([A-Z]*[a-z]+|\d+)//) {
            push(@Tokens, lc($1));
        }
        $WCopy=$Word;
        while($WCopy=~s/([A-Z]{2,})//) {
            push(@Tokens, lc($1));
        }
        $WCopy=$Word;
        while($WCopy=~s/([A-Z][a-z]+)([A-Z]|\Z)/$2/) {
            push(@Tokens, lc($1));
        }
    }
    @Tokens = unique_array(@Tokens);
    $Cache{"get_tokens"}{$Word} = \@Tokens;
    return \@Tokens;
}

sub unique_array(@)
{
    my %seen = ();
    my @uniq = ();
    foreach my $item (@_)
    {
        unless ($seen{$item})
        { # if we get here, we have not seen it before
            $seen{$item} = 1;
            push(@uniq, $item);
        }
    }
    return @uniq;
}

sub sort_byName($$$)
{
    my ($Words, $KeyWords, $Type) = @_;
    my %Word_Coincidence = ();
    foreach my $Word (@{$Words})
    {
        my $TargetWord = $Word;
        if($Word=~/\A(_Z|\?)/) {
            $TargetWord = $CompleteSignature{$Word}{"ShortName"}." ".get_TypeName($CompleteSignature{$Word}{"Class"});
        }
        $Word_Coincidence{$Word} = get_word_coinsidence($TargetWord, $KeyWords);
    }
    @{$Words} = sort {$Word_Coincidence{$b} <=> $Word_Coincidence{$a}} @{$Words};
    if($Type eq "Constants")
    {
        my @Words_With_Tokens = ();
        foreach my $Word (@{$Words})
        {
            if($Word_Coincidence{$Word}>0) {
                push(@Words_With_Tokens, $Word);
            }
        }
        @{$Words} = @Words_With_Tokens;
    }
}

sub sort_FileOpen($)
{
    my @Interfaces = @{$_[0]};
    my (@FileOpen, @Other) = ();
    foreach my $Interface (sort {length($a) <=> length($b)} @Interfaces)
    {
        if($CompleteSignature{$Interface}{"ShortName"}=~/fopen/i) {
            push(@FileOpen, $Interface);
        }
        else {
            push(@Other, $Interface);
        }
    }
    @{$_[0]} = (@FileOpen, @Other);
}

sub get_word_coinsidence($$)
{
    my ($Word, $KeyWords) = @_;
    my @WordTokens1 = @{get_tokens($Word)};
    return 0 if($#WordTokens1==-1);
    my %WordTokens_Inc = ();
    my $WordTokens_Num = 0;
    foreach my $Token (@WordTokens1)
    {
        next if($Token=~/\A(get|create|new|insert)\Z/);
        $WordTokens_Inc{$Token} = ++$WordTokens_Num;
    }
    my @WordTokens2 = @{get_tokens($KeyWords)};
    return 0 if($#WordTokens2==-1);
    my $Weight=$#WordTokens2+2;
    my $StartWeight = $Weight;
    my $WordCoincidence = 0;
    foreach my $Token (@WordTokens2)
    {
        next if($Token=~/\A(get|create|new|insert)\Z/);
        if(defined $WordTokens_Inc{$Token} or defined $WordTokens_Inc{$ShortTokens{$Token}})
        {
            if($WordTokens_Inc{$Token}==1
            and $Library_Prefixes{$Token}+$Library_Prefixes{$Token."_"}>=$LIBRARY_PREFIX_MAJORITY)
            { # first token is usually a library prefix
                $WordCoincidence+=$Weight;
            }
            else {
                $WordCoincidence+=$Weight-$WordTokens_Num/($StartWeight+$WordTokens_Num);
            }
        }
        $Weight-=1;
    }
    return $WordCoincidence*100/($#WordTokens2+1);
}

sub compare_byCriteria($$)
{
    my ($Interface, $Criteria) = @_;
    if($Criteria eq "DeleteSmth") {
        return $CompleteSignature{$Interface}{"ShortName"}!~/delete|remove|destroy|cancel/i;
    }
    elsif($Criteria eq "InLine") {
        return $CompleteSignature{$Interface}{"InLine"};
    }
    elsif($Criteria eq "Function") {
        return $CompleteSignature{$Interface}{"Type"} eq "Function";
    }
    elsif($Criteria eq "WithParams") {
        return getNumOfParams($Interface);
    }
    elsif($Criteria eq "WithoutParams") {
        return getNumOfParams($Interface)==0;
    }
    elsif($Criteria eq "Public") {
        return (not $CompleteSignature{$Interface}{"Protected"});
    }
    elsif($Criteria eq "Default") {
        return ($Interface=~/default/i);
    }
    elsif($Criteria eq "VaList") {
        return ($Interface!~/valist/i);
    }
    elsif($Criteria eq "NotInCharge") {
        return (not isNotInCharge($Interface));
    }
    elsif($Criteria eq "Class") {
        return (get_TypeName($CompleteSignature{$Interface}{"Class"}) ne "QApplication");
    }
    elsif($Criteria eq "Data") {
        return (not $CompleteSignature{$Interface}{"Data"});
    }
    elsif($Criteria eq "FirstParam_Intrinsic")
    {
        if(defined $CompleteSignature{$Interface}{"Param"}
        and defined $CompleteSignature{$Interface}{"Param"}{"0"})
        {
            my $FirstParamType_Id = $CompleteSignature{$Interface}{"Param"}{"0"}{"type"};
            return (get_TypeType(get_FoundationTypeId($FirstParamType_Id)) eq "Intrinsic");
        }
        else {
            return 0;
        }
    }
    elsif($Criteria eq "FirstParam_Enum")
    {
        if(defined $CompleteSignature{$Interface}{"Param"}
        and defined $CompleteSignature{$Interface}{"Param"}{"0"})
        {
            my $FirstParamType_Id = $CompleteSignature{$Interface}{"Param"}{"0"}{"type"};
            return (get_TypeType(get_FoundationTypeId($FirstParamType_Id)) eq "Enum");
        }
        else {
            return 0;
        }
    }
    elsif($Criteria eq "FirstParam_PKc")
    {
        if(defined $CompleteSignature{$Interface}{"Param"}
        and defined $CompleteSignature{$Interface}{"Param"}{"0"})
        {
            my $FirstParamType_Id = $CompleteSignature{$Interface}{"Param"}{"0"}{"type"};
            return (get_TypeName($FirstParamType_Id) eq "char const*");
        }
        else {
            return 0;
        }
    }
    elsif($Criteria eq "FirstParam_char")
    {
        if(defined $CompleteSignature{$Interface}{"Param"}
        and defined $CompleteSignature{$Interface}{"Param"}{"0"})
        {
            my $FirstParamType_Id = $CompleteSignature{$Interface}{"Param"}{"0"}{"type"};
            return (get_TypeName($FirstParamType_Id) eq "char");
        }
        else {
            return 0;
        }
    }
    elsif($Criteria eq "Operator") {
        return ($CompleteSignature{$Interface}{"ShortName"}!~/operator[^a-z]/i);
    }
    elsif($Criteria eq "Library") {
        return ($Symbol_Library{$Interface} or $Library_Class{$CompleteSignature{$Interface}{"Class"}});
    }
    elsif($Criteria eq "Internal") {
        return ($CompleteSignature{$Interface}{"ShortName"}!~/\A_/);
    }
    elsif($Criteria eq "Internal") {
        return ($CompleteSignature{$Interface}{"ShortName"}!~/debug/i);
    }
    elsif($Criteria eq "FileManipulating")
    {
        return 0 if($CompleteSignature{$Interface}{"ShortName"}=~/fopen|file/);
        foreach my $ParamPos (keys(%{$CompleteSignature{$Interface}{"Param"}}))
        {
            my $ParamTypeId = $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"type"};
            my $ParamName = $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"name"};
            if(isString($ParamTypeId, $ParamName, $Interface))
            {
                return 0 if(isStr_FileName($ParamPos, $ParamName, $CompleteSignature{$Interface}{"ShortName"})
                or isStr_Dir($ParamName, $CompleteSignature{$Interface}{"ShortName"}));
            }
            else {
                return 0 if(isFD($ParamTypeId, $ParamName));
            }
        }
        return 1;
    }
    else {
        return 1;
    }
}

sub sort_byRecurParams($)
{
    my @Interfaces = @{$_[0]};
    my (@Other, @WithRecurParams) = ();
    foreach my $Interface (@Interfaces)
    {
        my $WithRecur = 0;
        foreach my $ParamPos (keys(%{$CompleteSignature{$Interface}{"Param"}}))
        {
            my $ParamType_Id = $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"type"};
            if(isCyclical(\@RecurTypeId, get_TypeStackId($ParamType_Id))) {
                $WithRecur=1;
                last;
            }
        }
        if($WithRecur) {
            push(@WithRecurParams, $Interface);
        }
        else
        {
            if($CompleteSignature{$Interface}{"ShortName"}!~/copy|duplicate/i) {
                push(@Other, $Interface);
            }
        }
    }
    @{$_[0]} = (@Other, @WithRecurParams);
    return $#WithRecurParams;
}

sub sort_LibMainFunc($)
{
    my @Interfaces = @{$_[0]};
    my (@First, @Other) = ();
    foreach my $Interface (@Interfaces)
    {
        my $ShortName = cut_NamePrefix($CompleteSignature{$Interface}{"ShortName"});
        if($ShortName=~/\A(create|default|get|new|init)\Z/i) {
            push(@First, $Interface);
        }
        else {
             push(@Other, $Interface);
        }
    }
    @{$_[0]} = (@First, @Other);
}

sub sort_CreateParam($$)
{
    my @Interfaces = @{$_[0]};
    my $KeyWords = $_[1];
    foreach my $Prefix (keys(%Library_Prefixes))
    {
        if($Library_Prefixes{$Prefix}>=$LIBRARY_PREFIX_MAJORITY) {
            $KeyWords=~s/(\A| )$Prefix/$1/g;
        }
    }
    $KeyWords=~s/(\A|_)(new|get|create|default|alloc|init)(_|\Z)//g;
    my (@First, @Other) = ();
    foreach my $Interface (@Interfaces)
    {
        my $ShortName = $CompleteSignature{$Interface}{"ShortName"};
        if($ShortName=~/create|default|get|new|init/i
        and get_word_coinsidence($ShortName, $KeyWords)>0) {
            push(@First, $Interface);
        }
        else {
             push(@Other, $Interface);
        }
    }
    @{$_[0]} = (@First, @Other);
}

sub grep_token($$)
{
    my ($Word, $Token) = @_;
    return grep(/\A($Token)\Z/i, @{get_tokens($Word)});
}

sub cut_NamePrefix($)
{
    my $Name = $_[0];
    return "" if(not $Name);
    if(my $Prefix = getPrefix($Name))
    {
        if($Library_Prefixes{$Prefix}>=$LIBRARY_PREFIX_MAJORITY) {
            $Name=~s/\A\Q$Prefix\E//;
        }
    }
    return $Name;
}

sub sort_GetCreate($)
{
    my @Interfaces = @{$_[0]};
    my (@Open, @Root, @Create, @Default, @New, @Alloc, @Init, @Get, @Other, @Copy, @Wait) = ();
    foreach my $Interface (@Interfaces)
    {
        my $ShortName = $CompleteSignature{$Interface}{"ShortName"};
        if(grep_token($ShortName, "open")) {
            push(@Open, $Interface);
        }
        elsif(grep_token($ShortName, "root")
        and grep_token($ShortName, "default")) {
            push(@Root, $Interface);
        }
        elsif(grep_token($ShortName, "create")) {
            push(@Create, $Interface);
        }
        elsif(grep_token($ShortName, "default")
        and not grep_token($ShortName, "get")) {
            push(@Default, $Interface);
        }
        elsif(grep_token($ShortName, "new")) {
            push(@New, $Interface);
        }
        elsif(is_alloc_func($ShortName)) {
            push(@Alloc, $Interface);
        }
        elsif(grep_token($ShortName, "init")) {
            push(@Init, $Interface);
        }
        elsif(grep_token($ShortName, "get")) {
            push(@Get, $Interface);
        }
        elsif(grep_token($ShortName, "copy")) {
            push(@Copy, $Interface);
        }
        elsif(grep_token($ShortName, "wait")) {
            push(@Wait, $Interface);
        }
        else {
            push(@Other, $Interface);
        }
    }
    my @PrimaryGroup = (@Open, @Root, @Create, @Default);
    sort_byCriteria(\@PrimaryGroup, "WithoutParams");
    @{$_[0]} = (@PrimaryGroup, @New, @Alloc, @Init, @Get, @Other, @Copy, @Wait);
}

sub get_CompatibleInterfaces($$$)
{
    my ($TypeId, $Method, $KeyWords) = @_;
    return () if(not $TypeId or not $Method);
    my @Ints = compatible_interfaces($TypeId, $Method, $KeyWords);
    sort_byRecurParams(\@Ints) if(get_TypeName($TypeId)!~/time_t/);
    return @Ints;
}

sub compatible_interfaces($$$)
{
    my ($TypeId, $Method, $KeyWords) = @_;
    return () if(not $TypeId or not $Method);
    if(defined $Cache{"compatible_interfaces"}{$TypeId}{$Method}{$KeyWords}
    and not defined $RandomCode and not defined $AuxType{$TypeId}) {
        return @{$Cache{"compatible_interfaces"}{$TypeId}{$Method}{$KeyWords}};
    }
    my @Symbols = ();
    if($Method eq "Construct")
    {
        foreach my $Constructor (keys(%{$Class_Constructors{$TypeId}})) {
            @Symbols = (@Symbols, $Constructor);
        }
    }
    elsif($Method eq "Return")
    {
        foreach my $Interface (keys(%{$ReturnTypeId_Interface{$TypeId}}))
        {
            next if($CompleteSignature{$Interface}{"PureVirt"});
            @Symbols = (@Symbols, $Interface);
        }
    }
    elsif($Method eq "OutParam")
    {
        foreach my $Interface (keys(%{$OutParam_Interface{$TypeId}}))
        {
            next if($CompleteSignature{$Interface}{"Protected"});
            next if($CompleteSignature{$Interface}{"PureVirt"});
            @Symbols = (@Symbols, $Interface);
        }
    }
    elsif($Method eq "OnlyReturn")
    {
        foreach my $Interface (keys(%{$ReturnTypeId_Interface{$TypeId}}))
        {
            next if($CompleteSignature{$Interface}{"PureVirt"});
            next if($CompleteSignature{$Interface}{"Data"});
            @Symbols = (@Symbols, $Interface);
        }
    }
    elsif($Method eq "OnlyData")
    {
        foreach my $Interface (keys(%{$ReturnTypeId_Interface{$TypeId}}))
        {
            next if(not $CompleteSignature{$Interface}{"Data"});
            @Symbols = (@Symbols, $Interface);
        }
    }
    else
    {
        @{$Cache{"compatible_interfaces"}{$TypeId}{$Method}{$KeyWords}} = ();
        return ();
    }
    
    my @CompatibleInterfaces = ();
    
    foreach my $Symbol (@Symbols)
    {
        next if(skipSymbol($Symbol));
        next if($CompleteSignature{$Symbol}{"Private"});
        
        push(@CompatibleInterfaces, $Symbol);
    }
    
    if($#CompatibleInterfaces==-1)
    {
        @{$Cache{"compatible_interfaces"}{$TypeId}{$Method}{$KeyWords}} = ();
        return ();
    }
    elsif($#CompatibleInterfaces==0)
    {
        @{$Cache{"compatible_interfaces"}{$TypeId}{$Method}{$KeyWords}} = @CompatibleInterfaces;
        return @CompatibleInterfaces;
    }
    # sort by name
    @CompatibleInterfaces = sort @CompatibleInterfaces;
    @CompatibleInterfaces = sort {$CompleteSignature{$a}{"ShortName"} cmp $CompleteSignature{$b}{"ShortName"}} (@CompatibleInterfaces);
    @CompatibleInterfaces = sort {length($CompleteSignature{$a}{"ShortName"}) <=> length($CompleteSignature{$b}{"ShortName"})} (@CompatibleInterfaces);
    # sort by number of parameters
    if(defined $MinimumCode) {
        @CompatibleInterfaces = sort {int(keys(%{$CompleteSignature{$a}{"Param"}}))<=>int(keys(%{$CompleteSignature{$b}{"Param"}}))} (@CompatibleInterfaces);
    }
    elsif(defined $MaximumCode) {
        @CompatibleInterfaces = sort {int(keys(%{$CompleteSignature{$b}{"Param"}}))<=>int(keys(%{$CompleteSignature{$a}{"Param"}}))} (@CompatibleInterfaces);
    }
    else
    {
        sort_byCriteria(\@CompatibleInterfaces, "FirstParam_Intrinsic");
        sort_byCriteria(\@CompatibleInterfaces, "FirstParam_char");
        sort_byCriteria(\@CompatibleInterfaces, "FirstParam_PKc");
        sort_byCriteria(\@CompatibleInterfaces, "FirstParam_Enum") if(get_TypeName($TypeId)!~/char|string/i or $Method ne "Construct");
        @CompatibleInterfaces = sort {int(keys(%{$CompleteSignature{$a}{"Param"}}))<=>int(keys(%{$CompleteSignature{$b}{"Param"}}))} (@CompatibleInterfaces);
        @CompatibleInterfaces = sort {$b=~/virtual/i <=> $a=~/virtual/i} (@CompatibleInterfaces);
        sort_byCriteria(\@CompatibleInterfaces, "WithoutParams");
        sort_byCriteria(\@CompatibleInterfaces, "WithParams") if($Method eq "Construct");
    }
    sort_byCriteria(\@CompatibleInterfaces, "Operator");
    sort_byCriteria(\@CompatibleInterfaces, "FileManipulating");
    if($Method ne "Construct")
    {
        sort_byCriteria(\@CompatibleInterfaces, "Class");
        sort_CreateParam(\@CompatibleInterfaces, $KeyWords);
        
        # TODO: What should be first?
        # sort_byName(\@CompatibleInterfaces, $KeyWords, "Interfaces");
        sort_GetCreate(\@CompatibleInterfaces);
        
        sort_FileOpen(\@CompatibleInterfaces) if(get_TypeName(get_FoundationTypeId($TypeId))=~/\A(struct |)(_IO_FILE|__FILE|FILE|_iobuf)\Z/);
        sort_LibMainFunc(\@CompatibleInterfaces);
        sort_byCriteria(\@CompatibleInterfaces, "Data");
        sort_byCriteria(\@CompatibleInterfaces, "Function");
        sort_byCriteria(\@CompatibleInterfaces, "Library");
        sort_byCriteria(\@CompatibleInterfaces, "Internal");
        sort_byCriteria(\@CompatibleInterfaces, "Debug");
        if(get_TypeName($TypeId) ne "GType"
        and (my $Lib = get_TypeLib($TypeId)) ne "unknown") {
            sort_byLibrary(\@CompatibleInterfaces, $Lib);
        }
    }
    if(defined $RandomCode) {
        @CompatibleInterfaces = mix_array(@CompatibleInterfaces);
    }
    sort_byCriteria(\@CompatibleInterfaces, "Public");
    sort_byCriteria(\@CompatibleInterfaces, "NotInCharge") if($Method eq "Construct");
    @{$Cache{"compatible_interfaces"}{$TypeId}{$Method}{$KeyWords}} = @CompatibleInterfaces if(not defined $RandomCode);
    return @CompatibleInterfaces;
}

sub mix_array(@)
{
    my @Array = @_;
    return sort {2 * rand($#Array) - $#Array} @_;
}

sub getSomeConstructor($)
{
    my $ClassId = $_[0];
    my @Constructors = get_CompatibleInterfaces($ClassId, "Construct", "");
    return $Constructors[0];
}

sub getTypeParString($)
{
    my $Interface = $_[0];
    my $NumOfParams = getNumOfParams($Interface);
    if($NumOfParams == 0) {
        return ("()", "()", "()");
    }
    else
    {
        my (@TypeParList, @ParList, @TypeList) = ();
        foreach my $Param_Pos (sort {int($a)<=>int($b)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
        {
            next if(apply_default_value($Interface, $Param_Pos) and not $CompleteSignature{$Interface}{"PureVirt"});
            my $ParamName = $CompleteSignature{$Interface}{"Param"}{$Param_Pos}{"name"};
            $ParamName = "p".($Param_Pos + 1) if(not $ParamName);
            my $TypeId = $CompleteSignature{$Interface}{"Param"}{$Param_Pos}{"type"};
            my %Type = get_Type($TypeId);
            next if($Type{"Name"} eq "...");
            push(@ParList, $ParamName);
            push(@TypeList, $Type{"Name"});
            push(@TypeParList, create_member_decl($Type{"Name"}, $ParamName));
        }
        my $TypeParString .= "(".create_list(\@TypeParList, "    ").")";
        my $ParString .= "(".create_list(\@ParList, "    ").")";
        my $TypeString .= "(".create_list(\@TypeList, "    ").")";
        return ($TypeParString, $ParString, $TypeString);
    }
}

sub getValueClass($)
{
    my $Value = $_[0];
    $Value=~/([^()"]+)\(.*\)[^()]*/;
    my $ValueClass = $1;
    $ValueClass=~s/[ ]+\Z//g;
    if(get_TypeIdByName($ValueClass)) {
        return $ValueClass;
    }
    return "";
}

sub get_FoundationType($)
{
    my $TypeId = $_[0];
    return "" if(not $TypeId);
    if(defined $Cache{"get_FoundationType"}{$TypeId}
    and not defined $AuxType{$TypeId}) {
        return %{$Cache{"get_FoundationType"}{$TypeId}};
    }
    return "" if(not $TypeInfo{$TypeId});
    my %Type = %{$TypeInfo{$TypeId}};
    return %Type if(not $Type{"BaseType"});
    
    return %Type if($Type{"Type"} eq "Array");
    
    %Type = get_FoundationType($Type{"BaseType"});
    $Cache{"get_FoundationType"}{$TypeId} = \%Type;
    return %Type;
}

sub get_BaseType($)
{
    my $TypeId = $_[0];
    return "" if(not $TypeId);
    if(defined $Cache{"get_BaseType"}{$TypeId}
    and not defined $AuxType{$TypeId}) {
        return %{$Cache{"get_BaseType"}{$TypeId}};
    }
    return "" if(not $TypeInfo{$TypeId});
    my %Type = %{$TypeInfo{$TypeId}};
    return %Type if(not $Type{"BaseType"});
    %Type = get_BaseType($Type{"BaseType"});
    $Cache{"get_BaseType"}{$TypeId} = \%Type;
    return %Type;
}

sub get_FoundationTypeId($)
{
    my $TypeId = $_[0];
    if(defined $Cache{"get_FoundationTypeId"}{$TypeId}
    and not defined $AuxType{$TypeId}) {
        return $Cache{"get_FoundationTypeId"}{$TypeId};
    }
    my %BaseType = get_FoundationType($TypeId);
    return ($Cache{"get_FoundationTypeId"}{$TypeId} = $BaseType{"Tid"});
}

sub create_SubClass($)
{
    my $ClassId = $_[0];
    return () if(not $ClassId);
    
    my ($Declaration, $Headers, $Code);
    foreach my $Constructor (keys(%{$UsedConstructors{$ClassId}}))
    {
        if(isNotInCharge($Constructor)
        and my $InChargeConstructor = replace_c2c1($Constructor))
        {
            if($CompleteSignature{$InChargeConstructor})
            {
                $UsedConstructors{$ClassId}{$Constructor} = 0;
                $UsedConstructors{$ClassId}{$InChargeConstructor} = 1;
            }
        }
    }
    $Headers = addHeaders(getTypeHeaders($ClassId), $Headers);
    
    my $ClassNameOrig = get_TypeName($ClassId);
    my $ClassName = $ClassNameOrig;
    if(my $Typedef = $Class_SubClassTypedef{$ClassId}) {
        $ClassName = get_TypeName($Typedef);
    }
    my $ClassNameChild = getSubClassName($ClassName);
    
    $Declaration .= "class $ClassNameChild".": public $ClassName\n{\n";
    $Declaration .= "public:\n";
    if(not keys(%{$UsedConstructors{$ClassId}}))
    {
        if(my $SomeConstructor = getSomeConstructor($ClassId)) {
            $UsedConstructors{$ClassId}{$SomeConstructor} = 1;
        }
    }
    if(defined $UsedConstructors{$ClassId}
    and keys(%{$UsedConstructors{$ClassId}}))
    {
        foreach my $Constructor (sort keys(%{$UsedConstructors{$ClassId}}))
        {
            next if(not $Constructor);
            my $PreviousBlock = $CurrentBlock;
            $CurrentBlock = $Constructor;
            if($UsedConstructors{$ClassId}{$Constructor})
            {
                my ($TypeParString, $ParString, $TypeString) = getTypeParString($Constructor);
                $TypeParString = alignCode($TypeParString, "    ", 1);
                $ParString = alignCode($ParString, "        ", 1);
                $Declaration .= "    $ClassNameChild"."$TypeParString\:$ClassName"."$ParString\{\}\n\n";
                foreach my $Param_Pos (sort {int($b)<=>int($a)} keys(%{$CompleteSignature{$Constructor}{"Param"}}))
                {
                    my $Param_TypeId = $CompleteSignature{$Constructor}{"Param"}{$Param_Pos}{"type"};
                    my $Param_Name = $CompleteSignature{$Constructor}{"Param"}{$Param_Pos}{"name"};
                    $Param_Name = "p".($Param_Pos + 1) if(not $Param_Name);
                    $ValueCollection{$CurrentBlock}{$Param_Name} = $Param_TypeId;
                    $Block_Param{$CurrentBlock}{$Param_Name} = $Param_TypeId;
                    $Block_Variable{$CurrentBlock}{$Param_Name} = 1;
                }
            }
            $CurrentBlock = $PreviousBlock;
        }
    }
    else {
        $Declaration .= "    ".$ClassNameChild."();\n";
    }
    if(defined $Class_PureVirtFunc{$ClassNameOrig})
    {
        my %RedefinedTwice = ();
        my @PureVirtuals = keys(%{$Class_PureVirtFunc{$ClassNameOrig}});
        @PureVirtuals = sort {lc($CompleteSignature{$a}{"ShortName"}) cmp lc($CompleteSignature{$b}{"ShortName"})} @PureVirtuals;
        @PureVirtuals = sort {defined $Class_PureMethod{$ClassId}{$b} cmp defined $Class_PureMethod{$ClassId}{$a}} @PureVirtuals;
        foreach my $PureVirtualMethod (@PureVirtuals)
        {
            my $PreviousBlock = $CurrentBlock;
            $CurrentBlock = $PureVirtualMethod;
            delete($ValueCollection{$CurrentBlock});
            delete($Block_Variable{$CurrentBlock});
            my $ReturnTypeId = $CompleteSignature{$PureVirtualMethod}{"Return"};
            my $ReturnTypeName = get_TypeName($ReturnTypeId);
            my ($TypeParString, $ParString, $TypeString) = getTypeParString($PureVirtualMethod);
            $TypeParString = alignCode($TypeParString, "    ", 1);
            my ($PureVirtualMethodName, $ShortName) = ("", "");
            if($CompleteSignature{$PureVirtualMethod}{"Constructor"})
            {
                $ShortName = $ClassNameChild;
                $PureVirtualMethodName = "    ".$ShortName.$TypeParString;
            }
            if($CompleteSignature{$PureVirtualMethod}{"Destructor"})
            {
                $ShortName = "~".$ClassNameChild;
                $PureVirtualMethodName = "   ".$ShortName.$TypeParString;
            }
            else
            {
                $ShortName = $CompleteSignature{$PureVirtualMethod}{"ShortName"};
                $PureVirtualMethodName = "    ".$ReturnTypeName." ".$ShortName.$TypeParString;
            }
            if($CompleteSignature{$PureVirtualMethod}{"Throw"}) {
                $PureVirtualMethodName .= " throw()";
            }
            my $Const = ($PureVirtualMethod=~/\A_ZNK/)?" const":"";
            if($RedefinedTwice{$ShortName.$TypeString.$Const})
            { # skip pure methods from the base with the same signature
                next;
            }
            $RedefinedTwice{$ShortName.$TypeString.$Const} = 1;
            $Declaration .= "\n" if($PureVirtualMethodName=~/\n/);
            foreach my $Param_Pos (sort {int($b)<=>int($a)} keys(%{$CompleteSignature{$PureVirtualMethod}{"Param"}}))
            {
                my $Param_TypeId = $CompleteSignature{$PureVirtualMethod}{"Param"}{$Param_Pos}{"type"};
                my $Param_Name = $CompleteSignature{$PureVirtualMethod}{"Param"}{$Param_Pos}{"name"};
                $Param_Name = "p".($Param_Pos + 1) if(not $Param_Name);
                $ValueCollection{$CurrentBlock}{$Param_Name} = $Param_TypeId;
                $Block_Param{$CurrentBlock}{$Param_Name} = $Param_TypeId;
                $Block_Variable{$CurrentBlock}{$Param_Name} = 1;
            }
            if(get_TypeName($ReturnTypeId) eq "void"
            or $CompleteSignature{$PureVirtualMethod}{"Constructor"}
            or $CompleteSignature{$PureVirtualMethod}{"Destructor"}) {
                $Declaration .= $PureVirtualMethodName.$Const."\{\}\n\n";
            }
            elsif(get_TypeName($ReturnTypeId) eq get_TypeName($ClassId)."*")
            { # clone, copy, etc.
                $Declaration .= $PureVirtualMethodName.$Const."\{\n       return (".get_TypeName($ReturnTypeId).")this;\n    \}\n\n";
            }
            else
            {
                $Declaration .= $PureVirtualMethodName.$Const." {\n";
                my $ReturnTypeHeaders = getTypeHeaders($ReturnTypeId);
                push(@RecurInterface, $PureVirtualMethod);
                my %Param_Init = initializeParameter((
                    "ParamName" => "retval",
                    "AccessToParam" => {"obj"=>"no object"},
                    "TypeId" => $ReturnTypeId,
                    "Key" => "_ret",
                    "InLine" => 1,
                    "Value" => "no value",
                    "CreateChild" => 0,
                    "SpecType" => 0,
                    "Usage" => "Common",
                    "RetVal" => 1));
                pop(@RecurInterface);
                $Code .= $Param_Init{"Code"};
                $Headers = addHeaders($Param_Init{"Headers"}, $Headers);
                $Headers = addHeaders($ReturnTypeHeaders, $Headers);
                $Param_Init{"Init"} = alignCode($Param_Init{"Init"}, "       ", 0);
                $Param_Init{"Call"} = alignCode($Param_Init{"Call"}, "       ", 1);
                $Declaration .= $Param_Init{"Init"}."       return ".$Param_Init{"Call"}.";\n    }\n\n";
            }
            $CurrentBlock = $PreviousBlock;
        }
    }
    if(defined $UsedProtectedMethods{$ClassId})
    {
        foreach my $ProtectedMethod (sort {lc($CompleteSignature{$a}{"ShortName"}) cmp lc($CompleteSignature{$b}{"ShortName"})} keys(%{$UsedProtectedMethods{$ClassId}}))
        {
            my $ReturnType_Id = $CompleteSignature{$ProtectedMethod}{"Return"};
            my $ReturnType_Name = get_TypeName($ReturnType_Id);
            my $ReturnType_PointerLevel = get_PointerLevel($ReturnType_Id);
            my $ReturnFType_Id = get_FoundationTypeId($ReturnType_Id);
            my $ReturnFType_Name = get_TypeName($ReturnFType_Id);
            my $Break = ((length($ReturnType_Name)>20)?"\n":" ");
            my $ShortName = $CompleteSignature{$ProtectedMethod}{"ShortName"};
            my $ShortNameAdv = $ShortName."_Wrapper";
            $ShortNameAdv = cleanName($ShortNameAdv);
            $Declaration .= "    ".$ReturnType_Name." ".$ShortNameAdv."() {\n";
            if($Wrappers{$ProtectedMethod}{"Init"}) {
                $Declaration .= alignCode($Wrappers{$ProtectedMethod}{"Init"}, "       ", 0);
            }
            $Declaration .= alignCode($Wrappers{$ProtectedMethod}{"PreCondition"}, "      ", 0);
            my $FuncCall = "this->".alignCode($ShortName.$Wrappers{$ProtectedMethod}{"Parameters_Call"}, "      ", 1);
            if($Wrappers{$ProtectedMethod}{"PostCondition"} or $Wrappers{$ProtectedMethod}{"FinalCode"})
            {
                my $PostCode = alignCode($Wrappers{$ProtectedMethod}{"PostCondition"}, "      ", 0).alignCode($Wrappers{$ProtectedMethod}{"FinalCode"}, "      ", 0);
                # FIXME: destructors
                if($ReturnFType_Name eq "void" and $ReturnType_PointerLevel==0) {
                    $Declaration .= "       $FuncCall;\n".$PostCode;
                }
                else
                {
                    my $RetVal = select_var_name("retval", "");
                    my ($InitializedEType_Id, $Ret_Declarations, $Ret_Headers) = get_ExtTypeId($RetVal, $ReturnType_Id);
                    $Code .= $Ret_Declarations;
                    $Headers = addHeaders($Ret_Headers, $Headers);
                    my $InitializedType_Name = get_TypeName($InitializedEType_Id);
                    if($InitializedType_Name eq $ReturnType_Name) {
                        $Declaration .= "      ".$InitializedType_Name.$Break.$RetVal." = $FuncCall;\n".$PostCode;
                    }
                    else {
                        $Declaration .= "      ".$InitializedType_Name.$Break.$RetVal." = ($InitializedType_Name)$FuncCall;\n".$PostCode;
                    }
                    $Block_Variable{$ProtectedMethod}{$RetVal} = 1;
                    $Declaration .= "       return $RetVal;\n";
                }
            }
            else
            {
                if($ReturnFType_Name eq "void" and $ReturnType_PointerLevel==0) {
                    $Declaration .= "       $FuncCall;\n";
                }
                else {
                    $Declaration .= "       return $FuncCall;\n";
                }
            }
            $Code .= $Wrappers{$ProtectedMethod}{"Code"};
            $Declaration .= "    }\n\n";
            foreach my $ClassId (keys(%{$Wrappers_SubClasses{$ProtectedMethod}})) {
                $Create_SubClass{$ClassId} = 1;
            }
        }
    }
    $Declaration .= "};//$ClassNameChild\n\n";
    return ($Code.$Declaration, $Headers);
}

sub create_SubClasses(@)
{
    my ($Code, $Headers) = ("", []);
    foreach my $ClassId (sort @_)
    {
        my (%Before, %After, %New) = ();
        next if(not $ClassId or $SubClass_Created{$ClassId});
        %Create_SubClass = ();
        push(@RecurTypeId, $ClassId);
        my ($Code_SubClass, $Headers_SubClass) = create_SubClass($ClassId);
        $SubClass_Created{$ClassId} = 1;
        if(keys(%Create_SubClass))
        {
            my ($Code_Depend, $Headers_Depend) = create_SubClasses(keys(%Create_SubClass));
            $Code_SubClass = $Code_Depend.$Code_SubClass;
            $Headers_SubClass = addHeaders($Headers_Depend, $Headers_SubClass);
        }
        pop(@RecurTypeId);
        $Code .= $Code_SubClass;
        $Headers = addHeaders($Headers_SubClass, $Headers);
    }
    return ($Code, $Headers);
}

sub save_state()
{
    my %Saved_State = ();
    foreach (keys(%IntSubClass))
    {
        @{$Saved_State{"IntSubClass"}{$_}}{keys(%{$IntSubClass{$_}})} = values %{$IntSubClass{$_}};
    }
    foreach (keys(%Wrappers))
    {
        @{$Saved_State{"Wrappers"}{$_}}{keys(%{$Wrappers{$_}})} = values %{$Wrappers{$_}};
    }
    foreach (keys(%Wrappers_SubClasses))
    {
        @{$Saved_State{"Wrappers_SubClasses"}{$_}}{keys(%{$Wrappers_SubClasses{$_}})} = values %{$Wrappers_SubClasses{$_}};
    }
    foreach (keys(%ValueCollection))
    {
        @{$Saved_State{"ValueCollection"}{$_}}{keys(%{$ValueCollection{$_}})} = values %{$ValueCollection{$_}};
    }
    foreach (keys(%Block_Variable))
    {
        @{$Saved_State{"Block_Variable"}{$_}}{keys(%{$Block_Variable{$_}})} = values %{$Block_Variable{$_}};
    }
    foreach (keys(%UseVarEveryWhere))
    {
        @{$Saved_State{"UseVarEveryWhere"}{$_}}{keys(%{$UseVarEveryWhere{$_}})} = values %{$UseVarEveryWhere{$_}};
    }
    foreach (keys(%OpenStreams))
    {
        @{$Saved_State{"OpenStreams"}{$_}}{keys(%{$OpenStreams{$_}})} = values %{$OpenStreams{$_}};
    }
    foreach (keys(%Block_Param))
    {
        @{$Saved_State{"Block_Param"}{$_}}{keys(%{$Block_Param{$_}})} = values %{$Block_Param{$_}};
    }
    foreach (keys(%UsedConstructors))
    {
        @{$Saved_State{"UsedConstructors"}{$_}}{keys(%{$UsedConstructors{$_}})} = values %{$UsedConstructors{$_}};
    }
    foreach (keys(%UsedProtectedMethods))
    {
        @{$Saved_State{"UsedProtectedMethods"}{$_}}{keys(%{$UsedProtectedMethods{$_}})} = values %{$UsedProtectedMethods{$_}};
    }
    foreach (keys(%IntSpecType))
    {
        @{$Saved_State{"IntSpecType"}{$_}}{keys(%{$IntSpecType{$_}})} = values %{$IntSpecType{$_}};
    }
    foreach (keys(%RequirementsCatalog))
    {
        @{$Saved_State{"RequirementsCatalog"}{$_}}{keys(%{$RequirementsCatalog{$_}})} = values %{$RequirementsCatalog{$_}};
    }
    @{$Saved_State{"Template2Code_Defines"}}{keys(%Template2Code_Defines)} = values %Template2Code_Defines;
    @{$Saved_State{"TraceFunc"}}{keys(%TraceFunc)} = values %TraceFunc;
    $Saved_State{"MaxTypeId"} = $MaxTypeId;
    @{$Saved_State{"IntrinsicNum"}}{keys(%IntrinsicNum)} = values %IntrinsicNum;
    @{$Saved_State{"AuxHeaders"}}{keys(%AuxHeaders)} = values %AuxHeaders;
    @{$Saved_State{"Class_SubClassTypedef"}}{keys(%Class_SubClassTypedef)} = values %Class_SubClassTypedef;
    @{$Saved_State{"SubClass_Instance"}}{keys(%SubClass_Instance)} = values %SubClass_Instance;
    @{$Saved_State{"SubClass_ObjInstance"}}{keys(%SubClass_ObjInstance)} = values %SubClass_ObjInstance;
    @{$Saved_State{"SpecEnv"}}{keys(%SpecEnv)} = values %SpecEnv;
    @{$Saved_State{"Block_InsNum"}}{keys(%Block_InsNum)} = values %Block_InsNum;
    @{$Saved_State{"AuxType"}}{keys %AuxType} = values %AuxType;
    @{$Saved_State{"AuxFunc"}}{keys %AuxFunc} = values %AuxFunc;
    @{$Saved_State{"Create_SubClass"}}{keys %Create_SubClass} = values %Create_SubClass;
    @{$Saved_State{"SpecCode"}}{keys %SpecCode} = values %SpecCode;
    @{$Saved_State{"SpecLibs"}}{keys %SpecLibs} = values %SpecLibs;
    @{$Saved_State{"UsedInterfaces"}}{keys %UsedInterfaces} = values %UsedInterfaces;
    @{$Saved_State{"ConstraintNum"}}{keys %ConstraintNum} = values %ConstraintNum;
    return \%Saved_State;
}

sub restore_state($)
{
    restore_state_I($_[0], 0);
}

sub restore_local_state($)
{
    restore_state_I($_[0], 1);
}

sub restore_state_I($$)
{
    my ($Saved_State, $Local) = @_;
    if(not $Local)
    {
        foreach my $AuxType_Id (keys(%AuxType))
        {
            if(my $OldName = $TypeInfo{$AuxType_Id}{"Name_Old"})
            {
                $TypeInfo{$AuxType_Id}{"Name"} = $OldName;
            }
        }
        if(not $Saved_State)
        { # restore aux types
            foreach my $AuxType_Id (sort {int($a)<=>int($b)} keys(%AuxType))
            {
                if(not $TypeInfo{$AuxType_Id}{"Name_Old"})
                {
                    delete($TypeInfo{$AuxType_Id});
                }
                delete($TName_Tid{$AuxType{$AuxType_Id}});
                delete($AuxType{$AuxType_Id});
            }
            $MaxTypeId = $MaxTypeId_Start;
        }
        elsif($Saved_State->{"MaxTypeId"})
        {
            foreach my $AuxType_Id (sort {int($a)<=>int($b)} keys(%AuxType))
            {
                if($AuxType_Id<=$MaxTypeId and $AuxType_Id>$Saved_State->{"MaxTypeId"})
                {
                    if(not $TypeInfo{$AuxType_Id}{"Name_Old"})
                    {
                        delete($TypeInfo{$AuxType_Id});
                    }
                    delete($TName_Tid{$AuxType{$AuxType_Id}});
                    delete($AuxType{$AuxType_Id});
                }
            }
        }
    }
    (%Block_Variable, %UseVarEveryWhere, %OpenStreams, %SpecEnv, %Block_InsNum,
    %ValueCollection, %IntrinsicNum, %ConstraintNum, %SubClass_Instance,
    %SubClass_ObjInstance, %Block_Param,%Class_SubClassTypedef, %AuxHeaders, %Template2Code_Defines) = ();
    if(not $Local)
    {
        (%Wrappers, %Wrappers_SubClasses, %IntSubClass, %AuxType, %AuxFunc,
        %UsedConstructors, %UsedProtectedMethods, %Create_SubClass, %SpecCode,
        %SpecLibs, %UsedInterfaces, %IntSpecType, %RequirementsCatalog, %TraceFunc) = ();
    }
    if(not $Saved_State)
    { # initializing
        %IntrinsicNum=(
            "Char"=>64,
            "Int"=>0,
            "Str"=>0,
            "Float"=>0);
        return;
    }
    foreach (keys(%{$Saved_State->{"Block_Variable"}}))
    {
        @{$Block_Variable{$_}}{keys(%{$Saved_State->{"Block_Variable"}{$_}})} = values %{$Saved_State->{"Block_Variable"}{$_}};
    }
    foreach (keys(%{$Saved_State->{"UseVarEveryWhere"}}))
    {
        @{$UseVarEveryWhere{$_}}{keys(%{$Saved_State->{"UseVarEveryWhere"}{$_}})} = values %{$Saved_State->{"UseVarEveryWhere"}{$_}};
    }
    foreach (keys(%{$Saved_State->{"OpenStreams"}}))
    {
        @{$OpenStreams{$_}}{keys(%{$Saved_State->{"OpenStreams"}{$_}})} = values %{$Saved_State->{"OpenStreams"}{$_}};
    }
    @SpecEnv{keys(%{$Saved_State->{"SpecEnv"}})} = values %{$Saved_State->{"SpecEnv"}};
    @Block_InsNum{keys(%{$Saved_State->{"Block_InsNum"}})} = values %{$Saved_State->{"Block_InsNum"}};
    foreach (keys(%{$Saved_State->{"ValueCollection"}}))
    {
        @{$ValueCollection{$_}}{keys(%{$Saved_State->{"ValueCollection"}{$_}})} = values %{$Saved_State->{"ValueCollection"}{$_}};
    }
    @Template2Code_Defines{keys(%{$Saved_State->{"Template2Code_Defines"}})} = values %{$Saved_State->{"Template2Code_Defines"}};
    @IntrinsicNum{keys(%{$Saved_State->{"IntrinsicNum"}})} = values %{$Saved_State->{"IntrinsicNum"}};
    @ConstraintNum{keys(%{$Saved_State->{"ConstraintNum"}})} = values %{$Saved_State->{"ConstraintNum"}};
    @SubClass_Instance{keys(%{$Saved_State->{"SubClass_Instance"}})} = values %{$Saved_State->{"SubClass_Instance"}};
    @SubClass_ObjInstance{keys(%{$Saved_State->{"SubClass_ObjInstance"}})} = values %{$Saved_State->{"SubClass_ObjInstance"}};
    foreach (keys(%{$Saved_State->{"Block_Param"}}))
    {
        @{$Block_Param{$_}}{keys(%{$Saved_State->{"Block_Param"}{$_}})} = values %{$Saved_State->{"Block_Param"}{$_}};
    }
    @Class_SubClassTypedef{keys(%{$Saved_State->{"Class_SubClassTypedef"}})} = values %{$Saved_State->{"Class_SubClassTypedef"}};
    @AuxHeaders{keys(%{$Saved_State->{"AuxHeaders"}})} = values %{$Saved_State->{"AuxHeaders"}};
    if(not $Local)
    {
        foreach my $AuxType_Id (sort {int($a)<=>int($b)} keys(%{$Saved_State->{"AuxType"}}))
        {
            $TypeInfo{$AuxType_Id}{"Name"} = $Saved_State->{"AuxType"}{$AuxType_Id};
            $TName_Tid{$Saved_State->{"AuxType"}{$AuxType_Id}} = $AuxType_Id;
        }
        foreach (keys(%{$Saved_State->{"IntSubClass"}}))
        {
            @{$IntSubClass{$_}}{keys(%{$Saved_State->{"IntSubClass"}{$_}})} = values %{$Saved_State->{"IntSubClass"}{$_}};
        }
        foreach (keys(%{$Saved_State->{"Wrappers"}}))
        {
            @{$Wrappers{$_}}{keys(%{$Saved_State->{"Wrappers"}{$_}})} = values %{$Saved_State->{"Wrappers"}{$_}};
        }
        foreach (keys(%{$Saved_State->{"Wrappers_SubClasses"}}))
        {
            @{$Wrappers_SubClasses{$_}}{keys(%{$Saved_State->{"Wrappers_SubClasses"}{$_}})} = values %{$Saved_State->{"Wrappers_SubClasses"}{$_}};
        }
        foreach (keys(%{$Saved_State->{"UsedConstructors"}}))
        {
            @{$UsedConstructors{$_}}{keys(%{$Saved_State->{"UsedConstructors"}{$_}})} = values %{$Saved_State->{"UsedConstructors"}{$_}};
        }
        foreach (keys(%{$Saved_State->{"UsedProtectedMethods"}}))
        {
            @{$UsedProtectedMethods{$_}}{keys(%{$Saved_State->{"UsedProtectedMethods"}{$_}})} = values %{$Saved_State->{"UsedProtectedMethods"}{$_}};
        }
        foreach (keys(%{$Saved_State->{"IntSpecType"}}))
        {
            @{$IntSpecType{$_}}{keys(%{$Saved_State->{"IntSpecType"}{$_}})} = values %{$Saved_State->{"IntSpecType"}{$_}};
        }
        foreach (keys(%{$Saved_State->{"RequirementsCatalog"}}))
        {
            @{$RequirementsCatalog{$_}}{keys(%{$Saved_State->{"RequirementsCatalog"}{$_}})} = values %{$Saved_State->{"RequirementsCatalog"}{$_}};
        }
        $MaxTypeId = $Saved_State->{"MaxTypeId"};
        @AuxType{keys(%{$Saved_State->{"AuxType"}})} = values %{$Saved_State->{"AuxType"}};
        @TraceFunc{keys(%{$Saved_State->{"TraceFunc"}})} = values %{$Saved_State->{"TraceFunc"}};
        @AuxFunc{keys(%{$Saved_State->{"AuxFunc"}})} = values %{$Saved_State->{"AuxFunc"}};
        @Create_SubClass{keys(%{$Saved_State->{"Create_SubClass"}})} = values %{$Saved_State->{"Create_SubClass"}};
        @SpecCode{keys(%{$Saved_State->{"SpecCode"}})} = values %{$Saved_State->{"SpecCode"}};
        @SpecLibs{keys(%{$Saved_State->{"SpecLibs"}})} = values %{$Saved_State->{"SpecLibs"}};
        @UsedInterfaces{keys(%{$Saved_State->{"UsedInterfaces"}})} = values %{$Saved_State->{"UsedInterfaces"}};
        @IntSpecType{keys(%{$Saved_State->{"IntSpecType"}})} = values %{$Saved_State->{"IntSpecType"}};
    }
}

sub isAbstractClass($)
{
    my $ClassId = $_[0];
    return (keys(%{$Class_PureVirtFunc{get_TypeName($ClassId)}}) > 0);
}

sub needToInherit($)
{
    my $Interface = $_[0];
    return ($CompleteSignature{$Interface}{"Class"} and (isAbstractClass($CompleteSignature{$Interface}{"Class"}) or isNotInCharge($Interface) or ($CompleteSignature{$Interface}{"Protected"})));
}

sub parseCode($$)
{
    my ($Code, $Mode) = @_;
    my $Global_State = save_state();
    my %ParsedCode = parseCode_m($Code, $Mode);
    if(not $ParsedCode{"IsCorrect"})
    {
        restore_state($Global_State);
        return ();
    }
    else {
        return %ParsedCode;
    }
}

sub get_TypeIdByName($)
{
    my $TypeName = $_[0];
    if(my $ExactId = $TName_Tid{formatName($TypeName, "T")}) {
        return $ExactId;
    }
    else {
        return $TName_Tid{remove_quals(formatName($TypeName, "T"))};
    }
}

sub callInterfaceParameters(@)
{
    my %Init_Desc = @_;
    my $Interface = $Init_Desc{"Interface"};
    return () if(not $Interface);
    return () if($SkipInterfaces{$Interface});
    foreach my $SkipPattern (keys(%SkipInterfaces_Pattern)) {
        return () if($Interface=~/$SkipPattern/);
    }
    if(defined $MakeIsolated and $Symbol_Library{$Interface}
    and keys(%InterfacesList) and not $InterfacesList{$Interface}) {
        return ();
    }
    my $Global_State = save_state();
    return () if(isCyclical(\@RecurInterface, $Interface));
    push(@RecurInterface, $Interface);
    my $PreviousBlock = $CurrentBlock;
    if($CompleteSignature{$Interface}{"Protected"}
    and not $CompleteSignature{$Interface}{"Constructor"}) {
        $CurrentBlock = $Interface;
    }
    $NodeInterface = $Interface;
    $UsedInterfaces{$NodeInterface} = 1;
    my %Params_Init = callInterfaceParameters_m(%Init_Desc);
    $CurrentBlock = $PreviousBlock;
    if(not $Params_Init{"IsCorrect"})
    {
        pop(@RecurInterface);
        restore_state($Global_State);
        if($Debug) {
            $DebugInfo{"Init_InterfaceParams"}{$Interface} = 1;
        }
        return ();
    }
    pop(@RecurInterface);
    if($InterfaceSpecType{$Interface}{"SpecEnv"}) {
        $SpecEnv{$InterfaceSpecType{$Interface}{"SpecEnv"}} = 1;
    }
    $Params_Init{"ReturnTypeId"} = $CompleteSignature{$Interface}{"Return"};
    return %Params_Init;
}

sub detectInLineParams($)
{
    my $Interface = $_[0];
    my ($SpecAttributes, %Param_SpecAttributes, %InLineParam) = ();
    foreach my $Param_Pos (keys(%{$InterfaceSpecType{$Interface}{"SpecParam"}}))
    {
        my $SpecType_Id = $InterfaceSpecType{$Interface}{"SpecParam"}{$Param_Pos};
        my %SpecType = %{$SpecType{$SpecType_Id}};
        $Param_SpecAttributes{$Param_Pos} = $SpecType{"Value"}.$SpecType{"PreCondition"}.$SpecType{"PostCondition"}.$SpecType{"InitCode"}.$SpecType{"DeclCode"}.$SpecType{"FinalCode"};
        $SpecAttributes .= $Param_SpecAttributes{$Param_Pos};
    }
    foreach my $Param_Pos (sort {int($a)<=>int($b)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
    {
        my $Param_Num = $Param_Pos + 1;
        if($SpecAttributes=~/\$$Param_Num(\W|\Z)/
        or $Param_SpecAttributes{$Param_Pos}=~/\$0(\W|\Z)/) {
            $InLineParam{$Param_Num} = 0;
        }
        else {
            $InLineParam{$Param_Num} = 1;
        }
    }
    return %InLineParam;
}

sub detectParamsOrder($)
{
    my $Interface = $_[0];
    my ($SpecAttributes, %OrderParam) = ();
    foreach my $Param_Pos (keys(%{$InterfaceSpecType{$Interface}{"SpecParam"}}))
    { # detect all dependencies
        my $SpecType_Id = $InterfaceSpecType{$Interface}{"SpecParam"}{$Param_Pos};
        my %SpecType = %{$SpecType{$SpecType_Id}};
        $SpecAttributes .= $SpecType{"Value"}.$SpecType{"PreCondition"}.$SpecType{"PostCondition"}.$SpecType{"InitCode"}.$SpecType{"DeclCode"}.$SpecType{"FinalCode"};
    }
    my $Orded = 1;
    foreach my $Param_Pos (sort {int($a)<=>int($b)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
    {
        my $Param_Num = $Param_Pos + 1;
        if($SpecAttributes=~/\$$Param_Num(\W|\Z)/)
        {
            $OrderParam{$Param_Num} = $Orded;
            $Orded += 1;
        }
    }
    foreach my $Param_Pos (sort {int($a)<=>int($b)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
    {
        my $Param_Num = $Param_Pos + 1;
        if(not defined $OrderParam{$Param_Pos+1})
        {
            $OrderParam{$Param_Num} = $Orded;
            $Orded += 1;
        }
    }
    return %OrderParam;
}

sub chooseSpecType($$$)
{
    my ($TypeId, $Kind, $Interface) = @_;
    if(my $SpecTypeId_Strong = chooseSpecType_Strong($TypeId, $Kind, $Interface, 1)) {
        return $SpecTypeId_Strong;
    }
    elsif(get_TypeType(get_FoundationTypeId($TypeId))!~/\A(Intrinsic)\Z/) {
        return chooseSpecType_Strong($TypeId, $Kind, $Interface, 0);
    }
    else {
        return "";
    }
}

sub chooseSpecType_Strong($$$$)
{
    my ($TypeId, $Kind, $Interface, $Strong) = @_;
    return 0 if(not $TypeId or not $Kind);
    foreach my $SpecType_Id (sort {int($a)<=>int($b)} keys(%SpecType))
    {
        next if($Interface and $Common_SpecType_Exceptions{$Interface}{$SpecType_Id});
        if($SpecType{$SpecType_Id}{"Kind"} eq $Kind)
        {
            if($Strong)
            {
                if($TypeId==get_TypeIdByName($SpecType{$SpecType_Id}{"DataType"})) {
                    return $SpecType_Id;
                }
            }
            else
            {
                my $FoundationTypeId = get_FoundationTypeId($TypeId);
                my $SpecType_FTypeId = get_FoundationTypeId(get_TypeIdByName($SpecType{$SpecType_Id}{"DataType"}));
                if($FoundationTypeId==$SpecType_FTypeId) {
                    return $SpecType_Id;
                }
            }
        }
    }
    return 0;
}

sub getAutoConstraint($)
{
    my $ReturnType_Id = $_[0];
    if(get_PointerLevel($ReturnType_Id) > 0) {
        return ("\$0 != ".get_null(), $ReturnType_Id);
    }
    else {
        return ();
    }
}

sub requirementReturn($$$$)
{
    my ($Interface, $Ireturn, $Ispecreturn, $CallObj) = @_;
    return "" if(defined $Template2Code and $Interface ne $TestedInterface);
    return "" if(not $Ireturn or not $Interface);
    my ($PostCondition, $TargetTypeId, $Requirement_Code) = ();
    if($Ispecreturn) {
        ($PostCondition, $TargetTypeId) = ($SpecType{$Ispecreturn}{"PostCondition"}, get_TypeIdByName($SpecType{$Ispecreturn}{"DataType"}));
    }
    elsif(defined $CheckReturn) {
        ($PostCondition, $TargetTypeId) = getAutoConstraint($Ireturn);
    }
    return "" if(not $PostCondition or not $TargetTypeId);
    my $PointerLevelReturn = get_PointerLevel($Ireturn);
    my ($TargetCallReturn, $TmpPreamble) =
    convertTypes((
        "InputTypeName"=>get_TypeName($Ireturn),
        "InputPointerLevel"=>$PointerLevelReturn,
        "OutputTypeId"=>$TargetTypeId,
        "Value"=>"\$0",
        "Key"=>"\$0",
        "Destination"=>"Target",
        "MustConvert"=>0));
    if($TmpPreamble) {
        $Requirement_Code .= $TmpPreamble."\n";
    }
    if($TargetCallReturn=~/\A\*/
    or $TargetCallReturn=~/\A\&/) {
        $TargetCallReturn = "(".$TargetCallReturn.")";
    }
    if($CallObj=~/\A\*/
    or $CallObj=~/\A\&/) {
        $CallObj = "(".$CallObj.")";
    }
    $PostCondition=~s/\$0/$TargetCallReturn/g;
    if($CallObj ne "no object") {
        $PostCondition=~s/\$obj/$CallObj/g;
    }
    $PostCondition = clearSyntax($PostCondition);
    my $NormalResult = $PostCondition;
    while($PostCondition=~s/([^\\])"/$1\\\"/g){}
    $ConstraintNum{$Interface}+=1;
    $RequirementsCatalog{$Interface}{$ConstraintNum{$Interface}} = "constraint for the return value: \'$PostCondition\'";
    my $ReqId = get_ShortName($Interface).".".normalize_num($ConstraintNum{$Interface});
    if(my $Format = is_printable(get_TypeName($TargetTypeId)))
    {
        my $Comment = "constraint for the return value failed: \'$PostCondition\', returned value: $Format";
        $Requirement_Code .= "REQva(\"$ReqId\",\n$NormalResult,\n\"$Comment\",\n$TargetCallReturn);\n";
        $TraceFunc{"REQva"}=1;
    }
    else
    {
        my $Comment = "constraint for the return value failed: \'$PostCondition\'";
        $Requirement_Code .= "REQ(\"$ReqId\",\n\"$Comment\",\n$NormalResult);\n";
        $TraceFunc{"REQ"}=1;
    }
    return $Requirement_Code;
}

sub is_printable($)
{
    my $TypeName = remove_quals(uncover_typedefs($_[0]));
    if(isIntegerType($TypeName)) {
        return "\%d";
    }
    elsif($TypeName=~/\A(char|unsigned char|wchar_t|void|short|unsigned short) const\*\Z/) {
        return "\%s";
    }
    elsif(isCharType($TypeName)) {
        return "\%c";
    }
    elsif($TypeName=~/\A(float|double|long double)\Z/) {
        return "\%f";
    }
    else {
        return "";
    }
}

sub get_ShortName($)
{
    my $Symbol = $_[0];
    my $Short = $CompleteSignature{$Symbol}{"ShortName"};
    if(my $Class = $CompleteSignature{$Symbol}{"Class"}) {
        $Short = get_TypeName($Class)."::".$Short;
    }
    return $Short;
}

sub normalize_num($)
{
    my $Num = $_[0];
    if(int($Num)<10) {
        return "0".$Num;
    }
    else {
        return $Num;
    }
}

sub get_PointerLevel($)
{
    my $TypeId = $_[0];
    return "" if(not $TypeId);
    if(defined $Cache{"get_PointerLevel"}{$TypeId}
    and not defined $AuxType{$TypeId}) {
        return $Cache{"get_PointerLevel"}{$TypeId};
    }
    return "" if(not $TypeInfo{$TypeId});
    my %Type = %{$TypeInfo{$TypeId}};
    return 0 if(not $Type{"BaseType"});
    return 0 if($Type{"Type"} eq "Array");
    my $PointerLevel = 0;
    if($Type{"Type"} eq "Pointer") {
        $PointerLevel += 1;
    }
    $PointerLevel += get_PointerLevel($Type{"BaseType"});
    $Cache{"get_PointerLevel"}{$TypeId} = $PointerLevel;
    return $PointerLevel;
}

sub select_ValueFromCollection(@)
{
    my %Init_Desc = @_;
    my ($TypeId, $Name, $Interface, $CreateChild, $IsObj) = ($Init_Desc{"TypeId"}, $Init_Desc{"ParamName"}, $Init_Desc{"Interface"}, $Init_Desc{"CreateChild"}, $Init_Desc{"ObjectInit"});
    return () if($Init_Desc{"DoNotReuse"});
    my $TypeName = get_TypeName($TypeId);
    my $FTypeId = get_FoundationTypeId($TypeId);
    my $FTypeName = get_TypeName($FTypeId);
    my $PointerLevel = get_PointerLevel($TypeId);
    my $ShortName = $CompleteSignature{$Interface}{"ShortName"};
    return () if(isString($TypeId, $Name, $Interface));
    return () if(uncover_typedefs($TypeName)=~/\A(char|unsigned char|wchar_t|void\*)\Z/);
    return () if(isCyclical(\@RecurTypeId, get_TypeStackId($TypeId)));
    if($CurrentBlock and keys(%{$ValueCollection{$CurrentBlock}}))
    {
        my (@Name_Type_Coinsidence, @Name_FType_Coinsidence, @Type_Coinsidence, @FType_Coinsidence) = ();
        foreach my $Value (sort {$b=~/$Name/i<=>$a=~/$Name/i} sort keys(%{$ValueCollection{$CurrentBlock}}))
        {
            return () if($Name=~/dest|source/i and $Value=~/source|dest/i and $ShortName=~/copy|move|backup/i);
            my $Value_TypeId = $ValueCollection{$CurrentBlock}{$Value};
            my $PointerLevel_Value = get_PointerLevel($Value_TypeId);
            if($Value!~/\A(argc|argv)\Z/)
            {
                if(get_TypeName($Value_TypeId)=~/(string|date|time|file)/i and $Name!~/\Ap\d+\Z/)
                { # date, time arguments
                    unless($Name=~/_elem\Z/ and $PointerLevel_Value==0)
                    { # array elements may be reused
                        next;
                    }
                }
                next if($CreateChild and not $SubClass_Instance{$Value});
                # next if(not $IsObj and $SubClass_Instance{$Value});
                next if(($Interface eq $TestedInterface) and ($Name ne $Value)
                and not $UseVarEveryWhere{$CurrentBlock}{$Value}); # and $Name!~/\Ap\d+\Z/
            }
            if($TypeName eq get_TypeName($Value_TypeId))
            {
                if($Value=~/\A(argc|argv)\Z/) {
                    next if($PointerLevel > $PointerLevel_Value);
                }
                else
                {
                    if(isNumericType($TypeName)
                    and $Name!~/\Q$Value\E/i and $TypeName!~/[A-Z]|_t/)
                    { # do not reuse intrinsic values
                        next;
                    }
                }
                if($Name=~/\A[_]*$Value(|[_]*[a-zA-Z0-9]|[_]*ptr)\Z/i) {
                    push(@Name_Type_Coinsidence, $Value);
                }
                else
                {
                    next if($Value=~/\A(argc|argv)\Z/ and $CurrentBlock eq "main");
                    push(@Type_Coinsidence, $Value);
                }
            }
            else
            {
                if($Value=~/\A(argc|argv)\Z/) {
                    next if($PointerLevel > $PointerLevel_Value);
                }
                else
                {
                    if(isNumericType($FTypeName) and $Name!~/\Q$Value\E/i)
                    { # do not reuse intrinsic values
                        next;
                    }
                    if($PointerLevel-$PointerLevel_Value!=1)
                    {
                        if($PointerLevel > $PointerLevel_Value) {
                            next;
                        }
                        elsif($PointerLevel ne $PointerLevel_Value)
                        {
                            if(get_TypeType($FTypeId)=~/\A(Intrinsic|Array|Enum)\Z/
                            or isArray($Value_TypeId, $Value, $Interface)) {
                                next;
                            }
                        }
                    }
                    if($PointerLevel<$PointerLevel_Value
                    and $Init_Desc{"OuterType_Type"} eq "Array") {
                        next;
                    }
                }
                my $Value_FTypeId = get_FoundationTypeId($Value_TypeId);
                if($FTypeName eq get_TypeName($Value_FTypeId))
                {
                    if($Name=~/\A[_]*\Q$Value\E(|[_]*[a-z0-9]|[_]*ptr)\Z/i) {
                        push(@Name_FType_Coinsidence, $Value);
                    }
                    else
                    {
                        next if($Value=~/\A(argc|argv)\Z/ and $CurrentBlock eq "main");
                        push(@FType_Coinsidence, $Value);
                    }
                }
            }
        }
        my @All_Coinsidence = (@Name_Type_Coinsidence, @Name_FType_Coinsidence, @Type_Coinsidence, @FType_Coinsidence);
        if($#All_Coinsidence>-1) {
            return ($All_Coinsidence[0], $ValueCollection{$CurrentBlock}{$All_Coinsidence[0]});
        }
    }
    return ();
}

sub get_interface_param_pos($$)
{
    my ($Interface, $Name) = @_;
    foreach my $Pos (keys(%{$CompleteSignature{$Interface}{"Param"}}))
    {
        if($CompleteSignature{$Interface}{"Param"}{$Pos}{"name"} eq $Name)
        {
            return $Pos;
        }
    }
    return "";
}

sub hasLength($$)
{
    my ($ParamName, $Interface) = @_;
    my $ParamPos = get_interface_param_pos($Interface, $ParamName);
    if(defined $CompleteSignature{$Interface}{"Param"}{$ParamPos+1})
    {
      return (isIntegerType(get_TypeName($CompleteSignature{$Interface}{"Param"}{$ParamPos+1}{"type"}))
      and is_array_count($ParamName, $CompleteSignature{$Interface}{"Param"}{$ParamPos+1}{"name"}));
    }
    return 0;
}

sub isArrayName($)
{
    my $Name = $_[0];
    if($Name=~/([a-z][a-rt-z]s\Z|matrix|list|set|range|array)/i) {
        return 1;
    }
    return 0;
}

sub isArray($$$)
{ # detect parameter semantic
    my ($TypeId, $ParamName, $Interface) = @_;
    return 0 if(not $TypeId or not $ParamName);
    my $I_ShortName = $CompleteSignature{$Interface}{"ShortName"};
    my $FTypeId = get_FoundationTypeId($TypeId);
    my $FTypeType = get_TypeType($FTypeId);
    my $FTypeName = get_TypeName($FTypeId);
    my $TypeName = get_TypeName($TypeId);
    my $PLevel = get_PointerLevel($TypeId);
    my $ParamPos = get_interface_param_pos($Interface, $ParamName);
    
    return 1 if(get_TypeType($TypeId) eq "Array");
    
    # strong reject
    return 0 if($PLevel <= 0);
    return 0 if(isString($TypeId, $ParamName, $Interface));
    return 0 if($PLevel==1 and (isOpaque($FTypeId) or $FTypeName eq "void"));
    return 0 if($ParamName=~/ptr|pointer/i and $FTypeType=~/\A(Struct|Union|Class)\Z/);
    return 0 if($Interface_OutParam{$Interface}{$ParamName});
    
    # particular reject
    # FILE *fopen(const char *path, const char *__modes)
    return 0 if(is_const_type($TypeName) and isCharType($FTypeName)
    and $PLevel==1 and $ParamName=~/mode/i);
    
    # returned by function
    return 0 if(($FTypeType=~/\A(Struct|Union|Class)\Z/
    or ($TypeName ne uncover_typedefs($TypeName) and $TypeName!~/size_t|int/))
    and check_type_returned($TypeId, isArrayName($TypeName)));
    
    # array followed by the number
    return 1 if(not is_const_type($TypeName) and hasLength($ParamName, $Interface));
    
    return 0 if($PLevel>=2 and isCharType($FTypeName)
    and not is_const_type($TypeName));
    
    # allowed configurations
    # array of arguments
    return 1 if($ParamName=~/argv/i);
    # array, list, matrix
    if($ParamName!~/out|context|name/i and isArrayName($ParamName)
    and (getParamNameByTypeName($TypeName) ne $ParamName or $TypeName!~/\*/)
    and $TypeName!~/$ParamName/i)
    { #  foo(struct type* list)
      #! curl_slist_free_all ( struct curl_slist* p1 )
        return 1;
    }
    # array of function pointers
    return 1 if($PLevel==1 and $FTypeType=~/\A(FuncPtr|Array)\Z/);
    # QString::vsprintf ( char const* format, va_list ap )
    return 1 if($ParamName!~/out|context/i and isArrayName($TypeName) and $TypeName!~/$ParamName/i);
    # high pointer level
    # xmlSchemaSAXPlug (xmlSchemaValidCtxtPtr ctxt, xmlSAXHandlerPtr* sax, void** user_data)
    return 1 if($PLevel>=2);
    # symbol array for reading
    return 1 if($PLevel==1 and not is_const_type($TypeName) and isCharType($FTypeName)
    and not grep(/\A(name|cur|current|out|ret|return|buf|buffer|res|result|rslt)\Z/i, @{get_tokens($ParamName)}));
    # array followed by the two numbers
    return 1 if(not is_const_type($TypeName) and defined $CompleteSignature{$Interface}{"Param"}{$ParamPos+1}
    and defined $CompleteSignature{$Interface}{"Param"}{$ParamPos+2}
    and isIntegerType(get_TypeName($CompleteSignature{$Interface}{"Param"}{$ParamPos+1}{"type"}))
    and isIntegerType(get_TypeName($CompleteSignature{$Interface}{"Param"}{$ParamPos+2}{"type"}))
    and is_array_count($ParamName, $CompleteSignature{$Interface}{"Param"}{$ParamPos+2}{"name"}));
    # numeric arrays for reading
    return 1 if(is_const_type($TypeName) and isNumericType($FTypeName));
    # symbol buffer for reading
    return 1 if(is_const_type($TypeName) and $ParamName=~/buf/i and $I_ShortName=~/memory/i
    and isCharType($FTypeName));
    
    # isn't array
    return 0;
}

sub check_type_returned($$)
{
    my ($TypeId, $Strong) = @_;
    return 0 if(not $TypeId);
    my $BaseTypeId = get_FoundationTypeId($TypeId);
    if(get_TypeType($BaseTypeId) ne "Intrinsic")
    { # by return value
        return 1 if(keys(%{$ReturnTypeId_Interface{$TypeId}}) or keys(%{$ReturnTypeId_Interface{$BaseTypeId}}));
        if(not $Strong)
        { # base type and plevel match
            my $PLevel = get_PointerLevel($TypeId);
            foreach (0 .. $PLevel)
            {
                return 1 if(keys(%{$BaseType_PLevel_OutParam{$BaseTypeId}{$_}})
                or keys(%{$BaseType_PLevel_Return{$BaseTypeId}{$_}}));
            }
        }
        
    }
    return 0;
}

sub isBuffer($$$)
{
    my ($TypeId, $ParamName, $Interface) = @_;
    return 0 if(not $TypeId or not $ParamName);
    my $I_ShortName = $CompleteSignature{$Interface}{"ShortName"};
    my $FTypeId = get_FoundationTypeId($TypeId);
    my $FTypeType = get_TypeType($FTypeId);
    my $FTypeName = get_TypeName($FTypeId);
    my $TypeName = get_TypeName($TypeId);
    my $PLevel = get_PointerLevel($TypeId);
    
    # exceptions
    # bmp_read24 (uintptr_t addr)
    # bmp_write24 (uintptr_t addr, int c)
    return 1 if($PLevel==0 and $ParamName=~/addr/i and isIntegerType($FTypeName));
    # cblas_zdotu_sub (int const N, void const* X, int const incX, void const* Y, int const incY, void* dotu)
    return 1 if($PLevel==1 and $FTypeName eq "void");
    if(get_TypeType($FTypeId) eq "Array" and $Interface)
    {
        my $ArrayElemType_Id = get_FoundationTypeId(get_OneStep_BaseTypeId($FTypeId));
        if(get_TypeType($ArrayElemType_Id)=~/\A(Intrinsic|Enum)\Z/)
        {
            return 1 if(get_TypeAttr($FTypeId, "Count")>1024);
        }
        else
        {
            return 1 if(get_TypeAttr($FTypeId, "Count")>256);
        }
    }
    
    # strong reject
    return 0 if($PLevel <= 0);
    return 0 if(is_const_type($TypeName));
    return 0 if(isString($TypeId, $ParamName, $Interface));
    return 0 if($PLevel==1 and isOpaque($FTypeId));
    return 0 if(($FTypeType=~/\A(Struct|Union|Class)\Z/
    or ($TypeName ne uncover_typedefs($TypeName) and $TypeName!~/size_t|int/))
    and check_type_returned($TypeId, isArrayName($TypeName)));
    
    # allowed configurations
    # symbol buffer for writing
    return 1 if(isSymbolBuffer($TypeId, $ParamName, $Interface));
    if($ParamName=~/\Ap\d+\Z/)
    {
        # buffer of void* type for writing
        return 1 if($PLevel==1 and $FTypeName eq "void");
        # buffer of arrays for writing
        return 1 if($FTypeType eq "Array");
    }
    return 1 if(is_out_word($ParamName));
    # gsl_fft_real_radix2_transform (double* data, size_t const stride, size_t const n)
    return 1 if($PLevel==1 and isNumericType($FTypeName) and $ParamName!~/(len|size)/i);
    
    # isn't array
    return 0;
}

sub is_out_word($)
{
    my $Word = $_[0];
    return grep(/\A(out|output|dest|buf|buff|buffer|ptr|pointer|result|res|ret|return|rtrn)\Z/i, @{get_tokens($Word)});
}

sub isSymbolBuffer($$$)
{
    my ($TypeId, $ParamName, $Interface) = @_;
    return 0 if(not $TypeId or not $ParamName);
    my $FTypeId = get_FoundationTypeId($TypeId);
    my $FTypeName = get_TypeName($FTypeId);
    my $TypeName = get_TypeName($TypeId);
    my $PLevel = get_PointerLevel($TypeId);
    return (not is_const_type($TypeName) and $PLevel==1
    and isCharType($FTypeName)
    and $ParamName!~/data|value|arg|var/i and $TypeName!~/list|va_/
    and (grep(/\A(name|cur|current)\Z/i, @{get_tokens($ParamName)}) or is_out_word($ParamName)));
}

sub isOutParam_NoUsing($$$)
{
    my ($TypeId, $ParamName, $Interface) = @_;
    return 0 if(not $TypeId or not $ParamName);
    my $Func_ShortName = $CompleteSignature{$Interface}{"ShortName"};
    my $FTypeId = get_FoundationTypeId($TypeId);
    my $FTypeName = get_TypeName($FTypeId);
    my $TypeName = get_TypeName($TypeId);
    my $PLevel = get_PointerLevel($TypeId);
    return 0 if($PLevel==1 and isOpaque($FTypeId)); # size of the structure/union is unknown
    return 0 if(is_const_type($TypeName) or $PLevel<=0);
    return 1 if(grep(/\A(err|error)(_|)(p|ptr|)\Z/i, @{get_tokens($ParamName." ".$TypeName)}) and $Func_ShortName!~/error/i);
    return 1 if(grep(/\A(out|ret|return)\Z/i, @{get_tokens($ParamName)}));
    return 1 if($PLevel>=2 and isCharType($FTypeName) and not is_const_type($TypeName));
    return 0;
}

sub isString($$$)
{
    my ($TypeId, $ParamName, $Interface) = @_;
    return 0 if(not $TypeId or not $ParamName);
    my $TypeName_Trivial = uncover_typedefs(get_TypeName($TypeId));
    my $PLevel = get_PointerLevel($TypeId);
    my $TypeName = get_TypeName($TypeId);
    my $FoundationTypeName = get_TypeName(get_FoundationTypeId($TypeId));
    # not a pointer
    return 0 if($ParamName=~/ptr|pointer/i);
    # standard string (std::string)
    return 1 if($PLevel==0 and $FoundationTypeName eq "std::basic_string<char>");
    if($FoundationTypeName=~/\A(char|unsigned char|wchar_t|short|unsigned short)\Z/)
    {
        # char const*, unsigned char const*, wchar_t const*
        # void const*, short const*, unsigned short const*
        # ChannelGroup::getName ( char* name, int namelen )
        return 1 if($PLevel==1 and is_const_type($TypeName_Trivial));
        if(not hasLength($ParamName, $Interface))
        {
            return 1 if($PLevel==1 and $CompleteSignature{$Interface}{"ShortName"}!~/get|encode/i
            and $ParamName=~/\A(file|)(_|)path\Z|description|label|name/i);
            # direct_trim ( char** s )
            return 1 if($PLevel>=1 and $ParamName=~/\A(s|str|string)\Z/i);
        }
    }
    
    # isn't a string
    return 0;
}

sub isOpaque($)
{
    my $TypeId = $_[0];
    return 0 if(not $TypeId);
    my %Type = get_Type($TypeId);
    return ($Type{"Type"}=~/\A(Struct|Union)\Z/ and not keys(%{$Type{"Memb"}}) and not $Type{"Memb"}{0}{"name"});
}

sub isStr_FileName($$$)
{ # should be called after the "isString" function
    my ($ParamPos, $ParamName, $Interface_ShortName) = @_;
    return 0 if(not $ParamName);
    if($ParamName=~/ext/i)
    { # not an extension
        return 0;
    }
    if($ParamName=~/file|dtd/i
    and $ParamName!~/type|opt/i)
    { # any files, dtds
        return 1;
    }
    return 1 if(lc($ParamName) eq "fname");
    # files as buffers
    return 1 if($ParamName=~/buf/i and $Interface_ShortName!~/memory|write/i and $Interface_ShortName=~/file/i);
    # name of the file at the first parameter of read/write/open functions
    # return 1 if($ParamName=~/\A[_]*name\Z/i and $Interface_ShortName=~/read|write|open/i and $ParamPos=="0");
    # file path
    return 1 if($ParamName=~/path/i
    and $Interface_ShortName=~/open|create|file/i
    and $Interface_ShortName!~/(open|_)dir(_|\Z)/i);
    # path to the configs
    return 1 if($ParamName=~/path|cfgs/i and $Interface_ShortName=~/config/i);
    # parameter of the string constructor
    return 1 if($ParamName=~/src/i and $Interface_ShortName!~/string/i and $ParamPos=="0");
    # uri/url of the local files
    return 1 if($ParamName=~/uri|url/i and $Interface_ShortName!~/http|ftp/i);
    
    # isn't a file path
    return 0;
}

sub isStr_Dir($$)
{
    my ($ParamName, $Interface_ShortName) = @_;
    return 0 if(not $ParamName);
    return 1 if($ParamName=~/path/i
    and $Interface_ShortName=~/(open|_)dir(_|\Z)/i);
    return 1 if($ParamName=~/dir/i);
    
    # isn't a directory
    return 0;
}

sub equal_types($$)
{
    my ($Type1_Id, $Type2_Id) = @_;
    return (uncover_typedefs(get_TypeName($Type1_Id)) eq uncover_typedefs(get_TypeName($Type2_Id)));
}

sub reduce_pointer_level($)
{
    my $TypeId = $_[0];
    my %PureType = get_PureType($TypeId);
    my $BaseTypeId = get_OneStep_BaseTypeId($PureType{"Tid"});
    return ($BaseTypeId eq $TypeId)?"":$BaseTypeId;
}

sub reassemble_array($)
{
    my $TypeId = $_[0];
    return () if(not $TypeId);
    my $FoundationTypeId = get_FoundationTypeId($TypeId);
    if(get_TypeType($FoundationTypeId) eq "Array")
    {
        my ($BaseName, $Length) = (get_TypeName($FoundationTypeId), 1);
        while($BaseName=~s/\[(\d+)\]//) {
            $Length*=$1;
        }
        return ($BaseName, $Length);
    }
    else {
        return ();
    }
}

sub get_call_malloc($)
{
    my $TypeId = $_[0];
    return "" if(not $TypeId);
    my $FoundationTypeId = get_FoundationTypeId($TypeId);
    my $FoundationTypeName = get_TypeName($FoundationTypeId);
    my $PointerLevel = get_PointerLevel($TypeId);
    my $Conv = ($FoundationTypeName ne "void")?"(".get_TypeName($TypeId).") ":"";
    $Conv=~s/\&//g;
    my $BuffSize = 0;
    if(get_TypeType($FoundationTypeId) eq "Array")
    {
        my ($Array_BaseName, $Array_Length) = reassemble_array($TypeId);
        $Conv = "($Array_BaseName*)";
        $BuffSize = $Array_Length;
        $FoundationTypeName = $Array_BaseName;
        my %ArrayBase = get_BaseType($TypeId);
        $FoundationTypeId = $ArrayBase{"Tid"};
    }
    else {
        $BuffSize = $BUFF_SIZE;
    }
    my $MallocCall = "malloc";
    if($LibraryMallocFunc)
    {
        $MallocCall = $CompleteSignature{$LibraryMallocFunc}{"ShortName"};
        if(my $NS = $CompleteSignature{$LibraryMallocFunc}{"NameSpace"}) {
            $MallocCall = $NS."::".$MallocCall;
        }
    }
    if($FoundationTypeName eq "void") {
        return $Conv.$MallocCall."($BuffSize)";
    }
    else
    {
        if(isOpaque($FoundationTypeId))
        { # opaque buffers
            if(get_TypeType($FoundationTypeId) eq "Array") {
                $BuffSize*=$BUFF_SIZE;
            }
            else {
                $BuffSize*=4;
            }
            return $Conv.$MallocCall."($BuffSize)";
        }
        else
        {
            if($PointerLevel==1)
            {
                my $ReducedTypeId = reduce_pointer_level($TypeId);
                return $Conv.$MallocCall."(sizeof(".get_TypeName($ReducedTypeId).")".($BuffSize>1?"*$BuffSize":"").")";
            }
            else {
                return $Conv.$MallocCall."(sizeof($FoundationTypeName)".($BuffSize>1?"*$BuffSize":"").")";
            }
        }
    }
}

sub isKnownExt($)
{
    my $Ext = $_[0];
    if($Ext=~/\A(png|tiff|zip|bmp|bitmap|nc)/i)
    {
        return $1;
    }
    return "";
}

sub add_VirtualSpecType(@)
{
    my %Init_Desc = @_;
    my %NewInit_Desc = %Init_Desc;
    if($Init_Desc{"Value"} eq "") {
        $Init_Desc{"Value"} = "no value";
    }
    my ($TypeId, $ParamName, $Interface) = ($Init_Desc{"TypeId"}, $Init_Desc{"ParamName"}, $Init_Desc{"Interface"});
    my $FoundationTypeId = get_FoundationTypeId($TypeId);
    my $FoundationTypeName = get_TypeName($FoundationTypeId);
    my $PointerLevel = get_PointerLevel($TypeId);
    my $FoundationTypeType = $TypeInfo{$FoundationTypeId}{"Type"};
    my $TypeName = get_TypeName($TypeId);
    my $TypeType = get_TypeType($TypeId);
    my $I_ShortName = $CompleteSignature{$Init_Desc{"Interface"}}{"ShortName"};
    my $I_Header = $CompleteSignature{$Init_Desc{"Interface"}}{"Header"};
    if($Init_Desc{"Value"} eq "no value"
    or (defined $ValueCollection{$CurrentBlock}{$ParamName} and $ValueCollection{$CurrentBlock}{$ParamName}==$TypeId))
    { # create value atribute
        if($CurrentBlock and keys(%{$ValueCollection{$CurrentBlock}}) and not $Init_Desc{"InLineArray"})
        {
            ($NewInit_Desc{"Value"}, $NewInit_Desc{"ValueTypeId"}) = select_ValueFromCollection(%Init_Desc);
            if($NewInit_Desc{"Value"} and $NewInit_Desc{"ValueTypeId"})
            {
                my ($Call, $TmpPreamble)=convertTypes((
                    "InputTypeName"=>get_TypeName($NewInit_Desc{"ValueTypeId"}),
                    "InputPointerLevel"=>get_PointerLevel($NewInit_Desc{"ValueTypeId"}),
                    "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$TypeId,
                    "Value"=>$NewInit_Desc{"Value"},
                    "Key"=>$LongVarNames?$Init_Desc{"Key"}:$ParamName,
                    "Destination"=>"Param",
                    "MustConvert"=>0));
                if($Call and not $TmpPreamble)
                { # try to create simple value
                    $NewInit_Desc{"ValueTypeId"}=$TypeId;
                    $NewInit_Desc{"Value"} = $Call;
                }
                if($NewInit_Desc{"ValueTypeId"}==$TypeId) {
                    $NewInit_Desc{"InLine"} = 1;
                }
                $NewInit_Desc{"Reuse"} = 1;
                return %NewInit_Desc;
            }
        }
        if($TypeName=~/\&/
        or not $Init_Desc{"InLine"}) {
            $NewInit_Desc{"InLine"} = 0;
        }
        else {
            $NewInit_Desc{"InLine"} = 1;
        }
        # creating virtual specialized type
        if($TypeName eq "...")
        {
            $NewInit_Desc{"Value"} = get_null();
            $NewInit_Desc{"ValueTypeId"} = get_TypeIdByName("int");
        }
        elsif($I_ShortName eq "time" and $I_Header eq "time.h")
        { # spectype for time_t time(time_t *t) from time.h
            $NewInit_Desc{"Value"} = get_null();
            $NewInit_Desc{"ValueTypeId"} = $TypeId;
        }
        elsif($ParamName=~/unused/i and $PointerLevel>=1)
        { # curl_getdate ( char const* p, time_t const* unused )
            $NewInit_Desc{"Value"} = get_null();
            $NewInit_Desc{"ValueTypeId"} = $TypeId;
        }
        elsif($FoundationTypeName eq "int" and $ParamName=~/\Aargc(_|)(p|ptr|)\Z/i
        and not $Interface_OutParam{$Interface}{$ParamName} and $PointerLevel>=1
        and my $Value_TId = register_new_type(get_TypeIdByName("int"), 1))
        { # gtk_init ( int* argc, char*** argv )
            $NewInit_Desc{"Value"} = "&argc";
            $NewInit_Desc{"ValueTypeId"} = $Value_TId;
        }
        elsif($FoundationTypeName eq "char" and $ParamName=~/\Aargv(_|)(p|ptr|)\Z/i
        and not $Interface_OutParam{$Interface}{$ParamName} and $PointerLevel>=3
        and my $Value_TId = register_new_type(get_TypeIdByName("char"), 3))
        { # gtk_init ( int* argc, char*** argv )
            $NewInit_Desc{"Value"} = "&argv";
            $NewInit_Desc{"ValueTypeId"} = $Value_TId;
        }
        elsif($FoundationTypeName eq "complex float")
        {
            $NewInit_Desc{"Value"} = getIntrinsicValue("float")." + I*".getIntrinsicValue("float");
            $NewInit_Desc{"ValueTypeId"} = $FoundationTypeId;
        }
        elsif($FoundationTypeName eq "complex double")
        {
            $NewInit_Desc{"Value"} = getIntrinsicValue("double")." + I*".getIntrinsicValue("double");
            $NewInit_Desc{"ValueTypeId"} = $FoundationTypeId;
        }
        elsif($FoundationTypeName eq "complex long double")
        {
            $NewInit_Desc{"Value"} = getIntrinsicValue("long double")." + I*".getIntrinsicValue("long double");
            $NewInit_Desc{"ValueTypeId"} = $FoundationTypeId;
        }
        elsif((($Interface_OutParam{$Interface}{$ParamName} and $PointerLevel>=1) or ($Interface_OutParam_NoUsing{$Interface}{$ParamName}
        and $PointerLevel>=1)) and not grep(/\A(in|input)\Z/, @{get_tokens($ParamName)}) and not isSymbolBuffer($TypeId, $ParamName, $Interface))
        {
            $NewInit_Desc{"InLine"} = 0;
            $NewInit_Desc{"ValueTypeId"} = reduce_pointer_level($TypeId);
            if($PointerLevel>=2) {
                $NewInit_Desc{"Value"} = get_null();
            }
            elsif($PointerLevel==1 and isNumericType(get_TypeName($FoundationTypeId)))
            {
                $NewInit_Desc{"Value"} = "0";
                $NewInit_Desc{"OnlyByValue"} = 1;
            }
            else {
                $NewInit_Desc{"OnlyDecl"} = 1;
            }
            $NewInit_Desc{"UseableValue"} = 1;
        }
        elsif($FoundationTypeName eq "void" and $PointerLevel==1
        and my $SimilarType_Id = find_similar_type($NewInit_Desc{"TypeId"}, $ParamName)
        and $TypeName=~/(\W|\A)void(\W|\Z)/ and not $NewInit_Desc{"TypeId_Changed"})
        {
            $NewInit_Desc{"TypeId"} = $SimilarType_Id;
            $NewInit_Desc{"DenyMalloc"} = 1;
            %NewInit_Desc = add_VirtualSpecType(%NewInit_Desc);
            $NewInit_Desc{"TypeId_Changed"} = $TypeId;
        }
        elsif(isArray($TypeId, $ParamName, $Interface)
        and not $Init_Desc{"IsString"})
        {
            $NewInit_Desc{"FoundationType_Type"} = "Array";
            if($ParamName=~/matrix/) {
                $NewInit_Desc{"ArraySize"} = 16;
            }
            $NewInit_Desc{"TypeType_Changed"} = 1;
        }
        elsif($Init_Desc{"FuncPtrName"}=~/realloc/i and $PointerLevel==1
        and $Init_Desc{"RetVal"} and $Init_Desc{"FuncPtrTypeId"})
        {
            my %FuncPtrType = get_Type($Init_Desc{"FuncPtrTypeId"});
            my ($IntParam, $IntParam2, $PtrParam, $PtrTypeId) = ("", "", "", 0);
            foreach my $ParamPos (sort {int($a) <=> int($b)} keys(%{$FuncPtrType{"Memb"}}))
            {
                my $ParamTypeId = $FuncPtrType{"Memb"}{$ParamPos}{"type"};
                my $ParamName = $FuncPtrType{"Memb"}{$ParamPos}{"name"};
                $ParamName = "p".($ParamPos+1) if(not $ParamName);
                my $ParamFTypeId = get_FoundationTypeId($ParamTypeId);
                if(isIntegerType(get_TypeName($ParamTypeId)))
                {
                    if(not $IntParam) {
                        $IntParam = $ParamName;
                    }
                    elsif(not $IntParam2) {
                        $IntParam2 = $ParamName;
                    }
                }
                elsif(get_PointerLevel($ParamTypeId)==1
                and get_TypeType($ParamFTypeId) eq "Intrinsic")
                {
                    $PtrParam = $ParamName;
                    $PtrTypeId = $ParamTypeId;
                }
            }
            if($IntParam and $PtrParam)
            { # function has an integer parameter
                my $Conv = ($FoundationTypeName ne "void")?"(".get_TypeName($TypeId).") ":"";
                $Conv=~s/\&//g;
                my $VoidConv = (get_TypeName(get_FoundationTypeId($PtrTypeId)) ne "void")?"(void*)":"";
                if($IntParam2) {
                    $NewInit_Desc{"Value"} = $Conv."realloc($VoidConv$PtrParam, $IntParam2)";
                }
                else {
                    $NewInit_Desc{"Value"} = $Conv."realloc($VoidConv$PtrParam, $IntParam)";
                }
            }
            else {
                $NewInit_Desc{"Value"} = get_call_malloc($TypeId);
            }
            $NewInit_Desc{"ValueTypeId"} = $TypeId;
            $NewInit_Desc{"InLine"} = ($Init_Desc{"RetVal"} or ($Init_Desc{"OuterType_Type"} eq "Array"))?1:0;
            if($LibraryMallocFunc and (not $IntParam or not $PtrParam)) {
                $NewInit_Desc{"Headers"} = addHeaders([$CompleteSignature{$LibraryMallocFunc}{"Header"}], $NewInit_Desc{"Headers"});
            }
            else
            {
                $NewInit_Desc{"Headers"} = addHeaders(["stdlib.h"], $NewInit_Desc{"Headers"});
                $AuxHeaders{"stdlib.h"} = 1;
            }
        }
        elsif($Init_Desc{"FuncPtrName"}=~/alloc/i and $PointerLevel==1
        and $Init_Desc{"RetVal"} and $Init_Desc{"FuncPtrTypeId"})
        {
            my %FuncPtrType = get_Type($Init_Desc{"FuncPtrTypeId"});
            my $IntParam = "";
            foreach my $ParamPos (sort {int($a) <=> int($b)} keys(%{$FuncPtrType{"Memb"}}))
            {
                my $ParamTypeId = $FuncPtrType{"Memb"}{$ParamPos}{"type"};
                my $ParamName = $FuncPtrType{"Memb"}{$ParamPos}{"name"};
                $ParamName = "p".($ParamPos+1) if(not $ParamName);
                if(isIntegerType(get_TypeName($ParamTypeId)))
                {
                    $IntParam = $ParamName;
                    last;
                }
            }
            if($IntParam)
            { # function has an integer parameter
                my $Conv = ($FoundationTypeName ne "void")?"(".get_TypeName($TypeId).") ":"";
                $Conv=~s/\&//g;
                $NewInit_Desc{"Value"} = $Conv."malloc($IntParam)";
            }
            else {
                $NewInit_Desc{"Value"} = get_call_malloc($TypeId);
            }
            $NewInit_Desc{"ValueTypeId"} = $TypeId;
            $NewInit_Desc{"InLine"} = ($Init_Desc{"RetVal"} or ($Init_Desc{"OuterType_Type"} eq "Array"))?1:0;
            if($LibraryMallocFunc and not $IntParam) {
                $NewInit_Desc{"Headers"} = addHeaders([$CompleteSignature{$LibraryMallocFunc}{"Header"}], $NewInit_Desc{"Headers"});
            }
            else
            {
                $NewInit_Desc{"Headers"} = addHeaders(["stdlib.h"], $NewInit_Desc{"Headers"});
                $AuxHeaders{"stdlib.h"} = 1;
            }
        }
        elsif((isBuffer($TypeId, $ParamName, $Interface)
        or ($PointerLevel==1 and $I_ShortName=~/free/i and $FoundationTypeName=~/\A(void|char|unsigned char|wchar_t)\Z/))
        and not $NewInit_Desc{"InLineArray"} and not $Init_Desc{"IsString"} and not $Init_Desc{"DenyMalloc"})
        {
            if(get_TypeName($TypeId) eq "char const*"
            and (my $NewTypeId = get_TypeIdByName("char*"))) {
                $TypeId = $NewTypeId;
            }
            $NewInit_Desc{"Value"} = get_call_malloc($TypeId);
            $NewInit_Desc{"ValueTypeId"} = $TypeId;
            $NewInit_Desc{"InLine"} = ($Init_Desc{"RetVal"} or ($Init_Desc{"OuterType_Type"} eq "Array"))?1:0;
            if($LibraryMallocFunc) {
                $NewInit_Desc{"Headers"} = addHeaders([$CompleteSignature{$LibraryMallocFunc}{"Header"}], $NewInit_Desc{"Headers"});
            }
            else
            {
                $NewInit_Desc{"Headers"} = addHeaders(["stdlib.h"], $NewInit_Desc{"Headers"});
                $AuxHeaders{"stdlib.h"} = 1;
            }
        }
        elsif(isString($TypeId, $ParamName, $Interface)
        or $Init_Desc{"IsString"})
        {
            my @Values = ();
            if($ParamName and $ParamName!~/\Ap\d+\Z/)
            {
                if($I_ShortName=~/Display/ and $ParamName=~/name|display/i)
                {
                    @Values = ("getenv(\"DISPLAY\")");
                    $NewInit_Desc{"Headers"} = addHeaders(["stdlib.h"], $NewInit_Desc{"Headers"});
                    $AuxHeaders{"stdlib.h"} = 1;
                }
                elsif($ParamName=~/uri|url|href/i
                and $I_ShortName!~/file/i) {
                    @Values = ("\"http://www.w3.org/\"");
                }
                elsif($ParamName=~/language/i) {
                    @Values = ("\"$COMMON_LANGUAGE\"");
                }
                elsif($ParamName=~/mount/i and $ParamName=~/path/i) {
                    @Values = ("\"/dev\"");
                }
                elsif(isStr_FileName($Init_Desc{"ParamPos"}, $ParamName, $I_ShortName))
                {
                    if($I_ShortName=~/sqlite/i) {
                        @Values = ("TG_TEST_DATA_DB");
                    }
                    elsif($TestedInterface=~/\A(ov_|vorbis_)/i) {
                        @Values = ("TG_TEST_DATA_AUDIO");
                    }
                    elsif($TestedInterface=~/\A(zip_)/i) {
                        @Values = ("TG_TEST_DATA_ZIP_FILE");
                    }
                    elsif($ParamName=~/dtd/i or $I_ShortName=~/dtd/i) {
                        @Values = ("TG_TEST_DATA_DTD_FILE");
                    }
                    elsif($ParamName=~/xml/i or $I_ShortName=~/xml/i
                    or ($Init_Desc{"OuterType_Type"}=~/\A(Struct|Union)\Z/ and get_TypeName($Init_Desc{"OuterType_Id"})=~/xml/i))
                    {
                        @Values = ("TG_TEST_DATA_XML_FILE");
                    }
                    elsif($ParamName=~/html/i or $I_ShortName=~/html/i
                    or ($Init_Desc{"OuterType_Type"}=~/\A(Struct|Union)\Z/ and get_TypeName($Init_Desc{"OuterType_Id"})=~/html/i))
                    {
                        @Values = ("TG_TEST_DATA_HTML_FILE");
                    }
                    elsif($ParamName=~/path/i and $I_ShortName=~/\Asnd_/)
                    { # ALSA
                        @Values = ("TG_TEST_DATA_ASOUNDRC_FILE");
                    }
                    else
                    {
                        my $KnownExt = isKnownExt(getPrefix($I_ShortName));
                        $KnownExt = isKnownExt($Init_Desc{"Key"}) if(not $KnownExt);
                        $KnownExt = isKnownExt($TestedInterface) if(not $KnownExt);
                        $KnownExt = isKnownExt($I_ShortName) if(not $KnownExt);
                        if($KnownExt) {
                            @Values = ("TG_TEST_DATA_FILE_".uc($KnownExt));
                        }
                        else {
                            @Values = ("TG_TEST_DATA_PLAIN_FILE");
                        }
                    }
                }
                elsif(isStr_Dir($ParamName, $I_ShortName)
                or ($ParamName=~/path/ and get_TypeName($Init_Desc{"OuterType_Id"})=~/Dir|directory/))
                {
                    @Values = ("TG_TEST_DATA_DIRECTORY");
                }
                elsif($ParamName=~/path/i and $I_ShortName=~/\Adbus_/)
                { # D-Bus
                    @Values = ("TG_TEST_DATA_ABS_FILE");
                }
                elsif($ParamName=~/path/i) {
                    @Values = ("TG_TEST_DATA_PLAIN_FILE");
                }
                elsif($ParamName=~/\A(ext|extension(s|))\Z/i) {
                    @Values = ("\".txt\"", "\".hh\"");
                }
                elsif($ParamName=~/mode/i and $I_ShortName=~/fopen/i)
                { # FILE *fopen(const char *path, const char *mode)
                    @Values = ("\"r+\"");
                }
                elsif($ParamName=~/mode/i and $I_ShortName=~/open/i) {
                    @Values = ("\"rw\"");
                }
                elsif($ParamName=~/date/i) {
                    @Values = ("\"Sun, 06 Nov 1994 08:49:37 GMT\"");
                }
                elsif($ParamName=~/day/i) {
                    @Values = ("\"monday\"", "\"tuesday\"");
                }
                elsif($ParamName=~/month/i) {
                    @Values = ("\"november\"", "\"october\"");
                }
                elsif($ParamName=~/name/i and $I_ShortName=~/font/i)
                {
                    if($I_ShortName=~/\A[_]*X/) {
                        @Values = ("\"10x20\"", "\"fixed\"");
                    }
                    else {
                        @Values = ("\"times\"", "\"arial\"", "\"courier\"");
                    }
                }
                elsif($ParamName=~/version/i) {
                    @Values = ("\"1.0\"", "\"2.0\"");
                }
                elsif($ParamName=~/encoding/i
                or $Init_Desc{"Key"}=~/encoding/i) {
                    @Values = ("\"utf-8\"", "\"koi-8\"");
                }
                elsif($ParamName=~/method/i
                and $I_ShortName=~/http|ftp|url|uri|request/i) {
                    @Values = ("\"GET\"", "\"PUT\"");
                }
                elsif($I_ShortName=~/cast/i
                and $CompleteSignature{$Interface}{"Class"}) {
                    @Values = ("\"".get_TypeName($CompleteSignature{$Interface}{"Class"})."\"");
                }
                elsif($I_ShortName=~/\Asnd_/ and $I_ShortName!~/\Asnd_seq_/ and $ParamName=~/name/i)
                { # ALSA
                    @Values = ("\"hw:0\"");
                }
                elsif($ParamName=~/var/i and $I_ShortName=~/env/i) {
                    @Values = ("\"HOME\"", "\"PATH\"");
                }
                elsif($ParamName=~/error_name/i and $I_ShortName=~/\Adbus_/)
                { # D-Bus
                    if($Constants{"DBUS_ERROR_FAILED"}{"Value"}) {
                        @Values = ("DBUS_ERROR_FAILED");
                    }
                    else {
                        @Values = ("\"org.freedesktop.DBus.Error.Failed\"");
                    }
                }
                elsif($ParamName=~/name/i and $I_ShortName=~/\Adbus_/)
                { # D-Bus
                    @Values = ("\"sample.bus\"");
                }
                elsif($ParamName=~/interface/i and $I_ShortName=~/\Adbus_/) {
                    @Values = ("\"sample.interface\""); # D-Bus
                }
                elsif($ParamName=~/address/i and $I_ShortName=~/\Adbus_server/) {
                    @Values = ("\"unix:tmpdir=/tmp\""); # D-Bus
                }
                elsif($CompleteSignature{$Interface}{"Constructor"} and not $Init_Desc{"ParamRenamed"})
                {
                    my $KeyPart = $Init_Desc{"Key"};
                    my $IgnoreSiffix = lc($I_ShortName)."_".$ParamName;
                    $KeyPart=~s/_\Q$ParamName\E\Z// if($I_ShortName=~/string|char/i and $KeyPart!~/(\A|_)\Q$IgnoreSiffix\E\Z/);
                    $KeyPart=~s/_\d+\Z//g;
                    $KeyPart=~s/\A.*_([^_]+)\Z/$1/g;
                    if($KeyPart!~/(\A|_)p\d+\Z/)
                    {
                        $NewInit_Desc{"ParamName"} = $KeyPart;
                        $NewInit_Desc{"ParamRenamed"} = 1;
                        %NewInit_Desc = add_VirtualSpecType(%NewInit_Desc);
                    }
                    else {
                        @Values = ("\"".$ParamName."\"");
                    }
                }
                else {
                    @Values = ("\"".$ParamName."\"");
                }
            }
            else
            {
                if($I_ShortName=~/Display/)
                {
                    @Values = ("getenv(\"DISPLAY\")");
                    $NewInit_Desc{"Headers"} = addHeaders(["stdlib.h"], $NewInit_Desc{"Headers"});
                    $AuxHeaders{"stdlib.h"} = 1;
                }
                elsif($I_ShortName=~/cast/ and $CompleteSignature{$Interface}{"Class"}) {
                    @Values = ("\"".get_TypeName($CompleteSignature{$Interface}{"Class"})."\"");
                }
                else {
                    @Values = (getIntrinsicValue("char*"));
                }
            }
            if($FoundationTypeName eq "wchar_t")
            {
                foreach my $Str (@Values) {
                    $Str = "L".$Str if($Str=~/\A\"/);
                }
                $NewInit_Desc{"ValueTypeId"} = get_TypeIdByName("wchar_t const*");
            }
            elsif($FoundationTypeType eq "Intrinsic") {
                $NewInit_Desc{"ValueTypeId"} = get_TypeIdByName("char const*");
            }
            else
            { # std::string
                $NewInit_Desc{"ValueTypeId"} = $FoundationTypeId;
            }
            $NewInit_Desc{"Value"} = vary_values(\@Values, \%Init_Desc) if($#Values>=0);
            if(not is_const_type(uncover_typedefs(get_TypeName($TypeId))) and not $Init_Desc{"IsString"})
            { # FIXME: inlining strings
                #$NewInit_Desc{"InLine"} = 0;
            }
        }
        elsif(($FoundationTypeName eq "void") and ($PointerLevel==1))
        {
            $NewInit_Desc{"FoundationType_Type"} = "Array";
            $NewInit_Desc{"TypeType_Changed"} = 1;
            $NewInit_Desc{"TypeId"} = get_TypeIdByName("char*");
            $NewInit_Desc{"TypeId_Changed"} = $TypeId;
        }
        elsif($FoundationTypeType eq "Intrinsic")
        {
            if($PointerLevel==1 and $ParamName=~/matrix/i)
            {
                $NewInit_Desc{"FoundationType_Type"} = "Array";
                $NewInit_Desc{"TypeType_Changed"} = 1;
                $NewInit_Desc{"ArraySize"} = 16;
            }
            elsif(isIntegerType($FoundationTypeName))
            {
                if($PointerLevel==0)
                {
                    if($Init_Desc{"RetVal"}
                    and $CurrentBlock=~/read/i) {
                        $NewInit_Desc{"Value"} = "0";
                    }
                    elsif($Init_Desc{"RetVal"}
                    and $TypeName=~/err/i) {
                        $NewInit_Desc{"Value"} = "1";
                    }
                    elsif($ParamName=~/socket|block/i) {
                        $NewInit_Desc{"Value"} = vary_values(["0"], \%Init_Desc);
                    }
                    elsif($ParamName=~/freq/i) {
                        $NewInit_Desc{"Value"} = vary_values(["50"], \%Init_Desc);
                    }
                    elsif(lc($ParamName) eq "id") {
                        $NewInit_Desc{"Value"} = "0";
                    }
                    elsif($ParamName=~/verbose/i) {
                        $NewInit_Desc{"Value"} = vary_values(["0", "1"], \%Init_Desc);
                    }
                    elsif($ParamName=~/year/i
                    or ($ParamName eq "y" and $I_ShortName=~/date/i)) {
                        $NewInit_Desc{"Value"} = vary_values(["2009", "2010"], \%Init_Desc);
                    }
                    elsif($ParamName eq "sa_family"
                    and get_TypeName($Init_Desc{"OuterType_Id"}) eq "struct sockaddr") {
                        $NewInit_Desc{"Value"} = vary_values(["AF_INET", "AF_INET6"], \%Init_Desc);
                    }
                    elsif($ParamName=~/day/i or ($ParamName eq "d" and $I_ShortName=~/date/i)) {
                        $NewInit_Desc{"Value"} = vary_values(["30", "17"], \%Init_Desc);
                    }
                    elsif($ParamName=~/month/i
                    or ($ParamName eq "m" and $I_ShortName=~/date/i)) {
                        $NewInit_Desc{"Value"} = vary_values(["11", "10"], \%Init_Desc);
                    }
                    elsif($ParamName=~/\Ac\Z/i and $I_ShortName=~/char/i) {
                        $NewInit_Desc{"Value"} = vary_values([get_CharNum()], \%Init_Desc);
                    }
                    elsif($ParamName=~/n_param_values/i) {
                        $NewInit_Desc{"Value"} = vary_values(["2"], \%Init_Desc);
                    }
                    elsif($ParamName=~/debug/i) {
                        $NewInit_Desc{"Value"} = vary_values(["0", "1"], \%Init_Desc);
                    }
                    elsif($ParamName=~/hook/i)
                    {
                        $NewInit_Desc{"Value"} = vary_values(["128"], \%Init_Desc);
                    }
                    elsif($ParamName=~/size|len|count/i
                    and $I_ShortName=~/char|string/i) {
                        $NewInit_Desc{"Value"} = vary_values(["7"], \%Init_Desc);
                    }
                    elsif($ParamName=~/size|len|capacity|count|max|(\A(n|l|s|c)_)/i) {
                        $NewInit_Desc{"Value"} = vary_values([$DEFAULT_ARRAY_AMOUNT], \%Init_Desc);
                    }
                    elsif($ParamName=~/time/i and $ParamName=~/req/i) {
                        $NewInit_Desc{"Value"} = vary_values([$HANGED_EXECUTION_TIME], \%Init_Desc);
                    }
                    elsif($ParamName=~/time/i
                    or ($ParamName=~/len/i and $ParamName!~/error/i)) {
                        $NewInit_Desc{"Value"} = vary_values(["1", "0"], \%Init_Desc);
                    }
                    elsif($ParamName=~/depth/i) {
                        $NewInit_Desc{"Value"} = vary_values(["1"], \%Init_Desc);
                    }
                    elsif($ParamName=~/delay/i) {
                        $NewInit_Desc{"Value"} = vary_values(["0", "1"], \%Init_Desc);
                    }
                    elsif($TypeName=~/(count|size)_t/i
                    and $ParamName=~/items/) {
                        $NewInit_Desc{"Value"} = vary_values([$DEFAULT_ARRAY_AMOUNT], \%Init_Desc);
                    }
                    elsif($ParamName=~/exists|start/i) {
                        $NewInit_Desc{"Value"} = vary_values(["0", "1"], \%Init_Desc);
                    }
                    elsif($ParamName=~/make/i) {
                        $NewInit_Desc{"Value"} = vary_values(["1", "0"], \%Init_Desc);
                    }
                    elsif($ParamName=~/\A(n|l|s|c)[0-9_]*\Z/i
                    # gsl_vector_complex_float_alloc (size_t const n)
                    # gsl_matrix_complex_float_alloc (size_t const n1, size_t const n2)
                    or (is_alloc_func($I_ShortName) and $ParamName=~/(num|len)[0-9_]*/i))
                    {
                        if($I_ShortName=~/column/) {
                            $NewInit_Desc{"Value"} = vary_values(["0"], \%Init_Desc);
                        }
                        else {
                            $NewInit_Desc{"Value"} = vary_values([$DEFAULT_ARRAY_AMOUNT], \%Init_Desc);
                        }
                    }
                    elsif($Init_Desc{"OuterType_Type"} eq "Array"
                    and $Init_Desc{"Index"} ne "") {
                        $NewInit_Desc{"Value"} = vary_values([$Init_Desc{"Index"}], \%Init_Desc);
                    }
                    elsif(($ParamName=~/index|from|pos|field|line|column|row/i and $ParamName!~/[a-z][a-rt-z]s\Z/i)
                    or $ParamName=~/\A(i|j|k|icol)\Z/i)
                    { # gsl_vector_complex_float_get (gsl_vector_complex_float const* v, size_t const i)
                        if($Init_Desc{"OuterType_Type"} eq "Array") {
                            $NewInit_Desc{"Value"} = vary_values([$Init_Desc{"Index"}], \%Init_Desc);
                        }
                        else {
                            $NewInit_Desc{"Value"} = vary_values(["0"], \%Init_Desc);
                        }
                    }
                    elsif($TypeName=~/bool/i) {
                        $NewInit_Desc{"Value"} = vary_values(["1", "0"], \%Init_Desc);
                    }
                    elsif($ParamName=~/with/i) {
                        $NewInit_Desc{"Value"} = vary_values(["1", "0"], \%Init_Desc);
                    }
                    elsif($ParamName=~/sign/i) {
                        $NewInit_Desc{"Value"} = vary_values(["1", "0"], \%Init_Desc);
                    }
                    elsif($ParamName=~/endian|order/i) {
                        $NewInit_Desc{"Value"} = vary_values(["1", "0"], \%Init_Desc);
                    }
                    elsif($ParamName=~/\A(w|width)\d*\Z/i
                    and $I_ShortName=~/display/i) {
                        $NewInit_Desc{"Value"} = vary_values(["640"], \%Init_Desc);
                    }
                    elsif($ParamName=~/\A(h|height)\d*\Z/i
                    and $I_ShortName=~/display/i) {
                        $NewInit_Desc{"Value"} = vary_values(["480"], \%Init_Desc);
                    }
                    elsif($ParamName=~/width|height/i
                    or $ParamName=~/\A(x|y|z|w|h)\d*\Z/i) {
                        $NewInit_Desc{"Value"} = vary_values([8 * getIntrinsicValue($FoundationTypeName)], \%Init_Desc);
                    }
                    elsif($ParamName=~/offset/i) {
                        $NewInit_Desc{"Value"} = vary_values(["8", "16"], \%Init_Desc);
                    }
                    elsif($ParamName=~/stride|step|spacing|iter|interval|move/i
                    or $ParamName=~/\A(to)\Z/) {
                        $NewInit_Desc{"Value"} = vary_values(["1"], \%Init_Desc);
                    }
                    elsif($ParamName=~/channels|frames/i and $I_ShortName=~/\Asnd_/i)
                    { # ALSA
                        $NewInit_Desc{"Value"} = vary_values([$DEFAULT_ARRAY_AMOUNT], \%Init_Desc);
                    }
                    elsif($ParamName=~/first/i and ($Init_Desc{"OuterType_Type"} eq "Struct" and get_TypeName($Init_Desc{"OuterType_Id"})=~/_snd_/i))
                    { # ALSA
                        $NewInit_Desc{"Value"} = vary_values([8 * getIntrinsicValue($FoundationTypeName)], \%Init_Desc);
                    }
                    elsif(isFD($TypeId, $ParamName))
                    {
                        $NewInit_Desc{"Value"} = vary_values(["open(TG_TEST_DATA_PLAIN_FILE, O_RDWR)"], \%Init_Desc);
                        $NewInit_Desc{"Headers"} = addHeaders(["sys/stat.h", "fcntl.h"], $NewInit_Desc{"Headers"});
                        $AuxHeaders{"sys/stat.h"}=1;
                        $NewInit_Desc{"InLine"}=0;
                        $AuxHeaders{"fcntl.h"}=1;
                        $FuncNames{"open"} = 1;
                    }
                    elsif(($TypeName=~/enum/i or $ParamName=~/message_type/i)
                    and my $EnumConstant = selectConstant($TypeName, $ParamName, $Interface))
                    { # or ($TypeName eq "int" and $ParamName=~/\Amode|type\Z/i and $I_ShortName=~/\Asnd_/i) or $ParamName=~/mask/
                        $NewInit_Desc{"Value"} = vary_values([$EnumConstant], \%Init_Desc);
                        $NewInit_Desc{"Headers"} = addHeaders([$Constants{$EnumConstant}{"Header"}], $NewInit_Desc{"Headers"});
                    }
                    elsif($TypeName=~/enum/i
                    or $ParamName=~/mode|type|flag|option/i) {
                        $NewInit_Desc{"Value"} = vary_values(["0"], \%Init_Desc);
                    }
                    elsif($ParamName=~/mask|alloc/i) {
                        $NewInit_Desc{"Value"} = vary_values(["0"], \%Init_Desc);
                    }
                    elsif($ParamName=~/screen|format/i) {
                        $NewInit_Desc{"Value"} = vary_values(["1"], \%Init_Desc);
                    }
                    elsif($ParamName=~/ed\Z/i) {
                        $NewInit_Desc{"Value"} = vary_values(["0"], \%Init_Desc);
                    }
                    elsif($ParamName=~/key/i
                    and $I_ShortName=~/\A[_]*X/)
                    { #X11
                        $NewInit_Desc{"Value"} = vary_values(["9"], \%Init_Desc);
                    }
                    elsif($ParamName=~/\Ap\d+\Z/
                    and $Init_Desc{"ParamPos"}==$Init_Desc{"MaxParamPos"}
                    and $I_ShortName=~/create|intern|privat/i) {
                        $NewInit_Desc{"Value"} = vary_values(["0"], \%Init_Desc);
                    }
                    elsif($TypeName=~/size/i) {
                        $NewInit_Desc{"Value"} = vary_values([$DEFAULT_ARRAY_AMOUNT], \%Init_Desc);
                    }
                    else {
                        $NewInit_Desc{"Value"} = vary_values([getIntrinsicValue($FoundationTypeName)], \%Init_Desc);
                    }
                }
                else {
                    $NewInit_Desc{"Value"} = "0";
                }
            }
            elsif(isCharType($FoundationTypeName)
            and $TypeName=~/bool/i) {
                $NewInit_Desc{"Value"} = vary_values([1, 0], \%Init_Desc);
            }
            else {
                $NewInit_Desc{"Value"} = vary_values([getIntrinsicValue($FoundationTypeName)], \%Init_Desc);
            }
            $NewInit_Desc{"ValueTypeId"} = ($PointerLevel==0)?$TypeId:$FoundationTypeId;
        }
        elsif($FoundationTypeType eq "Enum")
        {
            if(my $EnumMember = getSomeEnumMember($FoundationTypeId))
            {
                if(defined $Template2Code and $PointerLevel==0)
                {
                    my $Members = [];
                    foreach my $Member (@{getEnumMembers($FoundationTypeId)})
                    {
                        if(is_valid_constant($Member)) {
                            push(@{$Members}, $Member);
                        }
                    }
                    if($#{$Members}>=0) {
                        $NewInit_Desc{"Value"} = vary_values($Members, \%Init_Desc);
                    }
                    else {
                        $NewInit_Desc{"Value"} = vary_values(getEnumMembers($FoundationTypeId), \%Init_Desc);
                    }
                }
                else {
                    $NewInit_Desc{"Value"} = $EnumMember;
                }
            }
            else {
                $NewInit_Desc{"Value"} = "0";
            }
            $NewInit_Desc{"ValueTypeId"} = $FoundationTypeId;
        }
    }
    else
    {
        if(not $NewInit_Desc{"ValueTypeId"})
        { # for union spectypes
            $NewInit_Desc{"ValueTypeId"} = $TypeId;
        }
    }
    if($NewInit_Desc{"Value"} eq "")
    {
        $NewInit_Desc{"Value"} = "no value";
    }
    return %NewInit_Desc;
}

sub is_valid_constant($)
{
    my $Constant = $_[0];
    return $Constant!~/(unknown|invalid|null|err|none|(_|\A)(ms|win\d*|no)(_|\Z))/i;
}

sub get_CharNum()
{
    $IntrinsicNum{"Char"}=64 if($IntrinsicNum{"Char"} > 89 or $IntrinsicNum{"Char"} < 64);
    if($RandomCode) {
        $IntrinsicNum{"Char"} = 64+int(rand(25));
    }
    $IntrinsicNum{"Char"}+=1;
    return $IntrinsicNum{"Char"};
}

sub vary_values($$)
{
    my ($ValuesArrayRef, $Init_Desc) = @_;
    my @ValuesArray = @{$ValuesArrayRef};
    return "" if($#ValuesArray==-1);
    if(defined $Template2Code and ($Init_Desc->{"Interface"} eq $TestedInterface) and not $Init_Desc->{"OuterType_Type"} and length($Init_Desc->{"ParamName"})>=2 and $Init_Desc->{"ParamName"}!~/\Ap\d+\Z/i)
    {
        my $Define = uc($Init_Desc->{"ParamName"});
        if(defined $Constants{$Define}) {
            $Define = "_".$Define;
        }
        $Define = select_var_name($Define, "");
        $Block_Variable{$CurrentBlock}{$Define} = 1;
        my $DefineWithNum = keys(%Template2Code_Defines).":".$Define;
        if($#ValuesArray>=1) {
            $Template2Code_Defines{$DefineWithNum} = "SET(".$ValuesArray[0]."; ".$ValuesArray[1].")";
        }
        else {
            $Template2Code_Defines{$DefineWithNum} = $ValuesArray[0];
        }
        return $Define;
    }
    else
    { # standalone
        return $ValuesArray[0];
    }
}

sub selectConstant($$$)
{
    my ($TypeName, $ParamName, $Interface) = @_;
    return $Cache{"selectConstant"}{$TypeName}{$ParamName}{$Interface} if(defined $Cache{"selectConstant"}{$TypeName}{$ParamName}{$Interface});
    my @Csts = ();
    foreach (keys(%Constants))
    {
        if($Constants{$_}{"Value"}=~/\A\d/) {
            push(@Csts, $_);
        }
    }
    @Csts = sort @Csts;
    @Csts = sort {length($a)<=>length($b)} @Csts;
    @Csts = sort {$CompleteSignature{$Interface}{"Header"} cmp $Constants{$a}{"HeaderName"}} @Csts;
    my (@Valid, @Invalid) = ();
    foreach (@Csts)
    {
        if(is_valid_constant($_)) {
            push(@Valid, $_);
        }
        else {
            push(@Invalid, $_);
        }
    }
    @Csts = (@Valid, @Invalid);
    sort_byName(\@Csts, $ParamName." ".$CompleteSignature{$Interface}{"ShortName"}." ".$TypeName, "Constants");
    if($#Csts>=0)
    {
        $Cache{"selectConstant"}{$TypeName}{$ParamName}{$Interface} = $Csts[0];
        return $Csts[0];
    }
    else
    {
        $Cache{"selectConstant"}{$TypeName}{$ParamName}{$Interface} = "";
        return "";
    }
}

sub isFD($$)
{
    my ($TypeId, $ParamName) = @_;
    my $FoundationTypeId = get_FoundationTypeId($TypeId);
    my $FoundationTypeName = get_TypeName($FoundationTypeId);
    if($ParamName=~/(\A|[_]+)fd(s|)\Z/i
    and isIntegerType($FoundationTypeName)) {
        return (-f "/usr/include/sys/stat.h" and -f "/usr/include/fcntl.h");
    }
    else {
        return "";
    }
}

sub find_similar_type($$)
{
    my ($TypeId, $ParamName) = @_;
    return 0 if(not $TypeId or not $ParamName);
    return 0 if($ParamName=~/\A(p\d+|data|object)\Z/i or length($ParamName)<=2 or is_out_word($ParamName));
    return $Cache{"find_similar_type"}{$TypeId}{$ParamName} if(defined $Cache{"find_similar_type"}{$TypeId}{$ParamName} and not defined $AuxType{$TypeId});
    my $PointerLevel = get_PointerLevel($TypeId);
    $ParamName=~s/([a-z][a-df-rt-z])s\Z/$1/i;
    my @TypeNames = ();
    foreach my $TypeName (keys(%StructUnionPName_Tid))
    {
        if($TypeName=~/\Q$ParamName\E/i)
        {
            my $Tid = $StructUnionPName_Tid{$TypeName};
            next if(not $Tid);
            my $FTid = get_FoundationTypeId($Tid);
            next if(get_TypeType($FTid)!~/\A(Struct|Union)\Z/);
            next if(isOpaque($FTid) and not keys(%{$ReturnTypeId_Interface{$Tid}}));
            next if(get_PointerLevel($Tid)!=$PointerLevel);
            push(@TypeNames, $TypeName);
        }
    }
    @TypeNames = sort {lc($a) cmp lc($b)} @TypeNames;
    @TypeNames = sort {length($a)<=>length($b)} @TypeNames;
    @TypeNames = sort {$a=~/\*/<=>$b=~/\*/} @TypeNames;
    # @TypeNames = sort {keys(%{$ReturnTypeId_Interface{$TName_Tid{$b}}})<=>keys(%{$ReturnTypeId_Interface{$TName_Tid{$a}}})} @TypeNames;
    if($#TypeNames>=0)
    {
        $Cache{"find_similar_type"}{$TypeId}{$ParamName} = $TName_Tid{$TypeNames[0]};
        return $StructUnionPName_Tid{$TypeNames[0]};
    }
    else
    {
        $Cache{"find_similar_type"}{$TypeId}{$ParamName} = 0;
        return 0;
    }
}

sub isCyclical($$)
{
    return (grep {$_ eq $_[1]} @{$_[0]});
}

sub convertTypes(@)
{
    my %Conv = @_;
    return () if(not $Conv{"OutputTypeId"} or not $Conv{"InputTypeName"} or not $Conv{"Value"} or not $Conv{"Key"});
    my $OutputType_PointerLevel = get_PointerLevel($Conv{"OutputTypeId"});
    my $OutputType_Name = get_TypeName($Conv{"OutputTypeId"});
    my $OutputFType_Id = get_FoundationTypeId($Conv{"OutputTypeId"});
    my $OutputType_BaseTypeType = get_TypeType($OutputFType_Id);
    my $PLevelDelta = $OutputType_PointerLevel - $Conv{"InputPointerLevel"};
    return ($Conv{"Value"}, "") if($OutputType_Name eq "...");
    my $Tmp_Var = $Conv{"Key"};
    $Tmp_Var .= ($Conv{"Destination"} eq "Target")?"_tp":"_p";
    my $NeedTypeConvertion = 0;
    my ($Preamble, $ToCall) = ();
    # pointer convertion
    if($PLevelDelta==0) {
        $ToCall = $Conv{"Value"};
    }
    elsif($PLevelDelta==1)
    {
        if($Conv{"Value"}=~/\A\&/)
        {
            $Preamble .= $Conv{"InputTypeName"}." $Tmp_Var = (".$Conv{"InputTypeName"}.")".$Conv{"Value"}.";\n";
            $Block_Variable{$CurrentBlock}{$Tmp_Var} = 1;
            $ToCall = "&".$Tmp_Var;
        }
        else {
            $ToCall = "&".$Conv{"Value"};
        }
    }
    elsif($PLevelDelta<0)
    {
        foreach (0 .. - 1 - $PLevelDelta) {
            $ToCall = $ToCall."*";
        }
        $ToCall = $ToCall.$Conv{"Value"};
    }
    else
    { # this section must be deprecated in future
        my $Stars = "**";
        if($Conv{"Value"}=~/\A\&/)
        {
            $Preamble .= $Conv{"InputTypeName"}." $Tmp_Var = (".$Conv{"InputTypeName"}.")".$Conv{"Value"}.";\n";
            $Block_Variable{$CurrentBlock}{$Tmp_Var} = 1;
            $Conv{"Value"} = $Tmp_Var;
            $Tmp_Var .= "p";
        }
        $Preamble .= $Conv{"InputTypeName"}." *$Tmp_Var = (".$Conv{"InputTypeName"}." *)&".$Conv{"Value"}.";\n";
        $Block_Variable{$CurrentBlock}{$Tmp_Var} = 1;
        my $Tmp_Var_Pre = $Tmp_Var;
        foreach my $Itr (1 .. $PLevelDelta - 1)
        {
            $Tmp_Var .= "p";
            $Block_Variable{$CurrentBlock}{$Tmp_Var} = 1;
            $Preamble .= $Conv{"InputTypeName"}." $Stars$Tmp_Var = &$Tmp_Var_Pre;\n";
            $Stars .= "*";
            $NeedTypeConvertion = 1;
            $Tmp_Var_Pre = $Tmp_Var;
            $ToCall = $Tmp_Var;
        }
    }
    $Preamble .= "\n" if($Preamble);
    
    $NeedTypeConvertion = 1 if(get_base_type_name($OutputType_Name) ne get_base_type_name($Conv{"InputTypeName"}));
    $NeedTypeConvertion = 1 if(not is_equal_types($OutputType_Name,$Conv{"InputTypeName"}) and $PLevelDelta==0);
    $NeedTypeConvertion = 1 if(not is_const_type($OutputType_Name) and is_const_type($Conv{"InputTypeName"}));
    $NeedTypeConvertion = 0 if(($OutputType_PointerLevel eq 0) and (($OutputType_BaseTypeType eq "Class") or ($OutputType_BaseTypeType eq "Struct")));
    $NeedTypeConvertion = 1 if((($OutputType_Name=~/\&/) or $Conv{"MustConvert"}) and ($OutputType_PointerLevel > 0) and (($OutputType_BaseTypeType eq "Class") or ($OutputType_BaseTypeType eq "Struct")));
    $NeedTypeConvertion = 1 if($OutputType_PointerLevel eq 2);
    $NeedTypeConvertion = 0 if($OutputType_Name eq $Conv{"InputTypeName"});
    $NeedTypeConvertion = 0 if(uncover_typedefs($OutputType_Name)=~/\[(\d+|)\]/); # arrays
    $NeedTypeConvertion = 0 if(isAnon($OutputType_Name));
    
    # type convertion
    if($NeedTypeConvertion and ($Conv{"Destination"} eq "Param"))
    {
        if($ToCall=~/\-\>/) {
            $ToCall = "(".$OutputType_Name.")"."(".$ToCall.")";
        }
        else {
            $ToCall = "(".$OutputType_Name.")".$ToCall;
        }
    }
    return ($ToCall, $Preamble);
}

sub sortTypes_ByPLevel($$)
{
    my ($Types, $PLevel) = @_;
    my (@Eq, @Lt, @Gt) = ();
    foreach my $TypeId (@{$Types})
    {
        my $Type_PLevel = get_PointerLevel($TypeId);
        if($Type_PLevel==$PLevel) {
            push(@Eq, $TypeId);
        }
        elsif($Type_PLevel<$PLevel) {
            push(@Lt, $TypeId);
        }
        elsif($Type_PLevel>$PLevel) {
            push(@Gt, $TypeId);
        }
    }
    @{$Types} = (@Eq, @Lt, @Gt);
}

sub familyTypes($)
{
    my $TypeId = $_[0];
    return [] if(not $TypeId);
    my $FoundationTypeId = get_FoundationTypeId($TypeId);
    return $Cache{"familyTypes"}{$TypeId} if($Cache{"familyTypes"}{$TypeId} and not defined $AuxType{$TypeId});
    my (@FamilyTypes_Const, @FamilyTypes_NotConst) = ();
    foreach my $Tid (sort {int($a)<=>int($b)} keys(%TypeInfo))
    {
        if((get_FoundationTypeId($Tid) eq $FoundationTypeId) and ($Tid ne $TypeId))
        {
            if(is_const_type(get_TypeName($Tid))) {
                @FamilyTypes_Const = (@FamilyTypes_Const, $Tid);
            }
            else {
                @FamilyTypes_NotConst = (@FamilyTypes_NotConst, $Tid);
            }
        }
    }
    sortTypes_ByPLevel(\@FamilyTypes_Const, get_PointerLevel($TypeId));
    sortTypes_ByPLevel(\@FamilyTypes_NotConst, get_PointerLevel($TypeId));
    my @FamilyTypes = ((is_const_type(get_TypeName($TypeId)))?(@FamilyTypes_NotConst, $TypeId, @FamilyTypes_Const):($TypeId, @FamilyTypes_NotConst, @FamilyTypes_Const));
    $Cache{"familyTypes"}{$TypeId} = \@FamilyTypes;
    return \@FamilyTypes;
}

sub register_ExtType($$$)
{
    my ($Type_Name, $Type_Type, $BaseTypeId) = @_;
    return "" if(not $Type_Name or not $Type_Type or not $BaseTypeId);
    return $TName_Tid{$Type_Name} if($TName_Tid{$Type_Name});
    $MaxTypeId += 1;
    $TName_Tid{$Type_Name} = $MaxTypeId;
    %{$TypeInfo{$MaxTypeId}}=(
        "Name" => $Type_Name,
        "Type" => $Type_Type,
        "BaseType" => $BaseTypeId,
        "Tid" => $MaxTypeId,
        "Headers"=>getTypeHeaders($BaseTypeId)
    );
    $AuxType{$MaxTypeId} = $Type_Name;
    return $MaxTypeId;
}


sub get_ExtTypeId($$)
{
    my ($Key, $TypeId) = @_;
    return () if(not $TypeId);
    my ($Declarations, $Headers) = ("", []);
    if(get_TypeType($TypeId) eq "Typedef") {
        return ($TypeId, "", "");
    }
    my $FTypeId = get_FoundationTypeId($TypeId);
    my %BaseType = goToFirst($TypeId, "Typedef");
    my $BaseTypeId = $BaseType{"Tid"};
    if(not $BaseTypeId)
    {
        $BaseTypeId = $FTypeId;
        if(get_TypeName($BaseTypeId)=~/\Astd::/)
        {
            if(my $CxxTypedefId = get_type_typedef($BaseTypeId)) {
                $BaseTypeId = $CxxTypedefId;
            }
        }
    }
    my $PointerLevel = get_PointerLevel($TypeId) - get_PointerLevel($BaseTypeId);
    if(get_TypeType($FTypeId) eq "Array")
    {
        my ($Array_BaseName, $Array_Length) = reassemble_array($FTypeId);
        $BaseTypeId = get_TypeIdByName($Array_BaseName);
        $PointerLevel+=1;
    }
    my $BaseTypeName = get_TypeName($BaseTypeId);
    my $BaseTypeType = get_TypeType($BaseTypeId);
    if($BaseTypeType eq "FuncPtr") {
        $Declarations .= declare_funcptr_typedef($Key, $BaseTypeId);
    }
    if(isAnon($BaseTypeName))
    {
        if($BaseTypeType eq "Struct")
        {
            my ($AnonStruct_Declarations, $AnonStruct_Headers) = declare_anon_struct($Key, $BaseTypeId);
            $Declarations .= $AnonStruct_Declarations;
            $Headers = addHeaders($AnonStruct_Headers, $Headers);
        }
        elsif($BaseTypeType eq "Union")
        {
            my ($AnonUnion_Declarations, $AnonUnion_Headers) = declare_anon_union($Key, $BaseTypeId);
            $Declarations .= $AnonUnion_Declarations;
            $Headers = addHeaders($AnonUnion_Headers, $Headers);
        }
    }
    if($PointerLevel>=1)
    {
#         if(get_TypeType(get_FoundationTypeId($TypeId)) eq "FuncPtr" and get_TypeName($TypeId)=~/\A[^*]+const\W/)
#         {
#             $BaseTypeId = register_ExtType(get_TypeName($BaseTypeId)." const", "Const", $BaseTypeId);
#         }
        
        my $ExtTypeId = register_new_type($BaseTypeId, $PointerLevel);
        return ($ExtTypeId, $Declarations, $Headers);
    }
    else {
        return ($BaseTypeId, $Declarations, $Headers);
    }
}

sub register_new_type($$)
{
    my ($BaseTypeId, $PLevel) = @_;
    my $ExtTypeName = get_TypeName($BaseTypeId);
    my $ExtTypeId = $BaseTypeId;
    foreach (1 .. $PLevel)
    {
        $ExtTypeName .= "*";
        $ExtTypeName = formatName($ExtTypeName, "T");
        if(not $TName_Tid{$ExtTypeName}) {
            register_ExtType($ExtTypeName, "Pointer", $ExtTypeId);
        }
        $ExtTypeId = $TName_Tid{$ExtTypeName};
    }
    return $ExtTypeId;
}

sub correct_init_stmt($$$)
{
    my ($String, $TypeName, $ParamName) = @_;
    my $Stmt = $TypeName." ".$ParamName." = ".$TypeName;
    if($String=~/\Q$Stmt\E\:\:/) {
        return $String;
    }
    else
    {
        $String=~s/(\W|\A)\Q$Stmt\E\(\)(\W|\Z)/$1$TypeName $ParamName$2/g;
        $String=~s/(\W|\A)\Q$Stmt\E(\W|\Z)/$1$TypeName $ParamName$2/g;
        return $String;
    }
}

sub isValidConv($)
{
    return ($_[0]!~/\A(__va_list_tag|...)\Z/);
}

sub emptyDeclaration(@)
{
    my %Init_Desc = @_;
    my %Type_Init = ();
    $Init_Desc{"Var"} = select_var_name($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ParamNameExt"});
    my $Var = $Init_Desc{"Var"};
    my $InitTypeId = $Init_Desc{"ValueTypeId"};
    if(not $InitTypeId) {
        $InitTypeId = $Init_Desc{"TypeId"};
    }
    my $InitializedType_PLevel = get_PointerLevel($InitTypeId);
    my ($ETypeId, $Declarations, $Headers) = get_ExtTypeId($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $InitTypeId);
    my $InitializedType_Name = get_TypeName($ETypeId);
    if($InitializedType_Name eq "void") {
        $InitializedType_Name = "int";
    }
    $Type_Init{"Code"} .= $Declarations;
    $Type_Init{"Headers"} = addHeaders($Headers, $Type_Init{"Headers"});
    $Type_Init{"Headers"} = addHeaders($Headers, getTypeHeaders($ETypeId));
    $Type_Init{"Headers"} = addHeaders($Headers, getTypeHeaders(get_FoundationTypeId($ETypeId))) if($InitializedType_PLevel==0);
    $Type_Init{"Init"} = $InitializedType_Name." ".$Var.";\n";
    $Block_Variable{$CurrentBlock}{$Var} = 1;
    # create call
    my ($Call, $Preamble) = convertTypes((
        "InputTypeName"=>$InitializedType_Name,
        "InputPointerLevel"=>$InitializedType_PLevel,
        "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
        "Value"=>$Var,
        "Key"=>$Var,
        "Destination"=>"Param",
        "MustConvert"=>0));
    $Type_Init{"Init"} .= $Preamble;
    $Type_Init{"Call"} = $Call;
    # call to constraint
    if($Init_Desc{"TargetTypeId"}==$Init_Desc{"TypeId"}) {
        $Type_Init{"TargetCall"} = $Type_Init{"Call"};
    }
    else
    {
        my ($TargetCall, $TargetPreamble) =
        convertTypes((
            "InputTypeName"=>$InitializedType_Name,
            "InputPointerLevel"=>$InitializedType_PLevel,
            "OutputTypeId"=>$Init_Desc{"TargetTypeId"},
            "Value"=>$Var,
            "Key"=>$Var,
            "Destination"=>"Target",
            "MustConvert"=>0));
        $Type_Init{"TargetCall"} = $TargetCall;
        $Type_Init{"Init"} .= $TargetPreamble;
    }
    $Type_Init{"IsCorrect"} = 1;
    return %Type_Init;
}

sub initializeByValue(@)
{
    my %Init_Desc = @_;
    return () if($Init_Desc{"DoNotAssembly"} and $Init_Desc{"ByNull"});
    my %Type_Init = ();
    $Init_Desc{"InLine"} = 1 if($Init_Desc{"Value"}=~/\$\d+/);
    my $TName_Trivial = get_TypeName($Init_Desc{"TypeId"});
    $TName_Trivial=~s/&//g;
    my $FoundationType_Id = get_FoundationTypeId($Init_Desc{"TypeId"});
    # $Type_Init{"Headers"} = addHeaders(getTypeHeaders($FoundationType_Id), $Type_Init{"Headers"});
    $Type_Init{"Headers"} = addHeaders(getTypeHeaders($Init_Desc{"TypeId"}), $Type_Init{"Headers"});
    if(uncover_typedefs(get_TypeName($Init_Desc{"TypeId"}))=~/\&/
    and $Init_Desc{"OuterType_Type"}=~/\A(Struct|Union|Array)\Z/) {
        $Init_Desc{"InLine"} = 0;
    }
    my $FoundationType_Name = get_TypeName($FoundationType_Id);
    my $FoundationType_Type = get_TypeType($FoundationType_Id);
    my $PointerLevel = get_PointerLevel($Init_Desc{"TypeId"});
    my $Target_PointerLevel = get_PointerLevel($Init_Desc{"TargetTypeId"});
    if($FoundationType_Name eq "...")
    {
        $PointerLevel = get_PointerLevel($Init_Desc{"ValueTypeId"});
        $Target_PointerLevel = $PointerLevel;
    }
    my $Value_PointerLevel = get_PointerLevel($Init_Desc{"ValueTypeId"});
    return () if(not $Init_Desc{"ValueTypeId"} or $Init_Desc{"Value"} eq "");
    $Init_Desc{"Var"} = select_var_name($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ParamNameExt"});
    my $Var = $Init_Desc{"Var"};
    my ($Value_ETypeId, $Declarations, $Headers) = get_ExtTypeId($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ValueTypeId"});
    my $Value_ETypeName = get_TypeName($Value_ETypeId);
    $Type_Init{"Code"} .= $Declarations;
    $Type_Init{"Headers"} = addHeaders($Headers, $Type_Init{"Headers"});
    if($FoundationType_Type eq "Class")
    { # classes
        my ($ChildCreated, $CallDestructor) = (0, 1);
        if(my $ValueClass = getValueClass($Init_Desc{"Value"}) and $Target_PointerLevel eq 0)
        { # class object construction by constructor in value
            if($FoundationType_Name eq $ValueClass)
            {
                if(isAbstractClass($FoundationType_Id) or $Init_Desc{"CreateChild"})
                { # when don't know constructor in value, so declaring all in the child
                    my $ChildClassName = getSubClassName($FoundationType_Name);
                    my $FoundationChildName = getSubClassName($FoundationType_Name);
                    $ChildCreated = 1;
                    if($Init_Desc{"Value"}=~/\Q$FoundationType_Name\E/
                    and $Init_Desc{"Value"}!~/\Q$ChildClassName\E/) {
                        substr($Init_Desc{"Value"}, index($Init_Desc{"Value"}, $FoundationType_Name), pos($FoundationType_Name) + length($FoundationType_Name)) = $FoundationChildName;
                    }
                    $IntSubClass{$TestedInterface}{$FoundationType_Id} = 1;
                    $Create_SubClass{$FoundationType_Id} = 1;
                    foreach my $ClassConstructor (getClassConstructors($FoundationType_Id)) {
                        $UsedConstructors{$FoundationType_Id}{$ClassConstructor} = 1;
                    }
                    $FoundationType_Name = $ChildClassName;
                }
            }
            else
            { # new class
                $FoundationType_Name = $ValueClass;
            }
            if($Init_Desc{"InLine"} and ($PointerLevel eq 0))
            {
                $Type_Init{"Call"} = $Init_Desc{"Value"};
                $CallDestructor = 0;
            }
            else
            {
                $Block_Variable{$CurrentBlock}{$Var} = 1;
                if(not defined $DisableReuse) {
                    $ValueCollection{$CurrentBlock}{$Var} = $FoundationType_Id;
                }
                $Type_Init{"Init"} .= $FoundationType_Name." $Var = ".$Init_Desc{"Value"}.";".($Init_Desc{"ByNull"}?" //can't initialize":"")."\n";
                $Type_Init{"Headers"} = addHeaders(getTypeHeaders($FoundationType_Id), $Type_Init{"Headers"});
                $Type_Init{"Init"} = correct_init_stmt($Type_Init{"Init"}, $FoundationType_Name, $Var);
                my ($Call, $TmpPreamble) =
                convertTypes((
                    "InputTypeName"=>$FoundationType_Name,
                    "InputPointerLevel"=>$Value_PointerLevel,
                    "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
                    "Value"=>$Var,
                    "Key"=>$Var,
                    "Destination"=>"Param",
                    "MustConvert"=>0));
                $Type_Init{"Init"} .= $TmpPreamble;
                $Type_Init{"Call"} = $Call;
            }
        }
        else
        { # class object returned by some interface in value
            if($Init_Desc{"CreateChild"})
            {
                $ChildCreated = 1;
                my $FoundationChildName = getSubClassName($FoundationType_Name);
                my $TNameChild = $TName_Trivial;
                substr($Value_ETypeName, index($Value_ETypeName, $FoundationType_Name), pos($FoundationType_Name) + length($FoundationType_Name)) = $FoundationChildName;
                substr($TNameChild, index($TNameChild, $FoundationType_Name), pos($FoundationType_Name) + length($FoundationType_Name)) = $FoundationChildName;
                $IntSubClass{$TestedInterface}{$FoundationType_Id} = 1;
                $Create_SubClass{$FoundationType_Id} = 1;
                if($Value_PointerLevel==0
                and my $SomeConstructor = getSomeConstructor($FoundationType_Id)) {
                    $UsedConstructors{$FoundationType_Id}{$SomeConstructor} = 1;
                }
                if($Init_Desc{"InLine"} and ($PointerLevel eq $Value_PointerLevel))
                {
                    if($Init_Desc{"Value"} eq "NULL"
                    or $Init_Desc{"Value"} eq "0") {
                        $Type_Init{"Call"} = "($TNameChild) ".$Init_Desc{"Value"};
                    }
                    else
                    {
                        my ($Call, $TmpPreamble) =
                        convertTypes((
                            "InputTypeName"=>get_TypeName($Init_Desc{"ValueTypeId"}),
                            "InputPointerLevel"=>$Value_PointerLevel,
                            "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
                            "Value"=>$Init_Desc{"Value"},
                            "Key"=>$LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"},
                            "Destination"=>"Param",
                            "MustConvert"=>1));
                        $Type_Init{"Call"} = $Call;
                        $Type_Init{"Init"} .= $TmpPreamble;
                    }
                    $CallDestructor = 0;
                }
                else
                {
                    $Block_Variable{$CurrentBlock}{$Var} = 1;
                    if((not defined $DisableReuse and ($Init_Desc{"Value"} ne "NULL") and ($Init_Desc{"Value"} ne "0"))
                    or $Init_Desc{"ByNull"} or $Init_Desc{"UseableValue"}) {
                        $ValueCollection{$CurrentBlock}{$Var} = $Value_ETypeId;
                    }
                    $Type_Init{"Init"} .= $Value_ETypeName." $Var = ($Value_ETypeName)".$Init_Desc{"Value"}.";".($Init_Desc{"ByNull"}?" //can't initialize":"")."\n";
                    $Type_Init{"Headers"} = addHeaders(getTypeHeaders($Value_ETypeId), $Type_Init{"Headers"});
                    my ($Call, $TmpPreamble) =
                    convertTypes((
                        "InputTypeName"=>$Value_ETypeName,
                        "InputPointerLevel"=>$Value_PointerLevel,
                        "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
                        "Value"=>$Var,
                        "Key"=>$Var,
                        "Destination"=>"Param",
                        "MustConvert"=>0));
                    $Type_Init{"Init"} .= $TmpPreamble;
                    $Type_Init{"Call"} = $Call;
                }
            }
            else
            {
                if($Init_Desc{"InLine"} and $PointerLevel eq $Value_PointerLevel)
                {
                    if($Init_Desc{"Value"} eq "NULL"
                    or $Init_Desc{"Value"} eq "0") {
                        $Type_Init{"Call"} = "($TName_Trivial) ".$Init_Desc{"Value"};
                        $CallDestructor = 0;
                    }
                    else
                    {
                        $CallDestructor = 0;
                        my ($Call, $TmpPreamble) =
                        convertTypes((
                            "InputTypeName"=>get_TypeName($Init_Desc{"ValueTypeId"}),
                            "InputPointerLevel"=>$Value_PointerLevel,
                            "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
                            "Value"=>$Init_Desc{"Value"},
                            "Key"=>$LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"},
                            "Destination"=>"Param",
                            "MustConvert"=>1));
                        $Type_Init{"Call"} = $Call;
                        $Type_Init{"Init"} .= $TmpPreamble;
                    }
                }
                else
                {
                    $Block_Variable{$CurrentBlock}{$Var} = 1;
                    if((not defined $DisableReuse and $Init_Desc{"Value"} ne "NULL" and $Init_Desc{"Value"} ne "0")
                    or $Init_Desc{"ByNull"} or $Init_Desc{"UseableValue"}) {
                        $ValueCollection{$CurrentBlock}{$Var} = $Value_ETypeId;
                    }
                    $Type_Init{"Init"} .= $Value_ETypeName." $Var = ".$Init_Desc{"Value"}.";".($Init_Desc{"ByNull"}?" //can't initialize":"")."\n";
                    $Type_Init{"Headers"} = addHeaders(getTypeHeaders($Value_ETypeId), $Type_Init{"Headers"});
                    my ($Call, $TmpPreamble) =
                    convertTypes((
                        "InputTypeName"=>$Value_ETypeName,
                        "InputPointerLevel"=>$Value_PointerLevel,
                        "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
                        "Value"=>$Var,
                        "Key"=>$Var,
                        "Destination"=>"Param",
                        "MustConvert"=>0));
                    $Type_Init{"Init"} .= $TmpPreamble;
                    $Type_Init{"Call"} = $Call;
                }
            }
        }
        
        # create destructor call for class object
        if($CallDestructor and
        ((has_public_destructor($FoundationType_Id, "D2") and $ChildCreated) or
        (has_public_destructor($FoundationType_Id, "D0") and not $ChildCreated)) )
        {
            if($Value_PointerLevel > 0)
            {
                if($Value_PointerLevel eq 1) {
                    $Type_Init{"Destructors"} .= "delete($Var);\n";
                }
                else
                {
                    $Type_Init{"Destructors"} .= "delete(";
                    foreach (0 .. $Value_PointerLevel - 2) {
                        $Type_Init{"Destructors"} .= "*";
                    }
                    $Type_Init{"Destructors"} .= $Var.");\n";
                }
            }
        }
    }
    else
    { # intrinsics, structs
        if($Init_Desc{"InLine"} and ($PointerLevel eq $Value_PointerLevel))
        {
            if(($Init_Desc{"Value"} eq "NULL") or ($Init_Desc{"Value"} eq "0"))
            {
                if((getSymLang($TestedInterface) eq "C++" or $Init_Desc{"StrongConvert"})
                and isValidConv($TName_Trivial) and ($Init_Desc{"OuterType_Type"} ne "Array"))
                {
                    $Type_Init{"Call"} = "($TName_Trivial) ".$Init_Desc{"Value"};
                }
                else
                {
                    $Type_Init{"Call"} = $Init_Desc{"Value"};
                }
            }
            else
            {
                if((not is_equal_types(get_TypeName($Init_Desc{"TypeId"}), get_TypeName($Init_Desc{"ValueTypeId"})) or $Init_Desc{"StrongConvert"}) and isValidConv($TName_Trivial))
                {
                    $Type_Init{"Call"} = "($TName_Trivial) ".$Init_Desc{"Value"};
                }
                else
                {
                    $Type_Init{"Call"} = $Init_Desc{"Value"};
                }
            }
        }
        else
        {
            $Block_Variable{$CurrentBlock}{$Var} = 1;
            if((not defined $DisableReuse and ($Init_Desc{"Value"} ne "NULL") and ($Init_Desc{"Value"} ne "0"))
            or $Init_Desc{"ByNull"} or $Init_Desc{"UseableValue"})
            {
                $ValueCollection{$CurrentBlock}{$Var} = $Value_ETypeId;
            }
            $Type_Init{"Init"} .= $Value_ETypeName." $Var = ".$Init_Desc{"Value"}.";".($Init_Desc{"ByNull"}?" //can't initialize":"")."\n";
            $Type_Init{"Headers"} = addHeaders(getTypeHeaders($Value_ETypeId), $Type_Init{"Headers"});
            my ($Call, $TmpPreamble) =
            convertTypes((
                "InputTypeName"=>$Value_ETypeName,
                "InputPointerLevel"=>$Value_PointerLevel,
                "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
                "Value"=>$Var,
                "Key"=>$Var,
                "Destination"=>"Param",
                "MustConvert"=>$Init_Desc{"StrongConvert"}));
            $Type_Init{"Init"} .= $TmpPreamble;
            $Type_Init{"Call"} = $Call;
        }
    }
    # call to constraint
    if($Init_Desc{"TargetTypeId"}==$Init_Desc{"TypeId"})
    {
        $Type_Init{"TargetCall"} = $Type_Init{"Call"};
    }
    else
    {
        my ($TargetCall, $TargetPreamble) =
        convertTypes((
            "InputTypeName"=>$Value_ETypeName,
            "InputPointerLevel"=>$Value_PointerLevel,
            "OutputTypeId"=>$Init_Desc{"TargetTypeId"},
            "Value"=>$Var,
            "Key"=>$Var,
            "Destination"=>"Target",
            "MustConvert"=>0));
        $Type_Init{"TargetCall"} = $TargetCall;
        $Type_Init{"Init"} .= $TargetPreamble;
    }
    if(get_TypeType($Init_Desc{"TypeId"}) eq "Ref")
    { # ref handler
        my $BaseRefId = get_OneStep_BaseTypeId($Init_Desc{"TypeId"});
        my $BaseRefName = get_TypeName($BaseRefId);
        if(get_PointerLevel($BaseRefId) > $Value_PointerLevel)
        {
            $Type_Init{"Init"} .= $BaseRefName." ".$Var."_ref = ".$Type_Init{"Call"}.";\n";
            $Type_Init{"Call"} = $Var."_ref";
            $Block_Variable{$CurrentBlock}{$Var."_ref"} = 1;
            if(not defined $DisableReuse and ($Init_Desc{"Value"} ne "NULL") and ($Init_Desc{"Value"} ne "0"))
            {
                $ValueCollection{$CurrentBlock}{$Var."_ref"} = $Init_Desc{"TypeId"};
            }
        }
    }
    $Type_Init{"Code"} = $Type_Init{"Code"};
    $Type_Init{"IsCorrect"} = 1;
    $Type_Init{"ByNull"} = 1 if($Init_Desc{"ByNull"});
    return %Type_Init;
}

sub remove_quals($)
{
    my $Type_Name = $_[0];
    $Type_Name=~s/ (const|volatile|restrict)\Z//g;
    $Type_Name=~s/\A(const|volatile|restrict) //g;
    while($Type_Name=~s/(\W|\A|>)(const|volatile|restrict)(\W([^<>()]+|)|)\Z/$1$3/g){};
    return formatName($Type_Name, "T");
}

sub is_equal_types($$)
{
    my ($Type1_Name, $Type2_Name) = @_;
    return (remove_quals(uncover_typedefs($Type1_Name)) eq
            remove_quals(uncover_typedefs($Type2_Name)));
}

sub get_base_type_name($)
{
    my $Type_Name = $_[0];
    while($Type_Name=~s/(\*|\&)([^<>()]+|)\Z/$2/g){};
    my $Type_Name = remove_quals(uncover_typedefs($Type_Name));
    while($Type_Name=~s/(\*|\&)([^<>()]+|)\Z/$2/g){};
    return $Type_Name;
}

sub isIntegerType($)
{
    my $TName = remove_quals(uncover_typedefs($_[0]));
    return 0 if($TName=~/[(<*]/);
    if($TName eq "bool")
    {
        return (getSymLang($TestedInterface) ne "C++");
    }
    return ($TName=~/(\W|\A| )(int)(\W|\Z| )/
    or $TName=~/\A(short|size_t|unsigned|long|long long|unsigned long|unsigned long long|unsigned short)\Z/);
}

sub isCharType($)
{
    my $TName = remove_quals(uncover_typedefs($_[0]));
    return 0 if($TName=~/[(<*]/);
    return ($TName=~/\A(char|unsigned char|signed char|wchar_t)\Z/);
}

sub isNumericType($)
{
    my $TName = uncover_typedefs($_[0]);
    return 0 if($TName=~/[(<*]/);
    if(isIntegerType($TName))
    {
        return 1;
    }
    else
    {
        return ($TName=~/\A(float|double|long double|float const|double const|long double const)\Z/);
    }
}

sub getIntrinsicValue($)
{
    my $TypeName = $_[0];
    $IntrinsicNum{"Char"}=64 if($IntrinsicNum{"Char"}>89 or $IntrinsicNum{"Char"}<64);
    $IntrinsicNum{"Int"}=0 if($IntrinsicNum{"Int"} >= 10);
    if($RandomCode)
    {
        $IntrinsicNum{"Char"} = 64+int(rand(25));
        $IntrinsicNum{"Int"} = int(rand(5));
    }
    if($TypeName eq "char*")
    {
        $IntrinsicNum{"Str"}+=1;
        if($IntrinsicNum{"Str"}==1)
        {
            return "\"str\"";
        }
        else
        {
            return "\"str".$IntrinsicNum{"Str"}."\"";
        }
    }
    elsif($TypeName=~/(\A| )char(\Z| )/)
    {
        $IntrinsicNum{"Char"} += 1;
        return "'".chr($IntrinsicNum{"Char"})."'";
    }
    elsif($TypeName eq "wchar_t")
    {
        $IntrinsicNum{"Char"}+=1;
        return "L'".chr($IntrinsicNum{"Char"})."'";
    }
    elsif($TypeName eq "wchar_t*")
    {
        $IntrinsicNum{"Str"}+=1;
        if($IntrinsicNum{"Str"}==1)
        {
            return "L\"str\"";
        }
        else
        {
            return "L\"str".$IntrinsicNum{"Str"}."\"";
        }
    }
    elsif($TypeName eq "wint_t")
    {
        $IntrinsicNum{"Int"}+=1;
        return "L".$IntrinsicNum{"Int"};
    }
    elsif($TypeName=~/\A(long|long int)\Z/)
    {
        $IntrinsicNum{"Int"} += 1;
        return $IntrinsicNum{"Int"}."L";
    }
    elsif($TypeName=~/\A(long long|long long int)\Z/)
    {
        $IntrinsicNum{"Int"} += 1;
        return $IntrinsicNum{"Int"}."LL";
    }
    elsif(isIntegerType($TypeName))
    {
        $IntrinsicNum{"Int"} += 1;
        return $IntrinsicNum{"Int"};
    }
    elsif($TypeName eq "float")
    {
        $IntrinsicNum{"Float"} += 1;
        return $IntrinsicNum{"Float"}.".5f";
    }
    elsif($TypeName eq "double")
    {
        $IntrinsicNum{"Float"} += 1;
        return $IntrinsicNum{"Float"}.".5";
    }
    elsif($TypeName eq "long double")
    {
        $IntrinsicNum{"Float"} += 1;
        return $IntrinsicNum{"Float"}.".5L";
    }
    elsif($TypeName eq "bool")
    {
        if(getSymLang($TestedInterface) eq "C++") {
            return "true";
        }
        else {
            return "1";
        }
    }
    else
    { # void, "..." and other
        return "";
    }
}

sub findInterface_OutParam($$$$$$)
{
    my ($TypeId, $Key, $StrongTypeCompliance, $Var, $ParamName, $Strong) = @_;
    return () if(not $TypeId);
    foreach my $FamilyTypeId (get_OutParamFamily($TypeId, 1))
    {
        foreach my $Interface (get_CompatibleInterfaces($FamilyTypeId, "OutParam", $ParamName))
        { # find interface to create some type in the family as output parameter
            if($Strong)
            {
                foreach my $PPos (keys(%{$CompleteSignature{$Interface}{"Param"}}))
                { # only one possible structural out parameter
                    my $PTypeId = $CompleteSignature{$Interface}{"Param"}{$PPos}{"type"};
                    my $P_FTypeId = get_FoundationTypeId($PTypeId);
                    return () if(get_TypeType($P_FTypeId)!~/\A(Intrinsic|Enum)\Z/
                    and $P_FTypeId ne get_FoundationTypeId($FamilyTypeId)
                    and not is_const_type(get_TypeName($PTypeId)));
                }
            }
            my $OutParam_Pos = $OutParam_Interface{$FamilyTypeId}{$Interface};
            my %Interface_Init = callInterface((
                "Interface"=>$Interface, 
                "Key"=>$Key, 
                "OutParam"=>$OutParam_Pos,
                "OutVar"=>$Var));
            if($Interface_Init{"IsCorrect"})
            {
                $Interface_Init{"Interface"} = $Interface;
                $Interface_Init{"OutParamPos"} = $OutParam_Pos;
                return %Interface_Init;
            }
        }
    }
    return ();
}

sub findInterface(@)
{
    my %Init_Desc = @_;
    my ($TypeId, $Key, $StrongTypeCompliance, $ParamName) = ($Init_Desc{"TypeId"}, $Init_Desc{"Key"}, $Init_Desc{"StrongTypeCompliance"}, $Init_Desc{"ParamName"});
    return () if(not $TypeId);
    my @FamilyTypes = ();
    if($StrongTypeCompliance)
    {
        @FamilyTypes = ($TypeId);
        # try to initialize basic typedef
        my $BaseTypeId = $TypeId;
        $BaseTypeId = get_OneStep_BaseTypeId($TypeId) if(get_TypeType($BaseTypeId) eq "Const");
        $BaseTypeId = get_OneStep_BaseTypeId($TypeId) if(get_TypeType($BaseTypeId) eq "Pointer");
        if($BaseTypeId ne $TypeId)
        {
            if(get_TypeType($BaseTypeId) eq "Typedef") {
                push(@FamilyTypes, $BaseTypeId);
            }
        }
    }
    else {
        @FamilyTypes = @{familyTypes($TypeId)};
    }
    my @Ints = ();
    foreach my $FamilyTypeId (@FamilyTypes)
    {
        next if((get_PointerLevel($TypeId)<get_PointerLevel($FamilyTypeId)) and $Init_Desc{"OuterType_Type"} eq "Array");
        next if(get_TypeType($TypeId) eq "Class" and get_PointerLevel($FamilyTypeId)==0);
        if($Init_Desc{"OnlyData"}) {
            @Ints = (@Ints, get_CompatibleInterfaces($FamilyTypeId, "OnlyData",
                              $Init_Desc{"Interface"}." ".$ParamName." ".$Init_Desc{"KeyWords"}));
        }
        elsif($Init_Desc{"OnlyReturn"}) {
            @Ints = (@Ints, get_CompatibleInterfaces($FamilyTypeId, "OnlyReturn",
                              $Init_Desc{"Interface"}." ".$ParamName." ".$Init_Desc{"KeyWords"}));
        }
        else {
            @Ints = (@Ints, get_CompatibleInterfaces($FamilyTypeId, "Return",
                              $Init_Desc{"Interface"}." ".$ParamName." ".$Init_Desc{"KeyWords"}));
        }
    }
    sort_byCriteria(\@Ints, "DeleteSmth");
    foreach my $Interface (@Ints)
    { # find interface for returning some type in the family
        my %Interface_Init = callInterface((
            "Interface"=>$Interface, 
            "Key"=>$Key,
            "RetParam"=>$ParamName));
        if($Interface_Init{"IsCorrect"}) {
            $Interface_Init{"Interface"} = $Interface;
            return %Interface_Init;
        }
    }
    return ();
}

sub initializeByInterface_OutParam(@)
{
    my %Init_Desc = @_;
    return () if(not $Init_Desc{"TypeId"});
    my $Global_State = save_state();
    my %Type_Init = ();
    my $FTypeId = get_FoundationTypeId($Init_Desc{"TypeId"});
    my $PointerLevel = get_PointerLevel($Init_Desc{"TypeId"});
    $Init_Desc{"Var"} = select_var_name($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ParamNameExt"});
    my $Var = $Init_Desc{"Var"};
    $Block_Variable{$CurrentBlock}{$Var} = 1;
    my %Interface_Init = findInterface_OutParam($Init_Desc{"TypeId"}, $Init_Desc{"Key"}, $Init_Desc{"StrongTypeCompliance"}, "\@OUT_PARAM\@", $Init_Desc{"ParamName"}, $Init_Desc{"Strong"});
    if(not $Interface_Init{"IsCorrect"})
    {
        restore_state($Global_State);
        return ();
    }
    $Type_Init{"Init"} = $Interface_Init{"Init"};
    $Type_Init{"Destructors"} = $Interface_Init{"Destructors"};
    $Type_Init{"Code"} .= $Interface_Init{"Code"};
    $Type_Init{"Headers"} = addHeaders($Interface_Init{"Headers"}, $Type_Init{"Headers"});
    
    # initialization
    my $OutParam_Pos = $Interface_Init{"OutParamPos"};
    my $OutParam_TypeId = $CompleteSignature{$Interface_Init{"Interface"}}{"Param"}{$OutParam_Pos}{"type"};
    my $PLevel_Out = get_PointerLevel($OutParam_TypeId);
    my ($InitializedEType_Id, $Declarations, $Headers) = get_ExtTypeId($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $OutParam_TypeId);
    my $InitializedType_Name = get_TypeName($InitializedEType_Id);
    $Type_Init{"Code"} .= $Declarations;
    $Type_Init{"Headers"} = addHeaders($Headers, $Type_Init{"Headers"});
    my $InitializedFType_Id = get_FoundationTypeId($OutParam_TypeId);
#     my $InitializedFType_Type = get_TypeType($InitializedFType_Id);
    my $InitializedType_PointerLevel = get_PointerLevel($OutParam_TypeId);
    my $VarNameForReplace = $Var;
    if($PLevel_Out>1 or ($PLevel_Out==1 and not isOpaque($InitializedFType_Id)))
    {
        $OutParam_TypeId = reduce_pointer_level($InitializedEType_Id);
        $InitializedType_Name=get_TypeName($OutParam_TypeId);
        $VarNameForReplace="&".$Var;
        $InitializedType_PointerLevel-=1;
    }
    foreach (keys(%Interface_Init))
    {
        $Interface_Init{$_}=~s/\@OUT_PARAM\@/$VarNameForReplace/g;
        $Interface_Init{$_} = clearSyntax($Interface_Init{$_});
    }
    if(uncover_typedefs($InitializedType_Name)=~/&|\[/ or $PLevel_Out==1)
    {
#         if($InitializedFType_Type eq "Struct")
#         {
#             my %Struct_Desc = %Init_Desc;
#             $Struct_Desc{"TypeId"} = $OutParam_TypeId;
#             $Struct_Desc{"InLine"} = 0;
#             my $Key = $Struct_Desc{"Key"};
#             delete($Block_Variable{$CurrentBlock}{$Var});
#             my %Assembly = assembleStruct(%Struct_Desc);
#             $Block_Variable{$CurrentBlock}{$Var} = 1;
#             $Type_Init{"Init"} .= $Assembly{"Init"};
#             $Type_Init{"Code"} .= $Assembly{"Code"};
#             $Type_Init{"Headers"} = addHeaders($Assembly{"Headers"}, $Type_Init{"Headers"});
#         }
#         else
#         {
        $Type_Init{"Init"} .= $InitializedType_Name." $Var;\n";
        if(get_TypeType($InitializedFType_Id) eq "Struct")
        {
            my %Type = get_Type($InitializedFType_Id);
            foreach my $MemPos (keys(%{$Type{"Memb"}}))
            {
                if($Type{"Memb"}{$MemPos}{"name"}=~/initialized/i
                and isNumericType(get_TypeName($Type{"Memb"}{$MemPos}{"type"})))
                {
                    $Type_Init{"Init"} .= "$Var.initialized = 0;\n";
                    last;
                }
            }
        }
    }
    else
    {
        $Type_Init{"Init"} .= $InitializedType_Name." $Var = ".get_null().";\n";
    }
    if(not defined $DisableReuse)
    {
        $ValueCollection{$CurrentBlock}{$Var} = $OutParam_TypeId;
    }
    $Type_Init{"Init"} .= $Interface_Init{"PreCondition"} if($Interface_Init{"PreCondition"});
    $Type_Init{"Init"} .= $Interface_Init{"Call"}.";\n";
    $Type_Init{"Headers"} = addHeaders(getTypeHeaders($Init_Desc{"TypeId"}), $Type_Init{"Headers"});
    $Type_Init{"Init"} .= $Interface_Init{"PostCondition"} if($Interface_Init{"PostCondition"});
    if($Interface_Init{"FinalCode"})
    {
        $Type_Init{"Init"} .= "//final code\n";
        $Type_Init{"Init"} .= $Interface_Init{"FinalCode"}."\n";
    }
    # create call
    my ($Call, $Preamble) = convertTypes((
        "InputTypeName"=>$InitializedType_Name,
        "InputPointerLevel"=>$InitializedType_PointerLevel,
        "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
        "Value"=>$Var,
        "Key"=>$Var,
        "Destination"=>"Param",
        "MustConvert"=>0));
    $Type_Init{"Init"} .= $Preamble;
    $Type_Init{"Call"} = $Call;
    # create call to constraint
    if($Init_Desc{"TargetTypeId"}==$Init_Desc{"TypeId"})
    {
        $Type_Init{"TargetCall"} = $Type_Init{"Call"};
    }
    else
    {
        my ($TargetCall, $TargetPreamble) = convertTypes((
            "InputTypeName"=>$InitializedType_Name,
            "InputPointerLevel"=>$InitializedType_PointerLevel,
            "OutputTypeId"=>$Init_Desc{"TargetTypeId"},
            "Value"=>$Var,
            "Key"=>$Var,
            "Destination"=>"Target",
            "MustConvert"=>0));
        $Type_Init{"TargetCall"} = $TargetCall;
        $Type_Init{"Init"} .= $TargetPreamble;
    }
    if(get_TypeType($Init_Desc{"TypeId"}) eq "Ref")
    { # ref handler
        my $BaseRefTypeId = get_OneStep_BaseTypeId($Init_Desc{"TypeId"});
        if(get_PointerLevel($BaseRefTypeId) > $InitializedType_PointerLevel)
        {
            my $BaseRefTypeName = get_TypeName($BaseRefTypeId);
            $Type_Init{"Init"} .= $BaseRefTypeName." ".$Var."_ref = ".$Type_Init{"Call"}.";\n";
            $Type_Init{"Call"} = $Var."_ref";
            $Block_Variable{$CurrentBlock}{$Var."_ref"} = 1;
            if(not defined $DisableReuse)
            {
                $ValueCollection{$CurrentBlock}{$Var."_ref"} = $Init_Desc{"TypeId"};
            }
        }
    }
    $Type_Init{"Init"} .= "\n";
    $Type_Init{"IsCorrect"} = 1;
    return %Type_Init;
}

sub declare_funcptr_typedef($$)
{
    my ($Key, $TypeId) = @_;
    return "" if($AuxType{$TypeId} or not $TypeId or not $Key);
    my $TypedefTo = $Key."_type";
    my $Typedef = "typedef ".get_TypeName($TypeId).";\n";
    $Typedef=~s/[ ]*\(\*\)[ ]*/ \(\*$TypedefTo\) /;
    $AuxType{$TypeId} = $TypedefTo;
    $TypeInfo{$TypeId}{"Name_Old"} = get_TypeName($TypeId);
    $TypeInfo{$TypeId}{"Name"} = $AuxType{$TypeId};
    $TName_Tid{$TypedefTo} = $TypeId;
    return $Typedef;
}

sub have_copying_constructor($)
{
    my $ClassId = $_[0];
    return 0 if(not $ClassId);
    foreach my $Constructor (keys(%{$Class_Constructors{$ClassId}}))
    {
        if(keys(%{$CompleteSignature{$Constructor}{"Param"}})==1
        and not $CompleteSignature{$Constructor}{"Protected"})
        {
            my $FirstParamTypeId = $CompleteSignature{$Constructor}{"Param"}{0}{"type"};
            if(get_FoundationTypeId($FirstParamTypeId) eq $ClassId
            and get_PointerLevel($FirstParamTypeId)==0) {
                return 1;
            }
        }
    }
    return 0;
}

sub initializeByInterface(@)
{
    my %Init_Desc = @_;
    return () if(not $Init_Desc{"TypeId"});
    my $Global_State = save_state();
    my %Type_Init = ();
    my $PointerLevel = get_PointerLevel($Init_Desc{"TypeId"});
    my $FTypeId = get_FoundationTypeId($Init_Desc{"TypeId"});
    if(get_TypeType($FTypeId) eq "Class" and $PointerLevel==0
    and not have_copying_constructor($FTypeId)) {
        return ();
    }
    my %Interface_Init = ();
    if($Init_Desc{"ByInterface"})
    {
        %Interface_Init = callInterface((
          "Interface"=>$Init_Desc{"ByInterface"}, 
          "Key"=>$Init_Desc{"Key"},
          "RetParam"=>$Init_Desc{"ParamName"},
          "OnlyReturn"=>1));
    }
    else {
        %Interface_Init = findInterface(%Init_Desc);
    }
    if(not $Interface_Init{"IsCorrect"})
    {
        restore_state($Global_State);
        return ();
    }
    $Init_Desc{"Var"} = select_var_name($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ParamNameExt"});
    $Type_Init{"Init"} = $Interface_Init{"Init"};
    $Type_Init{"Destructors"} = $Interface_Init{"Destructors"};
    $Type_Init{"Code"} = $Interface_Init{"Code"};
    $Type_Init{"Headers"} = addHeaders($Interface_Init{"Headers"}, $Type_Init{"Headers"});
    if(keys(%{$CompleteSignature{$Interface_Init{"Interface"}}{"Param"}})>$MAX_PARAMS_INLINE) {
        $Init_Desc{"InLine"} = 0;
    }
    # initialization
    my $ReturnType_PointerLevel = get_PointerLevel($Interface_Init{"ReturnTypeId"});
    if($ReturnType_PointerLevel==$PointerLevel and $Init_Desc{"InLine"}
    and not $Interface_Init{"PreCondition"} and not $Interface_Init{"PostCondition"}
    and not $Interface_Init{"ReturnFinalCode"})
    {
        my ($Call, $Preamble) = convertTypes((
            "InputTypeName"=>get_TypeName($Interface_Init{"ReturnTypeId"}),
            "InputPointerLevel"=>$ReturnType_PointerLevel,
            "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
            "Value"=>$Interface_Init{"Call"},
            "Key"=>$Init_Desc{"Var"},
            "Destination"=>"Param",
            "MustConvert"=>0));
        $Type_Init{"Init"} .= $Preamble;
        $Type_Init{"Call"} = $Call;
        $Type_Init{"TypeName"} = get_TypeName($Interface_Init{"ReturnTypeId"});
    }
    else
    {
        my $Var = $Init_Desc{"Var"};
        $Block_Variable{$CurrentBlock}{$Var} = 1;
        my ($InitializedEType_Id, $Declarations, $Headers) = get_ExtTypeId($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Interface_Init{"ReturnTypeId"});
        my $InitializedType_Name = get_TypeName($InitializedEType_Id);
        $Type_Init{"TypeName"} = $InitializedType_Name;
        $Type_Init{"Code"} .= $Declarations;
        $Type_Init{"Headers"} = addHeaders($Headers, $Type_Init{"Headers"});
        my %ReturnType = get_Type($Interface_Init{"ReturnTypeId"});
        if(not defined $DisableReuse) {
            $ValueCollection{$CurrentBlock}{$Var} = $Interface_Init{"ReturnTypeId"};
        }
        $Type_Init{"Init"} .= $Interface_Init{"PreCondition"} if($Interface_Init{"PreCondition"});
        if(($InitializedType_Name eq $ReturnType{"Name"})) {
            $Type_Init{"Init"} .= $InitializedType_Name." $Var = ".$Interface_Init{"Call"}.";\n";
        }
        else {
            $Type_Init{"Init"} .= $InitializedType_Name." $Var = "."(".$InitializedType_Name.")".$Interface_Init{"Call"}.";\n";
        }
        if($Interface_Init{"Interface"} eq "fopen") {
            $OpenStreams{$CurrentBlock}{$Var} = 1;
        }
        # create call
        my ($Call, $Preamble) = convertTypes((
            "InputTypeName"=>$InitializedType_Name,
            "InputPointerLevel"=>$ReturnType_PointerLevel,
            "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
            "Value"=>$Var,
            "Key"=>$Var,
            "Destination"=>"Param",
            "MustConvert"=>0));
        $Type_Init{"Init"} .= $Preamble;
        $Type_Init{"Call"} = $Call;
        # create call to constraint
        if($Init_Desc{"TargetTypeId"}==$Init_Desc{"TypeId"}) {
            $Type_Init{"TargetCall"} = $Type_Init{"Call"};
        }
        else
        {
            my ($TargetCall, $TargetPreamble) = convertTypes((
                "InputTypeName"=>$InitializedType_Name,
                "InputPointerLevel"=>$ReturnType_PointerLevel,
                "OutputTypeId"=>$Init_Desc{"TargetTypeId"},
                "Value"=>$Var,
                "Key"=>$Var,
                "Destination"=>"Target",
                "MustConvert"=>0));
            $Type_Init{"TargetCall"} = $TargetCall;
            $Type_Init{"Init"} .= $TargetPreamble;
        }
        if(get_TypeType($Init_Desc{"TypeId"}) eq "Ref")
        { # ref handler
            my $BaseRefTypeId = get_OneStep_BaseTypeId($Init_Desc{"TypeId"});
            if(get_PointerLevel($BaseRefTypeId) > $ReturnType_PointerLevel)
            {
                my $BaseRefTypeName = get_TypeName($BaseRefTypeId);
                $Type_Init{"Init"} .= $BaseRefTypeName." ".$Var."_ref = ".$Type_Init{"Call"}.";\n";
                $Type_Init{"Call"} = $Var."_ref";
                $Block_Variable{$CurrentBlock}{$Var."_ref"} = 1;
                if(not defined $DisableReuse)
                {
                    $ValueCollection{$CurrentBlock}{$Var."_ref"} = $Init_Desc{"TypeId"};
                }
            }
        }
        if($Interface_Init{"ReturnRequirement"})
        {
            $Interface_Init{"ReturnRequirement"}=~s/(\$0|\$retval)/$Var/gi;
            $Type_Init{"Init"} .= $Interface_Init{"ReturnRequirement"};
        }
        if($Interface_Init{"ReturnFinalCode"})
        {
            $Interface_Init{"ReturnFinalCode"}=~s/(\$0|\$retval)/$Var/gi;
            $Type_Init{"Init"} .= "//final code\n";
            $Type_Init{"Init"} .= $Interface_Init{"ReturnFinalCode"}."\n";
        }
    }
    $Type_Init{"Init"} .= $Interface_Init{"PostCondition"} if($Interface_Init{"PostCondition"});
    if($Interface_Init{"FinalCode"})
    {
        $Type_Init{"Init"} .= "//final code\n";
        $Type_Init{"Init"} .= $Interface_Init{"FinalCode"}."\n";
    }
    
    $Type_Init{"IsCorrect"} = 1;
    return %Type_Init;
}

sub initializeFuncPtr(@)
{
    my %Init_Desc = @_;
    my %Type_Init = initializeByInterface(%Init_Desc);
    if($Type_Init{"IsCorrect"}) {
        return %Type_Init;
    }
    else {
        return assembleFuncPtr(%Init_Desc);
    }
}

sub get_OneStep_BaseTypeId($)
{
    my $TypeId = $_[0];
    my %Type = %{$TypeInfo{$TypeId}};
    if(defined $Type{"BaseType"}
    and $Type{"BaseType"}) {
        return $Type{"BaseType"};
    }
    else {
        return $Type{"Tid"};
    }
}

sub initializeArray(@)
{
    my %Init_Desc = @_;
    if($Init_Desc{"TypeType_Changed"})
    {
        my %Type_Init = assembleArray(%Init_Desc);
        if($Type_Init{"IsCorrect"}) {
            return %Type_Init;
        }
        else
        { # failed to initialize as "array"
            if(my $FTId = get_FoundationTypeId($Init_Desc{"TypeId"}))
            {
                my $FType = get_TypeType($FTId);
                if($FType ne "Array")
                {
                    $Init_Desc{"FoundationType_Type"} = $FType;
                    return selectInitializingWay(%Init_Desc);
                }
            }
            return ();
        }
    }
    else
    {
        $Init_Desc{"StrongTypeCompliance"} = 1;
        my %Type_Init = initializeByInterface(%Init_Desc);
        if($Type_Init{"IsCorrect"}) {
            return %Type_Init;
        }
        else
        {
            %Type_Init = initializeByInterface_OutParam(%Init_Desc);
            if($Type_Init{"IsCorrect"}) {
                return %Type_Init;
            }
            else
            {
                $Init_Desc{"StrongTypeCompliance"} = 0;
                return assembleArray(%Init_Desc);
            }
        }
    }
}

sub get_PureType($)
{
    my $TypeId = $_[0];
    return () if(not $TypeId);
    if(defined $Cache{"get_PureType"}{$TypeId}
    and not defined $AuxType{$TypeId}) {
        return %{$Cache{"get_PureType"}{$TypeId}};
    }
    return () if(not $TypeInfo{$TypeId});
    my %Type = %{$TypeInfo{$TypeId}};
    return %Type if(not $Type{"BaseType"});
    if($Type{"Type"}=~/\A(Ref|Const|Volatile|Restrict|Typedef)\Z/) {
        %Type = get_PureType($Type{"BaseType"});
    }
    $Cache{"get_PureType"}{$TypeId} = \%Type;
    return %Type;
}

sub delete_quals($)
{
    my $TypeId = $_[0];
    return () if(not $TypeId);
    if(defined $Cache{"delete_quals"}{$TypeId}
    and not defined $AuxType{$TypeId}) {
        return %{$Cache{"delete_quals"}{$TypeId}};
    }
    return () if(not $TypeInfo{$TypeId});
    my %Type = %{$TypeInfo{$TypeId}};
    return %Type if(not $Type{"BaseType"});
    if($Type{"Type"}=~/\A(Ref|Const|Volatile|Restrict)\Z/) {
        %Type = delete_quals($Type{"BaseType"});
    }
    $Cache{"delete_quals"}{$TypeId} = \%Type;
    return %Type;
}

sub goToFirst($$)
{
    my ($TypeId, $Type_Type) = @_;
    if(defined $Cache{"goToFirst"}{$TypeId}{$Type_Type}
    and not defined $AuxType{$TypeId}) {
        return %{$Cache{"goToFirst"}{$TypeId}{$Type_Type}};
    }
    return () if(not $TypeInfo{$TypeId});
    my %Type = %{$TypeInfo{$TypeId}};
    return () if(not $Type{"Type"});
    if($Type{"Type"} ne $Type_Type)
    {
        return () if(not $Type{"BaseType"});
        %Type = goToFirst($Type{"BaseType"}, $Type_Type);
    }
    $Cache{"goToFirst"}{$TypeId}{$Type_Type} = \%Type;
    return %Type;
}

sub detectArrayTypeId($)
{
    my $TypeId = $_[0];
    my $ArrayType_Id = get_FoundationTypeId($TypeId);
    my $PointerLevel = get_PointerLevel($TypeId);
    if(get_TypeType($ArrayType_Id) eq "Array")# and $PointerLevel==0
    {
        return $ArrayType_Id;
    }
    else
    { # this branch for types like arrays (char* like char[])
        my %Type = get_PureType($TypeId);
        return $Type{"Tid"};
    }
}

sub assembleArray(@)
{
    my %Init_Desc = @_;
    my %Type_Init = ();
    my $Global_State = save_state();
    my $PointerLevel = get_PointerLevel($Init_Desc{"TypeId"});
    my %Type = get_Type($Init_Desc{"TypeId"});
    # determine array base
    my $ArrayType_Id = detectArrayTypeId($Init_Desc{"TypeId"});
    my %ArrayType = get_Type($ArrayType_Id);
    my $AmountArray = ($ArrayType{"Type"} eq "Array")?$ArrayType{"Count"}:(($Init_Desc{"ArraySize"})?$Init_Desc{"ArraySize"}:$DEFAULT_ARRAY_AMOUNT);
    if($AmountArray>1024)
    { # such too long arrays should be initialized by other methods
        restore_state($Global_State);
        return ();
    }
    # array base type attributes
    my $ArrayElemType_Id = get_OneStep_BaseTypeId($ArrayType_Id);
    my $ArrayElemType_Name = remove_quals(get_TypeName($ArrayElemType_Id));
    my $ArrayElemType_PLevel = get_PointerLevel($ArrayElemType_Id);
    my $ArrayElemFType_Id = get_FoundationTypeId($ArrayElemType_Id);
    my $IsInlineDef = (($ArrayType{"Type"} eq "Array") and $PointerLevel==0 and ($Type{"Type"} ne "Ref") and $Init_Desc{"InLine"} or $Init_Desc{"InLineArray"});
    $Init_Desc{"Var"} = select_var_name($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ParamNameExt"});
    my $Var = $Init_Desc{"Var"};
    if(not $IsInlineDef) {
        $Block_Variable{$CurrentBlock}{$Var} = 1;
    }
    if(not isCharType(get_TypeName($ArrayElemFType_Id)) and not $IsInlineDef)
    {
        my ($ExtTypeId, $Declarations, $Headers) = get_ExtTypeId($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $ArrayElemType_Id);
        $ArrayElemType_Id = $ExtTypeId;
        $Type_Init{"Code"} .= $Declarations;
        $Type_Init{"Headers"} = addHeaders($Headers, $Type_Init{"Headers"});
    }
    my @ElemStr = ();
    foreach my $Elem_Pos (1 .. $AmountArray)
    { # initialize array members
        my $ElemName = "";
        if(isCharType(get_TypeName($ArrayElemFType_Id))
        and $ArrayElemType_PLevel==1) {
            $ElemName = $Init_Desc{"ParamName"}."_".$Elem_Pos;
        }
        elsif(my $EName = getParamNameByTypeName($ArrayElemType_Name)) {
            $ElemName = $EName;
        }
        else {
            $ElemName = $Init_Desc{"ParamName"}.((not defined $DisableReuse)?"_elem":"");
            $ElemName=~s/es_elem\Z/e/g;
        }
        my %Elem_Init = initializeParameter((
            "TypeId" => $ArrayElemType_Id,
            "Key" => $Init_Desc{"Key"}."_".$Elem_Pos,
            "InLine" => 1,
            "Value" => "no value",
            "ValueTypeId" => 0,
            "TargetTypeId" => 0,
            "CreateChild" => 0,
            "Usage" => "Common",
            "ParamName" => $ElemName,
            "OuterType_Type" => "Array",
            "Index" => $Elem_Pos-1,
            "InLineArray" => ($ArrayElemType_PLevel==1 and isCharType(get_TypeName($ArrayElemFType_Id)) and $Init_Desc{"ParamName"}=~/text|txt|doc/i)?1:0,
            "IsString" => ($ArrayElemType_PLevel==1 and isCharType(get_TypeName($ArrayElemFType_Id)) and $Init_Desc{"ParamName"}=~/prefixes/i)?1:0 ));
        if(not $Elem_Init{"IsCorrect"} or $Elem_Init{"ByNull"}) {
            restore_state($Global_State);
            return ();
        }
        if($Elem_Pos eq 1) {
            $Type_Init{"Headers"} = addHeaders($Elem_Init{"Headers"}, $Type_Init{"Headers"});
        }
        @ElemStr = (@ElemStr, $Elem_Init{"Call"});
        $Type_Init{"Init"} .= $Elem_Init{"Init"};
        $Type_Init{"Destructors"} .= $Elem_Init{"Destructors"};
        $Type_Init{"Code"} .= $Elem_Init{"Code"};
    }
    if(($ArrayType{"Type"} ne "Array") and not isNumericType($ArrayElemType_Name))
    { # the last array element
        if($ArrayElemType_PLevel==0
        and get_TypeName($ArrayElemFType_Id)=~/\A(char|unsigned char)\Z/) {
            @ElemStr = (@ElemStr, "\'\\0\'");
        }
        elsif($ArrayElemType_PLevel==0
        and is_equal_types($ArrayElemType_Name, "wchar_t")) {
            @ElemStr = (@ElemStr, "L\'\\0\'");
        }
        elsif($ArrayElemType_PLevel>=1) {
            @ElemStr = (@ElemStr, get_null());
        }
        elsif($ArrayElemType_PLevel==0
        and get_TypeType($ArrayElemFType_Id)=~/\A(Struct|Union)\Z/) {
            @ElemStr = (@ElemStr, "($ArrayElemType_Name) "."{0}");
        }
    }
    # initialization
    if($IsInlineDef) {
        $Type_Init{"Call"} = "{".create_matrix(\@ElemStr, "    ")."}";
    }
    else
    {
        if(not defined $DisableReuse) {
            $ValueCollection{$CurrentBlock}{$Var} = $ArrayType_Id;
        }
        # $Type_Init{"Init"} .= "//parameter initialization\n";
        $Type_Init{"Init"} .= $ArrayElemType_Name." $Var [".(($ArrayType{"Type"} eq "Array")?$AmountArray:"")."] = {".create_matrix(\@ElemStr, "    ")."};\n";
        #create call
        my ($Call, $TmpPreamble) =
        convertTypes((
            "InputTypeName"=>formatName($ArrayElemType_Name."*", "T"),
            "InputPointerLevel"=>get_PointerLevel($ArrayType_Id),
            "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
            "Value"=>$Var,
            "Key"=>$Var,
            "Destination"=>"Param",
            "MustConvert"=>0));
        $Type_Init{"Init"} .= $TmpPreamble;
        $Type_Init{"Call"} = $Call;
        # create type
        
        # create call to constraint
        if($Init_Desc{"TargetTypeId"}==$Init_Desc{"TypeId"}) {
            $Type_Init{"TargetCall"} = $Type_Init{"Call"};
        }
        else
        {
            my ($TargetCall, $Target_TmpPreamble) =
            convertTypes((
                "InputTypeName"=>formatName($ArrayElemType_Name."*", "T"),
                "InputPointerLevel"=>get_PointerLevel($ArrayType_Id),
                "OutputTypeId"=>$Init_Desc{"TargetTypeId"},
                "Value"=>$Var,
                "Key"=>$Var,
                "Destination"=>"Target",
                "MustConvert"=>0));
            $Type_Init{"TargetCall"} = $TargetCall;
            $Type_Init{"Init"} .= $Target_TmpPreamble;
        }
        # ref handler
        if($Type{"Type"} eq "Ref")
        {
            my $BaseRefId = get_OneStep_BaseTypeId($Init_Desc{"TypeId"});
            if($ArrayType{"Type"} eq "Pointer" or (get_PointerLevel($BaseRefId) > 0))
            {
                my $BaseRefName = get_TypeName($BaseRefId);
                $Type_Init{"Init"} .= $BaseRefName." ".$Var."_ref = ".$Type_Init{"Call"}.";\n";
                $Type_Init{"Call"} = $Var."_ref";
                $Block_Variable{$CurrentBlock}{$Var."_ref"} = 1;
                if(not defined $DisableReuse) {
                    $ValueCollection{$CurrentBlock}{$Var."_ref"} = $Init_Desc{"TypeId"};
                }
            }
        }
    }
    $Type_Init{"TypeName"} = $ArrayElemType_Name." [".(($ArrayType{"Type"} eq "Array")?$AmountArray:"")."]";
    $Type_Init{"IsCorrect"} = 1;
    return %Type_Init;
}

sub get_null()
{
    if(getSymLang($TestedInterface) eq "C++"
    and $Constants{"NULL"}) {
        return "NULL";
    }
    else {
        return "0";
    }
}

sub create_list($$)
{
    my ($Array, $Spaces) = @_;
    my @Elems = @{$Array};
    my ($MaxLength, $SumLength);
    foreach my $Elem (@Elems)
    {
        $SumLength += length($Elem);
        if(not defined $MaxLength
        or $MaxLength<length($Elem)) {
            $MaxLength = length($Elem);
        }
    }
    if(($#Elems+1>$MAX_PARAMS_INLINE)
    or ($SumLength>$MAX_PARAMS_LENGTH_INLINE and $#Elems>0)
    or join("", @Elems)=~/\n/) {
        return "\n$Spaces".join(",\n$Spaces", @Elems);
    }
    else {
        return join(", ", @Elems);
    }
}

sub create_matrix($$)
{
    my ($Array, $Spaces) = @_;
    my @Elems = @{$Array};
    my $MaxLength;
    foreach my $Elem (@Elems)
    {
        if(length($Elem) > $MATRIX_MAX_ELEM_LENGTH) {
            return create_list($Array, $Spaces);
        }
        if(not defined $MaxLength
        or $MaxLength<length($Elem)) {
            $MaxLength = length($Elem);
        }
    }
    if($#Elems+1 >= $MIN_PARAMS_MATRIX)
    {
        my (@Rows, @Row) = ();
        foreach my $Num (0 .. $#Elems)
        {
            my $Elem = $Elems[$Num];
            if($Num%$MATRIX_WIDTH==0 and $Num!=0)
            {
                push(@Rows, join(", ", @Row));
                @Row = ();
            }
            push(@Row, aligh_str($Elem, $MaxLength));
        }
        push(@Rows, join(", ", @Row)) if($#Row>=0);
        return "\n$Spaces".join(",\n$Spaces", @Rows);
    }
    else {
        return create_list($Array, $Spaces);
    }
}

sub aligh_str($$)
{
    my ($Str, $Length) = @_;
    if(length($Str)<$Length)
    {
        foreach (1 .. $Length - length($Str)) {
            $Str = " ".$Str;
        }
    }
    return $Str;
}

sub findFuncPtr_RealFunc($$)
{
    my ($FuncTypeId, $ParamName) = @_;
    my @AvailableRealFuncs = ();
    foreach my $Interface (sort {length($a)<=>length($b)} sort {$a cmp $b} keys(%{$Func_TypeId{$FuncTypeId}}))
    {
        next if(isCyclical(\@RecurInterface, $Interface));
        if($Symbol_Library{$Interface}
        or $DepSymbol_Library{$Interface}) {
            push(@AvailableRealFuncs, $Interface);
        }
    }
    sort_byCriteria(\@AvailableRealFuncs, "Internal");
    @AvailableRealFuncs = sort {($b=~/\Q$ParamName\E/i)<=>($a=~/\Q$ParamName\E/i)} @AvailableRealFuncs if($ParamName!~/\Ap\d+\Z/);
    sort_byName(\@AvailableRealFuncs, $ParamName, "Interfaces");
    if($#AvailableRealFuncs>=0) {
        return $AvailableRealFuncs[0];
    }
    else {
        return "";
    }
}

sub get_base_typedef($)
{
    my $TypeId = $_[0];
    my %TypeDef = goToFirst($TypeId, "Typedef");
    return 0 if(not $TypeDef{"Type"});
    if(get_PointerLevel($TypeDef{"Tid"})==0) {
        return $TypeDef{"Tid"};
    }
    my $BaseTypeId = get_OneStep_BaseTypeId($TypeDef{"Tid"});
    return get_base_typedef($BaseTypeId);
}

sub assembleFuncPtr(@)
{
    my %Init_Desc = @_;
    my %Type_Init = ();
    my $Global_State = save_state();
    my %Type = get_Type($Init_Desc{"TypeId"});
    my $FuncPtr_TypeId = get_FoundationTypeId($Init_Desc{"TypeId"});
    my %FuncPtrType = get_Type($FuncPtr_TypeId);
    my ($TypeName, $AuxFuncName) = ($FuncPtrType{"Name"}, "");
    if(get_PointerLevel($Init_Desc{"TypeId"})>0)
    {
        if(my $Typedef_Id = get_base_typedef($Init_Desc{"TypeId"})) {
            $TypeName = get_TypeName($Typedef_Id);
        }
        elsif(my $Typedef_Id = get_type_typedef($FuncPtr_TypeId))
        {
            $Type_Init{"Headers"} = addHeaders(getTypeHeaders($Typedef_Id), $Type_Init{"Headers"});
            $TypeName = get_TypeName($Typedef_Id);
        }
        else
        {
            $Type_Init{"Code"} .= declare_funcptr_typedef($Init_Desc{"Key"}, $FuncPtr_TypeId);
            $TypeName = get_TypeName($FuncPtr_TypeId);
        }
    }
    if($FuncPtrType{"Name"} eq "void*(*)(size_t)")
    {
        $Type_Init{"Headers"} = addHeaders(["stdlib.h"], $Type_Init{"Headers"});
        $AuxHeaders{"stdlib.h"} = 1;
        $AuxFuncName = "malloc";
    }
    elsif(my $Interface_FuncPtr = findFuncPtr_RealFunc($FuncPtrType{"FuncTypeId"}, $Init_Desc{"ParamName"}))
    {
        $UsedInterfaces{$Interface_FuncPtr} = 1;
        $Type_Init{"Headers"} = addHeaders([$CompleteSignature{$Interface_FuncPtr}{"Header"}], $Type_Init{"Headers"});
        $AuxFuncName = $CompleteSignature{$Interface_FuncPtr}{"ShortName"};
        if($CompleteSignature{$Interface_FuncPtr}{"NameSpace"}) {
            $AuxFuncName = $CompleteSignature{$Interface_FuncPtr}{"NameSpace"}."::".$AuxFuncName;
        }
    }
    else
    {
        if($AuxFunc{$FuncPtr_TypeId}) {
            $AuxFuncName = $AuxFunc{$FuncPtr_TypeId};
        }
        else
        {
            my @FuncParams = ();
            $AuxFuncName = select_func_name($LongVarNames?$Init_Desc{"Key"}:(($Init_Desc{"ParamName"}=~/\Ap\d+\Z/)?"aux_func":$Init_Desc{"ParamName"}));
            # global
            $AuxFunc{$FuncPtr_TypeId} = $AuxFuncName;
            my $PreviousBlock = $CurrentBlock;
            $CurrentBlock = $AuxFuncName;
            # function declaration
            my $FuncReturnType_Id = $FuncPtrType{"Return"};
            foreach my $ParamPos (sort {int($a)<=>int($b)} keys(%{$FuncPtrType{"Param"}}))
            {
                my $ParamTypeId = $FuncPtrType{"Param"}{$ParamPos}{"type"};
                $Type_Init{"Headers"} = addHeaders(getTypeHeaders($ParamTypeId), $Type_Init{"Headers"});
                my $ParamName = $FuncPtrType{"Param"}{$ParamPos}{"name"};
                $ParamName = "p".($ParamPos+1) if(not $ParamName);
                # my ($ParamEType_Id, $Param_Declarations, $Param_Headers) = get_ExtTypeId($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $ParamTypeId);
                my $ParamTypeName = get_TypeName($ParamTypeId);#get_TypeName($ParamEType_Id);
                # $Type_Init{"Header"} = addHeaders($Param_Headers, $Type_Init{"Header"});
                # $Type_Init{"Code"} .= $Param_Declarations;
                if($ParamTypeName and ($ParamTypeName ne "..."))
                {
                    my $Field = create_member_decl($ParamTypeName, $ParamName);
                    @FuncParams = (@FuncParams, $Field);
                }
                $ValueCollection{$AuxFuncName}{$ParamName} = $ParamTypeId;
                $Block_Param{$AuxFuncName}{$ParamName} = $ParamTypeId;
                $Block_Variable{$CurrentBlock}{$ParamName} = 1;
            }
            # definition of function
            if(get_TypeName($FuncReturnType_Id) eq "void")
            {
                my $FuncDef = "//auxiliary function\n";
                $FuncDef .= "void\n".$AuxFuncName."(".create_list(\@FuncParams, "    ").")";
                if($AuxFuncName=~/free/i)
                {
                    my $PtrParam = "";
                    foreach my $ParamPos (sort {int($a)<=>int($b)} keys(%{$FuncPtrType{"Param"}}))
                    {
                        my $ParamTypeId = $FuncPtrType{"Param"}{$ParamPos}{"type"};
                        my $ParamName = $FuncPtrType{"Param"}{$ParamPos}{"name"};
                        $ParamName = "p".($ParamPos+1) if(not $ParamName);
                        my $ParamFTypeId = get_FoundationTypeId($ParamTypeId);
                        if(get_PointerLevel($ParamTypeId)==1
                        and get_TypeType($ParamFTypeId) eq "Intrinsic")
                        {
                            $PtrParam = $ParamName;
                            last;
                        }
                    }
                    if($PtrParam)
                    {
                        $FuncDef .= "{\n";
                        $FuncDef .= "    free($PtrParam);\n";
                        $FuncDef .= "}\n\n";
                    }
                    else {
                        $FuncDef .= "{}\n\n";
                    }
                }
                else {
                    $FuncDef .= "{}\n\n";
                }
                $Type_Init{"Code"} .= "\n".$FuncDef;
            }
            else
            {
                my %ReturnType_Init = initializeParameter((
                    "TypeId" => $FuncReturnType_Id,
                    "Key" => "retval",
                    "InLine" => 1,
                    "Value" => "no value",
                    "ValueTypeId" => 0,
                    "TargetTypeId" => 0,
                    "CreateChild" => 0,
                    "Usage" => "Common",
                    "RetVal" => 1,
                    "ParamName" => "retval",
                    "FuncPtrTypeId" => $FuncPtr_TypeId),
                    "FuncPtrName" => $AuxFuncName);
                if(not $ReturnType_Init{"IsCorrect"})
                {
                    restore_state($Global_State);
                    $CurrentBlock = $PreviousBlock;
                    return ();
                }
                $ReturnType_Init{"Init"} = alignCode($ReturnType_Init{"Init"}, "    ", 0);
                $ReturnType_Init{"Call"} = alignCode($ReturnType_Init{"Call"}, "    ", 1);
                $Type_Init{"Code"} .= $ReturnType_Init{"Code"};
                $Type_Init{"Headers"} = addHeaders($ReturnType_Init{"Headers"}, $Type_Init{"Headers"});
                my ($FuncReturnEType_Id, $Declarations, $Headers) = get_ExtTypeId($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $FuncReturnType_Id);
                my $FuncReturnType_Name = get_TypeName($FuncReturnEType_Id);
                $Type_Init{"Code"} .= $Declarations;
                $Type_Init{"Headers"} = addHeaders($Headers, $Type_Init{"Headers"});
                my $FuncDef = "//auxiliary function\n";
                $FuncDef .= $FuncReturnType_Name."\n".$AuxFuncName."(".create_list(\@FuncParams, "    ").")";
                $FuncDef .= "{\n";
                $FuncDef .= $ReturnType_Init{"Init"};
                $FuncDef .= "    return ".$ReturnType_Init{"Call"}.";\n}\n\n";
                $Type_Init{"Code"} .= "\n".$FuncDef;
            }
            $CurrentBlock = $PreviousBlock;
        }
    }
    
    $Init_Desc{"Var"} = select_var_name($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ParamNameExt"});
    my $Var = $Init_Desc{"Var"};
    
    # create call
    my ($Call, $TmpPreamble) =
    convertTypes((
        "InputTypeName"=>$TypeName,
        "InputPointerLevel"=>0,
        "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
        "Value"=>"&".$AuxFuncName,
        "Key"=>$LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"},
        "Destination"=>"Param",
        "MustConvert"=>0));
    $Type_Init{"Init"} .= $TmpPreamble;
    $Type_Init{"Call"} = $Call;
    # create type
    $Type_Init{"TypeName"} = get_TypeName($Init_Desc{"TypeId"});
    # create call to constraint
    if($Init_Desc{"TargetTypeId"}==$Init_Desc{"TypeId"}) {
        $Type_Init{"TargetCall"} = $Type_Init{"Call"};
    }
    else
    {
        my ($TargetCall, $Target_TmpPreamble) =
        convertTypes((
            "InputTypeName"=>$TypeName,
            "InputPointerLevel"=>0,
            "OutputTypeId"=>$Init_Desc{"TargetTypeId"},
            "Value"=>"&".$AuxFuncName,
            "Key"=>$LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"},
            "Destination"=>"Target",
            "MustConvert"=>0));
        $Type_Init{"TargetCall"} = $TargetCall;
        $Type_Init{"Init"} .= $Target_TmpPreamble;
    }
    
    # ref handler
    if($Type{"Type"} eq "Ref")
    {
        my $BaseRefId = get_OneStep_BaseTypeId($Init_Desc{"TypeId"});
        if(get_PointerLevel($BaseRefId) > 0)
        {
            my $BaseRefName = get_TypeName($BaseRefId);
            $Type_Init{"Init"} .= $BaseRefName." ".$Var."_ref = ".$Type_Init{"Call"}.";\n";
            $Type_Init{"Call"} = $Var."_ref";
            $Block_Variable{$CurrentBlock}{$Var."_ref"} = 1;
        }
    }
    $Type_Init{"IsCorrect"} = 1;
    return %Type_Init;
}

sub declare_anon_union($$)
{
    my ($Key, $UnionId) = @_;
    return "" if($AuxType{$UnionId} or not $UnionId or not $Key);
    my %Union = get_Type($UnionId);
    my @MembStr = ();
    my ($Headers, $Declarations) = ([], "");
    foreach my $Member_Pos (sort {int($a)<=>int($b)} keys(%{$Union{"Memb"}}))
    { # create member types string
        my $Member_Name = $Union{"Memb"}{$Member_Pos}{"name"};
        my $MemberType_Id = $Union{"Memb"}{$Member_Pos}{"type"};
        my $MemberFType_Id = get_FoundationTypeId($MemberType_Id);
        my $MemberType_Name = "";
        if(isAnon(get_TypeName($MemberFType_Id)))
        {
            my ($FieldEType_Id, $Field_Declarations, $Field_Headers) = get_ExtTypeId($Key, $MemberType_Id);
            $Headers = addHeaders($Field_Headers, $Headers);
            $Declarations .= $Field_Declarations;
            $MemberType_Name = get_TypeName($FieldEType_Id);
        }
        else {
            $MemberType_Name = get_TypeName($MemberFType_Id);
        }
        my $MembDecl = create_member_decl($MemberType_Name, $Member_Name);
        @MembStr = (@MembStr, $MembDecl);
    }
    my $Type_Name = select_type_name("union_type_".$Key);
    $Declarations .= "//auxiliary union type\nunion ".$Type_Name;
    $Declarations .= "{\n    ".join(";\n    ", @MembStr).";};\n\n";
    $AuxType{$UnionId} = "union ".$Type_Name;
    $TName_Tid{$AuxType{$UnionId}} = $UnionId;
    $TypeInfo{$UnionId}{"Name_Old"} = $Union{"Name"};
    $TypeInfo{$UnionId}{"Name"} = $AuxType{$UnionId};
    return ($Declarations, $Headers);
}

sub declare_anon_struct($$)
{
    my ($Key, $StructId) = @_;
    return () if($AuxType{$StructId} or not $StructId or not $Key);
    my %Struct = get_Type($StructId);
    my @MembStr = ();
    my ($Headers, $Declarations) = ([], "");
    foreach my $Member_Pos (sort {int($a)<=>int($b)} keys(%{$Struct{"Memb"}}))
    {
        my $Member_Name = $Struct{"Memb"}{$Member_Pos}{"name"};
        my $MemberType_Id = $Struct{"Memb"}{$Member_Pos}{"type"};
        my $MemberFType_Id = get_FoundationTypeId($MemberType_Id);
        my $MemberType_Name = "";
        if(isAnon(get_TypeName($MemberFType_Id)))
        {
            my ($FieldEType_Id, $Field_Declarations, $Field_Headers) = get_ExtTypeId($Key, $MemberType_Id);
            $Headers = addHeaders($Field_Headers, $Headers);
            $Declarations .= $Field_Declarations;
            $MemberType_Name = get_TypeName($FieldEType_Id);
        }
        else {
            $MemberType_Name = get_TypeName($MemberFType_Id);
        }
        my $MembDecl = create_member_decl($MemberType_Name, $Member_Name);
        @MembStr = (@MembStr, $MembDecl);
    }
    my $Type_Name = select_type_name("struct_type_".$Key);
    $Declarations .= "//auxiliary struct type\nstruct ".$Type_Name;
    $Declarations .= "{\n    ".join(";\n    ", @MembStr).";};\n\n";
    $AuxType{$StructId} = "struct ".$Type_Name;
    $TName_Tid{$AuxType{$StructId}} = $StructId;
    $TypeInfo{$StructId}{"Name_Old"} = $Struct{"Name"};
    $TypeInfo{$StructId}{"Name"} = $AuxType{$StructId};
    return ($Declarations, $Headers);
}

sub create_member_decl($$)
{
    my ($TName, $Member) = @_;
    if($TName=~/\([\*]+\)/)
    {
        $TName=~s/\(([\*]+)\)/\($1$Member\)/;
        return $TName;
    }
    else
    {
        my @ArraySizes = ();
        while($TName=~s/(\[[^\[\]]*\])\Z//) {
            push(@ArraySizes, $1);
        }
        return $TName." ".$Member.join("", @ArraySizes);
    }
}

sub assembleStruct(@)
{
    my %Init_Desc = @_;
    my %Type_Init = ();
    my %Type = get_Type($Init_Desc{"TypeId"});
    my $Type_PointerLevel = get_PointerLevel($Init_Desc{"TypeId"});
    my $StructId = get_FoundationTypeId($Init_Desc{"TypeId"});
    my $StructName = get_TypeName($StructId);
    return () if($OpaqueTypes{$StructName});
    my %Struct = get_Type($StructId);
    return () if(not keys(%{$Struct{"Memb"}}));
    my $Global_State = save_state();
    $Init_Desc{"Var"} = select_var_name($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ParamNameExt"});
    my $Var = $Init_Desc{"Var"};
    if($Type_PointerLevel>0 or $Type{"Type"} eq "Ref"
    or not $Init_Desc{"InLine"}) {
        $Block_Variable{$CurrentBlock}{$Var} = 1;
    }
    $Type_Init{"Headers"} = addHeaders([$Struct{"Header"}], $Type_Init{"Headers"});
    my @ParamStr = ();
    my $Static = "";
    foreach my $Member_Pos (sort {int($a)<=>int($b)} keys(%{$Struct{"Memb"}}))
    { # initialize members
        my $Member_Name = $Struct{"Memb"}{$Member_Pos}{"name"};
        if(getSymLang($TestedInterface) eq "C")
        {
            if($Member_Name eq "c_class"
            and $StructName=~/\A(struct |)(XWindowAttributes|Visual|XVisualInfo)\Z/)
            { # for X11
                $Member_Name = "class";
            }
            elsif($Member_Name eq "c_explicit"
            and $StructName=~/\A(struct |)(_XkbServerMapRec)\Z/)
            { # for X11
                $Member_Name = "explicit";
            }
            elsif($Member_Name=~/\A(__|)fds_bits\Z/ and $StructName eq "fd_set")
            { # for libc
                if(defined $Constants{"__USE_XOPEN"}) {
                    $Member_Name = "fds_bits";
                }
                else {
                    $Member_Name = "__fds_bits";
                }
            }
        }
        my $MemberType_Id = $Struct{"Memb"}{$Member_Pos}{"type"};
        my $MemberFType_Id = get_FoundationTypeId($MemberType_Id);
        
        if(not $Static)
        {
            if($Member_Pos+1==keys(%{$Struct{"Memb"}}))
            {
                if(get_TypeName($MemberFType_Id)=~/\[\]/)
                { # flexible arrays
                    $Static = "static ";
                }
            }
        }
        
        if(get_TypeType($MemberFType_Id) eq "Array")
        {
            my $ArrayElemType_Id = get_FoundationTypeId(get_OneStep_BaseTypeId($MemberFType_Id));
            if(get_TypeType($ArrayElemType_Id)=~/\A(Intrinsic|Enum)\Z/)
            {
                if(get_TypeAttr($MemberFType_Id, "Count")>1024) {
                    next;
                }
            }
            else
            {
                if(get_TypeAttr($MemberFType_Id, "Count")>256) {
                    next;
                }
            }
        }
#         my $Member_Access = $Struct{"Memb"}{$Member_Pos}{"access"};
#         return () if($Member_Access eq "private" or $Member_Access eq "protected");
        my $Memb_Key = "";
        if($Member_Name) {
            $Memb_Key = ($Init_Desc{"Key"})?$Init_Desc{"Key"}."_".$Member_Name:$Member_Name;
        }
        else {
            $Memb_Key = ($Init_Desc{"Key"})?$Init_Desc{"Key"}."_".($Member_Pos+1):"m".($Member_Pos+1);
        }
        my %Memb_Init = initializeParameter((
            "TypeId" => $MemberType_Id,
            "Key" => $Memb_Key,
            "InLine" => 1,
            "Value" => "no value",
            "ValueTypeId" => 0,
            "TargetTypeId" => 0,
            "CreateChild" => 0,
            "Usage" => "Common",
            "ParamName" => $Member_Name,
            "OuterType_Type" => "Struct",
            "OuterType_Id" => $StructId));
        if(not $Memb_Init{"IsCorrect"}) {
            restore_state($Global_State);
            return ();
        }
        $Type_Init{"Code"} .= $Memb_Init{"Code"};
        $Type_Init{"Headers"} = addHeaders($Memb_Init{"Headers"}, $Type_Init{"Headers"});
        $Memb_Init{"Call"} = alignCode($Memb_Init{"Call"}, get_paragraph($Memb_Init{"Call"}, 1)."    ", 1);
        if(getSymLang($TestedInterface) eq "C"
        and $OSgroup ne "windows") {
            @ParamStr = (@ParamStr, "\.$Member_Name = ".$Memb_Init{"Call"});
        }
        else {
            @ParamStr = (@ParamStr, $Memb_Init{"Call"});
        }
        $Type_Init{"Init"} .= $Memb_Init{"Init"};
        $Type_Init{"Destructors"} .= $Memb_Init{"Destructors"};
    }
    if(my $Typedef_Id = get_type_typedef($StructId)) {
        $StructName = get_TypeName($Typedef_Id);
    }
    
    # initialization
    if($Type_PointerLevel==0 and ($Type{"Type"} ne "Ref") and $Init_Desc{"InLine"} and not $Static)
    {
        my $Conversion = (not isAnon($StructName) and not isAnon($Struct{"Name_Old"}))?"(".$Type{"Name"}.") ":"";
        $Type_Init{"Call"} = $Conversion."{".create_list(\@ParamStr, "    ")."}";
        $Type_Init{"TypeName"} = $Type{"Name"};
    }
    else
    {
        if(not defined $DisableReuse) {
            $ValueCollection{$CurrentBlock}{$Var} = $StructId;
        }
        if(isAnon($StructName))
        {
            my ($AnonStruct_Declarations, $AnonStruct_Headers) = declare_anon_struct($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $StructId);
            $Type_Init{"Code"} .= $AnonStruct_Declarations;
            $Type_Init{"Headers"} = addHeaders($AnonStruct_Headers, $Type_Init{"Headers"});
            $Type_Init{"Init"} .= $Static.get_TypeName($StructId)." $Var = {".create_list(\@ParamStr, "    ")."};\n";
            $Type_Init{"TypeName"} = get_TypeName($StructId);
            foreach (1 .. $Type_PointerLevel) {
                $Type_Init{"TypeName"} .= "*";
            }
        }
        else
        {
            $Type_Init{"Init"} .= $Static.$StructName." $Var = {".create_list(\@ParamStr, "    ")."};\n";
            $Type_Init{"TypeName"} = $Type{"Name"};
        }
        # create call
        my ($Call, $TmpPreamble) =
        convertTypes((
            "InputTypeName"=>get_TypeName($StructId),
            "InputPointerLevel"=>0,
            "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
            "Value"=>$Var,
            "Key"=>$Var,
            "Destination"=>"Param",
            "MustConvert"=>0));
        $Type_Init{"Init"} .= $TmpPreamble;
        $Type_Init{"Call"} = $Call;
        # create call for constraint
        if($Init_Desc{"TargetTypeId"}==$Init_Desc{"TypeId"}) {
            $Type_Init{"TargetCall"} = $Type_Init{"Call"};
        }
        else
        {
            my ($TargetCall, $Target_TmpPreamble) =
            convertTypes((
                "InputTypeName"=>get_TypeName($StructId),
                "InputPointerLevel"=>0,
                "OutputTypeId"=>$Init_Desc{"TargetTypeId"},
                "Value"=>$Var,
                "Key"=>$Var,
                "Destination"=>"Target",
                "MustConvert"=>0));
            $Type_Init{"TargetCall"} = $TargetCall;
            $Type_Init{"Init"} .= $Target_TmpPreamble;
        }
        #ref handler
        if($Type{"Type"} eq "Ref")
        {
            my $BaseRefId = get_OneStep_BaseTypeId($Init_Desc{"TypeId"});
            if(get_PointerLevel($BaseRefId) > 0)
            {
                my $BaseRefName = get_TypeName($BaseRefId);
                $Type_Init{"Init"} .= $BaseRefName." ".$Var."_ref = ".$Type_Init{"Call"}.";\n";
                $Type_Init{"Call"} = $Var."_ref";
                $Block_Variable{$CurrentBlock}{$Var."_ref"} = 1;
                if(not defined $DisableReuse) {
                    $ValueCollection{$CurrentBlock}{$Var."_ref"} = $Init_Desc{"TypeId"};
                }
            }
        }
    }
    $Type_Init{"IsCorrect"} = 1;
    return %Type_Init;
}

sub getSomeEnumMember($)
{
    my $EnumId = $_[0];
    my %Enum = get_Type($EnumId);
    return "" if(not keys(%{$Enum{"Memb"}}));
    my @Members = ();
    foreach my $MembPos (sort{int($a)<=>int($b)} keys(%{$Enum{"Memb"}})) {
        push(@Members, $Enum{"Memb"}{$MembPos}{"name"});
    }
    if($RandomCode) {
        @Members = mix_array(@Members);
    }
    my @ValidMembers = ();
    foreach my $Member (@Members)
    {
        if(is_valid_constant($Member)) {
            push(@ValidMembers, $Member);
        }
    }
    my $MemberName = $Members[0];
    if($#ValidMembers>=0) {
        $MemberName = $ValidMembers[0];
    }
    if($Enum{"NameSpace"} and $MemberName
    and getSymLang($TestedInterface) eq "C++") {
        $MemberName = $Enum{"NameSpace"}."::".$MemberName;
    }
    return $MemberName;
}

sub getEnumMembers($)
{
    my $EnumId = $_[0];
    my %Enum = get_Type($EnumId);
    return () if(not keys(%{$Enum{"Memb"}}));
    my @Members = ();
    foreach my $MembPos (sort{int($a)<=>int($b)} keys(%{$Enum{"Memb"}})) {
        push(@Members, $Enum{"Memb"}{$MembPos}{"name"});
    }
    return \@Members;
}

sub add_NullSpecType(@)
{
    my %Init_Desc = @_;
    my %NewInit_Desc = %Init_Desc;
    my $PointerLevel = get_PointerLevel($Init_Desc{"TypeId"});
    my $TypeName = get_TypeName($Init_Desc{"TypeId"});
    if($TypeName=~/\&/ or not $Init_Desc{"InLine"}) {
        $NewInit_Desc{"InLine"} = 0;
    }
    else {
        $NewInit_Desc{"InLine"} = 1;
    }
    if($PointerLevel>=1)
    {
        if($Init_Desc{"OuterType_Type"}!~/\A(Struct|Union|Array)\Z/
        and (isOutParam_NoUsing($Init_Desc{"TypeId"}, $Init_Desc{"ParamName"}, $Init_Desc{"Interface"})
        or $Interface_OutParam{$Init_Desc{"Interface"}}{$Init_Desc{"ParamName"}}
        or $Interface_OutParam_NoUsing{$Init_Desc{"Interface"}}{$Init_Desc{"ParamName"}} or $PointerLevel>=2))
        {
            $NewInit_Desc{"InLine"} = 0;
            $NewInit_Desc{"ValueTypeId"} = reduce_pointer_level($Init_Desc{"TypeId"});
            if($PointerLevel>=2) {
                $NewInit_Desc{"Value"} = get_null();
            }
            else {
                $NewInit_Desc{"OnlyDecl"} = 1;
            }
        }
        else
        {
            $NewInit_Desc{"Value"} = get_null();
            $NewInit_Desc{"ValueTypeId"} = $Init_Desc{"TypeId"};
            $NewInit_Desc{"ByNull"}=1;
        }
    }
    else {
        $NewInit_Desc{"Value"} = "no value";
    }
    return %NewInit_Desc;
}

sub initializeIntrinsic(@)
{
    my %Init_Desc = @_;
    $Init_Desc{"StrongTypeCompliance"} = 1;
    my %Type_Init = initializeByInterface(%Init_Desc);
    if($Type_Init{"IsCorrect"}) {
        return %Type_Init;
    }
    else {
        return initializeByInterface_OutParam(%Init_Desc);
    }
}

sub initializeRetVal(@)
{
    my %Init_Desc = @_;
    return () if(get_TypeName($Init_Desc{"TypeId"}) eq "void*");
    my %Type_Init = initializeByInterface(%Init_Desc);
    if($Type_Init{"IsCorrect"}) {
        return %Type_Init;
    }
    else {
        return initializeByInterface_OutParam(%Init_Desc);
    }
}

sub initializeEnum(@)
{
    my %Init_Desc = @_;
    return initializeByInterface(%Init_Desc);
}

sub is_geometry_body($)
{
    my $TypeId = $_[0];
    return 0 if(not $TypeId);
    my $StructId = get_FoundationTypeId($TypeId);
    my %Struct = get_Type($StructId);
    return 0 if($Struct{"Name"}!~/rectangle|line/i);
    return 0 if($Struct{"Type"} ne "Struct");
    foreach my $Member_Pos (sort {int($a)<=>int($b)} keys(%{$Struct{"Memb"}}))
    {
        if(get_TypeType(get_FoundationTypeId($Struct{"Memb"}{$Member_Pos}{"type"}))!~/\A(Intrinsic|Enum)\Z/) {
            return 0;
        }
    }
    return 1;
}

sub initializeUnion(@)
{
    my %Init_Desc = @_;
    $Init_Desc{"Strong"}=1;
    my %Type_Init = initializeByInterface_OutParam(%Init_Desc);
    if($Type_Init{"IsCorrect"}) {
        return %Type_Init;
    }
    else
    {
        delete($Init_Desc{"Strong"});
        %Type_Init = initializeByInterface(%Init_Desc);
        if($Type_Init{"IsCorrect"}) {
            return %Type_Init;
        }
        else
        {
            %Type_Init = assembleUnion(%Init_Desc);
            if($Type_Init{"IsCorrect"}) {
                return %Type_Init;
            }
            else {
                return initializeByInterface_OutParam(%Init_Desc);
            }
        }
    }
}

sub initializeStruct(@)
{
    my %Init_Desc = @_;
    if(is_geometry_body($Init_Desc{"TypeId"}))
    { # GdkRectangle
        return assembleStruct(%Init_Desc);
    }
#     $Init_Desc{"Strong"}=1;
#     my %Type_Init = initializeByInterface_OutParam(%Init_Desc);
#     if($Type_Init{"IsCorrect"})
#     {
#         return %Type_Init;
#     }
#     else
#     {
#         delete($Init_Desc{"Strong"});
    $Init_Desc{"OnlyReturn"}=1;
    my %Type_Init = initializeByInterface(%Init_Desc);
    if($Type_Init{"IsCorrect"}) {
        return %Type_Init;
    }
    else
    {
        return () if($Init_Desc{"OnlyByInterface"});
        delete($Init_Desc{"OnlyReturn"});
        %Type_Init = initializeByInterface_OutParam(%Init_Desc);
        if($Type_Init{"IsCorrect"}) {
            return %Type_Init;
        }
        else
        {
            $Init_Desc{"OnlyData"}=1;
            %Type_Init = initializeByInterface(%Init_Desc);
            if($Type_Init{"IsCorrect"}) {
                return %Type_Init;
            }
            else
            {
                delete($Init_Desc{"OnlyData"});
                %Type_Init = initializeByAlienInterface(%Init_Desc);
                if($Type_Init{"IsCorrect"}) {
                    return %Type_Init;
                }
                else
                {
                    %Type_Init = initializeSubClass_Struct(%Init_Desc);
                    if($Type_Init{"IsCorrect"}) {
                        return %Type_Init;
                    }
                    else
                    {
                        if($Init_Desc{"DoNotAssembly"}) {
                            return initializeByField(%Init_Desc);
                        }
                        else
                        {
                            %Type_Init = assembleStruct(%Init_Desc);
                            if($Type_Init{"IsCorrect"}) {
                                return %Type_Init;
                            }
                            else
                            {
                                %Type_Init = assembleClass(%Init_Desc);
                                if($Type_Init{"IsCorrect"}) {
                                    return %Type_Init;
                                }
                                else {
                                    return initializeByField(%Init_Desc);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

sub initializeByAlienInterface(@)
{ # GtkWidget*  gtk_plug_new (GdkNativeWindow socket_id)
  # return GtkPlug*
    my %Init_Desc = @_;
    if($Init_Desc{"ByInterface"} = find_alien_interface($Init_Desc{"TypeId"}))
    {
        my %Type_Init = initializeByInterface(%Init_Desc);
        if(not $Type_Init{"ByNull"}) {
            return %Type_Init;
        }
    }
    return ();
}

sub find_alien_interface($)
{
    my $TypeId = $_[0];
    return "" if(not $TypeId);
    return "" if(get_PointerLevel($TypeId)!=1);
    my $StructId = get_FoundationTypeId($TypeId);
    return "" if(get_TypeType($StructId) ne "Struct");
    my $Desirable = get_TypeName($StructId);
    $Desirable=~s/\Astruct //g;
    $Desirable=~s/\A[_]+//g;
    while($Desirable=~s/([a-z]+)([A-Z][a-z]+)/$1_$2/g){};
    $Desirable = lc($Desirable);
    my @Cnadidates = ($Desirable."_new", $Desirable."_create");
    foreach my $Candiate (@Cnadidates)
    {
        if(defined $CompleteSignature{$Candiate}
        and $CompleteSignature{$Candiate}{"Header"}
        and get_PointerLevel($CompleteSignature{$Candiate}{"Return"})==1)  {
            return $Candiate;
        }
    }
    return "";
}

sub initializeByField(@)
{ # FIXME: write body of this function
    my %Init_Desc = @_;
    return ();
}

sub initializeSubClass_Struct(@)
{
    my %Init_Desc = @_;
    $Init_Desc{"TypeId_Changed"} = $Init_Desc{"TypeId"} if(not $Init_Desc{"TypeId_Changed"});
    my $StructId = get_FoundationTypeId($Init_Desc{"TypeId"});
    my $StructName = get_TypeName($StructId);
    my $PLevel = get_PointerLevel($Init_Desc{"TypeId"});
    return () if(get_TypeType($StructId) ne "Struct" or $PLevel==0);
    foreach my $SubClassId (keys(%{$Struct_SubClasses{$StructId}}))
    {
        $Init_Desc{"TypeId"} = get_TypeId($SubClassId, $PLevel);
        next if(not $Init_Desc{"TypeId"});
        $Init_Desc{"DoNotAssembly"} = 1;
        my %Type_Init = initializeType(%Init_Desc);
        if($Type_Init{"IsCorrect"}) {
            return %Type_Init;
        }
    }
    if(my $ParentId = get_TypeId($Struct_Parent{$StructId}, $PLevel))
    {
        $Init_Desc{"TypeId"} = $ParentId;
        $Init_Desc{"DoNotAssembly"} = 1;
        $Init_Desc{"OnlyByInterface"} = 1;
        $Init_Desc{"KeyWords"} = $StructName;
        $Init_Desc{"KeyWords"}=~s/\Astruct //;
        my %Type_Init = initializeType(%Init_Desc);
        if($Type_Init{"IsCorrect"}
        and (not $Type_Init{"Interface"} or get_word_coinsidence($Type_Init{"Interface"}, $Init_Desc{"KeyWords"})>0)) {
            return %Type_Init;
        }
    }
}

sub get_TypeId($$)
{
    my ($BaseTypeId, $PLevel) = @_;
    return 0 if(not $BaseTypeId);
    if(my @DerivedTypes = sort {length($a)<=>length($b)}
    keys(%{$BaseType_PLevel_Type{$BaseTypeId}{$PLevel}})) {
        return $DerivedTypes[0];
    }
    elsif(my $NewTypeId = register_new_type($BaseTypeId, $PLevel)) {
        return $NewTypeId;
    }
    else {
        return 0;
    }
}

sub assembleUnion(@)
{
    my %Init_Desc = @_;
    my %Type_Init = ();
    my %Type = get_Type($Init_Desc{"TypeId"});
    my $Type_PointerLevel = get_PointerLevel($Init_Desc{"TypeId"});
    my $UnionId = get_FoundationTypeId($Init_Desc{"TypeId"});
    my %UnionType = get_Type($UnionId);
    my $UnionName = $UnionType{"Name"};
    return () if($OpaqueTypes{$UnionName});
    return () if(not keys(%{$UnionType{"Memb"}}));
    my $Global_State = save_state();
    $Init_Desc{"Var"} = select_var_name($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ParamNameExt"});
    my $Var = $Init_Desc{"Var"};
    if($Type_PointerLevel>0 or $Type{"Type"} eq "Ref"
    or not $Init_Desc{"InLine"}) {
        $Block_Variable{$CurrentBlock}{$Var} = 1;
    }
    $Type_Init{"Headers"} = addHeaders([$UnionType{"Header"}], $Type_Init{"Headers"});
    my (%Memb_Init, $SelectedMember_Name) = ();
    foreach my $Member_Pos (sort {int($a)<=>int($b)} keys(%{$UnionType{"Memb"}}))
    { # initialize members
        my $Member_Name = $UnionType{"Memb"}{$Member_Pos}{"name"};
        my $MemberType_Id = $UnionType{"Memb"}{$Member_Pos}{"type"};
        my $Memb_Key = "";
        if($Member_Name) {
            $Memb_Key = ($Init_Desc{"Key"})?$Init_Desc{"Key"}."_".$Member_Name:$Member_Name;
        }
        else {
            $Memb_Key = ($Init_Desc{"Key"})?$Init_Desc{"Key"}."_".($Member_Pos+1):"m".($Member_Pos+1);
        }
        %Memb_Init = initializeParameter((
            "TypeId" => $MemberType_Id,
            "Key" => $Memb_Key,
            "InLine" => 1,
            "Value" => "no value",
            "ValueTypeId" => 0,
            "TargetTypeId" => 0,
            "CreateChild" => 0,
            "Usage" => "Common",
            "ParamName" => $Member_Name,
            "OuterType_Type" => "Union",
            "OuterType_Id" => $UnionId));
        next if(not $Memb_Init{"IsCorrect"});
        $SelectedMember_Name = $Member_Name;
        last;
    }
    if(not $Memb_Init{"IsCorrect"})
    {
        restore_state($Global_State);
        return ();
    }
    $Type_Init{"Code"} .= $Memb_Init{"Code"};
    $Type_Init{"Headers"} = addHeaders($Memb_Init{"Headers"}, $Type_Init{"Headers"});
    $Type_Init{"Init"} .= $Memb_Init{"Init"};
    $Type_Init{"Destructors"} .= $Memb_Init{"Destructors"};
    $Memb_Init{"Call"} = alignCode($Memb_Init{"Call"}, get_paragraph($Memb_Init{"Call"}, 1)."    ", 1);
    if(my $Typedef_Id = get_type_typedef($UnionId)) {
        $UnionName = get_TypeName($Typedef_Id);
    }
    # initialization
    if($Type_PointerLevel==0 and ($Type{"Type"} ne "Ref") and $Init_Desc{"InLine"})
    {
        my $Conversion = (not isAnon($UnionName) and not isAnon($UnionType{"Name_Old"}))?"(".$Type{"Name"}.") ":"";
        if($TestedInterface=~/\A(_Z|\?)/) { # C++
            $Type_Init{"Call"} = $Conversion."{".$Memb_Init{"Call"}."}";
        }
        else {
            $Type_Init{"Call"} = $Conversion."{\.$SelectedMember_Name = ".$Memb_Init{"Call"}."}";
        }
        $Type_Init{"TypeName"} = $Type{"Name"};
    }
    else
    {
        if(not defined $DisableReuse) {
            $ValueCollection{$CurrentBlock}{$Var} = $UnionId;
        }
        if(isAnon($UnionName))
        {
            my ($AnonUnion_Declarations, $AnonUnion_Headers) = declare_anon_union($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $UnionId);
            $Type_Init{"Code"} .= $AnonUnion_Declarations;
            $Type_Init{"Headers"} = addHeaders($AnonUnion_Headers, $Type_Init{"Headers"});
            if($TestedInterface=~/\A(_Z|\?)/) { # C++
                $Type_Init{"Init"} .= get_TypeName($UnionId)." $Var = {".$Memb_Init{"Call"}."};\n";
            }
            else {
                $Type_Init{"Init"} .= get_TypeName($UnionId)." $Var = {\.$SelectedMember_Name = ".$Memb_Init{"Call"}."};\n";
            }
            $Type_Init{"TypeName"} = "union ".get_TypeName($UnionId);
            foreach (1 .. $Type_PointerLevel) {
                $Type_Init{"TypeName"} .= "*";
            }
        }
        else
        {
            if($TestedInterface=~/\A(_Z|\?)/) { # C++
                $Type_Init{"Init"} .= $UnionName." $Var = {".$Memb_Init{"Call"}."};\n";
            }
            else {
                $Type_Init{"Init"} .= $UnionName." $Var = {\.$SelectedMember_Name = ".$Memb_Init{"Call"}."};\n";
            }
            $Type_Init{"TypeName"} = $Type{"Name"};
        }
        #create call
        my ($Call, $TmpPreamble) =
        convertTypes((
            "InputTypeName"=>get_TypeName($UnionId),
            "InputPointerLevel"=>0,
            "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
            "Value"=>$Var,
            "Key"=>$Var,
            "Destination"=>"Param",
            "MustConvert"=>0));
        $Type_Init{"Init"} .= $TmpPreamble;
        $Type_Init{"Call"} = $Call;
        #create call in constraint
        if($Init_Desc{"TargetTypeId"}==$Init_Desc{"TypeId"}) {
            $Type_Init{"TargetCall"} = $Type_Init{"Call"};
        }
        else
        {
            my ($TargetCall, $Target_TmpPreamble) =
            convertTypes((
                "InputTypeName"=>get_TypeName($UnionId),
                "InputPointerLevel"=>0,
                "OutputTypeId"=>$Init_Desc{"TargetTypeId"},
                "Value"=>$Var,
                "Key"=>$Var,
                "Destination"=>"Target",
                "MustConvert"=>0));
            $Type_Init{"TargetCall"} = $TargetCall;
            $Type_Init{"Init"} .= $Target_TmpPreamble;
        }
        #ref handler
        if($Type{"Type"} eq "Ref")
        {
            my $BaseRefId = get_OneStep_BaseTypeId($Init_Desc{"TypeId"});
            if(get_PointerLevel($BaseRefId) > 0)
            {
                my $BaseRefName = get_TypeName($BaseRefId);
                $Type_Init{"Init"} .= $BaseRefName." ".$Var."_ref = ".$Type_Init{"Call"}.";\n";
                $Type_Init{"Call"} = $Var."_ref";
                $Block_Variable{$CurrentBlock}{$Var."_ref"} = 1;
                if(not defined $DisableReuse) {
                    $ValueCollection{$CurrentBlock}{$Var."_ref"} = $Init_Desc{"TypeId"};
                }
            }
        }
    }
    $Type_Init{"IsCorrect"} = 1;
    return %Type_Init;
}

sub initializeClass(@)
{
    my %Init_Desc = @_;
    my %Type_Init = ();
    if($Init_Desc{"CreateChild"})
    {
        $Init_Desc{"InheritingPriority"} = "High";
        return assembleClass(%Init_Desc);
    }
    else
    {
        if((get_TypeType($Init_Desc{"TypeId"}) eq "Typedef"))
        { # try to initialize typedefs by interface return value
            %Type_Init = initializeByInterface(%Init_Desc);
            if($Type_Init{"IsCorrect"}) {
                return %Type_Init;
            }
        }
        $Init_Desc{"InheritingPriority"} = "Low";
        %Type_Init = assembleClass(%Init_Desc);
        if($Type_Init{"IsCorrect"}) {
            return %Type_Init;
        }
        else
        {
            if(isAbstractClass(get_FoundationTypeId($Init_Desc{"TypeId"})))
            {
                $Init_Desc{"InheritingPriority"} = "High";
                %Type_Init = assembleClass(%Init_Desc);
                if($Type_Init{"IsCorrect"}) {
                    return %Type_Init;
                }
                else {
                    return initializeByInterface(%Init_Desc);
                }
            }
            else
            {
                %Type_Init = initializeByInterface(%Init_Desc);
                if($Type_Init{"IsCorrect"}) {
                    return %Type_Init;
                }
                else
                {
                    $Init_Desc{"InheritingPriority"} = "High";
                    %Type_Init = assembleClass(%Init_Desc);
                    if($Type_Init{"IsCorrect"}) {
                        return %Type_Init;
                    }
                    else {
                        return initializeByInterface_OutParam(%Init_Desc);
                    }
                }
            }
        }
    }
}

sub has_public_destructor($$)
{
    my ($ClassId, $DestrType) = @_;
    my $ClassName = get_TypeName($ClassId);
    return $Cache{"has_public_destructor"}{$ClassId}{$DestrType} if($Cache{"has_public_destructor"}{$ClassId}{$DestrType});
    foreach my $Destructor (sort keys(%{$Class_Destructors{$ClassId}}))
    {
        if($Destructor=~/\Q$DestrType\E/)
        {
            if(not $CompleteSignature{$Destructor}{"Protected"})
            {
                $Cache{"has_public_destructor"}{$ClassId}{$DestrType} = $Destructor;
                return $Destructor;
            }
            else {
                return "";
            }
        }
    }
    $Cache{"has_public_destructor"}{$ClassId}{$DestrType} = "Default";
    return "Default";
}

sub findConstructor($$)
{
    my ($ClassId, $Key) = @_;
    return () if(not $ClassId);
    foreach my $Constructor (get_CompatibleInterfaces($ClassId, "Construct", ""))
    {
        my %Interface_Init = callInterfaceParameters((
            "Interface"=>$Constructor,
            "Key"=>$Key,
            "ObjectCall"=>"no object"));
        if($Interface_Init{"IsCorrect"})
        {
            $Interface_Init{"Interface"} = $Constructor;
            return %Interface_Init;
        }
    }
    return ();
}

sub assembleClass(@)
{
    my %Init_Desc = @_;
    my %Type_Init = ();
    my $Global_State = save_state();
    my $CreateDestructor = 1;
    $Type_Init{"TypeName"} = get_TypeName($Init_Desc{"TypeId"});
    my $ClassId = get_FoundationTypeId($Init_Desc{"TypeId"});
    my $ClassName = get_TypeName($ClassId);
    my $PointerLevel = get_PointerLevel($Init_Desc{"TypeId"});
    $Init_Desc{"Var"} = select_var_name($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ParamNameExt"});
    my $Var = $Init_Desc{"Var"};
    $Block_Variable{$CurrentBlock}{$Var} = 1;
    my %Obj_Init = findConstructor($ClassId, $Init_Desc{"Key"});
    if(not $Obj_Init{"IsCorrect"}) {
        restore_state($Global_State);
        return ();
    }
    $Type_Init{"Init"} = $Obj_Init{"Init"};
    $Type_Init{"Destructors"} = $Obj_Init{"Destructors"};
    $Type_Init{"Code"} = $Obj_Init{"Code"};
    $Type_Init{"Headers"} = addHeaders($Obj_Init{"Headers"}, $Type_Init{"Headers"});
    my $NeedToInheriting = (isAbstractClass($ClassId) or $Init_Desc{"CreateChild"} or isNotInCharge($Obj_Init{"Interface"}) or $CompleteSignature{$Obj_Init{"Interface"}}{"Protected"});
    if($Init_Desc{"InheritingPriority"} eq "Low"
    and $NeedToInheriting) {
        restore_state($Global_State);
        return ();
    }
    my $HeapStack = (($PointerLevel eq 0) and has_public_destructor($ClassId, "D1") and not $Init_Desc{"ObjectInit"} and (not $Init_Desc{"RetVal"} or get_TypeType($Init_Desc{"TypeId"}) ne "Ref"))?"Stack":"Heap";
    my $ChildName = getSubClassName($ClassName);
    if($NeedToInheriting)
    {
        if($Obj_Init{"Call"}=~/\A(\Q$ClassName\E([\n]*)\()/) {
            substr($Obj_Init{"Call"}, index($Obj_Init{"Call"}, $1), pos($1) + length($1)) = $ChildName.$2."(";
        }
        $UsedConstructors{$ClassId}{$Obj_Init{"Interface"}} = 1;
        $IntSubClass{$TestedInterface}{$ClassId} = 1;
        $Create_SubClass{$ClassId} = 1;
        $SubClass_Instance{$Var} = 1;
        $SubClass_ObjInstance{$Var} = 1 if($Init_Desc{"ObjectInit"});
    }
    my %AutoFinalCode_Init = ();
    my $Typedef_Id = detect_typedef($Init_Desc{"TypeId"});
    if(get_TypeName($ClassId)=~/list/i or get_TypeName($Typedef_Id)=~/list/i)
    { # auto final code
        %AutoFinalCode_Init = get_AutoFinalCode($Obj_Init{"Interface"}, ($HeapStack eq "Stack")?$Var:"*".$Var);
        if($AutoFinalCode_Init{"IsCorrect"}) {
            $Init_Desc{"InLine"} = 0;
        }
    }
    if($Obj_Init{"PreCondition"}
    or $Obj_Init{"PostCondition"}) {
        $Init_Desc{"InLine"} = 0;
    }
    # check precondition
    if($Obj_Init{"PreCondition"}) {
        $Type_Init{"Init"} .= $Obj_Init{"PreCondition"}."\n";
    }
    if($HeapStack eq "Stack")
    {
        $CreateDestructor = 0;
        if($Init_Desc{"InLine"} and ($PointerLevel eq 0))
        {
            $Type_Init{"Call"} = $Obj_Init{"Call"};
            $Type_Init{"TargetCall"} = $Type_Init{"Call"};
            delete($Block_Variable{$CurrentBlock}{$Var});
        }
        else
        {
            if(not defined $DisableReuse) {
                $ValueCollection{$CurrentBlock}{$Var} = $ClassId;
            }
            # $Type_Init{"Init"} .= "//parameter initialization\n";
            my $ConstructedName = ($NeedToInheriting)?$ChildName:$ClassName;
            $Type_Init{"Init"} .= correct_init_stmt($ConstructedName." $Var = ".$Obj_Init{"Call"}.";\n", $ConstructedName, $Var);
            # create call
            my ($Call, $TmpPreamble) =
            convertTypes((
                "InputTypeName"=>$ConstructedName,
                "InputPointerLevel"=>0,
                "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
                "Value"=>$Var,
                "Key"=>$Var,
                "Destination"=>"Param",
                "MustConvert"=>0));
            $Type_Init{"Init"} .= $TmpPreamble;
            $Type_Init{"Call"} = $Call;
            #call to constraint
            if($Init_Desc{"TargetTypeId"}==$Init_Desc{"TypeId"}) {
                $Type_Init{"TargetCall"} = $Type_Init{"Call"};
            }
            else
            {
                my ($TargetCall, $Target_TmpPreamble) =
                convertTypes((
                    "InputTypeName"=>$ConstructedName,
                    "InputPointerLevel"=>0,
                    "OutputTypeId"=>$Init_Desc{"TargetTypeId"},
                    "Value"=>$Var,
                    "Key"=>$Var,
                    "Destination"=>"Target",
                    "MustConvert"=>0));
                $Type_Init{"TargetCall"} = $TargetCall;
                $Type_Init{"Init"} .= $Target_TmpPreamble;
            }
        }
    }
    elsif($HeapStack eq "Heap")
    {
        if($Init_Desc{"InLine"} and ($PointerLevel eq 1))
        {
            $Type_Init{"Call"} = "new ".$Obj_Init{"Call"};
            $Type_Init{"TargetCall"} = $Type_Init{"Call"};
            $CreateDestructor = 0;
            delete($Block_Variable{$CurrentBlock}{$Var});
        }
        else
        {
            if(not defined $DisableReuse) {
                $ValueCollection{$CurrentBlock}{$Var} = get_TypeIdByName("$ClassName*");
            }
            #$Type_Init{"Init"} .= "//parameter initialization\n";
            if($NeedToInheriting)
            {
                if($Init_Desc{"ConvertToBase"}) {
                    $Type_Init{"Init"} .= $ClassName."* $Var = ($ClassName*)new ".$Obj_Init{"Call"}.";\n";
                }
                else {
                    $Type_Init{"Init"} .= $ChildName."* $Var = new ".$Obj_Init{"Call"}.";\n";
                }
            }
            else {
                $Type_Init{"Init"} .= $ClassName."* $Var = new ".$Obj_Init{"Call"}.";\n";
            }
            #create call
            my ($Call, $TmpPreamble) =
            convertTypes((
                "InputTypeName"=>"$ClassName*",
                "InputPointerLevel"=>1,
                "OutputTypeId"=>($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"},
                "Value"=>$Var,
                "Key"=>$Var,
                "Destination"=>"Param",
                "MustConvert"=>0));
            $Type_Init{"Init"} .= $TmpPreamble;
            $Type_Init{"Call"} = $Call;
            #call to constraint
            if($Init_Desc{"TargetTypeId"}==$Init_Desc{"TypeId"}) {
                $Type_Init{"TargetCall"} = $Type_Init{"Call"};
            }
            else
            {
                my ($TargetCall, $Target_TmpPreamble) =
                convertTypes((
                    "InputTypeName"=>"$ClassName*",
                    "InputPointerLevel"=>1,
                    "OutputTypeId"=>$Init_Desc{"TargetTypeId"},
                    "Value"=>$Var,
                    "Key"=>$Var,
                    "Destination"=>"Target",
                    "MustConvert"=>0));
                $Type_Init{"TargetCall"} = $TargetCall;
                $Type_Init{"Init"} .= $Target_TmpPreamble;
            }
        }
        # destructor for object
        if($CreateDestructor) # mayCallDestructors($ClassId)
        {
            if($HeapStack eq "Heap")
            {
                if($NeedToInheriting)
                {
                    if(has_public_destructor($ClassId, "D2")) {
                        $Type_Init{"Destructors"} .= "delete($Var);\n";
                    }
                }
                else
                {
                    if(has_public_destructor($ClassId, "D0")) {
                        $Type_Init{"Destructors"} .= "delete($Var);\n";
                    }
                }
            }
        }
    }
    # check postcondition
    if($Obj_Init{"PostCondition"}) {
        $Type_Init{"Init"} .= $Obj_Init{"PostCondition"}."\n";
    }
    if($Obj_Init{"ReturnRequirement"})
    {
        if($HeapStack eq "Stack") {
            $Obj_Init{"ReturnRequirement"}=~s/(\$0|\$obj)/$Var/gi;
        }
        else {
            $Obj_Init{"ReturnRequirement"}=~s/(\$0|\$obj)/*$Var/gi;
        }
        $Type_Init{"Init"} .= $Obj_Init{"ReturnRequirement"}."\n";
    }
    if($Obj_Init{"FinalCode"})
    {
        $Type_Init{"Init"} .= "//final code\n";
        $Type_Init{"Init"} .= $Obj_Init{"FinalCode"}."\n";
    }
    if(get_TypeType($Init_Desc{"TypeId"}) eq "Ref")
    { # obsolete
        my $BaseRefId = get_OneStep_BaseTypeId($Init_Desc{"TypeId"});
        if($HeapStack eq "Heap")
        {
            if(get_PointerLevel($BaseRefId)>1)
            {
                my $BaseRefName = get_TypeName($BaseRefId);
                $Type_Init{"Init"} .= $BaseRefName." ".$Var."_ref = ".$Type_Init{"Call"}.";\n";
                $Type_Init{"Call"} = $Var."_ref";
                $Block_Variable{$CurrentBlock}{$Var."_ref"} = 1;
                if(not defined $DisableReuse) {
                    $ValueCollection{$CurrentBlock}{$Var."_ref"} = $Init_Desc{"TypeId"};
                }
            }
        }
        else
        {
            if(get_PointerLevel($BaseRefId)>0)
            {
                my $BaseRefName = get_TypeName($BaseRefId);
                $Type_Init{"Init"} .= $BaseRefName." ".$Var."_ref = ".$Type_Init{"Call"}.";\n";
                $Type_Init{"Call"} = $Var."_ref";
                $Block_Variable{$CurrentBlock}{$Var."_ref"} = 1;
                if(not defined $DisableReuse) {
                    $ValueCollection{$CurrentBlock}{$Var."_ref"} = $Init_Desc{"TypeId"};
                }
            }
        }
    }
    $Type_Init{"IsCorrect"} = 1;
    if($Typedef_Id)
    {
        $Type_Init{"Headers"} = addHeaders(getTypeHeaders($Typedef_Id), $Type_Init{"Headers"});
        foreach my $Elem ("Call", "Init") {
            $Type_Init{$Elem} = cover_by_typedef($Type_Init{$Elem}, $ClassId, $Typedef_Id);
        }
    }
    else {
        $Type_Init{"Headers"} = addHeaders(getTypeHeaders($ClassId), $Type_Init{"Headers"});
    }
    if($AutoFinalCode_Init{"IsCorrect"})
    {
        $Type_Init{"Init"} = $AutoFinalCode_Init{"Init"}.$Type_Init{"Init"}.$AutoFinalCode_Init{"PreCondition"}.$AutoFinalCode_Init{"Call"}.";\n".$AutoFinalCode_Init{"FinalCode"}.$AutoFinalCode_Init{"PostCondition"};
        $Type_Init{"Code"} .= $AutoFinalCode_Init{"Code"};
        $Type_Init{"Destructors"} .= $AutoFinalCode_Init{"Destructors"};
        $Type_Init{"Headers"} = addHeaders($AutoFinalCode_Init{"Headers"}, $Type_Init{"Headers"});
    }
    return %Type_Init;
}

sub cover_by_typedef($$$)
{
    my ($Code, $Type_Id, $Typedef_Id) = @_;
    if($Class_SubClassTypedef{$Type_Id}) {
        $Typedef_Id = $Class_SubClassTypedef{$Type_Id};
    }
    return $Code if(not $Code or not $Type_Id or not $Typedef_Id);
    return $Code if(not $Type_Id or not $Typedef_Id);
    return $Code if(get_TypeType($Type_Id)!~/\A(Class|Struct)\Z/);
    my $Type_Name = get_TypeName($Type_Id);
    my $Typedef_Name = get_TypeName($Typedef_Id);
    if(length($Typedef_Name)>=length($Type_Name)) {
        return $Code;
    }
    my $Child_Name_Old = getSubClassName($Type_Name);
    my $Child_Name_New = getSubClassName($Typedef_Name);
    $Class_SubClassTypedef{$Type_Id}=$Typedef_Id;
    $Code=~s/(\W|\A)\Q$Child_Name_Old\E(\W|\Z)/$1$Child_Name_New$2/g;
    if($Type_Name=~/\W\Z/)
    {
        $Code=~s/(\W|\A)\Q$Type_Name\E(\W|\Z)/$1$Typedef_Name$2/g;
        $Code=~s/(\W|\A)\Q$Type_Name\E(\w|\Z)/$1$Typedef_Name $2/g;
    }
    else {
        $Code=~s/(\W|\A)\Q$Type_Name\E(\W|\Z)/$1$Typedef_Name$2/g;
    }
    return $Code;
}

sub get_type_typedef($)
{
    my $TypeId = $_[0];
    my $TypeName = get_TypeName($TypeId);
    
    if($Class_SubClassTypedef{$TypeId}) {
        return $Class_SubClassTypedef{$TypeId};
    }
    my @Types = ();
    
    foreach (keys(%{$Type_Typedef{$TypeId}}))
    {
        my $Typedef = get_TypeName($_);
        if($TypeName=~/ \Q$Typedef\E\Z/) {
            next;
        }
        
        push(@Types, $_);
    }
    
    @Types = sort {lc(get_TypeName($a)) cmp lc(get_TypeName($b))} @Types;
    @Types = sort {length(get_TypeName($a)) <=> length(get_TypeName($b))} @Types;
    if($#Types==0) {
        return $Types[0];
    }
    else {
        return 0;
    }
}

sub is_used_var($$)
{
    my ($Block, $Var) = @_;
    return ($Block_Variable{$Block}{$Var} or $ValueCollection{$Block}{$Var}
    or not is_allowed_var_name($Var));
}

sub select_var_name($$)
{
    my ($Var_Name, $SuffixCandidate) = @_;
    my $OtherVarPrefix = 1;
    my $Candidate = $Var_Name;
    if($Var_Name=~/\Ap\d+\Z/)
    {
        $Var_Name = "p";
        while(is_used_var($CurrentBlock, $Candidate))
        {
            $Candidate = $Var_Name.$OtherVarPrefix;
            $OtherVarPrefix += 1;
        }
    }
    else
    {
        if($SuffixCandidate)
        {
            $Candidate = $Var_Name."_".$SuffixCandidate;
            if(not is_used_var($CurrentBlock, $Candidate)) {
                return $Candidate;
            }
        }
        if($Var_Name eq "description" and is_used_var($CurrentBlock, $Var_Name)
        and not is_used_var($CurrentBlock, "desc")) {
            return "desc";
        }
        elsif($Var_Name eq "system" and is_used_var($CurrentBlock, $Var_Name)
        and not is_used_var($CurrentBlock, "sys")) {
            return "sys";
        }
        while(is_used_var($CurrentBlock, $Candidate))
        {
            $Candidate = $Var_Name."_".$OtherVarPrefix;
            $OtherVarPrefix += 1;
        }
    }
    return $Candidate;
}

sub select_type_name($)
{
    my $Type_Name = $_[0];
    my $OtherPrefix = 1;
    my $NameCandidate = $Type_Name;
    while($TName_Tid{$NameCandidate}
    or $TName_Tid{"struct ".$NameCandidate}
    or $TName_Tid{"union ".$NameCandidate})
    {
        $NameCandidate = $Type_Name."_".$OtherPrefix;
        $OtherPrefix += 1;
    }
    return $NameCandidate;
}

sub select_func_name($)
{
    my $FuncName = $_[0];
    my $OtherFuncPrefix = 1;
    my $Candidate = $FuncName;
    while(is_used_func_name($Candidate))
    {
        $Candidate = $FuncName."_".$OtherFuncPrefix;
        $OtherFuncPrefix += 1;
    }
    return $Candidate;
}

sub is_used_func_name($)
{
    my $FuncName = $_[0];
    return 1 if($FuncNames{$FuncName});
    foreach my $FuncTypeId (keys(%AuxFunc))
    {
        if($AuxFunc{$FuncTypeId} eq $FuncName) {
            return 1;
        }
    }
    return 0;
}

sub get_TypeStackId($)
{
    my $TypeId = $_[0];
    my $FoundationId = get_FoundationTypeId($TypeId);
    if(get_TypeType($FoundationId) eq "Intrinsic")
    {
        my %BaseTypedef = goToFirst($TypeId, "Typedef");
        if(get_TypeType($BaseTypedef{"Tid"}) eq "Typedef") {
            return $BaseTypedef{"Tid"};
        }
        else {
            return $FoundationId;
        }
    }
    else {
        return $FoundationId;
    }
}

sub initializeType(@)
{
    my %Init_Desc = @_;
    return () if(not $Init_Desc{"TypeId"});
    my %Type_Init = ();
    my $Global_State = save_state();
    my $TypeName = get_TypeName($Init_Desc{"TypeId"});
    my $SpecValue = $Init_Desc{"Value"};
    %Init_Desc = add_VirtualSpecType(%Init_Desc);
    $Init_Desc{"Var"} = select_var_name($LongVarNames?$Init_Desc{"Key"}:$Init_Desc{"ParamName"}, $Init_Desc{"ParamNameExt"});
    if(($TypeName eq "...") and (($Init_Desc{"Value"} eq "no value") or ($Init_Desc{"Value"} eq "")))
    {
        $Type_Init{"IsCorrect"} = 1;
        $Type_Init{"Call"} = "";
        return %Type_Init;
    }
    if($TypeName eq "struct __va_list_tag*")
    { # initialize va_list
        if(my $VaList_Tid = $TName_Tid{"va_list"}) {
            $Init_Desc{"TypeId"} = $VaList_Tid;
        }
        %Type_Init = emptyDeclaration(%Init_Desc);
        $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
        return %Type_Init;
    }
    my $FoundationId = get_FoundationTypeId($Init_Desc{"TypeId"});
    if(not $Init_Desc{"FoundationType_Type"}) {
        $Init_Desc{"FoundationType_Type"} = get_TypeType($FoundationId);
    }
    my $TypeStackId = get_TypeStackId($Init_Desc{"TypeId"});
    if(isCyclical(\@RecurTypeId, $TypeStackId))
    { # initialize by null for cyclical types
        if($Init_Desc{"Value"} ne "no value" and $Init_Desc{"Value"} ne "")
        {
            return () if(get_TypeType($TypeStackId) eq "Typedef" and $TypeName!~/_t/);
            %Type_Init = initializeByValue(%Init_Desc);
            $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
            return %Type_Init;
        }
        else
        {
            %Init_Desc = add_NullSpecType(%Init_Desc);
            if($Init_Desc{"OnlyDecl"})
            {
                %Type_Init = emptyDeclaration(%Init_Desc);
                $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
                return %Type_Init;
            }
            elsif(($Init_Desc{"Value"} ne "no value") and ($Init_Desc{"Value"} ne ""))
            {
                %Type_Init = initializeByValue(%Init_Desc);
                $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
                return %Type_Init;
            }
            else {
                return ();
            }
        }
    }
    else
    {
        if($Init_Desc{"FoundationType_Type"} ne "Array") {
            push(@RecurTypeId, $TypeStackId);
        }
    }
    if(not $Init_Desc{"TargetTypeId"})
    { # repair target type
        $Init_Desc{"TargetTypeId"} = $Init_Desc{"TypeId"};
    }
    if($Init_Desc{"RetVal"} and get_PointerLevel($Init_Desc{"TypeId"})>=1
    and not $Init_Desc{"TypeType_Changed"} and $TypeName!~/(\W|\Z)const(\W|\Z)/)
    { # return value
        if(($Init_Desc{"Value"} ne "no value") and ($Init_Desc{"Value"} ne ""))
        { # try to initialize type by value
            %Type_Init = initializeByValue(%Init_Desc);
            if($Type_Init{"IsCorrect"})
            {
                if($Init_Desc{"FoundationType_Type"} ne "Array") {
                    pop(@RecurTypeId);
                }
                $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
                return %Type_Init;
            }
        }
        else
        {
            %Type_Init = initializeRetVal(%Init_Desc);
            if($Type_Init{"IsCorrect"})
            {
                if($Init_Desc{"FoundationType_Type"} ne "Array") {
                    pop(@RecurTypeId);
                }
                $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
                return %Type_Init;
            }
        }
    }
    if($Init_Desc{"OnlyDecl"})
    {
        %Type_Init = emptyDeclaration(%Init_Desc);
        $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
        if($Init_Desc{"FoundationType_Type"} ne "Array") {
            pop(@RecurTypeId);
        }
        return %Type_Init;
    }
    my $RealTypeId = ($Init_Desc{"TypeId_Changed"})?$Init_Desc{"TypeId_Changed"}:$Init_Desc{"TypeId"};
    my $RealFTypeType = get_TypeType(get_FoundationTypeId($RealTypeId));
    if(($RealFTypeType eq "Intrinsic") and not $SpecValue and not $Init_Desc{"Reuse"} and not $Init_Desc{"OnlyByValue"} and $Init_Desc{"ParamName"}!~/num|width|height/i)
    { # initializing intrinsics by the interface
        my %BaseTypedef = goToFirst($RealTypeId, "Typedef");
        if(get_TypeType($BaseTypedef{"Tid"}) eq "Typedef"
        and $BaseTypedef{"Name"}!~/(int|short|long|error|real|float|double|bool|boolean|pointer|count|byte|len)\d*(_t|)\Z/i
        and $BaseTypedef{"Name"}!~/char|str|size|enum/i
        and $BaseTypedef{"Name"}!~/(\A|::)u(32|64)/i)
        { # try to initialize typedefs to intrinsic types
            my $Global_State1 = save_state();
            my %Init_Desc_Copy = %Init_Desc;
            $Init_Desc_Copy{"InLine"} = 0 if($Init_Desc{"ParamName"}!~/\Ap\d+\Z/);
            $Init_Desc_Copy{"TypeId"} = $RealTypeId;
            restore_state($Global_State);
            %Type_Init = initializeIntrinsic(%Init_Desc_Copy);
            if($Type_Init{"IsCorrect"})
            {
                if($Init_Desc{"FoundationType_Type"} ne "Array") {
                    pop(@RecurTypeId);
                }
                return %Type_Init;
            }
            else {
                restore_state($Global_State1);
            }
        }
    }
    if(($Init_Desc{"Value"} ne "no value") and ($Init_Desc{"Value"} ne ""))
    { # try to initialize type by value
        %Type_Init = initializeByValue(%Init_Desc);
        $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
        if($Init_Desc{"FoundationType_Type"} ne "Array") {
            pop(@RecurTypeId);
        }
        return %Type_Init;
    }
    else {
        %Type_Init = selectInitializingWay(%Init_Desc);
    }
    if($Type_Init{"IsCorrect"})
    {
        $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
        if($Init_Desc{"FoundationType_Type"} ne "Array") {
            pop(@RecurTypeId);
        }
        return %Type_Init;
    }
    else {
        restore_state($Global_State);
    }
    if($Init_Desc{"TypeId_Changed"})
    {
        $Init_Desc{"TypeId"} = $Init_Desc{"TypeId_Changed"};
        %Init_Desc = add_VirtualSpecType(%Init_Desc);
        if(($Init_Desc{"Value"} ne "no value") and ($Init_Desc{"Value"} ne ""))
        { # try to initialize type by value
            %Type_Init = initializeByValue(%Init_Desc);
            $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
            if($Init_Desc{"FoundationType_Type"} ne "Array") {
                pop(@RecurTypeId);
            }
            return %Type_Init;
        }
    }
    # finally initializing by null (0)
    %Init_Desc = add_NullSpecType(%Init_Desc);
    if($Init_Desc{"OnlyDecl"})
    {
        %Type_Init = emptyDeclaration(%Init_Desc);
        $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
        if($Init_Desc{"FoundationType_Type"} ne "Array") {
            pop(@RecurTypeId);
        }
        return %Type_Init;
    }
    elsif(($Init_Desc{"Value"} ne "no value") and ($Init_Desc{"Value"} ne ""))
    {
        %Type_Init = initializeByValue(%Init_Desc);
        $Type_Init{"Headers"} = addHeaders($Init_Desc{"Headers"}, $Type_Init{"Headers"});
        if($Init_Desc{"FoundationType_Type"} ne "Array") {
            pop(@RecurTypeId);
        }
        return %Type_Init;
    }
    else
    {
        if($Init_Desc{"FoundationType_Type"} ne "Array") {
            pop(@RecurTypeId);
        }
        return ();
    }
}

sub selectInitializingWay(@)
{
    my %Init_Desc = @_;
    if($Init_Desc{"FoundationType_Type"} eq "Class") {
        return initializeClass(%Init_Desc);
    }
    elsif($Init_Desc{"FoundationType_Type"} eq "Intrinsic") {
        return initializeIntrinsic(%Init_Desc);
    }
    elsif($Init_Desc{"FoundationType_Type"} eq "Struct") {
        return initializeStruct(%Init_Desc);
    }
    elsif($Init_Desc{"FoundationType_Type"} eq "Union") {
        return initializeUnion(%Init_Desc);
    }
    elsif($Init_Desc{"FoundationType_Type"} eq "Enum") {
        return initializeEnum(%Init_Desc);
    }
    elsif($Init_Desc{"FoundationType_Type"} eq "Array") {
        return initializeArray(%Init_Desc);
    }
    elsif($Init_Desc{"FoundationType_Type"} eq "FuncPtr") {
        return initializeFuncPtr(%Init_Desc);
    }
    else {
        return ();
    }
}

sub is_const_type($)
{ # char const*
  #! char*const
    my $TypeName = uncover_typedefs($_[0]);
    return ($TypeName=~/(\W|\A)const(\W)/);
}

sub clearSyntax($)
{
    my $Expression = $_[0];
    $Expression=~s/\*\&//g;
    $Expression=~s/\&\*//g;
    $Expression=~s/\(\*(\w+)\)\./$1\-\>/ig;
    $Expression=~s/\(\&(\w+)\)\-\>/$1\./ig;
    $Expression=~s/\*\(\&(\w+)\)/$1/ig;
    $Expression=~s/\*\(\(\&(\w+)\)\)/$1/ig;
    $Expression=~s/\&\(\*(\w+)\)/$1/ig;
    $Expression=~s/\&\(\(\*(\w+)\)\)/$1/ig;
    $Expression=~s/(?<=[\s()])\(([a-z_]\w*)\)[ ]*,/$1,/ig;
    $Expression=~s/,(\s*)\(([a-z_]\w*)\)[ ]*(\)|,)/,$1$2/ig;
    $Expression=~s/(?<=[^\$])\(\(([a-z_]\w*)\)\)/\($1\)/ig;
    return $Expression;
}

sub apply_default_value($$)
{
    my ($Interface, $ParamPos) = @_;
    return 0 if(defined $DisableDefaultValues);
    return 0 if(not defined $CompleteSignature{$Interface}{"Param"}{$ParamPos});
    return 0 if(not $CompleteSignature{$Interface}{"Param"}{$ParamPos}{"default"});
    if($Interface eq $TestedInterface
    or replace_c2c1($Interface) eq replace_c2c1($TestedInterface))
    { # do not use defaults for target symbol
        return 0;
    }
    return 1;
}

sub sort_AppendInsert(@)
{
    my @Interfaces = @_;
    my (@Add, @Append, @Push, @Init, @Insert) = ();
    foreach my $Interface (@Interfaces)
    {
        if($CompleteSignature{$Interface}{"ShortName"}=~/add/i) {
            push(@Add, $Interface);
        }
        elsif($CompleteSignature{$Interface}{"ShortName"}=~/append/i) {
            push(@Append, $Interface);
        }
        elsif($CompleteSignature{$Interface}{"ShortName"}=~/push/i) {
            push(@Push, $Interface);
        }
        elsif($CompleteSignature{$Interface}{"ShortName"}=~/init/i) {
            push(@Init, $Interface);
        }
        elsif($CompleteSignature{$Interface}{"ShortName"}=~/insert/) {
            push(@Insert, $Interface);
        }
    }
    return (@Add, @Append, @Push, @Init, @Insert);
}

sub get_AutoFinalCode($$)
{
    my ($Interface, $ObjectCall) = @_;
    my (@AddMethods, @AppendMethods, @PushMethods, @InitMethods, @InsertMethods) = ();
    if($CompleteSignature{$Interface}{"Constructor"})
    {
        my $ClassId = $CompleteSignature{$Interface}{"Class"};
        my @Methods = sort_AppendInsert(keys(%{$Class_Method{$ClassId}}));
        return () if($#Methods<0);
        foreach my $Method (@Methods)
        {
            my %Method_Init = callInterface((
            "Interface"=>$Method,
            "ObjectCall"=>$ObjectCall,
            "DoNotReuse"=>1,
            "InsertCall"));
            if($Method_Init{"IsCorrect"}) {
                return %Method_Init;
            }
        }
        return ();
    }
    else {
        return ();
    }
}

sub initializeParameter(@)
{
    my %ParamDesc = @_;
    my $ParamPos = $ParamDesc{"ParamPos"};
    my ($TypeOfSpecType, $SpectypeCode, $SpectypeValue);
    my (%Param_Init, $PreCondition, $PostCondition, $InitCode, $DeclCode);
    my $ObjectCall = $ParamDesc{"AccessToParam"}->{"obj"};
    my $FoundationType_Id = get_FoundationTypeId($ParamDesc{"TypeId"});
    if((not $ParamDesc{"SpecType"}) and ($ObjectCall ne "create object")
    and not $Interface_OutParam_NoUsing{$ParamDesc{"Interface"}}{$ParamDesc{"ParamName"}}
    and not $Interface_OutParam{$ParamDesc{"Interface"}}{$ParamDesc{"ParamName"}}) {
        $ParamDesc{"SpecType"} = chooseSpecType($ParamDesc{"TypeId"}, "common_param", $ParamDesc{"Interface"});
    }
    if($ParamDesc{"SpecType"} and not isCyclical(\@RecurSpecType, $ParamDesc{"SpecType"}))
    {
        $IntSpecType{$TestedInterface}{$ParamDesc{"SpecType"}} = 1;
        $SpectypeCode = $SpecType{$ParamDesc{"SpecType"}}{"GlobalCode"} if(not $SpecCode{$ParamDesc{"SpecType"}});
        $SpecCode{$ParamDesc{"SpecType"}} = 1;
        push(@RecurSpecType, $ParamDesc{"SpecType"});
        $TypeOfSpecType = get_TypeIdByName($SpecType{$ParamDesc{"SpecType"}}{"DataType"});
        $SpectypeValue = $SpecType{$ParamDesc{"SpecType"}}{"Value"};
        if($SpectypeValue=~/\A[A-Z_0-9]+\Z/
        and get_TypeType($FoundationType_Id)=~/\A(Struct|Union)\Z/i) {
            $ParamDesc{"InLine"} = 1;
        }
        $DeclCode = $SpecType{$ParamDesc{"SpecType"}}{"DeclCode"};
        if($DeclCode)
        {
            $DeclCode .= "\n";
            if($DeclCode=~/\$0/ or $DeclCode=~/\$$ParamPos(\Z|\D)/) {
                $ParamDesc{"InLine"} = 0;
            }
        }
        $InitCode = $SpecType{$ParamDesc{"SpecType"}}{"InitCode"};
        if($InitCode)
        {
            $InitCode .= "\n";
            if($InitCode=~/\$0/ or $InitCode=~/\$$ParamPos(\Z|\D)/) {
                $ParamDesc{"InLine"} = 0;
            }
        }
        $Param_Init{"FinalCode"} = $SpecType{$ParamDesc{"SpecType"}}{"FinalCode"};
        if($Param_Init{"FinalCode"})
        {
            $Param_Init{"FinalCode"} .= "\n";
            if($Param_Init{"FinalCode"}=~/\$0/
            or $Param_Init{"FinalCode"}=~/\$$ParamPos(\Z|\D)/) {
                $ParamDesc{"InLine"} = 0;
            }
        }
        $PreCondition = $SpecType{$ParamDesc{"SpecType"}}{"PreCondition"};
        if($PreCondition=~/\$0/ or $PreCondition=~/\$$ParamPos(\Z|\D)/) {
            $ParamDesc{"InLine"} = 0;
        }
        $PostCondition = $SpecType{$ParamDesc{"SpecType"}}{"PostCondition"};
        if($PostCondition=~/\$0/ or $PostCondition=~/\$$ParamPos(\Z|\D)/) {
            $ParamDesc{"InLine"} = 0;
        }
        foreach my $Lib (keys(%{$SpecType{$ParamDesc{"SpecType"}}{"Libs"}})) {
            $SpecLibs{$Lib} = 1;
        }
        
    }
    elsif(apply_default_value($ParamDesc{"Interface"}, $ParamDesc{"ParamPos"}))
    {
        $Param_Init{"IsCorrect"} = 1;
        $Param_Init{"Call"} = "";
        return %Param_Init;
    }
    if(($ObjectCall ne "no object") and ($ObjectCall ne "create object"))
    {
        if(($ObjectCall=~/\A\*/) or ($ObjectCall=~/\A\&/)) {
            $ObjectCall = "(".$ObjectCall.")";
        }
        $SpectypeValue=~s/\$obj/$ObjectCall/g;
        $SpectypeValue = clearSyntax($SpectypeValue);
    }
    if($ParamDesc{"Value"} ne ""
    and $ParamDesc{"Value"} ne "no value") {
        $SpectypeValue = $ParamDesc{"Value"};
    }
    if($SpectypeValue=~/\$[^\(\[]/)
    { # access to other parameters
        foreach my $ParamKey (keys(%{$ParamDesc{"AccessToParam"}}))
        {
            my $AccessToParam_Value = $ParamDesc{"AccessToParam"}->{$ParamKey};
            $SpectypeValue=~s/\$\Q$ParamKey\E([^0-9]|\Z)/$AccessToParam_Value$1/g;
        }
    }
    if($SpectypeValue)
    {
        my %ParsedValueCode = parseCode($SpectypeValue, "Value");
        if(not $ParsedValueCode{"IsCorrect"})
        {
            pop(@RecurSpecType);
            return ();
        }
        $Param_Init{"Init"} .= $ParsedValueCode{"CodeBefore"};
        $Param_Init{"FinalCode"} .= $ParsedValueCode{"CodeAfter"};
        $SpectypeValue = $ParsedValueCode{"Code"};
        $Param_Init{"Headers"} = addHeaders($ParsedValueCode{"Headers"}, $ParsedValueCode{"Headers"});
        $Param_Init{"Code"} .= $ParsedValueCode{"NewGlobalCode"};
    }
    if(get_TypeType($FoundationType_Id)=~/\A(Struct|Class|Union)\Z/i
    and $CompleteSignature{$ParamDesc{"Interface"}}{"Constructor"}
    and get_PointerLevel($ParamDesc{"TypeId"})==0) {
        $ParamDesc{"InLine"} = 0;
    }
    if($DeclCode)
    {
        $Param_Init{"Headers"} = addHeaders(getTypeHeaders($ParamDesc{"TypeId"}), $Param_Init{"Headers"});
        $Param_Init{"Call"} = select_var_name($ParamDesc{"ParamName"}, "");
        $Param_Init{"TargetCall"} = $Param_Init{"Value"}?$Param_Init{"Value"}:$Param_Init{"Call"};
    }
    elsif($ParamDesc{"Usage"} eq "Common")
    {
        my %Type_Init = initializeType((
            "Interface" => $ParamDesc{"Interface"},
            "TypeId" => $ParamDesc{"TypeId"},
            "Key" => $ParamDesc{"Key"},
            "InLine" => $ParamDesc{"InLine"},
            "Value" => $SpectypeValue,
            "ValueTypeId" => $TypeOfSpecType,
            "TargetTypeId" => $TypeOfSpecType,
            "CreateChild" => $ParamDesc{"CreateChild"},
            "ParamName" => $ParamDesc{"ParamName"},
            "ParamPos" => $ParamDesc{"ParamPos"},
            "ConvertToBase" => $ParamDesc{"ConvertToBase"},
            "StrongConvert" => $ParamDesc{"StrongConvert"},
            "ObjectInit" => $ParamDesc{"ObjectInit"},
            "DoNotReuse" => $ParamDesc{"DoNotReuse"},
            "RetVal" => $ParamDesc{"RetVal"},
            "ParamNameExt" => $ParamDesc{"ParamNameExt"},
            "MaxParamPos" => $ParamDesc{"MaxParamPos"},
            "OuterType_Id" => $ParamDesc{"OuterType_Id"},
            "OuterType_Type" => $ParamDesc{"OuterType_Type"},
            "Index" => $ParamDesc{"Index"},
            "InLineArray" => $ParamDesc{"InLineArray"},
            "IsString" => $ParamDesc{"IsString"},
            "FuncPtrName" => $ParamDesc{"FuncPtrName"},
            "FuncPtrTypeId" => $ParamDesc{"FuncPtrTypeId"}));
        if(not $Type_Init{"IsCorrect"})
        {
            pop(@RecurSpecType);
            return ();
        }
        $Param_Init{"Init"} .= $Type_Init{"Init"};
        $Param_Init{"Call"} .= $Type_Init{"Call"};
        $Param_Init{"TargetCall"} = $Type_Init{"TargetCall"};
        $Param_Init{"Code"} .= $Type_Init{"Code"};
        $Param_Init{"Destructors"} .= $Type_Init{"Destructors"};
        $Param_Init{"FinalCode"} .= $Type_Init{"FinalCode"};
        $Param_Init{"PreCondition"} .= $Type_Init{"PreCondition"};
        $Param_Init{"PostCondition"} .= $Type_Init{"PostCondition"};
        $Param_Init{"Headers"} = addHeaders($Type_Init{"Headers"}, $Param_Init{"Headers"});
        $Param_Init{"ByNull"} = $Type_Init{"ByNull"};
    }
    else
    {
        $Param_Init{"Headers"} = addHeaders(getTypeHeaders($ParamDesc{"TypeId"}), $Param_Init{"Headers"});
        if(my $Target = $ParamDesc{"AccessToParam"}->{"0"}) {
            $Param_Init{"TargetCall"} = $Target;
        }
    }
    my $TargetCall = $Param_Init{"TargetCall"};
    if($TargetCall=~/\A(\*|\&)/) {
        $TargetCall = "(".$TargetCall.")";
    }
    if($SpectypeCode)
    {
        my $PreviousBlock = $CurrentBlock;
        $CurrentBlock = $CurrentBlock."_code_".$ParamDesc{"SpecType"};
        my %ParsedCode = parseCode($SpectypeCode, "Code");
        $CurrentBlock = $PreviousBlock;
        if(not $ParsedCode{"IsCorrect"})
        {
            pop(@RecurSpecType);
            return ();
        }
        foreach my $Header (@{$ParsedCode{"Headers"}}) {
            $SpecTypeHeaders{get_filename($Header)}=1;
        }
        $Param_Init{"Headers"} = addHeaders($ParsedCode{"Headers"}, $Param_Init{"Headers"});
        $Param_Init{"Code"} .= $ParsedCode{"NewGlobalCode"}.$ParsedCode{"Code"};
    }
    if($ObjectCall eq "create object")
    {
        $ObjectCall = $Param_Init{"Call"};
        if($ObjectCall=~/\A\*/ or $ObjectCall=~/\A\&/) {
            $ObjectCall = "(".$ObjectCall.")";
        }
    }
    if($DeclCode)
    {
        if($ObjectCall ne "no object") {
            $DeclCode=~s/\$obj/$ObjectCall/g;
        }
        $DeclCode=~s/\$0/$TargetCall/g;
        my %ParsedCode = parseCode($DeclCode, "Code");
        if(not $ParsedCode{"IsCorrect"})
        {
            pop(@RecurSpecType);
            return ();
        }
        $DeclCode = clearSyntax($DeclCode);
        $Param_Init{"Headers"} = addHeaders($ParsedCode{"Headers"}, $Param_Init{"Headers"});
        $Param_Init{"Code"} .= $ParsedCode{"NewGlobalCode"};
        $DeclCode = $ParsedCode{"Code"};
        $Param_Init{"Init"} .= "//decl code\n".$DeclCode."\n";
    }
    if($InitCode)
    {
        if($ObjectCall ne "no object") {
            $InitCode=~s/\$obj/$ObjectCall/g;
        }
        $InitCode=~s/\$0/$TargetCall/g;
        my %ParsedCode = parseCode($InitCode, "Code");
        if(not $ParsedCode{"IsCorrect"})
        {
            pop(@RecurSpecType);
            return ();
        }
        $InitCode = clearSyntax($InitCode);
        $Param_Init{"Headers"} = addHeaders($ParsedCode{"Headers"}, $Param_Init{"Headers"});
        $Param_Init{"Code"} .= $ParsedCode{"NewGlobalCode"};
        $InitCode = $ParsedCode{"Code"};
        $Param_Init{"Init"} .= "//init code\n".$InitCode."\n";
    }
    if($Param_Init{"FinalCode"})
    {
        if($ObjectCall ne "no object") {
            $Param_Init{"FinalCode"}=~s/\$obj/$ObjectCall/g;
        }
        $Param_Init{"FinalCode"}=~s/\$0/$TargetCall/g;
        my %ParsedCode = parseCode($Param_Init{"FinalCode"}, "Code");
        if(not $ParsedCode{"IsCorrect"})
        {
            pop(@RecurSpecType);
            return ();
        }
        $Param_Init{"FinalCode"} = clearSyntax($Param_Init{"FinalCode"});
        $Param_Init{"Headers"} = addHeaders($ParsedCode{"Headers"}, $Param_Init{"Headers"});
        $Param_Init{"Code"} .= $ParsedCode{"NewGlobalCode"};
        $Param_Init{"FinalCode"} = $ParsedCode{"Code"};
    }
    if(not defined $Template2Code or $ParamDesc{"Interface"} eq $TestedInterface)
    {
        $Param_Init{"PreCondition"} .= constraint_for_parameter($ParamDesc{"Interface"}, $SpecType{$ParamDesc{"SpecType"}}{"DataType"}, "precondition", $PreCondition, $ObjectCall, $TargetCall);
        $Param_Init{"PostCondition"} .= constraint_for_parameter($ParamDesc{"Interface"}, $SpecType{$ParamDesc{"SpecType"}}{"DataType"}, "postcondition", $PostCondition, $ObjectCall, $TargetCall);
    }
    pop(@RecurSpecType);
    $Param_Init{"IsCorrect"} = 1;
    return %Param_Init;
}

sub constraint_for_parameter($$$$$$)
{
    my ($Interface, $DataType, $ConditionType, $Condition, $ObjectCall, $TargetCall) = @_;
    return "" if(not $Interface or not $ConditionType or not $Condition);
    my $Condition_Comment = $Condition;
    $Condition_Comment=~s/\$obj/$ObjectCall/g if($ObjectCall ne "no object" and $ObjectCall ne "");
    $Condition_Comment=~s/\$0/$TargetCall/g if($TargetCall ne "");
    $Condition_Comment = clearSyntax($Condition_Comment);
    $Condition = $Condition_Comment;
    while($Condition_Comment=~s/([^\\])"/$1\\\"/g){}
    $ConstraintNum{$Interface}+=1;
    my $ParameterObject = ($ObjectCall eq "create object")?"object":"parameter";
    $RequirementsCatalog{$Interface}{$ConstraintNum{$Interface}} = "$ConditionType for the $ParameterObject: \'$Condition_Comment\'";
    my $ReqId = get_ShortName($Interface).".".normalize_num($ConstraintNum{$Interface});
    if(my $Format = is_printable($DataType))
    {
        my $Comment = "$ConditionType for the $ParameterObject failed: \'$Condition_Comment\', parameter value: $Format";
        $TraceFunc{"REQva"}=1;
        return "REQva(\"$ReqId\",\n$Condition,\n\"$Comment\",\n$TargetCall);\n";
    }
    else
    {
        my $Comment = "$ConditionType for the $ParameterObject failed: \'$Condition_Comment\'";
        $TraceFunc{"REQ"}=1;
        return "REQ(\"$ReqId\",\n\"$Comment\",\n$Condition);\n";
    }
}

sub is_array_count($$)
{
    my ($ParamName_Prev, $ParamName_Next) = @_;
    return ($ParamName_Next=~/\A(\Q$ParamName_Prev\E|)[_]*(n|l|c|s)[_]*(\Q$ParamName_Prev\E|)\Z/i
    or $ParamName_Next=~/len|size|amount|count|num|number/i);
}

sub add_VirtualProxy($$$$)
{
    my ($Interface, $OutParamPos, $Order, $Step) = @_;
    return if(keys(%{$CompleteSignature{$Interface}{"Param"}})<$Step+1);
    foreach my $Param_Pos (sort {($Order eq "forward")?int($a)<=>int($b):int($b)<=>int($a)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
    {
        if(apply_default_value($Interface, $Param_Pos)) {
            next;
        }
        my $Prev_Pos = ($Order eq "forward")?$Param_Pos-$Step:$Param_Pos+$Step;
        next if(($Order eq "forward")?$Prev_Pos<0:$Prev_Pos>keys(%{$CompleteSignature{$Interface}{"Param"}})-1);
        my $ParamName = $CompleteSignature{$Interface}{"Param"}{$Param_Pos}{"name"};
        my $ParamTypeId = $CompleteSignature{$Interface}{"Param"}{$Param_Pos}{"type"};
        my $ParamTypeName = get_TypeName($ParamTypeId);
        my $ParamName_Prev = $CompleteSignature{$Interface}{"Param"}{$Prev_Pos}{"name"};
        my $ParamTypeId_Prev = $CompleteSignature{$Interface}{"Param"}{$Prev_Pos}{"type"};
        if(not $InterfaceSpecType{$Interface}{"SpecParam"}{$Param_Pos})
        {
            next if($OutParamPos ne "" and $OutParamPos==$Prev_Pos);
            my $ParamFTypeId = get_FoundationTypeId($ParamTypeId);
            if(isIntegerType(get_TypeName($ParamFTypeId)) and get_PointerLevel($ParamTypeId)==0
            and get_PointerLevel($ParamTypeId_Prev)>=1 and $ParamName_Prev
            and is_array_count($ParamName_Prev, $ParamName) and not isOutParam_NoUsing($ParamTypeId_Prev, $ParamName_Prev, $Interface)
            and not $OutParamInterface_Pos{$Interface}{$Prev_Pos} and not $OutParamInterface_Pos_NoUsing{$Interface}{$Prev_Pos})
            {
                if(isArray($ParamTypeId_Prev, $ParamName_Prev, $Interface)) {
                    $ProxyValue{$Interface}{$Param_Pos} = $DEFAULT_ARRAY_AMOUNT;
                }
                elsif(isBuffer($ParamTypeId_Prev, $ParamName_Prev, $Interface)) {
                    $ProxyValue{$Interface}{$Param_Pos} = $BUFF_SIZE;
                }
                elsif(isString($ParamTypeId_Prev, $ParamName_Prev, $Interface))
                {
                    if($ParamName_Prev=~/file|src|uri|buf|dir|url/i) {
                        $ProxyValue{$Interface}{$Param_Pos} = "1";
                    }
                    elsif($ParamName_Prev!~/\Ap\d+\Z/i) {
                        $ProxyValue{$Interface}{$Param_Pos} = length($ParamName_Prev);
                    }
                }
                elsif($ParamName_Prev=~/buf/i) {
                    $ProxyValue{$Interface}{$Param_Pos} = "1";
                }
            }
            elsif($Order eq "forward" and isString($ParamTypeId_Prev, $ParamName_Prev, $Interface)
            and ($ParamName_Prev=~/\A[_0-9]*(format|fmt)[_0-9]*\Z/i) and ($ParamTypeName eq "..."))
            {
                $ProxyValue{$Interface}{$Param_Pos-1} = "\"\%d\"";
                $ProxyValue{$Interface}{$Param_Pos} = "1";
            }
        }
    }
}

sub isExactValueAble($)
{
    my $TypeName = $_[0];
    return $TypeName=~/\A(char const\*|wchar_t const\*|wint_t|int|bool|double|float|long double|char|long|long long|long long int|long int)\Z/;
}

sub select_obj_name($$)
{
    my ($Key, $ClassId) = @_;
    my $ClassName = get_TypeName($ClassId);
    if(my $NewName = getParamNameByTypeName($ClassName)) {
        return $NewName;
    }
    else {
        return (($Key)?"src":"obj");
    }
}

sub getParamNameByTypeName($)
{
    my $TypeName = get_type_short_name(remove_quals($_[0]));
    return "" if(not $TypeName or $TypeName=~/\(|\)|<|>/);
    while($TypeName=~s/\A\w+\:\://g){ };
    while($TypeName=~s/(\*|\&|\[|\])//g){ };
    $TypeName=~s/(\A\s+|\s+\Z)//g;
    return "Db" if($TypeName eq "sqlite3");
    return "tif" if($TypeName eq "TIFF");
    my $ShortTypeName = cut_NamePrefix($TypeName);
    if($ShortTypeName ne $TypeName
    and is_allowed_var_name(lc($ShortTypeName)))
    {
        $TypeName = $ShortTypeName;
        return lc($ShortTypeName);
    }
    if($TypeName=~/[A-Z]+/)
    {
        if(is_allowed_var_name(lc($TypeName))) {
            return lc($TypeName);
        }
    }
    return "";
}

sub is_allowed_var_name($)
{
    my $Candidate = $_[0];
    return (not $IsKeyword{$Candidate} and not $TName_Tid{$Candidate}
    and not $NameSpaces{$Candidate} and not $EnumMembers{$Candidate}
    and not $GlobalDataNames{$Candidate} and not $FuncNames{$Candidate});
}

sub callInterfaceParameters_m(@)
{
    my %Init_Desc = @_;
    my (@ParamList, %ParametersOrdered, %Params_Init, $IsWrapperCall);
    my ($Interface, $Key, $ObjectCall) = ($Init_Desc{"Interface"}, $Init_Desc{"Key"}, $Init_Desc{"ObjectCall"});
    add_VirtualProxy($Interface, $Init_Desc{"OutParam"},  "forward", 1);
    add_VirtualProxy($Interface, $Init_Desc{"OutParam"},  "forward", 2);
    add_VirtualProxy($Interface, $Init_Desc{"OutParam"}, "backward", 1);
    add_VirtualProxy($Interface, $Init_Desc{"OutParam"}, "backward", 2);
    my (%KeyTable, %AccessToParam, %TargetAccessToParam, %InvOrder, %Interface_Init, $SubClasses_Before) = ();
    $AccessToParam{"obj"} = $ObjectCall;
    $TargetAccessToParam{"obj"} = $ObjectCall;
    return () if(needToInherit($Interface) and isInCharge($Interface));
    $Interface_Init{"Headers"} = addHeaders([$CompleteSignature{$Interface}{"Header"}], $Interface_Init{"Headers"});
    if(not $CompleteSignature{$Interface}{"Constructor"}
    and not $CompleteSignature{$Interface}{"Destructor"}) {
        $Interface_Init{"Headers"} = addHeaders(getTypeHeaders($CompleteSignature{$Interface}{"Return"}), $Interface_Init{"Headers"});
    }
    my $ShortName = $CompleteSignature{$Interface}{"ShortName"};
    if($CompleteSignature{$Interface}{"Constructor"}) {
        $Interface_Init{"Call"} .= get_TypeName($CompleteSignature{$Interface}{"Class"});
    }
    else {
        $Interface_Init{"Call"} .= $ShortName;
    }
    my $IsWrapperCall = (($CompleteSignature{$Interface}{"Protected"}) and (not $CompleteSignature{$Interface}{"Constructor"}));
    if($IsWrapperCall)
    {
        $Interface_Init{"Call"} .= "_Wrapper";
        $Interface_Init{"Call"} = cleanName($Interface_Init{"Call"});
        @{$SubClasses_Before}{keys %Create_SubClass} = values %Create_SubClass;
        %Create_SubClass = ();
    }
    my $NumOfParams = getNumOfParams($Interface);
    # detecting inline parameters
    my %InLineParam = detectInLineParams($Interface);
    my %Order = detectParamsOrder($Interface);
    @InvOrder{values %Order} = keys %Order;
    foreach my $Param_Pos (sort {int($a)<=>int($b)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
    {
        $ParametersOrdered{$Order{$Param_Pos + 1} - 1}{"type"} = $CompleteSignature{$Interface}{"Param"}{$Param_Pos}{"type"};
        $ParametersOrdered{$Order{$Param_Pos + 1} - 1}{"name"} = $CompleteSignature{$Interface}{"Param"}{$Param_Pos}{"name"};
    }
    # initializing parameters
    if(keys(%{$CompleteSignature{$Interface}{"Param"}})>0
    and defined $CompleteSignature{$Interface}{"Param"}{0})
    {
        my $MaxParamPos = keys(%{$CompleteSignature{$Interface}{"Param"}}) - 1;
        foreach my $Param_Pos (sort {int($a)<=>int($b)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
        {
            next if($Param_Pos eq "");
            my $TruePos = $InvOrder{$Param_Pos + 1} - 1;
            my $TypeId = $ParametersOrdered{$Param_Pos}{"type"};
            my $TypeName = get_TypeName($TypeId);
            
            my $FTypeId = get_FoundationTypeId($TypeId);
            
            my $Param_Name = $ParametersOrdered{$Param_Pos}{"name"};
            if($Param_Name=~/\Ap\d+\Z/
            and (my $NewParamName = getParamNameByTypeName($TypeName))) {
                $Param_Name = $NewParamName;
            }
            my $Param_Name_Ext = "";
            if(is_used_var($CurrentBlock, $Param_Name) and not $LongVarNames
            and ($Key=~/(_|\A)\Q$Param_Name\E(_|\Z)/))
            {
                if($TypeName=~/string/i) {
                    $Param_Name_Ext="str";
                }
                elsif($TypeName=~/char/i) {
                    $Param_Name_Ext="ch";
                }
            }
            $Param_Name = "p".($TruePos+1) if(not $Param_Name);
            my $TypeType = get_TypeType($TypeId);
            my $TypeName_Uncovered = uncover_typedefs($TypeName);
            my $InLine = $InLineParam{$TruePos+1};
            my $StrongConvert = 0;
            if($OverloadedInterface{$Interface})
            {
                if(not isExactValueAble($TypeName_Uncovered)
                and $TypeType ne "Enum")
                {
                    # $InLine = 0;
                    $StrongConvert = 1;
                }
            }
            $InLine = 0 if(uncover_typedefs($TypeName)=~/\&/);
            $InLine = 0 if(get_TypeType($FTypeId)!~/\A(Intrinsic|Enum)\Z/ and $Param_Name!~/\Ap\d+\Z/
                and not isCyclical(\@RecurTypeId, get_TypeStackId($TypeId)));
            my $NewKey = ($Param_Name)? (($Key)?$Key."_".$Param_Name:$Param_Name) : ($Key)?$Key."_".($TruePos+1):"p".$InvOrder{$Param_Pos+1};
            my $SpecTypeId = $InterfaceSpecType{$Interface}{"SpecParam"}{$TruePos};
            my $ParamValue = "no value";
            if(defined $ProxyValue{$Interface}
            and my $PValue = $ProxyValue{$Interface}{$TruePos}) {
                $ParamValue = $PValue;
            }
            # initialize parameter
            if(($Init_Desc{"OutParam"} ne "") and $Param_Pos==$Init_Desc{"OutParam"})
            { # initializing out-parameter
                $AccessToParam{$TruePos+1} = $Init_Desc{"OutVar"};
                $TargetAccessToParam{$TruePos+1} = $Init_Desc{"OutVar"};
                if($SpecTypeId and ($SpecType{$SpecTypeId}{"InitCode"}.$SpecType{$SpecTypeId}{"FinalCode"}.$SpecType{$SpecTypeId}{"PreCondition"}.$SpecType{$SpecTypeId}{"PostCondition"})=~/\$0/)
                {
                    if(is_equal_types(get_TypeName($TypeId), $SpecType{$SpecTypeId}{"DataType"}))
                    {
                        $AccessToParam{"0"} = $Init_Desc{"OutVar"};
                        $TargetAccessToParam{"0"} = $Init_Desc{"OutVar"};
                    }
                    else
                    {
                        my ($TargetCall, $Preamble)=
                        convertTypes((
                            "InputTypeName"=>get_TypeName($TypeId),
                            "InputPointerLevel"=>get_PointerLevel($TypeId),
                            "OutputTypeId"=>get_TypeIdByName($SpecType{$SpecTypeId}{"DataType"}),
                            "Value"=>$Init_Desc{"OutVar"},
                            "Key"=>$NewKey,
                            "Destination"=>"Target",
                            "MustConvert"=>0));
                        $Params_Init{"Init"} .= $Preamble;
                        $AccessToParam{"0"} = $TargetCall;
                        $TargetAccessToParam{"0"} = $TargetCall;
                    }
                }
                my %Param_Init = initializeParameter((
                    "Interface" => $Interface,
                    "AccessToParam" => \%TargetAccessToParam,
                    "TypeId" => $TypeId,
                    "Key" => $NewKey,
                    "SpecType" => $SpecTypeId,
                    "Usage" => "OnlySpecType",
                    "ParamName" => $Param_Name,
                    "ParamPos" => $TruePos));
                $Params_Init{"Init"} .= $Param_Init{"Init"};
                $Params_Init{"Code"} .= $Param_Init{"Code"};
                $Params_Init{"FinalCode"} .= $Param_Init{"FinalCode"};
                $Params_Init{"PreCondition"} .= $Param_Init{"PreCondition"};
                $Params_Init{"PostCondition"} .= $Param_Init{"PostCondition"};
                $Interface_Init{"Headers"} = addHeaders($Param_Init{"Headers"}, $Interface_Init{"Headers"});
            }
            else
            {
                my $CreateChild = ($ShortName eq "operator=" and get_TypeName($FTypeId) eq get_TypeName($CompleteSignature{$Interface}{"Class"}) and $CompleteSignature{$Interface}{"Protected"});
                if($IsWrapperCall
                and $CompleteSignature{$Interface}{"Class"}) {
                    # push(@RecurTypeId, $CompleteSignature{$Interface}{"Class"});
                }
                my %Param_Init = initializeParameter((
                    "Interface" => $Interface,
                    "AccessToParam" => \%TargetAccessToParam,
                    "TypeId" => $TypeId,
                    "Key" => $NewKey,
                    "InLine" => $InLine,
                    "Value" => $ParamValue,
                    "CreateChild" => $CreateChild,
                    "SpecType" => $SpecTypeId,
                    "Usage" => "Common",
                    "ParamName" => $Param_Name,
                    "ParamPos" => $TruePos,
                    "StrongConvert" => $StrongConvert,
                    "DoNotReuse" => $Init_Desc{"DoNotReuse"},
                    "ParamNameExt" => $Param_Name_Ext,
                    "MaxParamPos" => $MaxParamPos));
                if($IsWrapperCall
                and $CompleteSignature{$Interface}{"Class"}) {
                    # pop(@RecurTypeId);
                }
                if(not $Param_Init{"IsCorrect"})
                {
                    foreach my $ClassId (keys(%{$SubClasses_Before})) {
                        $Create_SubClass{$ClassId} = 1;
                    }
                    return ();
                }
                my $RetParam = $Init_Desc{"RetParam"};
                if($Param_Init{"ByNull"} and ($Interface ne $TestedInterface)
                and (($ShortName=~/(\A|_)\Q$RetParam\E(\Z|_)/i and $ShortName!~/(\A|_)init(\Z|_)/i and $Param_Name!~/out|error/i)
                or is_transit_function($CompleteSignature{$Interface}{"ShortName"}))) {
                    return ();
                }
                if($Param_Init{"ByNull"}
                and $Param_Init{"InsertCall"}) {
                    return ();
                }
                $Params_Init{"Init"} .= $Param_Init{"Init"};
                $Params_Init{"Code"} .= $Param_Init{"Code"};
                $Params_Init{"Destructors"} .= $Param_Init{"Destructors"};
                $Params_Init{"FinalCode"} .= $Param_Init{"FinalCode"};
                $Params_Init{"PreCondition"} .= $Param_Init{"PreCondition"};
                $Params_Init{"PostCondition"} .= $Param_Init{"PostCondition"};
                $Interface_Init{"Headers"} = addHeaders($Param_Init{"Headers"}, $Interface_Init{"Headers"});
                $AccessToParam{$TruePos+1} = $Param_Init{"Call"};
                $TargetAccessToParam{$TruePos+1} = $Param_Init{"TargetCall"};
            }
        }
        foreach my $Param_Pos (sort {int($a)<=>int($b)} keys(%{$CompleteSignature{$Interface}{"Param"}}))
        {
            next if($Param_Pos eq "");
            my $Param_Call = $AccessToParam{$Param_Pos + 1};
            my $ParamType_Id = $CompleteSignature{$Interface}{"Param"}{$Param_Pos}{"type"};
            if((get_TypeName($ParamType_Id) ne "..." and not $CompleteSignature{$Interface}{"Param"}{$Param_Pos}{"default"})
            or $Param_Call ne "") {
                push(@ParamList, $Param_Call);
            }
        }
        my $LastParamPos = keys(%{$CompleteSignature{$Interface}{"Param"}})-1;
        my $LastTypeId = $CompleteSignature{$Interface}{"Param"}{$LastParamPos}{"type"};
        my $LastParamCall = $AccessToParam{$LastParamPos+1};
        if(get_TypeName($LastTypeId) eq "..." and $LastParamCall ne "0" and $LastParamCall ne "NULL")
        { # add sentinel to function call
          # http://www.linuxonly.nl/docs/2/2_GCC_4_warnings_about_sentinels.html
            push(@ParamList, "(char*)0");
        }
        my $Parameters_Call = "(".create_list(\@ParamList, "    ").")";
        if($IsWrapperCall)
        {
            $Interface_Init{"Call"} .= "()";
            $Wrappers{$Interface}{"Init"} = $Params_Init{"Init"};
            $Wrappers{$Interface}{"Code"} = $Params_Init{"Code"};
            $Wrappers{$Interface}{"Destructors"} = $Params_Init{"Destructors"};
            $Wrappers{$Interface}{"FinalCode"} = $Params_Init{"FinalCode"};
            $Wrappers{$Interface}{"PreCondition"} = $Params_Init{"PreCondition"};
            $Wrappers{$Interface}{"PostCondition"} = $Params_Init{"PostCondition"};
            $Wrappers{$Interface}{"Parameters_Call"} = $Parameters_Call;
            foreach my $ClassId (keys(%Create_SubClass)) {
                $Wrappers_SubClasses{$Interface}{$ClassId} = 1;
            }
        }
        else
        {
            $Interface_Init{"Call"} .= $Parameters_Call;
            $Interface_Init{"Init"} .= $Params_Init{"Init"};
            $Interface_Init{"Code"} .= $Params_Init{"Code"};
            $Interface_Init{"Destructors"} .= $Params_Init{"Destructors"};
            $Interface_Init{"FinalCode"} .= $Params_Init{"FinalCode"};
            $Interface_Init{"PreCondition"} .= $Params_Init{"PreCondition"};
            $Interface_Init{"PostCondition"} .= $Params_Init{"PostCondition"};
        }
    }
    elsif($CompleteSignature{$Interface}{"Data"})
    {
        if($IsWrapperCall) {
            $Interface_Init{"Call"} .= "()";
        }
    }
    else
    {
        $Interface_Init{"Call"} .= "()";
        $Wrappers{$Interface}{"Parameters_Call"} = "()";
    }
    if($IsWrapperCall)
    {
        foreach my $ClassId (keys(%{$SubClasses_Before})) {
            $Create_SubClass{$ClassId} = 1;
        }
    }
    # check requirement for return value
    my $SpecReturnType = $InterfaceSpecType{$Interface}{"SpecReturn"};
    if(not $SpecReturnType) {
        $SpecReturnType = chooseSpecType($CompleteSignature{$Interface}{"Return"}, "common_retval", $Interface);
    }
    $Interface_Init{"ReturnRequirement"} = requirementReturn($Interface, $CompleteSignature{$Interface}{"Return"}, $SpecReturnType, $ObjectCall);
    if($SpecReturnType)
    {
        if(my $ReturnInitCode = $SpecType{$SpecReturnType}{"InitCode"})
        {
            my %ParsedCode = parseCode($ReturnInitCode, "Code");
            if($ParsedCode{"IsCorrect"})
            {
                $Interface_Init{"Headers"} = addHeaders($ParsedCode{"Headers"}, $Interface_Init{"Headers"});
                $Interface_Init{"Code"} .= $ParsedCode{"NewGlobalCode"};
                $Interface_Init{"Init"} .= $ParsedCode{"Code"};
            }
        }
        if(my $ReturnFinalCode = $SpecType{$SpecReturnType}{"FinalCode"})
        {
            my %ParsedCode = ();
            if($Init_Desc{"RetParam"})
            {
                my $LastId = pop(@RecurTypeId);
                # add temp $retval
                $ValueCollection{$CurrentBlock}{"\$retval"} = $CompleteSignature{$Interface}{"Return"};
                # parse code using temp $retval
                %ParsedCode = parseCode($ReturnFinalCode, "Code");
                # remove temp $retval
                delete($ValueCollection{$CurrentBlock}{"\$retval"});
                push(@RecurTypeId, $LastId);
            }
            else {
                %ParsedCode = parseCode($ReturnFinalCode, "Code");
            }
            if($ParsedCode{"IsCorrect"})
            {
                $Interface_Init{"Headers"} = addHeaders($ParsedCode{"Headers"}, $Interface_Init{"Headers"});
                $Interface_Init{"Code"} .= $ParsedCode{"NewGlobalCode"};
                $Interface_Init{"ReturnFinalCode"} = $ParsedCode{"Code"};
            }
            else {
                $Interface_Init{"ReturnFinalCode"} = "";
            }
        }
    }
    foreach my $ParamId (keys %AccessToParam)
    {
        if($TargetAccessToParam{$ParamId} and ($TargetAccessToParam{$ParamId} ne "no object"))
        {
            my $AccessValue = $TargetAccessToParam{$ParamId};
            foreach my $Attr (keys(%Interface_Init)) {
                $Interface_Init{$Attr}=~s/\$\Q$ParamId\E([^0-9]|\Z)/$AccessValue$1/g;
            }
        }
    }
    $Interface_Init{"IsCorrect"} = 1;
    return %Interface_Init;
}

sub parse_param_name($$)
{
    my ($String, $Place) = @_;
    if($String=~/(([a-z_]\w+)[ ]*\(.+\))/i)
    {
        my ($Call, $Interface_ShortName) = ($1, $2);
        my $Pos = 0;
        foreach my $Part (get_Signature_Parts($Call, 0))
        {
            $Part=~s/(\A\s+|\s+\Z)//g;
            if($Part eq $Place)
            {
                if($CompleteSignature{$Interface_ShortName}) {
                    return ($CompleteSignature{$Interface_ShortName}{"Param"}{$Pos}{"name"}, $Pos, $Interface_ShortName);
                }
                else {
                    return (0, 0, "");
                }
            }
            $Pos+=1;
        }
    }
    return (0, 0, "");
}

sub parseCode_m($$)
{
    my ($Code, $Mode) = @_;
    return ("IsCorrect"=>1) if(not $Code or not $Mode);
    my ($Bracket_Num, $Code_Inlined, $NotEnded) = (0, "", 0);
    foreach my $Line (split(/\n/, $Code))
    {
        foreach my $Pos (0 .. length($Line) - 1)
        {
            my $Symbol = substr($Line, $Pos, 1);
            $Bracket_Num += 1 if($Symbol eq "(");
            $Bracket_Num -= 1 if($Symbol eq ")");
        }
        if($NotEnded and $Bracket_Num!=0) {
            $Line=~s/\A\s+/ /g;
        }
        $Code_Inlined .= $Line;
        if($Bracket_Num==0) {
            $Code_Inlined .= "\n";
        }
        else {
            $NotEnded = 1;
        }
    }
    $Code = $Code_Inlined;
    my ($AllSubCode, $ParsedCode, $Headers) = ();
    $Block_InsNum{$CurrentBlock} = 1 if(not defined $Block_InsNum{$CurrentBlock});
    if($Mode eq "Value") {
        $Code=~s/\n//g;
    }
    foreach my $String (split(/\n/, $Code))
    {
        if($String=~/\#[ \t]*include[ \t]*\<[ \t]*([^ \t]+)[ \t]*\>/)
        {
            $Headers = addHeaders($Headers, [$1]);
            next;
        }
        my ($CodeBefore, $CodeAfter) = ();
        while($String=~/(\$\(([^\$\(\)]+)\))/)
        { # parsing $(Type) constructions
            my $Replace = $1;
            my $TypeName = $2;
            my $TypeId = get_TypeIdByName($TypeName);
            my $FTypeId = get_FoundationTypeId($TypeId);
            my $NewKey = "_var".$Block_InsNum{$CurrentBlock};
            my ($FuncParamName, $FuncParamPos, $InterfaceShortName) = parse_param_name($String, $Replace);
            if($FuncParamName) {
                $NewKey = $FuncParamName;
            }
            my $InLine = 1;
            $InLine = 0 if(uncover_typedefs($TypeName)=~/\&/);
            $InLine = 0 if(get_TypeType($FTypeId)!~/\A(Intrinsic|Enum)\Z/ and $FuncParamName and $FuncParamName!~/\Ap\d+\Z/
                and not isCyclical(\@RecurTypeId, get_TypeStackId($TypeId)));
            my %Param_Init = initializeParameter((
                "AccessToParam" => {"obj"=>"no object"},
                "TypeId" => $TypeId,
                "Key" => $NewKey,
                "InLine" => $InLine,
                "Value" => "no value",
                "CreateChild" => 0,
                "SpecType" => ($FuncParamName and $InterfaceShortName)?$InterfaceSpecType{$InterfaceShortName}{"SpecParam"}{$FuncParamPos}:0,
                "Usage" => "Common",
                "ParamName" => $NewKey,
                "Interface" => $InterfaceShortName));
            return () if(not $Param_Init{"IsCorrect"} or $Param_Init{"ByNull"});
            $Block_InsNum{$CurrentBlock} += 1 if(($Param_Init{"Init"}.$Param_Init{"FinalCode"}.$Param_Init{"Code"})=~/\Q$NewKey\E/);
            $Param_Init{"Init"} = alignCode($Param_Init{"Init"}, $String, 0);
            $Param_Init{"PreCondition"} = alignCode($Param_Init{"PreCondition"}, $String, 0);
            $Param_Init{"PostCondition"} = alignCode($Param_Init{"PostCondition"}, $String, 0);
            $Param_Init{"Call"} = alignCode($Param_Init{"Call"}, $String, 1);
            substr($String, index($String, $Replace), pos($Replace) + length($Replace)) = $Param_Init{"Call"};
            $String = clearSyntax($String);
            $AllSubCode .= $Param_Init{"Code"};
            $Headers = addHeaders($Param_Init{"Headers"}, $Headers);
            $CodeBefore .= $Param_Init{"Init"}.$Param_Init{"PreCondition"};
            $CodeAfter .= $Param_Init{"PostCondition"}.$Param_Init{"FinalCode"};
        }
        while($String=~/(\$\[([^\$\[\]]+)\])/)
        { # parsing $[Interface] constructions
            my $Replace = $1;
            my $InterfaceName = $2;
            my $RetvalName = "";
            if($InterfaceName=~/\A(.+):(\w+?)\Z/)
            { # $[al_create_display:allegro_display]
                ($InterfaceName, $RetvalName) = ($1, $2);
            }
            my $NewKey = "_var".$Block_InsNum{$CurrentBlock};
            my %Interface_Init = ();
            return () if(not $InterfaceName or not $CompleteSignature{$InterfaceName});
            if($InterfaceName eq $TestedInterface)
            { # recursive call of the target interface
                substr($String, index($String, $Replace), pos($Replace) + length($Replace)) = "";
                $String = "" if($String eq ";");
                next;
            }
            if($CompleteSignature{$InterfaceName}{"Constructor"})
            {
                push(@RecurTypeId, $CompleteSignature{$InterfaceName}{"Class"});
                %Interface_Init = callInterface((
                    "Interface"=>$InterfaceName, 
                    "Key"=>$NewKey));
                pop(@RecurTypeId);
            }
            else
            {
                if($RetvalName) {
                    push(@RecurTypeId, get_TypeStackId($CompleteSignature{$InterfaceName}{"Return"}));
                }
                %Interface_Init = callInterface((
                    "Interface"=>$InterfaceName, 
                    "Key"=>$NewKey,
                    "RetParam"=>$RetvalName));
                if($RetvalName)
                {
                    pop(@RecurTypeId);
                    $Interface_Init{"ReturnFinalCode"}=~s/\$retval/$RetvalName/;
                }
            }
            return () if(not $Interface_Init{"IsCorrect"});
            $Block_InsNum{$CurrentBlock} += 1 if(($Interface_Init{"Init"}.$Interface_Init{"FinalCode"}.$Interface_Init{"ReturnFinalCode"}.$Interface_Init{"Code"})=~/\Q$NewKey\E/);
            if(($CompleteSignature{$InterfaceName}{"Constructor"}) and (needToInherit($InterfaceName)))
            { # for constructors in abstract classes
                    my $ClassName = get_TypeName($CompleteSignature{$InterfaceName}{"Class"});
                    my $ClassNameChild = getSubClassName($ClassName);
                    if($Interface_Init{"Call"}=~/\A(\Q$ClassName\E([\n]*)\()/) {
                        substr($Interface_Init{"Call"}, index($Interface_Init{"Call"}, $1), pos($1) + length($1)) = $ClassNameChild.$2."(";
                    }
                    $UsedConstructors{$CompleteSignature{$InterfaceName}{"Class"}}{$InterfaceName} = 1;
                    $IntSubClass{$TestedInterface}{$CompleteSignature{$InterfaceName}{"Class"}} = 1;
                    $Create_SubClass{$CompleteSignature{$InterfaceName}{"Class"}} = 1;
            }
            $Interface_Init{"Init"} = alignCode($Interface_Init{"Init"}, $String, 0);
            $Interface_Init{"PreCondition"} = alignCode($Interface_Init{"PreCondition"}, $String, 0);
            $Interface_Init{"PostCondition"} = alignCode($Interface_Init{"PostCondition"}, $String, 0);
            $Interface_Init{"FinalCode"} = alignCode($Interface_Init{"FinalCode"}, $String, 0);
            $Interface_Init{"ReturnFinalCode"} = alignCode($Interface_Init{"ReturnFinalCode"}, $String, 0);
            $Interface_Init{"Call"} = alignCode($Interface_Init{"Call"}, $String, 1);
            if($RetvalName)
            {
                $Block_Variable{$CurrentBlock}{$RetvalName} = 1;
                $ValueCollection{$CurrentBlock}{$RetvalName} = $CompleteSignature{$InterfaceName}{"Return"};
                $UseVarEveryWhere{$CurrentBlock}{$RetvalName} = 1;
                $Interface_Init{"Call"} = get_TypeName($CompleteSignature{$InterfaceName}{"Return"})." $RetvalName = ".$Interface_Init{"Call"};
            }
            substr($String, index($String, $Replace), pos($Replace) + length($Replace)) = $Interface_Init{"Call"};
            $AllSubCode .= $Interface_Init{"Code"};
            $Headers = addHeaders($Interface_Init{"Headers"}, $Headers);
            $CodeBefore .= $Interface_Init{"Init"}.$Interface_Init{"PreCondition"};
            $CodeAfter .= $Interface_Init{"PostCondition"}.$Interface_Init{"FinalCode"}.$Interface_Init{"ReturnFinalCode"};
        }
        $ParsedCode .= $CodeBefore.$String."\n".$CodeAfter;
        if($Mode eq "Value")
        {
            return ("NewGlobalCode" => $AllSubCode,
            "Code" => $String,
            "CodeBefore" => $CodeBefore,
            "CodeAfter" => $CodeAfter,
            "Headers" => $Headers,
            "IsCorrect" => 1);
        }
    }
    return ("NewGlobalCode" => $AllSubCode, "Code" => clearSyntax($ParsedCode), "Headers" => $Headers, "IsCorrect" => 1);
}

sub callInterface_m(@)
{
    my %Init_Desc = @_;
    my ($Interface, $Key) = ($Init_Desc{"Interface"}, $Init_Desc{"Key"});
    my $SpecObjectType = $InterfaceSpecType{$Interface}{"SpecObject"};
    my $SpecReturnType = $InterfaceSpecType{$Interface}{"SpecReturn"};
    my %Interface_Init = ();
    my $ClassName = get_TypeName($CompleteSignature{$Interface}{"Class"});
    my ($CreateChild, $CallAsGlobalData, $MethodToInitObj) = (0, 0, "Common");
    
    if(needToInherit($Interface) and isInCharge($Interface))
    { # impossible testing
        return ();
    }
    if($CompleteSignature{$Interface}{"Protected"})
    {
        if(not $CompleteSignature{$Interface}{"Constructor"}) {
            $UsedProtectedMethods{$CompleteSignature{$Interface}{"Class"}}{$Interface} = 1;
        }
        $IntSubClass{$TestedInterface}{$CompleteSignature{$Interface}{"Class"}} = 1;
        $Create_SubClass{$CompleteSignature{$Interface}{"Class"}} = 1;
        $CreateChild = 1;
    }
    if(($CompleteSignature{$Interface}{"Static"}) and (not $CompleteSignature{$Interface}{"Protected"}))
    {
        $MethodToInitObj = "OnlySpecType";
        $CallAsGlobalData = 1;
    }
    if($SpecReturnType and not isCyclical(\@RecurSpecType, $SpecReturnType))
    {
        my $SpecReturnCode = $SpecType{$SpecReturnType}{"Code"};
        if($SpecReturnCode) {
            push(@RecurSpecType, $SpecReturnType);
        }
        my $PreviousBlock = $CurrentBlock;
        $CurrentBlock = $CurrentBlock."_code_".$SpecReturnType;
        my %ParsedCode = parseCode($SpecType{$SpecReturnType}{"Code"}, "Code");
        $CurrentBlock = $PreviousBlock;
        if(not $ParsedCode{"IsCorrect"})
        {
            if($SpecReturnCode) {
                pop(@RecurSpecType);
            }
            return ();
        }
        $SpecCode{$SpecReturnType} = 1 if($ParsedCode{"Code"});
        $Interface_Init{"Code"} .= $ParsedCode{"NewGlobalCode"}.$ParsedCode{"Code"};
        $Interface_Init{"Headers"} = addHeaders($ParsedCode{"Headers"}, $Interface_Init{"Headers"});
        if($SpecReturnCode) {
            pop(@RecurSpecType);
        }
    }
    if($CompleteSignature{$Interface}{"Class"}
    and not $CompleteSignature{$Interface}{"Constructor"})
    {
        # initialize object
        my $ParamName = select_obj_name($Key, $CompleteSignature{$Interface}{"Class"});
        my $NewKey = ($Key)?$Key."_".$ParamName:$ParamName;
        if(not $SpecObjectType) {
            $SpecObjectType = chooseSpecType($CompleteSignature{$Interface}{"Class"}, "common_param", $Init_Desc{"Interface"});
        }
        my %Obj_Init = (not $Init_Desc{"ObjectCall"})?initializeParameter((
            "ParamName" => $ParamName,
            "Interface" => $Interface,
            "AccessToParam" => {"obj"=>"create object"},
            "TypeId" => $CompleteSignature{$Interface}{"Class"},
            "Key" => $NewKey,
            "InLine" => 0,
            "Value" => "no value",
            "CreateChild" => $CreateChild,
            "SpecType" => $SpecObjectType,
            "Usage" => $MethodToInitObj,
            "ConvertToBase" => (not $CompleteSignature{$Interface}{"Protected"}),
            "ObjectInit" =>1 )):("IsCorrect"=>1, "Call"=>$Init_Desc{"ObjectCall"});
        if(not $Obj_Init{"IsCorrect"})
        {
            if($Debug) {
                $DebugInfo{"Init_Class"}{get_TypeName($CompleteSignature{$Interface}{"Class"})} = 1;
            }
            return ();
        }
        $Obj_Init{"Call"} = "no object" if($CallAsGlobalData);
        # initialize parameters
        pop(@RecurInterface);
        $Init_Desc{"ObjectCall"} = $Obj_Init{"Call"} if(not $Init_Desc{"ObjectCall"});
        my %Params_Init = callInterfaceParameters(%Init_Desc);
        push(@RecurInterface, $Interface);
        return () if(not $Params_Init{"IsCorrect"});
        $Interface_Init{"ReturnRequirement"} .= $Params_Init{"ReturnRequirement"};
        $Interface_Init{"ReturnFinalCode"} .= $Params_Init{"ReturnFinalCode"};
        $Interface_Init{"Init"} .= $Obj_Init{"Init"}.$Params_Init{"Init"};
        $Interface_Init{"Destructors"} .= $Params_Init{"Destructors"}.$Obj_Init{"Destructors"};
        $Interface_Init{"Headers"} = addHeaders($Params_Init{"Headers"}, $Interface_Init{"Headers"});
        $Interface_Init{"Headers"} = addHeaders($Obj_Init{"Headers"}, $Interface_Init{"Headers"});
        $Interface_Init{"Code"} .= $Obj_Init{"Code"}.$Params_Init{"Code"};
        $Interface_Init{"PreCondition"} .= $Obj_Init{"PreCondition"}.$Params_Init{"PreCondition"};
        $Interface_Init{"PostCondition"} .= $Obj_Init{"PostCondition"}.$Params_Init{"PostCondition"};
        $Interface_Init{"FinalCode"} .= $Obj_Init{"FinalCode"}.$Params_Init{"FinalCode"};
        # target call
        if($CallAsGlobalData) {
            $Interface_Init{"Call"} = $ClassName."::".$Params_Init{"Call"};
        }
        else
        {
            if(($Obj_Init{"Call"}=~/\A\*/) or ($Obj_Init{"Call"}=~/\A\&/)) {
                $Obj_Init{"Call"} = "(".$Obj_Init{"Call"}.")";
            }
            $Interface_Init{"Call"} = $Obj_Init{"Call"}.".".$Params_Init{"Call"};
            $Interface_Init{"Call"}=~s/\(\*(\w+)\)\./$1\-\>/;
            $Interface_Init{"Call"}=~s/\(\&(\w+)\)\-\>/$1\./;
        }
        #simplify operators
        $Interface_Init{"Call"} = simplifyOperator($Interface_Init{"Call"});
        $Interface_Init{"IsCorrect"} = 1;
        return %Interface_Init;
    }
    else
    {
        pop(@RecurInterface);
        $Init_Desc{"ObjectCall"} = "no object";
        my %Params_Init = callInterfaceParameters(%Init_Desc);
        push(@RecurInterface, $Interface);
        return () if(not $Params_Init{"IsCorrect"});
        $Interface_Init{"ReturnRequirement"} .= $Params_Init{"ReturnRequirement"};
        $Interface_Init{"ReturnFinalCode"} .= $Params_Init{"ReturnFinalCode"};
        $Interface_Init{"Init"} .= $Params_Init{"Init"};
        $Interface_Init{"Destructors"} .= $Params_Init{"Destructors"};
        $Interface_Init{"Headers"} = addHeaders($Params_Init{"Headers"}, $Interface_Init{"Headers"});
        $Interface_Init{"Code"} .= $Params_Init{"Code"};
        $Interface_Init{"PreCondition"} .= $Params_Init{"PreCondition"};
        $Interface_Init{"PostCondition"} .= $Params_Init{"PostCondition"};
        $Interface_Init{"FinalCode"} .= $Params_Init{"FinalCode"};
        $Interface_Init{"Call"} = $Params_Init{"Call"};
        if($CompleteSignature{$Interface}{"NameSpace"}
        and not $CompleteSignature{$Interface}{"Class"}) {
            $Interface_Init{"Call"} = $CompleteSignature{$Interface}{"NameSpace"}."::".$Interface_Init{"Call"};
        }
        $Interface_Init{"IsCorrect"} = 1;
        return %Interface_Init;
    }
}

sub simplifyOperator($)
{
    my $String = $_[0];
    if($String!~/\.operator/) {
        return $String;
    }
    return $String if($String!~/(.*)\.operator[ ]*([^()]+)\((.*)\)/);
    my $Target = $1;
    my $Operator = $2;
    my $Params = $3;
    if($Params eq "")
    {
        #prefix operator
        if($Operator=~/[a-z]/i) {
            return $String;
        }
        else {
            return $Operator.$Target;
        }
    }
    else
    {
        #postfix operator
        if($Params!~/\,/)
        {
            $Params = "" if(($Operator eq "++") or ($Operator eq "--"));
            if($Operator eq "[]") {
                return $Target."[$Params]";
            }
            else {
                return $Target.$Operator."$Params";
            }
        }
        else {
            return $Target.$Operator."($Params)";
        }
    }
}

sub callInterface(@)
{
    my %Init_Desc = @_;
    my $Interface = $Init_Desc{"Interface"};
    return () if(not $Interface);
    return () if($SkipInterfaces{$Interface});
    foreach my $SkipPattern (keys(%SkipInterfaces_Pattern)) {
        return () if($Interface=~/$SkipPattern/);
    }
    if(defined $MakeIsolated and $Symbol_Library{$Interface}
    and keys(%InterfacesList) and not $InterfacesList{$Interface}) {
        return ();
    }
    my $Global_State = save_state();
    return () if(isCyclical(\@RecurInterface, $Interface));
    push(@RecurInterface, $Interface);
    $UsedInterfaces{$Interface} = 1;
    my %Interface_Init = callInterface_m(%Init_Desc);
    if(not $Interface_Init{"IsCorrect"})
    {
        pop(@RecurInterface);
        restore_state($Global_State);
        return ();
    }
    pop(@RecurInterface);
    $Interface_Init{"ReturnTypeId"} = $CompleteSignature{$Interface}{"Return"};
    return %Interface_Init;
}

sub get_REQ_define($)
{
    my $Interface = $_[0];
    my $Code = "#define REQ(id, failure_comment, constraint) { \\\n";
    $Code .= "    if(!(constraint)) { \\\n";
    $Code .= "        printf(\"\%s: \%s\\n\", id, failure_comment); \\\n    } \\\n";
    $Code .= "}\n";
    $FuncNames{"REQ"} = 1;
    $Block_Variable{"REQ"}{"id"} = 1;
    $Block_Variable{"REQ"}{"failure_comment"} = 1;
    $Block_Variable{"REQ"}{"constraint"} = 1;
    return $Code;
}

sub get_REQva_define($)
{
    my $Interface = $_[0];
    my $Code = "#define REQva(id, constraint, failure_comment_fmt, ...) { \\\n";
    $Code .= "    if(!(constraint)) { \\\n";
    $Code .= "        printf(\"\%s: \"failure_comment_fmt\"\\n\", id, __VA_ARGS__); \\\n    } \\\n";
    $Code .= "}\n";
    $FuncNames{"REQva"} = 1;
    $Block_Variable{"REQva"}{"id"} = 1;
    $Block_Variable{"REQva"}{"failure_comment"} = 1;
    $Block_Variable{"REQva"}{"constraint"} = 1;
    return $Code;
}

sub parse_variables($)
{
    my $Code = $_[0];
    return () if(not $Code);
    my $Code_Copy = $Code;
    my (%Variables, %LocalFuncNames, %LocalMethodNames) = ();
    while($Code=~s/([a-z_]\w*)[ ]*\([^;{}]*\)[ \n]*\{//io) {
        $LocalFuncNames{$1} = 1;
    }
    $Code = $Code_Copy;
    while($Code=~s/\:\:([a-z_]\w*)[ ]*\([^;{}]*\)[ \n]*\{//io) {
        $LocalMethodNames{$1} = 1;
    }
    foreach my $Block (sort keys(%Block_Variable))
    {
        foreach my $Variable (sort {length($b)<=>length($a)} keys(%{$Block_Variable{$Block}}))
        {
            next if(not $Variable);
            if($Code_Copy=~/\W$Variable[ ]*(,|(\n[ ]*|)\))/) {
                $Variables{$Variable}=1;
            }
            else
            {
                next if(is_not_variable($Variable, $Code_Copy));
                next if($LocalFuncNames{$Variable} and ($Code_Copy=~/\W\Q$Variable\E[ ]*\(/ or $Code_Copy=~/\&\Q$Variable\E\W/));
                next if($LocalMethodNames{$Variable} and $Code_Copy=~/\W\Q$Variable\E[ ]*\(/);
                $Variables{$Variable}=1;
            }
        }
    }
    while($Code=~s/[ ]+([a-z_]\w*)([ ]*=|;)//io)
    {
        my $Variable = $1;
        next if(is_not_variable($Variable, $Code_Copy));
        next if($LocalFuncNames{$Variable} and ($Code_Copy=~/\W\Q$Variable\E[ ]*\(/ or $Code_Copy=~/\&\Q$Variable\E\W/));
        next if($LocalMethodNames{$Variable} and $Code_Copy=~/\W\Q$Variable\E[ ]*\(/);
        $Variables{$Variable}=1;
    }
    while($Code=~s/(\(|,)[ ]*([a-z_]\w*)[ ]*(\)|,)//io)
    {
        my $Variable = $2;
        next if(is_not_variable($Variable, $Code_Copy));
        next if($LocalFuncNames{$Variable} and ($Code_Copy=~/\W\Q$Variable\E[ ]*\(/ or $Code_Copy=~/\&\Q$Variable\E\W/));
        next if($LocalMethodNames{$Variable} and $Code_Copy=~/\W\Q$Variable\E[ ]*\(/);
        $Variables{$Variable}=1;
    }
    my @Variables = keys(%Variables);
    return @Variables;
}

sub is_not_variable($$)
{
    my ($Variable, $Code) = @_;
    return 1 if($Variable=~/\A[A-Z_]+\Z/);
    # FIXME: more appropriate constants check
    return 1 if($TName_Tid{$Variable});
    return 1 if($EnumMembers{$Variable});
    return 1 if($NameSpaces{$Variable}
    and ($Code=~/\W\Q$Variable\E\:\:/ or $Code=~/\s+namespace\s+\Q$Variable\E\s*;/));
    return 1 if($IsKeyword{$Variable} or $Variable=~/\A(\d+)\Z|_SubClass/);
    return 1 if($Constants{$Variable});
    return 1 if($GlobalDataNames{$Variable});
    return 1 if($FuncNames{$Variable} and ($Code=~/\W\Q$Variable\E[ ]*\(/ or $Code=~/\&\Q$Variable\E\W/));
    return 1 if($MethodNames{$Variable} and $Code=~/\W\Q$Variable\E[ ]*\(/);
    return 1 if($Code=~/(\-\>|\.|\:\:)\Q$Variable\E[ ]*\(/);
    return 0;
}

sub highlight_code($$)
{
    my ($Code, $Interface) = @_;
    my $Signature = get_Signature($Interface);
    my %Preprocessor = ();
    my $PreprocessorNum = 1;
    my @Lines = split(/\n/, $Code);
    foreach my $LineNum (0 .. $#Lines)
    {
        my $Line = $Lines[$LineNum];
        if($Line=~/\A[ \t]*(#.+)\Z/)
        {
            my $LineNum_Define = $LineNum;
            my $Define = $1;
            while($Define=~/\\[ \t]*\Z/)
            {
                $LineNum_Define+=1;
                $Define .= "\n".$Lines[$LineNum_Define];
            }
            if($Code=~s/\Q$Define\E/\@PREPROC_$PreprocessorNum\@/)
            {
                $Preprocessor{$PreprocessorNum} = $Define;
                $PreprocessorNum+=1;
            }
        }
    }
    my %Strings_DQ = ();
    my $StrNum_DQ = 1;
    while($Code=~s/((L|)"[^"]*")/\@STR_DQ_$StrNum_DQ\@/)
    {
        $Strings_DQ{$StrNum_DQ} = $1;
        $StrNum_DQ += 1;
    }
    my %Strings = ();
    my $StrNum = 1;
    while($Code=~s/((?<=\W)(L|)'[^']*')/\@STR_$StrNum\@/)
    {
        $Strings{$StrNum} = $1;
        $StrNum += 1;
    }
    my %Comments = ();
    my $CommentNum = 1;
    while($Code=~s/([^:]|\A)(\/\/[^\n]*)\n/$1\@COMMENT_$CommentNum\@\n/)
    {
        $Comments{$CommentNum} = $2;
        $CommentNum += 1;
    }
    if(my $ShortName = ($CompleteSignature{$Interface}{"Constructor"})?get_TypeName($CompleteSignature{$Interface}{"Class"}):$CompleteSignature{$Interface}{"ShortName"})
    { # target interface
        if($CompleteSignature{$Interface}{"Class"})
        {
            while($ShortName=~s/\A\w+\:\://g){ };
            if($CompleteSignature{$Interface}{"Constructor"}) {
                $Code=~s!(\:| new |\n    )(\Q$ShortName\E)([ \n]*\()!$1\@LT\@span\@SP\@class='targ'\@GT\@$2\@LT\@/span\@GT\@$3!g;
            }
            elsif($CompleteSignature{$Interface}{"Destructor"}) {
                $Code=~s!(\n    )(delete)([ \n]*\()!$1\@LT\@span\@SP\@class='targ'\@GT\@$2\@LT\@/span\@GT\@$3!g;
            }
            else {
                $Code=~s!(\-\>|\.|\:\:| new )(\Q$ShortName\E)([ \n]*\()!$1\@LT\@span\@SP\@class='targ'\@GT\@$2\@LT\@/span\@GT\@$3!g;
            }
        }
        else {
            $Code=~s!( )(\Q$ShortName\E)([ \n]*\()!$1\@LT\@span\@SP\@class='targ'\@GT\@$2\@LT\@/span\@GT\@$3!g;
        }
    }
    my %Variables = ();
    foreach my $Variable (parse_variables($Code))
    {
        if($Code=~s#(?<=[^\w\n.:>])($Variable)(?=\W)#\@LT\@span\@SP\@class='var'\@GT\@$1\@LT\@/span\@GT\@#g) {
            $Variables{$Variable}=1;
        }
    }
    $Code=~s!(?<=[^.\w])(bool|_Bool|_Complex|complex|void|const|int|long|short|float|double|volatile|restrict|char|unsigned|signed)(?=[^\w\=])!\@LT\@span\@SP\@class='type'\@GT\@$1\@LT\@/span\@GT\@!g;
    $Code=~s!(?<=[^.\w])(false|true|namespace|return|struct|static|enum|union|public|protected|private|delete|typedef)(?=[^\w\=])!\@LT\@span\@SP\@class='keyw'\@GT\@$1\@LT\@/span\@GT\@!g;
    if(not $Variables{"class"}) {
        $Code=~s!(?<=[^.\w])(class)(?=[^\w\=])!\@LT\@span\@SP\@class='keyw'\@GT\@$1\@LT\@/span\@GT\@!g;
    }
    if(not $Variables{"new"}) {
        $Code=~s!(?<=[^.\w])(new)(?=[^\w\=])!\@LT\@span\@SP\@class='keyw'\@GT\@$1\@LT\@/span\@GT\@!g;
    }
    $Code=~s!(?<=[^.\w])(for|if|else if)([ \n]*\()(?=[^\w\=])!\@LT\@span\@SP\@class='keyw'\@GT\@$1\@LT\@/span\@GT\@$2!g;
    $Code=~s!(?<=[^.\w])else([ \n\{]+)(?=[^\w\=])!\@LT\@span\@SP\@class='keyw'\@GT\@else\@LT\@/span\@GT\@$1!g;
    $Code=~s!(?<=[^\w\@\$])(\d+(f|L|LL|)|NULL)(?=[^\w\@\$])!\@LT\@span\@SP\@class='num'\@GT\@$1\@LT\@/span\@GT\@!g;
    $Code=~s!(?<=[^\w\@\$])(0x[a-fA-F\d]{4})(?=[^\w\@\$])!\@LT\@span\@SP\@class='num'\@GT\@$1\@LT\@/span\@GT\@!g;
    foreach my $Num (keys(%Comments))
    {
        my $String = $Comments{$Num};
        $Code=~s!\@COMMENT_$Num\@!\@LT\@span\@SP\@class='comm'\@GT\@$String\@LT\@/span\@GT\@!g;
    }
    foreach my $Num (keys(%Preprocessor))
    {
        my $Define = $Preprocessor{$Num};
        $Code=~s!\@PREPROC_$Num\@!\@LT\@span\@SP\@class='prepr'\@GT\@$Define\@LT\@/span\@GT\@!g;
    }
    foreach my $Num (keys(%Strings_DQ))
    {
        my $String = $Strings_DQ{$Num};
        $Code=~s!\@STR_DQ_$Num\@!\@LT\@span\@SP\@class='str'\@GT\@$String\@LT\@/span\@GT\@!g;
    }
    foreach my $Num (keys(%Strings))
    {
        my $String = $Strings{$Num};
        $Code=~s!\@STR_$Num\@!\@LT\@span\@SP\@class='str'\@GT\@$String\@LT\@/span\@GT\@!g;
    }
    $Code =~ s!\[\]![\@LT\@span\@SP\@style='padding-left:2px;'\@GT\@]\@LT\@/span\@GT\@!g;
    $Code =~ s!\(\)!(\@LT\@span\@SP\@style='padding-left:2px;'\@GT\@)\@LT\@/span\@GT\@!g;
    return $Code;
}

sub is_process_running($)
{
    my ($PID, $procname) = @_;
    if (!-e "/proc/$PID") {
        return 0;
    }
    open(FILE, "/proc/$PID/stat") or return 0;
    my $info = <FILE>;
    close(FILE);
    if ($info=~/^\d+\s+\((.*)\)\s+(\S)\s+[^\(\)]+$/) {
        return ($2 ne 'Z');
    }
    else {
        return 0;
    }
}

sub kill_all_childs($)
{
    my $root_pid = $_[0];
    return if(not $root_pid);
    # Build the list of processes to be killed.
    # Sub-tree of this particular process is excluded so that it could finish its work.
    my %children = ();
    my %parent = ();
    # Read list of all currently running processes
    if(!opendir(PROC_DIR, "/proc"))
    {
        kill(9, $root_pid);
        return;
    }
    my @all_pids = grep(/^\d+$/, readdir(PROC_DIR));
    closedir(PROC_DIR);
    # Build the parent-child tree and get command lines
    foreach my $pid (@all_pids)
    {
        if (open(PID_FILE, "/proc/$pid/stat"))
        {
            my $info = <PID_FILE>;
            close(PID_FILE);
            if ($info=~/^\d+\s+\((.*)\)\s+\S\s+(\d+)\s+[^\(\)]+$/)
            {
                my $ppid = $2;
                $parent{$pid} = $ppid;
                if (!defined($children{$ppid})) {
                    $children{$ppid} = [];
                }
                push @{$children{$ppid}}, $pid;
            }
        }
    }
    # Get the plain list of processes to kill (breadth-first tree-walk)
    my @kill_list = ($root_pid);
    for (my $i = 0; $i < scalar(@kill_list); ++$i)
    {
        my $pid = $kill_list[$i];
        if ($children{$pid})
        {
            foreach (@{$children{$pid}}) {
                push @kill_list, $_;
            }
        }
    }
    # Send TERM signal to all processes
    foreach (@kill_list) {
        kill("SIGTERM", $_);
    }
    # Try 20 times, waiting 0.3 seconds each time, for all the processes to be really dead.
    my %death_check = map { $_ => 1 } @kill_list;
    for (my $i = 0; $i < 20; ++$i)
    {
        foreach (keys %death_check)
        {
            if (!is_process_running($_)) {
                delete $death_check{$_};
            }
        }
        if (scalar(keys %death_check) == 0) {
            last;
        }
        else {
            select(undef, undef, undef, 0.3);
        }
    }
}

sub filt_output($)
{
    my $Output = $_[0];
    return $Output if(not keys(%SkipWarnings) and not keys(%SkipWarnings_Pattern));
    my @NewOutput = ();
    foreach my $Line (split(/\n/, $Output))
    {
        my $IsMatched = 0;
        foreach my $Warning (keys(%SkipWarnings))
        {
            if($Line=~/\Q$Warning\E/) {
                $IsMatched = 1;
            }
        }
        foreach my $Warning (keys(%SkipWarnings_Pattern))
        {
            if($Line=~/$Warning/) {
                $IsMatched = 1;
            }
        }
        if(not $IsMatched) {
            push(@NewOutput, $Line);
        }
    }
    my $FinalOut = join("\n", @NewOutput);
    $FinalOut=~s/\A[\n]+//g;
    return $FinalOut;
}

sub createTestRunner()
{ # C-utility to run tests under Windows

    # remove old stuff
    rmtree("test_runner/");
    
    writeFile("test_runner/test_runner.cpp","
    #include <windows.h>
    #include <stdio.h>
    int main(int argc, char *argv[])
    {
        char* cmd = argv[1];
        char* directory = argv[2];
        char* res = argv[3];
        STARTUPINFO si;
        PROCESS_INFORMATION pi;
        ZeroMemory( &si, sizeof(STARTUPINFO));
        si.cb = sizeof(STARTUPINFO);
        ZeroMemory( &pi, sizeof(PROCESS_INFORMATION));
        if(CreateProcess(NULL, cmd, NULL, NULL, FALSE, DEBUG_PROCESS,
        NULL, directory, &si, &pi) == 0) {
            return 1;
        }
        FILE * result = fopen(res, \"w+\");
        if(result==NULL) {
            return 1;
        }
        DEBUG_EVENT de;
        DWORD ecode;
        int done = 0;
        for(;;)
        {
            if(WaitForDebugEvent(&de, INFINITE)==0)
                break;
            switch (de.dwDebugEventCode)
            {
                case EXCEPTION_DEBUG_EVENT:
                    ecode = de.u.Exception.ExceptionRecord.ExceptionCode;
                    if (ecode!=EXCEPTION_BREAKPOINT &&
                    ecode!=EXCEPTION_SINGLE_STEP)
                    {
                        fprintf(result, \"\%x;0\", ecode);
                        printf(\"\%x\\n\", ecode);
                        TerminateProcess(pi.hProcess, 0);
                        done = 1;
                    }
                    break;
                case EXIT_PROCESS_DEBUG_EVENT:
                    done = 1;
            }
            if(done==1)
                break;
            ContinueDebugEvent(de.dwProcessId, de.dwThreadId, DBG_CONTINUE);
        }
        fclose(result);
        return 0;
    }
    ");
    chdir("test_runner");
    system("cl test_runner.cpp >build_log 2>&1");
    chdir($ORIG_DIR);
    if($?) {
        exitStatus("Error", "can't compile test runner\n");
    }
}

my %WindowsExceptions=(
    "c0000005" => "ACCESS_VIOLATION",
    "c00002c5" => "DATATYPE_MISALIGNMENT",
    "c000008c" => "ARRAY_BOUNDS_EXCEEDED",
    "c000008d" => "FLOAT_DENORMAL_OPERAND",
    "c000008e" => "FLOAT_DIVIDE_BY_ZERO",
    "c000008f" => "FLOAT_INEXACT_RESULT",
    "c0000090" => "FLOAT_INVALID_OPERATION",
    "c0000091" => "FLOAT_OVERFLOW",
    "c0000092" => "FLOAT_STACK_CHECK",
    "c0000093" => "FLOAT_UNDERFLOW",
    "c0000094" => "INTEGER_DIVIDE_BY_ZERO",
    "c0000095" => "INTEGER_OVERFLOW",
    "c0000096" => "PRIVILEGED_INSTRUCTION",
    "c0000006" => "IN_PAGE_ERROR",
    "c000001d" => "ILLEGAL_INSTRUCTION",
    "c0000025" => "NONCONTINUABLE_EXCEPTION",
    "c00000fd" => "STACK_OVERFLOW",
    "c0000026" => "INVALID_DISPOSITION",
    "80000001" => "GUARD_PAGE_VIOLATION",
    "c0000008" => "INVALID_HANDLE",
    "c0000135" => "DLL_NOT_FOUND"
);

sub runTest($)
{
    my $Interface = $_[0];
    my $TestDir = $Interface_TestDir{$Interface};
    if(not $TestDir)
    {
        $ResultCounter{"Run"}{"Fail"} += 1;
        $RunResult{$Interface}{"IsCorrect"} = 0;
        $RunResult{$Interface}{"TestNotExists"} = 1;
        if($TargetInterfaceName)
        {
            printMsg("INFO", "fail");
            exitStatus("Error", "test is not generated yet");
        }
        return 1;
    }
    elsif(not -f $TestDir."/test" and not -f $TestDir."/test.exe")
    {
        $ResultCounter{"Run"}{"Fail"} += 1;
        $RunResult{$Interface}{"IsCorrect"} = 0;
        $RunResult{$Interface}{"TestNotExists"} = 1;
        if($TargetInterfaceName)
        {
            printMsg("INFO", "fail");
            exitStatus("Error", "test is not built yet");
        }
        return 1;
    }
    unlink($TestDir."/result");
    my $pid = fork();
    unless($pid)
    {
        if($OSgroup eq "windows")
        {
            my $ProcCmd = "test_runner/test_runner.exe \"".abs_path($TestDir)."/run_test.bat\" \"$TestDir\" \"".abs_path($TestDir)."/result\" >nul 2>&1";
            $ProcCmd=~s/[\/\\]/\\/g;
            system($ProcCmd);
        }
        else
        {
            my $Cmd = "";
            if($INSTALL_PREFIX) {
                $Cmd .= "INSTALL_PREFIX=\"$INSTALL_PREFIX\" ";
            }
            $Cmd .= "sh run_test.sh 2>stderr";
            
            open(STDIN,"$TMP_DIR/null");
            open(STDOUT,"$TMP_DIR/null");
            open(STDERR,"$TMP_DIR/null");
            
            setsid(); # to remove signals printing on the terminal screen
            
            chdir($TestDir);
            qx/$Cmd/; # execute
            chdir($ORIG_DIR);
            
            writeFile("$TestDir/result", $?.";".$!);
        }
        exit(0);
    }
    my $Hang = 0;
    $SIG{ALRM} = sub {
        $Hang=1;
        if($OSgroup eq "windows") {
            kill(9, $pid);
        }
        else {
            kill_all_childs($pid);
        }
    };
    alarm $HANGED_EXECUTION_TIME;
    waitpid($pid, 0);
    alarm 0;
    
    my $Result = readFile("$TestDir/result");
    unlink($TestDir."/result");
    unlink("$TestDir/output") if(not readFile("$TestDir/output"));
    unlink("$TestDir/stderr") if(not readFile("$TestDir/stderr"));
    
    my ($R_1, $R_2) = split(";", $Result);
    
    my $ErrorOut = readFile("$TestDir/output"); # checking test output
    $ErrorOut = filt_output($ErrorOut);
    
    if($ErrorOut)
    { # reduce length of the test output
        if(length($ErrorOut)>1200) {
            $ErrorOut = substr($ErrorOut, 0, 1200)." ...";
        }
    }
    if($Hang)
    {
        $ResultCounter{"Run"}{"Fail"} += 1;
        $RunResult{$Interface}{"IsCorrect"} = 0;
        $RunResult{$Interface}{"Type"} = "Hanged_Execution";
        $RunResult{$Interface}{"Info"} = "hanged execution (more than $HANGED_EXECUTION_TIME seconds)";
        $RunResult{$Interface}{"Info"} .= "\n".$ErrorOut if($ErrorOut);
    }
    elsif($R_1)
    {
        if($OSgroup eq "windows")
        {
            my $ExceptionName = $WindowsExceptions{$R_1};
            $RunResult{$Interface}{"Info"} = "received exception $ExceptionName\n";
            $RunResult{$Interface}{"Type"} = "Received_Exception";
            $RunResult{$Interface}{"Value"} = $ExceptionName;
        }
        else
        {
            if ($R_1 == -1)
            {
                $RunResult{$Interface}{"Info"} = "failed to execute: $R_2\n";
                $RunResult{$Interface}{"Type"} = "Other_Problems";
            }
            elsif (my $Signal_Num = ($R_1 & 127))
            {
                my $Signal_Name = $SigName{$Signal_Num};
                $RunResult{$Interface}{"Info"} = "received signal $Signal_Name, ".(($R_1 & 128)?"with":"without")." coredump\n";
                $RunResult{$Interface}{"Type"} = "Received_Signal";
                $RunResult{$Interface}{"Value"} = ($R_1 & 127);
            }
            else
            {
                my $Signal_Num = ($R_1 >> 8)-128;
                my $Signal_Name = $SigName{$Signal_Num};
                if($Signal_Name)
                {
                    $RunResult{$Interface}{"Info"} = "received signal $Signal_Name\n";
                    $RunResult{$Interface}{"Type"} = "Received_Signal";
                    $RunResult{$Interface}{"Value"} = $Signal_Name;
                }
                else
                {
                    $RunResult{$Interface}{"Info"} = "exited with value ".($R_1 >> 8)."\n";
                    $RunResult{$Interface}{"Type"} = "Exited_With_Value";
                    $RunResult{$Interface}{"Value"} = ($R_1 >> 8);
                }
            }
        }
        $ResultCounter{"Run"}{"Fail"} += 1;
        $RunResult{$Interface}{"IsCorrect"} = 0;
        $RunResult{$Interface}{"Info"} .= "\n".$ErrorOut if($ErrorOut);
    }
    elsif(readFile($TestDir."/output")=~/(constraint|postcondition|precondition) for the (return value|object|environment|parameter) failed/i)
    {
        $ResultCounter{"Run"}{"Fail"} += 1;
        $RunResult{$Interface}{"IsCorrect"} = 0;
        $RunResult{$Interface}{"Type"} = "Requirement_Failed";
        $RunResult{$Interface}{"Info"} .= "\n".$ErrorOut if($ErrorOut);
    }
    elsif($ErrorOut)
    {
        $ResultCounter{"Run"}{"Fail"} += 1;
        $RunResult{$Interface}{"Unexpected_Output"} = $ErrorOut;
        $RunResult{$Interface}{"Type"} = "Unexpected_Output";
        $RunResult{$Interface}{"Info"} = $ErrorOut;
    }
    else
    {
        $ResultCounter{"Run"}{"Success"} += 1;
        $RunResult{$Interface}{"IsCorrect"} = 1;
    }
    if(not $RunResult{$Interface}{"IsCorrect"})
    {
        return 0 if(not -e $TestDir."/test.c" and not -e $TestDir."/test.cpp");
        my $ReadingStarted = 0;
        foreach my $Line (split(/\n/, readFile($TestDir."/view.html")))
        {
            if($ReadingStarted) {
                $RunResult{$Interface}{"Test"} .= $Line."\n";
            }
            if($Line eq "<!--Test-->") {
                $ReadingStarted = 1;
            }
            if($Line eq "<!--Test_End-->") {
                last;
            }
        }
        my $Test_Info = readFile($TestDir."/info");
        foreach my $Str (split(/\n/, $Test_Info))
        {
            if($Str=~/\A[ ]*([^:]*?)[ ]*\:[ ]*(.*)[ ]*\Z/i)
            {
                my ($Attr, $Value) = ($1, $2);
                if(lc($Attr) eq "header") {
                    $RunResult{$Interface}{"Header"} = $Value;
                }
                elsif(lc($Attr) eq "shared object") {
                    $RunResult{$Interface}{"SharedObject"} = $Value;
                }
                elsif(lc($Attr) eq "interface") {
                    $RunResult{$Interface}{"Signature"} = $Value;
                }
                elsif(lc($Attr) eq "short name") {
                    $RunResult{$Interface}{"ShortName"} = $Value;
                }
                elsif(lc($Attr) eq "namespace") {
                    $RunResult{$Interface}{"NameSpace"} = $Value;
                }
            }
        }
        $RunResult{$Interface}{"ShortName"} = $Interface if(not $RunResult{$Interface}{"ShortName"});
        # filtering problems
        if($RunResult{$Interface}{"Type"} eq "Exited_With_Value")
        {
            if($RunResult{$Interface}{"ShortName"}=~/exit|die|assert/i) {
                skip_problem($Interface);
            }
            else
            {
                if($RunResult{$Interface}{"Info"}!~/error while loading shared libraries/)
                {
                    mark_as_warning($Interface);
                }
            }
        }
        elsif($RunResult{$Interface}{"Type"} eq "Hanged_Execution")
        {
            if($RunResult{$Interface}{"ShortName"}=~/call|exec|acquire|start|run|loop|blocking|startblock|wait|time|show|suspend|pause/i
            or ($Interface=~/internal|private/ and $RunResult{$Interface}{"ShortName"}!~/private(.*)key/i)) {
                mark_as_warning($Interface);
            }
        }
        elsif($RunResult{$Interface}{"Type"} eq "Received_Signal")
        {
            if($RunResult{$Interface}{"ShortName"}=~/badalloc|bad_alloc|fatal|assert/i) {
                skip_problem($Interface);
            }
            elsif($Interface=~/internal|private/ and $RunResult{$Interface}{"ShortName"}!~/private(.*)key/i) {
                mark_as_warning($Interface);
            }
            elsif($RunResult{$Interface}{"Value"}!~/\A(SEGV|FPE|BUS|ILL|PIPE|SYS|XCPU|XFSZ)\Z/) {
                mark_as_warning($Interface);
            }
        }
        elsif($RunResult{$Interface}{"Type"} eq "Unexpected_Output")
        {
            if($Interface=~/print|debug|warn|message|error|fatal/i) {
                skip_problem($Interface);
            }
            else {
                mark_as_warning($Interface);
            }
        }
        elsif($RunResult{$Interface}{"Type"} eq "Other_Problems") {
            mark_as_warning($Interface);
        }
    }
    return 0;
}

sub mark_as_warning($)
{
    my $Interface = $_[0];
    $RunResult{$Interface}{"Warnings"} = 1;
    $ResultCounter{"Run"}{"Warnings"} += 1;
    $ResultCounter{"Run"}{"Fail"} -= 1;
    $ResultCounter{"Run"}{"Success"} += 1;
    $RunResult{$Interface}{"IsCorrect"} = 1;
}

sub skip_problem($)
{
    my $Interface = $_[0];
    $ResultCounter{"Run"}{"Fail"} -= 1;
    $ResultCounter{"Run"}{"Success"} += 1;
    delete($RunResult{$Interface});
    $RunResult{$Interface}{"IsCorrect"} = 1;
}

sub readScenario()
{
    foreach my $TestCase (split(/\n/, readFile($TEST_SUITE_PATH."/scenario")))
    {
        if($TestCase=~/\A(.*);(.*)\Z/) {
            $Interface_TestDir{$1} = $2;
        }
    }
}

sub write_scenario()
{
    my $TestCases = "";
    foreach my $Interface (sort {lc($a) cmp lc($b)} keys(%Interface_TestDir)) {
        $TestCases .= $Interface.";".$Interface_TestDir{$Interface}."\n";
    }
    writeFile("$TEST_SUITE_PATH/scenario", $TestCases);
}

sub buildTest($)
{
    my $Interface = $_[0];
    my $TestDir = $Interface_TestDir{$Interface};
    if(not $TestDir or not -f "$TestDir/Makefile")
    {
        $BuildResult{$Interface}{"TestNotExists"} = 1;
        if($TargetInterfaceName)
        {
            printMsg("INFO", "fail");
            exitStatus("Error", "test is not generated yet");
        }
        return 0;
    }
    
    my $MakeCmd = "make";
    
    if($OSgroup eq "windows") {
        $MakeCmd = "nmake";
    }
    
    my $Cmd = "$MakeCmd clean -f Makefile 2>build_log >$TMP_DIR/null";
    
    if($INSTALL_PREFIX) {
        $Cmd .= " && export INSTALL_PREFIX=\"$INSTALL_PREFIX\"";
    }
    
    $Cmd .= " && $MakeCmd -f Makefile 2>build_log >$TMP_DIR/null";
    
    chdir($TestDir);
    qx/$Cmd/; # execute
    chdir($ORIG_DIR);
    
    if($?)
    {
        $ResultCounter{"Build"}{"Fail"} += 1;
        $BuildResult{$Interface}{"IsCorrect"} = 0;
    }
    else
    {
        $ResultCounter{"Build"}{"Success"} += 1;
        $BuildResult{$Interface}{"IsCorrect"} = 1;
    }
    unlink("$TestDir/test.o");
    unlink("$TestDir/test.obj");
    if(not readFile("$TestDir/build_log")) {
        unlink("$TestDir/build_log");
    }
    elsif($BuildResult{$Interface}{"IsCorrect"}) {
        $BuildResult{$Interface}{"Warnings"} = 1;
    }
}

sub cleanTest($)
{
    my $Interface = $_[0];
    my $TestDir = $Interface_TestDir{$Interface};
    if(not $TestDir or not -f "$TestDir/Makefile")
    {
        $BuildResult{$Interface}{"TestNotExists"} = 1;
        if($TargetInterfaceName)
        {
            printMsg("INFO", "fail");
            exitStatus("Error", "test is not generated yet");
        }
        return 0;
    }
    unlink("$TestDir/test.o");
    unlink("$TestDir/test.obj");
    unlink("$TestDir/test");
    unlink("$TestDir/test.exe");
    unlink("$TestDir/build_log");
    unlink("$TestDir/output");
    unlink("$TestDir/stderr");
    rmtree("$TestDir/testdata");
    if($CleanSources)
    {
        foreach my $Path (cmd_find($TestDir,"f","",""))
        {
            if(get_filename($Path) ne "view.html") {
                unlink($Path);
            }
        }
    }
    return 1;
}

sub testForDestructor($)
{
    my $Interface = $_[0];
    my $ClassId = $CompleteSignature{$Interface}{"Class"};
    my $ClassName = get_TypeName($ClassId);
    my %Interface_Init = ();
    my $Var = select_obj_name("", $ClassId);
    $Block_Variable{$CurrentBlock}{$Var} = 1;
    if($Interface=~/D2/)
    {
        # push(@RecurTypeId, $ClassId);
        my %Obj_Init = findConstructor($ClassId, "");
        # pop(@RecurTypeId);
        return () if(not $Obj_Init{"IsCorrect"});
        my $ClassNameChild = getSubClassName($ClassName);
        if($Obj_Init{"Call"}=~/\A(\Q$ClassName\E([\n]*)\()/) {
            substr($Obj_Init{"Call"}, index($Obj_Init{"Call"}, $1), pos($1) + length($1)) = $ClassNameChild.$2."(";
        }
        $ClassName = $ClassNameChild;
        $UsedConstructors{$ClassId}{$Obj_Init{"Interface"}} = 1;
        $IntSubClass{$TestedInterface}{$ClassId} = 1;
        $Create_SubClass{$ClassId} = 1;
        $Interface_Init{"Init"} .= $Obj_Init{"Init"};
        # $Interface_Init{"Init"} .= "//parameter initialization\n";
        if($Obj_Init{"PreCondition"}) {
            $Interface_Init{"Init"} .= $Obj_Init{"PreCondition"};
        }
        $Interface_Init{"Init"} .= "$ClassName *$Var = new ".$Obj_Init{"Call"}.";\n";
        if($Obj_Init{"PostCondition"}) {
            $Interface_Init{"Init"} .= $Obj_Init{"PostCondition"};
        }
        if($Obj_Init{"ReturnRequirement"})
        {
            $Obj_Init{"ReturnRequirement"}=~s/(\$0|\$obj)/*$Var/gi;
            $Interface_Init{"Init"} .= $Obj_Init{"ReturnRequirement"};
        }
        if($Obj_Init{"FinalCode"})
        {
            $Interface_Init{"Init"} .= "//final code\n";
            $Interface_Init{"Init"} .= $Obj_Init{"FinalCode"}."\n";
        }
        $Interface_Init{"Headers"} = addHeaders($Obj_Init{"Headers"}, $Interface_Init{"Headers"});
        $Interface_Init{"Code"} .= $Obj_Init{"Code"};
        $Interface_Init{"Call"} = "delete($Var)";
        $UsedInterfaces{$Interface} = 1;
    }
    elsif($Interface=~/D0/)
    {
        if(isAbstractClass($ClassId))
        { # Impossible to call in-charge-deleting (D0) destructor in abstract class
            return ();
        }
        if($CompleteSignature{$Interface}{"Protected"})
        { # Impossible to call protected in-charge-deleting (D0) destructor
            return ();
        }
        # push(@RecurTypeId, $ClassId);
        my %Obj_Init = findConstructor($ClassId, "");
        # pop(@RecurTypeId);
        return () if(not $Obj_Init{"IsCorrect"});
        if($CompleteSignature{$Obj_Init{"Interface"}}{"Protected"})
        { # Impossible to call in-charge-deleting (D0) destructor in class with protected constructor
            return ();
        }
        $Interface_Init{"Init"} .= $Obj_Init{"Init"};
        if($Obj_Init{"PreCondition"}) {
            $Interface_Init{"Init"} .= $Obj_Init{"PreCondition"};
        }
        # $Interface_Init{"Init"} .= "//parameter initialization\n";
        $Interface_Init{"Init"} .= $ClassName." *$Var = new ".$Obj_Init{"Call"}.";\n";
        if($Obj_Init{"PostCondition"}) {
            $Interface_Init{"Init"} .= $Obj_Init{"PostCondition"};
        }
        if($Obj_Init{"ReturnRequirement"})
        {
            $Obj_Init{"ReturnRequirement"}=~s/(\$0|\$obj)/*$Var/gi;
            $Interface_Init{"Init"} .= $Obj_Init{"ReturnRequirement"}
        }
        if($Obj_Init{"FinalCode"})
        {
            $Interface_Init{"Init"} .= "//final code\n";
            $Interface_Init{"Init"} .= $Obj_Init{"FinalCode"}."\n";
        }
        $Interface_Init{"Headers"} = addHeaders($Obj_Init{"Headers"}, $Interface_Init{"Headers"});
        $Interface_Init{"Code"} .= $Obj_Init{"Code"};
        $Interface_Init{"Call"} = "delete($Var)";
        $UsedInterfaces{$Interface} = 1;
    }
    elsif($Interface=~/D1/)
    {
        if(isAbstractClass($ClassId))
        { # Impossible to call in-charge (D1) destructor in abstract class
            return ();
        }
        if($CompleteSignature{$Interface}{"Protected"})
        { # Impossible to call protected in-charge (D1) destructor
            return ();
        }
        # push(@RecurTypeId, $ClassId);
        my %Obj_Init = findConstructor($ClassId, "");
        # pop(@RecurTypeId);
        return () if(not $Obj_Init{"IsCorrect"});
        if($CompleteSignature{$Obj_Init{"Interface"}}{"Protected"})
        { # Impossible to call in-charge (D1) destructor in class with protected constructor
            return ();
        }
        $Interface_Init{"Init"} .= $Obj_Init{"Init"};
        # $Interface_Init{"Init"} .= "//parameter initialization\n";
        if($Obj_Init{"PreCondition"}) {
            $Interface_Init{"Init"} .= $Obj_Init{"PreCondition"};
        }
        $Interface_Init{"Init"} .= correct_init_stmt("$ClassName $Var = ".$Obj_Init{"Call"}.";\n", $ClassName, $Var);
        if($Obj_Init{"PostCondition"}) {
            $Interface_Init{"Init"} .= $Obj_Init{"PostCondition"};
        }
        if($Obj_Init{"ReturnRequirement"})
        {
            $Obj_Init{"ReturnRequirement"}=~s/(\$0|\$obj)/$Var/gi;
            $Interface_Init{"Init"} .= $Obj_Init{"ReturnRequirement"}
        }
        if($Obj_Init{"FinalCode"})
        {
            $Interface_Init{"Init"} .= "//final code\n";
            $Interface_Init{"Init"} .= $Obj_Init{"FinalCode"}."\n";
        }
        $Interface_Init{"Headers"} = addHeaders($Obj_Init{"Headers"}, $Interface_Init{"Headers"});
        $Interface_Init{"Code"} .= $Obj_Init{"Code"};
        $Interface_Init{"Call"} = ""; # auto call after construction
        $UsedInterfaces{$Interface} = 1;
    }
    $Interface_Init{"Headers"} = addHeaders([$CompleteSignature{$Interface}{"Header"}], $Interface_Init{"Headers"});
    $Interface_Init{"IsCorrect"} = 1;
    if(my $Typedef_Id = get_type_typedef($ClassId))
    {
        $Interface_Init{"Headers"} = addHeaders(getTypeHeaders($Typedef_Id), $Interface_Init{"Headers"});
        foreach my $Elem ("Call", "Init") {
            $Interface_Init{$Elem} = cover_by_typedef($Interface_Init{$Elem}, $ClassId, $Typedef_Id);
        }
    }
    else {
        $Interface_Init{"Headers"} = addHeaders(getTypeHeaders($ClassId), $Interface_Init{"Headers"});
    }
    return %Interface_Init;
}

sub testForConstructor($)
{
    my $Interface = $_[0];
    my $Ispecobjecttype = $InterfaceSpecType{$Interface}{"SpecObject"};
    my $PointerLevelTarget = get_PointerLevel($SpecType{$Ispecobjecttype}{"TypeId"});
    my $ClassId = $CompleteSignature{$Interface}{"Class"};
    my $ClassName = get_TypeName($ClassId);
    my $Var = select_obj_name("", $ClassId);
    $Block_Variable{$CurrentBlock}{$Var} = 1;
    if(isInCharge($Interface))
    {
        if(isAbstractClass($ClassId))
        { # Impossible to call in-charge constructor in abstract class
            return ();
        }
        if($CompleteSignature{$Interface}{"Protected"})
        { # Impossible to call in-charge protected constructor
            return ();
        }
    }
    my $HeapStack = ($SpecType{$Ispecobjecttype}{"TypeId"} and ($PointerLevelTarget eq 0))?"Stack":"Heap";
    my $ObjectCall = ($HeapStack eq "Stack")?$Var:"(*$Var)";
    my %Interface_Init = callInterfaceParameters((
            "Interface"=>$Interface,
            "Key"=>"",
            "ObjectCall"=>$ObjectCall));
    return () if(not $Interface_Init{"IsCorrect"});
    my $PreviousBlock = $CurrentBlock;
    $CurrentBlock = $CurrentBlock."_code_".$Ispecobjecttype;
    my %ParsedCode = parseCode($SpecType{$Ispecobjecttype}{"Code"}, "Code");
    $CurrentBlock = $PreviousBlock;
    return () if(not $ParsedCode{"IsCorrect"});
    $SpecCode{$Ispecobjecttype} = 1 if($ParsedCode{"Code"});
    $Interface_Init{"Code"} .= $ParsedCode{"NewGlobalCode"}.$ParsedCode{"Code"};
    $Interface_Init{"Headers"} = addHeaders($ParsedCode{"Headers"}, $Interface_Init{"Headers"});
    if(isAbstractClass($ClassId) or isNotInCharge($Interface) or ($CompleteSignature{$Interface}{"Protected"}))
    {
        my $ClassNameChild = getSubClassName($ClassName);
        if($Interface_Init{"Call"}=~/\A($ClassName([\n]*)\()/)
        {
            substr($Interface_Init{"Call"}, index($Interface_Init{"Call"}, $1), pos($1) + length($1)) = $ClassNameChild.$2."(";
        }
        $ClassName = $ClassNameChild;
        $UsedConstructors{$ClassId}{$Interface} = 1;
        $IntSubClass{$TestedInterface}{$ClassId} = 1;
        $Create_SubClass{$ClassId} = 1;
    }
    if($HeapStack eq "Stack") {
        $Interface_Init{"Call"} = correct_init_stmt($ClassName." $Var = ".$Interface_Init{"Call"}, $ClassName, $Var);
    }
    elsif($HeapStack eq "Heap") {
        $Interface_Init{"Call"} = $ClassName."* $Var = new ".$Interface_Init{"Call"};
    }
    if(my $Typedef_Id = get_type_typedef($ClassId))
    {
        $Interface_Init{"Headers"} = addHeaders(getTypeHeaders($Typedef_Id), $Interface_Init{"Headers"});
        foreach my $Elem ("Call", "Init") {
            $Interface_Init{$Elem} = cover_by_typedef($Interface_Init{$Elem}, $ClassId, $Typedef_Id);
        }
    }
    else {
        $Interface_Init{"Headers"} = addHeaders(getTypeHeaders($ClassId), $Interface_Init{"Headers"});
    }
    if($Ispecobjecttype and my $PostCondition = $SpecType{$Ispecobjecttype}{"PostCondition"}
    and $ObjectCall ne "" and (not defined $Template2Code or $Interface eq $TestedInterface))
    { # postcondition
        $PostCondition=~s/(\$0|\$obj)/$ObjectCall/gi;
        $PostCondition = clearSyntax($PostCondition);
        my $NormalResult = $PostCondition;
        while($PostCondition=~s/([^\\])"/$1\\\"/g){}
        $ConstraintNum{$Interface}+=1;
        my $ReqId = get_ShortName($Interface).".".normalize_num($ConstraintNum{$Interface});
        $RequirementsCatalog{$Interface}{$ConstraintNum{$Interface}} = "postcondition for the object: \'$PostCondition\'";
        my $Comment = "postcondition for the object failed: \'$PostCondition\'";
        $Interface_Init{"ReturnRequirement"} .= "REQ(\"$ReqId\",\n\"$Comment\",\n$NormalResult);\n";
        $TraceFunc{"REQ"}=1;
    }
    # init code
    my $InitCode = $SpecType{$Ispecobjecttype}{"InitCode"};
    $Interface_Init{"Init"} .= clearSyntax($InitCode);
    # final code
    my $ObjFinalCode = $SpecType{$Ispecobjecttype}{"FinalCode"};
    $ObjFinalCode=~s/(\$0|\$obj)/$ObjectCall/gi;
    $Interface_Init{"FinalCode"} .= clearSyntax($ObjFinalCode);
    return %Interface_Init;
}

sub add_VirtualTestData($$)
{
    my ($Code, $Path) = @_;
    my $RelPath = test_data_relpath("sample.txt");
    if($Code=~s/TG_TEST_DATA_(PLAIN|TEXT)_FILE/$RelPath/g)
    { # plain text files
        mkpath($Path);
        writeFile($Path."/sample.txt", "Where there's a will there's a way.");
    }
    $RelPath = test_data_abspath("sample", $Path);
    if($Code=~s/TG_TEST_DATA_ABS_FILE/$RelPath/g)
    {
        mkpath($Path);
        writeFile($Path."/sample", "Where there's a will there's a way.");
    }
    $RelPath = test_data_relpath("sample.xml");
    if($Code=~s/TG_TEST_DATA_XML_FILE/$RelPath/g)
    {
        mkpath($Path);
        writeFile($Path."/sample.xml", getXMLSample());
    }
    $RelPath = test_data_relpath("sample.html");
    if($Code=~s/TG_TEST_DATA_HTML_FILE/$RelPath/g)
    {
        mkpath($Path);
        writeFile($Path."/sample.html", getHTMLSample());
    }
    $RelPath = test_data_relpath("sample.dtd");
    if($Code=~s/TG_TEST_DATA_DTD_FILE/$RelPath/g)
    {
        mkpath($Path);
        writeFile($Path."/sample.dtd", getDTDSample());
    }
    $RelPath = test_data_relpath("sample.db");
    if($Code=~s/TG_TEST_DATA_DB/$RelPath/g)
    {
        mkpath($Path);
        writeFile($Path."/sample.db", "");
    }
    $RelPath = test_data_relpath("sample.audio");
    if($Code=~s/TG_TEST_DATA_AUDIO/$RelPath/g)
    {
        mkpath($Path);
        writeFile($Path."/sample.audio", "");
    }
    $RelPath = test_data_relpath("sample.asoundrc");
    if($Code=~s/TG_TEST_DATA_ASOUNDRC_FILE/$RelPath/g)
    {
        mkpath($Path);
        writeFile($Path."/sample.asoundrc", getASoundRCSample());
    }
    $RelPath = test_data_relpath("");
    if($Code=~s/TG_TEST_DATA_DIRECTORY/$RelPath/g)
    {
        mkpath($Path);
        writeFile($Path."/sample.txt", "Where there's a will there's a way.");
    }
    while($Code=~/TG_TEST_DATA_FILE_([A-Z]+)/)
    {
        my ($Type, $Ext) = ($1, lc($1));
        $RelPath = test_data_relpath("sample.$Ext");
        $Code=~s/TG_TEST_DATA_FILE_$Type/$RelPath/g;
        mkpath($Path);
        writeFile($Path."/sample.$Ext", "");
    }
    return $Code;
}

sub test_data_relpath($)
{
    my $File = $_[0];
    if(defined $Template2Code) {
        return "T2C_GET_DATA_PATH(\"$File\")";
    }
    else {
        return "\"testdata/$File\"";
    }
}

sub test_data_abspath($$)
{
    my ($File, $Path) = @_;
    if(defined $Template2Code) {
        return "T2C_GET_DATA_PATH(\"$File\")";
    }
    else {
        return "\"".abs_path("./")."/".$Path.$File."\"";
    }
}

sub getXMLSample()
{
    return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<note>
    <to>Tove</to>
    <from>Jani</from>
    <heading>Reminder</heading>
    <body>Don't forget me this weekend!</body>
</note>";
}

sub getHTMLSample()
{
    return "<html>
<body>
Where there's a will there's a way.
</body>
</html>";
}

sub getDTDSample()
{
    return "<!ELEMENT note (to,from,heading,body)>
<!ELEMENT to (#PCDATA)>
<!ELEMENT from (#PCDATA)>
<!ELEMENT heading (#PCDATA)>
<!ELEMENT body (#PCDATA)>";
}

sub getASoundRCSample()
{
    if(my $Sample = readFile("/usr/share/alsa/alsa.conf"))
    {
        return $Sample;
    }
    elsif(my $Sample = readFile("/etc/asound-pulse.conf"))
    {
        return $Sample;
    }
    elsif(my $Sample = readFile("/etc/asound.conf"))
    {
        return $Sample;
    }
    else
    {
        return "pcm.card0 {
    type hw
    card 0
}
ctl.card0 {
    type hw
    card 0
}";
    }
}

sub add_TestData($$)
{
    my ($Code, $Path) = @_;
    my %CopiedFiles = ();
    if($Code=~/TEST_DATA_PATH/)
    {
        if(not $TestDataPath)
        {
            printMsg("ERROR", "test data directory is not specified");
            return $Code;
        }
    }
    while($Code=~s/TEST_DATA_PATH[ ]*\([ ]*"([^\(\)]+)"[ ]*\)/test_data_relpath($1)/ge)
    {
        my $FileName = $1;
        next if($CopiedFiles{$FileName});
        mkpath($Path);
        next if(not -e $TestDataPath."/".$FileName);
        copy($TestDataPath."/".$FileName, $Path);
        $CopiedFiles{$FileName} = 1;
    }
    return $Code;
}

sub constraint_for_environment($$$)
{
    my ($Interface, $ConditionType, $Condition) = @_;
    $ConstraintNum{$Interface}+=1;
    my $ReqId = get_ShortName($Interface).".".normalize_num($ConstraintNum{$Interface});
    $RequirementsCatalog{$Interface}{$ConstraintNum{$Interface}} = "$ConditionType for the environment: \'$Condition\'";
    my $Comment = "$ConditionType for the environment failed: \'$Condition\'";
    $TraceFunc{"REQ"}=1;
    return "REQ(\"$ReqId\",\n\"$Comment\",\n$Condition);\n";
}

sub get_env_conditions($$)
{
    my ($Interface, $SpecEnv_Id) = @_;
    my %Conditions = ();
    if(my $InitCode = $SpecType{$SpecEnv_Id}{"InitCode"}) {
        $Conditions{"Preamble"} .= $InitCode."\n";
    }
    if(my $FinalCode = $SpecType{$SpecEnv_Id}{"FinalCode"}) {
        $Conditions{"Finalization"} .= $FinalCode."\n";
    }
    if(my $GlobalCode = $SpecType{$SpecEnv_Id}{"GlobalCode"}) {
        $Conditions{"Env_CommonCode"} .= $GlobalCode."\n";
        $SpecCode{$SpecEnv_Id} = 1;
    }
    if(my $PreCondition = $SpecType{$SpecEnv_Id}{"PreCondition"}) {
        $Conditions{"Env_PreRequirements"} .= constraint_for_environment($Interface, "precondition", $PreCondition);
    }
    if(my $PostCondition = $SpecType{$SpecEnv_Id}{"PostCondition"}) {
        $Conditions{"Env_PostRequirements"} .= constraint_for_environment($Interface, "postcondition", $PostCondition);
    }
    foreach my $Lib (keys(%{$SpecType{$SpecEnv_Id}{"Libs"}})) {
        $SpecLibs{$Lib} = 1;
    }
    return %Conditions;
}

sub path_format($$)
{
    my ($Path, $Fmt) = @_;
    $Path=~s/[\/\\]+\.?\Z//g;
    if($Fmt eq "windows")
    {
        $Path=~s/\//\\/g;
        $Path=lc($Path);
    }
    else
    { # forward slash to pass into MinGW GCC
        $Path=~s/\\/\//g;
    }
    return $Path;
}

sub inc_opt($$)
{
    my ($Path, $Style) = @_;
    $Path=~s/\A\"//;
    $Path=~s/\"\Z//;
    return "" if(not $Path);
    if($Style eq "GCC")
    { # GCC options
        if($OSgroup eq "windows")
        { # to MinGW GCC
            return "-I\"".path_format($Path, "unix")."\"";
        }
        elsif($OSgroup eq "macos"
        and $Path=~/\.framework\Z/)
        { # to Apple's GCC
            return "-F".esc(get_dirname($Path));
        }
        else {
            return "-I".esc($Path);
        }
    }
    elsif($Style eq "CL") {
        return "/I \"$Path\"";
    }
    return "";
}

sub esc_option($$)
{
    my ($Path, $Style) = @_;
    return "" if(not $Path);
    if($Style eq "GCC")
    { # GCC options
        if($OSgroup eq "windows")
        { # to MinGW GCC
            return "\"".path_format($Path, "unix")."\"";
        }
        else {
            return esc($Path);
        }
    }
    elsif($Style eq "CL") {
        return "\"".$Path."\"";
    }
    return "";
}

sub generateTest($)
{
    my %Result = ();
    my $Interface = $_[0];
    return () if(not $Interface);
    
    my $CommonCode = "";
    my %TestComponents = ();
    $TestedInterface = $Interface;
    $CurrentBlock = "main";
    $ValueCollection{$CurrentBlock}{"argc"} = get_TypeIdByName("int");
    $Block_Param{$CurrentBlock}{"argc"} = get_TypeIdByName("int");
    $Block_Variable{$CurrentBlock}{"argc"} = 1;
    $ValueCollection{$CurrentBlock}{"argv"} = get_TypeIdByName("char**");
    $Block_Param{$CurrentBlock}{"argv"} = get_TypeIdByName("char**");
    $Block_Variable{$CurrentBlock}{"argv"} = 1;
    
    my ($CommonPreamble, $Preamble, $Finalization, $Env_CommonCode, $Env_PreRequirements, $Env_PostRequirements) = ();
    foreach my $SpecEnv_Id (sort {int($a)<=>int($b)} (keys(%Common_SpecEnv)))
    { # common environments
        next if($Common_SpecType_Exceptions{$Interface}{$SpecEnv_Id});
        my %Conditions = get_env_conditions($Interface, $SpecEnv_Id);
        $CommonPreamble .= $Conditions{"Preamble"};# in the direct order
        $Finalization = $Conditions{"Finalization"}.$Finalization;# in the backward order
        $Env_CommonCode .= $Conditions{"Env_CommonCode"};
        $Env_PreRequirements .= $Conditions{"Env_PreRequirements"};# in the direct order
        $Env_PostRequirements = $Conditions{"Env_PostRequirements"}.$Env_PostRequirements;# in the backward order
    }
    
    # parsing of common preamble code for using
    # created variables in the following test case
    my %CommonPreamble_Parsed = parseCode($CommonPreamble, "Code");
    $CommonPreamble = $CommonPreamble_Parsed{"Code"};
    $CommonCode = $CommonPreamble_Parsed{"NewGlobalCode"}.$CommonCode;
    $TestComponents{"Headers"} = addHeaders($CommonPreamble_Parsed{"Headers"}, $TestComponents{"Headers"});
    
    # creating test case
    if($CompleteSignature{$Interface}{"Constructor"})
    {
        %TestComponents = testForConstructor($Interface);
        $CommonCode .= $TestComponents{"Code"};
    }
    elsif($CompleteSignature{$Interface}{"Destructor"})
    {
        %TestComponents = testForDestructor($Interface);
        $CommonCode .= $TestComponents{"Code"};
    }
    else
    {
        %TestComponents = callInterface((
            "Interface"=>$Interface));
        $CommonCode .= $TestComponents{"Code"};
    }
    if(not $TestComponents{"IsCorrect"})
    {
        $ResultCounter{"Gen"}{"Fail"} += 1;
        $GenResult{$Interface}{"IsCorrect"} = 0;
        return ();
    }
    if($TraceFunc{"REQ"} and not defined $Template2Code) {
        $CommonCode = get_REQ_define($Interface)."\n".$CommonCode;
    }
    if($TraceFunc{"REQva"} and not defined $Template2Code) {
        $CommonCode = get_REQva_define($Interface)."\n".$CommonCode;
    }
    
    foreach my $SpecEnv_Id (sort {int($a)<=>int($b)} (keys(%SpecEnv)))
    { # environments used in the test case
        my %Conditions = get_env_conditions($Interface, $SpecEnv_Id);
        $Preamble .= $Conditions{"Preamble"};# in the direct order
        $Finalization = $Conditions{"Finalization"}.$Finalization;# in the backward order
        $Env_CommonCode .= $Conditions{"Env_CommonCode"};
        $Env_PreRequirements .= $Conditions{"Env_PreRequirements"};# in the direct order
        $Env_PostRequirements = $Conditions{"Env_PostRequirements"}.$Env_PostRequirements;# in the backward order
    }
    
    my %Preamble_Parsed = parseCode($Preamble, "Code");
    $Preamble = $Preamble_Parsed{"Code"};
    $CommonCode = $Preamble_Parsed{"NewGlobalCode"}.$CommonCode;
    $TestComponents{"Headers"} = addHeaders($Preamble_Parsed{"Headers"}, $TestComponents{"Headers"});
    
    my %Finalization_Parsed = parseCode($Finalization, "Code");
    $Finalization = $Finalization_Parsed{"Code"};
    $CommonCode = $Finalization_Parsed{"NewGlobalCode"}.$CommonCode;
    $TestComponents{"Headers"} = addHeaders($Finalization_Parsed{"Headers"}, $TestComponents{"Headers"});
    
    my %Env_ParsedCode = parseCode($Env_CommonCode, "Code");
    $CommonCode = $Env_ParsedCode{"NewGlobalCode"}.$Env_ParsedCode{"Code"}.$CommonCode;
    $TestComponents{"Headers"} = addHeaders($Env_ParsedCode{"Headers"}, $TestComponents{"Headers"});
    foreach my $Header (@{$Env_ParsedCode{"Headers"}}) {
        $SpecTypeHeaders{get_filename($Header)}=1;
    }
    # insert subclasses
    my ($SubClasses_Code, $SubClasses_Headers) = create_SubClasses(keys(%Create_SubClass));
    $TestComponents{"Headers"} = addHeaders($SubClasses_Headers, $TestComponents{"Headers"});
    $CommonCode = $SubClasses_Code.$CommonCode;
    # close streams
    foreach my $Stream (keys(%{$OpenStreams{"main"}})) {
        $Finalization .= "fclose($Stream);\n";
    }
    # assemble test
    my ($SanityTest, $SanityTestMain, $SanityTestBody) = ();
    if($CommonPreamble.$Preamble)
    {
        $SanityTestMain .= "//preamble\n";
        $SanityTestMain .= $CommonPreamble.$Preamble."\n";
    }
    if($Env_PreRequirements) {
        $SanityTestMain .= $Env_PreRequirements."\n";
    }
    if($TestComponents{"Init"}) {
        $SanityTestBody .= $TestComponents{"Init"};
    }
    # precondition for parameters
    if($TestComponents{"PreCondition"}) {
        $SanityTestBody .= $TestComponents{"PreCondition"};
    }
    if($TestComponents{"Call"})
    {
        if($TestComponents{"ReturnRequirement"} and $CompleteSignature{$Interface}{"Return"})
        { # call interface and check return value
            my $ReturnType_Id = $CompleteSignature{$Interface}{"Return"};
            my $ReturnType_Name = $TypeInfo{$ReturnType_Id}{"Name"};
            my $ReturnType_PointerLevel = get_PointerLevel($ReturnType_Id);
            my $ReturnFType_Id = get_FoundationTypeId($ReturnType_Id);
            my $ReturnFType_Name = get_TypeName($ReturnFType_Id);
            if($ReturnFType_Name eq "void" and $ReturnType_PointerLevel==1)
            {
                my $RetVal = select_var_name("retval", "");
                $TestComponents{"ReturnRequirement"}=~s/(\$0|\$retval)/$RetVal/gi;
                $SanityTestBody .= "int* $RetVal = (int*)".$TestComponents{"Call"}."; //target call\n";
                $Block_Variable{$CurrentBlock}{$RetVal} = 1;
            }
            elsif($ReturnFType_Name eq "void" and $ReturnType_PointerLevel==0) {
                $SanityTestBody .= $TestComponents{"Call"}."; //target call\n";
            }
            else
            {
                my $RetVal = select_var_name("retval", "");
                $TestComponents{"ReturnRequirement"}=~s/(\$0|\$retval)/$RetVal/gi;
                my ($InitializedEType_Id, $Declarations, $Headers) = get_ExtTypeId($RetVal, $ReturnType_Id);
                my $InitializedType_Name = get_TypeName($InitializedEType_Id);
                $TestComponents{"Code"} .= $Declarations;
                $TestComponents{"Headers"} = addHeaders($Headers, $TestComponents{"Headers"});
                my $Break = ((length($InitializedType_Name)>20)?"\n":" ");
                my $InitializedFType_Id = get_FoundationTypeId($ReturnType_Id);
                if(($InitializedType_Name eq $ReturnType_Name)) {
                    $SanityTestBody .= $ReturnType_Name.$Break.$RetVal." = ".$TestComponents{"Call"}."; //target call\n";
                }
                else {
                    $SanityTestBody .= $InitializedType_Name.$Break.$RetVal." = "."(".$InitializedType_Name.")".$TestComponents{"Call"}."; //target call\n";
                }
                $Block_Variable{$CurrentBlock}{$RetVal} = 1;
                $TestComponents{"Headers"} = addHeaders(getTypeHeaders($InitializedFType_Id), $TestComponents{"Headers"});
            }
        }
        else {
            $SanityTestBody .= $TestComponents{"Call"}."; //target call\n";
        }
    }
    elsif($CompleteSignature{$Interface}{"Destructor"}) {
        $SanityTestBody .= "//target interface will be called at the end of main() function automatically\n";
    }
    if($TestComponents{"ReturnRequirement"}) {
        $SanityTestBody .= $TestComponents{"ReturnRequirement"}."\n";
    }
    # postcondition for parameters
    if($TestComponents{"PostCondition"}) {
        $SanityTestBody .= $TestComponents{"PostCondition"}."\n";
    }
    if($TestComponents{"FinalCode"})
    {
        $SanityTestBody .= "//final code\n";
        $SanityTestBody .= $TestComponents{"FinalCode"}."\n";
    }
    $SanityTestMain .= $SanityTestBody;
    if($Finalization)
    {
        $SanityTestMain .= "\n//finalization\n";
        $SanityTestMain .= $Finalization."\n";
    }
    if($Env_PostRequirements) {
        $SanityTestMain .= $Env_PostRequirements."\n";
    }
    if(my $AddDefines = $Descriptor{"Defines"})
    {
        $AddDefines=~s/\n\s+/\n/g;
        $SanityTest .= $AddDefines."\n";
    }
    # clear code syntax
    $SanityTestMain = alignCode($SanityTestMain, "    ", 0);
    @{$TestComponents{"Headers"}} = reverse(@{$TestComponents{"Headers"}});
    if(keys(%ConstraintNum)>0)
    {
        if(getTestLang($Interface) eq "C++")
        {
            $TestComponents{"Headers"} = addHeaders(["iostream"], $TestComponents{"Headers"});
            $AuxHeaders{"iostream"} = 1;
        }
        else
        {
            $TestComponents{"Headers"} = addHeaders(["stdio.h"], $TestComponents{"Headers"});
            $AuxHeaders{"stdio.h"} = 1;
        }
    }
    @{$TestComponents{"Headers"}} = (@Include_Preamble, @{$TestComponents{"Headers"}});
    
    if(keys(%Include_Order))
    {
        if(grep {defined $Include_Order{$_}} @{$TestComponents{"Headers"}}) {
            $TestComponents{"Headers"} = orderHeaders($TestComponents{"Headers"});
        }
    }
    
    my ($Headers, $IncPaths) = prepareHeaders(@{$TestComponents{"Headers"}});
    
    $Result{"Headers"} = [];
    my $HList = "";
    foreach my $Header (@{$Headers})
    {
        $HList .= "#include <".$Header.">\n";
        push(@{$Result{"Headers"}}, $Header);
        if($Header=~/\+\+(\.h|)\Z/) {
            $UsedInterfaces{"__gxx_personality"} = 1;
        }
    }
    $SanityTest .= $HList;
    
    my %UsedNameSpaces = ();
    foreach my $NameSpace (add_namespaces(\$CommonCode), add_namespaces(\$SanityTestMain)) {
        $UsedNameSpaces{$NameSpace} = 1;
    }
    if(keys(%UsedNameSpaces))
    {
        $SanityTest .= "\n";
        foreach my $NameSpace (sort {get_depth($a,"::")<=>get_depth($b,"::")} keys(%UsedNameSpaces)) {
            $SanityTest .= "using namespace $NameSpace;\n";
        }
        $SanityTest .= "\n";
    }
    if($CommonCode)
    {
        $SanityTest .= "\n$CommonCode\n\n";
        $Result{"Code"} = $CommonCode;
    }
    $SanityTest .= "int main(int argc, char *argv[])\n";
    $SanityTest .= "{\n";
    $Result{"main"} = correct_spaces($SanityTestMain);
    $SanityTestMain .= "    return 0;\n";
    $SanityTest .= $SanityTestMain;
    $SanityTest .= "}\n";
    $SanityTest = correct_spaces($SanityTest); # cleaning code
    if(getTestLang($Interface) eq "C++" and getSymLang($Interface) eq "C")
    { # removing extended initializer lists
        $SanityTest=~s/({\s*|\s)\.[a-z_][a-z_\d]*\s*=\s*/$1  /ig;
    }
    if(defined $Standalone)
    { # create stuff for building and running test
        my $TestFileName = (getTestLang($Interface) eq "C++")?"test.cpp":"test.c";
        my $TestPath = getTestPath($Interface);
        if(-e $TestPath) {
            rmtree($TestPath);
        }
        mkpath($TestPath);
        $Interface_TestDir{$Interface} = $TestPath;
        $SanityTest = add_VirtualTestData($SanityTest, $TestPath."/testdata/");
        $SanityTest = add_TestData($SanityTest, $TestPath."/testdata/");
        writeFile("$TestPath/$TestFileName", $SanityTest);
        my $SharedObject = $Symbol_Library{$Interface};
        $SharedObject = $DepSymbol_Library{$Interface} if(not $SharedObject);
        my $TestInfo = "Library: $TargetLibraryName-".$Descriptor{"Version"};
        $TestInfo .= "\nInterface: ".get_Signature($Interface);
        $TestInfo .= "\nSymbol: $Interface";
        
        my %SInfo = %{$CompleteSignature{$Interface}};
        
        if($Interface=~/\A(_Z|\?)/) {
            $TestInfo .= "\nShort Name: ".$SInfo{"ShortName"};
        }
        $TestInfo .= "\nHeader: ".$SInfo{"Header"};
        if($SharedObject) {
            $TestInfo .= "\nShared Object: ".get_filename($SharedObject);
        }
        my $NameSpace = select_Symbol_NS($Interface);
        if($NameSpace) {
            $TestInfo .= "\nNamespace: ".$NameSpace;
        }
        writeFile("$TestPath/info", $TestInfo);
        my $Signature = get_Signature($Interface);
        
        $Signature=~s/\s+:.+\Z//; # return value
        $Signature=~s/\s*\[[a-z\-]+\]//g; # [in-charge], [static], etc.
        if($NameSpace) {
            $Signature=~s/(\W|\A)\Q$NameSpace\E\:\:(\w)/$1$2/g;
        }
        
        my $Title = "Test for ".htmlSpecChars($Signature);
        my $Keywords = htmlSpecChars($SInfo{"ShortName"}).", unit test";
        my $Description = "Sanity test for ".htmlSpecChars($Signature);
        
        my $View = "";
        
        if(my $Class = $SInfo{"Class"})
        {
            my $ClassName = get_TypeName($Class);
            if($NameSpace) {
                $ClassName=~s/(\W|\A)\Q$NameSpace\E\:\:(\w)/$1$2/g;
            }
            if($SInfo{"Constructor"})
            { # c-tor
                $View .= "<h1>Test for c-tor of <span style='color:Red'>".htmlSpecChars($ClassName)."</span> class</h1>\n";
            }
            elsif($SInfo{"Destructor"})
            { # d-tor
                $View .= "<h1>Test for d-tor of <span style='color:Red'>".htmlSpecChars($ClassName)."</span> class</h1>\n";
            }
            else
            { # method
                $View .= "<h1>Test for <span style='color:Red'>".htmlSpecChars($SInfo{"ShortName"})."</span> method of <span style='color:Blue'>".htmlSpecChars($ClassName)."</span> class</h1>\n";
            }
        }
        else {
            $View .= "<h1>Test for <span style='color:Red'>".htmlSpecChars($SInfo{"ShortName"})."</span> function</h1>\n";
        }
        # $View .= highLight_Signature_Italic_Color($Signature)."\n";
        my $Unmangled = $tr_name{$Interface};
        if($NameSpace) {
            $Unmangled=~s/(\W|\A)\Q$NameSpace\E\:\:(\w)/$1$2/g;
        }
        $View .= "<span class='yellow'>".highLight_Signature_Italic_Color($Signature)."</span>\n";
        if($Interface=~/\A(_Z|\?)/) {
            $View .= "<br/><i><span class='yellow'>$Interface</span></i>\n";
        }
        
        # summary
        $View .= "<h2>Info</h2><hr/>\n";
        
        $View .= "<table class='summary'>\n";
        $View .= "<tr><th>Header File</th><td>".$SInfo{"Header"}."</td></tr>\n";
        
#         my $SharedObject = get_filename($Symbol_Library{$Interface});
#         $SharedObject = get_filename($DepSymbol_Library{$Interface}) if(not $SharedObject);
#         
#         if($SharedObject) {
#             $View .= "<tr><th>Library</th><td>".$SharedObject."</td></tr>\n";
#         }
        
        if($NameSpace) {
            $View .= "<tr><th>Namespace</th><td>".$NameSpace."</td></tr>\n";
        }
        if(my $Class = $SInfo{"Class"})
        {
            my $ClassName = get_TypeName($Class);
            if($NameSpace) {
                $ClassName=~s/(\W|\A)\Q$NameSpace\E\:\:(\w)/$1$2/g;
            }
            $View .= "<tr><th>Class</th><td>".htmlSpecChars($ClassName)."</td></tr>\n";
            if($SInfo{"Constructor"})
            { # c-tor
                $View .= "<tr><th>Method</th><td>Constructor</td></tr>\n";
                if(my $ChargeLevel = get_ChargeLevel($Interface)) {
                    $View .= "<tr><th>Kind</th><td>$ChargeLevel</td></tr>\n";
                }
            }
            elsif($SInfo{"Destructor"})
            { # d-tor
                $View .= "<tr><th>Method</th><td>Destructor</td></tr>\n";
                if(my $ChargeLevel = get_ChargeLevel($Interface)) {
                    $View .= "<tr><th>Kind</th><td>$ChargeLevel</td></tr>\n";
                }
            }
            else
            { # method
                $View .= "<tr><th>Method</th><td>".htmlSpecChars($SInfo{"ShortName"})."</td></tr>\n";
            }
        }
        else
        {
            $View .= "<tr><th>Function</th><td>".htmlSpecChars($SInfo{"ShortName"})."</td></tr>\n";
        }
        if(my $Return = $SInfo{"Return"})
        {
            my $ReturnType = get_TypeName($Return);
            if($NameSpace) {
                $ReturnType=~s/(\W|\A)\Q$NameSpace\E\:\:(\w)/$1$2/g;
            }
            $View .= "<tr><th>Return Type</th><td>".htmlSpecChars($ReturnType)."</td></tr>\n";
        }
        if(my @Params = keys(%{$SInfo{"Param"}})) {
            $View .= "<tr><th>Parameters</th><td><a href='#Params'>".($#Params+1)."</a></td></tr>\n";
        }
        else {
            # $View .= "<tr><th>Parameters</th><td>none</td></tr>\n";
        }
        
        $View .= "</table>\n";
        
        if(keys(%{$SInfo{"Param"}}))
        {
            $View .= "<a name='Params'></a>\n";
            $View .= "<h2>Parameters</h2><hr/>\n";
            $View .= "<table class='summary'>\n";
            $View .= "<tr><th width='20px'>#</th><th>Name</th><th>Type</th></tr>\n";
            foreach my $Pos (sort {int($a)<=>int($b)} keys(%{$SInfo{"Param"}}))
            {
                my $TName = get_TypeName($SInfo{"Param"}{$Pos}{"type"});
                if($NameSpace) {
                    $TName=~s/(\W|\A)\Q$NameSpace\E\:\:(\w)/$1$2/g;
                }
                $View .= "<tr><td>$Pos</td><td><span class='color_p'>".$SInfo{"Param"}{$Pos}{"name"}."</span></td><td>".htmlSpecChars($TName)."</td></tr>\n";
            }
            $View .= "</table>\n";
        }
        
        # code
        $View .= "<h2>Code</h2><hr/>\n";
        $View .= "<!--Test-->\n".get_TestView($SanityTest, $Interface)."<!--Test_End-->\n";
        
        my $CssStyles = readModule("Styles", "Test.css");
        $View = composeHTML_Head($Title, $Keywords, $Description, $CssStyles, "")."<body>\n".$View.getReportFooter()."\n</body>\n</html>\n";
        writeFile("$TestPath/view.html", $View);
        
        %UsedSharedObjects = ();
        
        foreach my $Sym (keys(%UsedInterfaces))
        { # add v-tables
            if(index($Sym, "C1E")!=-1
            or index($Sym, "C2E")!=-1
            or index($Sym, "C3E")!=-1
            or index($Sym, "C4E")!=-1)
            {
                if(my $VTable = getVTSymbol($Sym))
                { # guess v-table name
                    $UsedInterfaces{$VTable} = 1;
                    
                    $VTable=~s/\A_ZTVN/_ZTV/;
                    $VTable=~s/E\Z//;
                    $UsedInterfaces{$VTable} = 1;
                }
                if(my $TInfo = getTISymbol($Sym))
                { # guess typeinfo name
                    $UsedInterfaces{$TInfo} = 1;
                    
                    $TInfo=~s/\A_ZTIN/_ZTI/;
                    $UsedInterfaces{$TInfo} = 1;
                }
            }
        }
        
        # used symbols
        foreach my $Sym (keys(%UsedInterfaces))
        {
            if(my $Path = $Symbol_Library{$Sym}) {
                $UsedSharedObjects{$Path} = 1;
            }
            elsif(my $Path = $DepSymbol_Library{$Sym})
            {
                if(index(get_filename($Path), "libstdc++")!=-1)
                { # will be included by the compiler automatically
                    next;
                }
                $UsedSharedObjects{$Path} = 1;
            }
            else
            {
                # TODO
            }
        }
        
        # undefined symbols
        foreach my $Path (keys(%UsedSharedObjects))
        {
            foreach my $Dep (getLib_Deps($Path))
            { # required libraries
                $UsedSharedObjects{$Dep} = 1;
            }
        }
        
        # needed libs
        my %LibName_P = ();
        foreach my $Path (keys(%UsedSharedObjects)) {
            $LibName_P{get_filename($Path)}{$Path} = 1;
        }
        
        foreach my $Path (keys(%UsedSharedObjects))
        {
            my $Name = get_filename($Path);
            foreach my $Dep (keys(%{$Library_Needed{$Name}}))
            {
                $Dep = identifyLibrary($Dep);
                if(is_abs($Dep))
                { # links
                    $Dep = realpath($Dep);
                }
                $Dep = get_filename($Dep);
                if(defined $LibName_P{$Dep})
                {
                    my @Paths = keys(%{$LibName_P{$Dep}});
                    if($#Paths==0)
                    {
                        my $Dir = get_dirname($Paths[0]);
                        if(not grep {$Dir eq $_} @DefaultLibPaths)
                        { # non-default
                            next;
                        }
                        delete($UsedSharedObjects{$Paths[0]});
                    }
                }
            }
        }
        
        writeFile("$TestPath/Makefile", get_Makefile($Interface, $IncPaths));
        
        my $RunScript = ($OSgroup eq "windows")?"run_test.bat":"run_test.sh";
        writeFile("$TestPath/$RunScript", get_RunScript($Interface));
        chmod(0775, $TestPath."/$RunScript");
    }
    else
    { # t2c
    }
    $GenResult{$Interface}{"IsCorrect"} = 1;
    $ResultCounter{"Gen"}{"Success"} += 1;
    $Result{"IsCorrect"} = 1;
    return %Result;
}

sub getLib_Deps($)
{
    my $Path = $_[0];
    
    if(grep {$Path eq $_} @RecurLib)
    { # lock
        return ();
    }
    push(@RecurLib, $Path);
    
    my %Deps = ();
    foreach my $Sym (keys(%{$UndefinedSymbols{get_filename($Path)}}))
    {
        if(my $P = $Symbol_Library{$Sym}) {
            $Deps{$P} = 1;
        }
        elsif(my $P = $DepSymbol_Library{$Sym}) {
            $Deps{$P} = 1;
        }
        elsif(index($Sym, '@')!=-1)
        {
            $Sym=~s/\@/\@\@/;
            if(my $P = $Symbol_Library{$Sym}) {
                $Deps{$P} = 1;
            }
            elsif(my $P = $DepSymbol_Library{$Sym}) {
                $Deps{$P} = 1;
            }
        }
    }
    foreach my $P (keys(%Deps))
    {
        foreach my $Dep (getLib_Deps($P))
        { # recursive
            $Deps{$Dep} = 1;
        }
    }
    
    pop(@RecurLib);
    return keys(%Deps);
}

sub getVTSymbol($)
{
    my $Symbol = $_[0];
    $Symbol=~s/\A_ZN/_ZTVN/;
    $Symbol=~s/(C[1-4]E).*?\Z/E/;
    return $Symbol;
}

sub getTISymbol($)
{
    my $Symbol = $_[0];
    $Symbol=~s/\A_ZN/_ZTIN/;
    $Symbol=~s/(C[1-4]E).*?\Z//;
    return $Symbol;
}

sub getTestLang($)
{
    my $Symbol = $_[0];
    
    if(getSymLang($Symbol) eq "C++") {
        return "C++";
    }
    
    foreach my $S (keys(%UsedInterfaces))
    {
        if(getSymLang($S) eq "C++") {
            return "C++";
        }
    }
    
    return $COMMON_LANGUAGE;
}

sub getSymLang($)
{
    my $Symbol = $_[0];
    my $Header = $CompleteSignature{$Symbol}{"Header"};
    
    if($Header=~/\.(hh|hp|hxx|hpp|h\+\+)\Z/i
    or $Header!~/\.[^\.]+\Z/) {
        return "C++";
    }
    if(index($Symbol, "_Z")==0)
    { # mangled symbols
        if($Symbol!~/\A_Z(L|)\d/)
        { # mangled C functions and global data
            return "C++";
        }
    }
    if(index($Symbol, "__gxx_")==0) {
        return "C++";
    }
    
    if(my $Lib = get_filename($Symbol_Library{$Symbol}))
    {
        if($Language{$Lib}) {
            return $Language{$Lib};
        }
    }
    elsif(my $Lib = get_filename($DepSymbol_Library{$Symbol}))
    {
        if($Language{$Lib}) {
            return $Language{$Lib};
        }
    }
    
    return $COMMON_LANGUAGE;
}

sub add_namespaces($)
{
    my $CodeRef = $_[0];
    my @UsedNameSpaces = ();
    foreach my $NameSpace (sort {get_depth($b,"::")<=>get_depth($a,"::")} keys(%NestedNameSpaces))
    {
        next if($NameSpace eq "std");
        my $NameSpace_InCode = $NameSpace."::";
        if(${$CodeRef}=~s/(\W|\A)(\Q$NameSpace_InCode\E)(\w)/$1$3/g) {
            push(@UsedNameSpaces, $NameSpace);
        }
        my $NameSpace_InSubClass = getSubClassBaseName($NameSpace_InCode);
        if(${$CodeRef}=~s/(\W|\A)($NameSpace_InSubClass)(\w+_SubClass)/$1$3/g) {
            push(@UsedNameSpaces, $NameSpace);
        }
    }
    return @UsedNameSpaces;
}

sub correct_spaces($)
{
    my $Code = $_[0];
    $Code=~s/\n\n\n\n/\n\n/g;
    $Code=~s/\n\n\n/\n\n/g;
    $Code=~s/\n    \n    /\n\n    /g;
    $Code=~s/\n    \n\n/\n/g;
    $Code=~s/\n\n\};/\n};/g;
    return $Code;
}

sub orderHeaders($)
{ # ordering headers according to descriptor
    my @List = ();
    my %Replace = ();
    my $Num = 1;
    my %ElemNum = map {$_=>$Num++} @{$_[0]};
    
    foreach my $Elem (@{$_[0]})
    {
        if(my $Preamble = $Include_Order{$Elem})
        {
            if(not $ElemNum{$Preamble})
            {
                push(@List, $Preamble);
                push(@List, $Elem);
            }
            elsif($ElemNum{$Preamble}>$ElemNum{$Elem})
            {
                push(@List, $Preamble);
                $Replace{$Preamble} = $Elem;
            }
            else {
                push(@List, $Elem);
            }
        }
        elsif($Replace{$Elem}) {
            push(@List, $Replace{$Elem});
        }
        else {
            push(@List, $Elem);
        }
    }
    return \@List;
}

sub alignSpaces($)
{
    my $Code = $_[0];
    my $Code_Copy = $Code;
    my ($MinParagraph, $Paragraph);
    while($Code=~s/\A([ ]+)//) {
        $MinParagraph = length($1) if(not defined $MinParagraph or $MinParagraph>length($1));
    }
    foreach (1 .. $MinParagraph) {
        $Paragraph .= " ";
    }
    $Code_Copy=~s/(\A|\n)$Paragraph/$1/g;
    return $Code_Copy;
}

sub alignCode($$$)
{
    my ($Code, $Code_Align, $Single) = @_;
    return "" if($Code eq "" or $Code_Align eq "");
    my $Paragraph = get_paragraph($Code_Align, 0);
    $Code=~s/\n([^\n])/\n$Paragraph$1/g;
    if(not $Single) {
        $Code=~s/\A/$Paragraph/g;
    }
    return $Code;
}

sub get_paragraph($$)
{
    my ($Code, $MaxMin) = @_;
    my ($MinParagraph_Length, $MinParagraph);
    while($Code=~s/\A([ ]+)//)
    {
        if(not defined $MinParagraph_Length or
        (($MaxMin)?$MinParagraph_Length<length($1):$MinParagraph_Length>length($1))) {
            $MinParagraph_Length = length($1);
        }
    }
    foreach (1 .. $MinParagraph_Length) {
        $MinParagraph .= " ";
    }
    return $MinParagraph;
}

sub writeFile($$)
{
    my ($Path, $Content) = @_;
    return if(not $Path);
    if(my $Dir = get_dirname($Path)) {
        mkpath($Dir);
    }
    open (FILE, ">".$Path) || die ("can't open file \'$Path\': $!\n");
    print FILE $Content;
    close(FILE);
}

sub readFile($)
{
    my $Path = $_[0];
    return "" if(not $Path or not -f $Path);
    open (FILE, $Path);
    my $Content = join("", <FILE>);
    close(FILE);
    $Content=~s/\r//g;
    return $Content;
}

sub get_RunScript($)
{
    my $Interface = $_[0];
    
    my @Paths = ();
    foreach my $Path (sort (keys(%UsedSharedObjects), keys(%LibsDepend), keys(%SpecLibs)))
    {
        if(my $Dir = get_dirname($Path))
        {
            next if(grep {$Dir eq $_} @DefaultLibPaths);
            
            if($INSTALL_PREFIX and $OSgroup!~/win/) {
                $Dir=~s/\A\Q$INSTALL_PREFIX\E(\/|\Z)/\$INSTALL_PREFIX$1/;
            }
            
            push_U(\@Paths, $Dir);
        }
    }
    
    if($OSgroup eq "windows")
    {
        if(@Paths)
        {
            my $EnvSet = "\@set PATH=".join(";", @Paths).";\%PATH\%";
            return $EnvSet."\ntest.exe arg1 arg2 arg3 >output 2>&1\n";
        }
        else {
            return "test.exe arg1 arg2 arg3 >output 2>&1\n";
        }
    }
    elsif($OSgroup eq "macos")
    {
        if(@Paths)
        {
            my $EnvSet = "export DYLD_LIBRARY_PATH=\$DYLD_LIBRARY_PATH:\"".join(":", @Paths)."\"";
            return "#!/bin/sh\n$EnvSet && ./test arg1 arg2 arg3 >output 2>&1\n";
        }
        else {
            return "#!/bin/sh\n./test arg1 arg2 arg3 >output 2>&1\n";
        }
    }
    else
    {
        if(@Paths)
        {
            my $Content = "#!/bin/sh\n";
            
            if($INSTALL_PREFIX and $OSgroup!~/win/)
            {
                $Content .= "INSTALL_PREFIX=\${INSTALL_PREFIX:-$INSTALL_PREFIX}\n\n";
            }
            
            my $EnvSet = "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\"".join(":", @Paths)."\"";
            $Content .= $EnvSet." && ./test arg1 arg2 arg3 >output 2>&1\n";
            
            return $Content;
        }
        else {
            return "#!/bin/sh\n./test arg1 arg2 arg3 >output 2>&1\n";
        }
    }
}

sub short_soname($)
{
    my $Name = $_[0];
    $Name=~s/(?<=\.$LIB_EXT)\.[0-9.]+\Z//g;
    return $Name;
}

sub checkHeader($)
{
    if(defined $Cache{"checkHeader"}{$_[0]}) {
        return $Cache{"checkHeader"}{$_[0]}
    }
    foreach my $Path (@DefaultIncPaths)
    {
        if(-f $Path."/".$_[0]) {
            return ($Cache{"checkHeader"}{$_[0]} = join_P($Path, $_[0]));
        }
    }
    return ($Cache{"checkHeader"}{$_[0]} = "");
}

sub optimizeIncludes($$)
{
    my %Paths = %{$_[0]};
    my $Level = $_[1];
    
    if($Level=~/Low|Medium|High/i)
    { # optimization N1: included by others
        foreach my $Path1 (sort {$Paths{$b}<=>$Paths{$a}} keys(%Paths))
        {
            if($Paths{$Path1}<0)
            { # preamble headers (%Include_Preamble)
                next;
            }
            
            my $N = $Paths{$Path1};
            foreach my $Path2 (sort {$Paths{$b}<=>$Paths{$a}} keys(%Paths))
            {
                next if($Path1 eq $Path2);
                next if($Paths{$Path2}<=$N); # top-to-bottom
                if(grep {get_dirname($Path2) eq $_} @DefaultIncPaths)
                { # save
                    next if(not defined $Include_RevOrder{get_filename($Path2)});
                }
                
                if(defined $RecursiveIncludes{$Path1}{$Path2})
                {
                    my $Name = get_filename($Path2);
                    my $Dir = get_filename(get_dirname($Path2));
                    my $DirName = join_P($Dir, $Name);
                    
                    if(defined $DirectIncludes{$Path1}{$Name}
                    or defined $DirectIncludes{$Path1}{$DirName}) {
                        delete($Paths{$Path2});
                    }
                }
            }
        }
    }
    
    if($Level=~/Medium|High/i)
    { # optimization N2: non registered
        foreach my $Path (sort {$Paths{$b}<=>$Paths{$a}} keys(%Paths))
        {
            if($Paths{$Path}<0)
            { # preamble headers (%Include_Preamble)
                next;
            }
            
            if(not $RegisteredHeaders_R{$Path})
            {
                my $Dir = get_dirname($Path);
                next if(grep {$Dir eq $_} @DefaultIncPaths); # save
                
                my @Tops = sort keys(%{$RecursiveIncludes_R{$Path}});
                @Tops = sort {keys(%{$DirectIncludes{$b}}) <=> keys(%{$DirectIncludes{$a}})} @Tops;
                foreach my $Top (@Tops)
                {
                    if(defined $RegisteredHeaders_R{$Top})
                    {
                        if(not defined $Paths{$Top}) {
                            $Paths{$Top} = $Paths{$Path};
                        }
                        delete($Paths{$Path});
                        last;
                    }
                }
            }
        }
    }
    
    if($Level=~/High/i)
    { # optimization N3: top headers
        foreach my $Path (sort {$Paths{$b}<=>$Paths{$a}} keys(%Paths))
        {
            if($Paths{$Path}<0)
            { # preamble headers (%Include_Preamble)
                next;
            }
            
            if($RegisteredHeaders_R{$Path})
            {
                if(my @Tops = sort keys(%{$RegisteredIncludes_R{$Path}}))
                {
                    my $Name = get_filename($Path);
                    my $Short = $Name;
                    $Short=~s/\.\w+\Z//;
                    
                    @Tops = sort {keys(%{$DirectIncludes{$b}}) <=> keys(%{$DirectIncludes{$a}})} @Tops;
                    @Tops = sort {$b=~/\Q$Short\E/i cmp $a=~/\Q$Short\E/i} @Tops;
                    
                    foreach my $Top (@Tops)
                    {
                        if(get_filename($Top) ne $Name)
                        {
                            next if(keys(%{$DirectIncludes{$Top}})<=keys(%{$DirectIncludes{$Path}}));
                            next if(keys(%{$DirectIncludes{$Path}})>$MAX_INC/3);
                        }
                        
                        next if(skipHeader($Top));
                        
                        # replace
                        if(not defined $Paths{$Top}) {
                            $Paths{$Top} = $Paths{$Path};
                        }
                        delete($Paths{$Path});
                        last;
                    }
                }
            }
        }
    }
    
    %{$_[0]} = %Paths;
}

sub identifyHeader($)
{
    if(defined $Cache{"identifyHeader"}{$_[0]}) {
        return $Cache{"identifyHeader"}{$_[0]}
    }
    return ($Cache{"identifyHeader"}{$_[0]} = identifyHeader_I($_[0]));
}

sub identifyHeader_I($)
{
    my $Name = $_[0];
    if(my $Path = $RegisteredHeaders{$Name}) {
        return $Path;
    }
    elsif(my $Path = $KnownHeaders{$Name}) {
        return $Path;
    }
    elsif(my $Path = checkHeader($Name)) {
        return $Path;
    }
    return $Name;
}

sub prepareHeaders(@)
{
    my @List = @_;
    my %Paths = ();
    my ($Num, $PNum) = (0, -$#List-2);
    
    # determine header paths
    foreach my $Name (@_)
    {
        if(my $Path = identifyHeader($Name))
        {
            if(my $Redirect = $Include_Redirect{$Path}) {
                $Path = $Redirect;
            }
            if(not defined $Paths{$Path})
            {
                if(grep {$Name eq $_} @Include_Preamble) {
                    $Paths{$Path} = $PNum++;
                }
                else {
                    $Paths{$Path} = $Num++;
                }
            }
        }
    }
    
    if(my $Level = lc($OptimizeIncludes))
    {
        if($Level ne "none") {
            optimizeIncludes(\%Paths, $Level);
        }
    }
    else
    { # default
        optimizeIncludes(\%Paths, "High");
    }
    
    foreach my $Path (sort {$Paths{$a}<=>$Paths{$b}} keys(%Paths))
    {
        if(my $Redirect = $Include_Redirect{$Path})
        {
            if(not defined $Paths{$Redirect}) {
                $Paths{$Redirect} = $Paths{$Path};
            }
            delete($Paths{$Path});
        }
    }
    
    my (@Headers, %IncPaths) = ();
    
    # determine include paths
    foreach my $Path (sort {$Paths{$a}<=>$Paths{$b}} keys(%Paths))
    {
        my $FName = get_filename($Path);
        my $Dir = get_dirname($Path);
        
        my $Prefix = undef;
        
        if(my @Prefixes = keys(%{$IncludePrefix{$FName}}))
        {
            @Prefixes = sort {length($a)<=>length($b)} sort @Prefixes;
            
            foreach my $P (@Prefixes)
            {
                if($Dir=~s/[\/\\]+\Q$P\E\Z//g)
                {
                    push(@Headers, join_P($P, $FName));
                    $Prefix = $P;
                    last;
                }
            }
        }
        if(not $Prefix)
        { # default
            if($Prefix = getFilePrefix($Path))
            { # NOTE: /usr/include/sys/...
                push(@Headers, join_P($Prefix, $FName));
                $Dir=~s/[\/\\]+\Q$Prefix\E\Z//;
            }
            else {
                push(@Headers, $FName);
            }
        }
        
        if($Dir)
        {
            if(not grep {$Dir eq $_} @DefaultIncPaths) {
                $IncPaths{$Dir} = $Num++;
            }
        }
        
        # if(index($Dir, "/usr/include/c++/")!=0) {
        #     $IncPaths{$Dir} = $Num;
        # }
    }
    
    my @IncPaths = sort {$IncPaths{$b} <=> $IncPaths{$a}} keys(%IncPaths);
    return (\@Headers, \@IncPaths);
}

sub get_Makefile($$)
{
    my ($Interface, $IncPaths) = @_;
    
    my (%LibPaths_All, %LibNames_All) = (); # Win
    
    my (%LibPaths, %LibSuffixes) = ();
    
    my @LIBS = ();
    my @INCS = ();
    
    foreach my $Path (sort (keys(%UsedSharedObjects), keys(%LibsDepend), keys(%SpecLibs)))
    {
        if($TestFormat eq "CL")
        {
            $Path=~s/\.dll\Z/.lib/;
            $LibPaths_All{"\"".get_dirname($Path)."\""} = 1;
            $LibNames_All{get_filename($Path)} = 1;
        }
        else
        {
            if(($Path=~/\.$LIB_EXT\Z/ or -f short_soname($Path))
            and $Path=~/\A(.*)[\/\\]lib([^\/\\]+)\.$LIB_EXT[^\/\\]*\Z/)
            {
                $LibPaths{$1} = 1;
                $LibSuffixes{$2} = 1;
            }
            elsif($Path=~/\Alib([^\/\\]+)\.$LIB_EXT[^\/\\]*\Z/) {
                $LibSuffixes{$1} = 1;
            }
            else {
                push(@LIBS, $Path);
            }
        }
    }
    foreach my $Path (keys(%LibPaths))
    {
        next if(not $Path);
        next if(grep {$Path eq $_} @DefaultLibPaths);
        push(@LIBS, "-L".esc_option($Path, "GCC"));
    }
    foreach my $Suffix (keys(%LibSuffixes)) {
        push(@LIBS, "-l".$Suffix);
    }
    
    if($LibString)
    { # undefined symbols
        push(@LIBS, $LibString);
    }
    
    if($CompilerOptions_Libs) {
        push(@LIBS, $CompilerOptions_Libs);
    }
    
    foreach my $Path (@{$IncPaths})
    {
        my $IncOpt = inc_opt($Path, $TestFormat);
        if($IncludeString!~/\Q$IncOpt\E( |\Z)/) {
            push(@INCS, $IncOpt);
        }
    }
    if($IncludeString) {
        push(@INCS, $IncludeString);
    }
    
    my $Source = "test.c";
    my $Exe = "test";
    my $Obj = "test.o";
    my $Rm = "rm -f";
    
    if(getTestLang($Interface) eq "C++") {
        $Source = "test.cpp";
    }
    
    if($OSgroup eq "windows")
    {
        $Exe = "test.exe";
        $Rm = "del";
    }
    
    if($TestFormat eq "CL") {
        $Obj = "test.obj";
    }
    
    my $Makefile = "";
    
    if($INSTALL_PREFIX and $OSgroup!~/win/)
    {
        foreach (@INCS, @LIBS)
        {
            my $P = esc($INSTALL_PREFIX);
            $_=~s/\Q$P\E(\/|\Z)/\"\$(INSTALL_PREFIX)\"$1/g;
        }
        
        $Makefile .= "INSTALL_PREFIX ?= ".$INSTALL_PREFIX."\n\n";
    }
    
    if($TestFormat eq "CL")
    { # compiling using CL and NMake
        $Makefile .= "CC       = cl";
        if(@INCS) {
            $Makefile .= "\nINCLUDES = ".join(" ", @INCS);
        }
        if(keys(%LibNames_All)) {
            $Makefile .= "\nLIBS     = ".join(" ", keys(%LibNames_All));
        }
        $Makefile .= "\n\nall: $Exe\n\n";
        $Makefile .= "$Exe: $Source\n\t";
        if(keys(%LibNames_All)) {
            $Makefile .= "set LIB=".join(";", keys(%LibPaths_All)).";\$(LIB)\n\t";
        }
        $Makefile .= "\$(CC) ";
        if(@INCS) {
            $Makefile .= "\$(INCLUDES) ";
        }
        $Makefile .= $Source;
        if(keys(%LibNames_All)) {
            $Makefile .= " \$(LIBS)";
        }
        $Makefile .= "\n\n";
        $Makefile .= "clean:\n\t$Rm $Exe $Obj\n";
        return $Makefile;
    }
    else
    { # compiling using GCC and Make
        if(getTestLang($Interface) eq "C++")
        {
            $Makefile .= "CXX      = g++\n";
            $Makefile .= "CXXFLAGS = -Wall";
            if($CompilerOptions_Cflags) {
                $Makefile .= " ".$CompilerOptions_Cflags;
            }
            if(@INCS) {
                $Makefile .= "\nINCLUDES = ".join(" ", @INCS);
            }
            if(@LIBS) {
                $Makefile .= "\nLIBS     = ".join(" ", @LIBS);
            }
            $Makefile .= "\n\nall: $Exe\n\n";
            $Makefile .= "$Exe: $Source\n\t";
            $Makefile .= "\$(CXX) \$(CXXFLAGS)";
            if(@INCS) {
                $Makefile .= " \$(INCLUDES)";
            }
            $Makefile .= " $Source -o $Exe";
            if(@LIBS) {
                $Makefile .= " \$(LIBS)";
            }
            $Makefile .= "\n\n";
            $Makefile .= "clean:\n\t$Rm $Exe $Obj\n";
            return $Makefile;
        }
        else
        {
            $Makefile .= "CC       = gcc\n";
            $Makefile .= "CFLAGS   = -Wall";
            if($CompilerOptions_Cflags) {
                $Makefile .= " ".$CompilerOptions_Cflags;
            }
            if(@INCS) {
                $Makefile .= "\nINCLUDES = ".join(" ", @INCS);
            }
            if(@LIBS) {
                $Makefile .= "\nLIBS     = ".join(" ", @LIBS);
            }
            $Makefile .= "\n\nall: $Exe\n\n";
            $Makefile .= "$Exe: $Source\n\t";
            $Makefile .= "\$(CC) \$(CFLAGS)";
            if(@INCS) {
                $Makefile .= " \$(INCLUDES)";
            }
            $Makefile .= " $Source -o $Exe";
            if(@LIBS) {
                $Makefile .= " \$(LIBS)";
            }
            $Makefile .= "\n\n";
            $Makefile .= "clean:\n\t$Rm $Exe $Obj\n";
            return $Makefile;
        }
    }
}

sub get_one_step_title($$$$$)
{
    my ($Num, $All_Count, $Head, $Success, $Fail)  = @_;
    my $Title = "$Head: $Num/$All_Count [".cut_off_number($Num*100/$All_Count, 3)."%],";
    $Title .= " success/fail: $Success/$Fail";
    return $Title."    ";
}

sub insertIDs($)
{
    my $Text = $_[0];
    
    while($Text=~/CONTENT_ID/)
    {
        if(int($Content_Counter)%2) {
            $ContentID -= 1;
        }
        $Text=~s/CONTENT_ID/c_$ContentID/;
        $ContentID += 1;
        $Content_Counter += 1;
    }
    return $Text;
}

sub cut_off_number($$)
{
    my ($num, $digs_to_cut) = @_;
    if($num!~/\./)
    {
        $num .= ".";
        foreach (1 .. $digs_to_cut-1) {
            $num .= "0";
        }
    }
    elsif($num=~/\.(.+)\Z/ and length($1)<$digs_to_cut-1)
    {
        foreach (1 .. $digs_to_cut - 1 - length($1)) {
            $num .= "0";
        }
    }
    elsif($num=~/\d+\.(\d){$digs_to_cut,}/) {
      $num=sprintf("%.".($digs_to_cut-1)."f", $num);
    }
    return $num;
}

sub selectSymbol($)
{
    my $Symbol = $_[0];
    
    if(defined $CompleteSignature{$Symbol})
    {
        if(my $Header = $CompleteSignature{$Symbol}{"Header"})
        {
            if(my $Path = identifyHeader($Header))
            {
                if(my $Skip = skipHeader($Path))
                {
                    if($Skip==1)
                    { # skip_headers
                        return 0;
                    }
                }
            }
            if($RegisteredHeaders{$Header})
            {
                if($Symbol_Library{$Symbol}) {
                    return 1;
                }
                if($CompleteSignature{$Symbol}{"InLine"})
                {
                    if(not defined $NoInline) {
                        return 1;
                    }
                }
            }
        }
    }
    return 0;
}

sub generateTests()
{
    rmtree($TEST_SUITE_PATH) if(-e $TEST_SUITE_PATH);
    mkpath($TEST_SUITE_PATH);
    ($ResultCounter{"Gen"}{"Success"}, $ResultCounter{"Gen"}{"Fail"}) = (0, 0);
    my %TargetInterfaces = ();
    if($TargetHeaderName)
    { # for the header file
        foreach my $Symbol (sort keys(%CompleteSignature))
        {
            if(my $Header = $CompleteSignature{$Symbol}{"Header"})
            {
                if(get_filename($Header) eq $TargetHeaderName)
                {
                    if(selectSymbol($Symbol))
                    {
                        if(symbolFilter($Symbol)) {
                            $TargetInterfaces{$Symbol} = 1;
                        }
                    }
                }
            }
        }
    }
    elsif(keys(%InterfacesList))
    { # for the list
        foreach my $Symbol (sort keys(%InterfacesList))
        {
            if(symbolFilter($Symbol)) {
                $TargetInterfaces{$Symbol} = 1;
            }
        }
    }
    else
    { # all symbols (default)
        foreach my $Symbol (sort keys(%CompleteSignature))
        {
            if(not defined $GenerateAll)
            {
                if(not selectSymbol($Symbol)) {
                    next;
                }
            }
            
            if(symbolFilter($Symbol)) {
                $TargetInterfaces{$Symbol} = 1;
            }
        }
        if(not keys(%TargetInterfaces)) {
            exitStatus("Error", "cannot obtain enough information from header files to generate tests");
        }
    }
    if(not keys(%TargetInterfaces)) {
        exitStatus("Error", "specified information is not enough to generate tests");
    }
    unlink($TEST_SUITE_PATH."/scenario");
    open(FAIL_LIST, ">$TEST_SUITE_PATH/gen_fail_list");
    if(defined $Template2Code)
    {
        if(keys(%LibGroups))
        {
            my %LibGroups_Filtered = ();
            my ($Test_Num, $All_Count) = (0, 0);
            foreach my $LibGroup (sort {lc($a) cmp lc($b)} keys(%LibGroups))
            {
                foreach my $Interface (keys(%{$LibGroups{$LibGroup}}))
                {
                    if($TargetInterfaces{$Interface})
                    {
                        $LibGroups_Filtered{$LibGroup}{$Interface} = 1;
                        $All_Count+=1;
                    }
                }
            }
            foreach my $LibGroup (sort {lc($a) cmp lc($b)} keys(%LibGroups_Filtered))
            {
                my @Ints = sort {lc($a) cmp lc($b)} keys(%{$LibGroups_Filtered{$LibGroup}});
                t2c_group_generation($LibGroup, "", \@Ints, 0, \$Test_Num, $All_Count);
            }
            print "\r".get_one_step_title($All_Count, $All_Count, "generating tests", $ResultCounter{"Gen"}{"Success"}, $ResultCounter{"Gen"}{"Fail"})."\n";
        }
        else
        {
            my $TwoComponets = 0;
            my %Header_Class_Interface = ();
            my ($Test_Num, $All_Count) = (0, int(keys(%TargetInterfaces)));
            foreach my $Interface (sort {lc($a) cmp lc($b)} keys(%TargetInterfaces))
            {
                my %Signature = %{$CompleteSignature{$Interface}};
                $Header_Class_Interface{$Signature{"Header"}}{get_type_short_name(get_TypeName($Signature{"Class"}))}{$Interface}=1;
                if($Signature{"Class"}) {
                    $TwoComponets=1;
                }
            }
            foreach my $Header (sort {lc($a) cmp lc($b)} keys(%Header_Class_Interface))
            {
                foreach my $ClassName (sort {lc($a) cmp lc($b)} keys(%{$Header_Class_Interface{$Header}}))
                {
                    my @Ints = sort {lc($a) cmp lc($b)} keys(%{$Header_Class_Interface{$Header}{$ClassName}});
                    t2c_group_generation($Header, $ClassName, \@Ints, $TwoComponets, \$Test_Num, $All_Count);
                }
            }
            print "\r".get_one_step_title($All_Count, $All_Count, "generating tests", $ResultCounter{"Gen"}{"Success"}, $ResultCounter{"Gen"}{"Fail"})."\n";
        }
        writeFile("$TEST_SUITE_PATH/$TargetLibraryName-t2c/$TargetLibraryName.cfg", "# Custom compiler options\nCOMPILER_FLAGS = -DCHECK_EXT_REQS `pkg-config --cflags $TargetLibraryName` -D_GNU_SOURCE\n\n# Custom linker options\nLINKER_FLAGS = `pkg-config --libs $TargetLibraryName`\n\n# Maximum time (in seconds) each test is allowed to run\nWAIT_TIME = $HANGED_EXECUTION_TIME\n\n# Copyright holder\nCOPYRIGHT_HOLDER = COMPANY\n");
    }
    else
    { # standalone
        my $Test_Num = 0;
        if(keys(%LibGroups))
        {
            foreach my $Interface (keys(%TargetInterfaces))
            {
                if(not $Interface_LibGroup{$Interface}) {
                    delete($TargetInterfaces{$Interface});
                }
            }
        }
        my $All_Count = keys(%TargetInterfaces);
        foreach my $Interface (sort {lc($a) cmp lc($b)} keys(%TargetInterfaces))
        {
            print "\r".get_one_step_title($Test_Num, $All_Count, "generating tests", $ResultCounter{"Gen"}{"Success"}, $ResultCounter{"Gen"}{"Fail"});
            # reset global state
            restore_state(());
            @RecurInterface = ();
            @RecurTypeId = ();
            @RecurSpecType = ();
            %SubClass_Created = ();
            my %Result = generateTest($Interface);
            if(not $Result{"IsCorrect"})
            {
                print FAIL_LIST $Interface."\n";
                if($StrictGen) {
                    exitStatus("Error", "can't generate test for $Interface");
                }
            }
            $Test_Num += 1;
        }
        write_scenario();
        print "\r".get_one_step_title($All_Count, $All_Count, "generating tests", $ResultCounter{"Gen"}{"Success"}, $ResultCounter{"Gen"}{"Fail"})."\n";
        restore_state(());
    }
    close(FAIL_LIST);
    unlink($TEST_SUITE_PATH."/gen_fail_list") if(not readFile($TEST_SUITE_PATH."/gen_fail_list"));
}

sub t2c_group_generation($$$$$$)
{
    my ($C1, $C2, $Interfaces, $TwoComponets, $Test_NumRef, $All_Count) = @_;
    my ($SuitePath, $MediumPath, $TestName) = getLibGroupPath($C1, $C2, $TwoComponets);
    my $MaxLength = 0;
    my $LibGroupName = getLibGroupName($C1, $C2);
    my %TestComponents = ();
    # reset global state for section
    restore_state(());
    foreach my $Interface (@{$Interfaces})
    {
        print "\r".get_one_step_title(${$Test_NumRef}, $All_Count, "generating tests", $ResultCounter{"Gen"}{"Success"}, $ResultCounter{"Gen"}{"Fail"});
        restore_local_state(());
        %IntrinsicNum=(
            "Char"=>64,
            "Int"=>0,
            "Str"=>0,
            "Float"=>0);
        @RecurInterface = ();
        @RecurTypeId = ();
        @RecurSpecType = ();
        %SubClass_Created = ();
        my $Global_State = save_state();
        my %Result = generateTest($Interface);
        if(not $Result{"IsCorrect"})
        {
            restore_state($Global_State);
            print FAIL_LIST $Interface."\n";
        }
        ${$Test_NumRef} += 1;
        $TestComponents{"Headers"} = addHeaders($TestComponents{"Headers"}, $Result{"Headers"});
        $TestComponents{"Code"} .= $Result{"Code"};
        my ($DefinesList, $ValuesList) = list_t2c_defines();
        $TestComponents{"Blocks"} .= "##=========================================================================\n## ".get_Signature($Interface)."\n\n<BLOCK>\n\n<TARGETS>\n    ".$CompleteSignature{$Interface}{"ShortName"}."\n</TARGETS>\n\n".(($DefinesList)?"<DEFINE>\n".$DefinesList."</DEFINE>\n\n":"")."<CODE>\n".$Result{"main"}."</CODE>\n\n".(($ValuesList)?"<VALUES>\n".$ValuesList."</VALUES>\n\n":"")."</BLOCK>\n\n\n";
        $MaxLength = length($CompleteSignature{$Interface}{"ShortName"}) if($MaxLength<length($CompleteSignature{$Interface}{"ShortName"}));
    }
    # adding test data
    my $TestDataDir = $SuitePath."/testdata/".(($MediumPath)?"$MediumPath/":"")."$TestName/";
    mkpath($TestDataDir);
    $TestComponents{"Blocks"} = add_VirtualTestData($TestComponents{"Blocks"}, $TestDataDir);
    $TestComponents{"Blocks"} = add_TestData($TestComponents{"Blocks"}, $TestDataDir);
    my $Content = "#library $TargetLibraryName\n#libsection $LibGroupName\n\n<GLOBAL>\n\n// Tested here:\n";
    foreach my $Interface (@{$Interfaces})
    { # development progress
        $Content .= "// ".$CompleteSignature{$Interface}{"ShortName"};
        foreach (0 .. $MaxLength - length($CompleteSignature{$Interface}{"ShortName"}) + 2) {
            $Content .= " ";
        }
        $Content .= "DONE (shallow)\n";
    }
    $Content .= "\n";
    foreach my $Header (@{$TestComponents{"Headers"}})
    { # includes
        $Content .= "#include <$Header>\n";
    }
    $Content .= "\n".$TestComponents{"Code"}."\n" if($TestComponents{"Code"});
    $Content .= "\n</GLOBAL>\n\n".$TestComponents{"Blocks"};
    writeFile($SuitePath."/src/".(($MediumPath)?"$MediumPath/":"")."$TestName.t2c", $Content);
    writeFile($SuitePath."/reqs/".(($MediumPath)?"$MediumPath/":"")."$TestName.xml", get_requirements_catalog($Interfaces));
}

sub get_requirements_catalog($)
{
    my @Interfaces = @{$_[0]};
    my $Reqs = "";
    foreach my $Interface (@Interfaces)
    {
        foreach my $ReqId (sort {int($a)<=>int($b)} keys(%{$RequirementsCatalog{$Interface}}))
        {
            my $Req = $RequirementsCatalog{$Interface}{$ReqId};
            $Req=~s/&/&amp;/g;
            $Req=~s/>/&gt;/g;
            $Req=~s/</&lt;/g;
            $Reqs .= "<req id=\"".$CompleteSignature{$Interface}{"ShortName"}.".".normalize_num($ReqId)."\">\n    $Req\n</req>\n";
        }
    }
    if(not $Reqs) {
        $Reqs = "<req id=\"function.01\">\n    If ... then ...\n</req>\n";
    }
    return "<?xml version=\"1.0\"?>\n<requirements>\n".$Reqs."</requirements>\n";
}

sub list_t2c_defines()
{
    my (%Defines, $DefinesList, $ValuesList) = ();
    my $MaxLength = 0;
    foreach my $Define (sort keys(%Template2Code_Defines))
    {
        if($Define=~/\A(\d+):(.+)\Z/)
        {
            $Defines{$1}{"Name"} = $2;
            $Defines{$1}{"Value"} = $Template2Code_Defines{$Define};
            $MaxLength = length($2) if($MaxLength<length($2));
        }
    }
    foreach my $Pos (sort {int($a) <=> int($b)} keys(%Defines))
    {
        $DefinesList .= "#define ".$Defines{$Pos}{"Name"};
        foreach (0 .. $MaxLength - length($Defines{$Pos}{"Name"}) + 2) {
            $DefinesList .= " ";
        }
        $DefinesList .= "<%$Pos%>\n";
        $ValuesList .= "    ".$Defines{$Pos}{"Value"}."\n";
    }
    return ($DefinesList, $ValuesList);
}

sub buildTests()
{
    if(-e $TEST_SUITE_PATH."/build_fail_list") {
        unlink($TEST_SUITE_PATH."/build_fail_list");
    }
    ($ResultCounter{"Build"}{"Success"}, $ResultCounter{"Build"}{"Fail"}) = (0, 0);
    readScenario();
    return if(not keys(%Interface_TestDir));
    my $All_Count = keys(%Interface_TestDir);
    my $Test_Num = 0;
    open(FAIL_LIST, ">$TEST_SUITE_PATH/build_fail_list");
    foreach my $Interface (sort {lc($a) cmp lc($b)} keys(%Interface_TestDir))
    { # building tests
        print "\r".get_one_step_title($Test_Num, $All_Count, "building tests", $ResultCounter{"Build"}{"Success"}, $ResultCounter{"Build"}{"Fail"});
        buildTest($Interface);
        if(not $BuildResult{$Interface}{"IsCorrect"})
        {
            print FAIL_LIST $Interface_TestDir{$Interface}."\n";
            if($StrictBuild) {
                exitStatus("Error", "can't build test for $Interface");
            }
        }
        $Test_Num += 1;
    }
    close(FAIL_LIST);
    unlink($TEST_SUITE_PATH."/build_fail_list") if(not readFile($TEST_SUITE_PATH."/build_fail_list"));
    print "\r".get_one_step_title($All_Count, $All_Count, "building tests", $ResultCounter{"Build"}{"Success"}, $ResultCounter{"Build"}{"Fail"})."\n";
}

sub cleanTests()
{
    readScenario();
    return if(not keys(%Interface_TestDir));
    my $All_Count = keys(%Interface_TestDir);
    my $Test_Num = 0;
    foreach my $Interface (sort {lc($a) cmp lc($b)} keys(%Interface_TestDir))
    { # cleaning tests
        print "\r".get_one_step_title($Test_Num, $All_Count, "cleaning tests", $Test_Num, 0);
        cleanTest($Interface);
        $Test_Num += 1;
    }
    print "\r".get_one_step_title($All_Count, $All_Count, "cleaning tests", $All_Count, 0)."\n";
}

sub runTests()
{
    if(-f $TEST_SUITE_PATH."/run_fail_list") {
        unlink($TEST_SUITE_PATH."/run_fail_list");
    }
    ($ResultCounter{"Run"}{"Success"}, $ResultCounter{"Run"}{"Fail"}) = (0, 0);
    readScenario();
    if(not keys(%Interface_TestDir)) {
        exitStatus("Error", "tests were not generated yet");
    }
    my %ForRunning = ();
    foreach my $Interface (keys(%Interface_TestDir))
    {
        if(-f $Interface_TestDir{$Interface}."/test"
        or -f $Interface_TestDir{$Interface}."/test.exe") {
            $ForRunning{$Interface} = 1;
        }
    }
    my $All_Count = keys(%ForRunning);
    if($All_Count==0) {
        exitStatus("Error", "tests were not built yet");
    }
    my $Test_Num = 0;
    open(FAIL_LIST, ">$TEST_SUITE_PATH/run_fail_list");
    my $XvfbStarted = 0;
    $XvfbStarted = runXvfb() if($UseXvfb);
    foreach my $Interface (sort {lc($a) cmp lc($b)} keys(%ForRunning))
    { # running tests
        print "\r".get_one_step_title($Test_Num, $All_Count, "running tests", $ResultCounter{"Run"}{"Success"}, $ResultCounter{"Run"}{"Fail"});
        runTest($Interface);
        if(not $RunResult{$Interface}{"IsCorrect"})
        {
            print FAIL_LIST $Interface_TestDir{$Interface}."\n";
            if($StrictRun) {
                exitStatus("Error", "test run failed for $Interface");
            }
        }
        $Test_Num += 1;
    }
    stopXvfb($XvfbStarted) if($UseXvfb);
    close(FAIL_LIST);
    unlink($TEST_SUITE_PATH."/run_fail_list") if(not readFile($TEST_SUITE_PATH."/run_fail_list"));
    print "\r".get_one_step_title($All_Count, $All_Count, "running tests", $ResultCounter{"Run"}{"Success"}, $ResultCounter{"Run"}{"Fail"})."\n";
    return 0;
}

sub initSignals()
{
    return if(not defined $Config{"sig_name"}
    or not defined $Config{"sig_num"});
    my $No = 0;
    my @Numbers = split(/\s/, $Config{"sig_num"} );
    foreach my $Name (split(/\s/, $Config{"sig_name"})) 
    {
        if(not $SigName{$Numbers[$No]}
        or $Name=~/\A(SEGV|ABRT)\Z/)
        {
            $SigNo{$Name} = $Numbers[$No];
            $SigName{$Numbers[$No]} = $Name;
        }
        $No+=1;
    }
}

sub esc($)
{
    my $Str = $_[0];
    $Str=~s/([()\[\]{}$ &'"`;,<>\+])/\\$1/g;
    return $Str;
}

sub remove_option($$)
{
    my ($OptionsRef, $Option) = @_;
    return if(not $OptionsRef or not $Option);
    $Option = esc($Option);
    my @Result = ();
    foreach my $Arg (@{$OptionsRef})
    {
        if($Arg!~/\A[-]+$Option\Z/) {
            push(@Result, $Arg);
        }
    }
    @{$OptionsRef} = @Result;
}

sub get_RetValName($)
{
    my $Interface = $_[0];
    return "" if(not $Interface);
    if($Interface=~/\A(.+?)(_|)(init|initialize|initializer|install)\Z/) {
        return $1;
    }
    else {
        return getParamNameByTypeName($CompleteSignature{$Interface}{"Return"});
    }
}

sub add_LibraryPreambleAndFinalization()
{
    if(not keys(%LibraryInitFunc)
    or keys(%LibraryInitFunc)>1) {
        return;
    }
    my $AddedPreamble = 0;
    my $Pos = 0;
    foreach my $Interface (sort {$Library_Prefixes{getPrefix($b)} <=> $Library_Prefixes{getPrefix($a)}}
    sort {$b=~/init/i <=> $a=~/init/i} sort {lc($a) cmp lc($b)} keys(%LibraryInitFunc))
    {
        next if(not symbolFilter($Interface));
        my $Prefix = getPrefix($Interface);
        next if($Library_Prefixes{$Prefix}<$LIBRARY_PREFIX_MAJORITY);
        next if($Interface=~/plugin/i);
        my $ReturnId = $CompleteSignature{$Interface}{"Return"};
        my $ReturnFId = get_FoundationTypeId($ReturnId);
        my $ReturnFTypeType = get_TypeType($ReturnFId);
        my $RPLevel = get_PointerLevel($ReturnId);
        my $RetValName = get_RetValName($Interface);
        if(defined $CompleteSignature{$Interface}{"Param"}{0})
        { # should not have a complex parameter type
            my $PTypeId = $CompleteSignature{$Interface}{"Param"}{0}{"type"};
            next if(get_TypeType(get_FoundationTypeId($PTypeId))!~/\A(Enum|Intrinsic)\Z/ and get_PointerLevel($PTypeId)!=0);
        }
        if(get_TypeName($ReturnId) eq "void"
        or ($ReturnFTypeType=~/\A(Enum|Intrinsic)\Z/ and $RPLevel==0)
        or ($ReturnFTypeType eq "Struct" and $RPLevel>=1))
        { # should return a simple type or structure pointer
            readSpecTypes("
            <spec_type>
                <name>
                    automatic preamble
                </name>
                <kind>
                    common_env
                </kind>
                <global_code>
                    #include <".$CompleteSignature{$Interface}{"Header"}.">
                </global_code>
                <init_code>
                    \$[$Interface".($ReturnFTypeType eq "Struct" and $RetValName?":$RetValName":"")."];
                </init_code>
                <libs>
                    ".get_filename($Symbol_Library{$Interface})."
                </libs>
                <associating>
                    <except>
                        $Interface
                    </except>
                </associating>
            </spec_type>");
            $AddedPreamble = 1;
            $LibraryInitFunc{$Interface} = $Pos++;
        }
    }
    if(not $AddedPreamble
    or keys(%LibraryExitFunc)>1) {
        return;
    }
    foreach my $Interface (sort {lc($a) cmp lc($b)} keys(%LibraryExitFunc))
    {
        next if(not symbolFilter($Interface));
        my $Prefix = getPrefix($Interface);
        next if($Library_Prefixes{$Prefix}<$LIBRARY_PREFIX_MAJORITY);
        next if($Interface=~/plugin/i);
        my $ReturnId = $CompleteSignature{$Interface}{"Return"};
        my $PTypeId = (defined $CompleteSignature{$Interface}{"Param"}{0})?$CompleteSignature{$Interface}{"Param"}{0}{"type"}:0;
        my $Interface_Pair = 0;
        foreach my $Interface_Init (keys(%LibraryInitFunc))
        { # search for a pair interface
            my $Prefix_Init = getPrefix($Interface_Init);
            my $ReturnId_Init = $CompleteSignature{$Interface_Init}{"Return"};
            my $PTypeId_Init = (defined $CompleteSignature{$Interface_Init}{"Param"}{0})?$CompleteSignature{$Interface_Init}{"Param"}{0}{"type"}:0;
            if($Prefix eq $Prefix_Init
            and ($PTypeId==0 or $PTypeId_Init==$ReturnId or $PTypeId==$ReturnId_Init or $PTypeId==$PTypeId_Init))
            { # libraw_init ( unsigned int flags ):libraw_data_t*
              # libraw_close ( libraw_data_t* p1 ):void
                $Interface_Pair = $Interface_Init;
                last;
            }
        }
        next if(not $Interface_Pair);
        if(get_TypeName($ReturnId) eq "void"
        or (get_TypeType(get_FoundationTypeId($ReturnId))=~/\A(Enum|Intrinsic)\Z/ and get_PointerLevel($ReturnId)==0))
        {
            readSpecTypes("
            <spec_type>
                <name>
                    automatic finalization
                </name>
                <kind>
                    common_env
                </kind>
                <global_code>
                    #include <".$CompleteSignature{$Interface}{"Header"}.">
                </global_code>
                <final_code>
                    \$[$Interface];
                </final_code>
                <libs>
                    ".get_filename($Symbol_Library{$Interface})."
                </libs>
                <associating>
                    <except>
                        $Interface
                    </except>
                </associating>
            </spec_type>");
        }
    }
}

sub initLogging()
{
    $DEBUG_PATH = "debug/$TargetLibraryName/".$Descriptor{"Version"};
    
    if($Debug)
    { # reset
        if(not ($UseCache and -d $CACHE_PATH))
        {
            rmtree($DEBUG_PATH);
            mkpath($DEBUG_PATH);
        }
    }
    
}

sub writeDebugLog()
{
    my $DEBUG_LOG = "";
    if(my @Interfaces = keys(%{$DebugInfo{"Init_InterfaceParams"}}))
    {
        $DEBUG_LOG .= "Failed to initialize parameters of these symbols:\n";
        foreach my $Interface (@Interfaces) {
            $DEBUG_LOG .= "  ".get_Signature($Interface)."\n";
        }
        delete($DebugInfo{"Init_InterfaceParams"});
    }
    if(my @Types = keys(%{$DebugInfo{"Init_Class"}}))
    {
        $DEBUG_LOG .= "Failed to create instances for these classes:\n";
        foreach my $Type (@Types) {
            $DEBUG_LOG .= "  $Type\n";
        }
        delete($DebugInfo{"Init_Class"});
    }
    if($DEBUG_LOG) {
        writeFile($DEBUG_PATH."/log.txt", $DEBUG_LOG."\n");
    }
}

sub printMsg($$)
{
    my ($Type, $Msg) = @_;
    if($Type!~/\AINFO/) {
        $Msg = $Type.": ".$Msg;
    }
    if($Type!~/_C\Z/) {
        $Msg .= "\n";
    }
    if($Type eq "ERROR") {
        print STDERR $Msg;
    }
    else {
        print $Msg;
    }
}

sub exitStatus($$)
{
    my ($Code, $Msg) = @_;
    printMsg("ERROR", $Msg);
    exit($ERROR_CODE{$Code});
}

sub listDir($)
{
    my $Path = $_[0];
    return () if(not $Path or not -d $Path);
    opendir(my $DH, $Path);
    return () if(not $DH);
    my @Contents = grep { $_ ne "." and $_ ne ".." } readdir($DH);
    return @Contents;
}

sub read_ABI($)
{
    my $Path = $_[0];
    
    # check ACC
    if(my $Version = `$ABI_CC -dumpversion`)
    {
        if(cmpVersions($Version, $ABI_CC_VERSION)<0) {
            exitStatus("Module_Error", "the version of ABI Compliance Checker should be $ABI_CC_VERSION or newer");
        }
    }
    else {
        exitStatus("Module_Error", "cannot find \'$ABI_CC\'");
    }
    
    my $Extra_Dir = $TMP_DIR."/extra-info";
    my $ABI_Dir = $TMP_DIR;
    if($Debug)
    {
        $Extra_Dir = $DEBUG_PATH."/extra-info";
        $ABI_Dir = $DEBUG_PATH;
    }
    
    if($UseCache and -f $CACHE_PATH."/ABI.dump")
    { # use cache
        printMsg("INFO", "Using cached ABI dump");
        $Extra_Dir = $CACHE_PATH."/extra-info";
        $ABI_Dir = $CACHE_PATH;
    }
    else
    {
        printMsg("INFO", "creating ABI dump ...");
        mkpath($Extra_Dir);
        
        # clear cache
        rmtree($CACHE_PATH);
        
        my $Cmd = $ABI_CC." -l $TargetLibraryName -dump \"$Path\" -dump-path \"".$ABI_Dir."/ABI.dump\"";
        $Cmd .= " -extra-info \"$Extra_Dir\""; # include paths and dependent libs
        $Cmd .= " -extra-dump"; # dump all symbols
        if($TargetVersion) {
            $Cmd .= " -vnum \"$TargetVersion\"";
        }
        if($RelativeDirectory) {
            $Cmd .= " -relpath \"$RelativeDirectory\"";
        }
        if($CheckHeadersOnly) {
            $Cmd .= " -headers-only";
        }
        if($Debug)
        {
            $Cmd .= " -debug";
            printMsg("INFO", "running $Cmd");
        }
        
        $Cmd .= " >$TMP_DIR/null";
        
        qx/$Cmd/;
        
        if(not -f $ABI_Dir."/ABI.dump") {
            exit(1);
        }
        
        if($UseCache)
        { # cache ABI dump
            printMsg("INFO", "cache ABI dump");
            mkpath($CACHE_PATH."/extra-info");
            foreach (listDir($Extra_Dir)) {
                copy($Extra_Dir."/".$_, $CACHE_PATH."/extra-info");
            }
            copy($ABI_Dir."/ABI.dump", $CACHE_PATH);
        }
    }
    
    # read ABI dump
    my $ABI_Dump = readFile($ABI_Dir."/ABI.dump");
    
    # extra info
    if(my $Str = readFile($Extra_Dir."/include-string"))
    {
        $Str=~s/\A\s+//;
        if($TestFormat eq "GCC")
        {
            $IncludeString = $Str;
        }
        else
        {
            $Str=~s/\\//g; # unescape
            
            foreach (split(/\s*\-I/, $Str))
            {
                if($_) {
                    $IncludeString .= " ".inc_opt($_, $TestFormat);
                }
            }
            
        }
    }
    
    $LibString = readFile($Extra_Dir."/libs-string");
    
    if(my $RInc = eval(readFile($Extra_Dir."/recursive-includes")))
    {
        %RecursiveIncludes = %{$RInc};
        foreach my $K1 (sort {length($a)<=>length($b)} keys(%RecursiveIncludes))
        {
            registerHeader($K1, \%KnownHeaders);
            foreach my $K2 (sort {length($a)<=>length($b)} keys(%{$RecursiveIncludes{$K1}}))
            {
                registerHeader($K2, \%KnownHeaders);
                $RecursiveIncludes_R{$K2}{$K1} = 1;
                
                if($RegisteredHeaders_R{$K1}
                and $RegisteredHeaders_R{$K2})
                {
                    $RegisteredIncludes{$K1}{$K2} = 1;
                    $RegisteredIncludes_R{$K2}{$K1} = 1;
                }
            }
        }
    }
    
    if(my @Paths = split(/\n/, readFile($Extra_Dir."/header-paths")))
    {
        foreach my $P (sort {length($a)<=>length($b)} @Paths) {
            registerHeader($P, \%KnownHeaders);
        }
    }
    
    if(my @Paths = split(/\n/, readFile($Extra_Dir."/lib-paths")))
    {
        foreach my $P (@Paths) {
            $KnownLibs{get_filename($P)} = $P;
        }
    }
    
    if(my @Paths = split(/\n/, readFile($Extra_Dir."/default-includes")))
    { # default include paths
        @DefaultIncPaths = @Paths;
    }
    
    if(my @Paths = split(/\n/, readFile($Extra_Dir."/default-libs")))
    { # default lib paths
        @DefaultLibPaths = @Paths;
    }
    
    if(my @Lines = split(/\n/, readFile($Extra_Dir."/include-redirect")))
    {
        foreach (@Lines)
        {
            if(my ($P1, $P2) = split(";", $_))
            { # separated by ";"
                $Include_Redirect{$P1} = $P2;
            }
        }
    }
    
    if(my $DInc = eval(readFile($Extra_Dir."/direct-includes"))) {
        %DirectIncludes = %{$DInc};
    }
    
    if(not $Debug and not $UseCache)
    {
        rmtree($Extra_Dir);
        unlink($ABI_Dir."/ABI.dump");
    }
    
    if(not $ABI_Dump) {
        exitStatus("Error", "internal error - ABI dump cannot be created");
    }
    
    my $ABI = eval($ABI_Dump);
    
    if(not $ABI) {
        exitStatus("Error", "internal error - eval() procedure seem to not working correctly, try to remove 'use strict' and try again");
    }
    
    %TypeInfo = %{$ABI->{"TypeInfo"}};
    %SymbolInfo = %{$ABI->{"SymbolInfo"}};
    %DepLibrary_Symbol = %{$ABI->{"DepSymbols"}};
    %Library_Symbol = %{$ABI->{"Symbols"}};
    %UndefinedSymbols = %{$ABI->{"UndefinedSymbols"}};
    %Library_Needed = %{$ABI->{"Needed"}};
    
    %Constants = %{$ABI->{"Constants"}};
    %NestedNameSpaces = %{$ABI->{"NameSpaces"}};
    
    $COMMON_LANGUAGE = $ABI->{"Language"};
    
    $ABI = undef; # clear memory
    
    if(defined $UserLang) {
        $COMMON_LANGUAGE = uc($UserLang);
    }
    
    foreach my $P (keys(%DirectIncludes))
    {
        if(defined $RegisteredHeaders_R{$P})
        {
            if($MAX_INC<keys(%{$DirectIncludes{$P}})) {
                $MAX_INC = keys(%{$DirectIncludes{$P}});
            }
        }
        
        foreach my $Inc (keys(%{$DirectIncludes{$P}}))
        {
            if(defined $Constants{$Inc})
            { # FT_FREETYPE_H, etc.
                $Inc = $Constants{$Inc}{"Value"};
                if($Inc=~s/\A([<"])//g
                and $Inc=~s/([>"])\Z//g)
                {
                    $DirectIncludes{$P}{$Inc} = 1;
                    my $Kind = $1 eq ">"?1:-1;
                    if(my $IncP = $KnownHeaders{get_filename($Inc)})
                    {
                        if(defined $RecursiveIncludes{$P}
                        and not defined $RecursiveIncludes{$P}{$IncP})
                        { # add to known headers to recursive includes
                            $RecursiveIncludes{$P}{$IncP} = $Kind;
                            foreach (keys(%{$RecursiveIncludes_R{$P}})) {
                                $RecursiveIncludes{$_}{$IncP} = $Kind;
                            }
                        }
                    }
                }
            }
            
            if(my $Dir = get_dirname($Inc))
            {
                my $Name = get_filename($Inc);
                if($Name ne get_filename($P))
                { # NOTE: stdlib.h includes bits/stdlib.h
                    $IncludePrefix{$Name}{$Dir} = 1;
                }
            }
        }
    }
    
    # recreate environment
    foreach my $Lib_Name (keys(%Library_Symbol))
    {
        foreach my $Symbol (keys(%{$Library_Symbol{$Lib_Name}}))
        {
            if(my $P = identifyLibrary($Lib_Name))
            {
                $Symbol_Library{$Symbol} = $P;
                
                if(index($Symbol, "?")!=0)
                { # remove version
                    $Symbol=~s/[\@\$]+.+?\Z//g;
                    $Symbol_Library{$Symbol} = $P;
                }
                
                if(not defined $Language{$Lib_Name})
                {
                    if(index($Symbol, "_ZN")==0
                    or index($Symbol, "?")==0) {
                        $Language{$Lib_Name} = "C++"
                    }
                }
            }
        }
    }
    foreach my $Lib_Name (keys(%DepLibrary_Symbol))
    {
        foreach my $Symbol (keys(%{$DepLibrary_Symbol{$Lib_Name}}))
        {
            if(my $P = identifyLibrary($Lib_Name))
            {
                $DepSymbol_Library{$Symbol} = $P;
                
                if(index($Symbol, "?")!=0)
                { # remove version
                    $Symbol=~s/[\@\$]+.+?\Z//g;
                    $DepSymbol_Library{$Symbol} = $P;
                }
                
                if(not defined $Language{$Lib_Name})
                {
                    if(index($Symbol, "_ZN")==0
                    or index($Symbol, "?")==0) {
                        $Language{$Lib_Name} = "C++"
                    }
                }
            }
        }
    }
    foreach my $NS (keys(%NestedNameSpaces))
    {
        foreach (split("::", $NS)) {
            $NameSpaces{$NS} = 1;
        }
    }
    
    my %Ctors = ();
    my @IDs = sort {int($a)<=>int($b)} keys(%SymbolInfo);
    
    foreach my $InfoId (@IDs)
    {
        if(my $Mangled = $SymbolInfo{$InfoId}{"MnglName"})
        { # unmangling
            $tr_name{$Mangled} = $SymbolInfo{$InfoId}{"Unmangled"};
        }
        else
        { # ABI dumps have no mangled names for C-functions
            $SymbolInfo{$InfoId}{"MnglName"} = $SymbolInfo{$InfoId}{"ShortName"};
        }
        if(my $ClassId = $SymbolInfo{$InfoId}{"Class"})
        {
            $Library_Class{$ClassId} = 1;
            
            if(not $SymbolInfo{$InfoId}{"Static"})
            { # support for ACC >= 1.99.1
              # remove artificial "this" parameter
                if(defined $SymbolInfo{$InfoId}{"Param"}
                and defined $SymbolInfo{$InfoId}{"Param"}{0})
                {
                    if($SymbolInfo{$InfoId}{"Param"}{0}{"name"} eq "this")
                    {
                        foreach my $MP (0 .. keys(%{$SymbolInfo{$InfoId}{"Param"}})-2)
                        {
                            $SymbolInfo{$InfoId}{"Param"}{$MP} = $SymbolInfo{$InfoId}{"Param"}{$MP+1};
                        }
                        delete($SymbolInfo{$InfoId}{"Param"}{keys(%{$SymbolInfo{$InfoId}{"Param"}})-1});
                        
                        if(not keys(%{$SymbolInfo{$InfoId}{"Param"}})) {
                            delete($SymbolInfo{$InfoId}{"Param"});
                        }
                    }
                }
            }
        }
        if(defined $SymbolInfo{$InfoId}{"Param"})
        {
            foreach my $Pos (keys(%{$SymbolInfo{$InfoId}{"Param"}}))
            {
                my $TypeId = $SymbolInfo{$InfoId}{"Param"}{$Pos}{"type"};
                if($TypeInfo{$TypeId}{"Type"} eq "Restrict") {
                    $SymbolInfo{$InfoId}{"Param"}{$Pos}{"type"} = $TypeInfo{$TypeId}{"BaseType"};
                }
            }
        }
        if(defined $SymbolInfo{$InfoId}{"Constructor"}) {
            $Ctors{$SymbolInfo{$InfoId}{"Class"}}{$InfoId} = 1;
        }
    }
    
    my $MAX = $IDs[$#IDs] + 1;
    
    foreach my $TypeId (sort {int($a)<=>int($b)} keys(%TypeInfo))
    { # order is important
        if(not defined $TypeInfo{$TypeId}{"Tid"}) {
            $TypeInfo{$TypeId}{"Tid"} = $TypeId;
        }
        if(defined $TypeInfo{$TypeId}{"BaseType"})
        {
            if(defined $TypeInfo{$TypeId}{"BaseType"}{"Tid"})
            { # format of ABI dump changed in ACC 1.99
                $TypeInfo{$TypeId}{"BaseType"} = $TypeInfo{$TypeId}{"BaseType"}{"Tid"};
            }
        }
        my %TInfo = %{$TypeInfo{$TypeId}};
        if(defined $TInfo{"Base"})
        {
            foreach (keys(%{$TInfo{"Base"}})) {
                $Class_SubClasses{$_}{$TypeId} = 1;
            }
        }
        if($TInfo{"Type"} eq "Typedef"
        and defined $TInfo{"BaseType"})
        {
            if(my $BTid = $TInfo{"BaseType"})
            {
                my $BName = $TypeInfo{$BTid}{"Name"};
                if(not $BName)
                { # broken type
                    next;
                }
                if($TInfo{"Name"} eq $BName)
                { # typedef to "class Class"
                  # should not be registered in TName_Tid
                    next;
                }
                if(not $Typedef_BaseName{$TInfo{"Name"}}) {
                    $Typedef_BaseName{$TInfo{"Name"}} = $BName;
                }
                if(selectType($TypeId)) {
                    $Type_Typedef{$BTid}{$TypeId} = 1;
                }
            }
        }
        if($TInfo{"Type"} eq "Intrinsic"
        or $TInfo{"Type"} eq "Pointer")
        { # support for SUSE
          # integer_type has srcp dump{1-2}.i
            delete($TypeInfo{$TypeId}{"Header"});
        }
        if(not $TName_Tid{$TInfo{"Name"}})
        { # classes: class (id1), typedef (artificial, id2 > id1)
            $TName_Tid{$TInfo{"Name"}} = $TypeId;
        }
        if(my $Prefix = getPrefix($TInfo{"Name"})) {
            $Library_Prefixes{$Prefix} += 1;
        }
        
        if($TInfo{"Type"} eq "Array")
        { # size in bytes to size in elements
            if($TInfo{"Name"}=~/\[(\d+)\]/) {
                $TypeInfo{$TypeId}{"Count"} = $1;
            }
        }
        
        if($TInfo{"Type"} eq "Class"
        and not defined $Ctors{$TypeId})
        { # add default c-tors
            %{$SymbolInfo{$MAX++}} = (
                "Class"=>$TypeId,
                "Constructor"=>1,
                "Header"=>$TInfo{"Header"},
                "InLine"=>1,
                "Line"=>$TInfo{"Line"},
                "ShortName"=>$TInfo{"Name"},
                "MnglName"=>"_aux_".$MAX."_C1E"
            );
        }
    }
    
    if($COMMON_LANGUAGE eq "C")
    {
        if(my $TypeId = get_TypeIdByName("struct __exception*"))
        {
            $TypeInfo{$TypeId}{"Name"} = "struct exception*";
            $TypeInfo{$TypeInfo{$TypeId}{"BaseType"}}{"Name"} = "struct exception";
        }
    }
}

sub identifyLibrary($)
{
    my $Name = $_[0];
    if(my $Path = $RegisteredLibs{$Name}) {
        return $Path;
    }
    elsif(my $Path = $KnownLibs{$Name}) {
        return $Path;
    }
    return $Name;
}

sub selectType($)
{
    my $Tid = $_[0];
    my $Name = $TypeInfo{$Tid}{"Name"};
    if(index($Name, "::_")!=-1)
    { # std::basic_istream<wchar_t>::__streambuf_type
        return 0;
    }
    if(index($Name, "_")==0)
    { # __gthread_t
        return 0;
    }
    if(get_depth($Name, "::")>=2)
    { # std::vector::difference_type
        return 0;
    }
    if(get_depth($Name, "_")>=3)
    { # std::random_access_iterator_tag
        return 0;
    }
    if(index($Name, ">::")!=-1)
    { # std::collate<char>::collate
        return 0;
    }
    return 1;
}

sub skipHeader($)
{
    if(defined $Cache{"skipHeader"}{$_[0]}) {
        return $Cache{"skipHeader"}{$_[0]}
    }
    return ($Cache{"checkHeader"}{$_[0]} = skipHeader_I($_[0]));
}

sub skipHeader_I($)
{
    my $Path = $_[0];
    return 1 if(not $Path);
    if(not keys(%SkipHeaders)) {
        return 0;
    }
    my $Name = get_filename($Path);
    if(my $Kind = $SkipHeaders{"Name"}{$Name}) {
        return $Kind;
    }
    foreach my $D (keys(%{$SkipHeaders{"Path"}}))
    {
        if(index($Path, $D)!=-1)
        {
            if($Path=~/\Q$D\E([\/\\]|\Z)/) {
                return $SkipHeaders{"Path"}{$D};
            }
        }
    }
    foreach my $P (keys(%{$SkipHeaders{"Pattern"}}))
    {
        if(my $Kind = $SkipHeaders{"Pattern"}{$P})
        {
            if($Name=~/$P/) {
                return $Kind;
            }
            if($P=~/[\/\\]/ and $Path=~/$P/) {
                return $Kind;
            }
        }
    }
    return 0;
}

sub classifyPath($)
{
    my $Path = $_[0];
    if($Path=~/[\*\[]/)
    { # wildcard
        $Path=~s/\*/.*/g;
        $Path=~s/\\/\\\\/g;
        return ($Path, "Pattern");
    }
    elsif($Path=~/[\/\\]/)
    { # directory or relative path
        return (path_format($Path, $OSgroup), "Path");
    }
    else {
        return ($Path, "Name");
    }
}

sub detectInstallPrefix()
{
    my @Headers = sort split(/\s*\n\s*/, $Descriptor{"Headers"});
    my @Libs = sort split(/\s*\n\s*/, $Descriptor{"Libs"});
    
    # detect install prefix
    if(@Headers and @Libs) {
        $INSTALL_PREFIX = detectPrefix(@Headers, @Libs);
    }
}

sub registerFiles()
{
    
    foreach my $Path (split(/\s*\n\s*/, $Descriptor{"SkipHeaders"}))
    {
        my ($CPath, $Type) = classifyPath($Path);
        $SkipHeaders{$Type}{$CPath} = 1;
    }
    
    foreach my $Path (split(/\s*\n\s*/, $Descriptor{"SkipIncluding"}))
    {
        my ($CPath, $Type) = classifyPath($Path);
        $SkipHeaders{$Type}{$CPath} = 2;
    }
    
    my @Headers = sort split(/\s*\n\s*/, $Descriptor{"Headers"});
    my @Libs = sort split(/\s*\n\s*/, $Descriptor{"Libs"});
    
    foreach my $Path (@Headers) {
        registerHeaders($Path);
    }
    
    foreach my $Path (@Libs) {
        registerLibs($Path);
    }
}

sub detectPrefix(@)
{
    my @Files = @_;
    
    my $F1 = $Files[0];
    $F1 = get_abs_path($F1);
    
    $F1=~s&[\/]+\Z&&g;
    $F1=~s&[\/]{2,}&/&g;
    
    my @Prefixes = ($F1);
    
    while($F1=~s&/[^/]*\Z&&)
    {
        if($F1!~/\A\/[^\/]*\Z/) {
            push(@Prefixes, $F1);
        }
    };
    
    foreach my $Prefix (@Prefixes)
    {
        my $Found = 1;
        
        foreach my $File (@Files)
        {
            $File = get_abs_path($File);
            
            if($File!~/\A\Q$Prefix\E(\/|\Z)/)
            {
                $Found = 0;
                last;
            }
        }
        
        if($Found)
        {
            return $Prefix;
        }
    }
    
    return undef;
}

sub getReportFooter()
{
    my $Footer = "<hr/><div class='footer' align='right'><i>Generated on ".(localtime time);
    $Footer .= " by <a href='".$HomePage."'>API Sanity Checker</a> $TOOL_VERSION &#160;";
    $Footer .= "</i></div>";
    $Footer .= "<br/>";
    return $Footer;
}

sub scenario()
{
    if(defined $Help)
    {
        HELP_MESSAGE();
        exit(0);
    }
    if(defined $InfoMsg)
    {
        INFO_MESSAGE();
        exit(0);
    }
    if(defined $ShowVersion)
    {
        printMsg("INFO", "API Sanity Checker $TOOL_VERSION\nCopyright (C) 2015 Andrey Ponomarenko's ABI Laboratory\nLicense: LGPL or GPL <http://www.gnu.org/licenses/>\nThis program is free software: you can redistribute it and/or modify it.\n\nWritten by Andrey Ponomarenko.");
        exit(0);
    }
    if(defined $DumpVersion)
    {
        printMsg("INFO", $TOOL_VERSION);
        exit(0);
    }
    if(not defined $Template2Code) {
        $Standalone = 1;
    }
    if($OSgroup eq "windows")
    {
        if(not $ENV{"DevEnvDir"}
        or not $ENV{"LIB"}) {
            exitStatus("Error", "can't start without VS environment (vsvars32.bat)");
        }
    }
    if(defined $TargetCompiler)
    {
        $TargetCompiler = uc($TargetCompiler);
        if($TargetCompiler!~/\A(GCC|CL)\Z/) {
            exitStatus("Error", "Target compiler is not either gcc or cl");
        }
    }
    else
    { # default
        if($OSgroup eq "windows") {
            $TargetCompiler = "CL";
        }
    }
    if(defined $TestTool)
    {
        loadModule("RegTests");
        testTool($Debug, $LIB_EXT, $TargetCompiler);
        exit(0);
    }
    if(not defined $TargetLibraryName) {
        exitStatus("Error", "library name is not selected (-l option)");
    }
    else
    { # validate library name
        if($TargetLibraryName=~/[\*\/\\]/) {
            exitStatus("Error", "These symbols are not allowed in the library name: \"\\\", \"\/\" and \"*\"");
        }
    }
    if(not $TargetTitle) {
        $TargetTitle = $TargetLibraryName;
    }
    if($TestDataPath and not -d $TestDataPath) {
        exitStatus("Access_Error", "can't access directory \'$TestDataPath\'");
    }
    if($SpecTypes_PackagePath and not -f $SpecTypes_PackagePath) {
        exitStatus("Access_Error", "ERROR: can't access file \'$SpecTypes_PackagePath\'");
    }
    if($InterfacesListPath)
    {
        if(-f $InterfacesListPath)
        {
            foreach my $Interface (split(/\n/, readFile($InterfacesListPath))) {
                $InterfacesList{$Interface} = 1;
            }
        }
        else {
            exitStatus("Access_Error", "can't access file \'$InterfacesListPath\'");
        }
    }
    
    if(not $Descriptor{"Path"}) {
        exitStatus("Error", "library descriptor is not selected (option -d PATH)");
    }
    elsif(not -f $Descriptor{"Path"}) {
        exitStatus("Access_Error", "can't access file \'".$Descriptor{"Path"}."\'");
    }
    elsif($Descriptor{"Path"}!~/\.(xml|desc)\Z/i) {
        exitStatus("Error", "descriptor should be *.xml file");
    }
    
    if(not $GenerateTests and not $BuildTests
    and not $RunTests and not $CleanTests and not $CleanSources) {
        exitStatus("Error", "one of these options is not specified: -gen, -build, -run or -clean");
    }
    
    if($ParameterNamesFilePath)
    {
        if(-f $ParameterNamesFilePath)
        {
            foreach my $Line (split(/\n/, readFile($ParameterNamesFilePath)))
            {
                if($Line=~s/\A(\w+)\;//)
                {
                    my $Interface = $1;
                    if($Line=~/;(\d+);/)
                    {
                        while($Line=~s/(\d+);(\w+)//) {
                            $AddIntParams{$Interface}{$1}=$2;
                        }
                    }
                    else
                    {
                        my $Num = 0;
                        foreach my $Name (split(/;/, $Line))
                        {
                            $AddIntParams{$Interface}{$Num}=$Name;
                            $Num+=1;
                        }
                    }
                }
            }
        }
        else {
            exitStatus("Access_Error", "can't access file \'$ParameterNamesFilePath\'");
        }
    }
    if($TargetInterfaceName and defined $Template2Code) {
        exitStatus("Error", "selecting of symbol is not supported in the Template2Code format");
    }
    if(($BuildTests or $RunTests or $CleanTests) and defined $Template2Code
    and not defined $GenerateTests) {
        exitStatus("Error", "see Template2Code technology documentation for building and running tests:\n       http://template2code.sourceforge.net/t2c-doc/index.htm");
    }
    if($Strict) {
        ($StrictGen, $StrictBuild, $StrictRun) = (1, 1, 1);
    }
    if($GenerateTests)
    {
        readDescriptor($Descriptor{"Path"});
        registerFiles();
        detectInstallPrefix();
        
        $TestFormat = "GCC";
        if($OSgroup eq "windows"
        and $TargetCompiler eq "CL")
        { # default for Windows
            $TestFormat = "CL";
        }
        
        $TEST_SUITE_PATH = ((defined $Template2Code)?"tests_t2c":"tests")."/$TargetLibraryName/".$Descriptor{"Version"};
        my $LOG_DIR = "logs/".$TargetLibraryName."/".$Descriptor{"Version"};
        rmtree($LOG_DIR);
        mkpath($LOG_DIR);
        $LOG_PATH = abs_path($LOG_DIR)."/log.txt";
        $CACHE_PATH = "cache/".$TargetLibraryName."/".$Descriptor{"Version"};
        
        initLogging();
        
        read_ABI($Descriptor{"Path"});
        
        prepareInterfaces();
        add_os_spectypes();
        if($SpecTypes_PackagePath) {
            readSpecTypes(readFile($SpecTypes_PackagePath));
        }
        
        setRegularities();
        markAbstractClasses();
        
        if(not keys(%Common_SpecEnv))
        { # automatic preamble and finalization
            add_LibraryPreambleAndFinalization();
        }
        if($TargetInterfaceName)
        {
            if(not $CompleteSignature{$TargetInterfaceName})
            {
                my $EMsg = "specified symbol is not found\n";
                if($Func_ShortName_MangledName{$TargetInterfaceName})
                {
                    if(keys(%{$Func_ShortName_MangledName{$TargetInterfaceName}})==1) {
                        $EMsg .= "did you mean ".(keys(%{$Func_ShortName_MangledName{$TargetInterfaceName}}))[0]." ?";
                    }
                    else {
                        $EMsg .= "candidates are:\n ".join("\n ", keys(%{$Func_ShortName_MangledName{$TargetInterfaceName}}));
                    }
                }
                exitStatus("Error", $EMsg);
            }
            if(not symbolFilter($TargetInterfaceName)) {
                exitStatus("Error", "can't generate test for $TargetInterfaceName");
            }
            printMsg("INFO_C", "generating test for $TargetInterfaceName ... ");
            readScenario();
            generateTest($TargetInterfaceName);
            write_scenario();
            if($GenResult{$TargetInterfaceName}{"IsCorrect"}) {
                printMsg("INFO", "success");
            }
            else {
                printMsg("INFO", "fail");
            }
            create_Index();
        }
        else
        {
            generateTests();
            create_Index() if(not defined $Template2Code);
        }
        if($ResultCounter{"Gen"}{"Success"}>0)
        {
            if($TargetInterfaceName)
            {
                my $TestPath = getTestPath($TargetInterfaceName);
                printMsg("INFO", "see generated test in \'$TestPath/\'");
            }
            else
            {
                printMsg("INFO", "");
                if($Template2Code)
                {
                    printMsg("INFO", "1. see generated test suite in the directory \'$TEST_SUITE_PATH/\'");
                    printMsg("INFO", "2. see Template2Code technology documentation for building and running tests:\nhttp://template2code.sourceforge.net/t2c-doc/index.html");
                }
                else
                {
                    printMsg("INFO", "1. see generated test suite in the directory \'$TEST_SUITE_PATH/\'");
                    printMsg("INFO", "2. for viewing tests use \'$TEST_SUITE_PATH/view_tests.html\'");
                    printMsg("INFO", "3. use -build option for building tests");
                }
                printMsg("INFO", "");
            }
        }
        if($Debug)
        { # write debug log
            writeDebugLog();
        }
        remove_option(\@INPUT_OPTIONS, "gen");
        remove_option(\@INPUT_OPTIONS, "generate");
    }
    if($BuildTests and $GenerateTests and defined $Standalone)
    { # allocated memory for tests generation should be returned to OS
        system("perl", $0, @INPUT_OPTIONS); # build + run
        exit($?>>8);
    }
    elsif($BuildTests and defined $Standalone)
    {
        readDescriptor($Descriptor{"Path"});
        detectInstallPrefix();
        
        $TEST_SUITE_PATH = "tests/$TargetLibraryName/".$Descriptor{"Version"};
        if(not -e $TEST_SUITE_PATH) {
            exitStatus("Error", "tests were not generated yet");
        }
        if($TargetInterfaceName)
        {
            printMsg("INFO_C", "building test for $TargetInterfaceName ... ");
            readScenario();
            buildTest($TargetInterfaceName);
            if($BuildResult{$TargetInterfaceName}{"IsCorrect"})
            {
                if($BuildResult{$TargetInterfaceName}{"Warnings"}) {
                    printMsg("INFO", "success (Warnings)");
                }
                else {
                    printMsg("INFO", "success");
                }
            }
            elsif(not $BuildResult{$TargetInterfaceName}{"TestNotExists"}) {
                printMsg("INFO", "fail");
            }
        }
        else {
            buildTests();
        }
        if($ResultCounter{"Build"}{"Success"}>0
        and not $TargetInterfaceName and not $RunTests) {
            printMsg("INFO", "use -run option to run tests");
        }
        remove_option(\@INPUT_OPTIONS, "build");
        remove_option(\@INPUT_OPTIONS, "make");
    }
    if(($CleanTests or $CleanSources) and defined $Standalone)
    {
        readDescriptor($Descriptor{"Path"});
        $TEST_SUITE_PATH = "tests/$TargetLibraryName/".$Descriptor{"Version"};
        if(not -e $TEST_SUITE_PATH) {
            exitStatus("Error", "tests were not generated yet");
        }
        if($TargetInterfaceName)
        {
            printMsg("INFO_C", "cleaning test for $TargetInterfaceName ... ");
            readScenario();
            cleanTest($TargetInterfaceName);
            printMsg("INFO", "success");
        }
        else {
            cleanTests();
        }
        remove_option(\@INPUT_OPTIONS, "clean") if($CleanTests);
        remove_option(\@INPUT_OPTIONS, "view-only") if($CleanSources);
        
    }
    if($RunTests and $GenerateTests and defined $Standalone)
    { # tests running requires creation of two processes, so allocated memory must be returned to the system
        system("perl", $0, @INPUT_OPTIONS);
        exit($ResultCounter{"Build"}{"Fail"}!=0 or $?>>8);
    }
    elsif($RunTests and defined $Standalone)
    {
        initSignals();
        readDescriptor($Descriptor{"Path"});
        detectInstallPrefix();
        
        $TEST_SUITE_PATH = "tests/$TargetLibraryName/".$Descriptor{"Version"};
        $REPORT_PATH = "test_results/$TargetLibraryName/".$Descriptor{"Version"};
        if(not -e $TEST_SUITE_PATH) {
            exitStatus("Error", "tests were not generated yet");
        }
        if($OSgroup eq "windows") {
            createTestRunner();
        }
        my $ErrCode = 0;
        if($TargetInterfaceName)
        {
            readScenario();
            my $XvfbStarted = 0;
            if($UseXvfb and (-f $Interface_TestDir{$TargetInterfaceName}."/test"
            or -f $Interface_TestDir{$TargetInterfaceName}."/test.exe")) {
                $XvfbStarted = runXvfb();
            }
            printMsg("INFO_C", "running test for $TargetInterfaceName ... ");
            $ErrCode = runTest($TargetInterfaceName);
            stopXvfb($XvfbStarted) if($UseXvfb);
            if($RunResult{$TargetInterfaceName}{"IsCorrect"})
            {
                if($RunResult{$TargetInterfaceName}{"Warnings"}) {
                    printMsg("INFO", "success (Warnings)");
                }
                else {
                    printMsg("INFO", "success");
                }
            }
            elsif(not $RunResult{$TargetInterfaceName}{"TestNotExists"}) {
                printMsg("INFO", "fail (".get_problem_title($RunResult{$TargetInterfaceName}{"Type"}, $RunResult{$TargetInterfaceName}{"Value"}).")");
            }
        }
        else {
            $ErrCode = runTests();
        }
        mkpath($REPORT_PATH);
        if((not $TargetInterfaceName or not $RunResult{$TargetInterfaceName}{"TestNotExists"})
        and keys(%Interface_TestDir) and not $ErrCode)
        {
            unlink($REPORT_PATH."/test_results.html");# removing old report
            printMsg("INFO", "creating report ...");
            createReport();
            printMsg("INFO", "see test results in the file:\n  $REPORT_PATH/test_results.html");
        }
        exit($ResultCounter{"Run"}{"Fail"}!=0);
    }
    exit($ResultCounter{"Build"}{"Fail"}!=0);
}

scenario();
