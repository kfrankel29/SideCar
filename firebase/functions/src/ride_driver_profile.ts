export function preferredDriverPhotoUrl(
  currentProfilePhotoUrl: unknown,
  storedRidePhotoUrl: unknown,
): string {
  const current = typeof currentProfilePhotoUrl === "string" ?
    currentProfilePhotoUrl.trim() : "";
  if (current) return current;
  return typeof storedRidePhotoUrl === "string" ? storedRidePhotoUrl.trim() : "";
}
