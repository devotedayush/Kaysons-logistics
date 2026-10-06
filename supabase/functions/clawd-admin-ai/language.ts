export type ClawdLanguage = "English" | "Hindi";

export function responseLanguage(
  question: string,
  requestedLanguage: string,
): ClawdLanguage {
  if (/\b(?:reply|answer|respond|write)\s+in\s+english\b/i.test(question)) {
    return "English";
  }
  if (
    /[\u0900-\u097f]/.test(question) ||
    /\b(?:hindi|hindee)\b/i.test(question) ||
    requestedLanguage.toLowerCase().startsWith("hi")
  ) {
    return "Hindi";
  }
  return "English";
}
