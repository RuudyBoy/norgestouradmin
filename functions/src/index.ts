import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

type MatchData = Record<string, unknown>;

/**
 * MatchRunner — triggers when a match is marked as finished.
 *
 * Group stage (group_match_3 / group_match_4):
 *   Sets group_placement (1–4) on both teams.
 *
 * Playoff stage:
 *   Copies the winner's team data into the next match's slot.
 *   Flips next match status to 'scheduled' once both slots are filled.
 */
export const matchRunner = onDocumentUpdated(
  "matches/{matchId}",
  async (event) => {
    const before = event.data?.before.data() as MatchData | undefined;
    const after = event.data?.after.data() as MatchData | undefined;

    if (!before || !after) return;

    // Only run on the transition to 'finished', not on subsequent writes.
    if (before["status"] === "finished" || after["status"] !== "finished") {
      return;
    }

    const stage = after["stage"] as string | undefined;
    const matchType = after["match_type"] as string | undefined;

    const homeScore = (after["home_score"] as number) ?? 0;
    const awayScore = (after["away_score"] as number) ?? 0;
    const homeWins = homeScore > awayScore;

    // ── Group stage: set placements on teams ─────────────────────────────────
    if (stage === "group") {
      if (matchType !== "group_match_3" && matchType !== "group_match_4") {
        return;
      }

      const winnerTeamId = homeWins
        ? (after["team_a_id"] as string)
        : (after["team_b_id"] as string);
      const loserTeamId = homeWins
        ? (after["team_b_id"] as string)
        : (after["team_a_id"] as string);

      const winnerPlace = matchType === "group_match_3" ? 1 : 3;
      const loserPlace = matchType === "group_match_3" ? 2 : 4;

      const batch = db.batch();
      if (winnerTeamId && winnerTeamId !== "placeholder") {
        batch.update(db.collection("teams").doc(winnerTeamId), {
          group_placement: winnerPlace,
        });
      }
      if (loserTeamId && loserTeamId !== "placeholder") {
        batch.update(db.collection("teams").doc(loserTeamId), {
          group_placement: loserPlace,
        });
      }
      await batch.commit();
      return;
    }

    // ── Playoff stage: advance winner to next match ──────────────────────────
    if (stage === "playoff") {
      const nextMatchId = after["next_match_id"] as string | undefined;
      const nextMatchSlot = after["next_match_slot"] as string | undefined; // 'a' | 'b'

      if (!nextMatchId || !nextMatchSlot) {
        // This is the final match — no next match to advance to.
        return;
      }

      // Source prefix in THIS match (winner's data lives here).
      const srcPfx = homeWins ? "team_a" : "team_b";
      // Destination prefix in the NEXT match.
      const dstPfx = nextMatchSlot === "a" ? "team_a" : "team_b";
      // The OTHER slot in the next match (already filled or still placeholder).
      const otherPfx = nextMatchSlot === "a" ? "team_b" : "team_a";

      const updateFields: Record<string, unknown> = {
        [`${dstPfx}_name`]: after[`${srcPfx}_name`] ?? "",
        [`${dstPfx}_id`]: after[`${srcPfx}_id`],
        [`${dstPfx}_p1_name`]: after[`${srcPfx}_p1_name`] ?? "",
        [`${dstPfx}_p1_id`]: after[`${srcPfx}_p1_id`] ?? "",
        [`${dstPfx}_p2_name`]: after[`${srcPfx}_p2_name`] ?? "",
        [`${dstPfx}_p2_id`]: after[`${srcPfx}_p2_id`] ?? "",
      };

      const nextMatchRef = db.collection("matches").doc(nextMatchId);
      const nextMatchSnap = await nextMatchRef.get();
      if (!nextMatchSnap.exists) return;

      const nextData = nextMatchSnap.data() as MatchData;
      const otherTeamId = nextData[`${otherPfx}_id`] as string | undefined;

      // If the other slot is already a real team, both slots will be filled
      // after this update — flip the match to 'scheduled'.
      if (otherTeamId && otherTeamId !== "placeholder") {
        updateFields["status"] = "scheduled";
      }

      await nextMatchRef.update(updateFields);
      return;
    }
  }
);
