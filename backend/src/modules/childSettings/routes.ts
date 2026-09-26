import type { FastifyInstance } from "fastify";

import { requireAuth, requireRole } from "../../auth/plugin.js";
import { pool } from "../../lib/db.js";
import { HttpError } from "../../lib/errors.js";
import { bodySchema } from "../../lib/schema.js";

interface ChildSettingsRow {
  difficulty: "SIMPLE" | "ADVANCED";
  sound_enabled: boolean;
  music_enabled: boolean;
  animations_enabled: boolean;
  large_text_enabled: boolean;
}

function response(row: ChildSettingsRow) {
  return {
    difficulty: row.difficulty,
    soundEnabled: row.sound_enabled,
    musicEnabled: row.music_enabled,
    animationsEnabled: row.animations_enabled,
    largeTextEnabled: row.large_text_enabled,
  };
}

export async function childSettingsRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    "/child/settings",
    { preHandler: [requireAuth, requireRole("CHILD")] },
    async (req) => {
      const res = await pool.query<ChildSettingsRow>(
        `SELECT difficulty, sound_enabled, music_enabled,
                animations_enabled, large_text_enabled
           FROM child_profiles WHERE user_id = $1`,
        [req.authUser!.id],
      );
      const settings = res.rows[0];
      if (!settings) throw new HttpError(404, "child_profile_not_found");
      return response(settings);
    },
  );

  app.put<{
    Body: {
      difficulty: "SIMPLE" | "ADVANCED";
      soundEnabled: boolean;
      musicEnabled: boolean;
      largeTextEnabled: boolean;
    };
  }>(
    "/child/settings",
    {
      preHandler: [requireAuth, requireRole("CHILD")],
      schema: bodySchema(
        {
          difficulty: { type: "string", enum: ["SIMPLE", "ADVANCED"] },
          soundEnabled: { type: "boolean" },
          musicEnabled: { type: "boolean" },
          largeTextEnabled: { type: "boolean" },
        },
        ["difficulty", "soundEnabled", "musicEnabled", "largeTextEnabled"],
      ),
    },
    async (req) => {
      const res = await pool.query<ChildSettingsRow>(
        `UPDATE child_profiles
            SET difficulty = $2,
                sound_enabled = $3,
                music_enabled = $4,
                large_text_enabled = $5,
                updated_at = now()
          WHERE user_id = $1
          RETURNING difficulty, sound_enabled, music_enabled,
                    animations_enabled, large_text_enabled`,
        [
          req.authUser!.id,
          req.body.difficulty,
          req.body.soundEnabled,
          req.body.musicEnabled,
          req.body.largeTextEnabled,
        ],
      );
      const settings = res.rows[0];
      if (!settings) throw new HttpError(404, "child_profile_not_found");
      return response(settings);
    },
  );
}
