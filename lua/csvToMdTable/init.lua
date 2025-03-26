local M = {}

M.convertLines = function(lines)
	local resultingLines = {}

	for i, line in ipairs(lines) do
		local row = {}

		for word in line:gmatch("[^,]+") do
			table.insert(row, word)
		end
		local inserted = ("| " .. table.concat(row, " | ") .. " |")
		if i == 1 then
			local ins = inserted
			local replaces = ins:gsub("%w", "-")
			table.insert(resultingLines, 1, inserted)
			table.insert(resultingLines, 2, replaces)
		else
			table.insert(resultingLines, i + 1, inserted)
		end
	end

	vim.inspect(resultingLines)

	return resultingLines
end

local sampleLines = {
	"a,b,c",
	"1,2,3",
	"4,5,6",
}

-- vim.notify(vim.inspect(M.convertLines(sampleLines)))

function M.GetVisualSelection(keepSelectionIfNotInBlockMode, advanceCursorOneLine, debugNotify)
	local line_start, column_start
	local line_end, column_end
	-- if debugNotify is true, use M.notify to show debug info.
	debugNotify = debugNotify or false
	-- keep selection defaults to false, but if true the selection will
	-- be reinstated after it's cleared to set '> and '<
	-- only relevant in visual or visual line mode, block always keeps selection.
	keepSelectionIfNotInBlockMode = keepSelectionIfNotInBlockMode or false
	-- advance cursor one line defaults to true, but is turned off for
	-- visual block mode regardless.
	advanceCursorOneLine = (function()
		if keepSelectionIfNotInBlockMode == true then
			return false
		else
			return advanceCursorOneLine or true
		end
	end)()

	if vim.fn.visualmode() == "\22" then
		line_start, column_start = unpack(vim.fn.getpos("v"), 2)
		line_end, column_end = unpack(vim.fn.getpos("."), 2)
	else
		-- if not in visual block mode then i want to escape to normal mode.
		-- if this isn't done here, then the '< and '> do not get set,
		-- and the selection will only be whatever was LAST selected.
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", true)
		line_start, column_start = unpack(vim.fn.getpos("'<"), 2)
		line_end, column_end = unpack(vim.fn.getpos("'>"), 2)
	end
	if column_start > column_end then
		column_start, column_end = column_end, column_start
		if debugNotify == true then
			M.notify(
				"switching column start and end, \nWas "
					.. column_end
					.. ","
					.. column_start
					.. "\nNow "
					.. column_start
					.. ","
					.. column_end
			)
		end
	end
	if line_start > line_end then
		line_start, line_end = line_end, line_start
		if debugNotify == true then
			M.notify(
				"switching line start and end, \nWas "
					.. line_end
					.. ","
					.. line_start
					.. "\nNow "
					.. line_start
					.. ","
					.. line_end
			)
		end
	end
	if vim.g.selection == "exclusive" then
		column_end = column_end - 1 -- Needed to remove the last character to make it match the visual selection
	end
	if debugNotify == true then
		M.notify(
			"vim.fn.visualmode(): "
				.. vim.fn.visualmode()
				.. "\nsel start "
				.. vim.inspect(line_start)
				.. " "
				.. vim.inspect(column_start)
				.. "\nSel end "
				.. vim.inspect(line_end)
				.. " "
				.. vim.inspect(column_end)
		)
	end
	local n_lines = math.abs(line_end - line_start) + 1
	local lines = vim.api.nvim_buf_get_lines(0, line_start - 1, line_end, false)
	if #lines == 0 then
		return { "" }
	end
	if vim.fn.visualmode() == "\22" then
		-- this is what actually sets the lines to only what is found between start and end columns
		for i = 1, #lines do
			lines[i] = string.sub(lines[i], column_start, column_end)
		end
	else
		lines[1] = string.sub(lines[1], column_start, -1)
		if n_lines == 1 then
			lines[n_lines] = string.sub(lines[n_lines], 1, column_end - column_start + 1)
		else
			lines[n_lines] = string.sub(lines[n_lines], 1, column_end)
		end
		-- if advanceCursorOneLine == true, then i do want the cursor to advance once.
		if advanceCursorOneLine == true then
			if debugNotify == true then
				M.notify(
					"advancing cursor one line past the end of the selection to line " .. vim.inspect(line_end + 1)
				)
			end

			local lastline = vim.fn.line("w$")
			if line_end > lastline then
				vim.api.nvim_win_set_cursor(0, { line_end + 1, 0 })
			end
		end

		if keepSelectionIfNotInBlockMode then
			vim.api.nvim_feedkeys("gv", "n", true)
		end
	end
	if debugNotify == true then
		M.notify(vim.fn.join(lines, "\n") .. "\n")
		-- M.notify(table.concat(lines, "\n"))
	end
	return lines -- use this return if you want an array of text lines
	-- return table.concat(lines, "\n") -- use this return instead if you need a text block
end

M.convert = function()
	local mdTabled = (M.convertLines(M.GetVisualSelection(true, false, false)))

	vim.inspect(mdTabled)
	local start, rEnd = vim.fn.getpos("'<")[2] - 1, vim.fn.getpos("'>")[2]
	vim.inspect("start: " .. start)
	vim.inspect("end: " .. rEnd)
	vim.api.nvim_buf_set_lines(0, start, rEnd, false, mdTabled)
	return mdTabled
end

---@type Config
M.config = config

M.setup = function(args)
	M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

return M
