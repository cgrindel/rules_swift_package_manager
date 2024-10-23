//
//  ContentView.swift
//  ShakeIOSExample
//
//  Created by Chuck Grindel on 9/27/23.
//

import SwiftUI
import SingleFactorAuth

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
        let singleFactorAuthArgs = SingleFactorAuthArgs(
        web3AuthClientId: "<Your Client Id>",
        network: Web3AuthNetwork.SAPPHIRE_MAINNET)
        let singleFactoreAuth = SingleFactorAuth(params: SFAParams)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
