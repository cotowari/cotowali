// Copyright (c) 2021 zakuro <z@kuro.red>. All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
module pwsh

import cotowali.ast { Expr }
import cotowali.messages { unreachable }
import cotowali.symbols { builtin_type }

[params]
struct ExprOpt {}

fn (mut e Emitter) expr(expr Expr, opt ExprOpt) {
	match expr {
		ast.AsExpr { e.expr(expr.expr, opt) }
		ast.BoolLiteral { e.bool_literal(expr, opt) }
		ast.CallCommandExpr { e.call_command_expr(expr, opt) }
		ast.CallExpr { e.call_expr(expr, opt) }
		ast.DefaultValue { e.default_value(expr, opt) }
		ast.DecomposeExpr { e.decompose_expr(expr, opt) }
		ast.FloatLiteral { e.float_literal(expr, opt) }
		ast.IntLiteral { e.int_literal(expr, opt) }
		ast.ParenExpr { e.paren_expr(expr, opt) }
		ast.Pipeline { e.pipeline(expr, opt) }
		ast.InfixExpr { e.infix_expr(expr, opt) }
		ast.IndexExpr { e.index_expr(expr, opt) }
		ast.MapLiteral { e.map_literal(expr, opt) }
		ast.NamespaceItem { e.namespace_item(expr, opt) }
		ast.PrefixExpr { e.prefix_expr(expr, opt) }
		ast.SelectorExpr { e.selector_expr(expr, opt) }
		ast.ArrayLiteral { e.array_literal(expr, opt) }
		ast.StringLiteral { e.string_literal(expr, opt) }
		ast.Var { e.var_(expr, opt) }
	}
}

fn (mut e Emitter) decompose_expr(expr ast.DecomposeExpr, opt ExprOpt) {
	panic('unimplemented')
}

fn (mut e Emitter) default_value(expr ast.DefaultValue, opt ExprOpt) {
	ts := Expr(expr).type_symbol()
	if tuple_info := ts.tuple_info() {
		e.paren_expr(ast.ParenExpr{
			scope: expr.scope
			exprs: tuple_info.elements.map(Expr(ast.DefaultValue{
				typ: it.typ
				scope: expr.scope
			}))
		}, opt)
		return
	}

	e.write(match ts.resolved().typ {
		builtin_type(.bool) { r'$false' }
		builtin_type(.int), builtin_type(.float) { '0' }
		else { '""' }
	})
}

fn (mut e Emitter) index_expr(expr ast.IndexExpr, opt ExprOpt) {
	panic('unimplemented')
}

fn (mut e Emitter) infix_expr(expr ast.InfixExpr, opt ExprOpt) {
	op := expr.op
	if !op.kind.@is(.infix_op) {
		panic(unreachable('not a infix op'))
	}

	ts := Expr(expr).type_symbol()
	ts_resolved := ts.resolved()
	is_int := ts_resolved.typ == builtin_type(.int)

	if expr.left.type_symbol().resolved().kind() == .tuple
		|| expr.right.type_symbol().resolved().kind() == .tuple {
		e.infix_expr_for_tuple(expr, opt)
		return
	}

	if op.kind == .pow {
		if is_int {
			e.write('[int]')
		}
		e.write('[Math]::Pow(')
		{
			e.expr(expr.left)
			e.write(', ')
			e.expr(expr.right)
		}
		e.write(')')
		return
	}

	op_text := match op.kind {
		.eq { '-eq' }
		.ne { '-ne' }
		.logical_and { '-and' }
		.logical_or { '-or' }
		.plus { '+' }
		.minus { '-' }
		.mul { '*' }
		.div { '/' }
		.mod { '%' }
		else { panic('unimplemented') }
	}

	if op.kind == .div && is_int {
		e.write('[int][Math]::Floor(')
		defer {
			e.write(')')
		}
	}

	e.expr(expr.left)
	e.write(' $op_text ')
	e.expr(expr.right)
}

fn (mut e Emitter) infix_expr_for_tuple(expr ast.InfixExpr, opt ExprOpt) {
	match expr.op.kind {
		.eq { e.pwsh_array_eq(expr.left, expr.right) }
		.ne { e.pwsh_array_ne(expr.left, expr.right) }
		.plus { e.pwsh_array_concat(expr.left, expr.right) }
		else { panic('unimplemented') }
	}
}

fn (mut e Emitter) namespace_item(expr ast.NamespaceItem, opt ExprOpt) {
	if !expr.is_resolved() {
		panic(unreachable('unresolved namespace item'))
	}
	e.expr(expr.item, opt)
	panic('unimplemented')
}

fn (mut e Emitter) paren_expr(expr ast.ParenExpr, opt ExprOpt) {
	e.write('(')
	for i, subexpr in expr.exprs {
		if i > 0 {
			e.write(', ')
		}
		e.expr(subexpr, opt)
	}
	e.write(')')
}

fn (mut e Emitter) prefix_expr(expr ast.PrefixExpr, opt ExprOpt) {
	op := expr.op
	if !op.kind.@is(.prefix_op) {
		panic(unreachable('not a prefix op'))
	}

	e.write(match op.kind {
		.not { '! ' }
		else { panic('unimplemented') }
	})
	e.expr(expr.expr)
}

fn (mut e Emitter) pipeline(expr ast.Pipeline, opt ExprOpt) {
	panic('unimplemented')
}

fn (mut e Emitter) selector_expr(expr ast.SelectorExpr, opt ExprOpt) {
	// selector expr is used for only method call now.
	// method call is handled by call_expr. Nothing to do
}

fn (mut e Emitter) var_(v ast.Var, opt ExprOpt) {
	e.write('\$${e.ident_for(v)}')
}