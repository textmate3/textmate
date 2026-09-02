# Onigmo

Onigmo is the regular expression engine. It powers grammar parsing, scope matching and every find
operation, and it runs patterns supplied by bundles, so its correctness and memory safety matter more
than its size suggests.

## Where it lives

`vendor/Onigmo/` is TextMate's wrapper directory. It holds the build description (`default.rave`), the
hand maintained `config.h`, a small `src/setup.c`, and the tests. The engine source sits inside it as a
git submodule at `vendor/Onigmo/vendor/`, pointing at the `textmate3/Onigmo` repository. The doubled
`vendor/Onigmo/vendor` path reads like a typo and is not.

[`textmate3/Onigmo`](https://github.com/textmate3/Onigmo) is a fork of the upstream engine, `k-takata/Onigmo`.

## What the pin is, and why

The submodule pins a commit on the fork's `main`, not a release tag. Upstream has cut no release since
`Onigmo-6.2.0` in 2019, while its `main` carries fixes worth shipping that exist nowhere else, among
them an out-of-bounds read in character class parsing, a stack overflow on nested repetition, and a
crash in `onig_error_code_to_str`. For an engine that executes untrusted patterns, those fixes outweigh
the comfort of a tagged release.

## What the fork carries beyond upstream

The fork's `main` holds upstream's history plus TextMate's own commits on top. Currently that is one
change: the `st` hash table declares full prototypes for its function pointers (`st.h`, `st.c`, and the
callback signatures in `regparse.c`). Upstream declares them with an empty parameter list, which C23
removes from the language and current compilers warn about. The application builds with zero warnings
from Onigmo sources.

List the local commits at any time with:

```sh
cd vendor/Onigmo/vendor
git log --oneline Onigmo-6.2.0..HEAD --author-date-order | head
```

Commits authored in the `textmate3` fork sit above the upstream merge they are based on.

## Taking upstream changes, if Onigmo wakes up

Work in a fresh clone of `textmate3/Onigmo`, not in the submodule working copy. Clone it anywhere disposable and delete it when the merge is pushed.

1. Add upstream: `git remote add upstream https://github.com/k-takata/Onigmo.git`
2. `git fetch upstream` and merge `upstream/master` into `main`.
3. Expect conflicts wherever the fork's own commits touch, today `st.h`, `st.c` and the four
   `st_foreach` callbacks in `regparse.c`. Keep the full prototypes. If upstream has adopted
   prototypes itself, prefer upstream's spelling and drop the fork's patch in the merge.
4. Build the fork's own way once if convenient, but the check that matters is TextMate's: push `main`
   to `textmate3/Onigmo` first, then in this repository check the submodule out at the new commit,
   `git add vendor/Onigmo/vendor`, and rebuild.
5. A submodule pointer is only clonable when the commit it names is on the fork's remote. Push the
   fork before committing the pointer, in the same sitting.
6. Verify: `script/test` runs the Onigmo suite along with everything else, and the `regexp` framework
   suite exercises the engine hard. A clean rebuild should report zero warnings from
   `vendor/Onigmo/vendor` sources.

The same procedure applies to a new upstream release. A release tag is preferable to a `main` tip when
one exists that contains the safety fixes above, so if upstream ever tags again, pin the tag and rebase
the fork's commits onto it.

## config.h is hand maintained

`vendor/Onigmo/config.h` belongs to TextMate, not to upstream, and upstream's configure machinery never
runs. Onigmo sizes `st_data_t` by comparing `SIZEOF_LONG` and `SIZEOF_LONG_LONG` against
`SIZEOF_VOIDP`, and an undefined macro silently reads as zero, so any upstream change that consults a
new `SIZEOF_` or `HAVE_` macro needs a matching definition here. When the engine misbehaves after an
update, an undefined config macro is the first thing to rule out.
