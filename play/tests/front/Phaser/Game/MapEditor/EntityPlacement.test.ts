import { describe, expect, it } from "vitest";
import { getEntityPlacementTopLeft } from "../../../../../src/front/Phaser/Game/MapEditor/Tools/EntityPlacement";

describe("getEntityPlacementTopLeft", () => {
    // the mouse is in map tile (10, 20), i.e. pixels 320..351 x 640..671
    const mouse = { x: 330, y: 650 };

    it("holds a tree by its trunk: the blocking tile lands under the mouse", () => {
        // birch: 5 x 5 tiles, the trunk is the middle tile of the bottom row
        const grid = [
            [0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0],
            [0, 0, 1, 0, 0],
        ];
        const topLeft = getEntityPlacementTopLeft(mouse.x, mouse.y, 160, 160, grid, true);
        // trunk tile = top-left + (2, 4) tiles = tile (10, 20)
        expect(topLeft).toEqual({ x: (10 - 2) * 32, y: (20 - 4) * 32 });
    });

    it("uses the middle blocking tile of the lowest blocking row", () => {
        // a 3-wide table blocking its whole bottom row: anchor is the middle tile
        const grid = [
            [0, 0, 0],
            [1, 1, 1],
        ];
        expect(getEntityPlacementTopLeft(mouse.x, mouse.y, 96, 64, grid, true)).toEqual({
            x: (10 - 1) * 32,
            y: (20 - 1) * 32,
        });
        // an off-centre collider: the object shifts so that collider is under the mouse
        const offCentre = [
            [0, 0, 0, 0],
            [0, 0, 0, 1],
        ];
        expect(getEntityPlacementTopLeft(mouse.x, mouse.y, 128, 64, offCentre, true)).toEqual({
            x: (10 - 3) * 32,
            y: (20 - 1) * 32,
        });
    });

    it("snaps to the bottom middle tile when there is no blocking tile (Shift held)", () => {
        expect(getEntityPlacementTopLeft(mouse.x, mouse.y, 128, 160, undefined, true)).toEqual({
            x: (10 - 2) * 32,
            y: (20 - 4) * 32,
        });
    });

    it("free placement centres horizontally and keeps the mouse half a tile above the bottom", () => {
        const topLeft = getEntityPlacementTopLeft(mouse.x, mouse.y, 40, 100, undefined, false);
        expect(topLeft).toEqual({ x: 330 - 20, y: 650 - (100 - 16) });
        // a tiny object: the mouse stays in its middle
        expect(getEntityPlacementTopLeft(mouse.x, mouse.y, 10, 14, undefined, false)).toEqual({
            x: 325,
            y: 643,
        });
    });
});
