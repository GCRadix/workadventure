import type { GameMapAreas } from "../GameMap/GameMapAreas";
import type { EntityCoordinates } from "../types";

export class EntityPermissions {
    constructor(
        private gameMapAreas: GameMapAreas,
        private userConnectedTags: string[],
        private userCanEdit?: boolean,
        private userUUID?: string,
    ) {}

    /**
     * @param entityTopLeft the entity position (its top-left corner)
     * @param width the entity size: its base (bottom tile row) must overlap a zone the user can write to.
     *              Without a size, the top-left corner must be.
     */
    public canEdit(entityTopLeft: EntityCoordinates, width: number = 0, height: number = 0): boolean {
        if (this.userCanEdit) {
            return true;
        }
        return this.gameMapAreas.isUserHasWriteAccessOnAreaForEntityCoordinates(
            entityTopLeft,
            this.userConnectedTags,
            this.userUUID,
            width,
            height,
        );
    }

    public canRead(entityCenterCoordinates: EntityCoordinates): boolean {
        if (this.userCanEdit) {
            return true;
        }
        return this.isEntityInsideAreaWithUserReadAccess(entityCenterCoordinates);
    }

    private isEntityInsideAreaWithUserReadAccess(entityCenterCoordinates: EntityCoordinates) {
        return this.gameMapAreas.isUserHasReadAccessOnAreaForEntityCoordinates(
            entityCenterCoordinates,
            this.userConnectedTags,
        );
    }
}
