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

    let uri = urilib#new('http://d.hatena.ne.jp/tyru/20100619/git_push_vim_plugins_to_github#c')
    Is uri.scheme(), 'http'
    Is uri.host(), 'd.hatena.ne.jp'
    Is uri.path(), '/tyru/20100619/git_push_vim_plugins_to_github'
    Is uri.opaque(), '//d.hatena.ne.jp/tyru/20100619/git_push_vim_plugins_to_github'
    Is uri.fragment(), 'c'
endfunction

call s:run()
Done


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
