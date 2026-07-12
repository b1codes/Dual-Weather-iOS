//
//  ConvertView.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 6/9/25.
//

import SwiftUI

struct ConvertView: View {
    private enum FocusedField {
        case fahrenheit, celsius
    }

    // @State properties to hold the string values from the TextFields.
    @State private var fahrenheitString = "32"
    @State private var celsiusString = "0"

    // @FocusState to track which TextField is currently active.
    @FocusState private var focusedField: FocusedField?

    // A number formatter to handle conversion between String and Double.
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        NavigationView {
            Form {
                // Section for Fahrenheit input
                Section(header: Text("Fahrenheit").font(.headline)) {
                    TextField("Enter temperature", text: $fahrenheitString)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .fahrenheit)
                        .onChange(of: fahrenheitString) { _, newValue in
                            // Only perform conversion if this text field is focused
                            guard focusedField == .fahrenheit else { return }

                            // Convert the string input to a Double
                            if let fahrenheitValue = Double(newValue) {
                                // Calculate Celsius and update the other text field
                                let celsiusValue = (fahrenheitValue - 32) * 5 / 9
                                self.celsiusString = numberFormatter.string(from: NSNumber(value: celsiusValue)) ?? ""
                            } else {
                                // Input isn't a complete number yet (empty, or mid-typing
                                // like "72.") — clear the other field rather than leaving
                                // a stale converted value that no longer matches what's typed.
                                self.celsiusString = ""
                            }
                        }
                }

                // Section for Celsius input
                Section(header: Text("Celsius").font(.headline)) {
                    TextField("Enter temperature", text: $celsiusString)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .celsius)
                        .onChange(of: celsiusString) { _, newValue in
                            // Only perform conversion if this text field is focused
                            guard focusedField == .celsius else { return }

                            // Convert the string input to a Double
                            if let celsiusValue = Double(newValue) {
                                // Calculate Fahrenheit and update the other text field
                                let fahrenheitValue = (celsiusValue * 9 / 5) + 32
                                self.fahrenheitString = numberFormatter.string(from: NSNumber(value: fahrenheitValue)) ?? ""
                            } else {
                                // Input isn't a complete number yet (empty, or mid-typing
                                // like "72.") — clear the other field rather than leaving
                                // a stale converted value that no longer matches what's typed.
                                self.fahrenheitString = ""
                            }
                        }
                }
            }
            .navigationTitle("Temperature Converter")
            // Add a toolbar to dismiss the keyboard
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Clear All") {
                        fahrenheitString = ""
                        celsiusString = ""
                    }
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }
}

#Preview {
    ConvertView()
}
