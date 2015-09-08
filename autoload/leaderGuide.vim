function! leaderGuide#PopulateDictionary(key, dictname)
	let readinput = ""
	redir => readinput
	silent execute "verbose map ".a:key
	redir END
	let lines = split(readinput, "\n")
	for line in lines
		if !match(line, ".*Last set.*") == 0
			call s:handle_line(line, a:key, a:dictname)
			echo line
		else
			"echo line
		endif
	endfor
	let input = input("")
endfunction

function! s:handle_line(line, key, dictname)
	"echo a:line
	"let mlist = matchlist(a:line, '\([xnv ]\) *\(<Space>\)\([^ ]*\)[ |:|\*]*\(.*\)$')
	let mlist = matchlist(a:line, '\([xnv ]\) *\('.a:key.'\)\([^ ]*\)[ |:|\*]*\(.*\)$')
	echo mlist
	let mlist[4] = substitute(mlist[4], "<CR>$", "", "")
	let mode = mlist[1]
	let prefix = mlist[2]
	let map = mlist[3]
	let cmd = mlist[4]
	"echo "mode:".mode
	"echo "prefix:".prefix
	"echo "map:".map
	"echo "cmd:".cmd
	if map != ''
		let map = substitute(map, "<Space>", " ", "")
		call s:add_mapping(map, cmd, 0, a:dictname)
		"call s:addmapp(map, cmd, 0, 'g:lmap')
	endif
endfunction

function! s:add_mapping(key, cmd, level, dictname)
	""" WORKS 
	if len(a:key) > a:level+1
		" Go to next level
		if a:level == 0
			if !has_key({a:dictname}, a:key[a:level])
				let {a:dictname}[a:key[a:level]] = { 'name' : 'NONAME' }
			endif
		elseif a:level == 1
			if !has_key({a:dictname}[a:key[a:level-1]], a:key[a:level])
				echo a:dictname
				let {a:dictname}[a:key[a:level-1]][a:key[a:level]] = { 'name' : 'NONAME' }
			endif
		elseif a:level == 2
			if !has_key({a:dictname}[a:key[a:level-2]][a:key[a:level-1]], a:key[a:level])
				let {a:dictname}[a:key[a:level-2]][a:key[a:level-1]][a:key[a:level]] = { 'name' : 'NONAME' }
			endif
		endif
		call s:add_mapping(a:key, a:cmd, a:level + 1, a:dictname)
	else
		" This level
		let command = s:escape_mappings(a:cmd)
		if a:level == 0
			if !has_key({a:dictname}, a:key[0])
				let {a:dictname}[a:key[0]] = [command, a:cmd]
			endif
		elseif a:level == 1
			if !has_key({a:dictname}[a:key[a:level-1]], a:key[a:level])
				let {a:dictname}[a:key[a:level-1]][a:key[a:level]] = [ command, a:cmd ]
			endif
		elseif a:level == 2
			if !has_key({a:dictname}[a:key[a:level-2]][a:key[a:level-1]], a:key[a:level])
				let {a:dictname}[a:key[a:level-2]][a:key[a:level-1]][a:key[a:level]] = [ command, a:cmd ]
			endif
		elseif a:level == 3
			if !has_key({a:dictname}[a:key[a:level-3]][a:key[a:level-2]][a:key[a:level-1]], a:key[a:level])
				let {a:dictname}[a:key[a:level-3]][a:key[a:level-2]][a:key[a:level-1]][a:key[a:level]] = [ command, a:cmd ]
			endif
		endif
	endif
endfunction

function! s:escape_mappings(string)
	return substitute(a:string, '\([@]\?\)\(<Plug>.*\)$', 'call feedkeys("\\\2")', '')
endfunction

function! s:calc_layout(dkmap)
	let maxlength = 0
	for k in keys(a:dkmap)
		if k != 'name'
		if type(a:dkmap[k]) == type({})
			let currlen = strdisplaywidth("[".k."] ". a:dkmap[k].name ."\t\t")
		else
			let string = a:dkmap[k]
			let desc = string[1]
			let currlen = strdisplaywidth("[".k."] ".desc."\t\t")
		endif
		if currlen > maxlength
			let maxlength = currlen
		endif
		endif
	endfor
	let cols = winwidth(0) / maxlength
	let colwidth = winwidth(0) / cols
	return [cols, colwidth, maxlength]
endfunction

function! s:escape_keys(inp)
	return substitute(a:inp, "<", "<lt>", "")
endfunction


function! s:create_string(dkmap, ncols, colwidth)
	"echo a:dkmap
	let output = []
	let colnum = 1
	let nrows = 1
	for k in sort(keys(a:dkmap),'i')
		if k != 'name'
		if type(a:dkmap[k]) == type({})
			let displaystring = "[".k."] ".a:dkmap[k].name
		else
			let string = a:dkmap[k]
			let desc = string[1]
			let displaystring = "[".k."] ". desc
		endif
		let entry_len = strdisplaywidth(displaystring)
        call add(output, displaystring)
		if colnum == a:ncols || g:leaderGuide_vertical
			call add(output, "\n")
			let nrows += 1
			let colnum = 1
		else
			let colnum += 1
			while entry_len < a:colwidth
				call add(output, ' ')
				let entry_len += 1
			endwhile
		endif
		execute "cmap <buffer> " . k . " " . s:escape_keys(k) ."<CR>"
		endif
	endfor
	cmap <buffer> <Space> <Space><CR>
	return [output, nrows]
endfunction

function! s:start_cmdwin(lmap)
	let [ncols, colwidth, maxlen] = s:calc_layout(a:lmap)
	let [string, nrows] = s:create_string(a:lmap, ncols, colwidth)
    let inp = input('Insert Key: '."\n".join(string,'')."\n")
    if inp != ''
		let fsel = get(a:lmap, inp)[0]
	else
		let fsel = ''
	endif
	silent! call s:unmap_keys(keys(a:lmap))
	redraw
	execute fsel
endfunction

function! s:start_buffer(lmap)
	call s:create_buffer()
	let [ncols, colwidth, maxlen] = s:calc_layout(a:lmap)
	let [string, nrows] = s:create_string(a:lmap, ncols, colwidth)

	if g:leaderGuide_vertical
		execute 'vert res '.maxlen
	else
		execute 'res '.nrows
	endif

	execute "normal! i ".join(string,'')
	setlocal nomodifiable
	redraw
	let inp = input("")
    if inp != '' && inp!= "<lt>ESC>"
		let fsel = get(a:lmap, inp)
	else
		let fsel = ['call feedkeys("\<ESC>")']
	endif
	bdelete!
	execute s:winnr.'wincmd w'
	call winrestview(s:winv)
	redraw
	if type(fsel) == type({})
		if s:vis
			normal gv
			LeaderGuideVisual fsel
		else
			LeaderGuide fsel
		endif
	else
		if s:vis
			normal gv
		endif
		execute fsel[0]
	endif
endfunction

function! s:create_buffer()
	if g:leaderGuide_vertical
		execute g:leaderGuide_position.' 1vnew'
	else
		execute g:leaderGuide_position.' 1new'
	endif
	setlocal filetype=leaderGuide nonumber nowrap
	setlocal nobuflisted buftype=nofile bufhidden=wipe noswapfile
	nnoremap <buffer> <silent> <ESC> :bdelete!<cr>
	autocmd WinLeave <buffer> :bdelete!
endfunction

function! leaderGuide#Start(vis, dict)
	let s:vis = a:vis
	let s:winv = winsaveview()
	let s:winnr = winnr()
	
	if g:leaderGuide_use_buffer
		call s:start_buffer(a:dict)
	else
		call s:start_cmdwin(a:dict)
	endif
endfunction
