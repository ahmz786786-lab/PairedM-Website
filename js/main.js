/* ============================================
   PairedM Website — JavaScript
   ============================================ */

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

    // Close on link click
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

  // ---------- Header Scroll Effect ----------
  const header = document.querySelector('.header');
  if (header) {
    let lastScroll = 0;
    window.addEventListener('scroll', () => {
      const currentScroll = window.scrollY;
      if (currentScroll > 50) {
        header.style.borderBottomColor = 'var(--border)';
      } else {
        header.style.borderBottomColor = 'transparent';
      }
      lastScroll = currentScroll;
    });
  }

  // ---------- Contact Form ----------
  const contactForm = document.querySelector('#contact-form');
  if (contactForm) {
    contactForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const formData = new FormData(contactForm);
      const name = formData.get('name');

      // Show success message
      const btn = contactForm.querySelector('.btn');
      const originalText = btn.textContent;
      btn.textContent = 'Message Sent!';
      btn.style.background = 'var(--success)';

      setTimeout(() => {
        btn.textContent = originalText;
        btn.style.background = '';
        contactForm.reset();
      }, 3000);
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

});
