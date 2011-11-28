" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


" Default values of global variables. "{{{
if g:__openbrowser_platform.cygwin
    function! s:get_default_open_commands()
        return ['cygstart']
    endfunction
    function! s:get_default_open_rules()
        return {'cygstart': '{browser} {shellescape(uri)} &'}
    endfunction
elseif g:__openbrowser_platform.macunix
    function! s:get_default_open_commands()
        return ['open']
    endfunction
    function! s:get_default_open_rules()
        return {'open': '{browser} {shellescape(uri)} &'}
    endfunction
elseif g:__openbrowser_platform.mswin
    function! s:get_default_open_commands()
        return ['cmd.exe']
    endfunction
    function! s:get_default_open_rules()
        " NOTE: On MS Windows, 'start' command is not executable.
        " NOTE: If &shellslash == 1,
        " `shellescape(uri)` uses single quotes not double quote.
        return {'cmd.exe': 'cmd /c start rundll32 url.dll,FileProtocolHandler {uri}'}
    endfunction
elseif g:__openbrowser_platform.unix
    function! s:get_default_open_commands()
        return ['xdg-open', 'x-www-browser', 'firefox', 'w3m']
    endfunction
    function! s:get_default_open_rules()
        return {
        \   'xdg-open':      '{browser} {shellescape(uri)} &',
        \   'x-www-browser': '{browser} {shellescape(uri)} &',
        \   'firefox':       '{browser} {shellescape(uri)} &',
        \   'w3m':           '{browser} {shellescape(uri)} &',
        \}
    endfunction
endif

" Do not remove g:__openbrowser_platform for debug.
" unlet g:__openbrowser_platform

" }}}

" Global Variables {{{
if !exists('g:openbrowser_open_commands')
    let g:openbrowser_open_commands = s:get_default_open_commands()
endif
if !exists('g:openbrowser_open_rules')
    let g:openbrowser_open_rules = s:get_default_open_rules()
endif
if !exists('g:openbrowser_fix_schemes')
    let g:openbrowser_fix_schemes = {
    \   'ttp': 'http',
    \   'ttps': 'https',
    \}
endif
if !exists('g:openbrowser_fix_hosts')
    let g:openbrowser_fix_hosts = {}
endif
if !exists('g:openbrowser_fix_paths')
    let g:openbrowser_fix_paths = {}
endif
if exists('g:openbrowser_isfname')
    " Backward compatibility.
    let g:openbrowser_iskeyword = g:openbrowser_isfname
endif
if !exists('g:openbrowser_iskeyword')
    " Getting only URI from <cword>.
    let g:openbrowser_iskeyword = join(
    \   range(char2nr('A'), char2nr('Z'))
    \   + range(char2nr('a'), char2nr('z'))
    \   + range(char2nr('0'), char2nr('9'))
    \   + [
    \   '_',
    \   ':',
    \   '/',
    \   '.',
    \   '-',
    \   '+',
    \   '%',
    \   '#',
    \   '?',
    \   '&',
    \   '=',
    \   ';',
    \   '@',
    \   '$',
    \   ',',
    \   '[',
    \   ']',
    \   '!',
    \   "'",
    \   "(",
    \   ")",
    \   "*",
    \   "~",
    \], ',')
endif
if !exists('g:openbrowser_default_search')
    let g:openbrowser_default_search = 'google'
endif

let s:default = {
\   'alc': 'http://eow.alc.co.jp/{query}/UTF-8/',
\   'askubuntu': 'http://askubuntu.com/search?q={query}',
\   'baidu': 'http://www.baidu.com/s?wd={query}&rsv_bp=0&rsv_spt=3&inputT=2478',
\   'blekko': 'http://blekko.com/ws/+{query}',
\   'cpan': 'http://search.cpan.org/search?query={query}',
\   'duckduckgo': 'http://duckduckgo.com/?q={query}',
\   'github': 'http://github.com/search?q={query}',
\   'google': 'http://google.com/search?q={query}',
\   'google-code': 'http://code.google.com/intl/en/query/#q={query}',
\   'php': 'http://php.net/{query}',
\   'python': 'http://docs.python.org/dev/search.html?q={query}&check_keywords=yes&area=default',
\   'twitter-search': 'http://twitter.com/search/{query}',
\   'twitter-user': 'http://twitter.com/{query}',
\   'verycd': 'http://www.verycd.com/search/entries/{query}',
\   'vim': 'http://www.google.com/cse?cx=partner-pub-3005259998294962%3Abvyni59kjr1&ie=ISO-8859-1&q={query}&sa=Search&siteurl=www.vim.org%2F#gsc.tab=0&gsc.q={query}&gsc.page=1',
\   'wikipedia': 'http://en.wikipedia.org/wiki/Special:Search?search={query}',
\   'yahoo': 'http://search.yahoo.com/search?p={query}',
\}
if exists('g:openbrowser_search_engines')
    call extend(g:openbrowser_search_engines, s:default, 'keep')
else
    let g:openbrowser_search_engines = s:default
endif
unlet s:default

if !exists('g:openbrowser_open_filepath_in_vim')
    let g:openbrowser_open_filepath_in_vim = 1
endif
if !exists('g:openbrowser_open_vim_command')
    let g:openbrowser_open_vim_command = 'vsplit'
endif
" }}}


" Interfaces {{{

function! openbrowser#load() "{{{
    " dummy function to load this file.
endfunction "}}}



" :OpenBrowser
function! openbrowser#open(uri) "{{{
    if a:uri =~# '^\s*$'
        return
    endif
    if s:get_var('openbrowser_open_filepath_in_vim')
    \   && s:seems_path(a:uri)
        execute s:get_var('openbrowser_open_vim_command') a:uri
        return
    endif

    let uri = s:convert_uri(a:uri)
    redraw
    echo "opening '" . uri . "' ..."

    for browser in s:get_var('openbrowser_open_commands')
        if !executable(browser)
            continue
        endif
        let open_rules = s:get_var('openbrowser_open_rules')
        if !has_key(open_rules, browser)
            continue
        endif

        let cmdline = s:expand_keywords(
        \   open_rules[browser],
        \   {'browser': browser, 'uri': uri}
        \)
        call system(cmdline)
        " No need to check v:shell_error
        " because browser is spawned in background process
        " so can't check its return value.
        redraw
        echo "opening '" . uri . "' ... done! (" . browser . ")"
        return
    endfor

    echohl WarningMsg
    redraw
    echomsg "open-browser doesn't know how to open '" . uri . "'."
    echohl None
endfunction "}}}

" :OpenBrowserSearch
function! openbrowser#search(query, ...) "{{{
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
    \   s:expand_keywords(search_engines[engine], {'query': urilib#uri_escape(a:query)})
    \)
endfunction "}}}

" :OpenBrowserSmartSearch
function! openbrowser#smart_search(query, ...) "{{{
    if s:seems_uri(a:query)
    \   || (s:get_var('openbrowser_open_filepath_in_vim')
    \       && s:seems_path(a:query))
        return openbrowser#open(a:query)
    else
        return openbrowser#search(
        \   a:query,
        \   (a:0 ? a:1 : s:get_var('openbrowser_default_search'))
        \)
    endif
endfunction "}}}

" }}}

" Implementations {{{

let s:NONE = []



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
        return openbrowser#search(expand('<cword>'))
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


function! s:seems_path(path) "{{{
    " - Has no invalid filename character (seeing &fname)
    " and, either
    " - file:// prefixed string
    " - Existed path
    return (stridx(a:path, 'file://') ==# 0
    \       || getftype(a:path) !=# '')
    \   && a:path =~# '^\f\+$'
endfunction "}}}

function! s:seems_uri(uri) "{{{
    let ERROR = []
    let uri = urilib#new_from_uri_like_string(a:uri, ERROR)
    return uri isnot ERROR
    \   && uri.scheme() !=# ''
    \   && uri.host() =~# '\.'
endfunction "}}}

" - If a:uri looks like file path, add "file:///"
" - Apply settings of g:openbrowser_fix_schemes, g:openbrowser_fix_hosts, g:openbrowser_fix_paths
function! s:convert_uri(uri) "{{{
    if s:seems_path(a:uri)    " File path
        " a:uri is File path. Converts a:uri to `file://` URI.
        if stridx(a:uri, 'file://') ==# 0
            return a:uri
        endif
        let save_shellslash = &shellslash
        let &l:shellslash = 1
        try
            let uri = fnamemodify(a:uri, ':p')
            if g:__openbrowser_platform.cygwin
                return uri
            else
                return 'file:///' . uri
            endif
        finally
            let &l:shellslash = save_shellslash
        endtry
    elseif s:seems_uri(a:uri)    " URI
        let ERROR = []
        let obj = urilib#new_from_uri_like_string(a:uri, ERROR)
        if obj isnot ERROR
            " Fix scheme, host, path.
            " e.g.: "ttp" => "http"
            for where in ['scheme', 'host', 'path']
                let fix = s:get_var('openbrowser_fix_'.where.'s')
                let value = obj[where]()
                if has_key(fix, value)
                    call call(obj[where], [fix[value]])
                endif
            endfor
            return obj.to_string()
        endif
        " Fall through
    endif
    return a:uri
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
    let save_iskeyword = &iskeyword
    " Avoid rebuilding of `chartab`.
    " (declared in globals.h, rebuilt by did_set_string_option() in option.c)
    if &iskeyword !=# g:openbrowser_iskeyword
        let &iskeyword = g:openbrowser_iskeyword
    endif
    try
        return expand('<cword>')
    finally
        " Avoid rebuilding of `chartab`.
        if &iskeyword !=# save_iskeyword
            let &iskeyword = save_iskeyword
        endif
    endtry
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

" }}}


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
