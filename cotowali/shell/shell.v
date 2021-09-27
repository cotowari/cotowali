// Copyright (c) 2021 zakuro <z@kuro.red>. All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
module shell

import os
import cotowali.context { Context }
import cotowali.util { nil_to_none }

pub struct Shell {
	ctx &Context
mut:
	backend_process &os.Process = 0
}

fn new_sh_process(command string) ?&os.Process {
	mut p := os.new_process(os.find_abs_path_of_executable(command) or {
		return error('command not found: $command')
	})

	p.set_redirect_stdio()
	return p
}

pub fn new_shell(sh string, ctx &Context) ?Shell {
	return Shell{
		ctx: ctx
		backend_process: new_sh_process(sh) ?
	}
}

fn (shell &Shell) backend_process() ?&os.Process {
	return nil_to_none(shell.backend_process)
}

pub fn (mut shell Shell) is_alive() bool {
	mut p := shell.backend_process() or { return false }
	return p.is_alive()
}

pub fn (mut shell Shell) start() {
	mut p := shell.backend_process() or { return }
	p.run()
}

pub fn (mut shell Shell) close() {
	mut p := shell.backend_process() or { return }
	p.close()
}

pub fn (mut shell Shell) stdin_write(s string) {
	mut p := shell.backend_process() or { return }
	p.stdin_write(s)
}

pub fn (mut shell Shell) stdout_read() string {
	mut p := shell.backend_process() or { return '' }
	// p.stdout_read() blocks until found 1 or more output.
	// To avoid this problem, print extra character, then trim it.
	p.stdin_write('printf ":"\n')
	mut stdout := p.stdout_read()
	return stdout[..stdout.len - 1]
}

pub fn (mut shell Shell) stderr_read() string {
	mut p := shell.backend_process() or { return '' }
	// same as stdout_rerad
	p.stdin_write('printf ":" >&2 \n')
	mut stderr := p.stderr_read()
	return stderr[..stderr.len - 1]
}
