#!/usr/bin/env node --no-warnings
/**
 * AMX Mod X and SourceMod compiler.
 *
 * @module
 */
import fs from "node:fs";
import path from "node:path";
import AppInfo from "../package.json" assert { type: "json" };
import { spawn } from "node:child_process";
import { Command } from "commander";

/** @enum */
enum Mod {
  AMXX = "amxx",
  SOURCEMOD = "sourcemod",
}

/**
 * AMX Mod X compiler.
 *
 * @function
 */
async function amxx() {
  const amxxPath = "generated/cstrike/addons/amxmodx";
  const amxxCompilerPath = path.join(amxxPath, "scripting/amxxpc.exe");
  const amxxIncludePath = path.join(amxxPath, "scripting/include");

  const input = path.join(process.cwd(), "config/cstrike/addons/amxmodx/scripting/liga.sma");
  const output = [
    path.join(process.cwd(), "config/cstrike/addons/amxmodx/plugins/liga.amxx"),
    path.join(process.cwd(), "config/czero/addons/amxmodx/plugins/liga.amxx"),
  ];

  // make sure the compiler is found
  try {
    await fs.promises.access(amxxCompilerPath, fs.constants.F_OK);
  } catch (error) {
    return Promise.reject(error);
  }

  // compile the plugins serially
  for (const out of output) {
    console.info("Compiling %s...", input);
    await new Promise((resolve, reject) =>
      spawn(amxxCompilerPath, ["-i" + amxxIncludePath, "-o" + out, input], {
        stdio: "inherit",
      })
        .on("error", reject)
        .on("close", resolve)
        .on("exit", resolve),
    );
  }

  return Promise.resolve();
}

/**
 * SourceMod compiler.
 *
 * @function
 */
async function sourcemod() {
  const smPath = "generated/csgo/addons/sourcemod";
  const smCompilerPath = path.join(smPath, "scripting/spcomp.exe");
  const smIncludePath = path.join(smPath, "scripting/include");

  const input = path.join(process.cwd(), "config/csgo/addons/sourcemod/scripting/liga.sp");
  const output = [
    path.join(process.cwd(), "config/csgo/addons/sourcemod/plugins/liga.smx"),
    path.join(process.cwd(), "config/cssource/addons/sourcemod/plugins/liga.smx"),
  ];

  // make sure the compiler is found
  try {
    await fs.promises.access(smCompilerPath, fs.constants.F_OK);
  } catch (error) {
    return Promise.reject(error);
  }

  // compile the plugins serially
  for (const out of output) {
    console.info("Compiling %s...", input);
    await new Promise((resolve, reject) =>
      spawn(smCompilerPath, ["-i" + smIncludePath, "-o" + out, input], {
        stdio: "inherit",
      })
        .on("error", reject)
        .on("close", resolve)
        .on("exit", resolve),
    );
  }

  return Promise.resolve();
}

/**
 * Validates the provided compiler type and runs it.
 *
 * @param type The type of compiler to run.
 * @function
 */
async function handler(type?: string) {
  if (!type || type === Mod.AMXX) {
    await amxx();
  }

  if (!type || type === Mod.SOURCEMOD) {
    await sourcemod();
  }

  return Promise.resolve();
}

/**
 * Bootstrapping logic.
 *
 * @name anonymous
 * @function
 */
(async () => {
  const program = new Command();
  program
    .name(path.basename(import.meta.url))
    .description(AppInfo.description)
    .version(AppInfo.version)
    .argument("[type]", "The type of compiler to use.")
    .action(handler);

  try {
    await program.parseAsync(process.argv);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
})();
