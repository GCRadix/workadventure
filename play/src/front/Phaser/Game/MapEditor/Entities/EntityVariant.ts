import type { EntityPrefab } from "@workadventure/map-editor";
import * as Sentry from "@sentry/svelte";

/**
 * All prefabs shown as one tile in the map editor: variant -> color -> direction.
 * Prefabs without a variant all sit in the "" variant, so collections that don't use variants behave as before.
 */
export class EntityVariant {
    private readonly _id: string;
    private readonly _defaultPrefab: EntityPrefab;
    private variantsByName: Map<string, Map<string, Map<string, EntityPrefab>>>;
    constructor(defaultPrefab: EntityPrefab) {
        this._id = defaultPrefab.id;
        this._defaultPrefab = defaultPrefab;
        this.variantsByName = new Map();
        this.addPrefab(defaultPrefab);
    }

    public get id(): string {
        return this._id;
    }

    public get defaultPrefab(): EntityPrefab {
        return this._defaultPrefab;
    }

    /** Variant names, in collection order. Contains only "" when the collection doesn't use variants. */
    public get variants(): string[] {
        return [...this.variantsByName.keys()];
    }

    public getColors(variant: string): string[] {
        return [...(this.variantsByName.get(variant)?.keys() ?? [])];
    }

    /** The prefab used as the thumbnail of a variant: its first color, facing Down if it has that direction. */
    public getVariantPreview(variant: string): EntityPrefab | undefined {
        const firstColor = this.variantsByName.get(variant)?.values().next().value;
        return firstColor?.get("Down") ?? firstColor?.values().next().value;
    }

    public getEntityPrefabsPositions(color: string, variant: string): EntityPrefab[] {
        const entityPrefabsPositions = this.variantsByName.get(variant)?.get(color);
        if (!entityPrefabsPositions) {
            Sentry.captureException("Could not find color for variant");
            throw new Error("Could not find color for variant");
        }
        return [...entityPrefabsPositions.values()];
    }

    public get prefabIds(): string[] {
        return [...this.variantsByName.values()].flatMap((colors) =>
            [...colors.values()].flatMap((positions) => [...positions.values()].map((prefab) => prefab.id)),
        );
    }

    public addPrefab(prefab: EntityPrefab) {
        const variant = prefab.variant ?? "";
        let colorMap = this.variantsByName.get(variant);
        if (colorMap === undefined) {
            colorMap = new Map<string, Map<string, EntityPrefab>>();
            this.variantsByName.set(variant, colorMap);
        }
        let positionMap = colorMap.get(prefab.color);
        if (positionMap === undefined) {
            positionMap = new Map<string, EntityPrefab>();
            colorMap.set(prefab.color, positionMap);
        }
        positionMap.set(prefab.direction, prefab);
    }
}
