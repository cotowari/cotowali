module parser

import cotowali.ast
import cotowali.source { Pos }
import cotowali.token { Token }
import cotowali.symbols { Type, builtin_type }
import cotowali.errors { unreachable }

struct FnParamParsingInfo {
mut:
	name string
	typ  Type
	pos  Pos
}

struct FnSignatureParsingInfo {
mut:
	name    Token
	pipe_in Type = builtin_type(.void)
	params  []FnParamParsingInfo
	ret_typ Type = builtin_type(.void)
}

fn (mut p Parser) parse_fn_params(mut info FnSignatureParsingInfo) ? {
	p.consume_with_check(.l_paren) ?
	if _ := p.consume_if_kind_eq(.r_paren) {
		return
	}

	for {
		name_tok := p.consume_with_check(.ident) ?
		ts := p.parse_type() ?

		info.params << FnParamParsingInfo{
			name: name_tok.text
			pos: name_tok.pos
			typ: ts.typ
		}

		if array_info := ts.array_info() {
			if array_info.variadic {
				p.consume_with_check(.r_paren) ?
				break
			}
		}
		tail_tok := p.consume_with_check(.comma, .r_paren) ?
		match tail_tok.kind {
			.comma {}
			.r_paren { break }
			else { panic(unreachable()) }
		}
	}
}

fn (mut p Parser) parse_fn_signature_info() ?FnSignatureParsingInfo {
	p.consume_with_assert(.key_fn)
	mut info := FnSignatureParsingInfo{}

	if p.kind(1) != .l_paren {
		// kind(1) is:
		//
		//      v
		// fn f ( )
		//      ^
		//        v
		// fn int | f()
		//        ^
		//      v
		// fn [ ] int | f()
		//      ^
		info.pipe_in = (p.parse_type() ?).typ
		p.consume_with_check(.pipe) ?
	}

	info.name = p.consume_with_check(.ident) ?

	p.parse_fn_params(mut info) ?
	if p.kind(0) != .l_brace {
		info.ret_typ = (p.parse_type() ?).typ
	}

	return info
}

fn (mut p Parser) parse_fn_decl() ?ast.FnDecl {
	$if trace_parser ? {
		p.trace_begin(@FN)
		defer {
			p.trace_end()
		}
	}

	info := p.parse_fn_signature_info() ?
	mut outer_scope := p.scope
	p.open_scope(info.name.text)
	defer {
		p.close_scope()
	}
	mut params := []ast.Var{len: info.params.len}
	for i, param in info.params {
		params[i] = ast.Var{
			scope: p.scope
			pos: param.pos
			sym: p.scope.register_var(name: param.name, pos: param.pos, typ: param.typ) or {
				return p.duplicated_error(param.name, param.pos)
			}
		}
	}

	typ := outer_scope.lookup_or_register_fn_type(
		params: params.map(it.sym.typ)
		pipe_in: info.pipe_in
		ret: info.ret_typ
	).typ
	func := outer_scope.register_var(
		name: info.name.text
		pos: info.name.pos
		typ: typ
	) or { return p.duplicated_error(info.name.text, info.name.pos) }

	p.scope.owner = func

	has_body := p.kind(0) == .l_brace
	mut node := ast.FnDecl{
		parent_scope: outer_scope
		name: info.name.text
		params: params
		has_body: has_body
		typ: typ
	}
	if has_body {
		node.body = p.parse_block_without_new_scope() ?
	}
	return node
}