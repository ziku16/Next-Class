/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        paper: '#fffdf0',
        cream: '#faf6ee',
        ink: '#000000',
        orange: '#ff5500',
        safety: '#ffe500',
      },
      fontFamily: { display: ['Space Grotesk', 'Arial', 'sans-serif'] },
      boxShadow: { brutal: '5px 5px 0 #000000', 'brutal-sm': '3px 3px 0 #000000' },
    },
  },
  plugins: [],
};
