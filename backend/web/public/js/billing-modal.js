const modal = document.querySelector('#billing-modal');
if (modal) {
  const openTrigger = document.querySelector('[data-open-billing]');
  const closeTriggers = modal.querySelectorAll('[data-close-billing]');
  const dialog = modal.querySelector('.billing-modal__dialog');
  const cycleButtons = modal.querySelectorAll('[data-cycle]');
  const priceTargets = modal.querySelectorAll('[data-plan-card]');

  if (!dialog) {
    console.warn('Billing modal dialog element not found.');
  } else {
    const initializeModal = () => {
      let lastFocusedElement = null;

    const focusableSelector = [
      'a[href]',
      'button:not([disabled])',
      'textarea:not([disabled])',
      'input[type="text"]:not([disabled])',
      'input[type="radio"]:not([disabled])',
      'input[type="checkbox"]:not([disabled])',
      'select:not([disabled])',
      '[tabindex]:not([tabindex="-1"])'
    ].join(', ');

    const getFocusableElements = () => {
      return Array.from(dialog.querySelectorAll(focusableSelector)).filter(
        (element) => element.offsetParent !== null
      );
    };

    const toggleVisibility = (shouldShow) => {
      if (shouldShow) {
        lastFocusedElement = document.activeElement instanceof HTMLElement ? document.activeElement : null;
        modal.classList.add('is-visible');
        modal.removeAttribute('hidden');
        document.body.classList.add('modal-open');
        requestAnimationFrame(() => {
          dialog.focus({ preventScroll: true });
        });
      } else {
        modal.classList.remove('is-visible');
        modal.setAttribute('hidden', '');
        document.body.classList.remove('modal-open');
        if (lastFocusedElement) {
          lastFocusedElement.focus({ preventScroll: true });
        }
      }
    };

    const updatePrices = (billingCycle) => {
      priceTargets.forEach((card) => {
        const monthlyPrice = card.getAttribute('data-monthly-price');
        const annualPrice = card.getAttribute('data-annual-price');
        const priceElement = card.querySelector('[data-plan-price]');
        if (!priceElement) return;

        priceElement.textContent = billingCycle === 'annual' ? annualPrice : monthlyPrice;
      });

      cycleButtons.forEach((button) => {
        const isActive = button.dataset.cycle === billingCycle;
        button.classList.toggle('is-active', isActive);
      });

      const annualNote = modal.querySelector('[data-annual-note]');
      if (annualNote) {
        annualNote.style.opacity = billingCycle === 'annual' ? '1' : '0.45';
      }
    };

    openTrigger?.addEventListener('click', () => toggleVisibility(true));

    closeTriggers.forEach((trigger) => {
      trigger.addEventListener('click', () => toggleVisibility(false));
    });

    modal.addEventListener('click', (event) => {
      if (!dialog.contains(event.target)) {
        toggleVisibility(false);
      }
    });

    cycleButtons.forEach((button) => {
      button.addEventListener('click', () => {
        const nextCycle = button.dataset.cycle === 'annual' ? 'annual' : 'monthly';
        updatePrices(nextCycle);
      });
    });

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && modal.classList.contains('is-visible')) {
        toggleVisibility(false);
      }
    });

    modal.addEventListener('keydown', (event) => {
      if (event.key !== 'Tab') {
        return;
      }

      const focusableElements = getFocusableElements();
      if (focusableElements.length === 0) {
        event.preventDefault();
        return;
      }

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];

      if (event.shiftKey) {
        if (document.activeElement === firstElement) {
          event.preventDefault();
          lastElement.focus();
        }
      } else if (document.activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    });

    updatePrices('monthly');
    };

    initializeModal();
  }
}
