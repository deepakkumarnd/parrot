// Light/dark toggle. The saved choice is applied early by an inline script in
// layout.html.erb; this wires up the header button and remembers new choices.
(function () {
  var root = document.documentElement;
  var button = document.querySelector('.theme-toggle');
  if (!button) return;

  var systemDark = window.matchMedia('(prefers-color-scheme: dark)');
  var themeColors = { light: '#ffffff', dark: '#212121' };

  function currentTheme() {
    return root.dataset.theme || (systemDark.matches ? 'dark' : 'light');
  }

  function render() {
    var theme = currentTheme();
    button.setAttribute('aria-pressed', theme === 'dark');
    button.title = theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode';
    // Only override the browser chrome color once the visitor has picked a theme.
    if (root.dataset.theme) {
      document.querySelectorAll('meta[name="theme-color"]').forEach(function (meta) {
        meta.content = themeColors[theme];
      });
    }
  }

  button.addEventListener('click', function () {
    var theme = currentTheme() === 'dark' ? 'light' : 'dark';
    root.dataset.theme = theme;
    try { localStorage.setItem('theme', theme); } catch (e) {}
    render();
  });

  systemDark.addEventListener('change', render);
  button.hidden = false;
  render();
})();
