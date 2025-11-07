/**
 * ESLint configuration file.
 *
 * @module
 */
import globals from "globals";
import prettier from "eslint-config-prettier";
import js from "@eslint/js";
import ts from "typescript-eslint";

/** @type {import('eslint').Linter.Config[]} */
export default [
  { files: ["**/*.{js,mjs,cjs,ts}"] },
  { languageOptions: { globals: globals.browser } },
  {
    rules: {
      "@typescript-eslint/no-unused-vars": ["warn", { caughtErrors: "none" }],
    },
  },
  js.configs.recommended,
  ...ts.configs.recommended,
  prettier,
];
