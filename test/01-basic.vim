scriptencoding utf-8

let s:suite = themis#suite('basic')
let s:assert = themis#suite('assert')


function! s:suite.system_linux() abort
    if !executable('xdg-open')
        call s:assert.skip()
    endif
    let use_vimproc = 0
    let background = 1
    call s:system_once({
    \   'browser_commands': [
    \       {'background': background, 'name': 'xdg-open',
    \        'args': ['{browser}', '{uri}']}
    \   ],
    \   'use_vimproc': use_vimproc,
    \   'input': 'http://example.com/',
    \   'args': [['xdg-open', 'http://example.com/'], {
    \      'use_vimproc': use_vimproc,
    \      'background': background
    \   }],
    \   'return': 0,
    \})
endfunction

function! s:suite.openbrowser_linux() abort
    if !executable('xdg-open')
        call s:assert.skip()
    endif
    let use_vimproc = 0
    let background = 1
    call s:openbrowser_once({
    \   'browser_commands': [
    \       {'background': background, 'name': 'xdg-open',
    \        'args': ['{browser}', '{uri}']}
    \   ],
    \   'use_vimproc': use_vimproc,
    \   'input': 'http://example.com/',
    \   'args': ['http://example.com/'],
    \   'return': '',
    \})
endfunction



function! s:system_once(param) abort
    let save_use_vimproc = g:openbrowser_use_vimproc
    let g:openbrowser_use_vimproc = a:param.use_vimproc
    let save_browser_commands = g:openbrowser_browser_commands
    let g:openbrowser_browser_commands = a:param.browser_commands
    try
        let mock = vmock#mock('openbrowser#__system__')
        call call(mock.with, a:param.args, mock)
        call mock.return(a:param.return).once()

        call openbrowser#open(a:param.input)
        call vmock#verify()
    catch
        echoerr v:exception
    finally
        call vmock#clear()
        let g:openbrowser_use_vimproc = save_use_vimproc
        let g:openbrowser_browser_commands = save_browser_commands
    endtry
endfunction

function! s:openbrowser_once(param) abort
    let save_use_vimproc = g:openbrowser_use_vimproc
    let g:openbrowser_use_vimproc = a:param.use_vimproc
    let save_browser_commands = g:openbrowser_browser_commands
    let g:openbrowser_browser_commands = a:param.browser_commands
    try
        let mock = vmock#mock('openbrowser#__open_browser__')
        call call(mock.with, a:param.args, mock)
        call mock.return(a:param.return).once()

        call openbrowser#open('http://example.com/')
        call vmock#verify()
    catch
        echoerr v:exception
    finally
        call vmock#clear()
        let g:openbrowser_use_vimproc = save_use_vimproc
    endtry
endfunction
