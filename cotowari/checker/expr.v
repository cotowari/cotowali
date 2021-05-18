module checker

import cotowari.ast { Expr }
import cotowari.source { Pos }
import cotowari.symbols { FunctionTypeInfo, TypeSymbol }

fn (mut c Checker) expr(expr Expr) {
	match mut expr {
		ast.CallFn { c.call_expr(mut expr) }
		ast.InfixExpr { c.infix_expr(expr) }
		ast.IntLiteral {}
		ast.StringLiteral {}
		ast.Pipeline {}
		ast.PrefixExpr {}
		ast.Var {}
	}
}

fn (mut c Checker) infix_expr(expr ast.InfixExpr) {
	c.check_types(
		want: expr.left.type_symbol()
		want_label: 'left'
		got: expr.right.type_symbol()
		got_label: 'right'
		pos: expr.pos()
		synmetric: true
	) or { return }
}

fn (mut c Checker) check_call_args(params []TypeSymbol, args []TypeSymbol, pos Pos) ? {
	if params.len != args.len {
		c.error('expected $params.len arguments, but got $args.len', pos)
		return none
	}
	return
}

fn (mut c Checker) call_expr(mut expr ast.CallFn) {
	name := expr.func.name()
	pos := Expr(expr).pos()

	func := expr.scope.lookup_var(name) or {
		c.error('function `$name` is not defined', pos)
		return
	}

	ts := func.type_symbol()
	fn_info := ts.fn_info() or {
		c.error('`$name` is not function (`$ts.name`)', pos)
		return
	}

	params := fn_info.params.map(expr.scope.must_lookup_type(it))
	args := expr.args.map(it.type_symbol())
	c.check_call_args(params, args, pos) or { return }
}
