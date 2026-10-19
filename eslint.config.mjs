import tsParser from "@typescript-eslint/parser";
import tsPlugin from "typescript-eslint";

export default tsPlugin.config(
  { ignores: [".next/", "node_modules/", "coverage/"] },
  ...tsPlugin.configs.recommended,
  {
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
    },
  },
);
