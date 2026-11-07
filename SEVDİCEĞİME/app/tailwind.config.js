/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        background: '#FFF9F7',
        primary: '#A63D57',
        secondary: '#D98EA0',
        accent: '#E8B86D',
        text: '#3A252B',
        card: '#FFFFFF',
        muted: '#8D777D',
      },
      fontFamily: {
        sans: ['Inter', 'Manrope', 'sans-serif'],
        serif: ['Playfair Display', 'serif'],
      },
      borderRadius: {
        'xl': '18px',
        '2xl': '24px',
      }
    },
  },
  plugins: [],
}
