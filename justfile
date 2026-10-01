# Verification entry point for the dotfiles repository.
# Canonical commands come from AGENTS.md §2.4.2 (hook template syntax) and §4
# (standard verification checklist) — this file invents nothing.
#
# `check` is the FULL gate and is what the global pre-push hook dispatches to.
# Partial checks must use other recipe names.

set shell := ["fish", "-c"]

# Invariant gate: the stateful memory-family extensions must stay disabled.
# Fails the build if memory/chatrecall/tom/scheduler are flipped on.
check-config:
	#!/usr/bin/env fish
	python3 -c 'import yaml,sys; c=yaml.safe_load(open(sys.argv[1]))["extensions"]; bad=[k for k in ["memory","chatrecall","tom","scheduler"] if c.get(k,{}).get("enabled") is not False]; (print("config-gate: must stay disabled: "+", ".join(bad), file=sys.stderr) or sys.exit(1)) if bad else print("config-gate: memory/chatrecall/tom/scheduler all disabled")' dot_config/goose/config.yaml

# Full gate: hook templates, git hooks, tool cards, config gate, whitespace.
check: check-config
	#!/usr/bin/env fish
	set -l failed 0
	for f in run_onchange_*.sh.tmpl
		if not chezmoi execute-template < $f | bash -n
			echo "FAIL: $f (template syntax)" >&2
			set failed 1
		end
	end
	for h in dot_config/git/hooks/*
		if not bash -n $h
			echo "FAIL: $h (hook syntax)" >&2
			set failed 1
		end
	end
	toolcard --validate; or set failed 1
	git diff --check; or set failed 1
	if test $failed -ne 0
		echo "VERIFY FAILED" >&2
		exit 1
	end
	echo "VERIFY PASSED: hook templates, git hooks, tool cards, config gate, whitespace"
