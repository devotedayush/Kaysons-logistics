import { responseLanguage } from "./language.ts";

Deno.test("uses the selected Hindi interface for English questions", () => {
  if (responseLanguage("How many PODs are pending?", "hi") !== "Hindi") {
    throw new Error("Expected Hindi response");
  }
});

Deno.test("recognizes Hindi questions independently of interface locale", () => {
  if (responseLanguage("कितने POD बाकी हैं?", "en") !== "Hindi") {
    throw new Error("Expected Hindi response");
  }
  if (responseLanguage("Please reply in Hindi", "en") !== "Hindi") {
    throw new Error("Expected Hindi response");
  }
});

Deno.test("honors an explicit English request within the Hindi interface", () => {
  if (responseLanguage("Please reply in English", "hi") !== "English") {
    throw new Error("Expected English response");
  }
});
