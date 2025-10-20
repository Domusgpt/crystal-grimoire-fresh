const globals = require("globals");

module.exports = [
  {
    ignores: [
      "**/index-full.js",
      "**/test-gemini.js",
    ],
  },
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "commonjs",
      globals: {
        ...globals.node,
        ...globals.es2022,
      },
    },
    rules: {
      "no-restricted-globals": ["error", "name", "length"],
      "prefer-arrow-callback": "error",
      "quotes": "off",
      "max-len": ["error", {"code": 160}],
      "new-cap": ["error", {"newIsCap": false}],
      "require-jsdoc": "off",
      "valid-jsdoc": "off",
    },
  },
  {
    files: ["**/*.ts"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        ...globals.node,
        ...globals.es2022,
      },
    },
    rules: {
      "no-restricted-globals": ["error", "name", "length"],
      "prefer-arrow-callback": "error",
      "quotes": "off",
      "max-len": ["error", {"code": 160}],
      "new-cap": ["error", {"newIsCap": false}],
    },
  },
];