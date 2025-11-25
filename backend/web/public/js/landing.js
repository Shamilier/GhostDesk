(function () {
  const landingData = (() => {
    try {
      const encoded = document.body ? document.body.getAttribute('data-landing') : null;
      return encoded ? JSON.parse(decodeURIComponent(encoded)) : {};
    } catch (error) {
      console.warn('Не удалось разобрать данные лендинга', error);
      return {};
    }
  })();

  const nav = document.querySelector('.landing-nav');
  const navToggle = nav ? nav.querySelector('.landing-nav-toggle') : null;
  const navContent = nav ? nav.querySelector('.landing-nav-content') : null;
  if (nav && navToggle && navContent) {
    const closeNav = () => {
      nav.classList.remove('is-open');
      navToggle.setAttribute('aria-expanded', 'false');
    };

    navToggle.addEventListener('click', () => {
      const isOpen = nav.classList.toggle('is-open');
      navToggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    });

    navContent.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', closeNav);
    });

    window.addEventListener('resize', () => {
      if (window.innerWidth >= 1024) {
        closeNav();
      }
    });
  }

  const useCaseButtons = Array.from(document.querySelectorAll('[data-usecase-index]'));
  const useCaseContainer = document.querySelector('[data-usecase-active]');
  if (useCaseButtons.length && useCaseContainer && Array.isArray(landingData.useCases)) {
    const titleEl = useCaseContainer.querySelector('h3');
    const summaryEl = useCaseContainer.querySelector('p');
    const listEl = useCaseContainer.querySelector('ul');
    const ctaEl = useCaseContainer.querySelector('a');

    const setActive = index => {
      const useCase = landingData.useCases[index];
      if (!useCase) return;

      useCaseButtons.forEach(button => {
        const isActive = Number(button.dataset.usecaseIndex) === index;
        button.classList.toggle('is-active', isActive);
        button.setAttribute('aria-selected', isActive ? 'true' : 'false');
      });

      titleEl.textContent = useCase.headline;
      summaryEl.textContent = useCase.summary;

      while (listEl.firstChild) {
        listEl.removeChild(listEl.firstChild);
      }
      (useCase.bullets || []).forEach(point => {
        const li = document.createElement('li');
        const marker = document.createElement('span');
        marker.setAttribute('aria-hidden', 'true');
        li.appendChild(marker);
        li.appendChild(document.createTextNode(point));
        listEl.appendChild(li);
      });

      ctaEl.textContent = useCase.cta;
    };

    useCaseButtons.forEach(button => {
      button.addEventListener('click', () => {
        const index = Number(button.dataset.usecaseIndex);
        setActive(index);
      });
    });

    setActive(0);
  }

  const billingButtons = Array.from(document.querySelectorAll('[data-billing]'));
  const planPriceContainers = Array.from(document.querySelectorAll('[data-plan-price] span'));
  if (billingButtons.length && planPriceContainers.length) {
    let currentMode = 'monthly';

    const updateMode = mode => {
      currentMode = mode;
      billingButtons.forEach(button => {
        const isActive = button.dataset.billing === mode;
        button.classList.toggle('is-active', isActive);
        button.setAttribute('aria-checked', isActive ? 'true' : 'false');
      });

      planPriceContainers.forEach(span => {
        const price = span.getAttribute(`data-${mode}-price`);
        const suffix = span.getAttribute(`data-${mode}-suffix`);
        span.textContent = '';
        if (price) {
          const amount = document.createElement('span');
          amount.className = 'landing-plan-amount';
          amount.textContent = price;
          span.appendChild(amount);
        }
        if (suffix) {
          const unit = document.createElement('span');
          unit.className = 'landing-plan-unit';
          unit.textContent = suffix;
          span.appendChild(unit);
        }
      });
    };

    billingButtons.forEach(button => {
      button.addEventListener('click', () => {
        const mode = button.dataset.billing;
        if (mode && mode !== currentMode) {
          updateMode(mode);
        }
      });
    });

    updateMode(currentMode);
  }

  const faqItems = Array.from(document.querySelectorAll('.landing-faq-list details'));
  if (faqItems.length) {
    faqItems.forEach(details => {
      details.addEventListener('toggle', () => {
        if (details.open) {
          faqItems.forEach(other => {
            if (other !== details) {
              other.removeAttribute('open');
            }
          });
        }
      });
    });
  }
})();
