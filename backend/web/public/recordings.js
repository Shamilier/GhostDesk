(function () {
  // Tabs
  const tabs = document.querySelectorAll('.tab');
  const panels = {
    transcript: document.getElementById('tab-transcript'),
    qa: document.getElementById('tab-qa'),
    notes: document.getElementById('tab-notes'),
  };

  tabs.forEach((btn) => {
    btn.addEventListener('click', () => {
      const tab = btn.dataset.tab;
      tabs.forEach((b) => {
        const isActive = b === btn;
        b.classList.toggle('is-active', isActive);
        b.setAttribute('aria-selected', isActive ? 'true' : 'false');
      });

      Object.entries(panels).forEach(([key, element]) => {
        if (!element) {
          return;
        }
        element.classList.toggle('is-active', key === tab);
      });
    });
  });

  // Delete confirmation
  document.querySelectorAll('[data-confirm]').forEach((button) => {
    button.addEventListener('click', (event) => {
      const message = button.getAttribute('data-confirm') || 'Вы уверены?';
      if (!window.confirm(message)) {
        event.preventDefault();
      }
    });
  });

  // Copy recording ID
  const copyBtn = document.querySelector('[data-copy-id]');
  if (copyBtn) {
    copyBtn.addEventListener('click', async () => {
      const id = copyBtn.getAttribute('data-copy-id');
      if (!id) {
        return;
      }
      try {
        await navigator.clipboard.writeText(id);
        copyBtn.classList.add('ok');
        setTimeout(() => copyBtn.classList.remove('ok'), 1200);
      } catch (error) {
        console.error('Failed to copy recording ID', error);
        window.alert('Не удалось скопировать ID');
      }
    });
  }
})();

