//
//  SearchOverlayView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/12/23.
//

import SwiftUI
import SwiftBSON

struct SearchOverlayView: View {
    let searchParser: SearchParser
    
    @State private var selectedAttribute: SearchFilter.Attribute = .None
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ButtonDetailViewPair(.DateBefore, parser: searchParser, label: {Label("Before Date", systemImage: "calendar")})
                ButtonDetailViewPair(.DateAfter, parser: searchParser, label: {Label("After Date", systemImage: "calendar")})
                ButtonDetailViewPair(.Camera, parser: searchParser, label: {Label("Camera", systemImage: "camera")})
                ButtonDetailViewPair(.Lens, parser: searchParser, label: {
                    if #available(macOS 12.3, iOS 15.4, *) {
                        return Label("Lens", systemImage: "camera.macro.circle")
                    } else if #available(macOS 11.0, iOS 14.0, *) {
                        return Label("Lens", systemImage: "camera.filters")
                    } else {
                        return Label("Lens", systemImage: "camera.circle")
                    }
                })
                ButtonDetailViewPair(.Aperture, parser: searchParser, label: {
                    if #available(macOS 11.0, iOS 14.0, *) {
                        return Label("Aperture", systemImage: "camera.aperture")
                    } else {
                        return Label("Aperture", systemImage: "sun.max.fill")
                    }
                })
                .cornerRadius(5)*/
                ButtonDetailViewPair(.FileExtension, parser: searchParser, label: {Label("File Extension", systemImage: "doc")})
            }
            .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
    }
    
    func select(_ attribute: SearchFilter.Attribute) {
        withAnimation {
            self.selectedAttribute=attribute
        }
    }
}
struct SearchOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        SearchOverlayView(searchParser: SearchParser(mongo_holder: MongoClientHolder()))
    }
}

struct OverlayButtonStyle: ButtonStyle {
    @StateObject var searchParser: SearchParser
    let attribute: SearchFilter.Attribute
    let darkMode: Bool
    let cornerRadius: CGFloat
    
    private var color: Color {
        get {
            if(attribute == .Portrait || attribute == .Landscape) {
                if(searchParser.searchHolder.currentSearch.filters[.Portrait] == nil && searchParser.searchHolder.currentSearch.filters[.Landscape] == nil) {
                    return Color.green
                } else {
                    return searchParser.searchHolder.currentSearch.filters[attribute] != nil ? Color.green : (darkMode ? Color.gray : Color.black)
                }
            } else {
                return searchParser.searchHolder.currentSearch.filters[attribute] != nil ? Color.green : (darkMode ? Color.gray : Color.black)
            }
        }
    }
    
    private var opacities: (Double, Double) {
        get {
            return searchParser.searchHolder.currentSearch.filters[attribute] != nil ? (0.4, 0.55) : (0.15, 0.3)
        }
    }
    
    init(searchParser: SearchParser, attribute: SearchFilter.Attribute, darkMode: Bool) {
        self._searchParser = StateObject(wrappedValue: searchParser)
        self.attribute = attribute
        self.darkMode = darkMode
        self.cornerRadius = 5
    }
    init(searchParser: SearchParser, attribute: SearchFilter.Attribute, darkMode: Bool, cornerRadius: CGFloat) {
        self._searchParser = StateObject(wrappedValue: searchParser)
        self.attribute = attribute
        self.darkMode = darkMode
        self.cornerRadius = cornerRadius
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(5)
            .background(darkMode ? color.opacity(configuration.isPressed ? self.opacities.0 : self.opacities.1) : color.opacity(configuration.isPressed ? self.opacities.0 : self.opacities.1))
            .cornerRadius(cornerRadius)
    }
}

struct ButtonDetailViewPair: View {
    let attribute: SearchFilter.Attribute
    @StateObject var parser: SearchParser
    
    let label: () -> Label<Text, Image>
    
    @State var isSelected: Bool = false
    
    init(_ attribute: SearchFilter.Attribute, parser: SearchParser, label: @escaping () -> Label<Text, Image>) {
        self.attribute=attribute
        self._parser=StateObject(wrappedValue: parser)
        self.label=label
    }
    
    var body: some View {
        if attribute == .DateAfter || attribute == .DateBefore {
            HStack {
                Button {
                    withAnimation {
                        isSelected.toggle()
                    }
                } label: {
                    label().frame(maxWidth: .infinity)
                }
                .buttonStyle(OverlayButtonStyle(searchParser: parser, attribute: attribute, darkMode: UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"))
                if isSelected {
                    QueryDetailView(attribute, parser: parser)
                        .transition(.scale(scale: 0.1, anchor: .leading))
                }
            }
        } else {
            VStack {
                Button(action: {
                    withAnimation {
                        isSelected.toggle()
                    }
                }, label: {
                    label().frame(maxWidth: .infinity)
                })
                .buttonStyle(OverlayButtonStyle(searchParser: parser, attribute: attribute, darkMode: UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"))
                if isSelected {
                    QueryDetailView(attribute, parser: parser)
                        .transition(.scale(scale: 0.1, anchor: .top))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

struct QueryDetailView: View {
    let attribute: SearchFilter.Attribute
    let parser: SearchParser
    @State var selectedDate:Date = Date()
    @State var selectedItems: Set<Int> = Set()
    
    
    init(_ attribute: SearchFilter.Attribute, parser: SearchParser) {
        self.attribute = attribute
        self.parser=parser
    }
    
    var body: some View {
        if attribute == .DateBefore || attribute == .DateAfter {
            DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .onChange(of: selectedDate) { date in
                    let filter = ["time":BSON.document([(attribute == .DateAfter ? "$gte" : "$lte") : BSON.datetime(selectedDate)])]
                    parser.setFilterForCurrent(attribute, text_representation: selectedDate.formatted(date: .numeric, time: .omitted), filter: filter)
                }
        } else if attribute == .Aperture {
            RangeSliderView(minValue: parser.aperture_range.0, maxValue: parser.aperture_range.1, decimalPlaces: 2, valuePrefix: "f/", valueSuffix: "") { (lower,upper) in
                let filter = ["exif_data.aperture":BSON.document([
                                                "$gt":BSON.double(lower),
                                                "$lt":BSON.double(upper)])
                ]
                parser.setFilterForCurrent(.Aperture, text_representation: "f/\(String(format: "%.2f", lower-0.01))–\(String(format: "%.2f", upper+0.01))", filter: filter)
            }
                .frame(maxWidth: .infinity)
                .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
        } else {
            if attribute == .Lens {
                SelectorView(parser.lenses, /*selectedItems: $selectedItems,*/ startSelected: true) { newValue in
                    var items: [BSON] = []
                    for item in newValue {
                        items.append(BSON.string(parser.lenses[item]))
                    }
                    let filter = ["exif_data.lens":BSON.document(["$in":BSON.array(items)])]
                    parser.setFilterForCurrent(.Lens, text_representation: "\(items.count) selected", filter: filter)
                }
            } else if attribute == .FileExtension {
                SelectorView(parser.file_extensions/*, selectedItems: $selectedItems*/, startSelected: true) { newValue in
                    var items: [BSON] = []
                    var textRespresentation = ""
                    for item in newValue {
                        items.append(BSON.string(parser.file_extensions[item]))
                        textRespresentation += ".\(parser.file_extensions[item]),"
                    }
                    if(textRespresentation == "") {
                        textRespresentation = "No extensions selected"
                    } else {
                        textRespresentation.removeLast()
                    }
                    let filter = ["extension":BSON.document(["$in":BSON.array(items)])]
                    parser.setFilterForCurrent(.FileExtension, text_representation: textRespresentation, filter: filter)
                    
                }
            } else if attribute == .Camera {
                SelectorView(parser.getCameraMakeModelStrings()/*,selectedItems: $selectedItems*/, startSelected: true) { newValue in
                    var items: [BSON] = []
                    for item in newValue {
                        items.append(BSON.string(parser.cameras[item].1))
                    }
                    let filter = ["exif_data.model":BSON.document(["$in":BSON.array(items)])]
                    parser.setFilterForCurrent(.Camera, text_representation: "\(items.count) selected", filter: filter)
                }
            }
        }
    }
}

struct SelectorView: View {
    @State var selectedItems: Set<Int>
    let items: [String]
    let items_len: Int
    
    let selectedChangedAction: (_ itemsSelected: Set<Int>) -> Void
    
    init(_ items: [String], /*selectedItems: Binding<Set<Int>>, */startSelected: Bool, selectedChangedAction: @escaping (_ itemsSelected: Set<Int>) -> Void) {
        var selectedItems = Set<Int>()
        self.items=items
        self.items_len=items.count
        if startSelected {
            for i in 0..<items_len {
                selectedItems.insert(i)
            }
        }
        self._selectedItems = State(wrappedValue: selectedItems)
        self.selectedChangedAction = selectedChangedAction
    }
    
    var body: some View {
        ZStack {
            VStack {
                if items.count>0 {
                    ForEach(Array(0...items.count-1), id: \.magnitude) { i in
                        Button {
                            withAnimation {
                                if(selectedItems.contains(i)) {
                                    selectedItems.remove(i)
                                } else {
                                    selectedItems.insert(i)
                                }
                            }
                            selectedChangedAction(selectedItems)
                        } label: {
                            HStack {
                                if selectedItems.contains(i) {
                                    //Image(systemName: "checkmark")
                                    Label(items[i], systemImage: "checkmark.circle")
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Label(items[i], systemImage: "")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .animation(Animation.linear, value: selectedItems.contains(i))
                        .frame(height: 32)
                        .buttonStyle(SelectorViewButtonStyle(darkMode: UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark", selected: selectedItems.contains(i)))
                    }
                }
                
            }
            .fixedSize(horizontal: false, vertical: true)
            .cornerRadius(10)
        }
        .padding(EdgeInsets(top: 5, leading: 20, bottom: 10, trailing: 20))
    }
}

struct SelectorViewButtonStyle: ButtonStyle {
    let darkMode: Bool
    let selected: Bool
    
    //maybe a green or blue tint for selected instead?
    
    private var nonpressedOpacity: Double {
        get {
            if selected {
                return darkMode ? 0.2 : 0.17
            } else {
                return darkMode ? 0.3 : 0.22
            }
        }
    }
    
    private var pressedOpacity: Double {
        get {
            return darkMode ? 0.12 : 0.15
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Rectangle().fill(darkMode ? Color.black.opacity(configuration.isPressed ? 0.12 : 0.3) : (configuration.isPressed ? Color.black.opacity(0.15) : Color.black.opacity(0.22))).frame(height: 40))
            .background(Rectangle().fill(Color.black.opacity(configuration.isPressed ? pressedOpacity : nonpressedOpacity)).frame(height: 40))
            .frame(height: 40)
    }
}
