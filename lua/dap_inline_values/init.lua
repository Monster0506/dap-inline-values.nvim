local M = {}

local debug_ns = vim.api.nvim_create_namespace("debugger_values")
local evaluated_marks = {}

-- Configuration
local config = {
	filetypes = {},
	keymaps = {
		evaluate = "M",
	},
	value_prefix = " -> ",
}

-- Get tree-sitter node at cursor position
local function get_node_at_cursor(buf, line, col, filetype)
	local parser = vim.treesitter.get_parser(buf, filetype)
	if not parser then
		return nil
	end

	local tree = parser:parse()
	local root = tree[1]:root()
	local node = root:named_descendant_for_range(line, col, line, col)
	return node
end

-- Extract expression from node
local function get_expression_from_node(node, buf)
	if not node then
		return nil
	end

	local node_type = node:type()

	if node_type == "identifier" or node_type == "attribute" or node_type == "subscript" or node_type == "call" then
		return vim.treesitter.get_node_text(node, buf)
	else
		local current = node
		while current do
			local ctype = current:type()
			if ctype == "identifier" or ctype == "attribute" or ctype == "subscript" or ctype == "call" then
				return vim.treesitter.get_node_text(current, buf)
			end
			current = current:parent()
		end
	end

	return nil
end

-- Find mark at cursor
local function find_mark_at_cursor(buf, line, col)
	if not evaluated_marks[buf] then
		return nil
	end

	for mark_id, range in pairs(evaluated_marks[buf]) do
		local start_row, start_col, end_row, end_col = range.start_row, range.start_col, range.end_row, range.end_col
		if line == start_row and col >= start_col and col <= end_col then
			return mark_id
		end
	end

	return nil
end

-- Evaluate and show inline in source buffer
local function evaluate_expression()
	local dap = require("dap")
	if not dap.session() then
		print("No active DAP session")
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local filetype = vim.api.nvim_buf_get_option(buf, "filetype")

	local cursor = vim.api.nvim_win_get_cursor(0)
	local line_num = cursor[1] - 1
	local col = cursor[2]

	-- Toggle off if already marked
	local existing_mark = find_mark_at_cursor(buf, line_num, col)
	if existing_mark then
		vim.api.nvim_buf_del_extmark(buf, debug_ns, existing_mark)
		evaluated_marks[buf][existing_mark] = nil
		return
	end

	-- Get node and expression
	local node = get_node_at_cursor(buf, line_num, col, filetype)
	if not node then
		print("Could not find expression at cursor")
		return
	end

	local expression = get_expression_from_node(node, buf)
	if not expression then
		return
	end

	-- Evaluate
	dap.session():request("threads", {}, function(err, threads_resp)
		if err or not threads_resp or not threads_resp.threads[1] then
			return
		end

		local thread_id = threads_resp.threads[1].id

		dap.session():request("stackTrace", { threadId = thread_id, levels = 1 }, function(err2, stack_resp)
			if err2 or not stack_resp or not stack_resp.stackFrames[1] then
				return
			end

			local frame = stack_resp.stackFrames[1]

			dap.session():request(
				"evaluate",
				{ expression = expression, frameId = frame.id, context = "variables" },
				function(err3, eval_resp)
					if err3 or not eval_resp then
						print("Failed to evaluate: " .. tostring(err3))
						return
					end

					local value = eval_resp.result

					-- Check for errors
					if value:match("name '.*' is not defined") then
						print("Variable not yet defined: " .. expression)
						return
					end

					-- Truncate long values
					if #value > 100 then
						value = value:sub(1, 97) .. "..."
					end

					local start_row, start_col, end_row, end_col = node:range()

					-- Create extmark with inline text
					local mark_id = vim.api.nvim_buf_set_extmark(buf, debug_ns, end_row, end_col, {
						virt_text = { { config.value_prefix .. value, "@constant.builtin" } },
						virt_text_pos = "inline",
					})

					if not evaluated_marks[buf] then
						evaluated_marks[buf] = {}
					end
					evaluated_marks[buf][mark_id] = {
						start_row = start_row,
						start_col = start_col,
						end_row = end_row,
						end_col = end_col,
					}
				end
			)
		end)
	end)
end

function M.setup(user_config)
	if user_config then
		if user_config.filetypes then
			config.filetypes = user_config.filetypes
		end
		if user_config.keymaps then
			config.keymaps = vim.tbl_extend("force", config.keymaps, user_config.keymaps)
		end
		if user_config.value_prefix then
			config.value_prefix = user_config.value_prefix
		end
	end

	vim.api.nvim_create_autocmd("FileType", {
		pattern = config.filetypes,
		callback = function(args)
			local buf = args.buf
			vim.keymap.set("n", config.keymaps.evaluate, evaluate_expression, {
				buffer = buf,
				noremap = true,
				silent = true,
				desc = "Debug: Evaluate expression",
			})
		end,
	})
end

return M
