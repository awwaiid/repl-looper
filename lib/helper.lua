---------------------------------------------------------------------
-- Helper functions -------------------------------------------------
---------------------------------------------------------------------

local helper = {}

function helper.tabkeys(tab)
  local keyset={}
  local n=0

  for k,v in pairs(tab) do
    n=n+1
    keyset[n]=k
  end
  return keyset
end

function helper.ls(o)
  return helper.tabkeys(getmetatable(o))
end

-- Helper string distance function
function helper.leven(s,t)
  if s == '' then return t:len() end
  if t == '' then return s:len() end

  local s1 = s:sub(2, -1)
  local t1 = t:sub(2, -1)

  if s:sub(0, 1) == t:sub(0, 1) then
    return helper.leven(s1, t1)
  end

  return 1 + math.min(
    helper.leven(s1, t1),
    helper.leven(s,  t1),
    helper.leven(s1, t )
  )
end

-- TODO: Consider memoizing
function helper.eval(code_string)
  -- This little trick tries to eval first in expression context with a
  -- `return`, and if that doesn't parse (shouldn't even get executed) then try
  -- again in regular command context. Got this method from
  -- https://github.com/hoelzro/lua-repl/blob/master/repl/plugins/autoreturn.lua
  --
  -- Either way we get a function back that we then invoke
  local eval_command, eval_errors = load("return " .. code_string, "EVAL")
  if not eval_command then
    eval_command, eval_errors = load(code_string, "EVAL")
  end

  if eval_errors then
    return nil, eval_errors
  end

  return eval_command()
end

function helper.all_words_have(words, letter, offset)
  for _, word in ipairs(words) do
    if string.sub(word, offset, offset) ~= letter then
      print("mm", word, offset)
      return false
    end
  end
  return true
end

function helper.longestPrefix(words)
  -- check border cases size 1 array and empty first word
  if (not words[1]) or (#words ==  1) then
    return words[1] or ""
  end

  local i = 1
  -- while all words have the same character at position i, increment i
  while (#words[1] >= i) and helper.all_words_have(words, string.sub(words[1], i, i), i) do
    i = i + 1
  end
  i = i - 1

  -- prefix is the substring from the beginning to the last successfully checked i
  return string.sub(words[1], 1, i)
end


return helper

