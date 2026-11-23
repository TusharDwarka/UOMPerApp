(() => {
  'use strict';

  const REPO = 'TusharDwarka/UOMPerApp';
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const finePointer = matchMedia('(hover: hover) and (pointer: fine)').matches;
  const mouse = { x: innerWidth / 2, y: innerHeight / 3, active: false };

  addEventListener('pointermove', (e) => {
    mouse.x = e.clientX; mouse.y = e.clientY; mouse.active = true;
  }, { passive: true });
  document.addEventListener('pointerleave', () => { mouse.active = false; });

  /* ---------- Moving grid (squares drifting diagonally, hovered cell lights up) ---------- */
  function initGrid() {
    const canvas = document.getElementById('grid');
    const ctx = canvas.getContext('2d');
    const size = 46;
    const speed = 0.25;
    let w = 0, h = 0, dpr = 1, ox = 0, oy = 0, raf = 0;

    function resize() {
      dpr = Math.min(devicePixelRatio || 1, 2);
      w = innerWidth; h = innerHeight;
      canvas.width = w * dpr; canvas.height = h * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      draw();
    }

    function draw() {
      ctx.clearRect(0, 0, w, h);
      const sx = -(ox % size), sy = -(oy % size);

      // hovered cell
      if (mouse.active && finePointer) {
        const cx = Math.floor((mouse.x - sx) / size) * size + sx;
        const cy = Math.floor((mouse.y - sy) / size) * size + sy;
        ctx.fillStyle = 'rgba(41, 98, 255, 0.22)';
        ctx.fillRect(cx, cy, size, size);
      }

      ctx.strokeStyle = 'rgba(255, 255, 255, 0.055)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let x = sx; x <= w + size; x += size) { ctx.moveTo(Math.round(x) + .5, 0); ctx.lineTo(Math.round(x) + .5, h); }
      for (let y = sy; y <= h + size; y += size) { ctx.moveTo(0, Math.round(y) + .5); ctx.lineTo(w, Math.round(y) + .5); }
      ctx.stroke();

      // fade the grid out towards the edges
      const g = ctx.createRadialGradient(w / 2, h * 0.35, 0, w / 2, h * 0.35, Math.hypot(w, h) * 0.62);
      g.addColorStop(0, 'rgba(5, 6, 13, 0)');
      g.addColorStop(1, 'rgba(5, 6, 13, 1)');
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, w, h);
    }

    function tick() {
      ox += speed; oy += speed;
      draw();
      raf = requestAnimationFrame(tick);
    }

    addEventListener('resize', resize);
    resize();
    if (reduceMotion) return;
    raf = requestAnimationFrame(tick);
    document.addEventListener('visibilitychange', () => {
      cancelAnimationFrame(raf);
      if (!document.hidden) raf = requestAnimationFrame(tick);
    });
  }

  /* ---------- Target cursor: spinning brackets that lock onto buttons and links ---------- */
  function initCursor() {
    if (!finePointer) return;
    document.documentElement.classList.add('has-cursor');
    const root = document.querySelector('.cursor');
    const dot = root.querySelector('.cursor-dot');
    const frame = root.querySelector('.cursor-frame');
    const base = 34, pad = 8;
    let fx = mouse.x - base / 2, fy = mouse.y - base / 2, fw = base, fh = base;
    let target = null;

    document.addEventListener('pointerover', (e) => {
      const t = e.target.closest('[data-cursor="target"]');
      if (t !== target) {
        target = t;
        frame.classList.toggle('locked', !!t);
        if (!t) { frame.style.width = frame.style.height = ''; }
      }
    });
    addEventListener('pointerdown', () => root.classList.add('down'));
    addEventListener('pointerup', () => root.classList.remove('down'));
    document.addEventListener('pointerleave', () => { root.style.opacity = '0'; });
    document.addEventListener('pointerenter', () => { root.style.opacity = '1'; });

    (function loop() {
      dot.style.translate = `${mouse.x}px ${mouse.y}px`;
      let tx, ty;
      if (target && target.isConnected) {
        const r = target.getBoundingClientRect();
        fw = r.width + pad * 2; fh = r.height + pad * 2;
        tx = r.left - pad; ty = r.top - pad;
        frame.style.width = fw + 'px'; frame.style.height = fh + 'px';
      } else {
        const s = root.classList.contains('down') ? 26 : base;
        tx = mouse.x - s / 2; ty = mouse.y - s / 2;
      }
      const k = target ? 0.22 : 0.3;
      fx += (tx - fx) * k; fy += (ty - fy) * k;
      frame.style.translate = `${fx}px ${fy}px`;
      requestAnimationFrame(loop);
    })();
  }

  /* ---------- Click sparks ---------- */
  function initSparks() {
    if (reduceMotion) return;
    const canvas = document.getElementById('sparks');
    const ctx = canvas.getContext('2d');
    let sparks = [], running = false, dpr = 1;
    function resize() {
      dpr = Math.min(devicePixelRatio || 1, 2);
      canvas.width = innerWidth * dpr; canvas.height = innerHeight * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }
    addEventListener('resize', resize); resize();

    addEventListener('pointerdown', (e) => {
      const now = performance.now();
      for (let i = 0; i < 9; i++) sparks.push({ x: e.clientX, y: e.clientY, a: (Math.PI * 2 * i) / 9, t: now });
      if (!running) { running = true; requestAnimationFrame(frame); }
    });

    function frame(now) {
      ctx.clearRect(0, 0, innerWidth, innerHeight);
      sparks = sparks.filter((s) => now - s.t < 450);
      for (const s of sparks) {
        const p = (now - s.t) / 450, ease = p * (2 - p);
        const r = ease * 34, len = 11 * (1 - ease);
        ctx.strokeStyle = `rgba(120, 220, 255, ${1 - p})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(s.x + Math.cos(s.a) * r, s.y + Math.sin(s.a) * r);
        ctx.lineTo(s.x + Math.cos(s.a) * (r + len), s.y + Math.sin(s.a) * (r + len));
        ctx.stroke();
      }
      if (sparks.length) requestAnimationFrame(frame);
      else { running = false; ctx.clearRect(0, 0, innerWidth, innerHeight); }
    }
  }

  /* ---------- Spotlight cards ---------- */
  function initSpotlight() {
    document.addEventListener('pointermove', (e) => {
      const el = e.target.closest('.spot');
      if (!el) return;
      const r = el.getBoundingClientRect();
      el.style.setProperty('--mx', `${e.clientX - r.left}px`);
      el.style.setProperty('--my', `${e.clientY - r.top}px`);
    }, { passive: true });
  }

  /* ---------- Hero headline: words blur in ---------- */
  function initBlurText() {
    let i = 0;
    document.querySelectorAll('.blur-in').forEach((line) => {
      const parts = [];
      line.childNodes.forEach((n) => {
        if (n.nodeType === Node.TEXT_NODE) {
          n.textContent.split(/(\s+)/).forEach((w) => {
            if (!w) return;
            if (/^\s+$/.test(w)) parts.push(document.createTextNode(' '));
            else { const s = document.createElement('span'); s.className = 'word'; s.textContent = w; parts.push(s); }
          });
        } else {
          const s = document.createElement('span'); s.className = 'word'; s.appendChild(n.cloneNode(true)); parts.push(s);
        }
      });
      line.replaceChildren(...parts);
      line.querySelectorAll('.word').forEach((w) => {
        w.style.animationDelay = `${120 + i++ * 110}ms`;
        w.classList.add('in');
      });
    });
  }

  /* ---------- Scroll reveal ---------- */
  function initReveal() {
    const els = document.querySelectorAll('.reveal');
    if (reduceMotion || !('IntersectionObserver' in window)) { els.forEach((e) => e.classList.add('in')); return; }
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (!en.isIntersecting) return;
        const sibs = [...en.target.parentElement.children].filter((c) => c.classList.contains('reveal'));
        const idx = Math.max(0, sibs.indexOf(en.target));
        en.target.style.transitionDelay = `${Math.min(idx % 6, 5) * 70}ms`;
        en.target.classList.add('in');
        io.unobserve(en.target);
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    els.forEach((e) => io.observe(e));
  }

  /* ---------- Screens showcase tabs (auto-advance until the visitor picks one) ---------- */
  function initTabs() {
    const tabs = [...document.querySelectorAll('.tabs [role="tab"]')];
    const list = document.querySelector('.tabs');
    const img = document.getElementById('shot');
    if (!tabs.length || !img) return;
    const DUR = 5000;
    list.style.setProperty('--dur', DUR + 'ms');
    tabs.forEach((t) => { const p = new Image(); p.src = `assets/screens/${t.dataset.shot}.webp`; });

    let current = 0, timer = 0, auto = !reduceMotion;

    function select(i) {
      current = (i + tabs.length) % tabs.length;
      tabs.forEach((t, j) => t.setAttribute('aria-selected', String(j === current)));
      const t = tabs[current];
      img.classList.add('swap');
      setTimeout(() => {
        img.src = `assets/screens/${t.dataset.shot}.webp`;
        img.alt = `${t.querySelector('strong').textContent} screen`;
        const done = () => img.classList.remove('swap');
        if (img.complete) requestAnimationFrame(done); else img.onload = done;
      }, 220);
      schedule();
    }
    function schedule() {
      clearTimeout(timer);
      if (auto) timer = setTimeout(() => select(current + 1), DUR);
    }

    tabs.forEach((t, i) => t.addEventListener('click', () => {
      auto = false; list.classList.add('paused'); select(i);
    }));
    list.addEventListener('keydown', (e) => {
      if (!['ArrowDown', 'ArrowUp', 'ArrowLeft', 'ArrowRight'].includes(e.key)) return;
      e.preventDefault();
      auto = false; list.classList.add('paused');
      select(current + (e.key === 'ArrowDown' || e.key === 'ArrowRight' ? 1 : -1));
      tabs[current].focus();
    });
    if (!auto) list.classList.add('paused');

    // only start cycling once the section is on screen
    if ('IntersectionObserver' in window) {
      new IntersectionObserver((en) => {
        if (en[0].isIntersecting) schedule(); else clearTimeout(timer);
      }, { threshold: 0.3 }).observe(list);
    }
  }

  /* ---------- 3D tilt on phones, magnetic buttons ---------- */
  function initTilt() {
    if (reduceMotion || !finePointer) return;
    const hero = document.querySelector('.phone-c');
    const stage = document.querySelector('.showcase-phone');
    const big = document.querySelector('.phone-lg');

    addEventListener('pointermove', () => {
      const nx = mouse.x / innerWidth - 0.5, ny = mouse.y / innerHeight - 0.5;
      hero.style.setProperty('--ry', `${nx * 16}deg`);
      hero.style.setProperty('--rx', `${-ny * 12}deg`);
    }, { passive: true });

    stage.addEventListener('pointermove', (e) => {
      const r = stage.getBoundingClientRect();
      const nx = (e.clientX - r.left) / r.width - 0.5, ny = (e.clientY - r.top) / r.height - 0.5;
      big.style.transform = `perspective(1200px) rotateY(${nx * 18}deg) rotateX(${-ny * 14}deg)`;
    });
    stage.addEventListener('pointerleave', () => { big.style.transform = ''; });

    document.querySelectorAll('.magnet').forEach((b) => {
      b.addEventListener('pointermove', (e) => {
        const r = b.getBoundingClientRect();
        b.style.transform = `translate(${(e.clientX - r.left - r.width / 2) * 0.18}px, ${(e.clientY - r.top - r.height / 2) * 0.3}px)`;
      });
      b.addEventListener('pointerleave', () => { b.style.transform = ''; });
    });
  }

  /* ---------- Nav background on scroll ---------- */
  function initNav() {
    const nav = document.querySelector('.nav');
    const on = () => nav.classList.toggle('scrolled', scrollY > 20);
    addEventListener('scroll', on, { passive: true }); on();
  }

  /* ---------- Latest release from GitHub (falls back to the releases page) ---------- */
  async function initRelease() {
    const KEY = 'uomper-release';
    let rel = null;
    try {
      const cached = JSON.parse(sessionStorage.getItem(KEY) || 'null');
      if (cached && Date.now() - cached.at < 30 * 60 * 1000) rel = cached.rel;
    } catch (_) { /* storage blocked */ }

    if (!rel) {
      try {
        const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, { headers: { Accept: 'application/vnd.github+json' } });
        if (!res.ok) return;
        const data = await res.json();
        rel = {
          name: data.name, tag: data.tag_name, date: data.published_at,
          assets: (data.assets || []).map((a) => ({ name: a.name, url: a.browser_download_url, size: a.size })),
        };
        try { sessionStorage.setItem(KEY, JSON.stringify({ at: Date.now(), rel })); } catch (_) { /* ignore */ }
      } catch (_) { return; }
    }

    const find = (re) => rel.assets.find((a) => re.test(a.name));
    const android = find(/\.apk$/i);
    const windows = find(/windows.*\.zip$/i) || find(/\.zip$/i);
    const verMatch = (android || windows || {}).name?.match(/-(v\d+(?:\.\d+)*)/i);
    const version = verMatch ? verMatch[1] : (rel.name || rel.tag);
    const mb = (b) => `${(b / 1048576).toFixed(1)} MB`;

    if (version) {
      document.querySelectorAll('[data-version]').forEach((el) => { el.textContent = version; });
      document.querySelectorAll('[data-version-label]').forEach((el) => { el.textContent = `${version} is out`; });
    }
    if (rel.date) {
      const d = new Date(rel.date);
      const el = document.querySelector('[data-date]');
      if (el && !isNaN(d)) el.textContent = ` · ${d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}`;
    }
    [['android', android, 'APK'], ['windows', windows, 'ZIP']].forEach(([key, a, kind]) => {
      if (!a) return;
      document.querySelectorAll(`[data-asset="${key}"]`).forEach((el) => { el.href = a.url; });
      const size = document.querySelector(`[data-size="${key}"]`);
      if (size) size.textContent = `${kind} · ${mb(a.size)}`;
    });
  }

  initGrid();
  initCursor();
  initSparks();
  initSpotlight();
  initBlurText();
  initReveal();
  initTabs();
  initTilt();
  initNav();
  initRelease();
})();
