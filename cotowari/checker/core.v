module checker

import cotowari.ast
import cotowari.errors
import cotowari.source { Pos }
import cotowari.context { Context }

pub struct Checker {
mut:
	cur_file &ast.File = 0
	cur_fn   ast.FnDecl
	ctx      &Context
}

pub fn new_checker(ctx &Context) Checker {
	return Checker{
		ctx: ctx
	}
}

fn (mut c Checker) error(msg string, pos Pos) {
	c.ctx.errors.push(
		source: c.cur_file.source
		msg: msg
		pos: pos
	)
}
