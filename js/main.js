/* ============================================
   PairedM Website — JavaScript
   ============================================ */

// Web3Forms access key (free, no signup needed — create one at web3forms.com)
// Replace this placeholder with your real access key to receive form submissions.
const WEB3FORMS_ACCESS_KEY = 'YOUR_WEB3FORMS_ACCESS_KEY_HERE';

document.addEventListener('DOMContentLoaded', () => {

  // ---------- Mobile Nav Toggle ----------
  const hamburger = document.querySelector('.hamburger');
  const mobileNav = document.querySelector('.mobile-nav');

  if (hamburger && mobileNav) {
    hamburger.addEventListener('click', () => {
      hamburger.classList.toggle('active');
      mobileNav.classList.toggle('active');
      document.body.style.overflow = mobileNav.classList.contains('active') ? 'hidden' : '';
    });

    mobileNav.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        hamburger.classList.remove('active');
        mobileNav.classList.remove('active');
        document.body.style.overflow = '';
      });
    });
  }

  // ---------- Hero Slider ----------
  const slides = document.querySelectorAll('.hero-slide');
  if (slides.length > 1) {
    let current = 0;
    setInterval(() => {
      slides[current].classList.remove('active');
      current = (current + 1) % slides.length;
      slides[current].classList.add('active');
    }, 4000);
  }

  // ---------- Banner Auto-scroll ----------
  const bannerCarousel = document.querySelector('.banner-carousel');
  if (bannerCarousel) {
    let scrollDirection = 1;
    let bannerInterval;

    const startBannerScroll = () => {
      bannerInterval = setInterval(() => {
        const maxScroll = bannerCarousel.scrollWidth - bannerCarousel.clientWidth;
        if (bannerCarousel.scrollLeft >= maxScroll - 5) {
          scrollDirection = -1;
        } else if (bannerCarousel.scrollLeft <= 5) {
          scrollDirection = 1;
        }
        bannerCarousel.scrollBy({ left: scrollDirection * 340, behavior: 'smooth' });
      }, 3000);
    };

    startBannerScroll();

    bannerCarousel.addEventListener('mouseenter', () => clearInterval(bannerInterval));
    bannerCarousel.addEventListener('mouseleave', startBannerScroll);
  }

  // ---------- Scroll Animations ----------
  const fadeElements = document.querySelectorAll('.fade-in');

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.1,
    rootMargin: '0px 0px -40px 0px',
  });

  fadeElements.forEach(el => observer.observe(el));

  // ---------- Scroll Progress Bar ----------
  const progressBar = document.querySelector('.scroll-progress');
  if (progressBar) {
    const updateProgress = () => {
      const scrolled = window.scrollY;
      const height = document.documentElement.scrollHeight - window.innerHeight;
      const pct = height > 0 ? (scrolled / height) * 100 : 0;
      progressBar.style.width = pct + '%';
    };
    updateProgress();
    window.addEventListener('scroll', updateProgress, { passive: true });
  }

  // ---------- Animated Number Counters ----------
  const counters = document.querySelectorAll('[data-counter]');
  if (counters.length) {
    const counterObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        const el = entry.target;
        const target = parseFloat(el.dataset.counter);
        const suffix = el.dataset.suffix || '';
        const prefix = el.dataset.prefix || '';
        const duration = 1600;
        const start = performance.now();
        const step = (now) => {
          const p = Math.min((now - start) / duration, 1);
          const eased = 1 - Math.pow(1 - p, 3);
          const value = target * eased;
          const display = Number.isInteger(target) ? Math.round(value) : value.toFixed(1);
          el.textContent = prefix + display + suffix;
          if (p < 1) requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
        counterObserver.unobserve(el);
      });
    }, { threshold: 0.3 });
    counters.forEach(el => counterObserver.observe(el));
  }

  // ---------- 3D Card Tilt ----------
  const tiltCards = document.querySelectorAll('[data-tilt]');
  tiltCards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width - 0.5;
      const y = (e.clientY - rect.top) / rect.height - 0.5;
      card.style.transform = `perspective(1000px) rotateX(${-y * 6}deg) rotateY(${x * 6}deg) translateY(-4px)`;
    });
    card.addEventListener('mouseleave', () => {
      card.style.transform = '';
    });
  });

  // ---------- Header Scroll Effect ----------
  const header = document.querySelector('.header');
  if (header) {
    window.addEventListener('scroll', () => {
      if (window.scrollY > 50) {
        header.classList.add('scrolled');
      } else {
        header.classList.remove('scrolled');
      }
    }, { passive: true });
  }

  // ---------- Form validation ----------
  const attachValidation = (form) => {
    if (!form) return;
    const fields = form.querySelectorAll('input[required], textarea[required], input[type="email"]');
    fields.forEach(field => {
      field.addEventListener('blur', () => validateField(field));
      field.addEventListener('input', () => {
        if (field.classList.contains('invalid')) validateField(field);
      });
    });
  };

  const validateField = (field) => {
    const group = field.closest('.form-group');
    if (!group) return field.checkValidity();
    let error = group.querySelector('.form-error');
    if (!error) {
      error = document.createElement('span');
      error.className = 'form-error';
      group.appendChild(error);
    }
    if (!field.value.trim() && field.hasAttribute('required')) {
      field.classList.add('invalid');
      field.classList.remove('valid');
      error.textContent = 'This field is required';
      return false;
    }
    if (field.type === 'email' && field.value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(field.value)) {
      field.classList.add('invalid');
      field.classList.remove('valid');
      error.textContent = 'Please enter a valid email';
      return false;
    }
    field.classList.remove('invalid');
    field.classList.add('valid');
    error.textContent = '';
    return true;
  };

  // ---------- Contact Form (real submit via Web3Forms) ----------
  const contactForm = document.querySelector('#contact-form');
  attachValidation(contactForm);

  if (contactForm) {
    contactForm.addEventListener('submit', async (e) => {
      e.preventDefault();

      // Validate all fields before submit
      const fields = contactForm.querySelectorAll('input[required], textarea[required], input[type="email"]');
      let allValid = true;
      fields.forEach(f => { if (!validateField(f)) allValid = false; });
      if (!allValid) return;

      const btn = contactForm.querySelector('button[type="submit"]');
      const originalText = btn.textContent;
      btn.disabled = true;
      btn.textContent = 'Sending...';

      const formData = new FormData(contactForm);
      formData.append('access_key', WEB3FORMS_ACCESS_KEY);
      formData.append('from_name', 'PairedM Website');
      formData.append('subject', formData.get('subject') || 'New enquiry from PairedM site');

      try {
        if (WEB3FORMS_ACCESS_KEY === 'YOUR_WEB3FORMS_ACCESS_KEY_HERE') {
          throw new Error('Form not yet configured — please contact us at info@pairedm.co.uk directly.');
        }

        const res = await fetch('https://api.web3forms.com/submit', {
          method: 'POST',
          body: formData,
        });
        const data = await res.json();

        if (data.success) {
          btn.textContent = '✓ Message Sent';
          btn.style.background = 'var(--success)';
          contactForm.reset();
          contactForm.querySelectorAll('.valid, .invalid').forEach(el => el.classList.remove('valid', 'invalid'));
          setTimeout(() => {
            btn.textContent = originalText;
            btn.style.background = '';
            btn.disabled = false;
          }, 4000);
        } else {
          throw new Error(data.message || 'Submission failed');
        }
      } catch (err) {
        btn.textContent = '✕ ' + (err.message.length > 40 ? 'Failed — try email' : err.message);
        btn.style.background = 'var(--error)';
        setTimeout(() => {
          btn.textContent = originalText;
          btn.style.background = '';
          btn.disabled = false;
        }, 4000);
      }
    });
  }

  // ---------- Theme Toggle ----------
  const savedTheme = localStorage.getItem('theme');
  if (savedTheme) {
    document.documentElement.setAttribute('data-theme', savedTheme);
  }

  document.querySelectorAll('.theme-toggle').forEach(btn => {
    btn.addEventListener('click', () => {
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      const newTheme = isDark ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', newTheme);
      localStorage.setItem('theme', newTheme);
    });
  });

  // ---------- Active Nav Link ----------
  const currentPage = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.nav a, .mobile-nav a').forEach(link => {
    const href = link.getAttribute('href');
    if (href === currentPage || (currentPage === '' && href === 'index.html')) {
      link.classList.add('active');
    }
  });

  // ---------- Interactive Process Timeline ----------
  document.querySelectorAll('.timeline-step').forEach(step => {
    step.addEventListener('click', () => {
      const wasActive = step.classList.contains('active');
      step.parentElement.querySelectorAll('.timeline-step').forEach(s => s.classList.remove('active'));
      if (!wasActive) step.classList.add('active');
    });
  });

  // ---------- Testimonial Carousel Indicator ----------
  const carouselTrack = document.querySelector('.testimonial-carousel');
  const carouselIndicator = document.querySelector('.testimonial-indicator');
  if (carouselTrack && carouselIndicator) {
    const total = carouselTrack.querySelectorAll('.testimonial-card').length;
    const indicator = carouselIndicator.querySelector('.testimonial-indicator-current');
    const totalEl = carouselIndicator.querySelector('.testimonial-indicator-total');
    if (totalEl) totalEl.textContent = total;
    let current = 0;
    const tick = () => {
      current = (current + 1) % total;
      if (indicator) indicator.textContent = current + 1;
    };
    setInterval(tick, 4000);
  }

});
