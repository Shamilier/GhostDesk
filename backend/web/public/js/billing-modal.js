const modal = document.querySelector('#billing-modal');

const getCsrfToken = () => {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.getAttribute('content') : null;
};

if (modal) {
  const openTrigger = document.querySelector('[data-open-billing]');
  const closeTriggers = modal.querySelectorAll('[data-close-billing]');
  const dialog = modal.querySelector('.billing-modal__dialog');
  const cycleButtons = Array.from(modal.querySelectorAll('[data-cycle]'));
  const priceTargets = Array.from(modal.querySelectorAll('[data-plan-card]'));
  const planButtons = Array.from(modal.querySelectorAll('[data-plan-action]'));
  const feedbackElement = modal.querySelector('[data-billing-feedback]');

  if (!dialog) {
    console.warn('Billing modal dialog element not found.');
  } else {
    let lastFocusedElement = null;
    let currentCycle = 'monthly';
    let isSubmitting = false;

    const focusableSelector = [
      'a[href]',
      'button:not([disabled])',
      'textarea:not([disabled])',
      'input[type="text"]:not([disabled])',
      'input[type="radio"]:not([disabled])',
      'input[type="checkbox"]:not([disabled])',
      'select:not([disabled])',
      '[tabindex]:not([tabindex="-1"])',
    ].join(', ');

    const getFocusableElements = () =>
      Array.from(dialog.querySelectorAll(focusableSelector)).filter((element) => element.offsetParent !== null);

    const setFeedback = (message, type = 'error') => {
      if (!feedbackElement) {
        return;
      }

      if (!message) {
        feedbackElement.textContent = '';
        feedbackElement.setAttribute('hidden', '');
        feedbackElement.classList.remove('is-error', 'is-success');
        return;
      }

      feedbackElement.textContent = message;
      feedbackElement.classList.toggle('is-error', type === 'error');
      feedbackElement.classList.toggle('is-success', type === 'success');
      feedbackElement.removeAttribute('hidden');
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
        setFeedback('');
      }
    };

    const updatePrices = (billingCycle) => {
      priceTargets.forEach((card) => {
        const monthlyPrice = card.getAttribute('data-monthly-price');
        const annualPrice = card.getAttribute('data-annual-price');
        const priceElement = card.querySelector('[data-plan-price]');
        if (!priceElement) {
          return;
        }

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

      currentCycle = billingCycle;
    };

    const handleCheckout = async (planId, trigger) => {
      if (!planId || isSubmitting) {
        return;
      }

      isSubmitting = true;
      setFeedback('');

      if (trigger) {
        trigger.setAttribute('data-loading', 'true');
        trigger.disabled = true;
      }

      try {
        const csrfToken = getCsrfToken();
        const response = await fetch('/api/billing/checkout', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(csrfToken ? { 'X-CSRF-Token': csrfToken } : {}),
          },
          body: JSON.stringify({ plan: planId, cycle: currentCycle }),
        });

        if (response.status === 401) {
          window.location.href = '/login';
          return;
        }

        const payload = await response.json().catch(() => ({}));

        if (!response.ok || !payload.confirmationUrl) {
          throw new Error(payload.error || 'payment_creation_failed');
        }

        window.location.href = payload.confirmationUrl;
      } catch (error) {
        console.error('Failed to initialize YooKassa payment', error);
        setFeedback('Не удалось инициировать оплату. Попробуйте еще раз или напишите на support@ghostai.ru.', 'error');
      } finally {
        isSubmitting = false;
        if (trigger) {
          trigger.removeAttribute('data-loading');
          trigger.disabled = false;
        }
      }
    };

    openTrigger?.addEventListener('click', () => {
      toggleVisibility(true);
      setFeedback('');
    });

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

    planButtons.forEach((button) => {
      button.addEventListener('click', () => {
        const planId = button.dataset.planAction;
        handleCheckout(planId, button);
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

    updatePrices(currentCycle);
  }
}
