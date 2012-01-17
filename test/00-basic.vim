" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}



function! s:run()
    let uri = urilib#new('http://twitter.com/tyru')
    Is uri.scheme(), 'http'
    Is uri.host(), 'twitter.com'
    Is uri.path(), '/tyru'
    Is uri.opaque(), '//twitter.com/tyru'
    Is uri.fragment(), ''
    Is uri.to_string(), 'http://twitter.com/tyru'

    call uri.scheme('ftp')
    Is uri.scheme(), 'ftp'
    Is uri.to_string(), 'ftp://twitter.com/tyru'
    call uri.host('ftp.vim.org')
    Is uri.host(), 'ftp.vim.org'
    Is uri.to_string(), 'ftp://ftp.vim.org/tyru'
    call uri.path('pub/vim/unix/vim-7.3.tar.bz2')
    Is uri.path(), '/pub/vim/unix/vim-7.3.tar.bz2'
    Is uri.to_string(), 'ftp://ftp.vim.org/pub/vim/unix/vim-7.3.tar.bz2'
    call uri.path('/pub/vim/unix/vim-7.3.tar.bz2')
    Is uri.path(), '/pub/vim/unix/vim-7.3.tar.bz2', 'uri.path(): ignore head slashes.'
    Is uri.to_string(), 'ftp://ftp.vim.org/pub/vim/unix/vim-7.3.tar.bz2', 'uri.path({path}): ignore head slashes.'


    let uri = urilib#new('http://d.hatena.ne.jp/tyru/20100619/git_push_vim_plugins_to_github#c')
    Is uri.scheme(), 'http'
    Is uri.host(), 'd.hatena.ne.jp'
    Is uri.path(), '/tyru/20100619/git_push_vim_plugins_to_github'
    Is uri.opaque(), '//d.hatena.ne.jp/tyru/20100619/git_push_vim_plugins_to_github'
    Is uri.fragment(), 'c'
    Is uri.to_string(), 'http://d.hatena.ne.jp/tyru/20100619/git_push_vim_plugins_to_github#c'

    call uri.scheme('https')
    Is uri.scheme(), 'https'
    Is uri.to_string(), 'https://d.hatena.ne.jp/tyru/20100619/git_push_vim_plugins_to_github#c'
    call uri.host('github.com')
    Is uri.host(), 'github.com'
    Is uri.to_string(), 'https://github.com/tyru/20100619/git_push_vim_plugins_to_github#c'
    call uri.path('tyru/urilib.vim/blob/master/autoload/urilib.vim')
    Is uri.path(), '/tyru/urilib.vim/blob/master/autoload/urilib.vim'
    Is uri.to_string(), 'https://github.com/tyru/urilib.vim/blob/master/autoload/urilib.vim#c'
    call uri.fragment('L32')
    Is uri.fragment(), 'L32'
    Is uri.to_string(), 'https://github.com/tyru/urilib.vim/blob/master/autoload/urilib.vim#L32'
    call uri.fragment('#L32')
    Is uri.fragment(), 'L32', 'uri.fragment({fragment}): ignore head # characters.'
    Is uri.to_string(), 'https://github.com/tyru/urilib.vim/blob/master/autoload/urilib.vim#L32', 'uri.fragment({fragment}): ignore head # characters.'


    OK urilib#is_uri('http://twitter.com/tyru')
    OK urilib#is_uri('http://d.hatena.ne.jp/tyru/20100619/git_push_vim_plugins_to_github#c')
    OK ! urilib#is_uri('foo')
    OK ! urilib#is_uri('/bar')
    OK urilib#is_uri('file://baz/')
    OK urilib#is_uri('file:///home/tyru/')
    OK urilib#is_uri('file:///home/tyru')
    OK urilib#is_uri('ftp://withoutslash.com')
endfunction

call s:run()
Done


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
