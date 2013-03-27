" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

let s:V = vital#of('open-browser.vim')
let s:Process = s:V.import('Process')
unlet s:V


" Interfaces {{{

function! openbrowser#load() "{{{
    " dummy function to load this file.
endfunction "}}}



" :OpenBrowser
function! openbrowser#open(uri) "{{{
    let uri = a:uri
    if uri =~# '^\s*$'
        " Error
        return
    endif

    let type = s:detect_query_type(uri)
    if type.filepath    " Existed file path or 'file://'
        " Convert to full path.
        if stridx(uri, 'file://') is 0    " file://
            let fullpath = substitute(uri, '^file://', '', '')
        elseif uri[0] ==# '/'    " full path
            let fullpath = uri
        else    " relative path
            let fullpath = s:convert_to_fullpath(uri)
        endif
        if s:get_var('openbrowser_open_filepath_in_vim')
            let command = s:get_var('openbrowser_open_vim_command')
            execute command fullpath
        else
            " Convert to file:// string.
            " NOTE: cygwin cannot treat file:// URI,
            " pass a string as fullpath.
            if !g:__openbrowser_platform.cygwin
                let fullpath = 'file://' . fullpath
            endif
            call s:open_browser(fullpath)
        endif
    elseif type.uri    " other URI
        let obj = urilib#new_from_uri_like_string(uri, s:NONE)
        if obj is s:NONE
            " Error
            return
        endif
        " Fix scheme, host, path.
        " e.g.: "ttp" => "http"
        for where in ['scheme', 'host', 'path']
            let fix = s:get_var('openbrowser_fix_'.where.'s')
            let value = obj[where]()
            if has_key(fix, value)
                call call(obj[where], [fix[value]], obj)
            endif
        endfor
        let uri = obj.to_string()
        call s:open_browser(uri)
    else
        " Error
        return
    endif
endfunction "}}}

" :OpenBrowserSearch
function! openbrowser#search(query, ...) "{{{
    if a:query =~# '^\s*$'
        return
    endif

    let engine = a:0 ? a:1 :
    \   s:get_var('openbrowser_default_search')
    let search_engines =
    \   s:get_var('openbrowser_search_engines')
    if !has_key(search_engines, engine)
        echohl WarningMsg
        echomsg "Unknown search engine '" . engine . "'."
        echohl None
        return
    endif

    call openbrowser#open(
    \   s:expand_keywords(search_engines[engine], {'query': a:query})
    \)
endfunction "}}}

" :OpenBrowserSmartSearch
function! openbrowser#smart_search(query, ...) "{{{
    let type = s:detect_query_type(a:query)
    if type.uri ||
    \  s:get_var('openbrowser_open_filepath_in_vim') &&
    \  type.filepath
        return openbrowser#open(a:query)
    else
        return openbrowser#search(
        \   a:query,
        \   (a:0 ? a:1 : s:get_var('openbrowser_default_search'))
        \)
    endif
endfunction "}}}

" so-called thinca-san escaping ;)
" http://d.hatena.ne.jp/thinca/20100210/1265813598
if g:__openbrowser_platform.mswin
    function! openbrowser#shellescape(uri) "{{{
        let uri = a:uri
        if uri =~# '[&|<>()^"%]'
            " 1. Escape all special characers (& | < > ( ) ^ " %) with hat (^).
            "    (Escaping percent (%) keeps hat (^) not to expand)
            let uri = substitute(uri, '[&|<>()^"%]', '^\0', 'g')
            " 2. Escape successive backslashes (\) before double-quote (") with the same number of backslashes.
            let uri = substitute(uri, '\\\+\ze"', '\0\0', 'g')
            " 3. Escape all double-quote (") with backslash (\)
            "    (though _"_ has been already escaped by hat (^) , escape it again.
            "     thus, double-quote (") becomes backslash + hat + double-quote (\^"))
            let uri = substitute(uri, '"', '\\\0', 'g')
            " 4. Wrap whole string with hat + double-quote (^").
            "    (Simply wrapping with _""_ results in _^_ gets invalid)
            let uri = '^"' . uri . '^"'
        endif
        return uri
    endfunction "}}}
else
    function! openbrowser#shellescape(uri) "{{{
        return a:uri
    endfunction "}}}
endif

" }}}

" Implementations {{{

let s:NONE = []
lockvar s:NONE



function! s:parse_and_delegate(excmd, parse, delegate, cmdline) "{{{
    let cmdline = substitute(a:cmdline, '^\s\+', '', '')

    try
        let [engine, cmdline] = {a:parse}(cmdline)
    catch /^parse error/
        echohl WarningMsg
        echomsg 'usage:'
        \       a:excmd
        \       '[-{search-engine}]'
        \       '{query}'
        echohl None
        return
    endtry

    let args = [cmdline] + (engine is s:NONE ? [] : [engine])
    return call(a:delegate, args)
endfunction "}}}
function! s:parse_cmdline(cmdline) "{{{
    let m = matchlist(a:cmdline, '^-\(\S\+\)\s\+\(.*\)')
    return !empty(m) ? m[1:2] : [s:NONE, a:cmdline]
endfunction "}}}

" :OpenBrowserSearch
function! openbrowser#_cmd_open_browser_search(cmdline) "{{{
    return s:parse_and_delegate(
    \   ':OpenBrowserSearch',
    \   's:parse_cmdline',
    \   'openbrowser#search',
    \   a:cmdline
    \)
endfunction "}}}
function! openbrowser#_cmd_complete(unused1, cmdline, unused2) "{{{
    let excmd = '^\s*OpenBrowser\w\+\s\+'
    if a:cmdline !~# excmd
        return
    endif
    let cmdline = substitute(a:cmdline, excmd, '', '')

    let engine_options = map(
    \   sort(keys(s:get_var('openbrowser_search_engines'))),
    \   '"-" . v:val'
    \)
    if cmdline ==# '' || cmdline ==# '-'
        " Return all search engines.
        return engine_options
    endif

    " Inputting search engine.
    " Find out which engine.
    return filter(engine_options, 'stridx(v:val, cmdline) is 0')
endfunction "}}}

" :OpenBrowserSmartSearch
function! openbrowser#_cmd_open_browser_smart_search(cmdline) "{{{
    return s:parse_and_delegate(
    \   ':OpenBrowserSmartSearch',
    \   's:parse_cmdline',
    \   'openbrowser#smart_search',
    \   a:cmdline
    \)
endfunction "}}}

" <Plug>(openbrowser-open)
function! openbrowser#_keymapping_open(mode) "{{{
    if a:mode ==# 'n'
        return openbrowser#open(s:get_url_on_cursor())
    else
        return openbrowser#open(s:get_selected_text())
    endif
endfunction "}}}

" <Plug>(openbrowser-search)
function! openbrowser#_keymapping_search(mode) "{{{
    if a:mode ==# 'n'
        return openbrowser#search(s:get_url_on_cursor())
    else
        return openbrowser#search(s:get_selected_text())
    endif
endfunction "}}}

" <Plug>(openbrowser-smart-search)
function! openbrowser#_keymapping_smart_search(mode) "{{{
    if a:mode ==# 'n'
        return openbrowser#smart_search(s:get_url_on_cursor())
    else
        return openbrowser#smart_search(s:get_selected_text())
    endif
endfunction "}}}


function! s:seems_path(uri) "{{{
    " - Has no invalid filename character (seeing &isfname)
    " and, either
    " - file:// prefixed string and existed file path
    " - Existed file path
    if stridx(a:uri, 'file://') is 0
        let path = substitute(a:uri, '^file://', '', '')
    else
        let path = a:uri
    endif
    return getftype(path) !=# ''
endfunction "}}}

function! s:seems_uri(uri) "{{{
    let uri = urilib#new_from_uri_like_string(a:uri, s:NONE)
    return uri isnot s:NONE
    \   && uri.scheme() !=# ''
    \   && uri.host() =~# '\.'
endfunction "}}}

function! s:detect_query_type(query) "{{{
    return {
    \   'uri': s:seems_uri(a:query),
    \   'filepath': s:seems_path(a:query),
    \}
endfunction "}}}

function! s:convert_to_fullpath(path) "{{{
    let save_shellslash = &shellslash
    let &l:shellslash = 1
    try
        return fnamemodify(a:path, ':p')
    finally
        let &l:shellslash = save_shellslash
    endtry
endfunction "}}}

function! s:open_browser(uri) "{{{
    let uri = a:uri

    redraw
    echo "opening '" . uri . "' ..."

    for cmd in s:get_var('openbrowser_browser_commands')
        if !executable(cmd.name)
            continue
        endif

        let cmdline = s:expand_keywords(
        \   cmd.args,
        \   {'browser': cmd.name, 'uri': uri}
        \)
        call s:Process.system_bg(cmdline)

        " No need to check v:shell_error
        " because browser is spawned in background process
        " so can't check its return value.

        redraw
        echo "opening '" . uri . "' ... done! (" . cmd.name . ")"
        return
    endfor

    echohl WarningMsg
    redraw
    echomsg "open-browser doesn't know how to open '" . uri . "'."
    echohl None
endfunction "}}}

" Get selected text in visual mode.
function! s:get_selected_text() "{{{
    let save_z = getreg('z', 1)
    let save_z_type = getregtype('z')

    try
        normal! gv"zy
        return @z
    finally
        call setreg('z', save_z, save_z_type)
    endtry
endfunction "}}}

function! s:get_url_on_cursor() "{{{
    let line = s:getconcealedline('.')
    let col = s:getconcealedcol('.')
    if line[col-1] !~# '\S'    " cursor is not on URL
        return ''
    endif
    " Get continuous non-space string under cursor.
    let left = col <=# 1 ? '' : line[: col-2]
    let right = line[col-1 :]
    let nonspstr = matchstr(left, '\S\+$').matchstr(right, '^\S\+')
    " Extract URL.
    " via https://github.com/mattn/vim-textobj-url/blob/af1edbe57d4f05c11e571d4cacd30672cdd9d944/autoload/textobj/url.vim#L2
    let re_url = '\(https\?\|ftp\)://[a-zA-Z0-9][a-zA-Z0-9_-]*\(\.[a-zA-Z0-9][a-zA-Z0-9_-]*\)*\(:\d\+\)\?\(/[a-zA-Z0-9_/.+%#?&=;@$,!''*~-]*\)\?'
    let url = matchstr(nonspstr, re_url)
    return url
endfunction "}}}

" This function is from quickrun.vim (http://github.com/thinca/vim-quickrun)
" Original function is `s:Runner.expand()`.
"
" NOTE: Original version recognize more keywords.
" This function is speciallized for open-browser.vim
" - @register @{register}
" - &option &{option}
" - $ENV_NAME ${ENV_NAME}
"
" Expand the keywords.
" - {expr}
"
" Escape by \ if you does not want to expand.
" - "\{keyword}" => "{keyword}", not expression `keyword`.
"   it does not expand vim variable `keyword`.
function! s:expand_keywords(str, options)  " {{{
    if type(a:str) != type('') || type(a:options) != type({})
        echoerr 's:expand_keywords(): invalid arguments. (a:str = '.string(a:str).', a:options = '.string(a:options).')'
        return ''
    endif
    let rest = a:str
    let result = ''

    " Assign these variables for eval().
    for [name, val] in items(a:options)
        " unlockvar l:
        " let l:[name] = val
        execute 'let' name '=' string(val)
    endfor

    while 1
        let f = match(rest, '\\\?[{]')

        " No more special characters. end parsing.
        if f < 0
            let result .= rest
            break
        endif

        " Skip ordinary string.
        if f != 0
            let result .= rest[: f - 1]
            let rest = rest[f :]
        endif

        " Process special string.
        if rest[0] == '\'
            let result .= rest[1]
            let rest = rest[2 :]
        elseif rest[0] == '{'
            let e = matchend(rest, '\\\@<!}')
            let expr = substitute(rest[1 : e - 2], '\\}', '}', 'g')
            let result .= eval(expr)
            let rest = rest[e :]
        else
            echohl WarningMsg
            echomsg 'parse error: rest = '.rest.', result = '.result
            echohl None
        endif
    endwhile
    return result
endfunction "}}}

function! s:get_var(varname) "{{{
    for ns in [b:, w:, t:, g:]
        if has_key(ns, a:varname)
            return ns[a:varname]
        endif
    endfor
    throw 'openbrowser: internal error: '
    \   . "s:get_var() couldn't find variable '".a:varname."'."
endfunction "}}}

" From https://github.com/chikatoike/concealedyank.vim
function! s:getconcealedline(lnum, ...) "{{{
    if !has('conceal')
        return getline(a:lnum)
    endif

    let line = getline(a:lnum)
    let index = get(a:000, 0, 0)
    let endidx = get(a:000, 1, -1)
    let endidx = endidx >= 0 ? min([endidx, strlen(line)]) : strlen(line)

    let region = -1
    let ret = ''

    while index <= endidx
        let concealed = synconcealed(a:lnum, index + 1)
        if concealed[0] != 0
            if region != concealed[2]
                let region = concealed[2]
                let ret .= concealed[1]
            endif
        else
            let ret .= line[index]
        endif

        " get next char index.
        let index += 1
    endwhile

    return ret
endfunction "}}}

function! s:getconcealedcol(expr) "{{{
    if !has('conceal')
        return col(a:expr)
    endif

    let line = getline('.')
    let index = 0
    let endidx = col(a:expr)

    let region = -1
    let ret = 0
    let isconceal = 0

    while index < endidx
        let concealed = synconcealed('.', index + 1)
        if concealed[0] == 0
            let ret += 1
        endif
        let isconceal = concealed[0]

        " get next char index.
        let index += 1
    endwhile

    if ret == 0
      let ret = 1
    elseif isconceal
      let ret += 1
    endif

    return ret
endfunction "}}}

" }}}


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
