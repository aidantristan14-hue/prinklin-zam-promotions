const menuToggle = document.querySelector('.menu-toggle');
const primaryNav = document.querySelector('#primary-nav');

if (menuToggle && primaryNav) {
  const closeMenu = ({ returnFocus = false } = {}) => {
    menuToggle.setAttribute('aria-expanded', 'false');
    menuToggle.setAttribute('aria-label', 'Open navigation menu');
    primaryNav.classList.remove('is-open');
    if (returnFocus) menuToggle.focus();
  };

  menuToggle.addEventListener('click', () => {
    const isExpanded = menuToggle.getAttribute('aria-expanded') === 'true';
    if (isExpanded) {
      closeMenu();
      return;
    }
    menuToggle.setAttribute('aria-expanded', 'true');
    menuToggle.setAttribute('aria-label', 'Close navigation menu');
    primaryNav.classList.add('is-open');
  });

  primaryNav.querySelectorAll('a').forEach((link) => {
    link.addEventListener('click', () => closeMenu());
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && primaryNav.classList.contains('is-open')) {
      closeMenu({ returnFocus: true });
    }
  });

  window.addEventListener('resize', () => {
    if (window.matchMedia('(min-width: 1051px)').matches) closeMenu();
  });
}

const year = document.querySelector('#current-year');
if (year) year.textContent = String(new Date().getFullYear());

// Keep homepage department navigation connected to the standalone pages.
const departmentPages = {
  technology: 'technology.html',
  'digital-services': 'digital-services.html',
  'crypto-finance': 'crypto-finance.html',
  'real-estate': 'real-estate.html',
  gadgets: 'gadgets.html',
  publications: 'publications.html'
};

Object.entries(departmentPages).forEach(([sectionId, page]) => {
  document.querySelectorAll(`a[href="#${sectionId}"]`).forEach((link) => {
    link.setAttribute('href', page);
  });
  const cardLink = document.querySelector(`#${sectionId} .card-link`);
  if (cardLink) cardLink.setAttribute('href', page);
});

// Add shared cross-site links without replacing the existing page navigation.
if (primaryNav) {
  if (!primaryNav.querySelector('a[href="service-centre.html"]')) {
    const serviceLink = document.createElement('a');
    serviceLink.href = 'service-centre.html';
    serviceLink.textContent = 'Service Centre';
    const contactLink = primaryNav.querySelector('.nav-contact');
    primaryNav.insertBefore(serviceLink, contactLink || null);
  }

  if (document.querySelector('.department-hero') && !primaryNav.querySelector('a[href="index.html#about"]')) {
    const aboutLink = document.createElement('a');
    aboutLink.href = 'index.html#about';
    aboutLink.textContent = 'About';
    const contactLink = primaryNav.querySelector('.nav-contact');
    primaryNav.insertBefore(aboutLink, contactLink || null);
  }
}

// A homepage callout makes the new service hub discoverable while preserving
// the existing department cards and their visual layout.
const departmentGrid = document.querySelector('.department-grid');
if (departmentGrid && !document.querySelector('.service-centre-promo')) {
  const promo = document.createElement('aside');
  promo.className = 'service-centre-promo';
  promo.innerHTML = '<div><p class="eyebrow">Need help choosing?</p><h3>Visit the Prinklin Zam Service Centre</h3><p>Explore service categories, learn how requests work and prepare an enquiry.</p></div><a class="button button-primary" href="service-centre.html">Open Service Centre <span aria-hidden="true">↗</span></a>';
  departmentGrid.insertAdjacentElement('afterend', promo);
}
