" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

let s:V = vital#of('openbrowser')
let s:Prelude = s:V.import('Prelude')
let s:String = s:V.import('Data.String')
let s:Process = s:V.import('Process')
let s:URI = s:V.import('Web.URI')
let s:HTTP = s:V.import('Web.HTTP')
let s:Buffer = s:V.import('Vim.Buffer')
let s:Msg = s:V.import('Vim.Message')
unlet s:V


" Save/Determine global variable values.
let s:vimproc_is_installed = globpath(&rtp, 'autoload/vimproc.vim') !=# ''


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

    let opened = 0
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
            let fullpath = tr(fullpath, '\', '/')
            try
                let command = s:get_var('openbrowser_open_vim_command')
                execute command fullpath
                let opened = 1
            catch
                call s:Msg.error('open-browser failed to open in vim...: '
                \          . 'v:exception = ' . v:exception
                \          . ', v:throwpoint = ' . v:throwpoint)
            endtry
        else
            let fullpath = tr(fullpath, '\', '/')
            " Convert to file:// string.
            " NOTE: cygwin cannot treat file:// URI,
            " pass a string as fullpath.
            if !g:__openbrowser_platform.cygwin
                let fullpath = 'file://' . fullpath
            endif
            let opened = s:open_browser(fullpath)
        endif
    elseif type.uri    " other URI
        let obj = s:URI.new_from_uri_like_string(uri, s:NONE)
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
        let opened = s:open_browser(uri)
    endif
    if !opened
        call s:Msg.warn("open-browser doesn't know how to open '" . uri . "'.")
    elseif s:Prelude.is_windows() && g:openbrowser_force_foreground_after_open
        " XXX: Vim looses a focus after opening URI...
        " Is this same as non-Windows platform?
        augroup openbrowser
            autocmd!
            autocmd FocusLost * call foreground() | autocmd! openbrowser FocusLost
        augroup END
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
        call s:Msg.warn("Unknown search engine '" . engine . "'.")
        return
    endif

    let query = s:HTTP.encodeURIComponent(a:query)
    let uri = s:expand_keywords(search_engines[engine], {'query': query})
    call openbrowser#open(uri)
endfunction "}}}

" :OpenBrowserSmartSearch
function! openbrowser#smart_search(query, ...) "{{{
    let type = s:detect_query_type(a:query)
    if type.uri || type.filepath
        return openbrowser#open(a:query)
    else
        return openbrowser#search(
        \   a:query,
        \   (a:0 ? a:1 : s:get_var('openbrowser_default_search'))
        \)
    endif
endfunction "}}}

" Escape one argument.
function! openbrowser#shellescape(...) "{{{
    return call(s:Process.shellescape, a:000, s:Process)
endfunction "}}}

" }}}

" Implementations {{{

let s:NONE = []
lockvar s:NONE



function! s:parse_and_delegate(excmd, parse, delegate, cmdline) "{{{
    let cmdline = substitute(a:cmdline, '^\s\+', '', '')

    try
        let [engine, cmdline] = {a:parse}(cmdline)
    catch /^parse error/
        call s:Msg.warn(
        \   a:excmd
        \   . ' [-{search-engine}]'
        \   . ' {query}'
        \)
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
        let url = openbrowser#get_url_on_cursor()
        let filepath = openbrowser#get_filepath_on_cursor()
        if url != ''
            return openbrowser#open(url)
        elseif filepath != ''
            return openbrowser#open(filepath)
        else
            call s:Msg.error("URL or file path is not found under cursor!")
            return
        endif
    else
        for url in s:extract_urls(s:get_selected_text())
            call openbrowser#open(url.str)
        endfor
    endif
endfunction "}}}

" <Plug>(openbrowser-search)
function! openbrowser#_keymapping_search(mode) "{{{
    if a:mode ==# 'n'
        return openbrowser#search(expand('<cword>'))
    else
        return openbrowser#search(s:get_selected_text())
    endif
endfunction "}}}

" <Plug>(openbrowser-smart-search)
function! openbrowser#_keymapping_smart_search(mode) "{{{
    if a:mode ==# 'n'
        let url = openbrowser#get_url_on_cursor()
        let filepath = openbrowser#get_filepath_on_cursor()
        let query = (url !=# '' ? url : filepath !=# '' ? filepath : expand('<cword>'))
        if query ==# ''
            call s:Msg.error("URL or word is not found under cursor!")
            return
        endif
        return openbrowser#smart_search(query)
    else
        let text = s:get_selected_text()
        let urls = s:extract_urls(text)
        if !empty(urls)
            for url in urls
                call openbrowser#open(url.str)
            endfor
        else
            call openbrowser#search(
            \   text, s:get_var('openbrowser_default_search')
            \)
        endif
    endif
endfunction "}}}

function! s:get_selected_text() "{{{
    let selected_text = s:Buffer.get_last_selected()
    let text = substitute(selected_text, '[\n\r]\+', ' ', 'g')
    return substitute(text, '^\s*\|\s*$', '', 'g')
endfunction "}}}

function! s:by_length(s1, s2) abort
    let [l1, l2] = [strlen(a:s1), strlen(a:s2)]
    return l1 ># l2 ? -1 : l1 <# l2 ? 1 : 0
endfunction

" @return Dictionary
"         str url
"         startidx start index
"         endidx end index ([startidex, endidx), half-open interval)
function! s:extract_urls(text) abort
    let text = a:text
    let scheme_map = s:get_var('openbrowser_fix_schemes')
    let schemes_pattern = join(sort(keys(scheme_map), 's:by_length'), '\|')
    let pattern = '\(https\?\|' . schemes_pattern . '\)'
    let urls = []
    let start = 0
    let len = strlen(text)
    while start <# len
        " Search scheme.
        let [start, end] = [match(text, pattern, start), matchend(text, pattern, start)]
        if start ==# -1
            break
        endif
        let subtext = text[start :]
        let scheme = text[start : end - 1]
        if has_key(scheme_map, scheme)
            let rep = scheme_map[scheme]
            let subtext = substitute(subtext, '^'.pattern, rep, '')
            let results = s:URI.new_from_seq_string(subtext, s:NONE)
        else
            let results = s:URI.new_from_seq_string(subtext, s:NONE)
        endif
        " Try to parse string as URI.
        if results isnot s:NONE
            let [url, original_url] = results[0:1]
            let skip_num = len(original_url) + (has_key(scheme_map, scheme) ?
            \                                   len(rep) - len(scheme) : 0)
            let urls += [{
            \   'str': url.to_string(),
            \   'startidx': start,
            \   'endidx': start + skip_num,
            \}]
            let start += skip_num
        else
            let start = end
        endif
    endwhile
    return urls
endfunction

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
    let uri = s:URI.new_from_uri_like_string(a:uri, s:NONE)
    return uri isnot s:NONE
    \   && uri.scheme() !=# ''
endfunction "}}}

function! s:detect_query_type(query) "{{{
    return {
    \   'uri': s:seems_uri(a:query),
    \   'filepath': s:seems_path(a:query),
    \}
endfunction "}}}

function! s:convert_to_fullpath(path) "{{{
    if exists('+shellslash')
        let save_shellslash = &l:shellslash
        let &l:shellslash = 1
    endif
    try
        return fnamemodify(a:path, ':p')
    finally
        if exists('+shellslash')
            let &l:shellslash = save_shellslash
        endif
    endtry
endfunction "}}}

function! s:expand_format_message(format_message, keywords) "{{{
    let maxlen = s:Msg.get_hit_enter_max_length()
    let expanded_msg = s:expand_keywords(a:format_message.msg, a:keywords)
    if a:format_message.truncate && strlen(expanded_msg) > maxlen
        " Avoid |hit-enter-prompt|.
        let non_uri_len = strlen(expanded_msg) - strlen(a:keywords.uri)
        " First Try: Remove protocol in URI.
        let protocol = '\C^https\?://'
        let matched_len = strlen(matchstr(a:keywords.uri, protocol))
        if matched_len > 0
            let a:keywords.uri = a:keywords.uri[matched_len :]
        endif
        if non_uri_len + strlen(a:keywords.uri) <= maxlen
            let expanded_msg = s:expand_keywords(a:format_message.msg, a:keywords)
        else
            " Second Try: Even if expanded_msg is longer than command-line
            " after "First Try", truncate URI as possible.
            let min_uri_len = a:format_message.min_uri_len
            if non_uri_len + min_uri_len <= maxlen
                " Truncate only URI.
                let a:keywords.uri = s:String.truncate_skipping(
                \           a:keywords.uri, maxlen - 4 - non_uri_len, 0, '...')
                let expanded_msg = s:expand_keywords(a:format_message.msg, a:keywords)
            else
                " Fallback: Even if expanded_msg is longer than command-line
                " after "Second Try", truncate whole string.
                let a:keywords.uri = s:String.truncate_skipping(
                \                   a:keywords.uri, min_uri_len, 0, '...')
                let expanded_msg = s:expand_keywords(a:format_message.msg, a:keywords)
                let expanded_msg = s:String.truncate_skipping(
                \                   expanded_msg, maxlen - 4, 0, '...')
            endif
        endif
    endif
    return expanded_msg
endfunction "}}}

function! s:open_browser(uri) "{{{
    let uri = a:uri

    let format_message = s:get_var('openbrowser_format_message')
    if format_message.msg !=# ''
        redraw
        let msg = s:expand_format_message(format_message,
        \   {
        \      'uri' : uri,
        \      'done' : 0,
        \      'command' : '',
        \   })
        echo msg
    endif

    for cmd in s:get_var('openbrowser_browser_commands')
        if !executable(cmd.name)
            continue
        endif

        " If args is not List, need to escape by open-browser,
        " not s:Process.system().
        let args = deepcopy(cmd.args)
        let need_escape = type(args) isnot type([])
        let quote = need_escape ? "'" : ''
        let use_vimproc = (g:openbrowser_use_vimproc && s:vimproc_is_installed)
        let system_args = map(
        \   (type(args) is type([]) ? copy(args) : [args]),
        \   's:expand_keywords(
        \      v:val,
        \      {
        \           "browser"      : quote . cmd.name . quote,
        \           "browser_noesc": cmd.name,
        \           "uri"          : quote . uri . quote,
        \           "uri_noesc"    : uri,
        \           "use_vimproc"  : use_vimproc,
        \       }
        \   )'
        \)
        call s:Process.system(
        \   (type(args) is type([]) ? system_args : system_args[0]),
        \   {'use_vimproc': use_vimproc,
        \    'background': get(cmd, 'background')}
        \)

        " No need to check v:shell_error
        " because browser is spawned in background process
        " so can't check its return value.

        if format_message.msg !=# ''
            redraw
            let msg = s:expand_format_message(format_message,
            \   {
            \      'uri' : uri,
            \      'done' : 1,
            \      'command' : cmd.name,
            \   })
            echo msg
        endif
        " succeed to open
        return 1
    endfor
    " failed to open
    return 0
endfunction "}}}

" @return the URL on cursor, or the first URL after cursor
function! openbrowser#get_url_on_cursor() "{{{
    let line = s:getconcealedline('.')
    let col = s:getconcealedcol('.')
    if line[col-1] =~# '\s'
        " Skip whitespaces.
        let line = substitute(line[col-1 :], '^\s\+', '', '')
        let urls = s:extract_urls(line)
        return (!empty(urls) ? urls[0].str : '')
    else
        " If cursor is on URL, return it.
        " Otherwise, find the first URL after cursor.
        let idx = col-1
        for url in s:extract_urls(line)
            if url.startidx <=# idx && idx <# url.endidx
            \   || idx <=# url.startidx
                return url.str
            endif
        endfor
        return ''
    endif
endfunction "}}}

" @return the filepath on cursor, or the first filepath after cursor
function! openbrowser#get_filepath_on_cursor() "{{{
    let line = s:getconcealedline('.')
    let col = s:getconcealedcol('.')
    if line[col-1] =~# '\s'
        let line = substitute(line[col-1 :], '^\s\+', '', '')
        if line ==# ''
            return ''
        endif
    endif
    " Get continuous non-space string under cursor.
    let left = col <=# 1 ? '' : line[: col-2]
    let right = line[col-1 :]
    let nonspstr = matchstr(left, '\S\+$').matchstr(right, '^\S\+')
    " Extract file path.
    if s:seems_path(nonspstr)
        return nonspstr
    else
        return ''
    endif
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
            " NOTE: braindex + 1 == 1, it skips first bracket (rest[0])
            let braindex = 0
            let braindex_stack = [braindex]
            while !empty(braindex_stack)
                let braindex = match(rest, '\\\@<![{}]', braindex + 1)
                if braindex ==# -1
                    echoerr 'expression is invalid: curly bracket is not closed.'
                    return ''
                elseif rest[braindex] ==# '{'
                    call add(braindex_stack, braindex)
                else    " '}'
                    let brastart = remove(braindex_stack, -1)
                    " expr does not contain brackets.
                    " Assert: rest[brastart ==# '{' && rest[braindex] ==# '}'
                    let left = brastart ==# 0 ? '' : rest[: brastart-1]
                    let expr = rest[brastart+1 : braindex-1]
                    let right = rest[braindex+1 :]
                    " Remove(unescape) backslashes.
                    let expr = substitute(expr, '\\\([{}]\)', '\1', 'g')
                    let value = eval(expr) . ""
                    let rest = left . value . right
                    let braindex -= len(expr) - len(value)
                endif
            endwhile
            let result .= rest[: braindex]
            let rest = rest[braindex+1 :]
        else
            call s:Msg.warn('parse error: rest = '.rest.', result = '.result)
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

function! s:shellslash()
    return exists('+shellslash') && &l:shellslash
endfunction "}}}

" }}}


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
