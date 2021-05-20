module symbols

pub struct ArrayTypeInfo {
	elem Type
}

fn (info ArrayTypeInfo) typename(s &Scope) string {
	elem_ts := s.must_lookup_type(info.elem)
	return '[]$elem_ts.name'
}

pub fn (mut s Scope) lookup_or_register_array_type(info ArrayTypeInfo) TypeSymbol {
	return s.lookup_or_register_type(name: info.typename(s), info: info)
}

pub fn (s Scope) lookup_array_type(info ArrayTypeInfo) ?TypeSymbol {
	return s.lookup_type(info.typename(s))
}
