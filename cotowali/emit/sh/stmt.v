module sh

import cotowali.ast { Stmt }
import cotowali.symbols { builtin_type }

fn (mut e Emitter) stmts(stmts []Stmt) {
	for stmt in stmts {
		e.stmt(stmt)
	}
}

fn (mut e Emitter) stmt(stmt Stmt) {
	match stmt {
		ast.AssertStmt { e.assert_stmt(stmt) }
		ast.FnDecl { e.fn_decl(stmt) }
		ast.Block { e.block(stmt) }
		ast.Expr { e.expr_stmt(stmt) }
		ast.AssignStmt { e.assign_stmt(stmt) }
		ast.EmptyStmt { e.writeln('') }
		ast.ForInStmt { e.for_in_stmt(stmt) }
		ast.IfStmt { e.if_stmt(stmt) }
		ast.InlineShell { e.writeln(stmt.text) }
		ast.ReturnStmt { e.return_stmt(stmt) }
		ast.RequireStmt { e.require_stmt(stmt) }
		ast.WhileStmt { e.while_stmt(stmt) }
	}
}

fn (mut e Emitter) expr_stmt(stmt ast.Expr) {
	discard_stdout := e.inside_fn
		&& if stmt is ast.CallExpr { e.cur_fn.function_info().ret != builtin_type(.void) } else { true }
	e.expr(stmt, as_command: true, discard_stdout: discard_stdout, writeln: true)
}

fn (mut e Emitter) assert_stmt(stmt ast.AssertStmt) {
	e.write('if ')
	e.sh_test_command(fn (mut e Emitter, cond ast.Expr) {
		e.sh_test_cond_is_true(cond)
	}, stmt.expr)
	e.writeln('')
	e.writeln('then')
	e.writeln(':')

	e.write_block({ open: 'else', close: 'fi' }, fn (mut e Emitter, stmt ast.AssertStmt) {
		e.writeln("echo 'LINE $stmt.key_pos.line: assertion failed' >&2")
		e.writeln('exit 1')
	}, stmt)
}

fn (mut e Emitter) block(block ast.Block) {
	e.stmts(block.stmts)
}

fn (mut e Emitter) if_stmt(stmt ast.IfStmt) {
	for i, branch in stmt.branches {
		mut is_else := i == stmt.branches.len - 1 && stmt.has_else
		if is_else {
			e.writeln('else')
		} else {
			e.write(if i == 0 { 'if ' } else { 'elif ' })
			e.sh_test_command(fn (mut e Emitter, cond ast.Expr) {
				e.sh_test_cond_is_true(cond)
			}, branch.cond)
			e.writeln('')
			e.writeln('then')
		}
		e.indent()
		e.block(branch.body)
		e.unindent()
	}
	e.writeln('fi')
}

fn (mut e Emitter) for_in_stmt(stmt ast.ForInStmt) {
	e.write('for ${e.ident_for(stmt.val)} in ')
	e.expr(stmt.expr, expand_array: true, writeln: true)
	e.write_block({ open: 'do', close: 'done' }, fn (mut e Emitter, stmt ast.ForInStmt) {
		e.block(stmt.body)
	}, stmt)
}

fn (mut e Emitter) return_stmt(stmt ast.ReturnStmt) {
	e.expr(stmt.expr, as_command: true, writeln: true)
	e.writeln('return 0')
}

fn (mut e Emitter) require_stmt(stmt ast.RequireStmt) {
	e.file(stmt.file)
}

fn (mut e Emitter) while_stmt(stmt ast.WhileStmt) {
	e.write('while ')
	e.sh_test_command(fn (mut e Emitter, cond ast.Expr) {
		e.sh_test_cond_is_true(cond)
	}, stmt.cond)
	e.writeln('')
	e.write_block({ open: 'do', close: 'done' }, fn (mut e Emitter, stmt ast.WhileStmt) {
		e.block(stmt.body)
	}, stmt)
}