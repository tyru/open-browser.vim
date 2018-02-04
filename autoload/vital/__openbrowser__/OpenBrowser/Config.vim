" vim:foldmethod=marker:fen:
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

function! s:new_global_var_source(prefix) abort
  return {
  \ 'prefix': a:prefix,
  \ 'get': function('s:Config_get'),
  \}
endfunction

function! s:Config_get(key) abort dict
  let name = self.prefix . a:key
  for ns in [b:, w:, t:, g:]
    if has_key(ns, name)
      return ns[name]
    endif
  endfor
  throw 'openbrowser: internal error: '
  \   . "s:get_var() couldn't find variable '" . name . "'."
endfunction


let &cpo = s:save_cpo
