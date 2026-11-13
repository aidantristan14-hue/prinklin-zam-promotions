const requestForm = document.querySelector('#service-request');
const categorySelect = document.querySelector('#category');
const specificServiceSelect = document.querySelector('#specific-service');
const formStatus = document.querySelector('#form-status');

const serviceOptions = {
  'Technology Services': ['Website development', 'Software development', 'Website maintenance', 'Business automation', 'Technology enquiry'],
  'Digital Services': ['SMS and OTP activation', 'Virtual phone numbers', 'Gift cards', 'Digital subscriptions', 'Other supported digital service'],
  'Payment Assistance': ['Platform guidance', 'Registration information', 'Account troubleshooting', 'Technical assistance'],
  'Gadget Services': ['Gadget enquiry', 'Buying or selling', 'Gadget swap', 'Repair request'],
  'Real Estate Services': ['Property enquiry', 'Land opportunity', 'House enquiry', 'Inspection request'],
  Publications: ['E-books', 'Educational resources', 'Articles', 'Digital publications']
};

if (categorySelect && specificServiceSelect) {
  categorySelect.addEventListener('change', () => {
    const choices = serviceOptions[categorySelect.value] || [];
    specificServiceSelect.replaceChildren();

    const placeholder = document.createElement('option');
    placeholder.value = '';
    placeholder.textContent = choices.length ? 'Choose a service' : 'Choose a category first';
    specificServiceSelect.append(placeholder);

    choices.forEach((service) => {
      const option = document.createElement('option');
      option.value = service;
      option.textContent = service;
      specificServiceSelect.append(option);
    });

    specificServiceSelect.disabled = choices.length === 0;
  });
}

// Category cards can preselect their corresponding enquiry type.
document.querySelectorAll('[data-service]').forEach((link) => {
  link.addEventListener('click', () => {
    if (!categorySelect) return;
    categorySelect.value = link.dataset.service;
    categorySelect.dispatchEvent(new Event('change'));
    document.querySelector('#request-form')?.scrollIntoView({ behavior: 'smooth' });
  });
});

if (requestForm) {
  requestForm.addEventListener('submit', (event) => {
    event.preventDefault();
    if (!requestForm.reportValidity()) return;
    if (formStatus) {
      formStatus.textContent = 'This is a frontend preview only. Your request was not sent or saved. Official submission channels will be added when available.';
    }
  });
}
