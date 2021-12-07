//
//  File.swift
//
//
//  Created by Vitor Jundi Moriya on 25/10/21.
//

import Foundation

/// Executa a função, marcando o tempo demorado.
///
/// - Returns: tempo demorado e valor retornado.
@inlinable
func withTiming<T>(run: () throws -> T) rethrows -> (elapsed: Double, value: T) {
    let start = DispatchTime.now()
    let value = try run()
    let end = DispatchTime.now()

    let diff = end.uptimeNanoseconds - start.uptimeNanoseconds
    let elapsed = Double(diff) / 1E9
    return (elapsed, value)
}

/// Executa a função async, marcando o tempo demorado.
///
/// - Returns: tempo demorado e valor retornado.
@inlinable
func withTiming<T>(run: () async throws -> T) async rethrows -> (elapsed: Double, value: T) {
    let start = DispatchTime.now()
    let value = try await run()
    let end = DispatchTime.now()

    let diff = end.uptimeNanoseconds - start.uptimeNanoseconds
    let elapsed = Double(diff) / 1E9
    return (elapsed, value)
}

/// Executa a função, marcando o tempo demorado.
///
/// - Returns: tempo demorado.
@inlinable
func withTiming(run: () throws -> Void) rethrows -> Double {
    try withTiming(run: run).elapsed
}

/// Executa a função async, marcando o tempo demorado.
///
/// - Returns: tempo demorado.
@inlinable
func withTiming(run: () async throws -> Void) async rethrows -> Double {
    try await withTiming(run: run).elapsed
}
