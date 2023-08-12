//
//  RangeSliderView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/24/23.
//

import SwiftUI

struct RangeSliderView: View {
    //0 (0.0) -> 100% (1.0)
    @State private var selectedArea: (Double, Double) = (0.0,1.0)
    
    let minValue: Double
    let maxValue: Double
    
    let decimalPlaces: UInt8
    
    let valuePrefix: String
    let valueSuffix: String
    
    let rangeChangedAction: (_ range: (Double,Double)) -> Void
    
    var selectedRange: (Double, Double) {
        get {
            let range = maxValue-minValue
            let roundModifier: Double = pow(10 as Double,Double(Int(decimalPlaces)))
            return (round((minValue+selectedArea.0*range)*roundModifier)/roundModifier,
                    round((minValue+selectedArea.1*range)*roundModifier)/roundModifier)
        }
    }
    
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                VStack {
                    ZStack {
                        Rectangle()
                            .fill(.clear)
                            .frame(maxWidth: .infinity, maxHeight: 5)
                            .background {
                                HStack(spacing: 0) {
                                    if (geometry.size.width-20)*selectedArea.0 > 0 {
                                        Color.gray
                                            .opacity(0.75)
                                            .frame(width: (geometry.size.width-20)*selectedArea.0)
                                    }
                                    
                                    if (geometry.size.width-20)*(selectedArea.1-selectedArea.0) >= 20 {
                                        Color.clear.frame(width: 20)
                                        Color.blue
                                            .opacity(0.6)
                                            .frame(width: (geometry.size.width-20)*(selectedArea.1-selectedArea.0)-20)
                                        Color.clear.frame(width: 20)
                                    } else {
                                        Color.clear.frame(width: (geometry.size.width-20)*(selectedArea.1-selectedArea.0)+20)
                                    }
                                    if (geometry.size.width-20)*(1.0-selectedArea.1) > 0 {
                                        Color.gray
                                            .opacity(0.75)
                                            .frame(width: (geometry.size.width-20)*(1.0-selectedArea.1))
                                    }
                                }
                                .cornerRadius(2.5)
                            }
                        Circle()
                            .strokeBorder(.gray, lineWidth: 1)
                            .background(Circle().fill(Color.black.opacity(0.22)))
                            .offset(CGSize(width: (geometry.size.width-20)*selectedArea.0-(geometry.size.width-20)*0.5, height: 0))
                            .gesture(DragGesture()
                                .onChanged({ val in
                                    if val.location.x-5 >= 0.0 && (val.location.x-5) <= self.selectedArea.1*(geometry.size.width-20) {
                                        self.selectedArea.0 = (val.location.x-5)/(geometry.size.width-20)
                                    } else if val.location.x-5 < 0.0 {
                                        self.selectedArea.0 = 0.0
                                    } else {
                                        self.selectedArea.0 = self.selectedArea.1
                                    }
                                }))
                        Circle()
                            .strokeBorder(.gray, lineWidth: 1)
                            .background(Circle().fill(Color.black.opacity(0.22)))
                            .offset(CGSize(width: (geometry.size.width-20)*selectedArea.1-(geometry.size.width-20)*0.5, height: 0))
                            .gesture(
                                DragGesture()
                                    .onChanged({ val in
                                        if (val.location.x-5) <= (geometry.size.width-20) && (val.location.x-5) >= self.selectedArea.0*(geometry.size.width-20) {
                                            self.selectedArea.1 = (val.location.x-5)/(geometry.size.width-20)
                                            print(selectedArea.1)
                                        } else if val.location.x-5 > geometry.size.width-20 {
                                            self.selectedArea.1 = 1.0
                                        } else {
                                            self.selectedArea.1 = self.selectedArea.0
                                        }
                                    })
                            )
                    }
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    .frame(height: 20)
                }
            }
            .frame(height: 20)
            HStack {
                Text("[f/\(String(format: "%.\(decimalPlaces)f", selectedRange.0)), f/\(String(format: "%.\(decimalPlaces)f", selectedRange.1))]")
            }
        }
        .onChange(of: selectedArea.0-selectedArea.1, perform: { v in
            rangeChangedAction(selectedRange)
        })
    }
}

struct RangeSliderView_Previews: PreviewProvider {
    static var previews: some View {
        RangeSliderView(minValue: 1.0, maxValue: 2.0, decimalPlaces: 2, valuePrefix: "f/", valueSuffix: "") { range in
            
        }
    }
}
