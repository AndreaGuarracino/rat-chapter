-- Pandoc Lua filter for the rat-chapter Word build.
--
-- Two jobs:
--
--   1. Mark Title, Summary, and backmatter headings as "unnumbered" so
--      that `pandoc --number-sections` skips them. Typst's
--      `numbering: none` attribute is not preserved when pandoc reads
--      Typst input, so we have to mark these headings here.
--
--   2. Left-align specific frontmatter paragraphs (author list,
--      affiliations block, Key Words line). The reference.docx
--      justifies BodyText/FirstParagraph/Normal so that running prose is
--      flush both margins, but those frontmatter paragraphs look ugly
--      when justified because they are short, multi-line, or label-like.

local UNNUMBERED_HEADINGS = {
  ["Pangenome Graph Construction, Variant Calling, and Phenome-Wide Association in the HXB/BXH Rat Panel"] = true,
  ["Summary"] = true,
  ["Competing Interests"] = true,
  ["Acknowledgments"] = true,
  ["Figure Captions"] = true,
}

-- Patterns that identify paragraphs we want left-aligned in the Word
-- output. Matched against the plain text of the paragraph. Author
-- names and Key Words are intentionally NOT in this list: they stay in
-- the justified BodyText/FirstParagraph style. Only the multi-line
-- affiliations block is left-aligned (justification stretches the short
-- address lines unevenly).
local LEFT_PATTERNS = {
  "^%d+ Bioinnovation and Genome Sciences",    -- affiliations block
}


local function matches_left_pattern(text)
  for _, pat in ipairs(LEFT_PATTERNS) do
    if text:find(pat) then
      return true
    end
  end
  return false
end


function Header(el)
  local title = pandoc.utils.stringify(el.content)
  if UNNUMBERED_HEADINGS[title] then
    el.classes:insert("unnumbered")
  end
  return el
end


function Para(el)
  local text = pandoc.utils.stringify(el.content)
  if matches_left_pattern(text) then
    -- Wrap in a Div with a class that the docx writer maps to the
    -- "Author" custom paragraph style (defined in reference.docx as
    -- left-aligned). Using a Div is the standard pandoc way to push
    -- a custom style without inventing new AST.
    return pandoc.Div({el}, pandoc.Attr("", {}, {["custom-style"] = "Author"}))
  end
  return el
end
