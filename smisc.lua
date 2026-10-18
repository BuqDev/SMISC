local sub, insert = string.sub, table.insert
function error(message)
    print("-- SMISC Error -----------------------------------")
    print("\t> " .. message)
    print("--------------------------------------------------")
    os.exit()
end
-- getting the file & it's text
local path, _ = arg[1], #arg ~= 0 or error("no file path given") 
local fileio, _ = io.open(path, "rb") or error("could not find file: '" .. path .. "'"), sub(path, #path - 2, #path) == ".sm" or error("file at \"" .. path .. "\" is not valid file type of \"*.sm\"")
local code_text = fileio:read("*all")
fileio:close()
-- might make my own thing for parsing spaces to be context aware and also split up longer strings 
local function parse(code_text)
    local t = {}
    for s0 in string.gmatch(code_text, "([^\n]+)") do
        local tokens = {}
        for s1 in string.gmatch(s0, "([^ \t]+)") do
            if tonumber(s1) then
                insert(tokens, math.floor(tonumber(s1)))
            else
                local _ = string.gsub(s1, string.char(13), "") insert(tokens, _)
            end
        end
        insert(t, tokens)
    end
    return t
end
local maxint = 4294967296
local function runsmisc(code)
    local keep_running, i = false, 1
    local instructions = {
        ["+"] = function(p) return           (p[1] + p[2]) % maxint end,
        ["-"] = function(p) return           (p[1] - p[2]) % maxint end,
        ["*"] = function(p) return           (p[1] * p[2]) % maxint end,
        ["/"] = function(p) return math.floor(p[1] / p[2]) % maxint end,
        [">"] = function(p)
            if p[1] > p[2] then return 1
            else return 0 end
        end,
        ["input"]  = function(p)
            io.write("\n> ")
            local c = io.read("*l")
            code[p[1]] = {"\"" .. sub(c, 1, 1) .. "\""}
            return 0
        end,
        ["output"] = function(p)
            for i=1, p[1] do
                local n = p[2] + i - 1
                local line = code[n]
                if n > #code or 1 > n then
                    error"Cannot copy outside of code body"
                end
                -- print(line[1])
                local v = doexpr(line, 1)
                
                io.write(string.char(v))
            end
            return 0
        end,
        ["swap"] = function(p)
            for i=1, p[1] do
                local a, b = p[3] + i - 1, p[2] + i - 1
                if a > #code or b > #code or 0 > a or 0 > b then
                    error"Cannot copy outside of code body"
                end
                local temp = code[a]
                code[a] = code[b] 
                code[b] = temp
            end
            return 0
        end,
        ["copy"]   = function(p)
            for i=1, p[1] do
                local a, b = p[3] + i - 1, p[2] + i - 1
                if a > #code or b > #code or 0 > a or 0 > b then
                    error"Cannot copy outside of code body"
                end
                code[a] = code[b] 
            end
            return 0
        end,
        -- basically no-ops
        ["."] = function() end,
        ["--"] = function() end,
    }
    function doexpr(line, i, prev)
        local value, done = 0, false
        if line[i] == nil then
            error(type(line) .. " " .. tostring(prev[1]))
        end

        while line[i] == ")" do
            i = i + 1
        end
        if tonumber(line[i]) then
            return line[i], i + 1
        elseif sub(line[i], 1, 1) == "\"" then
            if line[i] == "\"\"" then
                return string.byte(" "), i + 1
            end
            return string.byte(sub(line[i], 2, 2)), i + 1
        elseif line[i] == "." then
            local tag_line = -1
            for j, l in ipairs(code) do
                if l[1] == "." and l[2] == line[i + 1] then
                    tag_line = j
                    break
                end
            end
            if tag_line == -1 then error("Unable to find line marked as \". " .. line[i + 1] .. "\".") end
            return tag_line + 1, i + 2
        elseif line[i] == "(" then
            local a, b, head
            head = line[i + 1]
            if not instructions[head] then
                error("Invalid instruction \"" .. head .. "\"")
            end
            a, i = doexpr(line, i + 2, line)
            b, i = doexpr(line, i, line)
            value = instructions[head]({a, b})

        elseif not instructions[line[i]] then
            local tag_line = -1
            for j, l in ipairs(code) do
                if l[1] == "." and l[2] == line[i] then
                    tag_line = j
                    break
                end
            end
            if tag_line == -1 then error("Unable to find line marked as \". " .. tostring(line[i]) .. "\".") end
            local v = doexpr(code[tag_line + 1], 1, line)
            
            return v, i + 1
        end
        return value, i + 1
    end
    while i <= #code do
        local line, j = code[i], 2
        local head = line[1]
        if not tonumber(head) and head ~= nil and head ~= "" and head ~= "--" and head ~= "." and sub(head, 1, 1) ~= "\"" then
            local value, params = 0, {}
            if head ~= "." and head ~= "--" then
                keep_running = true
                while j <= #line do
                    local v = 0
                    v, j = doexpr(line, j, i)
                    if v ~= nil then
                        insert(params, v)
                    end
                end
            end
            if not instructions[head] then
                error("Invalid instruction \"" .. head .. "\" on line " .. tostring(i))
            end
            value = instructions[head](params)
            if head == "+" or head == "-" or head == "*" or head == "/" or head == ">" then
                code[i] = {value} 
            end
        end
        i = i + 1
    end
    return keep_running
end
code, run = parse(code_text), true
while run do
    run = runsmisc(code)
end
print("\n-- program halted")