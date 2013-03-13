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


let s:is_unix = has('unix')
let s:is_mswin = has('win16') || has('win32') || has('win64')
let s:is_cygwin = has('win32unix')
let s:is_macunix = !s:is_mswin && !s:is_cygwin && (has('mac') || has('macunix') || has('gui_macvim') || (!executable('xdg-open') && system('uname') =~? '^darwin'))
lockvar s:is_unix
lockvar s:is_mswin
lockvar s:is_cygwin
lockvar s:is_macunix

if !(s:is_unix || s:is_mswin || s:is_cygwin || s:is_macunix)
    echohl WarningMsg
    echomsg 'Your platform is not supported!'
    echohl None
    finish
endif

" Save booleans for autoload/openbrowser.vim
let g:__openbrowser_platform = {
\   'unix': s:is_unix,
\   'mswin': s:is_mswin,
\   'cygwin': s:is_cygwin,
\   'macunix': s:is_macunix,
\}

" Global Variables {{{
let g:openbrowser_search_engines = extend(
\   get(g:, 'openbrowser_search_engines', {}),
\   {
\       'alc': 'http://eow.alc.co.jp/{query}/UTF-8/',
\       'askubuntu': 'http://askubuntu.com/search?q={query}',
\       'baidu': 'http://www.baidu.com/s?wd={query}&rsv_bp=0&rsv_spt=3&inputT=2478',
\       'blekko': 'http://blekko.com/ws/+{query}',
\       'cpan': 'http://search.cpan.org/search?query={query}',
\       'duckduckgo': 'http://duckduckgo.com/?q={query}',
\       'github': 'http://github.com/search?q={query}',
\       'google': 'http://google.com/search?q={query}',
\       'google-code': 'http://code.google.com/intl/en/query/#q={query}',
\       'php': 'http://php.net/{query}',
\       'python': 'http://docs.python.org/dev/search.html?q={query}&check_keywords=yes&area=default',
\       'twitter-search': 'http://twitter.com/search/{query}',
\       'twitter-user': 'http://twitter.com/{query}',
\       'verycd': 'http://www.verycd.com/search/entries/{query}',
\       'vim': 'http://www.google.com/cse?cx=partner-pub-3005259998294962%3Abvyni59kjr1&ie=ISO-8859-1&q={query}&sa=Search&siteurl=www.vim.org%2F#gsc.tab=0&gsc.q={query}&gsc.page=1',
\       'wikipedia': 'http://en.wikipedia.org/wiki/{query}',
\       'wikipedia-ja': 'http://ja.wikipedia.org/wiki/{query}',
\       'yahoo': 'http://search.yahoo.com/search?p={query}',
\   },
\   'keep'
\)

" }}}


" Interfaces {{{

" For backward compatibility,
" - OpenBrowser()
" - OpenBrowserSearch()

" Open URL with `g:openbrowser_open_commands`.
function! OpenBrowser(...) "{{{
    return call('openbrowser#open', a:000)
endfunction "}}}

function! OpenBrowserSearch(...) "{{{
    return call('openbrowser#search', a:000)
endfunction "}}}



" Ex command
command!
\   -nargs=+
\   OpenBrowser
\   call openbrowser#open(<q-args>)
command!
\   -nargs=+ -complete=customlist,openbrowser#_cmd_complete
\   OpenBrowserSearch
\   call openbrowser#_cmd_open_browser_search(<q-args>)
command!
\   -nargs=+ -complete=customlist,openbrowser#_cmd_complete
\   OpenBrowserSmartSearch
\   call openbrowser#_cmd_open_browser_smart_search(<q-args>)



" Key-mapping
nnoremap <Plug>(openbrowser-open) :<C-u>call openbrowser#_keymapping_open('n')<CR>
vnoremap <Plug>(openbrowser-open) :<C-u>call openbrowser#_keymapping_open('v')<CR>
nnoremap <Plug>(openbrowser-search) :<C-u>call openbrowser#_keymapping_search('n')<CR>
vnoremap <Plug>(openbrowser-search) :<C-u>call openbrowser#_keymapping_search('v')<CR>
nnoremap <Plug>(openbrowser-smart-search) :<C-u>call openbrowser#_keymapping_smart_search('n')<CR>
vnoremap <Plug>(openbrowser-smart-search) :<C-u>call openbrowser#_keymapping_smart_search('v')<CR>

" }}}


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
