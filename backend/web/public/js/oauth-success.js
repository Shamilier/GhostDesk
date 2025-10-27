(() => {
  const link = document.querySelector('[data-redirect-url]');
  if (!link) {
    return;
  }

  const redirectUrl = link.getAttribute('href');
  if (!redirectUrl) {
    return;
  }

  const fallbackContainer = document.querySelector('[data-manual-fallback]');
  if (fallbackContainer) {
    fallbackContainer.classList.add('is-hidden');
    window.setTimeout(() => {
      fallbackContainer.classList.remove('is-hidden');
    }, 4000);
  }

  let lastAttempt = 0;
  const minimumDelay = 500;

  const attemptOpen = () => {
    const now = Date.now();
    if (now - lastAttempt < minimumDelay) {
      return;
    }

    lastAttempt = now;
    try {
      window.location.assign(redirectUrl);
    } catch (err) {
      // Ignore errors; the fallback UI will guide the user.
    }
  };

  const scheduleInitialAttempts = () => {
    attemptOpen();
    window.setTimeout(attemptOpen, minimumDelay);
    window.setTimeout(attemptOpen, minimumDelay * 4);
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', scheduleInitialAttempts, { once: true });
  } else {
    scheduleInitialAttempts();
  }

  const retryOnInteraction = () => {
    attemptOpen();
  };

  ['click', 'keydown', 'touchstart'].forEach((eventName) => {
    document.addEventListener(eventName, retryOnInteraction);
  });

  window.addEventListener('focus', retryOnInteraction);
})();
