// Copyright (c) 2021 zakuro <z@kuro.red>. All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
module errors

import cotowali.source { Pos, Source }
import cotowali.token { Token }

[inline]
pub fn unreachable<T>(err T) string {
	return 'unreachable - This is a compiler bug (err: $err).'
}

pub type ErrOrWarn = Err | Warn

pub fn (e ErrOrWarn) label() string {
	return match e {
		Err { 'error' }
		Warn { 'warning' }
	}
}

// Err represents cotowali compile error
pub struct Err {
pub:
	source          &Source
	pos             Pos
	is_syntax_error bool
	// Implements IError
	msg  string
	code int
}

pub fn (lhs Err) < (rhs Err) bool {
	lhs_path, rhs_path := lhs.source.path, rhs.source.path
	return lhs_path < rhs_path || (lhs_path == rhs_path && lhs.pos.i < rhs.pos.i)
}

// Warn represents cotowali compile warning
pub struct Warn {
pub:
	source &Source
	pos    Pos
	// Implements IError
	msg  string
	code int
}

pub fn (lhs Warn) < (rhs Warn) bool {
	lhs_path, rhs_path := lhs.source.path, rhs.source.path
	return lhs_path < rhs_path || (lhs_path == rhs_path && lhs.pos.i < rhs.pos.i)
}

pub struct LexerErr {
pub:
	source &Source
	token  Token
	// Implements IError
	msg  string
	code int
}

pub struct LexerWarn {
pub:
	source &Source
	token  Token
	// Implements IError
	msg  string
	code int
}

pub fn (err LexerErr) to_err() Err {
	return Err{
		source: err.source
		pos: err.token.pos
		msg: err.msg
		code: err.code
	}
}

pub struct ErrorWithPos {
pub:
	pos  Pos
	msg  string
	code int
}
