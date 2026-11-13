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
// This also updates the homepage nav and footer links while preserving their
// section IDs for the cards themselves.
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

// Department pages share the same navigation as the homepage, including About.
if (document.querySelector('.department-hero') && primaryNav && !primaryNav.querySelector('a[href="index.html#about"]')) {
  const aboutLink = document.createElement('a');
  aboutLink.href = 'index.html#about';
  aboutLink.textContent = 'About';
  const contactLink = primaryNav.querySelector('.nav-contact');
  primaryNav.insertBefore(aboutLink, contactLink || null);
}
