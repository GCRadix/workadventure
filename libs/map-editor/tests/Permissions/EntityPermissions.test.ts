import { describe, expect, it } from "vitest";
import { EntityPermissions, WamFile } from "../../src";

describe("EntityPermissions", () => {
    const wamFile = new WamFile({
        version: "1.0.0",
        mapUrl: "testMapUrl",
        entities: {},
        entityCollections: [],
        areas: [
            {
                id: "zone",
                name: "zone",
                x: 0,
                y: 0,
                width: 320,
                height: 320,
                visible: true,
                properties: [
                    { id: "rights", type: "restrictedRightsPropertyData", writeTags: ["editor"], readTags: [] },
                ],
            },
        ],
    });
    const permissions = new EntityPermissions(wamFile.getGameMapAreas(), ["editor"], false);

    // The zone is (0,0)-(320,320). canEdit takes the entity's top-left corner and its size.

    it("allows a wide entity fully inside the zone", () => {
        expect(permissions.canEdit({ x: 0, y: 100 }, 128, 32)).toBe(true);
    });

    it("allows an entity as long as one pixel of its base is in the zone", () => {
        expect(permissions.canEdit({ x: -32, y: 100 }, 128, 32)).toBe(true);
        // only the last pixel column of the base is in the zone
        expect(permissions.canEdit({ x: -127, y: 100 }, 128, 32)).toBe(true);
        // only the last pixel row of the base is in the zone
        expect(permissions.canEdit({ x: 0, y: -31 }, 128, 32)).toBe(true);
    });

    it("refuses an entity whose base only touches the edge of the zone", () => {
        expect(permissions.canEdit({ x: -128, y: 100 }, 128, 32)).toBe(false);
        expect(permissions.canEdit({ x: 0, y: 320 }, 128, 32)).toBe(false);
    });

    it("allows a tree whose crown sticks out of the zone when its base is inside", () => {
        // 160x160 tree, top-left corner above the zone: its bottom row (y 96..128) is inside.
        expect(permissions.canEdit({ x: 0, y: -32 }, 160, 160)).toBe(true);
        // crown sticking out to the right too
        expect(permissions.canEdit({ x: 160, y: -32 }, 160, 160)).toBe(true);
    });

    it("refuses a tree whose base is out of the zone, even if its crown is in it", () => {
        // base row y 320..352: below the zone, the crown (y 192..320) is inside
        expect(permissions.canEdit({ x: 0, y: 192 }, 160, 160)).toBe(false);
        // base row x 320..480: right of the zone
        expect(permissions.canEdit({ x: 320, y: 0 }, 160, 160)).toBe(false);
    });

    it("caps the height used for rights, so a fake size cannot move the base far into a zone", () => {
        // top-left 1000 px above the zone: with a claimed height of 1100 the base would be inside
        expect(permissions.canEdit({ x: 0, y: -1000 }, 32, 1100)).toBe(false);
    });

    it("checks the top-left corner when no size is given", () => {
        expect(permissions.canEdit({ x: 32, y: 32 })).toBe(true);
        expect(permissions.canEdit({ x: -32, y: 32 })).toBe(false);
    });
});
