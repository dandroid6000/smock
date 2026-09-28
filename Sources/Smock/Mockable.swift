//
//  Mockable.swift
//  Smock
//
//  Created by Dan Kane on 9/28/26.
//

/// Marks this type as `Mockable`, generating associated types including a `Mock`, `StubBuilder`, and `Verifier`, as well as typed functions
/// for generating instances.
///
/// Types are conditionally compiled for DEBUG builds only, as they are intended to only be used in tests.
///
/// - Note: This macro can only be attached to a `protocol` definition.
@attached(peer, names: suffixed(Mock), suffixed(StubBuilder), suffixed(Verifier), named(when), named(verify))
public macro Mockable() = #externalMacro(module: "SmockMacros", type: "MockableMacro")
