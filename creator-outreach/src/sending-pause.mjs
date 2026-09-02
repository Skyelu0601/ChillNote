import fs from "node:fs/promises";
import { sendingPausePath } from "./config.mjs";

export async function assertSendingAllowed() {
  try {
    const reason = (await fs.readFile(sendingPausePath, "utf8")).trim();
    throw new Error(
      `Live sending is paused${reason ? `: ${reason}` : "."} Remove the pause only after explicit review.`,
    );
  } catch (error) {
    if (error.code === "ENOENT") return;
    throw error;
  }
}

export async function pauseSending(reason) {
  await fs.writeFile(sendingPausePath, `${reason.trim()}\n`, "utf8");
}
