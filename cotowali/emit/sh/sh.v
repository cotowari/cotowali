// Copyright (c) 2021 zakuro <z@kuro.red>. All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
module sh

import cotowali.ast

const (
	true_value  = "'true'"
	false_value = "'false'"
)

fn (mut e Emitter) sh_test_cond_infix(left ExprOrString, op string, right ExprOrString) {
	e.expr_or_string(left)
	e.write(' $op ')
	e.expr_or_string(right)
}

fn (mut e Emitter) sh_test_cond_is_true(expr ExprOrString) {
	e.sh_test_cond_infix(expr, ' = ', '$sh.true_value')
}

fn (mut e Emitter) sh_test_command<T>(f fn (mut Emitter, T), v T) {
	e.write('[ ')
	f(mut e, v)
	e.write(' ]')
}

fn (mut e Emitter) sh_result_to_bool() {
	e.write(' && echo $sh.true_value || echo $sh.false_value')
}

fn (mut e Emitter) sh_test_command_as_bool<T>(f fn (mut Emitter, T), v T) {
	e.write('"\$( ')
	e.sh_test_command(f, v)
	e.sh_result_to_bool()
	e.write(' )"')
}

fn (mut e Emitter) sh_test_command_for_expr<T>(f fn (mut Emitter, T), v T, opt ExprOpt) {
	if opt.as_condition {
		e.sh_test_command(f, v)
	} else {
		e.sh_test_command_as_bool(f, v)
	}
}

fn (mut e Emitter) sh_command_substitution<T>(f fn (mut Emitter, T), v T) {
	e.write('\$( ')
	f(mut e, v)
	e.write(' )')
}

fn (mut e Emitter) sh_awk_infix_expr(expr ast.InfixExpr) {
	mut awk_expr := '\$1 $expr.op.text \$2'
	if expr.op.kind.@is(.comparsion_op) {
		awk_expr = '($awk_expr ? 1 : 0)'
	}
	awk := "awk '{ print $awk_expr }'"

	e.write(r'"$(echo ')
	{
		e.expr(expr.left)
		e.write(' ')
		e.expr(expr.right)
	}
	e.write(' | $awk )"')
}
