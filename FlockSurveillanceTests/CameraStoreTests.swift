import MapKit
import SwiftData
import XCTest
@testable import FlockSurveillance

@MainActor
final class CameraStoreTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ALPRCamera.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func dto(
        _ id: String,
        _ lat: Double,
        _ lon: Double,
        direction: String? = nil,
        fetchedAt: Date = .now
    ) -> ALPRCameraDTO {
        ALPRCameraDTO(
            id: id,
            latitude: lat,
            longitude: lon,
            manufacturer: "Flock Safety",
            operatorName: nil,
            direction: direction,
            cameraName: nil,
            tagsJSON: #"{"manufacturer":"Flock Safety"}"#,
            fetchedAt: fetchedAt
        )
    }

    private func tile(lon: Double, ids: Set<String>) -> FetchTileResult {
        FetchTileResult(
            region: MKCoordinateRegion(
                center: .init(latitude: 35.0, longitude: lon),
                span: .init(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ),
            ids: ids
        )
    }

    private func rows(_ container: ModelContainer) throws -> [String: ALPRCamera] {
        let all = try container.mainContext.fetch(FetchDescriptor<ALPRCamera>())
        return Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }

    // MARK: One absent pass per fetch

    func testBatchedAbsentPassRunsOncePerFetchNotPerTile() async throws {
        let store = CameraStore(modelContainer: try makeContainer())
        _ = await store.applyFetch(
            dtos: [dto("a", 35.0, -90.0)],
            tileResults: [tile(lon: -90.0, ids: ["a"]), tile(lon: -89.9, ids: []), tile(lon: -89.6, ids: [])],
            protecting: ["a"],
            markAbsent: true
        )
        let passes = await store.markAbsentPassCount
        XCTAssertEqual(passes, 1, "3 tiles must cost one pass, not three")

        _ = await store.applyFetch(dtos: [], tileResults: [tile(lon: -90.0, ids: [])], protecting: [], markAbsent: false)
        let after = await store.markAbsentPassCount
        XCTAssertEqual(after, 1, "markAbsent: false (report probes, oversized views) must skip the pass")
    }

    func testRepositorySourceMakesOneStoreCallPerFetch() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FlockSurveillance/Services/CameraRepository.swift")
        let src = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(src.components(separatedBy: "store.applyFetch(").count - 1, 1)
        XCTAssertFalse(src.contains("markAbsentFromOSM"), "per-tile absent marking must not live in the repository")
        XCTAssertFalse(src.contains("fetch(FetchDescriptor"), "SwiftData fetches belong to CameraStore")
    }

    // MARK: Same absent rules as the old per-tile code

    func testAbsentRulesMatchPerTileBehavior() async throws {
        let container = try makeContainer()
        let store = CameraStore(modelContainer: container)

        // Cached: a1,a2 + edge e1 in tile A; e1,b1,b2 (+ hidden h1) in tile B; 10 dense in tile C.
        var seed = [
            dto("a1", 35.0, -90.02), dto("a2", 35.01, -90.01), dto("e1", 35.0, -89.96),
            dto("b1", 35.0, -89.90), dto("b2", 35.0, -89.89), dto("h1", 35.0, -89.88),
        ]
        seed += (0..<10).map { dto("c\($0)", 35.0, -89.62 + Double($0) * 0.001) }
        _ = await store.applyFetch(dtos: seed, tileResults: [], protecting: [], markAbsent: false)
        _ = await store.hide(id: "h1")

        // Prime the main context so we also verify it sees later background saves.
        let before = try rows(container)
        XCTAssertEqual(before.count, 16)
        XCTAssertTrue(before["h1"]?.isHidden == true)

        let tileA = tile(lon: -90.0, ids: ["a1", "e1"])      // 3 cached in coverage, 2 returned -> trusted
        let tileB = tile(lon: -89.92, ids: [])                // 3 visible (h1 hidden, not counted) -> sparse void trusted
        let tileC = tile(lon: -89.6, ids: [])                 // 10 cached, empty -> dense, must refuse
        let result = await store.applyFetch(
            dtos: [dto("a1", 35.0, -90.02), dto("e1", 35.0, -89.96)],
            tileResults: [tileA, tileB, tileC],
            protecting: ["a1", "e1"],
            markAbsent: true
        )

        let after = try rows(container)
        XCTAssertEqual(after["a1"]?.isAbsentFromOSM, false)
        XCTAssertEqual(after["a2"]?.isAbsentFromOSM, true, "returned-short in a trusted tile")
        XCTAssertEqual(after["e1"]?.isAbsentFromOSM, false, "edge pin returned by neighbor tile is protected")
        XCTAssertEqual(after["b1"]?.isAbsentFromOSM, true)
        XCTAssertEqual(after["b2"]?.isAbsentFromOSM, true)
        XCTAssertEqual(after["h1"]?.isHidden, true)
        XCTAssertEqual(after["h1"]?.isAbsentFromOSM, false, "explicit hide is never overridden")
        for i in 0..<10 {
            XCTAssertEqual(after["c\(i)"]?.isAbsentFromOSM, false, "dense empty tile must refuse to clear")
        }
        XCTAssertEqual(result.orderedIDs.count, 12, "a1, e1 and the 10 dense pins stay visible")
    }

    func testLaterTileSeesAbsencesMarkedByEarlierTiles() async throws {
        // Overlapping tiles: after tile 1 soft-clears x1/x2, tile 2's density gate must not count them.
        // Cached x1,x2 + y1,y2 all inside both tiles (4 cached). Old per-tile code: tile 1 sees 4 -> refuses
        // empty clear (dense). Make tile 1 non-empty so it trusts, then tile 2 (empty) sees only the survivors.
        let container = try makeContainer()
        let store = CameraStore(modelContainer: container)
        let seed = [dto("x1", 35.0, -90.0), dto("x2", 35.0, -89.99), dto("y1", 35.0, -89.98), dto("y2", 35.0, -89.97)]
        _ = await store.applyFetch(dtos: seed, tileResults: [], protecting: [], markAbsent: false)

        let overlapping = tile(lon: -89.98, ids: [])
        _ = await store.applyFetch(
            dtos: [],
            tileResults: [tile(lon: -89.98, ids: ["y1", "y2"]), overlapping],
            protecting: ["y1", "y2"],
            markAbsent: true
        )
        let flags = try rows(container)
        // Tile 1: 4 cached, 2 returned (2*2 >= 4) -> trusted, x1/x2 absent.
        // Tile 2: only y1,y2 are still visible and both are protected -> nothing else changes.
        XCTAssertEqual(flags["x1"]?.isAbsentFromOSM, true)
        XCTAssertEqual(flags["x2"]?.isAbsentFromOSM, true)
        XCTAssertEqual(flags["y1"]?.isAbsentFromOSM, false)
        XCTAssertEqual(flags["y2"]?.isAbsentFromOSM, false)
    }

    // MARK: Upsert, prune, hide

    func testUpsertPreservesHideAndKnownDirection() async throws {
        let container = try makeContainer()
        let store = CameraStore(modelContainer: container)
        _ = await store.upsert(dtos: [dto("k", 35.0, -90.0, direction: "N")])
        _ = await store.hide(id: "k")

        let result = await store.upsert(dtos: [dto("k", 35.5, -90.5, direction: nil)])
        XCTAssertTrue(result.orderedIDs.isEmpty, "hidden rows stay out of the visible set")

        let row = try XCTUnwrap(rows(container)["k"])
        XCTAssertTrue(row.isHidden)
        XCTAssertEqual(row.direction, "N", "a mirror omitting the tag must not wipe a known direction")
        XCTAssertEqual(row.latitude, 35.5, accuracy: 1e-9, "coordinates still refresh")
    }

    func testPrunesRowsOlderThanFourteenDays() async throws {
        let container = try makeContainer()
        let store = CameraStore(modelContainer: container)
        let old = Date().addingTimeInterval(-15 * 24 * 60 * 60)
        let result = await store.applyFetch(
            dtos: [dto("fresh", 35.0, -90.0), dto("stale", 35.1, -90.1, fetchedAt: old)],
            tileResults: [],
            protecting: [],
            markAbsent: false
        )
        XCTAssertEqual(result.orderedIDs.count, 1)
        let ids = Set(try rows(container).keys)
        XCTAssertEqual(ids, ["fresh"])
    }

    func testLoadIsNewestFirstAndIndexMatchesOrder() async throws {
        let store = CameraStore(modelContainer: try makeContainer())
        let now = Date()
        let result = await store.upsert(dtos: [
            dto("oldest", 35.0, -90.0, fetchedAt: now.addingTimeInterval(-300)),
            dto("newest", 35.1, -90.1, fetchedAt: now),
            dto("middle", 35.2, -90.2, fetchedAt: now.addingTimeInterval(-100)),
        ])
        XCTAssertEqual(result.index.points.map(\.id), ["newest", "middle", "oldest"])
        XCTAssertEqual(result.index.count, result.orderedIDs.count)
        XCTAssertEqual(result.latestFetchedAt, now)
    }

    func testHideDropsFromLoadAndMainContextSeesIt() async throws {
        let container = try makeContainer()
        let store = CameraStore(modelContainer: container)
        _ = await store.upsert(dtos: [dto("p", 35.0, -90.0), dto("q", 35.1, -90.1)])
        let primed = try rows(container)
        XCTAssertEqual(primed["p"]?.isHidden, false)

        let result = await store.hide(id: "p")
        XCTAssertEqual(result.index.points.map(\.id), ["q"])
        XCTAssertEqual(try rows(container)["p"]?.isHidden, true, "main context must pick up the background save")
    }

    func testMainContextResolvesBackgroundLoadIDs() async throws {
        let container = try makeContainer()
        let store = CameraStore(modelContainer: container)
        let result = await store.upsert(dtos: [dto("m1", 35.0, -90.0), dto("m2", 35.2, -90.2)])
        let models = result.orderedIDs.compactMap { container.mainContext.model(for: $0) as? ALPRCamera }
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(Set(models.map(\.id)), ["m1", "m2"])

        // Update through the background actor; an already-registered main-context model must refresh.
        _ = await store.upsert(dtos: [dto("m1", 36.0, -91.0)])
        let m1 = try XCTUnwrap(try rows(container)["m1"])
        XCTAssertEqual(m1.latitude, 36.0, accuracy: 1e-9)
    }

    func testClearAllEmptiesTheStore() async throws {
        let container = try makeContainer()
        let store = CameraStore(modelContainer: container)
        _ = await store.upsert(dtos: [dto("z", 35.0, -90.0)])
        await store.clearAll()
        let result = await store.load()
        XCTAssertTrue(result.orderedIDs.isEmpty)
        XCTAssertTrue(try rows(container).isEmpty)
    }
}
