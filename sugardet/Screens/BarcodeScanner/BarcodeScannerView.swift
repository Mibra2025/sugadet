//
//  ContentView.swift
//  BarcodeScanner
//
//  Created by Sean Allen on 11/5/20.
//

import SwiftUI

struct BarcodeScannerView: View {
    @State private var isDarkMode: Bool = false

    @StateObject var viewModel = BarcodeScannerViewModel()
    
    var body: some View {
        NavigationView {
            ZStack{
                myGradient(isNight: isDarkMode)
                VStack {
                    ThemeChangeButton(isNight: $isDarkMode)

                    ScannerView(scannedCode: $viewModel.scannedCode,
                                alertItem: $viewModel.alertItem)
                        .frame(maxWidth: .infinity, maxHeight: 300)
                    
                    Spacer().frame(height: 60)
                    
                    Label("Scanned Barcode:", systemImage: "barcode.viewfinder")
                        .font(.title)
                    
                    Text(viewModel.statusText)
                        .bold()
                        .font(.largeTitle)
                        .foregroundColor(viewModel.statusTextColor)
                        .padding()
                }
            }
            .navigationTitle("Barcode Scanner")
            .alert(item: $viewModel.alertItem) { alertItem in
                Alert(title: Text(alertItem.title),
                      message: Text(alertItem.message),
                      dismissButton: alertItem.dismissButton)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        BarcodeScannerView()
    }
}

struct myGradient: View {
    var isNight: Bool;
    var body: some View {
        LinearGradient(gradient: Gradient(colors: [isNight ? .blue : .black,
                                                   isNight ? .white : .gray]),
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
        .ignoresSafeArea()
    }
}

struct ThemeChangeButton: View {
    @Binding var isNight: Bool;
    var body: some View {
        Button {
            isNight.toggle()
        } label: {
            Text("Change theme")
        }
    }
}
