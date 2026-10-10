set modelines=0
set number
set encoding=utf-8
set nowrap

set tabstop=2
set shiftwidth=2
set softtabstop=2
set autoindent
set copyindent
set expandtab
set noshiftround

set hlsearch
set incsearch
set showmatch
set smartcase

set hidden
set ttyfast
set laststatus=2

set showcmd
set background=dark
set nocompatible

colorscheme habamax
filetype on
syntax on

set list
set lcs=space:·


"Esc
imap jj <Esc>
"Completes 
inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : (col('.') > 1 && getline('.')[col('.') - 2] =~ '\k') ? "\<C-n>" : "\<Tab>"

command! TermRight vertical rightbelow terminal
