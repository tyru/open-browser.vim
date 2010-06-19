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
" Change Log {{{
" }}}
" Document {{{
"
" Name: openbrowser
" Version: 0.0.0
" Author:  tyru <tyru.exe@gmail.com>
" Last Change: 2010-06-20.
"
" Description:
"   Simple plugin to open URL with your favorite browser
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

let s:is_urilib_installed = exists('*urilib#new')
" }}}

" Check your platform {{{
if !(s:is_unix || s:is_mswin || s:is_cygwin || s:is_macunix)
    echoerr 'Your platform is not supported!'
    finish
endif
" }}}

" Get default open commands. "{{{
if s:is_cygwin
    function! s:get_default_open_commands()
        return ['cygstart']
    endfunction
elseif s:is_macunix
    function! s:get_default_open_commands()
        return ['open']
    endfunction
elseif s:is_unix
    function! s:get_default_open_commands()
        return ['xdg-open', 'x-www-browser', 'firefox', 'w3m']
    endfunction
elseif s:is_mswin
    function! s:get_default_open_commands()
        return ['start']
    endfunction
endif
" }}}

" Global Variables {{{
if !exists('g:openbrowser_open_commands')
    let g:openbrowser_open_commands = s:get_default_open_commands()
endif
if !exists('g:openbrowser_fix_schemes')
    let g:openbrowser_fix_schemes = {'ttp': 'http'}
endif
if !exists('g:openbrowser_isfname')
    let g:openbrowser_isfname = &isfname
endif
" }}}

" Functions {{{

" Open URL with `g:openbrowser_open_commands`.
function! OpenBrowser(uri) "{{{
    for browser in g:openbrowser_open_commands
        " NOTE: On MS Windows, 'start' command is not executable.
        if !executable(browser) && (s:is_mswin && browser !=# 'start' && !executable(browser))
            continue
        endif

        if s:is_urilib_installed
            let uri = urilib#new(a:uri, -1)
            if type(uri) != type(-1)
                let uri.scheme = get(g:openbrowser_fix_schemes, uri.scheme, uri.scheme)
                let uri_str = uri.to_string()
            else
                let uri_str = a:uri
            endif
        else
            let uri_str = a:uri
        endif

        if s:is_mswin
            call system(printf('%s %s %s %s', &shell, &shellcmdflag, browser, uri_str))
        else
            call system(browser . ' ' . shellescape(uri_str))
        endif

        let success = 0
        if v:shell_error ==# success
            return
        else
            echoerr printf("Can't open url with '%s': %s", browser, uri_str)
            return
        endif
    endfor
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
    let save_isfname = &isfname
    let &isfname = g:openbrowser_isfname
    try
        return expand('<cfile>')
    finally
        let &isfname = save_isfname
    endtry
endfunction "}}}

" }}}

" Interfaces {{{

" Ex command
command!
\   -bar -nargs=+ -complete=file
\   OpenBrowser
\   call OpenBrowser(<q-args>)

" Key-mapping
nnoremap <Plug>(openbrowser-open) :<C-u>call OpenBrowser(<SID>get_url_on_cursor())<CR>
vnoremap <Plug>(openbrowser-open) :<C-u>call OpenBrowser(<SID>get_selected_text())<CR>
" TODO operator
" noremap <Plug>(openbrowser-op-open)

" }}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
