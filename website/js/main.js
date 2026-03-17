document.addEventListener('DOMContentLoaded', () => {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const header = document.querySelector('.site-header');

    document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
        anchor.addEventListener('click', (event) => {
            const targetId = anchor.getAttribute('href');
            if (!targetId || targetId === '#') {
                return;
            }

            const target = document.querySelector(targetId);
            if (!target) {
                return;
            }

            event.preventDefault();
            const headerOffset = header ? header.offsetHeight + 12 : 0;
            const top = target.getBoundingClientRect().top + window.scrollY - headerOffset;

            window.scrollTo({
                top,
                behavior: prefersReducedMotion ? 'auto' : 'smooth'
            });
        });
    });

    const syncHeader = () => {
        if (!header) {
            return;
        }

        header.classList.toggle('is-scrolled', window.scrollY > 18);
    };

    syncHeader();
    window.addEventListener('scroll', syncHeader, { passive: true });

    const tabButtons = Array.from(document.querySelectorAll('[data-tab-trigger]'));
    const tabPanels = Array.from(document.querySelectorAll('[data-tab-panel]'));

    if (tabButtons.length && tabPanels.length) {
        const showPanel = (tabId) => {
            tabButtons.forEach((button) => {
                const isActive = button.dataset.tabTrigger === tabId;
                button.setAttribute('aria-selected', String(isActive));
                button.classList.toggle('is-active', isActive);
            });

            tabPanels.forEach((panel) => {
                const isActive = panel.dataset.tabPanel === tabId;
                panel.classList.toggle('is-active', isActive);
                panel.hidden = !isActive;
            });
        };

        tabButtons.forEach((button) => {
            button.addEventListener('click', () => {
                showPanel(button.dataset.tabTrigger);
            });
        });

        const defaultTab = tabButtons.find((button) => button.getAttribute('aria-selected') === 'true') || tabButtons[0];
        showPanel(defaultTab.dataset.tabTrigger);
    }

    if (prefersReducedMotion) {
        document.querySelectorAll('[data-reveal]').forEach((element) => {
            element.classList.add('is-visible');
        });
        return;
    }

    const revealElements = document.querySelectorAll('[data-reveal]');
    const revealObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                entry.target.classList.add('is-visible');
                revealObserver.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.14,
        rootMargin: '0px 0px -8% 0px'
    });

    revealElements.forEach((element, index) => {
        element.style.setProperty('--reveal-delay', `${(index % 6) * 70}ms`);
        revealObserver.observe(element);
    });
});
