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
