// Copyright (c) 2021 zakuro <z@kuro.red>. All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
module parser

import cotowali.ast
import cotowali.source { Pos }
import cotowali.token { Token }
import cotowali.symbols {
	Scope,
	Type,
	TypeSymbol,
	Var,
	builtin_type,
	new_placeholder_var,
}
import cotowali.messages { unreachable }
import cotowali.util { struct_name }

struct FnParamParsingInfo {
mut:
	name string
	ts   &TypeSymbol
	pos  Pos
}

fn (mut p Parser) register_fn_param(param FnParamParsingInfo) ?ast.Var {
	param_sym := p.scope.register_var(name: param.name, pos: param.pos, typ: param.ts.typ) or {
		new_placeholder_var(param.name, param.pos)
		return p.error(err.msg, param.pos)
	}
	return ast.Var{
		ident: ast.Ident{
			scope: p.scope
			pos: param.pos
			text: param.name
		}
		sym: param_sym
	}
}

enum FnSignatureKind {
	default
	method
	infix_op
	prefix_op
}

struct FnSignatureParsingInfo {
mut:
	kind          FnSignatureKind = .default
	name          Token
	pipe_in_param FnParamParsingInfo
	params        []FnParamParsingInfo
	variadic      bool
	ret_typ       Type = builtin_type(.void)
}

fn (info FnSignatureParsingInfo) register_sym(mut scope Scope) ?&Var {
	return match info.kind {
		.default {
			scope.register_fn(
				name: info.name.text
				pos: info.name.pos
				params: info.params.map(it.ts.typ)
				variadic: info.variadic
				pipe_in: info.pipe_in_param.ts.typ
				ret: info.ret_typ
			) ?
		}
		.method {
			mut receiver := info.params[0].ts
			receiver.register_method(
				name: info.name.text
				pos: info.name.pos
				params: info.params[1..].map(it.ts.typ)
				variadic: info.variadic
				pipe_in: info.pipe_in_param.ts.typ
				ret: info.ret_typ
			) ?
		}
		.infix_op {
			scope.register_infix_op(info.name, // name is op token
				pos: info.name.pos
				params: info.params.map(it.ts.typ)
				variadic: info.variadic
				pipe_in: info.pipe_in_param.ts.typ
				ret: info.ret_typ
			) ?
		}
		.prefix_op {
			scope.register_prefix_op(info.name, // name is op token
				pos: info.name.pos
				params: info.params.map(it.ts.typ)
				variadic: info.variadic
				pipe_in: info.pipe_in_param.ts.typ
				ret: info.ret_typ
			) ?
		}
	}
}

fn (mut p Parser) parse_fn_params(mut info FnSignatureParsingInfo) ? {
	p.consume_with_check(.l_paren) ?
	if _ := p.consume_if_kind_eq(.r_paren) {
		return
	}

	for {
		name_tok := p.consume_with_check(.ident) ?
		p.consume_with_check(.colon) ?
		ts := p.parse_type() ?

		info.params << FnParamParsingInfo{
			name: name_tok.text
			pos: name_tok.pos
			ts: ts
		}

		if sequence_info := ts.sequence_info() {
			p.consume_with_check(.r_paren) ?
			// varargs is normal (non variadic) array
			info.params[info.params.len - 1].ts = p.scope.lookup_or_register_array_type(
				elem: sequence_info.elem
			)
			info.variadic = true
			break
		}
		tail_tok := p.consume_with_check(.comma, .r_paren) ?
		match tail_tok.kind {
			.comma {}
			.r_paren { break }
			else { panic(unreachable('')) }
		}
	}
}

fn (mut p Parser) next_is_receiver_syntax() bool {
	// fn ( x : Type ) (int, int) |> f()
	//    | | +- kind(2) == .colon
	//    | +--- kind(1) == .ident
	//    +-|--- kind(0) == .l_paren
	//    | | +  kind(2) == .ident
	// fn ( x Type ) f() // frequently encountered invalid syntax.
	return p.kind(0) == .l_paren && p.kind(1) == .ident && p.kind(2) in [.colon, .ident]
}

fn (mut p Parser) parse_receiver() ?FnParamParsingInfo {
	p.consume_with_assert(.l_paren)
	{
		name_tok := p.consume_with_assert(.ident)
		name := name_tok.text
		name_pos := name_tok.pos

		p.consume_with_check(.colon) ?
		ts := (p.parse_type() ?)

		p.consume_with_check(.r_paren) ?
		return FnParamParsingInfo{
			name: name
			pos: name_pos
			ts: ts
		}
	}
}

fn (mut p Parser) parse_fn_signature_info() ?FnSignatureParsingInfo {
	p.consume_with_assert(.key_fn)
	mut info := FnSignatureParsingInfo{}
	info.pipe_in_param.ts = p.scope.must_lookup_type(builtin_type(.void))

	// fn ( x : Type ) (int, int) |> f()
	mut has_receiver := false
	if p.next_is_receiver_syntax() {
		rec := p.parse_receiver() ?
		//     vvvvvvvvvvv parsed receiver
		// fn ( x : Type ) |> f()
		//                 ^^ kind == .pipe
		if _ := p.consume_if_kind_eq(.pipe) {
			info.pipe_in_param = rec
		} else {
			info.params << rec
			has_receiver = true
		}
	}

	if p.next_is_receiver_syntax() {
		pipe_in := p.parse_receiver() ?
		//                vvvvvvvvvv
		// fn (rec: Type) (in: Type) |> f()
		if _ := p.consume_with_check(.pipe) {
			info.pipe_in_param = pipe_in
		}
	} else if !((p.kind(0) == .ident || p.kind(0).@is(.op)) && p.kind(1) == .l_paren) {
		//    v kind(0) == .ident
		// fn f ( )
		//      ^ kind(1) == .l_paren
		//
		//    vvv kind(0) == .ident
		// fn int |> f()
		//        ^^ kind(1) != .l_paren
		//
		// fn + (v: int)
		//    ^ kind(0).@is(.op)
		//
		// fn (lhs: int) + (rhs: int)
		//               ^ kind(0).@is(.op)
		//
		//    v kind(0) != .ident
		// fn [ ] int |> f()
		//      ^ kind(1) != .l_paren
		//
		//    vvv kind(0) != .ident
		// fn ... int |> f()
		//        ^^^ kind(1) != .l_paren
		//
		//    vvv kind(0) != .ident
		// fn ... ( int, int ) |> f()
		//        ^ kind(1) == .l_paren
		info.pipe_in_param.ts = (p.parse_type() ?)
		p.consume_with_check(.pipe) ?
	}

	if name := p.consume_if_kind_is(.op) {
		info.name = name
		if has_receiver {
			info.kind = .infix_op
		} else {
			info.kind = .prefix_op
		}
	} else {
		info.name = p.consume_with_check(.ident) ?
		if has_receiver {
			info.kind = .method
		}
	}

	p.parse_fn_params(mut info) ?
	if p.kind(0) in [.l_brace, .eol] {
		// implicit void
		return info
	}

	//        vv
	// fn f() |> int
	// fn f(): int
	//       ^
	p.consume_with_check(.colon, .pipe) ?
	info.ret_typ = (p.parse_type() ?).typ

	return info
}

fn (mut p Parser) parse_fn_decl() ?ast.FnDecl {
	$if trace_parser ? {
		p.trace_begin(@FN)
		defer {
			p.trace_end()
		}
	}

	mut has_error := false
	info := p.parse_fn_signature_info() ?
	mut outer_scope := p.scope

	mut sym_name := if info.name.kind == .ident {
		info.name.text
	} else {
		op_ident := info.name.kind.str_for_ident()
		type_names := info.params.map(it.ts.name).join('_')
		op_ident + type_names
	}
	sym := info.register_sym(mut outer_scope) or {
		has_error = true
		p.error(err.msg, info.name.pos)
		// use different name for duplicated function to create another scope
		sym_name += util.rand<u64>().str()
		new_placeholder_var(sym_name, info.name.pos)
	}

	p.open_scope(sym_name)
	defer {
		p.close_scope()
	}
	p.scope.owner = sym

	mut params := []ast.Var{len: info.params.len}
	for i, param in info.params {
		if registered := p.register_fn_param(param) {
			params[i] = registered
		} else {
			has_error = true
			continue
		}
	}

	has_body := p.kind(0) == .l_brace
	mut node := ast.FnDecl{
		parent_scope: outer_scope
		sym: sym
		params: params
		has_body: has_body
		is_method: info.kind == .method
	}
	if info.pipe_in_param.name != '' {
		if registered := p.register_fn_param(info.pipe_in_param) {
			node.pipe_in_param = registered
		} else {
			has_error = true
		}
	}

	if has_body {
		if body := p.parse_block_without_new_scope() {
			node.body = body
		} else {
			has_error = true
		}
	}
	if has_error {
		return none
	}
	return node
}

fn (mut p Parser) parse_call_args() ?[]ast.Expr {
	p.skip_eol()
	if p.kind(0) == .r_paren {
		return []
	}

	mut args := []ast.Expr{cap: 2}
	for {
		args << p.parse_expr(.toplevel) ?
		p.skip_eol()

		if p.kind(0) == .r_paren {
			break
		}

		p.consume_with_check(.comma) ?
		p.skip_eol()

		if p.kind(0) == .r_paren {
			// ends with trailing comman
			break
		}
	}
	return args
}

fn (mut p Parser) parse_call_expr_with_left(left ast.Expr) ?ast.Expr {
	$if trace_parser ? {
		p.trace_begin(@FN, '${struct_name(left)}{...}')
		defer {
			p.trace_end()
		}
	}

	p.consume_with_assert(.l_paren)

	mut args := p.parse_call_args() ?
	r_paren := p.consume_with_check(.r_paren) ?
	return ast.CallExpr{
		scope: p.scope
		pos: left.pos().merge(r_paren.pos)
		func: left
		args: args
	}
}
