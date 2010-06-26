" vim:foldmethod=marker:fen:
scriptencoding utf-8

" NEW BSD LICENSE {{{
"   Copyright (c) 2009, tyru
"   All rights reserved.
"
"   Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
"
"       * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
"       * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
"       * Neither the name of the tyru nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
"
"   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
" }}}
" Change Log: {{{
" }}}
" Document {{{
"
" Name: urilib
" Version: 0.0.0
" Author:  tyru <tyru.exe@gmail.com>
" Last Change: 2010-06-26.
"
" Description:
"   NO DESCRIPTION YET
"
" Usage: {{{
"   Commands: {{{
"   }}}
"   Mappings: {{{
"   }}}
"   Global Variables: {{{
"   }}}
" }}}
" }}}

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



function! urilib#new(str, ...) "{{{
    try
        return s:new(a:str)
    catch
        if a:0 && s:is_urilib_exception(v:exception)
            return a:1
        else
            throw substitute(v:exception, '^Vim([^()]\+):', '', '')
        endif
    endtry
endfunction "}}}

function! urilib#is_uri(str) "{{{
    try
        call urilib#new(a:str)
        return 1
    catch
        if s:is_urilib_exception(v:exception)
            return 0
        else
            throw substitute(v:exception, '^Vim([^()]\+):', '', '')
        endif
    endtry
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

let s:uri.is_uri = function('urilib#is_uri')



lockvar s:uri
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
    let [path    , rest] = s:eat_path(rest)
    let [fragment, rest] = s:eat_fragment(rest)
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
    return s:eat_em(a:str, '^\/\/\([^/]\+\)'.'\C')
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
