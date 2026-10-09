// Light/dark toggle. The saved choice is applied early by an inline script in
// layout.html.erb; this wires up the header button and remembers new choices.
(() => {
  const root = document.documentElement;
  const button = document.querySelector('.theme-toggle');
  if (!button) return;

  const systemDark = window.matchMedia('(prefers-color-scheme: dark)');
  const themeColors = { light: '#ffffff', dark: '#212121' };

  const currentTheme = () => root.dataset.theme || (systemDark.matches ? 'dark' : 'light');

  const render = () => {
    const theme = currentTheme();
    button.setAttribute('aria-pressed', theme === 'dark');
    button.title = theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode';
    // Only override the browser chrome color once the visitor has picked a theme.
    if (root.dataset.theme) {
      document.querySelectorAll('meta[name="theme-color"]').forEach((meta) => {
        meta.content = themeColors[theme];
      });
    }
  };

  button.addEventListener('click', () => {
    const theme = currentTheme() === 'dark' ? 'light' : 'dark';
    root.dataset.theme = theme;
    try { localStorage.setItem('theme', theme); } catch {}
    render();
  });

  systemDark.addEventListener('change', render);
  button.hidden = false;
  render();
})();
