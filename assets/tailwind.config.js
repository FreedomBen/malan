const colors = require("tailwindcss/colors");

// For custom colors
// https://tailwindcss.com/docs/customizing-colors#extending-the-defaults

module.exports = {
  mode: "jit",
  purge: ["./js/**/*.js", "../lib/*_web/**/*.*ex"],
  darkMode: "media", // or 'media' or 'class'
  theme: {
    extend: {
      colors: {
        sky: colors.sky,
        gray: colors.gray,
        bronze: colors.bronze,
        silver: colors.silver,
        gold: colors.gold,
        platinum: colors.platinum,
        'ehrman-blue': '#04395E',
        'ehrman-dark-blue': '#031D44',
        'ehrman-orange': '#B1740F',
        'ehrman-gray': '#EEEEEE'
      },
    },
  },
  variants: {
    extend: {},
  },
  plugins: [require("@tailwindcss/forms")],
};
