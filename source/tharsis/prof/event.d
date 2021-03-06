//          Copyright Ferdinand Majerech 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)


/// Profiling event and its members.
module tharsis.prof.event;


/** Types of events recorded by Profiler.
 */
// All EventID values must be 5-bit integers, see below.
enum EventID: ubyte
{
    // A 'checkpoint' event followed by an absolute time value (8 7-bit bytes).
    Checkpoint = 0,
    // Zone start.
    ZoneStart  = 1,
    // Zone end.
    ZoneEnd    = 2,
    // Info string. EventID/time bytes are followed by a string length byte and a string
    // of up to 255 chars.
    Info       = 3,

    // A variable value. VariableType followed by a 7-bit encoded big-endian variable value.
    Variable   = 4
}

/// Variable types that can be recorded.
enum VariableType: ubyte
{
    /// int. Encoded as a 5-byte long 7-bit encoded block.
    Int = 1,
    /// uint. Encoded as a 5-byte long 7-bit encoded block.
    Uint = 2,
    /// float. Encoded as a 5-byte long 7-bit encoded block.
    Float = 3
}

// Lengths of various variable types when encoded in 7-bit.
package enum variable7BitLengths = [size_t.max, 5, 5, 5];

/// Get a VariableType value corresponding to a variable type.
VariableType variableType(V)()
{
    static if(is(V == int))       { return VariableType.Int;   }
    else static if(is(V == uint)) { return VariableType.Uint;  }
    else static if(is(V == float)){ return VariableType.Float; }
    else static assert(false, "Unsupported type for Despiker variable event: " ~ V.stringof);
}

// A global array with all event IDs
import std.traits;
package immutable allEventIDs = [EnumMembers!EventID];
package immutable allVariableTypes = [EnumMembers!VariableType];

/// A variable parsed from profile data.
struct Variable
{
package:
    // Variable type.
    VariableType type_;
    union
    {
        // Integer value if type_ is VariableType.Int.
        int int_;
        // Unsigned integer value if type_ is VariableType.Uint.
        uint uint_;
        // Float value if type_ is VariableType.Float.
        float float_;
    }

public:
    /// Get the variable type.
    VariableType type() @safe pure nothrow const @nogc
    {
        return type_;
    }

    /// toString() with no allocations (except stack).
    void toString(scope void delegate(const(char)[]) sink) const
    {
        char[128] buffer;
        import core.stdc.stdio; // formattedWrite might be better, maybe rewrite
        int length;
        final switch(type_) with(VariableType)
        {
            case Int:   length = snprintf(buffer.ptr, buffer.length, "%d", varInt);   break;
            case Uint:  length = snprintf(buffer.ptr, buffer.length, "%u", varUint);  break;
            case Float: length = snprintf(buffer.ptr, buffer.length, "%f", varFloat); break;
        }
        assert(length > 0 && length < buffer.length, "Error formatting a value to string");
        sink(buffer[0 .. length]);
    }

    /** Get the integer value of the variable
     *
     * Can only be called if type is VariableType.Int.
     */
    int varInt() @safe pure nothrow const @nogc
    {
        assert(type_ == VariableType.Int, "Trying to read a non-int variable as an int");
        return int_;
    }

    /** Get the unsigned integer value of the variable
     *
     * Can only be called if type is VariableType.Uint.
     */
    uint varUint() @safe pure nothrow const @nogc
    {
        assert(type_ == VariableType.Uint, "Trying to read a non-uint variable as a uint");
        return uint_;
    }

    /** Get the float value of the variable
     *
     * Can only be called if type is VariableType.Float.
     */
    float varFloat() @safe pure nothrow const @nogc
    {
        assert(type_ == VariableType.Float, "Trying to read a non-float variable as a float");
        return float_;
    }
}

/// Profiling event generated by EventRange.
struct Event
{
    /// Event ID or type.
    EventID id;
    /// Time of the event since recording started in hectonanoseconds.
    ulong time;

    package union
    {
        const(char)[] info_;
        Variable var_;
    }

    /// Get the info string if this is an Info event.
    const(char)[] info() @trusted pure nothrow const @nogc
    {
        assert(id == EventID.Info, "Can't access info if it's not an Info event");
        return info_;
    }

    Variable var() @trusted pure nothrow const @nogc
    {
        assert(id == EventID.Variable, "Can't access variable if it's not a Variable event");
        return var_;
    }

    bool opEquals(ref const(Event) rhs) @safe pure nothrow const @nogc 
    {
        if(id != rhs.id || time != rhs.time) { return false; }
        final switch(id)
        {
            case EventID.Checkpoint, EventID.ZoneStart, EventID.ZoneEnd:
                return true;
            case EventID.Info:
                return info == rhs.info;
            case EventID.Variable:
                if(var.type != rhs.var.type) { return false; }
                final switch(var.type)
                {
                    case VariableType.Int:   return var.varInt   == rhs.var.varInt;
                    case VariableType.Uint:  return var.varUint  == rhs.var.varUint;
                    case VariableType.Float: return var.varFloat == rhs.var.varFloat;
                }
        }
    }
}
