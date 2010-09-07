" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Load Once {{{
if exists('g:loaded_openbrowser') && g:loaded_openbrowser
    finish
endif
let g:loaded_openbrowser = 1
" }}}
" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

" Scope Variables {{{
let s:is_unix = has('unix')
let s:is_mswin = has('win16') || has('win32') || has('win64')
let s:is_cygwin = has('win32unix')
let s:is_macunix = has('macunix')
lockvar s:is_unix
lockvar s:is_mswin
lockvar s:is_cygwin
lockvar s:is_macunix
" }}}

" Check your platform {{{
if !(s:is_unix || s:is_mswin || s:is_cygwin || s:is_macunix)
    echohl WarningMsg
    echomsg 'Your platform is not supported!'
    echohl None
    finish
endif
" }}}

" Default values of global variables. "{{{
if s:is_cygwin
    function! s:get_default_open_commands()
        return ['cygstart']
    endfunction
    function! s:get_default_open_rules()
        return {'cygstart': '{browser} {shellescape(uri)}'}
    endfunction
elseif s:is_macunix
    function! s:get_default_open_commands()
        return ['open']
    endfunction
    function! s:get_default_open_rules()
        return {'open': '{browser} {shellescape(uri)}'}
    endfunction
elseif s:is_mswin
    function! s:get_default_open_commands()
        return ['cmd.exe']
    endfunction
    function! s:get_default_open_rules()
        " NOTE: On MS Windows, 'start' command is not executable.
        " NOTE: If &shellslash == 1,
        " `shellescape(uri)` uses single quotes not double quote.
        return {'cmd.exe': 'cmd /c start "openbrowser.vim" "{uri}"'}
    endfunction
elseif s:is_unix
    function! s:get_default_open_commands()
        return ['xdg-open', 'x-www-browser', 'firefox', 'w3m']
    endfunction
    function! s:get_default_open_rules()
        return {
        \   'xdg-open':      '{browser} {shellescape(uri)}',
        \   'x-www-browser': '{browser} {shellescape(uri)}',
        \   'firefox':       '{browser} {shellescape(uri)}',
        \   'w3m':           '{browser} {shellescape(uri)}',
        \}
    endfunction
endif
" }}}

" Global Variables {{{
if !exists('g:openbrowser_open_commands')
    let g:openbrowser_open_commands = s:get_default_open_commands()
endif
if !exists('g:openbrowser_open_rules')
    let g:openbrowser_open_rules = s:get_default_open_rules()
endif
if !exists('g:openbrowser_fix_schemes')
    let g:openbrowser_fix_schemes = {'ttp': 'http'}
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
    " Getting only URI from <cfile>.
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
\   'google': 'http://google.com/search?q={query}',
\   'yahoo': 'http://search.yahoo.com/search?p={query}',
\}
if exists('g:openbrowser_search_engines')
    call extend(g:openbrowser_search_engines, s:default, 'keep')
else
    let g:openbrowser_search_engines = s:default
endif
unlet s:default

if !exists('g:openbrowser_path_open_vim')
    let g:openbrowser_path_open_vim = 1
endif
if !exists('g:openbrowser_open_vim_command')
    let g:openbrowser_open_vim_command = 'vsplit'
endif
" }}}

" Functions {{{

" Open URL with `g:openbrowser_open_commands`.
function! OpenBrowser(uri) "{{{
    if a:uri =~# '^\s*$'
        return
    endif

    if g:openbrowser_path_open_vim && s:seems_path(a:uri)
        execute g:openbrowser_open_vim_command a:uri
        return
    endif

    let uri = s:convert_uri(a:uri)
    redraw
    echo "opening '" . uri . "' ..."

    for browser in g:openbrowser_open_commands
        if !executable(browser)
            continue
        endif

        if !has_key(g:openbrowser_open_rules, browser)
            continue
        endif

        call system(s:expand_keyword(g:openbrowser_open_rules[browser], {'browser': browser, 'uri': uri}))

        let success = 0
        if v:shell_error ==# success
            redraw
            echo "opening '" . uri . "' ... done! (" . browser . ")"
            return
        endif
    endfor

    echohl WarningMsg
    redraw
    echomsg "open-browser doesn't know how to open '" . uri . "'."
    echohl None
endfunction "}}}

function! OpenBrowserSearch(query, ...) "{{{
    if !s:is_urilib_installed()
        echohl WarningMsg
        echomsg 'OpenBrowserSearch() requires urilib.'
        echohl None
        return
    endif

    let engine = a:0 ? a:1 : g:openbrowser_default_search
    if !has_key(g:openbrowser_search_engines, engine)
        echohl WarningMsg
        echomsg "Unknown search engine '" . engine . "'."
        echohl None
        return
    endif

    call OpenBrowser(
    \   s:expand_keyword(g:openbrowser_search_engines[engine], {'query': urilib#uri_escape(a:query)})
    \)
endfunction "}}}

function! s:cmd_open_browser_search(args) "{{{
    let NONE = -1
    let engine = NONE
    let args = substitute(a:args, '^\s\+', '', '')

    if args =~# '^-\w\+\s\+'
        let m = matchlist(args, '^-\(\w\+\)\s\+\(.*\)')
        if empty(m)
        endif
        let [engine, args] = m[1:2]
    endif

    call call('OpenBrowserSearch', [args] + (engine ==# NONE ? [] : [engine]))
endfunction "}}}

function! s:is_urilib_installed() "{{{
    try
        call urilib#load()
        return 1
    catch
        return 0
    endtry
endfunction "}}}

function! s:seems_path(path) "{{{
    return
    \   stridx(a:path, 'file://') ==# 0
    \   || getftype(a:path) =~# '^\(file\|dir\|link\)$'
endfunction "}}}

function! s:convert_uri(uri) "{{{
    if s:seems_path(a:uri)
        " a:uri is File path. Converts a:uri to `file://` URI.
        if stridx(a:uri, 'file://') ==# 0
            return a:uri
        endif
        let save_shellslash = &shellslash
        let &l:shellslash = 1
        try
            return 'file:///' . fnamemodify(a:uri, ':p')
        finally
            let &l:shellslash = save_shellslash
        endtry
    elseif s:is_urilib_installed() && urilib#is_uri(a:uri)
        " a:uri is URI.
        let uri = urilib#new(a:uri)
        call uri.scheme(get(g:openbrowser_fix_schemes, uri.scheme(), uri.scheme()))
        call uri.host  (get(g:openbrowser_fix_hosts, uri.host(), uri.host()))
        call uri.path  (get(g:openbrowser_fix_paths, uri.path(), uri.path()))
        return uri.to_string()
    else
        " Neither
        " - File path
        " - |urilib| has been installed and |urilib| determine a:uri is URI

        " ...But openbrowser should try to open!
        " Because a:uri might be URI like "file://...".
        " In this case, this is not file path and
        " |urilib| might not have been installed :(.
        return a:uri
    endif
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
    let &l:iskeyword = g:openbrowser_iskeyword
    try
        return expand('<cword>')
    finally
        let &l:iskeyword = save_iskeyword
    endtry
endfunction "}}}

" This function is from quickrun.vim (http://github.com/thinca/vim-quickrun)
" Original function is `s:Runner.expand()`.
"
" Expand the keyword.
" - @register @{register}
" - &option &{option}
" - $ENV_NAME ${ENV_NAME}
" - {expr}
" Escape by \ if you does not want to expand.
function! s:expand_keyword(str, options)  " {{{
  if type(a:str) != type('')
    return ''
  endif
  let i = 0
  let rest = a:str
  let result = ''

  " Assign these variables for eval().
  for [name, val] in items(a:options)
      " unlockvar l:
      " let l:[name] = val
      execute 'let' name '=' string(val)
  endfor

  while 1
    let f = match(rest, '\\\?[@&${]')
    if f < 0
      let result .= rest
      break
    endif

    if f != 0
      let result .= rest[: f - 1]
      let rest = rest[f :]
    endif

    if rest[0] == '\'
      let result .= rest[1]
      let rest = rest[2 :]
    else
      if rest =~ '^[@&$]{'
        let rest = rest[1] . rest[0] . rest[2 :]
      endif
      if rest[0] == '@'
        let e = 2
        let expr = rest[0 : 1]
      elseif rest =~ '^[&$]'
        let e = matchend(rest, '.\w\+')
        let expr = rest[: e - 1]
      else  " rest =~ '^{'
        let e = matchend(rest, '\\\@<!}')
        let expr = substitute(rest[1 : e - 2], '\\}', '}', 'g')
      endif
      let result .= eval(expr)
      let rest = rest[e :]
    endif
  endwhile
  return result
endfunction "}}}

" }}}

" Interfaces {{{

" Ex command
command!
\   -bar -nargs=+ -complete=file
\   OpenBrowser
\   call OpenBrowser(<q-args>)
command!
\   -bar -nargs=+
\   OpenBrowserSearch
\   call s:cmd_open_browser_search(<q-args>)

" Key-mapping
nnoremap <Plug>(openbrowser-open) :<C-u>call OpenBrowser(<SID>get_url_on_cursor())<CR>
vnoremap <Plug>(openbrowser-open) :<C-u>call OpenBrowser(<SID>get_selected_text())<CR>

" }}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
