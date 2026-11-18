#!/usr/bin/env fish
# Gate self-test: prove lint, docs, preflight, precommit, and the global
# pre-commit hook reject broken fixtures. Runs in an isolated temp repo and
# never mutates this working tree.

set -l failed 0
set -l root $PWD
set -l tmp (mktemp -d)
if test -z "$tmp"
    echo "selftest: mktemp failed" >&2
    exit 1
end

for tool in git cp env ln mkdir rm mktemp just fish bash
    if not command -q $tool
        echo "selftest: missing required tool: $tool" >&2
        rm -rf $tmp
        exit 1
    end
end

function expect_pass --argument-names label
    $argv[2..-1] >/dev/null 2>&1
    if test $status -eq 0
        echo "ok: $label passed"
    else
        echo "FAIL: $label should pass" >&2
        set -g failed 1
    end
end

function expect_fail --argument-names label
    $argv[2..-1] >/dev/null 2>&1
    if test $status -ne 0
        echo "ok: $label rejected"
    else
        echo "FAIL: $label should fail" >&2
        set -g failed 1
    end
end

set -l repo $tmp/repo
mkdir -p $repo/dot_config/git $repo/packages $tmp/nohooks
for f in justfile AGENTS.md dot_AGENTS.md dot_typos.toml dot_taplo.toml
    cp $root/$f $repo/
end
cp $root/packages/manifest.md $repo/packages/
cp -a $root/dot_config/git/hooks $repo/dot_config/git/
cp $root/run_onchange_*.sh.tmpl $repo/
cp $root/dot_config/fish/completions/hx.fish $repo/probe.fish

git -C $repo init -q
git -C $repo add -A
git -C $repo -c core.hooksPath=$tmp/nohooks \
    -c commit.gpgsign=false \
    -c user.name=selftest -c user.email=selftest@example.invalid commit -qm init

set -l jf $repo/justfile
expect_pass "baseline lint" just --justfile $jf lint
expect_pass "baseline templates" just --justfile $jf templates

# Unformatted fish must fail lint.
printf 'if true\necho probe\necho probe2\nend\n' >$repo/probe.fish
git -C $repo add probe.fish
expect_fail "unformatted fish" just --justfile $jf lint
git -C $repo rm --cached -q probe.fish
rm -f $repo/probe.fish

# Trailing whitespace must fail lint.
printf 'clean\n' >$repo/probe.txt
git -C $repo add probe.txt
printf 'dirty  \n' >>$repo/probe.txt
git -C $repo add probe.txt
expect_fail "trailing whitespace" just --justfile $jf lint
rm -f $repo/probe.txt
git -C $repo rm --cached -q probe.txt

# Conflict markers must fail lint.
printf '<<<<<<< HEAD\nleft\n=======\nright\n>>>>>>> other\n' >$repo/probe.txt
git -C $repo add probe.txt
expect_fail "conflict markers" just --justfile $jf lint
rm -f $repo/probe.txt
git -C $repo rm --cached -q probe.txt

# Rendered templates must be shfmt-clean.
printf 'echo   probe\n' >>$repo/run_onchange_after_10-install-toolchains.sh.tmpl
expect_fail "rendered template formatting" just --justfile $jf templates
cp $root/run_onchange_after_10-install-toolchains.sh.tmpl $repo/

# Missing .md citation must fail docs.
cp $repo/AGENTS.md $tmp/AGENTS.md.bak
printf '\n`missing.md`\n' >>$repo/AGENTS.md
expect_fail "missing docs citation" just --justfile $jf docs
cp $tmp/AGENTS.md.bak $repo/AGENTS.md

# Missing contract file must fail preflight.
mv $repo/dot_AGENTS.md $tmp/
expect_fail "missing contract file" just --justfile $jf preflight
mv $tmp/dot_AGENTS.md $repo/

# Missing tool must fail preflight.
set -l probe_home $tmp/home
set -l probe_bin $tmp/bin
mkdir -p $probe_home $probe_bin
ln -s (command -v just) $probe_bin/just
ln -s (command -v fish) $probe_bin/fish
expect_fail "missing tool" env HOME=$probe_home PATH=$probe_bin just --justfile $jf preflight

# Staged precommit gate and hook dispatch: clean passes, whitespace fails.
printf 'clean staged\n' >$repo/staged.txt
git -C $repo add staged.txt
expect_pass "staged precommit" just --justfile $jf precommit
expect_pass "hook dispatch" fish -c "cd $repo; and bash dot_config/git/hooks/executable_pre-commit"
printf 'dirty staged  \n' >>$repo/staged.txt
git -C $repo add staged.txt
expect_fail "staged whitespace" just --justfile $jf precommit
expect_fail "hook blocked staged whitespace" fish -c "cd $repo; and bash dot_config/git/hooks/executable_pre-commit"

rm -rf $tmp
if test $failed -ne 0
    echo "VERIFY FAILED: selftest" >&2
    exit 1
end
echo "selftest: gate rejects broken fixtures"
