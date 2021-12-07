//
//  File.swift
//  
//
//  Created by Vitor Jundi Moriya on 25/10/21.
//

import Foundation

extension Double {
    /// Limita o valor para o range `[min, max]`.
    ///
    /// - Returns: O valor dentro do intervalo fechado
    ///  `[min, max]` que está mais próximo de `self`.
    @inlinable
    func clamped(from min: Double = -Self.infinity, upTo max: Double = Self.infinity) -> Double {
        if self <= min {
            return min
        } else if self >= max {
            return max
        } else {
            return self
        }
    }
}
