(function () {
  const header = document.querySelector('[data-header]');
  const navToggle = header?.querySelector('[data-nav-toggle]');
  const navMenu = header?.querySelector('[data-nav-menu]');
  const navLinks = header ? header.querySelectorAll('[data-nav-link]') : [];

  function closeNavMenu() {
    if (!header || !navToggle || !navMenu) {
      return;
    }
    header.classList.remove('is-open');
    navToggle.setAttribute('aria-expanded', 'false');
  }

  if (navToggle && navMenu) {
    navToggle.addEventListener('click', () => {
      const isExpanded = navToggle.getAttribute('aria-expanded') === 'true';
      navToggle.setAttribute('aria-expanded', String(!isExpanded));
      header?.classList.toggle('is-open', !isExpanded);
    });

    document.addEventListener('click', event => {
      if (!header?.classList.contains('is-open')) {
        return;
      }
      if (!navMenu.contains(event.target) && !navToggle.contains(event.target)) {
        closeNavMenu();
      }
    });

    document.addEventListener('keydown', event => {
      if (event.key === 'Escape') {
        closeNavMenu();
      }
    });
  }

  navLinks.forEach(link => {
    link.addEventListener('click', () => {
      closeNavMenu();
    });
  });

  function updateHeaderOnScroll() {
    if (!header) {
      return;
    }
    header.classList.toggle('is-scrolled', window.scrollY > 16);
  }

  updateHeaderOnScroll();
  window.addEventListener('scroll', updateHeaderOnScroll, { passive: true });

  // Use cases switching
  const caseButtons = Array.from(document.querySelectorAll('[data-case-trigger]'));
  const casePanels = Array.from(document.querySelectorAll('[data-case-panel]'));

  function activateCase(targetId) {
    caseButtons.forEach(button => {
      const isActive = button.getAttribute('data-target') === targetId;
      button.classList.toggle('is-active', isActive);
      button.setAttribute('aria-selected', isActive ? 'true' : 'false');
    });
    casePanels.forEach(panel => {
      const panelId = panel.getAttribute('id');
      const isActive = panelId === targetId;
      panel.classList.toggle('is-active', isActive);
      if (isActive) {
        panel.removeAttribute('hidden');
      } else {
        panel.setAttribute('hidden', '');
      }
    });
  }

  caseButtons.forEach(button => {
    button.addEventListener('click', () => {
      const targetId = button.getAttribute('data-target');
      if (targetId) {
        activateCase(targetId);
      }
    });
  });

  // Testimonials carousel
  const testimonialButtons = Array.from(document.querySelectorAll('[data-testimonial-trigger]'));
  const testimonialPanels = Array.from(document.querySelectorAll('[data-testimonial-panel]'));
  const testimonialMetrics = Array.from(document.querySelectorAll('[data-testimonial-metric]'));

  let testimonialIndex = 0;
  let testimonialTimer;

  function activateTestimonial(targetId) {
    testimonialButtons.forEach((button, index) => {
      const isActive = button.getAttribute('data-target') === targetId;
      button.classList.toggle('is-active', isActive);
      if (isActive) {
        testimonialIndex = index;
      }
    });

    testimonialPanels.forEach(panel => {
      const isActive = panel.getAttribute('data-testimonial-panel') === targetId;
      panel.classList.toggle('is-active', isActive);
      if (isActive) {
        panel.removeAttribute('hidden');
      } else {
        panel.setAttribute('hidden', '');
      }
    });

    testimonialMetrics.forEach(metric => {
      const isActive = metric.getAttribute('data-target') === targetId;
      metric.classList.toggle('is-active', isActive);
      if (isActive) {
        metric.removeAttribute('hidden');
      } else {
        metric.setAttribute('hidden', '');
      }
    });
  }

  function getTestimonialId(index) {
    const button = testimonialButtons[index];
    return button?.getAttribute('data-target') || null;
  }

  function scheduleTestimonialRotation() {
    if (testimonialTimer) {
      window.clearInterval(testimonialTimer);
    }
    if (!testimonialButtons.length) {
      return;
    }
    testimonialTimer = window.setInterval(() => {
      testimonialIndex = (testimonialIndex + 1) % testimonialButtons.length;
      const id = getTestimonialId(testimonialIndex);
      if (id) {
        activateTestimonial(id);
      }
    }, 7000);
  }

  testimonialButtons.forEach((button, index) => {
    button.addEventListener('mouseenter', () => {
      const id = button.getAttribute('data-target');
      if (id) {
        activateTestimonial(id);
        scheduleTestimonialRotation();
      }
    });
    button.addEventListener('focus', () => {
      const id = button.getAttribute('data-target');
      if (id) {
        activateTestimonial(id);
        scheduleTestimonialRotation();
      }
    });
    button.addEventListener('click', () => {
      const id = button.getAttribute('data-target');
      if (id) {
        activateTestimonial(id);
        scheduleTestimonialRotation();
      }
    });
    if (index === 0) {
      const id = button.getAttribute('data-target');
      if (id) {
        activateTestimonial(id);
      }
    }
  });

  if (testimonialButtons.length > 1) {
    scheduleTestimonialRotation();
  }

  // Pricing toggle
  const billingButtons = Array.from(document.querySelectorAll('[data-billing-option]'));
  const planPrices = Array.from(document.querySelectorAll('[data-plan-price]'));
  const planSuffixes = Array.from(document.querySelectorAll('[data-plan-suffix]'));
  const billingNote = document.querySelector('[data-billing-note]');

  function setBilling(mode) {
    const normalized = mode === 'yearly' ? 'yearly' : 'monthly';
    billingButtons.forEach(button => {
      const isActive = button.getAttribute('data-billing-option') === normalized;
      button.classList.toggle('is-active', isActive);
      button.setAttribute('aria-selected', isActive ? 'true' : 'false');
    });

    planPrices.forEach(element => {
      const value = element.getAttribute(`data-${normalized}`);
      if (value) {
        element.textContent = value;
      }
    });

    planSuffixes.forEach(element => {
      const value = element.getAttribute(`data-${normalized}`);
      if (value) {
        element.textContent = value;
      }
    });

    if (billingNote) {
      const noteValue = billingNote.getAttribute(`data-${normalized}`);
      if (noteValue) {
        billingNote.textContent = noteValue;
      }
    }
  }

  billingButtons.forEach(button => {
    button.addEventListener('click', () => {
      const mode = button.getAttribute('data-billing-option');
      setBilling(mode === 'yearly' ? 'yearly' : 'monthly');
    });
  });

  if (billingButtons.length) {
    const activeButton = billingButtons.find(button => button.classList.contains('is-active'));
    const mode = activeButton?.getAttribute('data-billing-option') || 'monthly';
    setBilling(mode);
  }
})();
