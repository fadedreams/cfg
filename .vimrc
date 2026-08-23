" :PlugInstall manually if auto install did not worked
" ── Auto-install vim-plug ─────────────────────────────────────
let s:plug_file = expand('~/.vim/autoload/plug.vim')
let s:plug_url  = 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

if empty(glob(s:plug_file))
  echo "Installing vim-plug..."
  execute 'silent !curl -fLo ' . s:plug_file . ' --create-dirs ' . s:plug_url
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" ── Verify vim-plug loaded correctly ──────────────────────────
if !filereadable(s:plug_file)
  echohl WarningMsg
  echo "[vimrc] vim-plug not found — retrying download..."
  echohl None
  execute 'silent !curl -fLo ' . s:plug_file . ' --create-dirs ' . s:plug_url . ' 2>/dev/null'
endif

" ── Install fzf / ripgrep / fd (cross-distro) ────────────────
function! s:InstallFzfDeps()
  let l:missing = []

  if !executable('fzf')      | call add(l:missing, 'fzf')      | endif
  if !executable('rg')       | call add(l:missing, 'rg')        | endif
  if !executable('fd') && !executable('fdfind')
    call add(l:missing, 'fd')
  endif

  if empty(l:missing) | return | endif

  echo '[deps] Missing: ' . join(l:missing, ', ') . ' — installing...'

  if executable('apt-get')
    let l:pkgs = []
    for tool in l:missing
      call add(l:pkgs, tool ==# 'fd' ? 'fd-find' :
            \           tool ==# 'rg' ? 'ripgrep' : tool)
    endfor
    execute 'silent !sudo apt-get install -y ' . join(l:pkgs, ' ')

  elseif executable('pacman')
    let l:pkgs = []
    for tool in l:missing
      call add(l:pkgs, tool ==# 'fd' ? 'fd' :
            \           tool ==# 'rg' ? 'ripgrep' : tool)
    endfor
    execute 'silent !sudo pacman -S --noconfirm ' . join(l:pkgs, ' ')

  elseif executable('dnf')
    let l:pkgs = []
    for tool in l:missing
      call add(l:pkgs, tool ==# 'fd' ? 'fd-find' :
            \           tool ==# 'rg' ? 'ripgrep' : tool)
    endfor
    execute 'silent !sudo dnf install -y ' . join(l:pkgs, ' ')

  elseif executable('yum')
    let l:pkgs = []
    for tool in l:missing
      call add(l:pkgs, tool ==# 'fd' ? 'fd-find' :
            \           tool ==# 'rg' ? 'ripgrep' : tool)
    endfor
    execute 'silent !sudo yum install -y ' . join(l:pkgs, ' ')

  elseif executable('zypper')
    let l:pkgs = []
    for tool in l:missing
      call add(l:pkgs, tool ==# 'fd' ? 'fd' :
            \           tool ==# 'rg' ? 'ripgrep' : tool)
    endfor
    execute 'silent !sudo zypper install -y ' . join(l:pkgs, ' ')

  elseif executable('apk')
    let l:pkgs = []
    for tool in l:missing
      call add(l:pkgs, tool ==# 'fd' ? 'fd' :
            \           tool ==# 'rg' ? 'ripgrep' : tool)
    endfor
    execute 'silent !sudo apk add ' . join(l:pkgs, ' ')

  elseif executable('brew')
    let l:pkgs = []
    for tool in l:missing
      call add(l:pkgs, tool ==# 'fd' ? 'fd' :
            \           tool ==# 'rg' ? 'ripgrep' : tool)
    endfor
    execute 'silent !brew install ' . join(l:pkgs, ' ')

  else
    echohl WarningMsg
    echo '[deps] No supported package manager found. Install manually: ' . join(l:missing, ' ')
    echohl None
    return
  endif

  echo '[deps] Done. Restart Vim if fzf keymaps seem broken.'
endfunction

" fd compat: Debian/Ubuntu install it as fdfind
if !executable('fd') && executable('fdfind')
  let $FD = 'fdfind'
else
  let $FD = 'fd'
endif

call s:InstallFzfDeps()


" ══════════════════════════════════════════════════════════════
"  .vimrc
" ══════════════════════════════════════════════════════════════

" ── Plugins (vim-plug) ────────────────────────────────────────
silent! call plug#begin('~/.vim/plugged')
  Plug 'tpope/vim-commentary'       " gcc = toggle line comment, gc = comment motion
  Plug 'tpope/vim-surround'         " cs\"' / ds( / ysiw[ — surround text objects
  Plug 'tpope/vim-repeat'           " makes . work with surround, commentary, etc.
  Plug 'tpope/vim-eunuch'           " file ops on current buffer:
                                    "   :Rename newname.js
                                    "   :Move ../other/path.js   (change dir + name)
                                    "   :Copy ../other/copy.js
                                    "   :Delete                  (deletes file + wipes buffer)
                                    "   :Mkdir subfolder/nested  (creates intermediate dirs)
                                    "   :SudoWrite               (save file opened without sudo)
  Plug 'jiangmiao/auto-pairs'       " auto-close (), [], {}, \"\"
  Plug 'mbbill/undotree'            " visualise undofile history  (<leader>u)
  " Plug 'ghifarit53/tokyonight-vim'  " tokyonight colorscheme
  Plug 'luochen1990/rainbow'        " rainbow parentheses/brackets/braces
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
call plug#end()

" ── Colorscheme ───────────────────────────────────────────────
" set t_Co=256
silent! colorscheme habamax
" let g:tokyonight_style  = 'night'
" let g:tokyonight_enable_italic = 1
" if !empty(glob('~/.vim/plugged/tokyonight-vim/colors/tokyonight.vim'))
"   silent! colorscheme tokyonight
" endif

" ── Rainbow Parentheses ───────────────────────────────────────
let g:rainbow_active = 1              " 1 = always on  |  :RainbowToggle to flip
let g:rainbow_conf = {
  \   'guifgs': ['#e06c75', '#e5c07b', '#98c379', '#56b6c2', '#61afef', '#c678dd'],
  \   'ctermfgs': ['lightblue', 'lightyellow', 'lightcyan', 'lightmagenta'],
  \ }


" ── Clipboard ─────────────────────────────────────────────────
set clipboard=unnamedplus

noremap <Leader>y "+y
noremap <Leader>Y "+Y
noremap <Leader>p "+p
noremap <Leader>P "+P
nnoremap <silent> <localleader>' :registers<cr>
" Search for visually selected text (Ctrl+f)
vnoremap <silent> <C-f> y/\V<C-r>=escape(@", '/\')<CR><CR>

" ── Appearance ────────────────────────────────────────────────
set number
set relativenumber
set cursorline
set laststatus=2
set showmode
set showcmd
set signcolumn=yes
set termguicolors


" ── Editing ───────────────────────────────────────────────────
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set smartindent
set breakindent
set backspace=indent,eol,start
set nojoinspaces
set virtualedit=block

" ── Comment continuation ──────────────────────────────────────
augroup no_comment_continuation
  autocmd!
  autocmd FileType * setlocal formatoptions-=r formatoptions-=o
augroup END


" ── Search ────────────────────────────────────────────────────
set incsearch
set hlsearch
set ignorecase
set smartcase
set wrapscan
nnoremap <Esc><Esc> :nohlsearch<CR>


" ── Files ─────────────────────────────────────────────────────
set hidden
set autoread
set noswapfile
set nobackup
set undofile
set undodir=~/.vim/undo//
set encoding=utf-8

set fileformats=unix,dos
" ── Auto-create missing directories ───────────────────────────
function! s:AutoMkdir(dir)
  if !isdirectory(a:dir)
    call mkdir(a:dir, 'p', 0755)
  endif
endfunction

augroup AutoMkdir
  autocmd!
  autocmd BufNewFile * call s:AutoMkdir(expand('<afile>:p:h'))
augroup END

" Make sure undo dir exists
if !isdirectory(expand('~/.vim/undo'))
  call mkdir(expand('~/.vim/undo'), 'p', 0700)
endif


" ── Splits ────────────────────────────────────────────────────
set splitright
set splitbelow
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l


" ── Window Swap ───────────────────────────────────────────────
function! s:SwapWindow(dir)
  let l:win = win_getid()
  let l:buf = bufnr('%')
  execute 'wincmd ' . a:dir
  let l:other_win = win_getid()
  if l:other_win == l:win | return | endif
  let l:other_buf = bufnr('%')
  call win_gotoid(l:win)
  execute 'buffer ' . l:other_buf
  call win_gotoid(l:other_win)
  execute 'buffer ' . l:buf
endfunction

nnoremap <silent> <C-w><Left>  :call <SID>SwapWindow('h')<CR>
nnoremap <silent> <C-w><Right> :call <SID>SwapWindow('l')<CR>
nnoremap <silent> <C-w><Up>    :call <SID>SwapWindow('k')<CR>
nnoremap <silent> <C-w><Down>  :call <SID>SwapWindow('j')<CR>


" ══════════════════════════════════════════════════════════════
"  Mappings
" ══════════════════════════════════════════════════════════════

let mapleader = " "

" ── Files ─────────────────────────────────────────────────────
nnoremap <A-w> :w<CR>
inoremap <A-w> <Esc>:w<CR>gi
nnoremap <A-q> :q<CR>
inoremap <A-q> <Esc>:q<CR>

nnoremap <leader>q  :q<CR>
nnoremap <leader>e  :Explore<CR>
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprev<CR>
nnoremap <C-\> :bdelete<CR>
nnoremap <leader>bd :bdelete<CR>
nnoremap <leader>bv :vnew<CR>
nnoremap <leader>bs :new<CR>
nnoremap <C-BS>     :bd<CR>

" ── Whitespace cleanup ────────────────────────────────────────
function! s:CleanWhitespace()
  silent! %s/\r\n\?/\n/g
  silent! %s/\s\+$//g
  silent! g/^\s*$/d
endfunction
nnoremap <silent> <leader>ww :call <SID>CleanWhitespace()<CR>
nnoremap <leader>wc :set ff=unix<CR>

" ── Pasting ───────────────────────────────────────────────────
" Visual $ goes to last non-blank char (like g_)
vnoremap $ g_

" Paste in visual mode: keep register after pasting over selection
xnoremap p pgvy

" Paste below / above in normal mode
nnoremap <silent> <leader>p :put<CR>
nnoremap <silent> <S-p>     :put!<CR>

" Replace selection with clipboard in visual mode
vnoremap <leader>p "+p

" System clipboard paste in insert mode
inoremap <A-p> <C-r>+

" ── Deleting ──────────────────────────────────────────────────
" x: delete char without yanking
nnoremap x "_x

" D in visual: delete to black hole
xnoremap D "_d

" Alt-d in visual: delete selection to black hole
vnoremap <A-d> "_d

" Smart dd: blank lines go to black hole, others yank normally
function! s:SmartDD()
  let l:line = getline('.')
  if l:line =~# '^\s*$'
    return '"_dd'
  else
    return 'dd'
  endif
endfunction
nnoremap <expr> dd <SID>SmartDD()

" Change to EOL without yanking
nnoremap c$ "_c$

" ── Navigation ────────────────────────────────────────────────
" Keep cursor centred when jumping pages
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

" Keep search terms centred
nnoremap n nzzzv
nnoremap N Nzzzv

" Move lines in visual mode
vnoremap K :m '<-2<CR>gv=gv
vnoremap J :m '>+1<CR>gv=gv

" Move lines in normal/visual mode (Ctrl+Alt+j/k)
nnoremap <silent> <C-A-j> :m .+1<CR>==
nnoremap <silent> <C-A-k> :m .-2<CR>==
vnoremap <silent> <C-A-j> :m '>+1<CR>gv=gv
vnoremap <silent> <C-A-k> :m '<-2<CR>gv=gv

" Stay in indent mode
vnoremap < <gv
vnoremap > >gv

" Move cursor to middle of buffer
function! s:GotoMiddle()
  let l:mid = line('$') / 2
  execute 'normal! ' . l:mid . 'G'
endfunction
nnoremap <silent> M :call <SID>GotoMiddle()<CR>

" j/k on wrapped lines
nnoremap j gj
nnoremap k gk

" Escape insert mode
inoremap jk <Esc>

" Arrow-key navigation in insert mode (Alt+hjkl)
inoremap <A-h> <Left>
inoremap <A-j> <Down>
inoremap <A-k> <Up>
inoremap <A-l> <Right>

" Home / End in insert and command mode
inoremap <C-a> <Home>
inoremap <C-e> <End>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>

" Delete operations in insert mode
inoremap <A-u> <C-u>
inoremap <A-d> <C-o>db
inoremap <A-x> <Del>

" Arrow-key window navigation
nnoremap <C-Left>  <C-w>h
nnoremap <C-Right> <C-w>l
nnoremap <C-Up>    <C-w>k
nnoremap <C-Down>  <C-w>j

" git
function! s:JumpConflict(direction)
  let pattern = '^\(<<<<<<\|=======\|>>>>>>>\)'
  let flags = a:direction ==# 'next' ? 'W' : 'bW'
  let ok = search(pattern, flags)
  if ok == 0
    echo "No more conflict markers"
  endif
endfunction

nnoremap ]g <Cmd>call <SID>JumpConflict('next')<CR>
nnoremap [g <Cmd>call <SID>JumpConflict('prev')<CR>

" ── Buffer management ─────────────────────────────────────────
nnoremap <silent> <C-\>      :bdelete!<CR>
inoremap <silent> <C-\>      <Esc>:bdelete!<CR>
nnoremap <silent> <C-c>      :bd<CR>
inoremap <silent> <C-c>      <Esc>:bdelete<CR>

nnoremap <silent> <leader>bd :bd<CR>
nnoremap <silent> <leader>bn :enew<CR>
nnoremap <silent> <leader>bv :vnew<CR>
nnoremap <silent> <leader>bs :new<CR>
nnoremap <silent> <leader>b[ :bprevious<CR>
nnoremap <silent> <leader>b] :bnext<CR>
nnoremap <silent> <leader>br :edit!<CR>
nnoremap <silent> \[         :bprevious<CR>
nnoremap <silent> \]         :bnext<CR>

" Cycle buffers from insert mode
inoremap <silent> <C-h> <Esc>:bnext<CR>
inoremap <silent> <C-l> <Esc>:bprevious<CR>

" chmod +x current file
nnoremap <leader>bx :!chmod +x %<CR>

" ── Reopen last closed buffer ─────────────────────────────────
let g:last_closed_buffer = ''

augroup TrackClosedBuffers
  autocmd!
  autocmd BufDelete * call s:TrackLastClosed(expand('<abuf>'))
augroup END

function! s:TrackLastClosed(bufnr)
  let l:name = bufname(str2nr(a:bufnr))
  if l:name !=# ''
    let g:last_closed_buffer = l:name
  endif
endfunction

function! ReopenLastBuffer()
  if g:last_closed_buffer !=# '' && filereadable(g:last_closed_buffer)
    execute 'badd ' . fnameescape(g:last_closed_buffer)
    execute 'b '   . fnameescape(g:last_closed_buffer)
  else
    echohl WarningMsg | echo "No recently closed buffer or file does not exist" | echohl None
  endif
endfunction

nnoremap <silent> <leader>bl :call ReopenLastBuffer()<CR>
nnoremap <silent> <C-;>      :call ReopenLastBuffer()<CR>

" ── Delete buffer + file from disk (confirm, default y) ───────
function! s:DeleteBufferAndFile()
  let l:file = expand('%:p')
  if l:file ==# '' || &buftype !=# ''
    echo "No file to delete"
    return
  endif
  let l:fname = fnamemodify(l:file, ':t')
  let l:input = input('Delete "' . l:fname . '" from disk? [Y/n]: ', 'y')
  if l:input ==# '' || tolower(l:input) ==# 'y'
    bdelete!
    if delete(l:file) == 0
      echo "Nuked: " . l:file
    else
      echo "Delete failed"
    endif
  else
    echo "Deletion cancelled"
  endif
endfunction

nnoremap <silent> <leader>bd :call <SID>DeleteBufferAndFile()<CR>

" ── Delete other buffers (spare pinned ones) ──────────────────
let g:pinned_buffers = {}

function! s:DeleteOtherBuffers()
  let l:current = bufnr('%')
  for l:buf in filter(range(1, bufnr('$')),
        \ 'buflisted(v:val) && v:val != l:current && !get(g:pinned_buffers, v:val, 0)')
    silent! execute 'bdelete ' . l:buf
  endfor
endfunction

nnoremap <silent> <leader>bo :call <SID>DeleteOtherBuffers()<CR>

" ── Buffer info float ─────────────────────────────────────────
function! s:BufferInfo()
  let l:file  = expand('%:p')
  let l:name  = l:file !=# '' ? fnamemodify(l:file, ':~:.')  : '[No Name]'

  let l:size = '---'
  if l:file !=# '' && filereadable(l:file)
    let l:bytes = getfsize(l:file)
    if l:bytes >= 1048576
      let l:size = printf('%.1f MB', l:bytes / 1048576.0)
    elseif l:bytes >= 1024
      let l:size = printf('%.1f KB', l:bytes / 1024.0)
    else
      let l:size = l:bytes . ' B'
    endif
  endif

  let l:perms = '---'
  if l:file !=# ''
    let l:raw = system('stat -c %a ' . shellescape(l:file))
    if v:shell_error == 0
      let l:perms = substitute(l:raw, '\s\+', '', 'g')
    endif
  endif

  let l:owner = '---'
  if l:file !=# ''
    let l:raw = system('stat -c %U:%G ' . shellescape(l:file))
    if v:shell_error == 0
      let l:owner = substitute(l:raw, '\s\+', '', 'g')
    endif
  endif

  let l:enc = &fileencoding !=# '' ? &fileencoding : &encoding
  let l:lines = [
        \ '  ' . l:name,
        \ '  owner    ' . l:owner,
        \ '',
        \ '  ft       ' . (&filetype !=# '' ? &filetype : '-'),
        \ '  enc      ' . l:enc,
        \ '  fmt      ' . &fileformat,
        \ '  perms    ' . l:perms,
        \ '  size     ' . l:size,
        \ '  modified ' . (&modified ? 'true' : 'false'),
        \ '  readonly ' . (&readonly ? 'true' : 'false'),
        \ '',
        \ '  q / <Esc>  close',
        \ ]

  if !has('popupwin')
    echo join(l:lines, "\n")
    return
  endif

  let l:width = 48
  let l:winid = popup_create(l:lines, {
        \ 'pos':      'topleft',
        \ 'line':     3,
        \ 'col':      (&columns - l:width) / 2,
        \ 'minwidth': l:width,
        \ 'maxwidth': l:width,
        \ 'border':   [],
        \ 'padding':  [0, 1, 0, 1],
        \ 'mapping':  1,
        \ 'filter':   function('s:BufferInfoFilter'),
        \ })
endfunction

function! s:BufferInfoFilter(winid, key)
  if a:key ==# 'q' || a:key ==# "\<Esc>"
    call popup_close(a:winid)
    return 1
  endif
  return 0
endfunction

nnoremap <silent> <leader>bi :call <SID>BufferInfo()<CR>

" Misc
nnoremap <C-/> :nohlsearch<CR>:diffupdate<CR>:redraw!<CR>
nnoremap <C-_> :nohlsearch<CR>:diffupdate<CR>:redraw!<CR>

nnoremap <leader>rr :%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>

" ── UI Toggles ────────────────────────────────────────────────
nnoremap <silent> <leader>ir :set relativenumber!<CR>

function! s:ToggleColorcolumn()
  if &colorcolumn == '120'
    set colorcolumn=
  else
    set colorcolumn=120
  endif
endfunction
nnoremap <silent> <leader>ic :call <SID>ToggleColorcolumn()<CR>

function! s:ToggleBackground()
  if &background ==# 'dark'
    set background=light
  else
    set background=dark
  endif
endfunction
nnoremap <silent> <leader>uc :call <SID>ToggleBackground()<CR>

function! s:ToggleFoldcolumn()
  if &foldcolumn == 0
    set foldcolumn=1
  else
    set foldcolumn=0
  endif
endfunction
nnoremap <silent> <leader>if :call <SID>ToggleFoldcolumn()<CR>

function! s:ToggleListcharsFull()
  if &list
    set nolist
  else
    set listchars=tab:»\ ,trail:·,nbsp:␣,eol:¬
    set list
  endif
endfunction
nnoremap <silent> <leader>iL :call <SID>ToggleListcharsFull()<CR>

nnoremap <silent> <leader>il :set list!<CR>

nnoremap <silent> <leader>uhm :messages<CR>

function! s:CheckKey()
  let l:key = input("Check key: ")
  if l:key ==# '' | return | endif
  execute 'verbose nmap ' . l:key
  execute 'verbose vmap ' . l:key
  execute 'verbose omap ' . l:key
endfunction
nnoremap <leader>fK :call <SID>CheckKey()<CR>


" ── Performance ───────────────────────────────────────────────
set lazyredraw
set ttyfast
set updatetime=300
set timeoutlen=500
set history=1000
set scrolloff=8
set sidescrolloff=8
set wildmenu
set wildmode=list:longest
syntax on
filetype plugin indent on


" ══════════════════════════════════════════════════════════════
"  File Browser  (mirrors telescope-file-browser)
" ══════════════════════════════════════════════════════════════

let g:netrw_banner    = 0
let g:netrw_liststyle = 3
let g:netrw_winsize   = 30
let g:netrw_hide      = 0
let g:netrw_preview   = 1
autocmd FileType netrw nnoremap <buffer> <A-q> :bdelete<CR>
autocmd FileType netrw nnoremap <buffer> <C-v> :vnew<CR>
autocmd FileType netrw nnoremap <buffer> <C-s> :new<CR>

nnoremap <leader>v :Explore %:p:h<CR>


" ── Copy Path Helpers ─────────────────────────────────────────
nnoremap <leader>yy :let @+ = fnamemodify(expand('%'), ':.')<CR>
      \:echo "Copied relative: " . fnamemodify(expand('%'), ':.')<CR>
nnoremap <leader>yn :let @+ = expand('%:t')<CR>
      \:echo "Copied name: " . expand('%:t')<CR>
nnoremap <leader>yp :let @+ = expand('%:p')<CR>
      \:echo "Copied absolute: " . expand('%:p')<CR>


" ── Diff Split Picker ─────────────────────────────────────────
function! OpenDiffPicker()
  execute 'Explore ' . expand('%:p:h')
  augroup DiffPicker
    autocmd!
    autocmd FileType netrw nnoremap <buffer> <CR>
          \ :call <SID>NetrwDiffOpen()<CR>
    autocmd FileType netrw nnoremap <buffer> q
          \ :bdelete<CR>:autocmd! DiffPicker<CR>
  augroup END
endfunction

function! s:NetrwDiffOpen()
  let l:target = netrw#Call('NetrwGetWord')
  if !empty(l:target) && filereadable(l:target)
    bdelete
    autocmd! DiffPicker
    execute 'vert diffsplit ' . fnameescape(l:target)
  endif
endfunction

nnoremap <leader>dt :call OpenDiffPicker()<CR>


" ── Undotree ──────────────────────────────────────────────────
nnoremap <leader>u :UndotreeToggle<CR>
let g:undotree_WindowLayout       = 2
let g:undotree_ShortIndicators    = 1
let g:undotree_SetFocusWhenToggle = 1
let g:undotree_SplitWidth         = 30


" ── Auto-pairs ────────────────────────────────────────────────
let g:AutoPairsShortcutToggle   = ''
let g:AutoPairsShortcutFastWrap = '<M-e>'


" ── FZF ───────────────────────────────────────────────────────
let s:rg_opts    = '--hidden --no-ignore --ignore-case --column --line-number --no-heading --color=always'
let s:fd_excludes = '--exclude .git --exclude node_modules --exclude .cache --exclude dist --exclude build --exclude target'

function! FdFiles()
  let l:source = $FD . ' --type f --hidden ' . s:fd_excludes
  call fzf#vim#files(getcwd(), {
    \ 'source':  l:source,
    \ 'options': [
    \   '--prompt',  'Files> ',
    \   '--preview', 'bat --color=always --style=numbers {}',
    \   '--preview-window', 'right:50%:wrap'
    \ ]}, 0)
endfunction

nnoremap <silent> <leader><leader> :call FdFiles()<CR>

function! RipgrepFzf(query, fullscreen)
  let command_fmt     = 'rg ' . s:rg_opts . ' -- %s || true'
  let initial_command = printf(command_fmt, shellescape(a:query))
  let reload_command  = printf(command_fmt, '{q}')
  let spec = {
    \ 'options': [
    \   '--disabled',
    \   '--query', a:query,
    \   '--bind', 'change:reload:' . reload_command,
    \   '--delimiter', ':',
    \   '--preview', 'bat --color=always {1} --highlight-line {2}',
    \   '--preview-window', '+{2}-/2'
    \ ]}
  call fzf#vim#grep(initial_command, fzf#vim#with_preview(spec), a:fullscreen)
endfunction

command! -nargs=* -bang RG call RipgrepFzf(<q-args>, <bang>0)
nnoremap <silent> <leader>n :RG<CR>

function! RipgrepWord(word, fullscreen)
  let s:last_rg_query = a:word
  let command_fmt     = 'rg ' . s:rg_opts . ' -- %s || true'
  let initial_command = printf(command_fmt, shellescape(a:word))
  let reload_command  = printf(command_fmt, '{q}')
  let spec = {
    \ 'options': [
    \   '--disabled',
    \   '--query', a:word,
    \   '--prompt', 'Grep[' . a:word . ']> ',
    \   '--bind', 'change:reload:' . reload_command,
    \   '--delimiter', ':',
    \   '--preview', 'bat --color=always {1} --highlight-line {2}',
    \   '--preview-window', '+{2}-/2'
    \ ]}
  call fzf#vim#grep(initial_command, fzf#vim#with_preview(spec), a:fullscreen)
endfunction

nnoremap <silent> <leader>1 :call RipgrepWord(expand('<cword>'), 0)<CR>

function! s:GrepUnderCursor2()
  let l:line = getline('.')
  let l:col  = col('.')
  let l:s = searchpos('\S\+', 'bcn', line('.'))[1] - 1
  let l:e = searchpos('\S\+', 'cen', line('.'))[1]
  if l:s < 0 || l:e <= 0
    echo "No token under cursor"
    return
  endif
  let l:token = l:line[l:s : l:e - 1]
  let l:cur_start = 0
  let l:seg_start = 0
  let l:seg_end   = len(l:token)
  let l:i = 0
  while l:i < len(l:token)
    let l:ch = l:token[l:i]
    if l:ch ==# '/' || l:ch ==# '\'
      let l:abs_s = l:s + l:cur_start
      let l:abs_e = l:s + l:i
      if l:col - 1 >= l:abs_s && l:col - 1 < l:abs_e
        let l:seg_start = l:cur_start
        let l:seg_end   = l:i
        break
      endif
      let l:cur_start = l:i + 1
    endif
    let l:i += 1
  endwhile
  if l:seg_start == 0 && l:seg_end == len(l:token)
    let l:seg_start = l:cur_start
  endif
  let l:word = l:token[l:seg_start : l:seg_end - 1]
  if l:word ==# ''
    echo "No token under cursor"
    return
  endif
  call RipgrepWord(l:word, 0)
endfunction

nnoremap <silent> <leader>2 :call <SID>GrepUnderCursor2()<CR>

function! s:GrepUnderCursor3()
  let l:line = getline('.')
  let l:col  = col('.')
  let l:s = searchpos('\S\+', 'bcn', line('.'))[1] - 1
  let l:e = searchpos('\S\+', 'cen', line('.'))[1]
  if l:s < 0 || l:e <= 0
    echo "No token under cursor"
    return
  endif
  call RipgrepWord(l:line[l:s : l:e - 1], 0)
endfunction

nnoremap <silent> <leader>3 :call <SID>GrepUnderCursor3()<CR>


" ══════════════════════════════════════════════════════════════
"  Custom Statusline
" ══════════════════════════════════════════════════════════════

function! s:SetStatuslineHls()
    hi StatusLine   guifg=NONE guibg=NONE cterm=NONE
    hi StatusLineNC guifg=NONE guibg=NONE cterm=NONE
    hi SLAccent        guifg=#7aa2f7 guibg=NONE cterm=NONE
    hi SLInsertAccent  guifg=#0db9d7 guibg=NONE cterm=NONE
    hi SLVisualAccent  guifg=#a487d8 guibg=NONE cterm=NONE
    hi SLReplaceAccent guifg=#d94a4a guibg=NONE cterm=NONE
    hi SLCmdAccent     guifg=#e0af68 guibg=NONE cterm=NONE
    hi SLTermAccent    guifg=#565f89 guibg=NONE cterm=NONE
    hi SLText          guifg=#c0caf5 guibg=NONE cterm=NONE
    hi SLExtra         guifg=#a9b1d6 guibg=NONE cterm=NONE
    hi SLModified      guifg=#c0caf5 guibg=NONE cterm=NONE
    hi SLGitAdd        guifg=#1abc9c guibg=NONE cterm=NONE
    hi SLGitChange     guifg=#e0af68 guibg=NONE cterm=NONE
    hi SLGitDelete     guifg=#db4b4b guibg=NONE cterm=NONE
    hi SLError         guifg=#db4b4b guibg=NONE cterm=NONE
    hi SLWarn          guifg=#e0af68 guibg=NONE cterm=NONE
endfunction

call s:SetStatuslineHls()
augroup SLHighlights
    autocmd!
    autocmd ColorScheme * call s:SetStatuslineHls()
augroup END

let s:mode_map = {
    \ 'n':    ['NORMAL',    '%#SLAccent#'],
    \ 'no':   ['O-PEND',    '%#SLAccent#'],
    \ 'i':    ['INSERT',    '%#SLInsertAccent#'],
    \ 'ic':   ['INSERT',    '%#SLInsertAccent#'],
    \ 'v':    ['VISUAL',    '%#SLVisualAccent#'],
    \ 'V':    ['V-LINE',    '%#SLVisualAccent#'],
    \ "\<C-v>": ['V-BLOCK', '%#SLVisualAccent#'],
    \ 'R':    ['REPLACE',   '%#SLReplaceAccent#'],
    \ 'Rv':   ['V-REPLACE', '%#SLReplaceAccent#'],
    \ 'c':    ['COMMAND',   '%#SLCmdAccent#'],
    \ 't':    ['TERMINAL',  '%#SLTermAccent#'],
    \ 'nt':   ['TERMINAL',  '%#SLTermAccent#'],
    \ 's':    ['SELECT',    '%#SLVisualAccent#'],
    \ 'S':    ['S-LINE',    '%#SLVisualAccent#'],
    \ }

function! SLMode()
    let m    = mode()
    let info = get(s:mode_map, m, [toupper(m), '%#SLAccent#'])
    return info[1] . ' ' . info[0] . ' %#SLText#'
endfunction

function! SLFilename()
    let fpath = expand('%:.')
    if fpath ==# '' || fpath ==# '.'
        return '%#SLText# [No Name] '
    endif
    let file   = fnamemodify(fpath, ':t')
    let parent = fnamemodify(fpath, ':h')
    let result = parent ==# '.' ? file : parent . '/' . file
    if winwidth(0) <= 80
        let result = pathshorten(result)
    endif
    return '%#SLText# ' . result . ' '
endfunction

function! SLModified()
    if &readonly  | return '%#SLError# 󰌾 %#SLText#' | endif
    if &modified  | return '%#SLModified# ~ %#SLText#' | endif
    return ''
endfunction

function! SLVCS()
    if exists('b:gitsigns_status_dict')
        let d    = b:gitsigns_status_dict
        let head = get(d, 'head', '')
        if head ==# '' | return '' | endif
        if len(head) > 20 | let head = head[:16] . '…' | endif
        let out = '%#SLExtra#  ' . head
        if get(d, 'added',   0) > 0 | let out .= '%#SLGitAdd# +'    . d.added   | endif
        if get(d, 'changed', 0) > 0 | let out .= '%#SLGitChange# ~' . d.changed | endif
        if get(d, 'removed', 0) > 0 | let out .= '%#SLGitDelete# -' . d.removed | endif
        return out . ' '
    endif
    if exists('*FugitiveHead')
        let head = FugitiveHead()
        return head !=# '' ? '%#SLExtra#  ' . head . ' ' : ''
    endif
    return ''
endfunction

function! SLSearch()
    if !v:hlsearch | return '' | endif
    try
        let s = searchcount({'maxcount': 999})
        if empty(s) || !has_key(s, 'total') || s.total == 0 | return '' | endif
        return '%#SLExtra# ' . s.current . '/' . s.total . ' '
    catch
        return ''
    endtry
endfunction

function! SLMacro()
    let reg = reg_recording()
    return reg !=# '' ? '%#SLError# 󰑋 @' . reg . ' ' : ''
endfunction

function! SLBigFile()
    return line('$') > 1000 ? '%#SLWarn# 󰋩 big ' : ''
endfunction

function! SLFiletype()
    return &filetype !=# '' ? '%#SLExtra#  ' . &filetype . ' ' : ''
endfunction

function! SLEncoding()
    let enc = &fileencoding !=# '' ? &fileencoding : &encoding
    return (enc !=# 'utf-8' && enc !=# '') ? '%#SLExtra#  ' . toupper(enc) . ' ' : ''
endfunction

function! SLFileFormat()
    let icons = {'unix': 'LF', 'dos': 'CRLF', 'mac': 'CR'}
    return '%#SLExtra#  ' . get(icons, &fileformat, &fileformat) . ' '
endfunction

function! SLLineInfo()
    if &filetype ==# 'alpha' | return '' | endif
    let pct = float2nr(floor(line('.') * 100.0 / line('$')))
    return '%#SLExtra# ' . line('.') . ':' . col('.') . ' ' . pct . '%% '
endfunction

let s:scrollbar_chars = ['󰪞', '󰪟', '󰪠', '󰪡', '󰪢', '󰪣', '󰪤', '󰪥']
function! SLScrollbar()
    let n   = len(s:scrollbar_chars)
    let idx = max([1, min([n, float2nr(ceil(line('.') * 1.0 / line('$') * n))])])
    return '%#SLExtra# ' . s:scrollbar_chars[idx - 1] . ' '
endfunction

function! SLCharcount()
    return &filetype ==# 'alpha' ? '' : '%#SLExtra# ' . wordcount().chars . ' '
endfunction

function! SLLinecount()
    return &filetype ==# 'alpha' ? '' : '%#SLExtra# ' . line('$') . ' '
endfunction

function! SLVenv()
    if &filetype !=# 'python' | return '' | endif
    let env = !empty($VIRTUAL_ENV) ? $VIRTUAL_ENV : $CONDA_DEFAULT_ENV
    return env !=# '' ? '%#SLExtra# 󰆧 ' . fnamemodify(env, ':t') . ' ' : ''
endfunction

function! ActiveStatusline()
    let w = winwidth(0)
    let left =
        \ SLMode()     .
        \ SLFilename() .
        \ SLModified() .
        \ SLVCS()
    let right =
        \ SLMacro()                           .
        \ SLSearch()                          .
        \ SLBigFile()                         .
        \ (w > 100 ? SLVenv()      : '')      .
        \ (w > 100 ? SLFiletype()  : '')      .
        \ SLLineInfo()                        .
        \ SLScrollbar()                       .
        \ (w > 90  ? SLCharcount() : '')      .
        \ (w > 80  ? SLLinecount() : '')      .
        \ (w > 110 ? SLEncoding()  : '')      .
        \ (w > 110 ? SLFileFormat(): '')
    return left . '%=' . right
endfunction

function! InactiveStatusline()
    return '%#SLTermAccent#' . SLFilename() . SLModified()
endfunction

augroup CustomStatusline
    autocmd!
    autocmd WinEnter,BufEnter * setlocal statusline=%!ActiveStatusline()
    autocmd WinLeave,BufLeave * setlocal statusline=%!InactiveStatusline()
    autocmd FileType qf,help  setlocal statusline=%!ActiveStatusline()
augroup END

set statusline=%!ActiveStatusline()

" ══════════════════════════════════════════════════════════════
"  Marks Plugin
" ══════════════════════════════════════════════════════════════

" ── Config ────────────────────────────────────────────────────
let s:marks_save_path  = expand('~/.vim/marks.json')
let s:marks_buf        = -1
let s:marks_win        = -1
let s:last_closed_buf  = ''
let g:marks_colors     = { 'global': '#004E2E', 'local': '#004E89' }

" ── Highlights ────────────────────────────────────────────────
function! s:InitMarksHighlights()
  execute 'hi markGlobal guifg=' . g:marks_colors.global . ' gui=bold'
  execute 'hi markLocal  guifg=' . g:marks_colors.local  . ' gui=bold'
endfunction
call s:InitMarksHighlights()
augroup MarksHighlights
  autocmd!
  autocmd ColorScheme * call s:InitMarksHighlights()
augroup END

" ── Signs ─────────────────────────────────────────────────────
function! s:InitMarksSigns()
  for c in range(char2nr('A'), char2nr('Z'))
    let mark = nr2char(c)
    call sign_define('mark_' . mark, { 'text': mark . ' ', 'texthl': 'markGlobal' })
  endfor
  for c in range(char2nr('a'), char2nr('z'))
    let mark = nr2char(c)
    call sign_define('mark_' . mark, { 'text': mark . ' ', 'texthl': 'markLocal' })
  endfor
endfunction
call s:InitMarksSigns()

" ── Snapshot ──────────────────────────────────────────────────
function! s:MarksSnapshot()
  let data = { 'global': {}, 'local': {} }

  for c in range(char2nr('A'), char2nr('Z'))
    let mark = nr2char(c)
    let pos  = getpos("'" . mark)
    if pos[1] != 0
      let fname = fnamemodify(bufname(pos[0] != 0 ? pos[0] : bufnr('%')), ':p')
      if fname !=# ''
        let data.global[mark] = { 'file': fname, 'lnum': pos[1], 'col': pos[2] }
      endif
    endif
  endfor

  for bnr in range(1, bufnr('$'))
    if !buflisted(bnr) || !bufloaded(bnr) | continue | endif
    let fname = fnamemodify(bufname(bnr), ':p')
    if fname ==# '' | continue | endif
    let buf_marks = {}
    for c in range(char2nr('a'), char2nr('z'))
      let mark = nr2char(c)
      let pos  = getpos("'" . mark)
      if pos[1] != 0
        let mark_buf = pos[0] != 0 ? pos[0] : bufnr('%')
        if mark_buf == bnr
          let buf_marks[mark] = { 'lnum': pos[1], 'col': pos[2] }
        endif
      endif
    endfor
    if !empty(buf_marks)
      let data.local[fname] = buf_marks
    endif
  endfor

  return data
endfunction

" ── Persistence: save ─────────────────────────────────────────
function! s:MarksSave()
  let data    = s:MarksSnapshot()
  let encoded = json_encode(data)
  try
    call writefile([encoded], s:marks_save_path)
    echo printf('[marks] saved %d global, %d file(s) with local marks',
          \ len(data.global), len(data.local))
  catch
    echohl ErrorMsg | echo '[marks] write error: ' . v:exception | echohl None
  endtry
endfunction

" ── Persistence: load all ─────────────────────────────────────
function! s:MarksLoad()
  if !filereadable(s:marks_save_path) | return | endif
  let raw = join(readfile(s:marks_save_path), '')
  if raw ==# '' | return | endif
  try
    let data = json_decode(raw)
  catch
    echohl WarningMsg | echo '[marks] parse error' | echohl None
    return
  endtry

  if type(get(data, 'global', 0)) == v:t_dict
    for [mark, info] in items(data.global)
      if has_key(info, 'file') && has_key(info, 'lnum')
        let bnr = bufnr(info.file, 1)
        call setbufvar(bnr, '&buflisted', 1)
        silent! call setpos("'" . mark,
              \ [bnr, info.lnum, get(info, 'col', 0), 0])
      endif
    endfor
  endif

  if type(get(data, 'local', 0)) == v:t_dict
    for [fname, marks] in items(data.local)
      let bnr = bufnr(fname)
      if bnr != -1 && bufloaded(bnr)
        for [mark, info] in items(marks)
          silent! call setpos("'" . mark,
                \ [bnr, info.lnum, get(info, 'col', 0), 0])
        endfor
      endif
    endfor
  endif
endfunction

" ── Persistence: load for one buffer ──────────────────────────
function! s:MarksLoadForBuf(bufnr)
  let fname = fnamemodify(bufname(a:bufnr), ':p')
  if fname ==# '' || !filereadable(s:marks_save_path) | return | endif
  let raw = join(readfile(s:marks_save_path), '')
  if raw ==# '' | return | endif
  try
    let data = json_decode(raw)
  catch
    return
  endtry
  let locals = get(get(data, 'local', {}), fname, {})
  for [mark, info] in items(locals)
    silent! call setpos("'" . mark,
          \ [a:bufnr, info.lnum, get(info, 'col', 0), 0])
  endfor
endfunction

" ── Sign column refresh ───────────────────────────────────────
function! s:MarksUpdateSigns()
  let bnr   = bufnr('%')
  let fname = fnamemodify(bufname(bnr), ':p')
  call sign_unplace('marks', { 'buffer': bnr })
  if fname ==# '' | return | endif

  for c in range(char2nr('A'), char2nr('Z'))
    let mark = nr2char(c)
    let pos  = getpos("'" . mark)
    if pos[1] != 0
      let mark_fname = fnamemodify(bufname(pos[0] != 0 ? pos[0] : bnr), ':p')
      if mark_fname ==# fname
        call sign_place(0, 'marks', 'mark_' . mark, bnr, { 'lnum': pos[1] })
      endif
    endif
  endfor

  for c in range(char2nr('a'), char2nr('z'))
    let mark = nr2char(c)
    let pos  = getpos("'" . mark)
    if pos[1] != 0
      let mark_buf = pos[0] != 0 ? pos[0] : bnr
      if mark_buf == bnr
        call sign_place(0, 'marks', 'mark_' . mark, bnr, { 'lnum': pos[1] })
      endif
    endif
  endfor
endfunction

" ── Delete all marks ──────────────────────────────────────────
function! s:MarksDeleteAll()
  delmarks A-Z
  delmarks a-z
  echo '[marks] deleted all marks'
  call s:MarksSave()
endfunction

" ── Panel: build lines ────────────────────────────────────────
function! s:MarksBuildLines(data)
  let lines = [
        \ '╔════════════════════════════════════════╗',
        \ '║          📍 ALL MARKS                 ║',
        \ '╚════════════════════════════════════════╝',
        \ '',
        \ ]
  let has_marks = 0

  if !empty(a:data.global)
    call add(lines, '🌍 GLOBAL MARKS:')
    for c in range(char2nr('A'), char2nr('Z'))
      let mark = nr2char(c)
      if has_key(a:data.global, mark)
        let info  = a:data.global[mark]
        let short = fnamemodify(info.file, ':~:.')
        call add(lines, printf("  '%s  %s:%d", mark, short, info.lnum))
        let has_marks = 1
      endif
    endfor
    call add(lines, '')
  endif

  if !empty(a:data.local)
    call add(lines, '📄 LOCAL MARKS BY FILE:')
    for fname in sort(keys(a:data.local))
      call add(lines, '  ' . fnamemodify(fname, ':~:.'))
      for c in range(char2nr('a'), char2nr('z'))
        let mark = nr2char(c)
        if has_key(a:data.local[fname], mark)
          let info = a:data.local[fname][mark]
          call add(lines, printf("    '%s  line %d", mark, info.lnum))
          let has_marks = 1
        endif
      endfor
    endfor
    call add(lines, '')
  endif

  if !has_marks
    call add(lines, '  (no marks set)')
  endif

  call add(lines, '')
  call add(lines, 'ENTER / l — jump   q / <M-q> — close')
  return lines
endfunction

" ── Panel: refresh in-place ───────────────────────────────────
function! s:MarksRefreshPanel()
  if s:marks_win == -1 || !win_id2win(s:marks_win) | return | endif
  if s:marks_buf == -1 || !bufexists(s:marks_buf)  | return | endif
  let data  = s:MarksSnapshot()
  let lines = s:MarksBuildLines(data)
  call setbufvar(s:marks_buf, '&modifiable', 1)
  call deletebufline(s:marks_buf, 1, '$')
  call setbufline(s:marks_buf, 1, lines)
  call setbufvar(s:marks_buf, '&modifiable', 0)
endfunction

" ── Panel: jump from panel line ───────────────────────────────
function! s:MarksJump()
  let line     = getline('.')
  let mark_chr = matchstr(line, "'\\zs\\w\\ze")
  if mark_chr ==# '' | return | endif

  if !filereadable(s:marks_save_path) | return | endif
  let raw = join(readfile(s:marks_save_path), '')
  if raw ==# '' | return | endif
  try
    let data = json_decode(raw)
  catch
    return
  endtry

  let globals = get(data, 'global', {})
  if has_key(globals, mark_chr)
    let info = globals[mark_chr]
    call s:MarksClosePanel()
    execute 'edit ' . fnameescape(info.file)
    call cursor(info.lnum, get(info, 'col', 0))
    return
  endif

  for [fname, marks] in items(get(data, 'local', {}))
    if has_key(marks, mark_chr)
      let info = marks[mark_chr]
      call s:MarksClosePanel()
      execute 'edit ' . fnameescape(fname)
      call cursor(info.lnum, get(info, 'col', 0))
      return
    endif
  endfor
endfunction

" ── Panel: close ──────────────────────────────────────────────
function! s:MarksClosePanel()
  if s:marks_win != -1 && win_id2win(s:marks_win)
    call win_gotoid(s:marks_win)
    close
  endif
  let s:marks_win = -1
endfunction

" ── Panel: show / toggle ──────────────────────────────────────
function! s:MarksShow()
  if s:marks_win != -1 && win_id2win(s:marks_win)
    call s:MarksClosePanel()
    return
  endif

  call s:MarksSave()

  if s:marks_buf == -1 || !bufexists(s:marks_buf)
    let s:marks_buf = bufadd('')
    call setbufvar(s:marks_buf, '&buftype',   'nofile')
    call setbufvar(s:marks_buf, '&bufhidden', 'hide')
    call setbufvar(s:marks_buf, '&swapfile',  0)
    call bufload(s:marks_buf)
  endif

  let lines = s:MarksBuildLines(s:MarksSnapshot())
  call setbufvar(s:marks_buf, '&modifiable', 1)
  call deletebufline(s:marks_buf, 1, '$')
  call setbufline(s:marks_buf, 1, lines)
  call setbufvar(s:marks_buf, '&modifiable', 0)

  vsplit
  let s:marks_win = win_getid()
  execute 'buffer ' . s:marks_buf
  vertical resize 50

  nnoremap <buffer> <silent> q     :call <SID>MarksClosePanel()<CR>
  nnoremap <buffer> <silent> <M-q> :call <SID>MarksClosePanel()<CR>
  nnoremap <buffer> <silent> <CR>  :call <SID>MarksJump()<CR>
  nnoremap <buffer> <silent> l     :call <SID>MarksJump()<CR>
endfunction

" ── Intercept m{x} to refresh signs + panel ───────────────────
function! s:SetMarkAndRefresh(mark)
  execute 'normal! m' . a:mark
  call s:MarksUpdateSigns()
  call s:MarksRefreshPanel()
endfunction

for s:c in range(char2nr('A'), char2nr('Z'))
  execute printf("nnoremap <silent> m%s :call <SID>SetMarkAndRefresh('%s')<CR>",
        \ nr2char(s:c), nr2char(s:c))
endfor
for s:c in range(char2nr('a'), char2nr('z'))
  execute printf("nnoremap <silent> m%s :call <SID>SetMarkAndRefresh('%s')<CR>",
        \ nr2char(s:c), nr2char(s:c))
endfor

" ── Keymaps ───────────────────────────────────────────────────
nnoremap <silent> <leader>sm  :call <SID>MarksSave()<CR>
nnoremap <silent> <leader>lm  :call <SID>MarksLoad()<CR>
nnoremap <silent> <leader>d`  :call <SID>MarksDeleteAll()<CR>
nnoremap <silent> <localleader>` :call <SID>MarksShow()<CR>

" ── Autocmds ──────────────────────────────────────────────────
augroup MarksPlugin
  autocmd!
  autocmd BufWinEnter * call s:MarksLoadForBuf(expand('<abuf>') + 0)
        \ | call s:MarksUpdateSigns()
  autocmd VimLeavePre * call s:MarksSave()
  autocmd CursorMoved,BufEnter,BufWrite,DirChanged * call s:MarksUpdateSigns()
augroup END

" ── Initial load ──────────────────────────────────────────────
call s:MarksLoad()
