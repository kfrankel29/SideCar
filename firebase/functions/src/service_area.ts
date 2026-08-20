type AddressComponent = {
  shortText?: unknown;
  longText?: unknown;
  short_name?: unknown;
  long_name?: unknown;
  types?: unknown;
};

export const californiaRegionCode = "CA";

export function administrativeAreaCode(value: unknown): string {
  if (!Array.isArray(value)) return "";
  for (const item of value) {
    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
    const component = item as AddressComponent;
    const types = Array.isArray(component.types) ? component.types : [];
    if (!types.includes("administrative_area_level_1")) continue;
    const shortName = typeof component.shortText === "string" ?
      component.shortText : component.short_name;
    const longName = typeof component.longText === "string" ?
      component.longText : component.long_name;
    if (typeof shortName === "string") {
      return shortName.trim().toUpperCase();
    }
    if (typeof longName === "string" &&
        longName.trim().toLowerCase() === "california") {
      return californiaRegionCode;
    }
  }
  return "";
}

export function isCaliforniaAddress(value: unknown): boolean {
  return administrativeAreaCode(value) === californiaRegionCode;
}
