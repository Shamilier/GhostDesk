document.addEventListener('DOMContentLoaded', () => {
  const toggle = document.querySelector('[data-token-info-toggle]');
  const panel = document.querySelector('[data-token-info-panel]');
  if (!toggle || !panel) {
    return;
  }

  const closePanel = () => {
    if (panel.hasAttribute('hidden')) {
      return;
    }
    panel.setAttribute('hidden', '');
    toggle.setAttribute('aria-expanded', 'false');
    document.removeEventListener('click', handleOutsideClick);
    document.removeEventListener('keydown', handleEscapeKey);
  };

  const handleOutsideClick = (event) => {
    if (panel.contains(event.target) || toggle.contains(event.target)) {
      return;
    }
    closePanel();
  };

  const handleEscapeKey = (event) => {
    if (event.key === 'Escape') {
      closePanel();
    }
  };

  toggle.addEventListener('click', (event) => {
    event.preventDefault();
    const willOpen = panel.hasAttribute('hidden');

    if (willOpen) {
      panel.removeAttribute('hidden');
      toggle.setAttribute('aria-expanded', 'true');
      setTimeout(() => {
        document.addEventListener('click', handleOutsideClick);
      }, 0);
      document.addEventListener('keydown', handleEscapeKey);
    } else {
      closePanel();
    }
  });
});
