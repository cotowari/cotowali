module util

pub fn @in<T>(v T, low T, high T) bool {
	return low <= v && v <= high
}

pub fn in2<T>(v T, low1 T, high1 T, low2 T, high2 T) bool {
	return (low1 <= v && v <= high1) || (low2 <= v && v <= high2)
}

[inline]
pub fn nil_to_none<T>(ref &T) ?&T {
	return if isnil(ref) { none } else { ref }
}

pub fn panic_and_value<T>(msg string, v T) T {
	panic(msg)
	return v
}

pub fn struct_name<T>(v T) string {
	// SumTypeName(SumTypeName2(mod.Struct{
	mut s := v.str().split_into_lines()[0]
	s = s.split('(').last()
	s = s.split('{').first()

	// if struct has custom str, use typeof
	s = if s.len > 0 { s } else { typeof(v).name }

	return s.split('.').last()
}