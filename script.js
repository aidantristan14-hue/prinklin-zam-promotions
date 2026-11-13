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

// Turn the existing homepage department anchors into links to the new pages,
// while keeping the original homepage sections and all existing interactions.
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
