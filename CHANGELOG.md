## v0.4

- **Technically breaking**: A basically unknown functionality of pre-0.3 versions, using arbitrary column specifiers on the left-hand side, was removed. Instead, the behavior of using `{}` and `{n}` expressions on the left hand side was assimilated to the existing shortcut string syntax. `{}` or `{1}` refers to the name of the first column used, `{2}` to the second, etc. This allows to use transformation expressions on the used column names, such as `uppercase({})` or `split({2})[1]`.

## v0.3.3

- Fixed bug when column symbols were used inside braces.

## v0.3.2

- Added `@proprow`, `@eachindex` and `@groupindices` special function macros, which required compat to be raised to DataFrames v1.4.

## v0.3.0

- **Breaking**: The `$()` interpolation syntax is replaced by `{}` for single columns (or broadcasted multi-columns)
- Added `{{}}` for referring to multiple columns as a tuple.
- **Breaking**: No more flag macros, replaced by explit `@byrow`, `@bycol`, `@passmissing`, `@astable`.
- **Breaking**: `All()`, `Between()` and `Not()` have to be interpolated with `{}` and can't be used standalone anymore.

## v0.2.1

- Added ability to use multi-column expressions with `All()`, `Between()`, `Not()`, as well as any other multi-column identifier such as `$Real` for all columns of eltype `Real`.
- Added shortcut string option to specify renaming structures, e.g. `@transform(df, "sqrt_of_{}" = sqrt(All()))`.

## v0.2

- Added `@subset` argument for `@transform!` and `@select!` that performs a mutating transform on a subset of rows of a DataFrame.

## v0.1.2

- Fixed macro hygiene and enabled Julia 1.0.

## v0.1.1

- Added tuple destructuring syntax for the `@t` flag macro. [#14](https://github.com/jkrumbiegel/DataFrameMacros.jl/pull/14)

## v0.1

- Initial release.
