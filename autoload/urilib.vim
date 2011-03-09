" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Load Once {{{
if exists('g:loaded_urilib') && g:loaded_urilib
    finish
endif
let g:loaded_urilib = 1
" }}}
" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


let g:urilib#version = str2nr(printf('%02d%02d%03d', 0, 0, 0))


function! urilib#load() "{{{
    " dummy function to load this script
endfunction "}}}

function! s:sandbox_call(fn, args, nothrow, NothrowValue) "{{{
    try
        return call(a:fn, a:args)
    catch
        if a:nothrow && s:is_urilib_exception(v:exception)
            return a:NothrowValue
        else
            throw substitute(v:exception, '^Vim([^()]\+):', '', '')
        endif
    endtry
endfunction "}}}

function! urilib#new(uri, ...) "{{{
    let nothrow = a:0 != 0
    let NothrowValue = a:0 ? a:1 : 'unused'
    return s:sandbox_call(
    \   's:new', [a:uri], nothrow, NothrowValue)
endfunction "}}}

function! urilib#new_from_uri_like_string(str, ...) "{{{
    let str = a:str
    if str !~# '^[a-z]\+://'    " no scheme.
        let str = 'http://' . str
    endif

    let nothrow = a:0 != 0
    let NothrowValue = a:0 ? a:1 : 'unused'
    return s:sandbox_call(
    \   's:new', [str], nothrow, NothrowValue)
endfunction "}}}

function! urilib#is_uri(str) "{{{
    let ERROR = []
    return urilib#new(a:str, ERROR) isnot ERROR
endfunction "}}}

function! urilib#like_uri(str) "{{{
    let ERROR = []
    return urilib#new_from_uri_like_string(a:str, ERROR) isnot ERROR
endfunction "}}}

function! urilib#uri_escape(str) "{{{
    let escaped = ''
    for i in range(strlen(a:str))
        if a:str[i] =~# '^[A-Za-z0-9\-\._~"]$'
            let escaped .= a:str[i]
        else
            let escaped .= printf("%%%02X", char2nr(a:str[i]))
        endif
    endfor
    return escaped
endfunction "}}}


" s:uri {{{
let s:uri = {
\   '__scheme': '',
\   '__host': '',
\   '__path': '',
\   '__fragment': '',
\}



" Methods

function! s:uri.scheme(...) dict "{{{
    if a:0
        let self.__scheme = a:1
    endif
    return self.__scheme
endfunction "}}}

function! s:uri.host(...) dict "{{{
    if a:0
        let self.__host = a:1
    endif
    return self.__host
endfunction "}}}

function! s:uri.path(...) dict "{{{
    if a:0
        let self.__path = a:1
    endif
    return self.__path
endfunction "}}}

function! s:uri.opaque(...) dict "{{{
    if a:0
        " TODO
    endif
    return printf('//%s%s', self.__host, self.__path)
endfunction "}}}

function! s:uri.fragment(...) dict "{{{
    if a:0
        let self.__fragment = a:1
    endif
    return self.__fragment
endfunction "}}}

function! s:uri.to_string() dict "{{{
    return printf(
    \   '%s://%s%s%s',
    \   self.__scheme,
    \   self.__host,
    \   self.__path,
    \   (self.__fragment != '' ? '#' . self.__fragment : ''),
    \)
endfunction "}}}


" }}}


function! s:new(str) "{{{
    let [scheme, host, path, fragment] = s:split_uri(a:str)
    return extend(deepcopy(s:uri), {'__scheme': scheme, '__host': host, '__path': path, '__fragment': fragment}, 'force')
endfunction "}}}

function! s:is_urilib_exception(str) "{{{
    return a:str =~# '^uri parse error:'
endfunction "}}}

" Parsing URI
function! s:split_uri(str) "{{{
    let rest = a:str
    let [scheme  , rest] = s:eat_scheme(rest)
    let [host    , rest] = s:eat_host(rest)
    if rest == ''
        " URI allows no slash after host? Is it correct?
        let path = ''
        let fragment = ''
    else
        let [path    , rest] = s:eat_path(rest)
        let [fragment, rest] = s:eat_fragment(rest)
    endif
    " FIXME: What should I do for `rest`?
    return [scheme, host, path, fragment]
endfunction "}}}
function! s:eat_em(str, pat, ...) "{{{
    let m = matchlist(a:str, a:pat)
    if empty(m)
        if a:0
            return [a:1, a:str]
        else
            throw 'uri parse error:' . printf("can't parse '%s' with '%s'.", a:str, a:pat)
        endif
    endif
    let [match, want] = m[0:1]
    let rest = strpart(a:str, strlen(match))
    return [want, rest]
endfunction "}}}
function! s:eat_scheme(str) "{{{
    return s:eat_em(a:str, '^\(\w\+\):'.'\C')
endfunction "}}}
function! s:eat_host(str) "{{{
    let for_file_scheme = '\/*'
    return s:eat_em(a:str, '^\/\/\('.for_file_scheme.'[^/]\+\)'.'\C')
endfunction "}}}
function! s:eat_path(str) "{{{
    return s:eat_em(a:str, '^\(\/[^#]*\)'.'\C')
endfunction "}}}
function! s:eat_fragment(str) "{{{
    return s:eat_em(a:str, '^#\(.*\)'.'\C', '')
endfunction "}}}




" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
