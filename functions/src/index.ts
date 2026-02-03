import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();

const openaiKey = defineSecret("OPENAI_API_KEY");

export const generateMenu = onRequest(
  {cors: true, secrets: [openaiKey]},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "Method Not Allowed"});
      return;
    }

    // 認証トークン（Firebase Auth）を必須にする
    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      res.status(401).json({error: "Missing auth token"});
      return;
    }
    const idToken = authHeader.replace("Bearer ", "");
    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      logger.warn("Auth failed", e);
      res.status(401).json({error: "Invalid auth token"});
      return;
    }

    const {prompt} = req.body ?? {};
    if (!prompt || typeof prompt !== "string") {
      res.status(400).json({error: "prompt is required"});
      return;
    }

    try {
      const resp = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${openaiKey.value()}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [
            {
              role: "system",
              content: [
                "You are a fitness coach.",
                "Return a short workout menu in Japanese.",
              ].join(" "),
            },
            {role: "user", content: prompt},
          ],
          temperature: 0.7,
        }),
      });

      const data = await resp.json();

      if (!resp.ok) {
        logger.error("OpenAI error", data);
        res.status(500).json({
          error: "OpenAI request failed",
          data,
        });
        return;
      }

      const text = data?.choices?.[0]?.message?.content ?? "";
      res.json({text});
      return;
    } catch (e) {
      logger.error("Server error", e);
      res.status(500).json({error: "Server error"});
      return;
    }
  }
);
