module sh

import io
import cotowari.config { Config }
import cotowari.emit.code
import cotowari.ast { File }

pub struct Emitter {
mut:
	cur_file  &File = 0
	inside_fn bool
	w         code.Writer
}

[inline]
pub fn new_emitter(out io.Writer, config &Config) Emitter {
	return Emitter{
		w: code.new_writer(out, config)
	}
}

[inline]
fn (mut e Emitter) writeln(s string) {
	e.w.writeln(s)
}

[inline]
fn (mut e Emitter) write(s string) {
	e.w.write(s)
}

[inline]
fn (mut e Emitter) indent() {
	e.w.indent()
}

[inline]
fn (mut e Emitter) unindent() {
	e.w.unindent()
}

[inline]
fn (mut e Emitter) new_tmp_var() string {
	return e.w.new_tmp_var()
}