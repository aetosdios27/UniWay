import { z } from "zod";
import iconKeysConfig from "@/data/poi-icon-keys.json";

export const POI_ICON_KEYS = iconKeysConfig.keys as [string, ...string[]];
export const POI_ICON_FALLBACK = iconKeysConfig.fallback;

export const PoiIconKeySchema = z.enum(POI_ICON_KEYS, {
  message: `Invalid icon_key. Allowed keys: ${POI_ICON_KEYS.join(", ")}`,
});

export type PoiIconKey = z.infer<typeof PoiIconKeySchema>;
