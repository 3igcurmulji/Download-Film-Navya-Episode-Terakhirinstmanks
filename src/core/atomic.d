/**
 * The atomic module provides basic support for lock-free
 * concurrent programming.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2016.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Sean Kelly, Alex Rønne Petersen, Manu Evans
 * Source:    $(DRUNTIMESRC core/_atomic.d)
 */

module core.atomic;

import core.internal.atomic;
import core.internal.attributes : betterC;

version (D_InlineAsm_X86)
{
    version = AsmX86;
    version = AsmX86_32;
    enum has64BitXCHG = false;
    enum has64BitCAS = true;
    enum has128BitCAS = false;
}
else version (D_InlineAsm_X86_64)
{
    version = AsmX86;
    version = AsmX86_64;
    enum has64BitXCHG = true;
    enum has64BitCAS = true;
    enum has128BitCAS = true;
}
else
{
    enum has64BitXCHG = false;
    enum has64BitCAS = false;
    enum has128BitCAS = false;
}

version (AsmX86)
{
    // NOTE: Strictly speaking, the x86 supports atomic operations on
    //       unaligned values.  However, this is far slower than the
    //       common case, so such behavior should be prohibited.
    private bool atomicValueIsProperlyAligned(T)( ref T val ) pure nothrow @nogc @trusted
    {
        return atomicPtrIsProperlyAligned(&val);
    }

    private bool atomicPtrIsProperlyAligned(T)( T* ptr ) pure nothrow @nogc @safe
    {
        // NOTE: 32 bit x86 systems support 8 byte CAS, which only requires
        //       4 byte alignment, so use size_t as the align type here.
        static if ( T.sizeof > size_t.sizeof )
            return cast(size_t)ptr % size_t.sizeof == 0;
        else
            return cast(size_t)ptr % T.sizeof == 0;
    }
}

/**
 * Specifies the memory ordering semantics of an atomic operation.
 *
 * See_Also:
 *     $(HTTP en.cppreference.com/w/cpp/atomic/memory_order)
 */
enum MemoryOrder
{
    /**
     * Not sequenced.
     * Corresponds to $(LINK2 https://llvm.org/docs/Atomics.html#monotonic, LLVM AtomicOrdering.Monotonic)
     * and C++11/C11 `memory_order_relaxed`.
     */
    raw,
    /**
     * Hoist-load + hoist-store barrier.
     * Corresponds to $(LINK2 https://llvm.org/docs/Atomics.html#acquire, LLVM AtomicOrdering.Acquire)
     * and C++11/C11 `memory_order_acquire`.
     */
    acq,
    /**
     * Sink-load + sink-store barrier.
     * Corresponds to $(LINK2 https://llvm.org/docs/Atomics.html#release, LLVM AtomicOrdering.Release)
     * and C++11/C11 `memory_order_release`.
     */
    rel,
    /**
     * Acquire + release barrier.
     * Corresponds to $(LINK2 https://llvm.org/docs/Atomics.html#acquirerelease, LLVM AtomicOrdering.AcquireRelease)
     * and C++11/C11 `memory_order_acq_rel`.
     */
    acq_rel,
    /**
     * Fully sequenced (acquire + release). Corresponds to
     * $(LINK2 https://llvm.org/docs/Atomics.html#sequentiallyconsistent, LLVM AtomicOrdering.SequentiallyConsistent)
     * and C++11/C11 `memory_order_seq_cst`.
     */
    seq,
}

/**
 * Loads 'val' from memory and returns it.  The memory barrier specified
 * by 'ms' is applied to the operation, which is fully sequenced by
 * default.  Valid memory orders are MemoryOrder.raw, MemoryOrder.acq,
 * and MemoryOrder.seq.
 *
 * Params:
 *  val = The target variable.
 *
 * Returns:
 *  The value of 'val'.
 */
TailShared!T atomicLoad(MemoryOrder ms = MemoryOrder.seq, T)( ref const shared T val ) pure nothrow @nogc @trusted
{
    static if ( __traits(isFloating, T) )
    {
        alias IntTy = IntForFloat!T;
        IntTy r = core.internal.atomic.atomicLoad!ms(cast(IntTy*)&val);
        return *cast(T*)&r;
    }
    else
    {
        T r = core.internal.atomic.atomicLoad!ms(cast(T*)&val);
        return *cast(TailShared!T*)&r;
    }
}

/**
 * Writes 'newval' into 'val'.  The memory barrier specified by 'ms' is
 * applied to the operation, which is fully sequenced by default.
 * Valid memory orders are MemoryOrder.raw, MemoryOrder.rel, and
 * MemoryOrder.seq.
 *
 * Params:
 *  val    = The target variable.
 *  newval = The value to store.
 */
void atomicStore(MemoryOrder ms = MemoryOrder.seq, T, V)( ref shared T val, V newval ) pure nothrow @nogc @trusted
    if ( __traits( compiles, { val = newval; } ) )
{
    static if ( __traits(isFloating, T) )
    {
        static assert ( __traits(isFloating, V) && V.sizeof == T.sizeof, "Mismatching argument types." );
        alias IntTy = IntForFloat!T;
        core.internal.atomic.atomicStore!ms(cast(IntTy*)&val, *cast(IntTy*)&newval);
    }
    else
        core.internal.atomic.atomicStore!ms(cast(T*)&val, newval);
}

/**
 * Atomically adds `mod` to the value referenced by `val` and returns the value `val` held previously.
 * This operation is both lock-free and atomic.
 *
 * Params:
 *  val = Reference to the value to modify.
 *  mod = The value to add.
 *
 * Returns:
 *  The value held previously by `val`.
 */
TailShared!(T) atomicFetchAdd(MemoryOrder ms = MemoryOrder.seq, T)( ref shared T val, size_t mod ) pure nothrow @nogc @trusted
    if ( __traits(isIntegral, T) )
in ( atomicValueIsProperlyAligned(val) )
{
    return core.internal.atomic.atomicFetchAdd!ms( &val, cast(T)mod );
}

/**
 * Atomically subtracts `mod` from the value referenced by `val` and returns the value `val` held previously.
 * This operation is both lock-free and atomic.
 *
 * Params:
 *  val = Reference to the value to modify.
 *  mod = The value to subtract.
 *
 * Returns:
 *  The value held previously by `val`.
 */
TailShared!(T) atomicFetchSub(MemoryOrder ms = MemoryOrder.seq, T)( ref shared T val, size_t mod ) pure nothrow @nogc @trusted
    if ( __traits(isIntegral, T) )
in ( atomicValueIsProperlyAligned(val) )
{
    return core.internal.atomic.atomicFetchSub!ms( &val, cast(T)mod );
}

/**
 * Exchange `exchangeWith` with the memory referenced by `here`.
 * This operation is both lock-free and atomic.
 *
 * Params:
 *  here         = The address of the destination variable.
 *  exchangeWith = The value to exchange.
 *
 * Returns:
 *  The value held previously by `here`.
 */
shared(T) atomicExchange(MemoryOrder ms = MemoryOrder.seq,T,V)( shared(T)* here, V exchangeWith ) pure nothrow @nogc @trusted
    if ( !is(T == class) && !is(T U : U*) &&  __traits( compiles, { *here = exchangeWith; } ) )
in ( atomicPtrIsProperlyAligned( here ), "Argument `here` is not properly aligned" )
{
    static if ( __traits(isFloating, T) )
    {
        static assert ( __traits(isFloating, V) && V.sizeof == T.sizeof, "Mismatching argument types." );
        alias IntTy = IntForFloat!T;
        IntTy r = core.internal.atomic.atomicExchange!ms(cast(IntTy*)here, *cast(IntTy*)&exchangeWith);
        return *cast(shared(T)*)&r;
    }
    else
        return core.internal.atomic.atomicExchange!ms(here, exchangeWith);
}

/// Ditto
shared(T) atomicExchange(MemoryOrder ms = MemoryOrder.seq,T,V)( shared(T)* here, shared(V) exchangeWith ) pure nothrow @nogc @safe
    if ( is(T == class) && __traits( compiles, { *here = exchangeWith; } ) )
in ( atomicPtrIsProperlyAligned( here ), "Argument `here` is not properly aligned" )
{
    return core.internal.atomic.atomicExchange!ms(here, exchangeWith);
}

/// Ditto
shared(T) atomicExchange(MemoryOrder ms = MemoryOrder.seq,T,V)( shared(T)* here, shared(V)* exchangeWith ) pure nothrow @nogc @safe
    if ( is(T U : U*) && __traits( compiles, { *here = exchangeWith; } ) )
in ( atomicPtrIsProperlyAligned( here ), "Argument `here` is not properly aligned" )
{
    return core.internal.atomic.atomicExchange!ms(here, exchangeWith);
}

/**
 * Stores 'writeThis' to the memory referenced by 'here' if the value
 * referenced by 'here' is equal to 'ifThis'.  This operation is both
 * lock-free and atomic.
 *
 * Params:
 *  here      = The address of the destination variable.
 *  writeThis = The value to store.
 *  ifThis    = The comparison value.
 *
 * Returns:
 *  true if the store occurred, false if not.
 */
bool cas(T,V1,V2)( shared(T)* here, const V1 ifThis, V2 writeThis ) pure nothrow @nogc @trusted
    if ( !is(T == class) && !is(T U : U*) &&  __traits( compiles, { *here = writeThis; } ) )
in ( atomicPtrIsProperlyAligned( here ), "Argument `here` is not properly aligned" )
{
    static if ( __traits(isFloating, T) )
    {
        static assert ( __traits(isFloating, V1) && V1.sizeof == T.sizeof, "Mismatching argument types." );
        static assert ( __traits(isFloating, V2) && V2.sizeof == T.sizeof, "Mismatching argument types." );
        alias IntTy = IntForFloat!T;
        return atomicCompareExchangeStrongNoResult( cast(IntTy*)here, *cast(IntTy*)&ifThis, *cast(IntTy*)&writeThis );
    }
    else
        return atomicCompareExchangeStrongNoResult!( MemoryOrder.seq, MemoryOrder.seq, T )( cast(T*)here, cast()ifThis, cast()writeThis );
}

/// Ditto
bool cas(T,V1,V2)( shared(T)* here, const shared(V1) ifThis, shared(V2) writeThis ) pure nothrow @nogc @safe
    if ( is(T == class) && __traits( compiles, { *here = writeThis; } ) )
in ( atomicPtrIsProperlyAligned( here ), "Argument `here` is not properly aligned" )
{
    return atomicCompareExchangeStrongNoResult( here, ifThis, writeThis );
}

/// Ditto
bool cas(T,V1,V2)( shared(T)* here, const shared(V1)* ifThis, shared(V2)* writeThis ) pure nothrow @nogc @safe
    if ( is(T U : U*) && __traits( compiles, { *here = writeThis; } ) )
in ( atomicPtrIsProperlyAligned( here ), "Argument `here` is not properly aligned" )
{
    return atomicCompareExchangeStrongNoResult( here, ifThis, writeThis );
}

/**
 * Stores 'writeThis' to the memory referenced by 'here' if the value
 * referenced by 'here' is equal to the value referenced by 'ifThis'.
 * The prior value referenced by 'here' is written to `ifThis` and
 * returned to the user.  This operation is both lock-free and atomic.
 *
 * Params:
 *  here      = The address of the destination variable.
 *  writeThis = The value to store.
 *  ifThis    = The address of the value to compare, and receives the prior value of `here` as output.
 *
 * Returns:
 *  true if the store occurred, false if not.
 */
bool cas(T,V)( shared(T)* here, shared(T)* ifThis, V writeThis ) pure nothrow @nogc @trusted
    if ( !is(T == class) && !is(T U : U*) &&  __traits( compiles, { *here = writeThis; *ifThis = *here; } ) )
in ( atomicPtrIsProperlyAligned( here ), "Argument `here` is not properly aligned" )
{
    static if ( __traits(isFloating, T) )
    {
        static assert ( __traits(isFloating, V) && V.sizeof == T.sizeof, "Mismatching argument types." );
        alias IntTy = IntForFloat!T;
        return atomicCompareExchangeStrong( cast(IntTy*)here, cast(IntTy*)ifThis, *cast(IntTy*)&writeThis );
    }
    else
        return atomicCompareExchangeStrong!( MemoryOrder.seq, MemoryOrder.seq, T )( cast(T*)here, cast(T*)ifThis, cast()writeThis );
}

/// Ditto
bool cas(T,V)( shared(T)* here, shared(T)* ifThis, shared(V) writeThis ) pure nothrow @nogc @trusted
    if ( is(T == class) && __traits( compiles, { *here = writeThis; *ifThis = *here; } ) )
in ( atomicPtrIsProperlyAligned( here ), "Argument `here` is not properly aligned" )
{
    return atomicCompareExchangeStrong( cast(T*)here, cast(T*)ifThis, cast()writeThis );
}

/// Ditto
bool cas(T,V)( shared(T)* here, shared(T)* ifThis, shared(V)* writeThis ) pure nothrow @nogc @trusted
    if ( is(T U : U*) && __traits( compiles, { *here = writeThis; *ifThis = *here; } ) )
in ( atomicPtrIsProperlyAligned( here ), "Argument `here` is not properly aligned" )
{
    return atomicCompareExchangeStrong!( MemoryOrder.seq, MemoryOrder.seq, T )( cast(T*)here, cast(T*)ifThis, writeThis );
}

/**
 * Inserts a full load/store memory fence (on platforms that need it). This ensures
 * that all loads and stores before a call to this function are executed before any
 * loads and stores after the call.
 */
void atomicFence() nothrow @nogc @safe
{
    core.internal.atomic.atomicFence();
}


/**
 * Performs the binary operation 'op' on val using 'mod' as the modifier.
 *
 * Params:
 *  val = The target variable.
 *  mod = The modifier to apply.
 *
 * Returns:
 *  The result of the operation.
 */
TailShared!T atomicOp(string op, T, V1)( ref shared T val, V1 mod ) pure nothrow @nogc @safe
    if ( __traits( compiles, mixin( "*cast(T*)&val" ~ op ~ "mod" ) ) )
in ( atomicValueIsProperlyAligned( val ) )
{
    // binary operators
    //
    // +    -   *   /   %   ^^  &
    // |    ^   <<  >>  >>> ~   in
    // ==   !=  <   <=  >   >=
    static if ( op == "+"  || op == "-"  || op == "*"  || op == "/"   ||
                op == "%"  || op == "^^" || op == "&"  || op == "|"   ||
                op == "^"  || op == "<<" || op == ">>" || op == ">>>" ||
                op == "~"  || // skip "in"
                op == "==" || op == "!=" || op == "<"  || op == "<="  ||
                op == ">"  || op == ">=" )
    {
        TailShared!T get = atomicLoad!(MemoryOrder.raw)( val );
        mixin( "return get " ~ op ~ " mod;" );
    }
    else
    // assignment operators
    //
    // +=   -=  *=  /=  %=  ^^= &=
    // |=   ^=  <<= >>= >>>=    ~=
    static if ( op == "+=" && __traits(isIntegral, T) && __traits(isIntegral, V1) && T.sizeof <= size_t.sizeof && V1.sizeof <= size_t.sizeof)
    {
        return cast(T)( atomicFetchAdd!(MemoryOrder.seq, T)( val, mod ) + mod );
    }
    else static if ( op == "-=" && __traits(isIntegral, T) && __traits(isIntegral, V1) && T.sizeof <= size_t.sizeof && V1.sizeof <= size_t.sizeof)
    {
        return cast(T)( atomicFetchSub!(MemoryOrder.seq, T)( val, mod ) - mod );
    }
    else static if ( op == "+=" || op == "-="  || op == "*="  || op == "/=" ||
                op == "%=" || op == "^^=" || op == "&="  || op == "|=" ||
                op == "^=" || op == "<<=" || op == ">>=" || op == ">>>=" ) // skip "~="
    {
        TailShared!T get, set;

        do
        {
            get = set = atomicLoad!(MemoryOrder.raw)( val );
            mixin( "set " ~ op ~ " mod;" );
        } while ( !casByRef( val, get, set ) );
        return set;
    }
    else
    {
        static assert( false, "Operation not supported." );
    }
}

private
{
    template IntForFloat(F)
    {
        static assert ( __traits(isFloating, F), "Not a floating point type: " ~ F.stringof );
        static if ( F.sizeof == 4 )
            alias IntForFloat = uint;
        else static if ( F.sizeof == 8 )
            alias IntForFloat = ulong;
        else
            static assert ( false, "Invalid floating point type: " ~ F.stringof ~ ", only support `float` and `double`." );
    }

    // TODO: it'd be nice if we had @trusted scopes; we could remove this...
    bool casByRef(T,V1,V2)( ref T value, V1 ifThis, V2 writeThis ) pure nothrow @nogc @trusted
    {
        return cas( &value, ifThis, writeThis );
    }

    /* Construct a type with a shared tail, and if possible with an unshared
    head. */
    template TailShared(U) if (!is(U == shared))
    {
        alias TailShared = .TailShared!(shared U);
    }
    template TailShared(S) if (is(S == shared))
    {
        // Get the unshared variant of S.
        static if (is(S U == shared U)) {}
        else static assert(false, "Should never be triggered. The `static " ~
            "if` declares `U` as the unshared version of the shared type " ~
            "`S`. `S` is explicitly declared as shared, so getting `U` " ~
            "should always work.");

        static if (is(S : U))
            alias TailShared = U;
        else static if (is(S == struct))
        {
            enum implName = () {
                /* Start with "_impl". If S has a field with that name, append
                underscores until the clash is resolved. */
                string name = "_impl";
                string[] fieldNames;
                static foreach (alias field; S.tupleof)
                {
                    fieldNames ~= __traits(identifier, field);
                }
                static bool canFind(string[] haystack, string needle)
                {
                    foreach (candidate; haystack)
                    {
                        if (candidate == needle) return true;
                    }
                    return false;
                }
                while (canFind(fieldNames, name)) name ~= "_";
                return name;
            } ();
            struct TailShared
            {
                static foreach (i, alias field; S.tupleof)
                {
                    /* On @trusted: This is casting the field from shared(Foo)
                    to TailShared!Foo. The cast is safe because the field has
                    been loaded and is not shared anymore. */
                    mixin("
                        @trusted @property
                        ref " ~ __traits(identifier, field) ~ "()
                        {
                            alias R = TailShared!(typeof(field));
                            return * cast(R*) &" ~ implName ~ ".tupleof[i];
                        }
                    ");
                }
                mixin("
                    S " ~ implName ~ ";
                    alias " ~ implName ~ " this;
                ");
            }
        }
        else
            alias TailShared = S;
    }
    @safe unittest
    {
        // No tail (no indirections) -> fully unshared.

        static assert(is(TailShared!int == int));
        static assert(is(TailShared!(shared int) == int));

        static struct NoIndir { int i; }
        static assert(is(TailShared!NoIndir == NoIndir));
        static assert(is(TailShared!(shared NoIndir) == NoIndir));

        // Tail can be independently shared or is already -> tail-shared.

        static assert(is(TailShared!(int*) == shared(int)*));
        static assert(is(TailShared!(shared int*) == shared(int)*));
        static assert(is(TailShared!(shared(int)*) == shared(int)*));

        static assert(is(TailShared!(int[]) == shared(int)[]));
        static assert(is(TailShared!(shared int[]) == shared(int)[]));
        static assert(is(TailShared!(shared(int)[]) == shared(int)[]));

        static struct S1 { shared int* p; }
        static assert(is(TailShared!S1 == S1));
        static assert(is(TailShared!(shared S1) == S1));

        static struct S2 { shared(int)* p; }
        static assert(is(TailShared!S2 == S2));
        static assert(is(TailShared!(shared S2) == S2));

        // Tail follows shared-ness of head -> fully shared.

        static class C { int i; }
        static assert(is(TailShared!C == shared C));
        static assert(is(TailShared!(shared C) == shared C));

        /* However, structs get a wrapper that has getters which cast to
        TailShared. */

        static struct S3 { int* p; int _impl; int _impl_; int _impl__; }
        static assert(!is(TailShared!S3 : S3));
        static assert(is(TailShared!S3 : shared S3));
        static assert(is(TailShared!(shared S3) == TailShared!S3));

        static struct S4 { shared(int)** p; }
        static assert(!is(TailShared!S4 : S4));
        static assert(is(TailShared!S4 : shared S4));
        static assert(is(TailShared!(shared S4) == TailShared!S4));
    }
}


////////////////////////////////////////////////////////////////////////////////
// Unit Tests
////////////////////////////////////////////////////////////////////////////////


version (unittest)
{
    void testXCHG(T)( T val ) pure nothrow @nogc @trusted
    in
    {
        assert(val !is T.init);
    }
    do
    {
        T         base = cast(T)null;
        shared(T) atom = cast(shared(T))null;

        assert( base !is val, T.stringof );
        assert( atom is base, T.stringof );

        assert( atomicExchange( &atom, val ) is base, T.stringof );
        assert( atom is val, T.stringof );
    }

    void testCAS(T)( T val ) pure nothrow @nogc @trusted
    in
    {
        assert(val !is T.init);
    }
    do
    {
        T         base = cast(T)null;
        shared(T) atom = cast(shared(T))null;

        assert( base !is val, T.stringof );
        assert( atom is base, T.stringof );

        assert( cas( &atom, base, val ), T.stringof );
        assert( atom is val, T.stringof );
        assert( !cas( &atom, base, base ), T.stringof );
        assert( atom is val, T.stringof );

        atom = cast(shared(T))null;

        shared(T) arg = base;
        assert( cas( &atom, &arg, val ), T.stringof );
        assert( arg is base, T.stringof );
        assert( atom is val, T.stringof );

        arg = base;
        assert( !cas( &atom, &arg, base ), T.stringof );
        assert( arg is val, T.stringof );
        assert( atom is val, T.stringof );
    }

    void testLoadStore(MemoryOrder ms = MemoryOrder.seq, T)( T val = T.init + 1 ) pure nothrow @nogc @trusted
    {
        T         base = cast(T) 0;
        shared(T) atom = cast(T) 0;

        assert( base !is val );
        assert( atom is base );
        atomicStore!(ms)( atom, val );
        base = atomicLoad!(ms)( atom );

        assert( base is val, T.stringof );
        assert( atom is val );
    }


    void testType(T)( T val = T.init + 1 ) pure nothrow @nogc @safe
    {
        static if ( T.sizeof < 8 || has64BitXCHG )
            testXCHG!(T)( val );
        testCAS!(T)( val );
        testLoadStore!(MemoryOrder.seq, T)( val );
        testLoadStore!(MemoryOrder.raw, T)( val );
    }

    @betterC @safe pure nothrow unittest
    {
        testType!(bool)();

        testType!(byte)();
        testType!(ubyte)();

        testType!(short)();
        testType!(ushort)();

        testType!(int)();
        testType!(uint)();
    }

    @safe pure nothrow unittest
    {

        testType!(shared int*)();

        static class Klass {}
        testXCHG!(shared Klass)( new shared(Klass) );
        testCAS!(shared Klass)( new shared(Klass) );

        testType!(float)(1.0f);

        static if ( has64BitCAS )
        {
            testType!(double)(1.0);
            testType!(long)();
            testType!(ulong)();
        }
        static if (has128BitCAS)
        {
            () @trusted
            {
                align(16) struct Big { long a, b; }

                shared(Big) atom;
                shared(Big) base;
                shared(Big) arg;
                shared(Big) val = Big(1, 2);

                assert( cas( &atom, arg, val ), Big.stringof );
                assert( atom is val, Big.stringof );
                assert( !cas( &atom, arg, val ), Big.stringof );
                assert( atom is val, Big.stringof );

                atom = Big();
                assert( cas( &atom, &arg, val ), Big.stringof );
                assert( arg is base, Big.stringof );
                assert( atom is val, Big.stringof );

                arg = Big();
                assert( !cas( &atom, &arg, base ), Big.stringof );
                assert( arg is val, Big.stringof );
                assert( atom is val, Big.stringof );
            }();
        }

        shared(size_t) i;

        atomicOp!"+="( i, cast(size_t) 1 );
        assert( i == 1 );

        atomicOp!"-="( i, cast(size_t) 1 );
        assert( i == 0 );

        shared float f = 0;
        atomicOp!"+="( f, 1 );
        assert( f == 1 );

        static if ( has64BitCAS )
        {
            shared double d = 0;
            atomicOp!"+="( d, 1 );
            assert( d == 1 );
        }
    }

    @betterC pure nothrow unittest
    {
        static if (has128BitCAS)
        {
            struct DoubleValue
            {
                long value1;
                long value2;
            }

            align(16) shared DoubleValue a;
            atomicStore(a, DoubleValue(1,2));
            assert(a.value1 == 1 && a.value2 ==2);

            while (!cas(&a, DoubleValue(1,2), DoubleValue(3,4))){}
            assert(a.value1 == 3 && a.value2 ==4);

            align(16) DoubleValue b = atomicLoad(a);
            assert(b.value1 == 3 && b.value2 ==4);
        }

        version (D_LP64)
        {
            enum hasDWCAS = has128BitCAS;
        }
        else
        {
            enum hasDWCAS = has64BitCAS;
        }

        static if (hasDWCAS)
        {
            static struct List { size_t gen; List* next; }
            shared(List) head;
            assert(cas(&head, shared(List)(0, null), shared(List)(1, cast(List*)1)));
            assert(head.gen == 1);
            assert(cast(size_t)head.next == 1);
        }
    }

    @betterC pure nothrow unittest
    {
        static struct S { int val; }
        auto s = shared(S)(1);

        shared(S*) ptr;

        // head unshared
        shared(S)* ifThis = null;
        shared(S)* writeThis = &s;
        assert(ptr is null);
        assert(cas(&ptr, ifThis, writeThis));
        assert(ptr is writeThis);

        // head shared
        shared(S*) ifThis2 = writeThis;
        shared(S*) writeThis2 = null;
        assert(cas(&ptr, ifThis2, writeThis2));
        assert(ptr is null);

        // head unshared target doesn't want atomic CAS
        shared(S)* ptr2;
        static assert(!__traits(compiles, cas(&ptr2, ifThis, writeThis)));
        static assert(!__traits(compiles, cas(&ptr2, ifThis2, writeThis2)));
    }

    unittest
    {
        import core.thread;

        // Use heap memory to ensure an optimizing
        // compiler doesn't put things in registers.
        uint* x = new uint();
        bool* f = new bool();
        uint* r = new uint();

        auto thr = new Thread(()
        {
            while (!*f)
            {
            }

            atomicFence();

            *r = *x;
        });

        thr.start();

        *x = 42;

        atomicFence();

        *f = true;

        atomicFence();

        thr.join();

        assert(*r == 42);
    }

    // === atomicFetchAdd and atomicFetchSub operations ====
    @betterC pure nothrow @nogc @safe unittest
    {
        shared ubyte u8 = 1;
        shared ushort u16 = 2;
        shared uint u32 = 3;
        shared byte i8 = 5;
        shared short i16 = 6;
        shared int i32 = 7;

        assert(atomicOp!"+="(u8, 8) == 9);
        assert(atomicOp!"+="(u16, 8) == 10);
        assert(atomicOp!"+="(u32, 8) == 11);
        assert(atomicOp!"+="(i8, 8) == 13);
        assert(atomicOp!"+="(i16, 8) == 14);
        assert(atomicOp!"+="(i32, 8) == 15);
        version (AsmX86_64)
        {
            shared ulong u64 = 4;
            shared long i64 = 8;
            assert(atomicOp!"+="(u64, 8) == 12);
            assert(atomicOp!"+="(i64, 8) == 16);
        }
    }

    @betterC pure nothrow @nogc @safe unittest
    {
        shared ubyte u8 = 1;
        shared ushort u16 = 2;
        shared uint u32 = 3;
        shared byte i8 = 5;
        shared short i16 = 6;
        shared int i32 = 7;

        assert(atomicOp!"-="(u8, 1) == 0);
        assert(atomicOp!"-="(u16, 1) == 1);
        assert(atomicOp!"-="(u32, 1) == 2);
        assert(atomicOp!"-="(i8, 1) == 4);
        assert(atomicOp!"-="(i16, 1) == 5);
        assert(atomicOp!"-="(i32, 1) == 6);
        version (AsmX86_64)
        {
            shared ulong u64 = 4;
            shared long i64 = 8;
            assert(atomicOp!"-="(u64, 1) == 3);
            assert(atomicOp!"-="(i64, 1) == 7);
        }
    }

    @betterC pure nothrow @nogc @safe unittest // issue 16651
    {
        shared ulong a = 2;
        uint b = 1;
        atomicOp!"-="( a, b );
        assert(a == 1);

        shared uint c = 2;
        ubyte d = 1;
        atomicOp!"-="( c, d );
        assert(c == 1);
    }

    pure nothrow @safe unittest // issue 16230
    {
        shared int i;
        static assert(is(typeof(atomicLoad(i)) == int));

        shared int* p;
        static assert(is(typeof(atomicLoad(p)) == shared(int)*));

        shared int[] a;
        static if (__traits(compiles, atomicLoad(a)))
        {
            static assert(is(typeof(atomicLoad(a)) == shared(int)[]));
        }

        static struct S { int* _impl; }
        shared S s;
        static assert(is(typeof(atomicLoad(s)) : shared S));
        static assert(is(typeof(atomicLoad(s)._impl) == shared(int)*));
        auto u = atomicLoad(s);
        assert(u._impl is null);
        u._impl = new shared int(42);
        assert(atomicLoad(*u._impl) == 42);

        static struct S2 { S s; }
        shared S2 s2;
        static assert(is(typeof(atomicLoad(s2).s) == TailShared!S));

        static struct S3 { size_t head; int* tail; }
        shared S3 s3;
        static if (__traits(compiles, atomicLoad(s3)))
        {
            static assert(is(typeof(atomicLoad(s3).head) == size_t));
            static assert(is(typeof(atomicLoad(s3).tail) == shared(int)*));
        }

        static class C { int i; }
        shared C c;
        static assert(is(typeof(atomicLoad(c)) == shared C));

        static struct NoIndirections { int i; }
        shared NoIndirections n;
        static assert(is(typeof(atomicLoad(n)) == NoIndirections));
    }
}
