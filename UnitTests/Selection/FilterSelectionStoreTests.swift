//
//  Copyright © FINN.no AS, Inc. All rights reserved.
//

@testable import Charcoal
import XCTest

final class FilterSelectionStoreTests: XCTestCase {
    private let store = FilterSelectionStore()

    override func tearDown() {
        store.clear()
        super.tearDown()
    }

    // MARK: - Tests

    func testClear() {
        let filterA = Filter.list(title: "Test A", key: "testA", value: "valueB")
        let filterB = Filter.list(title: "Test B", key: "testB", value: "valueB")

        store.setValue(from: filterA)
        store.setValue(from: filterB)

        XCTAssertTrue(store.isSelected(filterA))
        XCTAssertTrue(store.isSelected(filterB))

        store.clear()

        XCTAssertFalse(store.isSelected(filterA))
        XCTAssertFalse(store.isSelected(filterB))
    }

    func testSetValueFromfilter() {
        let filter = Filter.list(title: "Test", key: "test", value: "valueA")

        store.setValue(from: filter)
        XCTAssertEqual(store.value(for: filter), "valueA")
    }

    func testSetValueForfilter() {
        let filter = Filter.list(title: "Test", key: "test")

        store.setValue("valueB", for: filter)
        XCTAssertEqual(store.value(for: filter), "valueB")

        store.setValue(10, for: filter)
        XCTAssertEqual(store.value(for: filter), 10)
    }

    func testRemoveValuesForfilter() {
        let filter = Filter.list(title: "Test", key: "test", value: "value")

        store.setValue(from: filter)
        XCTAssertTrue(store.isSelected(filter))

        store.removeValues(for: filter)
        XCTAssertFalse(store.isSelected(filter))
    }

    func testRemoveValuesForfilterWithSubfilters() {
        let subfilterA = Filter.list(title: "subfilter A", key: "subfilterA", value: "valueB")
        let subfilterB = Filter.list(title: "subfilter B", key: "subfilterB", value: "valueB")
        let subfilters = [subfilterA, subfilterB]
        let filter = Filter.list(title: "Test", key: "filter", value: "value", subfilters: subfilters)

        store.setValue(from: filter)
        store.setValue(from: subfilterA)
        store.setValue(from: subfilterB)

        store.removeValues(for: filter)
        XCTAssertFalse(store.isSelected(filter))
        XCTAssertFalse(store.isSelected(subfilterA))
        XCTAssertFalse(store.isSelected(subfilterB))
    }

    func testToggleValueForfilter() {
        let filter = Filter.list(title: "Test", key: "test", value: "value")

        store.toggleValue(for: filter)
        XCTAssertTrue(store.isSelected(filter))

        store.toggleValue(for: filter)
        XCTAssertFalse(store.isSelected(filter))
    }

    func testIsSelected() {
        let subfilterA = Filter.list(title: "subfilter A", key: "subfilterA", value: "valueB")
        let subfilterB = Filter.list(title: "subfilter B", key: "subfilterB", value: "valueB")
        let subfilters = [subfilterA, subfilterB]
        let filter = Filter.list(title: "Test", key: "filter", value: "value", subfilters: subfilters)

        store.setValue(from: subfilterA)
        XCTAssertTrue(store.isSelected(subfilterA))
        XCTAssertFalse(store.isSelected(filter))

        store.setValue(from: subfilterB)
        XCTAssertTrue(store.isSelected(subfilterB))
        XCTAssertTrue(store.isSelected(filter))
    }

    func testQueryItems() {
        let filter = Filter.list(title: "Test", key: "test", value: "value")
        store.setValue(from: filter)

        let expected = [URLQueryItem(name: "test", value: "value")]
        XCTAssertEqual(store.queryItems(for: filter), expected)
    }

    func testQueryItemsWithSubfilters() {
        let subfilterA = Filter.list(title: "subfilter A", key: "subfilterA", value: "valueA")
        let subfilterB = Filter.list(title: "subfilter B", key: "subfilterB", value: "valueB")
        let subfilters = [subfilterA, subfilterB]
        let filter = Filter.list(title: "Test", key: "filter", value: "value", subfilters: subfilters)

        store.setValue(from: subfilterA)
        store.setValue(from: subfilterB)

        let expected = [
            URLQueryItem(name: "subfilterA", value: "valueA"),
            URLQueryItem(name: "subfilterB", value: "valueB"),
        ]

        XCTAssertEqual(store.queryItems(for: filter), expected)
    }

    func testTitles() {
        let filter = Filter.list(title: "Test", key: "test", value: "value")

        store.setValue(from: filter)
        XCTAssertEqual(store.titles(for: filter), ["Test"])
    }

    func testTitlesWithSubfilters() {
        let subfilterA = Filter.list(title: "subfilter A", key: "subfilterA", value: "valueA")
        let subfilterB = Filter.list(title: "subfilter B", key: "subfilterB", value: "valueB")
        let subfilters = [subfilterA, subfilterB]
        let filter = Filter.list(title: "filter", key: "filter", value: "value", subfilters: subfilters)

        store.setValue(from: subfilterA)
        store.setValue(from: subfilterB)
        XCTAssertEqual(store.titles(for: filter), ["filter"])

        store.removeValues(for: subfilterB)
        XCTAssertEqual(store.titles(for: filter), ["subfilter A"])
    }

    func testTitlesWithRanges() {
        let filter = Filter.range(title: "Range", key: "range", lowValueKey: "from", highValueKey: "to")
        let lowValueFilter = filter.subfilters[0]
        let highValueFilter = filter.subfilters[1]

        XCTAssertTrue(store.titles(for: filter).isEmpty)

        store.setValue(10, for: lowValueFilter)
        store.removeValues(for: highValueFilter)
        XCTAssertEqual(store.titles(for: filter), ["10 - ..."])

        store.removeValues(for: lowValueFilter)
        store.setValue(100, for: highValueFilter)
        XCTAssertEqual(store.titles(for: filter), ["... - 100"])

        store.setValue(10, for: lowValueFilter)
        store.setValue(100, for: highValueFilter)
        XCTAssertEqual(store.titles(for: filter), ["10 - 100"])
    }

    func testTitlesWithMap() {
        let filter = Filter.map(title: "Map", key: "map", latitudeKey: "lat", longitudeKey: "lon", radiusKey: "r", locationKey: "loc")
        XCTAssertTrue(store.titles(for: filter).isEmpty)

        store.setValue(10, for: filter.subfilters[2])
        XCTAssertEqual(store.titles(for: filter), ["10 m"])
    }

    func testIsValid() {
        let filter = Filter.list(title: "Test", key: "test", value: "value")

        store.setValue(from: filter)
        XCTAssertTrue(store.isValid(filter))
    }

    func testIsValidWithRange() {
        let filter = Filter.range(title: "Range", key: "range", lowValueKey: "range_from", highValueKey: "range_to")
        let lowValueFilter = filter.subfilters[0]
        let highValueFilter = filter.subfilters[1]

        XCTAssertTrue(store.isValid(filter))

        store.setValue(100, for: lowValueFilter)
        store.removeValues(for: highValueFilter)
        XCTAssertTrue(store.isValid(filter))

        store.removeValues(for: lowValueFilter)
        store.setValue(100, for: highValueFilter)
        XCTAssertTrue(store.isValid(filter))

        store.setValue(100, for: lowValueFilter)
        store.setValue(100, for: highValueFilter)
        XCTAssertTrue(store.isValid(filter))

        store.setValue(100, for: lowValueFilter)
        store.setValue(200, for: highValueFilter)
        XCTAssertTrue(store.isValid(filter))

        store.setValue(300, for: lowValueFilter)
        store.setValue(200, for: highValueFilter)
        XCTAssertFalse(store.isValid(filter))
    }

    func testHasSelectedSubfilters() {
        let subfilter = Filter.list(title: "subfilter A", key: "subfilterA", value: "valueA")
        let filter = Filter.list(title: "filter", key: "filter", value: "value", subfilters: [subfilter])

        store.setValue(from: subfilter)
        XCTAssertTrue(store.hasSelectedSubfilters(for: filter))
    }

    func testHasSelectedSubfiltersWithPredicate() {
        let subfilter = Filter.list(title: "subfilter A", key: "subfilterA", value: "valueA")
        let filter = Filter.list(title: "filter", key: "filter", value: "value", subfilters: [subfilter])

        store.setValue(from: subfilter)
        XCTAssertTrue(store.hasSelectedSubfilters(for: filter, where: { $0.key == "subfilterA" }))
        XCTAssertFalse(store.hasSelectedSubfilters(for: filter, where: { $0.key == "subfilterB" }))
    }

    func testSelectedSubfilters() {
        let subfilter = Filter.list(title: "subfilter A", key: "subfilterA", value: "valueA")
        let filter = Filter.list(title: "filter", key: "filter", value: "value", subfilters: [subfilter])

        store.setValue(from: subfilter)
        XCTAssertEqual(store.selectedSubfilters(for: filter).count, 1)
    }

    func testSelectedSubfiltersWithPredicate() {
        let subfilter = Filter.list(title: "subfilter A", key: "subfilterA", value: "valueA")
        let filter = Filter.list(title: "filter", key: "filter", value: "value", subfilters: [subfilter])

        store.setValue(from: subfilter)
        XCTAssertEqual(store.selectedSubfilters(for: filter, where: { $0.key == "subfilterA" }).count, 1)
        XCTAssertTrue(store.selectedSubfilters(for: filter, where: { $0.key == "subfilterB" }).isEmpty)
    }
}
