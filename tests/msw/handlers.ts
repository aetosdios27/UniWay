import { http, HttpResponse } from "msw";
import { campus, buildings, rooms, pois, csLecturePoi, CAMPUS_ID, ENG_BLDG_ID } from "@/tests/fixtures/sample-campus";
import { mockPolygon } from "@/tests/fixtures/geojson";

export const handlers = [
  http.get("*/api/campus", () =>
    HttpResponse.json({ data: [campus] })
  ),

  http.get("*/api/campus/:id", ({ params }) =>
    HttpResponse.json({
      data: {
        campus: { id: params.id, name: "Main Campus", bounds: mockPolygon },
        buildings: buildings.map((b) => ({ id: b.id, name: b.name, outline: b.outline, floors: ["1", "2"] })),
        poiCounts: [
          { category: "lecture_hall", count: 1 },
          { category: "lab", count: 2 },
          { category: "cafeteria", count: 1 },
          { category: "office", count: 1 },
          { category: "restroom", count: 1 },
        ],
      },
    })
  ),

  http.get("*/api/campus/:id/pois", () =>
    HttpResponse.json({ data: pois })
  ),

  http.get("*/api/campus/:id/buildings", () =>
    HttpResponse.json({ data: buildings })
  ),

  http.get("*/api/campus/:id/rooms", () =>
    HttpResponse.json({ data: rooms.map((r) => ({ id: r.id, building_id: r.building_id, floor: r.floor, name: r.name })) })
  ),

  http.get("*/api/campus/:id/nearby", ({ request }) => {
    const url = new URL(request.url);
    if (!url.searchParams.has("lat") || !url.searchParams.has("lng")) {
      return HttpResponse.json({ error: "Missing or invalid parameters", code: "BAD_REQUEST", requestId: "test" }, { status: 400 });
    }
    const type = url.searchParams.get("type");
    if (type === "rooms") {
      return HttpResponse.json({ data: rooms.slice(0, 2) });
    }
    return HttpResponse.json({ data: pois.slice(0, 2) });
  }),

  http.get("*/api/campus/:id/route", () =>
    HttpResponse.json({
      data: {
        type: "Feature",
        properties: { distance_meters: 10 },
        geometry: { type: "LineString", coordinates: [[0, 0], [1, 1]] },
      },
    })
  ),

  http.get("*/api/pois/:id", ({ params }) => {
    const poi = pois.find((p) => p.id === params.id);
    if (!poi) {
      return HttpResponse.json({ error: "POI not found", code: "NOT_FOUND", requestId: "test" }, { status: 404 });
    }
    const room = rooms.find((r) => r.id === poi.room_id);
    return HttpResponse.json({
      data: {
        ...poi,
        room_name: room?.name ?? "",
        floor: room?.floor ?? "",
        building_id: ENG_BLDG_ID,
        building_name: "Engineering Building",
      },
    });
  }),

  http.get("*/api/rooms/:id", ({ params }) => {
    const room = rooms.find((r) => r.id === params.id);
    if (!room) {
      return HttpResponse.json({ error: "Room not found", code: "NOT_FOUND", requestId: "test" }, { status: 404 });
    }
    const building = buildings.find((b) => b.id === room.building_id);
    return HttpResponse.json({
      data: {
        ...room,
        building_name: building?.name ?? "",
        campus_id: CAMPUS_ID,
        campus_name: "Main Campus",
      },
    });
  }),

  http.get("*/api/route", ({ request }) => {
    const url = new URL(request.url);
    if (!url.searchParams.has("fromLng")) {
      return HttpResponse.json({ error: "Missing required parameters" }, { status: 400 });
    }
    return HttpResponse.json({
      data: {
        type: "Feature",
        properties: { distance_meters: 10 },
        geometry: { type: "LineString", coordinates: [[0, 0], [1, 1]] },
      },
    });
  }),

  http.get("*/api/search", ({ request }) => {
    const url = new URL(request.url);
    if (!url.searchParams.has("q") || !url.searchParams.has("campus")) {
      return HttpResponse.json({ error: "Missing or invalid parameters" }, { status: 400 });
    }
    return HttpResponse.json({
      data: [
        { ...csLecturePoi, rank: 0.12, floor: "1", building_id: ENG_BLDG_ID, building_name: "Engineering Building" },
      ],
    });
  }),

  http.post("*/api/report", async ({ request }) => {
    const body = (await request.json()) as { description?: string };
    if (!body.description) {
      return HttpResponse.json({ error: "Invalid request body" }, { status: 400 });
    }
    return HttpResponse.json(
      {
        data: { id: "123e4567-e89b-12d3-a456-426614174000", room_id: null, edge_id: null, description: body.description, status: "open", reported_at: "2026-01-01T00:00:00.000Z", resolved_at: null },
      },
      { status: 201 }
    );
  }),
];
