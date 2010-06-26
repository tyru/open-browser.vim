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

let s:is_urilib_installed = exists('*urilib#new')
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
        return ['start']
    endfunction
    function! s:get_default_open_rules()
        return {'start': '&shell &shellcmdflag {browser} {uri}'}
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
                call uri.scheme(get(g:openbrowser_fix_schemes, uri.scheme(), uri.scheme()))
                call uri.host  (get(g:openbrowser_fix_hosts, uri.host(), uri.host()))
                call uri.path  (get(g:openbrowser_fix_paths, uri.path(), uri.path()))
                let uri_str = uri.to_string()
            else
                let uri_str = a:uri
            endif
        else
            let uri_str = a:uri
        endif

        if !has_key(g:openbrowser_open_rules, browser)
            continue
        endif

        call system(s:expand_keyword(g:openbrowser_open_rules[browser], browser, uri_str))

        let success = 0
        if v:shell_error ==# success
            return
        endif
    endfor

    echohl WarningMsg
    echomsg printf("open-browser doesn't know how to open '%s'.", a:uri)
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
    let save_isfname = &isfname
    let &isfname = g:openbrowser_isfname
    try
        return expand('<cfile>')
    finally
        let &isfname = save_isfname
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
function! s:expand_keyword(str, browser, uri)  " {{{
  if type(a:str) != type('')
    return ''
  endif
  let i = 0
  let rest = a:str
  let result = ''

  " Assign these variables for eval().
  let browser = a:browser
  let uri = a:uri

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

" Key-mapping
nnoremap <Plug>(openbrowser-open) :<C-u>call OpenBrowser(<SID>get_url_on_cursor())<CR>
vnoremap <Plug>(openbrowser-open) :<C-u>call OpenBrowser(<SID>get_selected_text())<CR>
" TODO operator
" noremap <Plug>(openbrowser-op-open)

" }}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
