//
//  ObservedProvider.swift
//  ModelMana
//
//  Property wrapper for observing AIProvider instances in SwiftUI
//

import SwiftUI

/// Property wrapper for observing concrete AIProvider types
/// Uses the @Observable observation mechanism
@propertyWrapper
struct ObservedProvider<P: AIProvider>: DynamicProperty {
    @State private var object: P

    init(wrappedValue: P) {
        self.object = wrappedValue
    }

    var wrappedValue: P {
        get { object }
        mutating set { object = newValue }
    }
}
