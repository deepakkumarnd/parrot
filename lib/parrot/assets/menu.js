// Dropdown menu. It's a <details>, so it opens and closes without this; this
// also closes it on a click outside it, on picking one of its links, or on
// Escape. Shipped by the gem: the build puts it at the start of public/app.js.
//
// The listeners are on the document and look the menu up on each event, so
// they work even when app.js runs before the <body> is parsed (no `defer`),
// and keep working after something like Turbo swaps the <body>.
(() => {
  const openMenus = () => document.querySelectorAll('details.menu[open]');

  document.addEventListener('click', ({ target }) => {
    openMenus().forEach((menu) => {
      if (!menu.contains(target) || target.closest('.menu-items a')) menu.open = false;
    });
  });

  document.addEventListener('keydown', ({ key }) => {
    if (key !== 'Escape') return;

    openMenus().forEach((menu) => {
      menu.open = false;
      menu.querySelector('summary').focus();
    });
  });
})();
