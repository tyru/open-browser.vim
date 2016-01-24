scriptencoding utf-8

let s:suite = themis#suite('basic')
let s:assert = themis#suite('assert')

function! s:suite.system_linux()
    if !executable('xdg-open')
        call s:assert.skip()
    endif
    let save_use_vimproc = g:openbrowser_use_vimproc
    let g:openbrowser_use_vimproc = 0
    let save_browser_commands = g:openbrowser_browser_commands
    let g:openbrowser_browser_commands = [
    \   {'background': 1, 'name': 'xdg-open', 'args': ['{browser}', '{uri}']}
    \]
    let options = {'use_vimproc': 0, 'background': 1}
    try
        call vmock#mock('openbrowser#__system__')
        \.with(['xdg-open', 'http://example.com/'], options)
        \.return(0).once()
        call openbrowser#open('http://example.com/')
        call vmock#verify()
    catch
        echoerr v:exception
    finally
        call vmock#clear()
        let g:openbrowser_use_vimproc = save_use_vimproc
    endtry
endfunction

function! s:suite.openbrowser_linux()
    if !executable('xdg-open')
        call s:assert.skip()
    endif
    let save_use_vimproc = g:openbrowser_use_vimproc
    let g:openbrowser_use_vimproc = 0
    let save_browser_commands = g:openbrowser_browser_commands
    let g:openbrowser_browser_commands = [
    \   {'background': 1, 'name': 'xdg-open', 'args': ['{browser}', '{uri}']}
    \]
    let options = {'use_vimproc': 0, 'background': 1}
    try
        call vmock#mock('openbrowser#__open_browser__')
        \.with('http://example.com/')
        \.return('').once()
        call openbrowser#open('http://example.com/')
        call vmock#verify()
    catch
        echoerr v:exception
    finally
        call vmock#clear()
        let g:openbrowser_use_vimproc = save_use_vimproc
    endtry
endfunction
