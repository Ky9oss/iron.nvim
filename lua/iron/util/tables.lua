-- luacheck: globals vim
local fns = {}

fns.extend = function(...)
  local tbl = {}
  local tbls = {n = select("#", ...), ...}
  for ix=1, tbls.n do
    local itm = tbls[ix]
    if itm ~= nil then
      if type(itm) == "table" then
        vim.list_extend(tbl, itm)
      else
        table.insert(tbl, itm)
      end
    end
  end

  return tbl
end

---@param table table table of strings
---@param substring string
--- Checks in any sting in the table contains the substring
fns.contains = function(table, substring)
  if type(table) == "string" then
    vim.notify("Got table:" .. table, vim.log.levels.WARN, { title = "pin" })
  else
    for _, v in ipairs(table) do
      if string.find(v, substring) then
        return true
      end
    end
  end
  return false
end



return fns
