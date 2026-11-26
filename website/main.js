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

  /* ---------- Windows laptop: opens, zooms into features, zooms out (scroll-driven) ---------- */
  function initLaptop() {
    const section = document.getElementById('windows');
    if (!section) return;
    const lap = section.querySelector('.lap');
    const screen = section.querySelector('.lap-screen');
    const spot = section.querySelector('.lap-spot');
    const steps = [...section.querySelectorAll('.lap-steps li')];
    const rail = [...section.querySelectorAll('.lap-rail i')];
    const img = {};
    section.querySelectorAll('.lap-screen img').forEach((el) => { img[el.dataset.shot] = el; });

    // Feature areas as fractions of the 1440×900 screenshot: x, y, w, h.
    const R = {
      palette: { shot: 'palette-dark', r: [0.295, 0.095, 0.41, 0.51] },
      week: { shot: 'schedule-dark', r: [0.185, 0.2, 0.49, 0.42] },
      cpa: { shot: 'grades-dark', r: [0.19, 0.155, 0.42, 0.29] },
      activity: { shot: 'home-dark', r: [0.66, 0.765, 0.3, 0.235] },
    };

    // Small screens / reduced motion: no pinning, show zoomed crops on the cards instead.
    const big = matchMedia('(min-width: 760px) and (min-height: 560px)');
    if (reduceMotion || !big.matches) {
      steps.forEach((li) => {
        const f = R[li.dataset.step];
        const shot = f ? f.shot : li.dataset.step === 'theme' ? 'home' : 'home-dark';
        const [x, y, w, h] = f ? f.r : [0, 0, 1, 1];
        if (!f && li.dataset.step === 'home') return; // the laptop above already shows Home
        const crop = document.createElement('div');
        crop.className = 'lap-crop';
        crop.setAttribute('role', 'img');
        crop.setAttribute('aria-label', img[shot].alt);
        crop.style.setProperty('--img', `url("${img[shot].getAttribute('src')}")`);
        crop.style.setProperty('--ar', `${w * 1440} / ${h * 900}`);
        crop.style.setProperty('--bs', `${100 / w}%`);
        crop.style.setProperty('--bp', `${w < 1 ? (x / (1 - w)) * 100 : 0}% ${h < 1 ? (y / (1 - h)) * 100 : 0}%`);
        li.prepend(crop);
      });
      Object.values(img).forEach((el) => { el.loading = 'eager'; });
      return;
    }

    section.classList.add('is-pinned');
    Object.values(img).forEach((el) => { el.loading = 'eager'; });

    // Camera stops along the scroll (0 → 1).
    const STOPS = [
      [0.00, 'intro'], [0.12, 'fit'], [0.18, 'fit'],
      [0.26, 'palette'], [0.33, 'palette'], [0.385, 'fit'],
      [0.45, 'week'], [0.53, 'week'], [0.585, 'fit'],
      [0.65, 'cpa'], [0.72, 'cpa'], [0.765, 'fit'],
      [0.83, 'activity'], [0.89, 'activity'], [0.94, 'fit'], [1.00, 'fit'],
    ];
    // Which screenshot is on screen (swapped while zoomed out).
    const SHOTS = [[0, 'home-dark'], [0.205, 'palette-dark'], [0.385, 'schedule-dark'], [0.585, 'grades-dark'], [0.765, 'home-dark']];
    // Caption ranges.
    const STEPS = [[0.09, 'home'], [0.205, 'palette'], [0.385, 'week'], [0.585, 'cpa'], [0.765, 'activity'], [0.915, 'theme']];

    let L = null; // layout measured on resize
    function measure() {
      section.style.setProperty('--s', 1); section.style.setProperty('--tx', '0px'); section.style.setProperty('--ty', '0px');
      lap.style.setProperty('--lid', '0deg');
      const vw = innerWidth, vh = innerHeight;
      const lapW = Math.min(1000, vw * 0.88, (vh - 120) * 1.45);
      section.style.setProperty('--lapw', `${lapW}px`);
      const lr = lap.getBoundingClientRect();
      const sr = screen.getBoundingClientRect();
      const wide = vw >= 1100;
      // Area the camera frames: right of the caption on wide screens, above it otherwise.
      const box = wide
        ? { x0: Math.min(440, vw * 0.33), x1: vw - 70, y0: 88, y1: vh - 50 }
        : { x0: 28, x1: vw - 28, y0: 88, y1: vh - 250 };
      L = {
        vw, vh, box, lapW, lapH: lr.height,
        scr: { x: sr.left - lr.left - lr.width / 2, y: sr.top - lr.top - lr.height / 2, w: sr.width, h: sr.height },
      };
      L.cam = {};
      const bw = box.x1 - box.x0, bh = box.y1 - box.y0;
      const bcx = (box.x0 + box.x1) / 2 - vw / 2, bcy = (box.y0 + box.y1) / 2 - vh / 2;
      // Whole laptop framed in the box.
      const fs = Math.min(1, bw / lr.width, bh / lr.height);
      L.cam.fit = { s: fs, tx: bcx, ty: bcy };
      // Closed and centred under the intro text.
      L.cam.intro = { s: 0.78, tx: 0, ty: vh * 0.06 };
      for (const [k, f] of Object.entries(R)) {
        const [x, y, w, h] = f.r;
        const s = Math.max(1, Math.min(3.4, (bw * 0.96) / (w * L.scr.w), (bh * 0.94) / (h * L.scr.h)));
        const px = L.scr.x + (x + w / 2) * L.scr.w, py = L.scr.y + (y + h / 2) * L.scr.h;
        L.cam[k] = { s, tx: bcx - px * s, ty: bcy - py * s };
      }
    }

    const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
    const ease = (t) => t * t * (3 - 2 * t);
    const range = (p, a, b) => clamp((p - a) / (b - a));
    const lerp = (a, b, t) => a + (b - a) * t;

    function render(p) {
      // Camera between the two surrounding stops.
      let i = 0;
      while (i < STOPS.length - 2 && p > STOPS[i + 1][0]) i++;
      const [pa, ka] = STOPS[i], [pb, kb] = STOPS[i + 1];
      const t = ease(range(p, pa, pb));
      const A = L.cam[ka], B = L.cam[kb];
      section.style.setProperty('--s', lerp(A.s, B.s, t).toFixed(4));
      section.style.setProperty('--tx', `${lerp(A.tx, B.tx, t).toFixed(1)}px`);
      section.style.setProperty('--ty', `${lerp(A.ty, B.ty, t).toFixed(1)}px`);

      // Lid opens, screen powers on, intro fades.
      const open = ease(range(p, 0.015, 0.11));
      lap.style.setProperty('--lid', `${(1 - open) * 84}deg`);
      screen.style.setProperty('--power', (0.05 + 0.95 * ease(range(p, 0.05, 0.12))).toFixed(3));
      section.style.setProperty('--intro', (1 - range(p, 0.01, 0.07)).toFixed(3));

      // Highlight the feature being zoomed into.
      const region = R[ka] || R[kb];
      const amt = (R[ka] ? 1 - t : 0) + (R[kb] ? t : 0);
      if (region && amt > 0.01) {
        const [x, y, w, h] = region.r;
        Object.assign(spot.style, { left: `${x * 100}%`, top: `${y * 100}%`, width: `${w * 100}%`, height: `${h * 100}%` });
        spot.style.opacity = clamp(amt * 1.4 - 0.2).toFixed(3);
      } else spot.style.opacity = '0';

      // Screenshot crossfades.
      const op = {};
      SHOTS.forEach(([at, key], j) => {
        const next = SHOTS[j + 1] ? SHOTS[j + 1][0] : 2;
        const v = Math.min(range(p, at - 0.012, at + 0.012), 1 - range(p, next - 0.012, next + 0.012));
        op[key] = Math.max(op[key] || 0, j === 0 ? 1 - range(p, next - 0.012, next + 0.012) : v);
      });
      for (const [k, el] of Object.entries(img)) if (k !== 'home') el.style.opacity = (op[k] || 0).toFixed(3);
      // Light theme wipes across at the end.
      const wipe = ease(range(p, 0.935, 0.985));
      img.home.style.opacity = wipe > 0 ? '1' : '0';
      img.home.style.clipPath = `inset(0 ${(100 - wipe * 100).toFixed(2)}% 0 0)`;

      // Caption + rail.
      let s = -1;
      STEPS.forEach(([at], j) => { if (p >= at) s = j; });
      steps.forEach((li, j) => {
        li.classList.toggle('is-active', j === s);
        li.setAttribute('aria-hidden', String(j !== s));
      });
      rail.forEach((r, j) => r.classList.toggle('on', j === s));
    }

    let target = 0, cur = 0, raf = 0;
    function progress() {
      const r = section.getBoundingClientRect();
      return clamp(-r.top / (r.height - innerHeight));
    }
    function loop() {
      cur += (target - cur) * 0.14;
      if (Math.abs(target - cur) < 0.0005) cur = target;
      render(cur);
      raf = cur === target ? 0 : requestAnimationFrame(loop);
    }
    function onScroll() {
      target = progress();
      if (!raf) raf = requestAnimationFrame(loop);
    }

    measure();
    cur = target = progress();
    render(cur);
    addEventListener('scroll', onScroll, { passive: true });
    addEventListener('resize', () => { measure(); cur = target = progress(); render(cur); });
    big.addEventListener('change', () => location.reload());
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
  initLaptop();
  initNav();
  initRelease();
})();
