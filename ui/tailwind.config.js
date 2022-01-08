module.exports = {
  purge: ['src/**/*.vue', 'repl-looper.html'],
  darkMode: 'class', // or 'media' or 'class'
  theme: {
    extend: {
      fontFamily: {
        'mono': ['"VT323"', 'monospace']
      }
    },
  },
  // variants: {
    // extend: {},
  // },
  // plugins: [require("nightwind")],
}
