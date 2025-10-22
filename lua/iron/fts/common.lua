local is_windows = require("iron.util.os").is_windows
local extend = require("iron.util.tables").extend
local open_code = "\27[200~"
local close_code = "\27[201~"
local cr = "\13"

local common = {}


---@param table table table of strings
---@param substring string
--- Checks in any sting in the table contains the substring
local contains = function(table, substring)
  -- vim.notify("Got table: " .. type(table), vim.log.levels.WARN, { title = "pin" })
  if type(table) == "string" then
    -- vim.notify("Got string: " .. table, vim.log.levels.WARN, { title = "pin" })
  end
  for _, v in ipairs(table) do
    if string.find(v, substring) then
      return true
    end
  end
  return false
end


---@param lines table
-- Removes empty lines. On unix this includes lines only with whitespaces.
local function remove_empty_lines(lines)
  local newlines = {}

  for _, line in pairs(lines) do
    if string.len(line:gsub("[ \t]", "")) > 0 then
      table.insert(newlines, line)
    end
  end

  return newlines
end


---@param s string
--- A helper function using in bracked_paste_python.
-- Checks in a string starts with any of the exceptions.
local function python_close_indent_exceptions(s)
  local exceptions = { "elif", "else", "except", "finally", "#" }
  for _, exception in ipairs(exceptions) do
    local pattern0 = "^" .. exception .. "[%s:]"
    local pattern1 = "^" .. exception .. "$"
    if string.match(s, pattern0) or string.match(s, pattern1) then
      return true
    end
  end
  return false
end


common.format = function(repldef, lines)
  assert(type(lines) == "table", "Supplied lines is not a table")

  local new

  -- passing the command is for python. this will not affect bracketed_paste.
  if repldef.format then
    vim.notify("[1]", vim.log.levels.INFO, { title = "pin" })
    return repldef.format(lines, { command = repldef.command })
  elseif #lines == 1 then
    vim.notify("[2]", vim.log.levels.INFO, { title = "pin" })
    new = lines
  else
    vim.notify("[3]", vim.log.levels.INFO, { title = "pin" })
    new = extend(repldef.open, lines, repldef.close)
  end

  if #new > 0 then
    if not is_windows() then
      vim.notify("Not in Windows!!!", vim.log.levels.ERROR, { title = "pin" })
      new[#new] = new[#new] .. cr
    end
  end

  return new
end


common.bracketed_paste = function(lines)
  if #lines == 1 then
    return { lines[1] .. cr }
  else
    local new = { open_code .. lines[1] }
    for line = 2, #lines do
      table.insert(new, lines[line])
    end

    table.insert(new, close_code .. cr)

    return new
  end
end


--- @param lines table  "each item of the table is a new line to send to the repl"
--- @return table  "returns the table of lines to be sent the the repl with
-- the return carriage added"
common.bracketed_paste_python = function(lines, extras)
  local result = {}

  local cmd = extras["command"]
  local pseudo_meta = { current_buffer = vim.api.nvim_get_current_buf()}
  if type(cmd) == "function" then
    cmd = cmd(pseudo_meta)
  end

  local windows = is_windows()
  local python = false
  local ipython = false
  local ptpython = false

  if contains(cmd, "ipython") then
    ipython = true
  elseif contains(cmd, "ptpython") then
    ptpython = true
  else
    python = true
  end

  lines = remove_empty_lines(lines)

  local indent_open = false
  for i, line in ipairs(lines) do
    if string.match(line, "^%s") ~= nil then
      indent_open = true
    end

  local format = function (str)
    if type(str) ~= "string" then return nil end
    local result = "Binary string length; " .. tostring(#str) .. " bytes\n"
    local i = 1
    local hex = ""
    local chr = ""
    while i <= #str do
      local byte = str:byte(i)
      hex = string.format("%s%2x ", hex, byte)
      if byte < 32 then byte = string.byte(".") end
      chr = chr .. string.char(byte)
      if math.floor(i/16) == i/16 or i == #str then
        -- reached end of line
        hex = hex .. string.rep(" ", 16 * 3 - #hex)
        chr = chr .. string.rep(" ", 16 - #chr)

        result = result .. hex:sub(1, 8 * 3) .. "  " .. hex:sub(8*3+1, -1) .. " " .. chr:sub(1,8) .. " " .. chr:sub(9,-1) .. "\n"

        hex = ""
        chr = ""
      end
      i = i + 1
    end
    return result
  end

    -- vim.notify("Insert String: " .. line, vim.log.levels.WARN, { title = "pin" })
    -- vim.notify("String Binaries: " .. format(line), vim.log.levels.WARN, { title = "pin" })
    table.insert(result, line)

    if windows and python or not windows then
      if i < #lines and indent_open and string.match(lines[i + 1], "^%s") == nil then
        if not python_close_indent_exceptions(lines[i + 1]) then
          indent_open = false
          vim.notify("[1] Insert cr ", vim.log.levels.WARN, { title = "pin" })
          table.insert(result, cr)
        end
      end
    end
  end

  local newline = windows and "\r\n" or cr
  if #result == 0 then  -- handle sending blank lines
    vim.notify("[2] Insert cr ", vim.log.levels.WARN, { title = "pin" })
    table.insert(result, cr)
  elseif #result > 0 and result[#result]:sub(1, 1) == " " then
    -- Since the last line of code is indented, the Python REPL
    -- requires and extra newline in order to execute the code
    table.insert(result, newline)
  else
    vim.notify("[3] Insert blank ", vim.log.levels.WARN, { title = "pin" })
    table.insert(result, "")
  end

  if ptpython then
    table.insert(result, 1, open_code)
    table.insert(result, close_code)
    table.insert(result, "\n")
  end

  return result
end


return common
