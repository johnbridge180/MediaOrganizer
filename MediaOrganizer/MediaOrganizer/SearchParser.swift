//
//  SearchParser.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/10/23.
//

import Foundation
import SwiftUI
import SwiftBSON

struct SearchFilter {
    var attribute: Attribute
    var filter: [String:BSON]
    var text_representation: String
    
    enum Attribute: String {
        case DateBefore = "before"
        case DateAfter = "after"
        case Aperture = "aperture"
        case Lens = "lens"
        case Camera = "camera"
        case FileExtension = "ext"
        case Portrait = "PORTRAIT"
        case Landscape = "LANDSCAPE"
        case None = ""
        
        func prefix() -> String {
            switch self {
                case .Aperture:
                    return ""
                case .FileExtension:
                    return ""
                default:
                    return "\(self.rawValue):"
            }
                
        }
    }
}

class SearchHolder: ObservableObject {
    var previousSearches: [Search]
    init() {
        self.currentSearch = Search()
        self.previousSearches = []
    }
    
    func setFilterForCurrent(_ attribute: SearchFilter.Attribute, text_representation: String, filter: [String:BSON]) {
        currentSearch.setFilter(attribute, text_representation: text_representation, filter: filter)
    }
    
    func newSearch() {
        self.previousSearches.insert(currentSearch.copyReset(), at: 0)
        if previousSearches.count > 5 {
            previousSearches.remove(at: 5)
        }
    }
}

class Search: ObservableObject {
    var filters: [SearchFilter.Attribute:(SearchFilter, ClosedRange<String.Index>)] = [:]
    var sortedRanges: [(ClosedRange<String.Index>, SearchFilter.Attribute)] = []
    
    
    func setFilter(_ attribute: SearchFilter.Attribute, text_representation: String, filter: [String:BSON]) {
        let attr_string = "[\(attribute.prefix())\(text_representation)]"
        if let currentFilterRangePair = filters[attribute] {
            queryString.removeSubrange(currentFilterRangePair.1)
            queryString.insert(contentsOf: attr_string, at: currentFilterRangePair.1.lowerBound)
            filters[attribute] = (
                SearchFilter(attribute: attribute, filter: filter, text_representation: text_representation),
                ClosedRange(uncheckedBounds: (lower: currentFilterRangePair.1.lowerBound, upper: queryString.index(currentFilterRangePair.1.lowerBound, offsetBy: attr_string.count-1)))
                )
            for i in 0..<sortedRanges.count {
                if sortedRanges[i].0 == currentFilterRangePair.1 {
                    sortedRanges[i] = (filters[attribute]!.1,attribute)
                    break
                }
            }
        } else {
            let startIndex = queryString.endIndex
            
            queryString.append(attr_string)
            filters[attribute] = (
                    SearchFilter(attribute: attribute, filter: filter, text_representation: text_representation),
                    queryString.index(queryString.endIndex, offsetBy: -attr_string.count)...queryString.index(queryString.endIndex, offsetBy: -1)
                )
            print("attr_string: \(queryString[filters[attribute]!.1])")
            var i=0
            while i<sortedRanges.count, sortedRanges[i].0.lowerBound<filters[attribute]!.1.lowerBound {
                i+=1
            }
            sortedRanges.insert((filters[attribute]!.1, attribute), at: i)
        }
    }
    
    
    func copyReset() -> Search {
        let copy = Search()
        
        copy.queryString = self.queryString
        self.queryString = ""
        
        copy.sortedRanges = self.sortedRanges
        self.sortedRanges = []
        
        copy.filters = self.filters
        self.filters = [:]
        
        self.objectWillChange.send()
        
        return copy
    }
    //no colon predicates will be a string search across all text values (except attributes for server-side information)
}



class SearchParser: ObservableObject {
    
    
    //let shared: SearchParser = SearchParser()
    
    @Published var searchHolder: SearchHolder
    
    //var previousSearches: [Search] = []
    
    //@Published var currentSearch: Search
    
    var mongo_holder: MongoClientHolder
    
    let superFilter: BSONDocument
    
    var lenses: [String] = []
    var cameras: [(String,String)] = []
    var file_extensions: [String] = []
    var aperture_range: (Double, Double) = (0.7,45.0)
    
    //(Portrait, Landscape)
    var orientations: (Bool, Bool) = (true, true)
    
    convenience init(mongo_holder: MongoClientHolder) {
        self.init([:], mongo_holder: mongo_holder)
    }
    
    init(_ superFilter: BSONDocument, mongo_holder: MongoClientHolder) {
        self.mongo_holder=mongo_holder
        self.superFilter=superFilter
        self.currentFilter=superFilter
        self.searchHolder = SearchHolder()
        Task {
            do {
                try await getSearchSelectorValues()
            } catch {
                print("Error setting search selector values")
            }
        }
    }
    
    //This method is inefficient, optimize later!
    func updateQueryString(_ queryString: String) -> String {
        //TODO: MAYBE DO THIS FUNCTION IN OBJECTIVE-C? May may be easier to avoid indices issues
        if searchHolder.currentSearch.queryString == "" {
            searchHolder.currentSearch.queryString = queryString
            searchHolder.currentSearch.sortedRanges = []
            searchHolder.currentSearch.filters = [:]
            return queryString
        }
        if queryString == "" && searchHolder.currentSearch.queryString != "" {
            if searchHolder.currentSearch.queryString.count>1 {
                searchHolder.newSearch()
            }
            return queryString
        }
        if queryString == searchHolder.currentSearch.queryString {
            return queryString
        }
                var i = queryString.startIndex
        var j = searchHolder.currentSearch.queryString.startIndex
        
        while i != queryString.endIndex && j != searchHolder.currentSearch.queryString.endIndex && queryString[i]==searchHolder.currentSearch.queryString[j] {
            i=queryString.index(after: i)
            j=searchHolder.currentSearch.queryString.index(after: j)
        }
        
        if(j == searchHolder.currentSearch.queryString.endIndex) {
            searchHolder.currentSearch.queryString += queryString[i..<queryString.endIndex]
            return searchHolder.currentSearch.queryString
        }
        var changedRange: ClosedRange<String.Index>?
        var changedText = ""
        var insertIndex: String.Index?
        if(i==queryString.endIndex) {
            changedRange = j...searchHolder.currentSearch.queryString.index(before: searchHolder.currentSearch.queryString.endIndex)
        } else if (j==searchHolder.currentSearch.queryString.endIndex) {
            changedText = "\(queryString[queryString.startIndex...i])"
            insertIndex = searchHolder.currentSearch.queryString.endIndex
        } else {
            var k = queryString.index(before: queryString.endIndex)
            var l = searchHolder.currentSearch.queryString.index(before: searchHolder.currentSearch.queryString.endIndex)
            while k != queryString.startIndex && l != searchHolder.currentSearch.queryString.startIndex && queryString[k]==searchHolder.currentSearch.queryString[l] {
                k=queryString.index(before: k)
                l=searchHolder.currentSearch.queryString.index(before: l)
            }
            if(queryString[k]==searchHolder.currentSearch.queryString[l]) {
                if k==queryString.startIndex {
                    changedRange = searchHolder.currentSearch.queryString.startIndex...searchHolder.currentSearch.queryString.index(before: l)
                } else if l==searchHolder.currentSearch.queryString.startIndex {
                    changedText = "\(queryString[queryString.startIndex...queryString.index(before: k)])"
                    insertIndex = searchHolder.currentSearch.queryString.startIndex
                }
            } else {
                changedRange = l<j ? nil : j...l
                insertIndex = l<j ? j : nil
                changedText = k<i ? "" : "\(queryString[i...k])"
            }
        }
        
        var offset = 0
        if let index: String.Index = insertIndex {
            print(searchHolder.currentSearch.sortedRanges)
            var x = 0
            while x < searchHolder.currentSearch.sortedRanges.count {
                if index > searchHolder.currentSearch.sortedRanges[x].0.lowerBound {
                    if index <= searchHolder.currentSearch.sortedRanges[x].0.upperBound {
                        return searchHolder.currentSearch.queryString
                    }
                } else {
                    let newRange = searchHolder.currentSearch.queryString.index(searchHolder.currentSearch.sortedRanges[x].0.lowerBound, offsetBy: changedText.count)...searchHolder.currentSearch.queryString.index(searchHolder.currentSearch.sortedRanges[x].0.upperBound, offsetBy: changedText.count)
                    searchHolder.currentSearch.sortedRanges[x] = (newRange,searchHolder.currentSearch.sortedRanges[x].1)
                    searchHolder.currentSearch.filters[searchHolder.currentSearch.sortedRanges[x].1] = (searchHolder.currentSearch.filters[searchHolder.currentSearch.sortedRanges[x].1]!.0, newRange)
                }
                x+=1
            }
            searchHolder.currentSearch.queryString.insert(contentsOf: changedText, at: index)
            print(searchHolder.currentSearch.sortedRanges)
        } else {
            print(searchHolder.currentSearch.sortedRanges)
            var x = 0
            while x < searchHolder.currentSearch.sortedRanges.count {
                if changedRange!.overlaps(searchHolder.currentSearch.sortedRanges[x].0) {
                    changedRange = (searchHolder.currentSearch.sortedRanges[x].0.lowerBound < changedRange!.lowerBound ? searchHolder.currentSearch.sortedRanges[x].0.lowerBound : changedRange!.lowerBound)...(searchHolder.currentSearch.sortedRanges[x].0.upperBound > changedRange!.upperBound ? searchHolder.currentSearch.sortedRanges[x].0.upperBound : changedRange!.upperBound)
                    searchHolder.currentSearch.filters.removeValue(forKey: searchHolder.currentSearch.sortedRanges[x].1)
                    searchHolder.currentSearch.sortedRanges.remove(at: x)
                    break
                } else if x+1 < searchHolder.currentSearch.sortedRanges.count && changedRange!.upperBound < searchHolder.currentSearch.sortedRanges[x+1].0.lowerBound {
                    x+=1
                    break
                }
                x += 1
            }
            offset = changedText.count-searchHolder.currentSearch.queryString[changedRange!].count
            print("offset=\(offset); x=\(x)")
            var rangeContents: [(String,Int)] = []
            while x < searchHolder.currentSearch.sortedRanges.count {
                //TODO: FIX THIS (shouldn't have to search string for the range when we already know enough to calculate indices)
                rangeContents.append(("\(searchHolder.currentSearch.queryString[searchHolder.currentSearch.sortedRanges[x].0])",x))
                x += 1
            }
            searchHolder.currentSearch.queryString.replaceSubrange(changedRange!, with: changedText)
            for (textContent,x) in rangeContents {
                let firstRange: Range<String.Index> = searchHolder.currentSearch.queryString.range(of: textContent)!
                let newRange = firstRange.lowerBound...searchHolder.currentSearch.queryString.index(before: firstRange.upperBound)
                searchHolder.currentSearch.sortedRanges[x] = (newRange.lowerBound...newRange.upperBound,searchHolder.currentSearch.sortedRanges[x].1)
                searchHolder.currentSearch.filters[searchHolder.currentSearch.sortedRanges[x].1] = (searchHolder.currentSearch.filters[searchHolder.currentSearch.sortedRanges[x].1]!.0, searchHolder.currentSearch.sortedRanges[x].0)
            }
            
            print(searchHolder.currentSearch.sortedRanges)
        }
        return searchHolder.currentSearch.queryString
    }
    
    func parseQuery() {
        var bson_doc: BSONDocument = superFilter
        var mut_queryString = self.searchHolder.currentSearch.queryString
        print("mut_queryString: \(mut_queryString)")
        var offset = 0
        var i = searchHolder.currentSearch.sortedRanges.count-1
        while i >= 0 {
            let reservedRangePair = searchHolder.currentSearch.sortedRanges[i]
            //TODO: FIX : Still crashes sometimes after text removal, fix index madness in updateQueryString()
            print(mut_queryString[reservedRangePair.0])
            mut_queryString.removeSubrange(reservedRangePair.0)
            if let searchFilterPair = searchHolder.currentSearch.filters[reservedRangePair.1] {
                for filter in searchFilterPair.0.filter {
                    bson_doc[filter.key] = filter.value
                }
            }
            i-=1
        }
        print(mut_queryString)
        if(mut_queryString.replacingOccurrences(of: " ", with: "") != "") {
            bson_doc["$text"] = BSON.document(BSONDocument(dictionaryLiteral: ("$search", BSON.string(mut_queryString))))
        }
        
        currentFilter=bson_doc
        DispatchQueue.main.async {
            print("objectWillChange from SearchParser")
            self.objectWillChange.send()
        }
    }
    func resetFilter() {
        if(self.searchHolder.currentSearch.queryString != "") {
            self.searchHolder.newSearch()
        }
        DispatchQueue.main.async {
            print("objectWillChange from SearchParser")
            self.objectWillChange.send()
        }
    }
    
    private func getSearchSelectorValues() async throws {
        if(mongo_holder.client==nil) {
            await mongo_holder.connect()
        }
        
        let files_collection = mongo_holder.client!.db("media_organizer").collection("files")
        for lens_bson in try await files_collection.distinct(fieldName: "exif_data.lens") {
            if let str_value = lens_bson.stringValue {
                self.lenses.append(str_value)
            }
        }
        for file_ext_bson in try await files_collection.distinct(fieldName: "extension") {
            if let str_value = file_ext_bson.stringValue {
                self.file_extensions.append(str_value)
            }
        }
        for make_bson in try await files_collection.distinct(fieldName: "exif_data.make") {
            if let make_str_value = make_bson.stringValue {
                for model_bson in try await files_collection.distinct(fieldName: "exif_data.model", filter: ["exif_data.make":make_bson]) {
                    if let model_str_value = model_bson.stringValue {
                        self.cameras.append((make_str_value, model_str_value))
                    }
                }
            }
        }
        let agg = try await files_collection.aggregate([BSONDocument(dictionaryLiteral: ("$group", BSON(dictionaryLiteral: ("_id", BSON.null), ("max",BSON(dictionaryLiteral: ("$max", BSON.string("$exif_data.aperture")))), ("min",BSON(dictionaryLiteral: ("$min", BSON.string("$exif_data.aperture")))))))])
        if let agg_result: BSONDocument = try await agg.next(), let min: Double = agg_result["min"]?.doubleValue, let max: Double = agg_result["max"]?.doubleValue {
            aperture_range.0 = min
            aperture_range.1 = max
        }
        print(self.file_extensions)
        print(self.cameras)
        print(self.lenses)
    }
    
    func getCameraMakeModelStrings() -> [String] {
        var makemodel_arr: [String] = []
        for camera in cameras {
            makemodel_arr.append("\(camera.0) \(camera.1)")
        }
        return makemodel_arr
    }
    
    func setFilterForCurrent(_ attribute: SearchFilter.Attribute, text_representation: String, filter: [String:BSON]) {
        self.searchHolder.setFilterForCurrent(attribute, text_representation: text_representation, filter: filter)
        print("setFilterForCurrent() called")
        self.parseQuery()
        self.objectWillChange.send()
    }
}
