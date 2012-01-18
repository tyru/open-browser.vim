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

let g:urilib#version = str2nr(printf('%02d%02d%03d', 0, 1, 0))



" Autoload Functions {{{

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

function! s:is_urilib_exception(str) "{{{
    return a:str =~# '^uri parse error:'
endfunction "}}}

function! urilib#new(uri, ...) "{{{
    let nothrow = a:0 != 0
    let NothrowValue = a:0 ? a:1 : 'unused'
    return s:sandbox_call(
    \   's:new', [a:uri], nothrow, NothrowValue)
endfunction "}}}

function! urilib#new_from_uri_like_string(str, ...) "{{{
    let str = a:str
    if str !~# s:RX_SCHEME    " no scheme.
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
        if a:str[i] =~# '^[A-Za-z0-9._~"-]$'
            let escaped .= a:str[i]
        else
            let escaped .= printf("%%%02X", char2nr(a:str[i]))
        endif
    endfor
    return escaped
endfunction "}}}

" from Vital.Web.Http.unescape()
function! urilib#uri_unescape(str)
  let ret = a:str
  let ret = substitute(ret, '+', ' ', 'g')
  let ret = substitute(ret, '%\(\x\x\)', '\=nr2char("0x".submatch(1))', 'g')
  return ret
endfunction

" }}}

" URI Object {{{

function! s:new(str) "{{{
    let result = s:parse_uri(a:str)
    let result.path = join(
    \   map(split(result.path, '/', 1), 'urilib#uri_escape(v:val)'),
    \   '/'
    \)
    " TODO: Support punycode
    " let result.host = ...

    let obj = deepcopy(s:uri)
    for [where, value] in items(result)
        call s:validate_{where}(value)         " Validate the value.
        call call(obj[where], [value], obj)    " Set the value.
    endfor

    return obj
endfunction "}}}

function! s:uri_scheme(...) dict "{{{
    if a:0 && s:is_scheme(a:1)
        let self.__scheme = a:1
    endif
    return self.__scheme
endfunction "}}}

function! s:uri_host(...) dict "{{{
    if a:0 && s:is_host(a:1)
        let self.__host = a:1
    endif
    return self.__host
endfunction "}}}

function! s:uri_port(...) dict "{{{
    if a:0 && s:is_port(a:1)
        let self.__port = a:1
    endif
    return self.__port
endfunction "}}}

function! s:uri_path(...) dict "{{{
    if a:0
        " NOTE: self.__path must not have "/" as prefix.
        let path = substitute(a:1, '^/\+', '', '')
        if s:is_path(path)
            let self.__path = path
        endif
    endif
    return "/" . self.__path
endfunction "}}}

function! s:uri_opaque(...) dict "{{{
    if a:0
        " TODO
        throw 'urilib: uri.opaque(value) does not support yet.'
    endif
    return printf('//%s%s/%s',
    \           self.__host,
    \           (self.__port !=# '' ? ':' . self.__port : ''),
    \           self.__path)
endfunction "}}}

function! s:uri_fragment(...) dict "{{{
    if a:0
        " NOTE: self.__fragment must not have "#" as prefix.
        let fragment = substitute(a:1, '^#', '', '')
        if s:is_fragment(fragment)
            let self.__fragment = fragment
        endif
    endif
    return self.__fragment
endfunction "}}}

function! s:uri_query(...) dict "{{{
    if a:0
        " NOTE: self.__query must not have "?" as prefix.
        let query = substitute(a:1, '^?', '', '')
        if s:is_query(query)
            let self.__query = query
        endif
    endif
    return self.__query
endfunction "}}}

function! s:uri_to_iri() dict "{{{
    " Same as uri.to_string(), but do unescape for self.__path.
    return printf(
    \   '%s://%s%s/%s%s%s',
    \   self.__scheme,
    \   self.__host,
    \   (self.__port !=# '' ? ':' . self.__port : ''),
    \   urilib#uri_unescape(self.__path),
    \   (self.__query != '' ? '?' . self.__query : ''),
    \   (self.__fragment != '' ? '#' . self.__fragment : ''),
    \)
endfunction "}}}

function! s:uri_to_string() dict "{{{
    return printf(
    \   '%s://%s%s/%s%s%s',
    \   self.__scheme,
    \   self.__host,
    \   (self.__port !=# '' ? ':' . self.__port : ''),
    \   self.__path,
    \   (self.__query != '' ? '?' . self.__query : ''),
    \   (self.__fragment != '' ? '#' . self.__fragment : ''),
    \)
endfunction "}}}



function! s:local_func(name) "{{{
    let sid = matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_local_func$')
    return function('<SNR>' . sid . '_' . a:name)
endfunction "}}}

let s:uri = {
\   '__scheme': '',
\   '__host': '',
\   '__port': '',
\   '__path': '',
\   '__query': '',
\   '__fragment': '',
\
\   'scheme': s:local_func('uri_scheme'),
\   'host': s:local_func('uri_host'),
\   'port': s:local_func('uri_port'),
\   'path': s:local_func('uri_path'),
\   'opaque': s:local_func('uri_opaque'),
\   'query': s:local_func('uri_query'),
\   'fragment': s:local_func('uri_fragment'),
\   'to_iri': s:local_func('uri_to_iri'),
\   'to_string': s:local_func('uri_to_string'),
\}
" }}}

" Parsing Functions {{{

function! s:parse_uri(str) "{{{
    let rest = a:str

    " Ignore leading/trailing whitespaces.
    let rest = substitute(rest, '^\s\+', '', '')
    let rest = substitute(rest, '\s\+$', '', '')

    " URI = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
    " hier-part = "//" authority path-abempty
    "           / path-absolute
    "           / path-rootless
    "           / path-empty
    " authority = [ userinfo "@" ] host [ ":" port ]

    " scheme
    let [scheme, rest] = s:eat_scheme(rest)

    let [_, rest] = s:eat_em(rest, '^://')

    " TODO: userinfo

    " host
    let [host, rest] = s:eat_host(rest)

    " port
    if rest[0] ==# ':'
        let [port, rest] = s:eat_port(rest[1:])
    else
        let port = ''
    endif

    " path (string after authority in hier-part)
    let [path, rest] = s:eat_path(rest)

    " query
    if rest[0] ==# '?'
        let [query, rest] = s:eat_query(rest[1:])
    else
        let query = ''
    endif

    " fragment
    if rest[0] ==# '#'
        let [fragment, rest] = s:eat_fragment(rest[1:])
    else
        let fragment = ''
    endif

    if rest != ''
        throw 'uri parse error: unnecessary string at the end.'
    endif

    return {
    \   'scheme': scheme,
    \   'host': host,
    \   'port': port,
    \   'path': path,
    \   'query': query,
    \   'fragment': fragment,
    \}
endfunction "}}}
function! s:eat_em(str, pat) "{{{
    let pat = a:pat.'\C'
    let m = matchlist(a:str, pat)
    if empty(m)
        throw 'uri parse error: '
        \   . printf("can't parse '%s' with '%s'.", a:str, pat)
    endif
    let [match, want] = m[0:1]
    let rest = strpart(a:str, strlen(match))
    return [want, rest]
endfunction "}}}


" Patterns for URI syntax {{{
"
" The main parts of URLs
"   http://tools.ietf.org/html/rfc1738#section-2.1
" BNF for specific URL schemes
"   http://tools.ietf.org/html/rfc1738#section-5
" Collected ABNF for URI
"   http://tools.ietf.org/html/rfc3986#appendix-A
" Parsing a URI Reference with a Regular Expression
" NOTE: Using this regexp pattern in urilib.vim
"   http://tools.ietf.org/html/rfc3986#appendix-B

let s:RX_SCHEME   = '^\([^:/?#]\+\)'
let s:RX_HOST     = '^\([^/?#]*\)'
let s:RX_PORT     = '^\(\d*\)'
let s:RX_PATH     = '^\([^?#]*\)'
let s:RX_QUERY    = '^\([^#]*\)'
let s:RX_FRAGMENT = '^\(.*\)'
" }}}

" FIXME: make error messages user-friendly.
let s:FUNCTION_DESCS = {
\   'scheme': 'uri parse error: all characters'
\           . ' in scheme must be [a-z].',
\   'host': 'uri parse error: all characters'
\         . ' in host must be [\x00-\xff].',
\   'port': 'uri parse error: all characters'
\         . ' in port must be digit and the number'
\         . ' is greater than 0.',
\   'path': 'uri parse error: all characters'
\         . ' in path must be [\x00-\xff].',
\   'query': 'uri parse error: all characters'
\         . ' in query must be [\x00-\xff].',
\   'fragment': 'uri parse error: all characters'
\             . ' in fragment must be [\x00-\xff].',
\}

" Create s:eat_*() functions.
function! s:create_eat_functions()
    for where in keys(s:FUNCTION_DESCS)
        execute join([
        \   'function! s:eat_'.where.'(str)',
        \       'return s:eat_em(a:str, s:RX_'.toupper(where).')',
        \   'endfunction',
        \], "\n")
    endfor
endfunction
call s:create_eat_functions()

" Create s:is_*() functions.
function! s:has_error(func, args)
    try
        call call(a:func, a:args)
        return 0
    catch
        return 1
    endtry
endfunction
function! s:create_check_functions()
    for where in keys(s:FUNCTION_DESCS)
        execute join([
        \   'function! s:is_'.where.'(str)',
        \       'return !s:has_error("s:eat_'.where.'", [a:str])',
        \   'endfunction',
        \], "\n")
    endfor
endfunction
call s:create_check_functions()

" Create s:validate_*() functions.
function! s:create_validate_functions()
    for [where, msg] in items(s:FUNCTION_DESCS)
        execute join([
        \   'function! s:validate_'.where.'(str)',
        \       'if !s:is_'.where.'(a:str)',
        \           'throw '.string(msg),
        \       'endif',
        \   'endfunction',
        \], "\n")
    endfor
endfunction
call s:create_validate_functions()

" }}}



" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
