export function conversationPairKey(leftUserId: string, rightUserId: string): string {
  return [leftUserId.trim(), rightUserId.trim()].sort().join("::");
}

export function conversationDocumentId(leftUserId: string, rightUserId: string): string {
  return `pair_${[leftUserId.trim(), rightUserId.trim()].sort().join("_")}`;
}
