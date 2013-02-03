" =============================================================================
" QuickName: 	The most convenient way navigating opened buffers,
"               incremental search by name 
" Last Change:  2013-01-03
" Maintainer:   Pal Nart <palnart@gmail.com>
" Version:      1.2
" License:      Vim License
" =============================================================================

" Change Log
" 1.2   2013-01-03
" ADD: <Tab> and <S-Tab> moves selection like <Up> and <Down>
" ADD: Use <silent> mapping to keep cmdline clear
" FIX: Catch interrupt (<C-C> or <Esc> keypress) and restore cmd line
" FIX: Use case-sensitive string comparisons to afford immunity from value
"      of 'ignorecase'
" FIX: Do not clobber contents of @y register
"
" 1.1   2009-07-19
" ADD: Key Shift+Enter open buffer in a new horizontally split window. Thanks
" to contribution by Salman Halim
" ADD: Key Ctrl+U reset input line and show all buffers
" FIX: If a buffer is already associated with a window, navigate to that
" window instead of opening in current window
"
" 1.0   2008-07-30
"   Initial upload

if v:version < 700
	finish
endif

if !exists("g:qname_hotkey") || g:qname_hotkey == ""
	let g:qname_hotkey = "<F3>"
endif
exe "nmap" g:qname_hotkey ":cal QNameInit(1)<cr>:~"
let s:qname_hotkey = eval('"\'.g:qname_hotkey.'"')

if exists("g:qname_loaded") && g:qname_loaded
	finish
endif
let g:qname_loaded = 1

function! QNameRun()
	try
		call s:colPrinter.print()
		echo "\rMatch" len(s:n)."/".len(s:ls) "names:" s:inp
		call inputsave()
		let _key = getchar()
		if !type(_key)
			let _key = nr2char(_key)
		endif

		" use case-sensitive equality operator, otherwise <BS> looks like
		" <S-Tab> if 'ignorecase' is set
		if _key ==# "\<BS>"
			let s:inp = s:inp[:-2]
		elseif _key ==# "\<C-U>"
			let s:inp = ""
		elseif strlen(_key) == 1 && char2nr(_key) > 31
			let s:inp = s:inp._key
		endif

		if _key ==# "\<ESC>" || _key ==# "\<CR>" || _key ==# "\<S-CR>"
			let _sel = s:colPrinter.sel
			if _key != "\<ESC>" && _sel < len(s:n) && _sel >= 0
				if _key ==# "\<S-CR>"
					:split
				endif
				call s:swb(str2nr(matchstr(s:s[_sel], '<\zs\d\+\ze>')))
			endif
			call QNameInit(0)
		elseif _key ==# "\<Up>" || _key ==# "\<S-Tab>"
			call s:colPrinter.vert(-1)
		elseif _key ==# "\<Down>" || _key ==# "\<Tab>"
			call s:colPrinter.vert(1)
		elseif _key ==# "\<Left>"
			call s:colPrinter.horz(-1)
		elseif _key ==# "\<Right>"
			call s:colPrinter.horz(1)
		elseif _key ==# s:qname_hotkey
			call QNameInit(0)
		else
			call s:build()
		endif
	catch /^Vim:.*$/
		" restore cmdheight if search is interrupted
		cal QNameInit(0)
	finally
		" clean up screen after dismissing search window
		redraw!
		call inputrestore()
	endtry
endfunc

function! QNameInit(start)
	if a:start
		cmap <silent> ~ cal QNameRun()<CR>:~
		let s:cmdh = &cmdheight
		if a:start != -1
			let s:inp = ""
		endif
		call s:baselist()
		call s:build()
		exe "set cmdheight=".(s:colPrinter.trow+1)
	else
		cmap <silent> ~ exe "cunmap \x7E"<CR>
		exe "set cmdheight=".s:cmdh
	 endif
endfunc

function! s:build()
	let s:s = []
	let s:n = []
	let s:blen = 0
	let _cmp = tolower(tr(s:inp, '\', '/'))
	for _line in s:ls
		let _name = matchstr(_line, '^.\{-}\ze \+<')
		if s:fmatch(tolower(_name), _cmp)
			cal add(s:s, _line)
			cal add(s:n, _name)
		endif
	endfor
	if len(s:n) > s:colPrinter.trow
		cal s:colPrinter.put(s:n)
	else
		cal s:colPrinter.put(s:s)
	endif
endfunc

function! s:swb(bno)
	if bufwinnr(a:bno) == -1
		exe "hid b" a:bno
	else
		exe bufwinnr(a:bno) . "winc w"
	endif
endfunc 

function! s:fmatch(src,pat)
	let _si = strlen(a:src)-1
	let _pi = strlen(a:pat)-1
	while _si>=0 && _pi>=0
		if a:src[_si] == a:pat[_pi]
			let _pi -= 1
		endif
		let _si -= 1
	endwhile
	return _pi < 0
endfunc

function! s:baselist()
	let s:ls = []
	redir => l:bufs | silent ls! | redir END
	for _line in split(l:bufs, "\n")
		if _line[3]!='u' || _line[6]!='-'
			let _bno = matchstr(_line, '^ *\zs\d*')+0
			let _fname = substitute(expand("#"._bno.":p"), '\', '/', 'g')
			if _fname == ""
				let _fname = "|".matchstr(_line, '"\[\zs[^\]]*')."|"
			endif
			let _name = fnamemodify(_fname,":t")
			cal add(s:ls, _name." <"._bno."> ".fnamemodify(_fname,":h"))
		endif
	endfor
	let _align = max(map(copy(s:ls),'stridx(v:val,">")'))
	call map(s:ls, 'substitute(v:val, " <", repeat(" ",_align-stridx(v:val,">"))." <", "")')
	cal sort(s:ls, 1)
endfunc

let s:colPrinter = {"trow": 4}
function! s:colPrinter.put(its) dict
	let _cols = []
	let _trow = self.trow

	let _its = copy(a:its)
	let _len = len(_its)
	let _i = 0
	while _i < _len
		if _i+_trow <= _len
			cal add(_cols, remove(_its,0,_trow-1))
		else
			cal add(_cols, _its)
		endif
		let _i += _trow
	endwhile

	let _cpos = [0]
	let _cw = []
	let _t = 0
	for _li in _cols
		let _w = max(map(copy(_li),'strlen(v:val)'))+4
		let _t += _w
		cal add(_cpos,_t)
		cal add(_cw,_w)
	endfor

	let _rows = []
	for _i in range(_trow)
		let _row = []
		for _j in range(len(_cols))
			if _j*_trow+_i < _len
				cal add(_row,_cols[_j][_i])
			endif
		endfor
		cal add(_rows, _row)
	endfor

	let self.cols = _cols
	let self.cw = _cw
	let self.rows = _rows
	let self.cpos = _cpos
	let self.len = _len
	let self.lcol = 0
	let self.sel = 0
endfunc

function! s:colPrinter.horz(mv) dict
	let _t = self.sel + a:mv*self.trow
	if _t >= 0 && _t < self.len
		let self.sel = _t
	endif
endfunc

function! s:colPrinter.vert(mv) dict
	let _t = self.sel + a:mv
	let _len = self.len
	if _t < 0 && _len > 0
		let self.sel = _len-1
	elseif _t >= _len
		let self.sel = 0
	else
		let self.sel = _t
	endif
endfunc

function! s:colPrinter.print() dict
	let _len = self.len
	let _trow = self.trow
	if !_len
		echo "  [...NO MATCH...]" repeat("\n",_trow)
		return
	endif
	let _sel = self.sel
	let _t = _sel/_trow
	let _cpos = self.cpos
	let _lcol = self.lcol
	let _tcol = &columns
	if _cpos[_lcol]+_tcol < _cpos[_t+1]
		let _rcol = _t
		let _pos = _cpos[_t+1]-_tcol-2
		while _cpos[_lcol] < _pos
			let _lcol += 1
		endwhile
		let _lcol -= _lcol > _t
	else
		if _t < _lcol
			let _lcol = _t
		endif
		let _rcol = len(_cpos)-1
		let _pos = _cpos[_lcol]+_tcol+2
		while _cpos[_rcol] > _pos
			let _rcol -= 1
		endwhile
		let _rcol -= _rcol > _lcol
	endif
	let _cw = self.cw
	let _pos = _cpos[_lcol]+_tcol
	let self.lcol = _lcol
	for _i in range(_trow)
		let _row = self.rows[_i]
		for _j in range(_lcol,_rcol)
			if _j*_trow+_i < _len
				let _txt = "  " . _row[_j]
				let _txt .= repeat(" ", _cw[_j] - strlen(_txt))
				let _txt = _txt[:_pos-_cpos[_j]-2]
				if _j*_trow + _i == _sel
					echoh Search|echon _txt|echoh None
				else
					echon _txt
				endif
			endif
		endfor
		echon "\n"
	endfor
endfunc
