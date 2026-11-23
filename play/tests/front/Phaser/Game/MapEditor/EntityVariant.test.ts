import { describe, expect, it } from "vitest";
import type { EntityPrefab } from "@workadventure/map-editor";
import { EntityVariant } from "../../../../../src/front/Phaser/Game/MapEditor/Entities/EntityVariant";

function prefab(id: string, color: string, direction: EntityPrefab["direction"], variant?: string): EntityPrefab {
    return {
        id,
        name: "Radiator",
        tags: [],
        imagePath: `${id}.png`,
        direction,
        color,
        variant,
        collectionName: "Test",
        type: "Default",
    };
}

describe("EntityVariant", () => {
    it("groups prefabs without a variant by color and direction, as before", () => {
        const entity = new EntityVariant(prefab("a", "#fff", "Down"));
        entity.addPrefab(prefab("b", "#fff", "Left"));
        entity.addPrefab(prefab("c", "#000", "Down"));

        expect(entity.variants).toEqual([""]);
        expect(entity.getColors("")).toEqual(["#fff", "#000"]);
        expect(entity.getEntityPrefabsPositions("#fff", "").map((p) => p.id)).toEqual(["a", "b"]);
        expect(entity.prefabIds).toEqual(["a", "b", "c"]);
    });

    it("keeps colors and directions per variant", () => {
        const entity = new EntityVariant(prefab("large-white", "#fff", "Down", "Large"));
        entity.addPrefab(prefab("large-grey", "#888", "Down", "Large"));
        entity.addPrefab(prefab("small-white-left", "#fff", "Left", "Small"));
        entity.addPrefab(prefab("small-white-down", "#fff", "Down", "Small"));

        expect(entity.variants).toEqual(["Large", "Small"]);
        expect(entity.getColors("Large")).toEqual(["#fff", "#888"]);
        expect(entity.getColors("Small")).toEqual(["#fff"]);
        expect(entity.getEntityPrefabsPositions("#fff", "Small").map((p) => p.id)).toEqual([
            "small-white-left",
            "small-white-down",
        ]);
        // the thumbnail of a variant faces Down when it can
        expect(entity.getVariantPreview("Small")?.id).toBe("small-white-down");
        expect(() => entity.getEntityPrefabsPositions("#888", "Small")).toThrow();
    });
});
