//
//  DatePickerView.swift
//  MediaOrganizer
//
//  Created by John Bridge on 1/19/23.
//

import Foundation
import SwiftUI

struct DatePickerView: NSViewRepresentable {
    typealias NSViewType = NSDatePicker
    @Binding var selectedDate: UInt64
    let frame_rect: CGRect
    
    init(_ selectedDate: Binding<UInt64>, frame: CGRect) {
        self._selectedDate=selectedDate
        self.frame_rect=frame
    }
    
    func makeNSView(context: Context) -> NSDatePicker {
        let datePicker = NSDatePicker(frame: CGRect(x: 0, y: 0, width: 500, height: 500))//.zero)
        datePicker.isBezeled=true
        datePicker.datePickerElements = .yearMonthDay
        datePicker.datePickerStyle = .clockAndCalendar
        if let cell=datePicker.cell {
            cell.calcDrawInfo(CGRect(x: 0, y: 0, width: 500, height: 500))
            cell.controlSize = .large
            datePicker.setFrameOrigin(frame_rect.origin)
            datePicker.setFrameSize(CGSize(width: 500, height: 500))
            datePicker.updateCell(cell)
            datePicker.updateLayer()
        }
        //datePicker.cell
        //datePicker.cell?.cellSize=NSSize()
        //datePicker.cell?.backgroundStyle = .normal
        //datePicker.cell?.controlSize = .large
        //datePicker.cell?.drawInterior(withFrame: frame_rect, in: NSView())
        print(datePicker.cell?.cellSize)
        
        //datePicker.cell?.drawInterior(withFrame: frame_rect, in: datePicker)
        //datePicker.frame=self.frame_rect
        //datePicker.bounds=self.frame_rect
        return datePicker
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.dateValue = Date(timeIntervalSince1970: TimeInterval(selectedDate))
        nsView.isBezeled=true
        nsView.datePickerElements = .yearMonthDay
        nsView.delegate=context.coordinator
        nsView.datePickerStyle = .clockAndCalendar
        if let cell=nsView.cell {
            cell.calcDrawInfo(CGRect(x: 0, y: 0, width: 500, height: 500))
            cell.controlSize = .large
            nsView.cell?.draw(withFrame: CGRect(x: 0, y: 0, width: 500, height: 500), in: nsView)
            nsView.setFrameOrigin(frame_rect.origin)
            nsView.setFrameSize(CGSize(width: 500, height: 500))
            nsView.updateCellInside(cell)
            nsView.drawCellInside(cell)
            nsView.updateCell(cell)
            nsView.updateLayer()
            nsView.drawCell(cell)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator($selectedDate)
    }
    
    class Coordinator: NSObject, NSDatePickerCellDelegate {
        @Binding var selectedTime: UInt64
        
        init(_ selectedTime: Binding<UInt64>) {
            self._selectedTime=selectedTime
        }
        
        func datePickerCell(_ datePickerCell: NSDatePickerCell, validateProposedDateValue proposedDateValue: AutoreleasingUnsafeMutablePointer<NSDate>, timeInterval proposedTimeInterval: UnsafeMutablePointer<TimeInterval>?) {
        }
    }
}
