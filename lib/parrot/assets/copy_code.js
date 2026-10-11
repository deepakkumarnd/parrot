// Copy buttons for code blocks, shipped by Parrot into every build and
// loaded by the layout on every page. It does nothing on a page without a
// code block; otherwise each <pre><code> block gets a button in its top-right
// corner that copies the code and shows a short "Copied" toast. Restyle it
// through the .code-block, .copy-code and .copy-toast classes.
(() => {
  const LABEL = 'Copy code';
  const TOAST_MS = 1500;

  let toast;
  let toastTimer;

  const showToast = (message) => {
    if (!toast) {
      toast = document.createElement('div');
      toast.className = 'copy-toast';
      toast.setAttribute('role', 'status');
      toast.setAttribute('aria-live', 'polite');
      document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.classList.add('is-visible');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('is-visible'), TOAST_MS);
  };

  // The Clipboard API only exists on https:// and localhost pages; anywhere
  // else, fall back to copying from an off-screen textarea.
  const copyText = async (text) => {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return;
    }

    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.setAttribute('readonly', '');
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    const copied = document.execCommand('copy');
    textarea.remove();
    if (!copied) throw new Error('copy failed');
  };

  // Wraps a code block (rouge's .highlighter-rouge div, or a bare <pre> for
  // blocks without a language) so the button can sit over its corner
  // without scrolling away with long lines.
  const addButton = (code) => {
    const pre = code.parentElement;
    const block = pre.closest('.highlighter-rouge') || pre;
    if (block.parentElement.classList.contains('code-block')) return;

    const wrapper = document.createElement('div');
    wrapper.className = 'code-block';
    block.replaceWith(wrapper);
    wrapper.appendChild(block);

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'copy-code';
    // The icon itself is images/copy-icon.svg, drawn by app.css as a mask
    // so it takes the button's text colour.
    button.innerHTML = `<span class="copy-code-icon" aria-hidden="true"></span><span>${LABEL}</span>`;
    button.addEventListener('click', async () => {
      try {
        // Kramdown ends every block with a newline; leave it out of the copy.
        await copyText(code.textContent.replace(/\n$/, ''));
        showToast('Copied');
      } catch {
        showToast('Could not copy');
      }
    });
    wrapper.appendChild(button);
  };

  const init = () => {
    const blocks = document.querySelectorAll('pre > code');
    if (!blocks.length) return;

    blocks.forEach(addButton);
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
