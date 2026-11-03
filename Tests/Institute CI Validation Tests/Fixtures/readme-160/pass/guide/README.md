# swift-example-guide

Use `Example` when two values must be compared without making either conform to a protocol.

## Model

`Example<Value>` holds the comparison as a value, so one type can have several orderings.

## Laws

The comparison is a strict weak ordering: irreflexive, asymmetric and transitive.
