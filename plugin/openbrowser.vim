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


" Default values of global variables. "{{{

" FIXME: 'background' doesn't work now on neovim.
" https://github.com/tyru/open-browser.vim/issues/102
let s:background = has('nvim') ? 0 : 1

if g:__openbrowser_platform.cygwin
  if executable('cygstart')
    " Cygwin
    function! s:get_default_browser_commands()
      return [
      \   {'name': 'cygstart',
      \    'args': ['{browser}', '{uri}']}
      \]
    endfunction
  else
    " MSYS, MSYS2, ...
    function! s:get_default_browser_commands()
      return [
      \   {'name': 'rundll32',
      \    'args': 'rundll32 url.dll,FileProtocolHandler {use_vimproc ? uri : uri_noesc}'}
      \]
    endfunction
  endif
elseif g:__openbrowser_platform.macunix
  function! s:get_default_browser_commands()
    return [
    \   {'name': 'open',
    \    'args': ['{browser}', '{uri}'],
    \    'background': s:background}
    \]
  endfunction
elseif g:__openbrowser_platform.mswin
  function! s:get_default_browser_commands()
    return [
    \   {'name': 'rundll32',
    \    'args': 'rundll32 url.dll,FileProtocolHandler {use_vimproc ? uri : uri_noesc}'}
    \]
  endfunction
elseif g:__openbrowser_platform.unix
  function! s:get_default_browser_commands()
    if filereadable('/proc/version_signature') &&
    \ get(readfile('/proc/version_signature', 'b', 1), 0, '') =~# '^Microsoft'
      " Windows Subsystem for Linux (recent version's directory name is 'WINDOWS')
      for rundll32 in [
      \ '/mnt/c/WINDOWS/System32/rundll32.exe',
      \ '/mnt/c/Windows/System32/rundll32.exe',
      \]
        if executable(rundll32)
          return [
          \   {'name': 'rundll32',
          \    'cmd': rundll32,
          \    'args': rundll32 . ' url.dll,FileProtocolHandler {use_vimproc ? uri : uri_noesc}'}
          \]
        endif
      endfor
    endif
    return [
    \   {'name': 'xdg-open',
    \    'args': ['{browser}', '{uri}'],
    \    'background': s:background},
    \   {'name': 'x-www-browser',
    \    'args': ['{browser}', '{uri}'],
    \    'background': s:background},
    \   {'name': 'firefox',
    \    'args': ['{browser}', '{uri}'],
    \    'background': s:background},
    \   {'name': 'w3m',
    \    'args': ['{browser}', '{uri}'],
    \    'background': s:background},
    \]
  endfunction
endif

" Do not remove g:__openbrowser_platform for debug.
" unlet g:__openbrowser_platform

" }}}

" Global Variables {{{
function! s:valid_commands_and_rules()
  let open_commands = g:openbrowser_open_commands
  let open_rules    = g:openbrowser_open_rules
  if type(open_commands) isnot type([])
    return 0
  endif
  if type(open_rules) isnot type({})
    return 0
  endif
  for cmd in open_commands
    if !has_key(open_rules, cmd)
      return 0
    endif
  endfor
  return 1
endfunction
function! s:convert_commands_and_rules()
  let open_commands = g:openbrowser_open_commands
  let open_rules    = g:openbrowser_open_rules
  let browser_commands = []
  for cmd in open_commands
    call add(browser_commands,{
    \ 'name': cmd,
    \ 'args': open_rules[cmd]
    \})
  endfor
  return browser_commands
endfunction

if !exists('g:openbrowser_browser_commands')
  if exists('g:openbrowser_open_commands')
  \   && exists('g:openbrowser_open_rules')
  \   && s:valid_commands_and_rules()
    " Backward compatibility
    let g:openbrowser_browser_commands = s:convert_commands_and_rules()
  else
    let g:openbrowser_browser_commands = s:get_default_browser_commands()
  endif
endif
if !exists('g:openbrowser_fix_schemes')
  let g:openbrowser_fix_schemes = {
  \   'ttp': 'http',
  \   'ttps': 'https',
  \}
endif

let g:openbrowser_fix_hosts = get(g:, 'openbrowser_fix_hosts', {})
let g:openbrowser_fix_paths = get(g:, 'openbrowser_fix_paths', {})
let g:openbrowser_default_search = get(g:, 'openbrowser_default_search', 'google')

let g:openbrowser_search_engines = extend(
\   get(g:, 'openbrowser_search_engines', {}),
\   {
\       'alc': 'http://eow.alc.co.jp/{query}/UTF-8/',
\       'askubuntu': 'http://askubuntu.com/search?q={query}',
\       'baidu': 'http://www.baidu.com/s?wd={query}&rsv_bp=0&rsv_spt=3&inputT=2478',
\       'blekko': 'http://blekko.com/ws/+{query}',
\       'cpan': 'http://search.cpan.org/search?query={query}',
\       'devdocs': 'http://devdocs.io/#q={query}',
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
\       'fileformat': 'https://www.fileformat.info/info/unicode/char/{query}/',
\   },
\   'keep'
\)

let g:openbrowser_open_filepath_in_vim = get(g:, 'openbrowser_open_filepath_in_vim', 0)
let g:openbrowser_open_vim_command = get(g:, 'openbrowser_open_vim_command', 'vsplit')

let s:FORMAT_MESSAGE_DEFAULT = {
\   'msg': "opening '{uri}' ... {done ? 'done! ({command})' : ''}",
\   'truncate': 1,
\   'min_uri_len': 15,
\}
if !exists('g:openbrowser_format_message')
  let g:openbrowser_format_message = s:FORMAT_MESSAGE_DEFAULT
elseif type(g:openbrowser_format_message) is type("")
  " Backward-compatibility
  let s:msg = g:openbrowser_format_message
  unlet g:openbrowser_format_message
  let g:openbrowser_format_message = extend(
  \   s:FORMAT_MESSAGE_DEFAULT, {'msg': s:msg}, 'force')
else
  let g:openbrowser_format_message = extend(
  \   g:openbrowser_format_message, s:FORMAT_MESSAGE_DEFAULT, 'keep')
endif
unlet s:FORMAT_MESSAGE_DEFAULT

let g:openbrowser_message_verbosity = get(g:, 'openbrowser_message_verbosity', 2)

let g:openbrowser_use_vimproc = get(g:, 'openbrowser_use_vimproc', 1)
let g:openbrowser_force_foreground_after_open = get(g:, 'openbrowser_force_foreground_after_open', 0)
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
nnoremap <silent> <Plug>(openbrowser-open) :<C-u>call openbrowser#_keymapping_open('n')<CR>
xnoremap <silent> <Plug>(openbrowser-open) :<C-u>call openbrowser#_keymapping_open('v')<CR>
nnoremap <silent> <Plug>(openbrowser-search) :<C-u>call openbrowser#_keymapping_search('n')<CR>
xnoremap <silent> <Plug>(openbrowser-search) :<C-u>call openbrowser#_keymapping_search('v')<CR>
nnoremap <silent> <Plug>(openbrowser-smart-search) :<C-u>call openbrowser#_keymapping_smart_search('n')<CR>
xnoremap <silent> <Plug>(openbrowser-smart-search) :<C-u>call openbrowser#_keymapping_smart_search('v')<CR>


" Popup menus for Right-Click
if !get(g:, 'openbrowser_no_default_menus', (&guioptions =~# 'M'))
  function! s:add_menu() abort
    if get(g:, 'openbrowser_menu_lang',
    \      &langmenu !=# '' ? &langmenu : v:lang) =~# '^ja'
      runtime! lang/openbrowser_menu_ja.vim
    endif

    nnoremenu PopUp.-OpenBrowserSep- <Nop>
    xnoremenu PopUp.-OpenBrowserSep- <Nop>
    nmenu <silent> PopUp.Open\ URL <Plug>(openbrowser-open)
    xmenu <silent> PopUp.Open\ URL <Plug>(openbrowser-open)
    nmenu <silent> PopUp.Open\ Word(s) <Plug>(openbrowser-search)
    xmenu <silent> PopUp.Open\ Word(s) <Plug>(openbrowser-search)
    nmenu <silent> PopUp.Open\ URL\ or\ Word(s) <Plug>(openbrowser-smart-search)
    xmenu <silent> PopUp.Open\ URL\ or\ Word(s) <Plug>(openbrowser-smart-search)
  endfunction

  augroup openbrowser-menu
    autocmd!
    autocmd GUIEnter * call s:add_menu()
  augroup END
endif

" }}}


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
