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

    const {prompt, mode, exerciseName, view, size} = req.body ?? {};
    const isExerciseMode = mode === "exercise";
    const isImageMode = mode === "image";
    const systemPrompt = isExerciseMode
      ? "You are a fitness coach. Return JSON only in Japanese. " +
        "Format: {\"exercises\":[{name,sets,repsOrSeconds,rest,notes," +
        "tips:[string],steps:[string]}] }"
      : "You are a fitness coach. Return JSON only in Japanese. " +
        "Format: {\"plans\":[{name,durationWeeks,daysPerWeek,intensity," +
        "summary,exercises:[{name,sets,repsOrSeconds,rest,notes," +
        "tips:[string],steps:[string]}],caution}] }";

    try {
      if (isImageMode) {
        if (!exerciseName || typeof exerciseName !== "string") {
          res.status(400).json({error: "exerciseName is required"});
          return;
        }
        const viewText = typeof view === "string" && view ? view : "front";
        const sizeNum = typeof size === "number" ? size : 512;
        const sizeParam = sizeNum <= 1024 ? "1024x1024" : "1536x1024";
        const imagePrompt =
          "Flat vector illustration of proper exercise form: " +
          `"${exerciseName}", ${viewText} view. ` +
          "Simple light background, gender-neutral, fully clothed, " +
          "clear posture and joint angles, high contrast. " +
          "No text, no watermark, non-photorealistic.";

        const imgResp = await fetch(
          "https://api.openai.com/v1/images/generations",
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${openaiKey.value()}`,
            },
            body: JSON.stringify({
              model: "gpt-image-1",
              prompt: imagePrompt,
              size: sizeParam,
            }),
          },
        );

        const imgData = await imgResp.json();
        if (!imgResp.ok) {
          logger.error("OpenAI image error", imgData);
          res.status(500).json({
            error: "OpenAI image request failed",
            data: imgData,
          });
          return;
        }
        const b64 = imgData?.data?.[0]?.b64_json;
        if (!b64 || typeof b64 !== "string") {
          logger.error("Image response missing b64_json", imgData);
          res.status(500).json({error: "Image response missing b64_json"});
          return;
        }
        res.json({b64_json: b64});
        return;
      }

      if (!prompt || typeof prompt !== "string") {
        res.status(400).json({error: "prompt is required"});
        return;
      }

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
              content: systemPrompt,
            },
            {role: "user", content: prompt},
          ],
          temperature: 0.7,
          response_format: {type: "json_object"},
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
      try {
        const jsonObj = JSON.parse(text);
        res.json(jsonObj);
      } catch (e) {
        logger.error("JSON parse failed", {text});
        res.status(500).json({error: "Invalid JSON from model"});
      }
      return;
    } catch (e) {
      logger.error("Server error", e);
      res.status(500).json({error: "Server error"});
      return;
    }
  }
);
