# Publishing to GitHub

This directory is a local git repository with one commit.  No remote is
configured and nothing has been pushed.

## With gh

    gh repo create <user>/rva-e16 --public --source=. --remote=origin --push

If the repository already exists:

    git remote add origin git@github.com:<user>/rva-e16.git
    git push -u origin main

## Without gh

1. Create an empty repository on GitHub (no README, no .gitignore).
2. Then:

    git remote add origin git@github.com:<user>/rva-e16.git
    git branch -M main
    git push -u origin main

## Notes

- The repository is 31 files, docs + patches + tools + bench; no build
  artifacts (see .gitignore).
- The Zhihu article is a draft in docs/Zhihu-Article.md; publishing it needs
  a Zhihu account and is not automated.
- The LLVM/Spike changes live in the working trees under WSL; the patch in
  patches/llvm/0002-RISCV-Q3-MC.patch is the current LLVM diff.
