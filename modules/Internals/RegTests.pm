###########################################################################
# Module to test API Sanity Checker
#
# Copyright (C) 2009-2011 Institute for System Programming, RAS
# Copyright (C) 2011-2015 Andrey Ponomarenko's ABI laboratory
#
# Written by Andrey Ponomarenko
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
use strict;

my ($Debug, $LIB_EXT, $TargetCompiler);
my $OSgroup = get_OSgroup();

sub testTool($$$$)
{
    ($Debug, $LIB_EXT, $TargetCompiler) = @_;
    
    testC();
    testCpp();
}

sub testCpp()
{
    printMsg("INFO", "testing C++ library API");
    my ($DataDefs, $Sources)  = ();
    my $DeclSpec = ($OSgroup eq "windows")?"__declspec( dllexport )":"";
    
    # Inline
    $DataDefs .= "
        inline int inline_func(int param) { return 0; }";
    
    # Simple parameters
    $DataDefs .= "
        $DeclSpec int func_simple_parameters(
            int a,
            float b,
            double c,
            long double d,
            long long e,
            char f,
            unsigned int g,
            const char* h,
            char* i,
            unsigned char* j,
            char** k,
            const char*& l,
            const char**& m,
            char const*const* n,
            unsigned int* offset
        );";
    $Sources .= "
        int func_simple_parameters(
            int a,
            float b,
            double c,
            long double d,
            long long e,
            char f,
            unsigned int g,
            const char* h,
            char* i,
            unsigned char* j,
            char** k,
            const char*& l,
            const char**& m,
            char const*const* n,
            unsigned int* offset ) {
            return 1;
        }";
    
    # Initialization by interface
    $DataDefs .= "
        struct simple_struct {
            int m;
        };
        $DeclSpec struct simple_struct simple_func(int a, int b);";
    $Sources .= "
        struct simple_struct simple_func(int a, int b)
        {
            struct simple_struct x = {1};
            return x;
        }";
    
    $DataDefs .= "
        $DeclSpec int func_init_param_by_interface(struct simple_struct p);";
    $Sources .= "
        int func_init_param_by_interface(struct simple_struct p) {
            return 1;
        }";
    
    # Private Interface
    $DataDefs .= "
        class $DeclSpec private_class {
        private:
            private_class(){};
            int a;
            float private_func(float p);
        };";
    $Sources .= "
        float private_class::private_func(float p) {
            return p;
        }";
    
    # Assembling structure
    $DataDefs .= "
        struct complex_struct {
            int a;
            float b;
            struct complex_struct* c;
        };";
    
    $DataDefs .= "
        $DeclSpec int func_assemble_param(struct complex_struct p);";
    $Sources .= "
        int func_assemble_param(struct complex_struct p) {
            return 1;
        }";
    
    # Abstract class
    $DataDefs .= "
        class $DeclSpec abstract_class {
        public:
            abstract_class(){};
            int a;
            virtual float virt_func(float p) = 0;
            float func(float p);
        };";
    $Sources .= "
        float abstract_class::func(float p) {
            return p;
        }";
    
    # Parameter FuncPtr
    $DataDefs .= "
        typedef int (*funcptr_type)(int a, int b);
        $DeclSpec funcptr_type func_return_funcptr(int a);
        $DeclSpec int func_param_funcptr(const funcptr_type** p);";
    $Sources .= "
        funcptr_type func_return_funcptr(int a) {
            return 0;
        }
        int func_param_funcptr(const funcptr_type** p) {
            return 0;
        }";

    # Parameter FuncPtr (2)
    $DataDefs .= "
        typedef int (*funcptr_type2)(int a, int b, float c);
        $DeclSpec int func_param_funcptr2(funcptr_type2 p);";
    $Sources .= "
        int func_param_funcptr2(funcptr_type2 p) {
            return 0;
        }";
    
    # Parameter Array
    $DataDefs .= "
        $DeclSpec int func_param_array(struct complex_struct const ** x);";
    $Sources .= "
        int func_param_array(struct complex_struct const ** x) {
            return 0;
        }";
    
    # Nested classes
    $DataDefs .= "//Nested classes
        class $DeclSpec A {
        public:
            virtual bool method1() {
                return false;
            };
        };

        class $DeclSpec B: public A { };

        class $DeclSpec C: public B {
        public:
            C() { };
            virtual bool method1();
            virtual bool method2() const;
        };";
    $Sources .= "//Nested classes
        bool C::method1() {
            return false;
        };

        bool C::method2() const {
            return false;
        };";
    
    # Throw class
    $DataDefs .= "
        class $DeclSpec Exception {
        public:
            Exception();
            int a;
        };";
    $Sources .= "
        Exception::Exception() { }";
    $DataDefs .= "
        class $DeclSpec throw_class {
        public:
            throw_class() { };
            int a;
            virtual float virt_func(float p) throw(Exception) = 0;
            float func(float p);
        };";
    $Sources .= "
        float throw_class::func(float p) {
            return p;
        }";

    # Should crash
    $DataDefs .= "
        $DeclSpec int func_should_crash();";
    $Sources .= "
        int func_should_crash()
        {
            int *x = 0x0;
            *x = 1;
            return 1;
        }";
    
    runSelfTests("libsample_cpp", "C++", "namespace TestNS {\n$DataDefs\n}\n", "namespace TestNS {\n$Sources\n}\n", "type_test_opaque", "_ZN18type_test_internal5func1ES_");
}

sub testC()
{
    printMsg("INFO", "\ntesting C library API");
    my ($DataDefs, $Sources)  = ();
    my $DeclSpec = ($OSgroup eq "windows")?"__declspec( dllexport )":"";
    
    # Simple parameters
    $DataDefs .= "
        $DeclSpec int func_simple_parameters(
            int a,
            float b,
            double c,
            long double d,
            long long e,
            char f,
            unsigned int g,
            const char* h,
            char* i,
            unsigned char* j,
            char** k);";
    $Sources .= "
        int func_simple_parameters(
            int a,
            float b,
            double c,
            long double d,
            long long e,
            char f,
            unsigned int g,
            const char* h,
            char* i,
            unsigned char* j,
            char** k) {
            return 1;
        }";
    
    # Initialization by interface
    $DataDefs .= "
        struct simple_struct {
            int m;
        };
        $DeclSpec struct simple_struct simple_func(int a, int b);";
    $Sources .= "
        struct simple_struct simple_func(int a, int b)
        {
            struct simple_struct x = {1};
            return x;
        }";
    
    $DataDefs .= "
        $DeclSpec int func_init_param_by_interface(struct simple_struct p);";
    $Sources .= "
        int func_init_param_by_interface(struct simple_struct p) {
            return 1;
        }";
    
    # Assembling structure
    $DataDefs .= "
        typedef struct complex_struct {
            int a;
            float b;
            struct complex_struct* c;
        } complex_struct;";
    
    $DataDefs .= "
        $DeclSpec int func_assemble_param(struct complex_struct p);";
    $Sources .= "
        int func_assemble_param(struct complex_struct p) {
            return 1;
        }";
    
    # Initialization by out parameter
    $DataDefs .= "
        struct out_opaque_struct;
        $DeclSpec void create_out_param(struct out_opaque_struct** out);";
    $Sources .= "
        struct out_opaque_struct {
            const char* str;
        };
        $DeclSpec void create_out_param(struct out_opaque_struct** out) { }\n";
    
    $DataDefs .= "
        $DeclSpec int func_init_param_by_out_param(struct out_opaque_struct* p);";
    $Sources .= "
        int func_init_param_by_out_param(struct out_opaque_struct* p) {
            return 1;
        }";
    
    # Should crash
    $DataDefs .= "
        $DeclSpec int func_should_crash();";
    $Sources .= "
        int func_should_crash()
        {
            int *x = 0x0;
            *x = 1;
            return 1;
        }";
    
    # Function with out parameter
    $DataDefs .= "
        $DeclSpec int func_has_out_opaque_param(struct out_opaque_struct* out);";
    $Sources .= "
        int func_has_out_opaque_param(struct out_opaque_struct* out) {
            return 1;
        }";

    # C++ keywords
    $DataDefs .= "
        $DeclSpec int operator();";
    $Sources .= "
        int operator() {
            return 1;
        }";
    
    
    runSelfTests("libsample_c", "C", $DataDefs, $Sources, "type_test_opaque", "func_test_internal");
}

sub readFirstLine($)
{
    my $Path = $_[0];
    return "" if(not $Path or not -f $Path);
    open (FILE, $Path);
    my $FirstLine = <FILE>;
    close(FILE);
    return $FirstLine;
}

sub runSelfTests($$$$$$)
{
    my ($LibName, $Lang, $DataDefs, $Sources, $Opaque, $Private) = @_;
    my $Ext = ($Lang eq "C++")?"cpp":"c";
    # creating test suite
    rmtree($LibName);
    mkpath($LibName);
    writeFile("$LibName/version", "TEST_1.0 {\n};\nTEST_2.0 {\n};\n");
    writeFile("$LibName/libsample.h", $DataDefs."\n");
    writeFile("$LibName/libsample.$Ext", "#include \"libsample.h\"\n".$Sources."\n");
    writeFile("$LibName/descriptor.xml", "
        <version>
            1.0
        </version>

        <headers>
            ".abs_path($LibName)."
        </headers>

        <libs>
            ".abs_path($LibName)."
        </libs>

        <opaque_types>
            $Opaque
        </opaque_types>

        <skip_symbols>
            $Private
        </skip_symbols>\n");
    my @BuildCmds = ();
    if($OSgroup eq "windows")
    {
        if($TargetCompiler eq "CL")
        {
            push(@BuildCmds, "cl /LD libsample.$Ext >build_out 2>&1");
        }
        else
        {
            if($Lang eq "C++")
            {
                push(@BuildCmds, "g++ -shared libsample.$Ext -o libsample.$LIB_EXT");
                push(@BuildCmds, "g++ -c libsample.$Ext -o libsample.obj");
            }
            else
            {
                push(@BuildCmds, "gcc -shared libsample.$Ext -o libsample.$LIB_EXT");
                push(@BuildCmds, "gcc -c libsample.$Ext -o libsample.obj");
                push(@BuildCmds, "lib libsample.obj >build_out 2>&1");
            }
        }
    }
    elsif($OSgroup eq "linux")
    {
        writeFile("$LibName/version", "VERSION_1.0 {\n};\nVERSION_2.0 {\n};\n");
        my $BCmd = "";
        if($Lang eq "C++") {
            $BCmd = "g++ -Wl,--version-script version -shared libsample.$Ext -o libsample.$LIB_EXT";
        }
        else {
            $BCmd = "gcc -Wl,--version-script version -shared libsample.$Ext -o libsample.$LIB_EXT";
        }
        if(getArch()=~/\A(arm|x86_64)\Z/i)
        { # relocation R_X86_64_32S against `vtable for class' can not be used when making a shared object; recompile with -fPIC
            $BCmd .= " -fPIC";
        }
        push(@BuildCmds, $BCmd);
    }
    elsif($OSgroup eq "macos")
    {
        if($Lang eq "C++") {
            push(@BuildCmds, "g++ -dynamiclib libsample.$Ext -o libsample.$LIB_EXT");
        }
        else {
            push(@BuildCmds, "gcc -dynamiclib libsample.$Ext -o libsample.$LIB_EXT");
        }
    }
    else
    {
        if($Lang eq "C++") {
            push(@BuildCmds, "g++ -shared libsample.$Ext -o libsample.$LIB_EXT");
        }
        else {
            push(@BuildCmds, "gcc -shared libsample.$Ext -o libsample.$LIB_EXT");
        }
    }
    writeFile("$LibName/Makefile", "all:\n\t".join("\n\t", @BuildCmds)."\n");
    foreach (@BuildCmds)
    {
        system("cd $LibName && $_");
        if($?) {
            exitStatus("Error", "can't compile \'$LibName/libsample.$Ext\'");
        }
    }
    # running the tool
    my $Cmd = "perl $0 -l $LibName -d $LibName/descriptor.xml -gen -build -run -show-retval";
    
    if($TargetCompiler) {
        $Cmd .= " -target ".$TargetCompiler;
    }
    if($Debug)
    {
        $Cmd .= " -debug";
        printMsg("INFO", "run $Cmd");
    }
    system($Cmd);
    
    my $ECode = $?>>8;
    
    if($ECode!~/\A[0-1]\Z/)
    { # error
        exitStatus("Error", "analysis has failed");
    }
    
    my ($Total, $Passed, $Failed) = (0, 0, 0);
    if(my $FLine = readFirstLine("test_results/$LibName/1.0/test_results.html"))
    {
        if($FLine=~/total:(\d+)/) {
            $Total = $1;
        }
        if($FLine=~/passed:(\d+)/) {
            $Passed = $1;
        }
        if($FLine=~/failed:(\d+)/) {
            $Failed = $1;
        }
    }
    if($Total==($Passed+$Failed) and (($LibName eq "libsample_c" and $Total>5 and $Failed==1)
    or ($LibName eq "libsample_cpp" and $Total>10 and $Failed==1))) {
        printMsg("INFO", "result: SUCCESS ($Total test cases, $Passed passed, $Failed failed)\n");
    }
    else {
        printMsg("ERROR", "result: FAILED ($Total test cases, $Passed passed, $Failed failed)\n");
    }
}

return 1;