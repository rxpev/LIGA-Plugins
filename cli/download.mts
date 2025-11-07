#!/usr/bin/env node --no-warnings
/**
 * Downloads AMX Mod X, SourceMod, and
 * their associated MetaMod version.
 *
 * @module
 */
import path from "node:path";
import fs from "node:fs";
import compressing from "compressing";
import AppInfo from "../package.json" assert { type: "json" };
import { pipeline } from "node:stream/promises";
import { ReadableStream } from "node:stream/web";
import { Readable } from "node:stream";
import { Command } from "commander";

/** @enum */
enum Endpoint {
  AMXX = "https://www.amxmodx.org/amxxdrop/1.9/amxmodx-1.9.0-git5294-base-windows.zip",
  AMXX_CSTRIKE = "https://www.amxmodx.org/amxxdrop/1.9/amxmodx-1.9.0-git5294-cstrike-windows.zip",
  METAMOD = "https://www.amxmodx.org/release/metamod-1.21.1-am.zip",
  METAMOD_SOURCE = "https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1217-windows.zip",
  SOURCEMOD = "https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7193-windows.zip",
}

/** @enum */
enum Mod {
  AMXX = "amxx",
  SOURCEMOD = "sourcemod",
}

/** @constant */
const DOWNLOAD_DIR = path.join(process.cwd(), "downloads");

/** @constant */
const DOWNLOAD_THROTTLE_MS = 5000;

/**
 * Downloads a file with a delay to not overload
 * servers when used programmatically.
 *
 * @param url The url to download the file from.
 * @param to  The directory to download to.
 * @function
 */
async function download(from: string, to: string) {
  // create destination file tree if it doesn't exist
  const destination = path.join(to, path.basename(from));

  try {
    await fs.promises.access(to, fs.constants.F_OK);
  } catch (error) {
    await fs.promises.mkdir(to, { recursive: true });
  }

  // do not download file if it already exists
  try {
    await fs.promises.access(destination, fs.constants.F_OK);
    console.warn("%s already exists. Skipping...", path.basename(destination));
    return Promise.resolve(destination);
  } catch (error) {
    console.info("Downloading %s...", from);
  }

  // download the file
  const response = await fetch(from);
  await pipeline(
    Readable.fromWeb(response.body as ReadableStream<Uint8Array>),
    fs.createWriteStream(destination),
  );
  await sleep(DOWNLOAD_THROTTLE_MS);
  return Promise.resolve(destination);
}

/**
 * Extracts a zip file.
 *
 * @param from  The file to extract.
 * @param to    The directory to extract to.
 * @function
 */
async function extract(from: string, to: string) {
  try {
    await fs.promises.access(to, fs.constants.F_OK);
  } catch (error) {
    await fs.promises.mkdir(to, { recursive: true });
  }

  return compressing.zip.uncompress(from, to);
}

/**
 * Implementation of sleep with promises.
 *
 * @param ms Time in milliseconds to sleep for.
 * @function
 */
function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Downloads and extracts AMX Mod X
 * and its related dependencies.
 *
 * @function
 */
async function handlerAMXX() {
  const files = [] as Array<string>;
  const games = ["cstrike", "czero"];

  console.log(">> Downloading AMX Mod X...");
  files.push(await download(Endpoint.AMXX, DOWNLOAD_DIR));

  console.log(">> Downloading AMX Mod X dependencies...");
  files.push(await download(Endpoint.AMXX_CSTRIKE, DOWNLOAD_DIR));
  files.push(await download(Endpoint.METAMOD, DOWNLOAD_DIR));

  // now extract everything
  console.log(">> Extracting AMX Mod X files...");

  for (const file of files) {
    for (const game of games) {
      const destination = path.join(process.cwd(), "generated", game);
      console.log("Extracting %s to %s...", path.basename(file), path.basename(destination));
      try {
        await extract(file, destination);
      } catch (error) {
        console.error(error);
        continue;
      }
    }
  }

  // we're done here
  return Promise.resolve();
}

/**
 * Downloads and extracts SourceMod
 * and its related dependencies.
 *
 * @function
 */
async function handlerSourceMod() {
  const files = [] as Array<string>;
  const games = ["csgo", "cssource"];

  console.log(">> Downloading SourceMod...");
  files.push(await download(Endpoint.SOURCEMOD, DOWNLOAD_DIR));

  console.log(">> Downloading SourceMod dependencies...");
  files.push(await download(Endpoint.METAMOD_SOURCE, DOWNLOAD_DIR));

  // now extract everything
  console.log(">> Extracting SourceMod files...");

  for (const file of files) {
    for (const game of games) {
      const destination = path.join(process.cwd(), "generated", game);
      console.log("Extracting %s to %s...", path.basename(file), path.basename(destination));
      try {
        await extract(file, destination);
      } catch (error) {
        console.error(error);
        continue;
      }
    }
  }

  // we're done here
  return Promise.resolve();
}

/**
 * @param type The type of mod to download and install.
 * @function
 */
async function handler(type?: string) {
  if (!type || type === Mod.AMXX) {
    await handlerAMXX();
  }

  if (!type || type === Mod.SOURCEMOD) {
    await handlerSourceMod();
  }

  return Promise.resolve();
}

/**
 * @name anonymous
 * @function
 */
(async () => {
  const program = new Command();
  program
    .name(path.basename(import.meta.url))
    .description(AppInfo.description)
    .version(AppInfo.version)
    .argument("[type]", "The type of mod to download and install.")
    .action(handler);

  try {
    await program.parseAsync(process.argv);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
})();
