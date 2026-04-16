/* ============================================
   RELAX ROOM - JAVASCRIPT
   Versione HTML/CSS/JS Pura
   ============================================ */

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    // Initialize Theme (before anything else to avoid flash)
    initTheme();

    // Initialize Lucide Icons
    lucide.createIcons();

    // Initialize AOS (Animate on Scroll)
    AOS.init({
        duration: 800,
        easing: 'ease-out',
        once: true,
        offset: 100
    });

    // Initialize Particles
    initParticles();

    // Initialize Navbar
    initNavbar();

    // Initialize Smooth Scroll
    initSmoothScroll();
});

/* ============================================
   THEME TOGGLE
   ============================================ */
function initTheme() {
    const saved = localStorage.getItem('mcr-theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const theme = saved || (prefersDark ? 'dark' : 'light');

    applyTheme(theme);

    // Desktop toggle
    const toggle = document.getElementById('theme-toggle');
    if (toggle) {
        toggle.addEventListener('click', function() {
            const current = document.documentElement.getAttribute('data-theme') || 'light';
            const next = current === 'light' ? 'dark' : 'light';
            applyTheme(next);
            localStorage.setItem('mcr-theme', next);
            // Re-init particles with new colors
            reinitParticles();
        });
    }

    // Mobile toggle
    const mobileToggle = document.getElementById('mobile-theme-toggle');
    if (mobileToggle) {
        mobileToggle.addEventListener('click', function() {
            const current = document.documentElement.getAttribute('data-theme') || 'light';
            const next = current === 'light' ? 'dark' : 'light';
            applyTheme(next);
            localStorage.setItem('mcr-theme', next);
            reinitParticles();
        });
    }

    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function(e) {
        if (!localStorage.getItem('mcr-theme')) {
            applyTheme(e.matches ? 'dark' : 'light');
            reinitParticles();
        }
    });
}

function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    updateToggleIcons(theme);
}

function updateToggleIcons(theme) {
    const icons = document.querySelectorAll('.theme-icon');
    // Sun (&#9788;) for dark mode button (click to go light), Moon (&#9790;) for light mode button
    const symbol = theme === 'light' ? '\u263E' : '\u2604';
    const label = theme === 'light' ? 'Tema Scuro' : 'Tema Chiaro';

    icons.forEach(function(icon) { icon.textContent = symbol; });

    var desktopBtn = document.getElementById('theme-toggle');
    if (desktopBtn) desktopBtn.setAttribute('aria-label', label);

    var mobileBtn = document.getElementById('mobile-theme-toggle');
    if (mobileBtn) {
        mobileBtn.innerHTML = '<span class="theme-icon">' + symbol + '</span> ' + label;
    }
}

function reinitParticles() {
    // Destroy existing particle instances and re-create with theme colors
    if (window.pJSDom && window.pJSDom.length > 0) {
        // Clear all particle instances
        window.pJSDom.forEach(function(p) {
            if (p.pJS && p.pJS.fn && p.pJS.fn.vendors && p.pJS.fn.vendors.destroypJS) {
                p.pJS.fn.vendors.destroypJS();
            }
        });
        window.pJSDom = [];
    }
    initParticles();
}

/* ============================================
   PARTICLES CONFIGURATION
   ============================================ */
function initParticles() {
    var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    var colors = isDark
        ? ["#FFD700", "#f4a261", "#b8a9c9", "#f0e6d3"]
        : ["#FFD700", "#FF8C61", "#B5A1D6", "#ffffff"];

    const particlesConfig = {
        particles: {
            number: {
                value: 40,
                density: {
                    enable: true,
                    value_area: 1200
                }
            },
            color: {
                value: colors
            },
            shape: {
                type: "circle"
            },
            opacity: {
                value: 0.6,
                random: true,
                anim: {
                    enable: true,
                    speed: 0.5,
                    opacity_min: 0.2,
                    sync: false
                }
            },
            size: {
                value: 3,
                random: true,
                anim: {
                    enable: true,
                    speed: 1,
                    size_min: 1,
                    sync: false
                }
            },
            move: {
                enable: true,
                speed: 1,
                direction: "bottom",
                random: true,
                straight: false,
                out_mode: "out",
                bounce: false
            }
        },
        interactivity: {
            detect_on: "canvas",
            events: {
                onhover: {
                    enable: false
                },
                onclick: {
                    enable: false
                },
                resize: true
            }
        },
        retina_detect: true
    };
    
    // Hero Particles
    if (document.getElementById('particles-hero')) {
        particlesJS('particles-hero', particlesConfig);
    }
    
    // Download Section Particles (fewer particles)
    if (document.getElementById('particles-download')) {
        const downloadConfig = JSON.parse(JSON.stringify(particlesConfig));
        downloadConfig.particles.number.value = 25;
        particlesJS('particles-download', downloadConfig);
    }
}

/* ============================================
   NAVBAR
   ============================================ */
function initNavbar() {
    const navbar = document.getElementById('navbar');
    const hamburger = document.getElementById('hamburger');
    const mobileMenu = document.getElementById('mobile-menu');
    const menuIcon = document.getElementById('menu-icon');
    
    // Scroll Effect
    window.addEventListener('scroll', function() {
        if (window.scrollY > 50) {
            navbar.classList.add('scrolled');
        } else {
            navbar.classList.remove('scrolled');
        }
    });
    
    // Mobile Menu Toggle
    hamburger.addEventListener('click', function() {
        const isOpen = mobileMenu.classList.contains('active');
        
        if (isOpen) {
            mobileMenu.classList.remove('active');
            menuIcon.setAttribute('data-lucide', 'menu');
        } else {
            mobileMenu.classList.add('active');
            menuIcon.setAttribute('data-lucide', 'x');
        }
        
        // Re-render icon
        lucide.createIcons();
    });
    
    // Close mobile menu when clicking a link
    const mobileLinks = document.querySelectorAll('.mobile-link');
    mobileLinks.forEach(link => {
        link.addEventListener('click', function() {
            mobileMenu.classList.remove('active');
            menuIcon.setAttribute('data-lucide', 'menu');
            lucide.createIcons();
        });
    });
    
    // Close mobile menu when clicking outside
    document.addEventListener('click', function(e) {
        if (!navbar.contains(e.target) && mobileMenu.classList.contains('active')) {
            mobileMenu.classList.remove('active');
            menuIcon.setAttribute('data-lucide', 'menu');
            lucide.createIcons();
        }
    });
}

/* ============================================
   SMOOTH SCROLL
   ============================================ */
function initSmoothScroll() {
    const links = document.querySelectorAll('a[href^="#"]');
    
    links.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            if (targetId === '#') return;
            
            const targetElement = document.querySelector(targetId);
            if (targetElement) {
                const offsetTop = targetElement.offsetTop - 80; // Account for navbar height
                
                window.scrollTo({
                    top: offsetTop,
                    behavior: 'smooth'
                });
            }
        });
    });
}

/* ============================================
   UTILITY FUNCTIONS
   ============================================ */

// Debounce function for performance
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Check if element is in viewport
function isInViewport(element) {
    const rect = element.getBoundingClientRect();
    return (
        rect.top >= 0 &&
        rect.left >= 0 &&
        rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
        rect.right <= (window.innerWidth || document.documentElement.clientWidth)
    );
}

/* ============================================
   HOVER EFFECTS ENHANCEMENT
   ============================================ */

// Add interactive hover effects
document.addEventListener('DOMContentLoaded', function() {
    // Button ripple effect
    const buttons = document.querySelectorAll('.btn');
    buttons.forEach(button => {
        button.addEventListener('click', function(e) {
            const ripple = document.createElement('span');
            const rect = this.getBoundingClientRect();
            const size = Math.max(rect.width, rect.height);
            const x = e.clientX - rect.left - size / 2;
            const y = e.clientY - rect.top - size / 2;
            
            ripple.style.cssText = `
                position: absolute;
                width: ${size}px;
                height: ${size}px;
                left: ${x}px;
                top: ${y}px;
                background: rgba(255, 255, 255, 0.3);
                border-radius: 50%;
                transform: scale(0);
                animation: ripple 0.6s ease-out;
                pointer-events: none;
            `;
            
            this.style.position = 'relative';
            this.style.overflow = 'hidden';
            this.appendChild(ripple);
            
            setTimeout(() => ripple.remove(), 600);
        });
    });
});

// Add ripple animation to CSS dynamically
const style = document.createElement('style');
style.textContent = `
    @keyframes ripple {
        to {
            transform: scale(4);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);

/* ============================================
   PARALLAX EFFECT (Optional enhancement)
   ============================================ */

// Subtle parallax on scroll
window.addEventListener('scroll', debounce(function() {
    const scrolled = window.pageYOffset;
    const heroImage = document.querySelector('.floating-image');
    
    if (heroImage && scrolled < window.innerHeight) {
        heroImage.style.transform = `translateY(${scrolled * 0.3}px)`;
    }
}, 10));

console.log('🏠 Relax Room - Site loaded successfully!');
