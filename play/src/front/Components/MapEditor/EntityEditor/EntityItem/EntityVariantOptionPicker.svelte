<script lang="ts">
    import type { EntityVariant } from "../../../../Phaser/Game/MapEditor/Entities/EntityVariant";

    interface Props {
        entityVariant: EntityVariant;
        selectedVariant: string;
        onVariantChange: (variant: string) => void;
    }

    let { entityVariant, selectedVariant, onVariantChange }: Props = $props();
</script>

{#if entityVariant.variants.length > 1}
    <p class="m-0 text-xxs">Variants</p>
    <div class="flex flex-row flex-wrap gap-2">
        {#each entityVariant.variants as variant (variant)}
            {@const preview = entityVariant.getVariantPreview(variant)}
            {#if preview}
                <button
                    type="button"
                    title={variant}
                    aria-label={variant}
                    class={`p-0 bg-transparent hover:cursor-pointer ${
                        selectedVariant === variant ? "border-solid border-yellow-400 rounded-sm" : ""
                    }`}
                    onclick={() => onVariantChange(variant)}
                >
                    <img
                        draggable="false"
                        class="item-image max-w-[32px] max-h-[32px] object-contain"
                        src={preview.imagePath}
                        alt={variant}
                    />
                </button>
            {/if}
        {/each}
    </div>
{/if}
