//
//  AppearancePlaygroundView.swift
//  PaymentSheet Example
//
//  Created by Yuki Tokuhiro on 9/14/20.
//  Copyright © 2020 stripe-ios. All rights reserved.
//

import StripePaymentSheet
import SwiftUI

@available(iOS 14.0, *)
struct AppearancePlaygroundView: View {
    @State var appearance: PaymentSheet.Appearance
    var doneAction: ((PaymentSheet.Appearance) -> Void) = { _ in }

    init(appearance: PaymentSheet.Appearance, doneAction: @escaping ((PaymentSheet.Appearance) -> Void)) {
        _appearance = State<PaymentSheet.Appearance>(initialValue: appearance)
        self.doneAction = doneAction
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Colors")) {
                    ColorPicker("primary", selection: Binding(
                        get: { Color(self.appearance.colors.primary) },
                        set: { self.appearance.colors.primary = UIColor($0) }
                    ))
                    ColorPicker("background", selection: Binding(
                        get: { Color(self.appearance.colors.background) },
                        set: { self.appearance.colors.background = UIColor($0) }
                    ))
                    ColorPicker("componentBackground", selection: Binding(
                        get: { Color(self.appearance.colors.componentBackground) },
                        set: { self.appearance.colors.componentBackground = UIColor($0) }
                    ))
                    ColorPicker("componentBorder", selection: Binding(
                        get: { Color(self.appearance.colors.componentBorder) },
                        set: { self.appearance.colors.componentBorder = UIColor($0) }
                    ))
                    ColorPicker("componentText", selection: Binding(
                        get: { Color(self.appearance.colors.componentText) },
                        set: { self.appearance.colors.componentText = UIColor($0) }
                    ))
                    ColorPicker("danger", selection: Binding(
                        get: { Color(self.appearance.colors.danger) },
                        set: { self.appearance.colors.danger = UIColor($0) }
                    ))
                }

                Section(header: Text("Miscellaneous")) {
                    Stepper(String(format: "cornerRadius: %.1f", appearance.cornerRadius ?? 0.0), value: Binding(
                        get: { self.appearance.cornerRadius ?? 0.0 },
                        set: { self.appearance.cornerRadius = $0 }
                    ), in: 0 ... 30)
                    Stepper(String(format: "borderWidth: %.1f", appearance.borderWidth), value: Binding(
                        get: { self.appearance.borderWidth },
                        set: { self.appearance.borderWidth = $0 }
                    ), in: 0.0 ... 2.0, step: 0.5)
                }

                Button {
                    appearance = PaymentSheet.Appearance()
                    doneAction(appearance)
                } label: {
                    Text("Reset Appearance")
                }

            }.navigationTitle("Appearance")
            .toolbar {
                Button("Done") {
                    doneAction(appearance)
                }
            }
        }
    }
}

struct AppearancePlaygroundView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 14.0, *) {
            AppearancePlaygroundView(appearance: PaymentSheet.Appearance(), doneAction: { _ in })
        }
    }
}