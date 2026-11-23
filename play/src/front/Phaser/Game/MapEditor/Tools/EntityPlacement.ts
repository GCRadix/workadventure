const TILE = 32;

/**
 * Where an object being placed goes, as its top-left corner, for a mouse at (pointerX, pointerY).
 *
 * The mouse holds the object by its base (the tile it stands on), not by the centre of its image, so tall objects
 * such as trees are placed where they stand:
 * - with a collision grid: the middle blocking tile of its lowest blocking row (a tree's trunk),
 * - otherwise: the middle tile of its bottom row.
 *
 * With `snap` (objects with a collision grid, or Shift held) the object snaps to the 32 px grid, so its collisions
 * line up with the map. Without it, the object is horizontally centred on the mouse, half a tile above its bottom edge.
 */
export function getEntityPlacementTopLeft(
    pointerX: number,
    pointerY: number,
    width: number,
    height: number,
    collisionGrid: number[][] | undefined,
    snap: boolean,
): { x: number; y: number } {
    if (!snap) {
        return {
            x: Math.floor(pointerX - width / 2),
            y: Math.floor(pointerY - (height - Math.min(TILE / 2, height / 2))),
        };
    }

    const tilesWide = Math.max(1, Math.ceil(width / TILE));
    const tilesHigh = Math.max(1, Math.ceil(height / TILE));

    // the anchor tile, counted from the top-left of the object
    let anchorColumn = Math.floor(tilesWide / 2);
    let anchorRow = tilesHigh - 1;
    if (collisionGrid) {
        for (let row = collisionGrid.length - 1; row >= 0; row--) {
            const blocking = collisionGrid[row]
                .map((value, column) => (value === 1 ? column : -1))
                .filter((column) => column !== -1);
            if (blocking.length > 0) {
                anchorRow = row;
                anchorColumn = blocking[Math.floor((blocking.length - 1) / 2)];
                break;
            }
        }
    }

    return {
        x: (Math.floor(pointerX / TILE) - anchorColumn) * TILE,
        y: (Math.floor(pointerY / TILE) - anchorRow) * TILE,
    };
}
