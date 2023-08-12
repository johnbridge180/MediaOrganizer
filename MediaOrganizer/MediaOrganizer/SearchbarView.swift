//
//  SearchbarView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/9/23.
//

import SwiftUI

struct SearchbarView: NSViewRepresentable {
    typealias NSViewType = NSSearchField
    @StateObject var searchParser: SearchParser
    
    init(_ searchParser: SearchParser) {
        self._searchParser = StateObject(wrappedValue: searchParser)
    }
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchBar = PhotosSearchField(searchParser, frame: .zero)
        searchBar.placeholderString = "Search"
        searchBar.delegate = context.coordinator
        searchBar.sendsWholeSearchString=false
        searchBar.cell?.isScrollable=true
        return searchBar
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.stringValue = searchParser.searchHolder.currentSearch.queryString
        nsView.delegate = context.coordinator
        nsView.currentEditor()?.selectedRange = NSRange()
        print("SearchbarView.updateNSView() called. queryText=\"\(queryText)\"")
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(searchParser/*, queryText: $queryText*/)
    }
    
    class Coordinator: NSObject, NSSearchFieldDelegate {
        let searchParser: SearchParser
        
        init(_ searchParser: SearchParser/*, queryText: Binding<String>*/) {
            self.searchParser=searchParser
        }
        
        func searchFieldDidEndSearching(_ sender: NSSearchField) {
            print("END: \(sender.stringValue)")
        }
        
        func searchFieldDidStartSearching(_ sender: NSSearchField) {
            print("BEGIN: \(sender.stringValue)")
        }
        
        func controlTextDidChange(_ notification: Notification) {
            /*TODO: Dropdown menu below searchfield that gives options regarding what type of search is happening
             *Each option will be formatted `option:value` in the text field
             */
            guard let searchField = notification.object as? NSSearchField else {
                print("Unexpected control in update notification")
                return
            }
            searchField.stringValue = self.searchParser.updateQueryString(searchField.stringValue)
            self.searchParser.parseQuery()
        }
    }
}

class PhotosSearchField: NSSearchField, NSTextDelegate {
    let searchParser: SearchParser
    
    init(_ searchParser: SearchParser, frame: NSRect) {
        self.searchParser=searchParser
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Unable to decode PhotosSearchField from NSCoder")
    }
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    override func becomeFirstResponder() -> Bool {
        let returnVal = super.becomeFirstResponder()
        appDelegate.openSearchPanel(searchParser)
        return returnVal
    }
    
    override func resignFirstResponder() -> Bool {
        if super.resignFirstResponder() {
            appDelegate.closeSearchPanel()
            return true
        }
        return false
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        appDelegate.closeSearchPanel()
    }
}
