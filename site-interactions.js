(() => {
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const menuButton = document.querySelector('.nav-toggle');
  const menu = document.getElementById('primaryNav');
  const closeMenu = () => {
    menu?.classList.remove('open');
    menuButton?.setAttribute('aria-expanded', 'false');
    menuButton?.setAttribute('aria-label', 'Menüyü aç');
  };
  menuButton?.addEventListener('click', () => {
    const open = menu.classList.toggle('open');
    menuButton.setAttribute('aria-expanded', String(open));
    menuButton.setAttribute('aria-label', open ? 'Menüyü kapat' : 'Menüyü aç');
    if (open) menu.querySelector('a')?.focus();
  });
  menu?.querySelectorAll('a[href^="#"]').forEach(link => link.addEventListener('click', closeMenu));
  document.addEventListener('keydown', event => { if (event.key === 'Escape') closeMenu(); });

  const sectionLinks = [...document.querySelectorAll('.nav-links a[href^="#"]')];
  const sections = sectionLinks.map(link => document.querySelector(link.hash)).filter(Boolean);
  const activeSections = new IntersectionObserver(entries => entries.forEach(entry => {
    if (!entry.isIntersecting) return;
    sectionLinks.forEach(link => link.classList.toggle('is-active', link.hash === `#${entry.target.id}`));
  }), { rootMargin: '-25% 0px -60% 0px', threshold: 0 });
  sections.forEach(section => activeSections.observe(section));

  const progress = document.createElement('div');
  progress.className = 'scroll-progress';
  progress.setAttribute('aria-hidden', 'true');
  document.body.append(progress);
  let framePending = false;
  const updateProgress = () => {
    const max = document.documentElement.scrollHeight - innerHeight;
    progress.style.transform = `scaleX(${max > 0 ? scrollY / max : 0})`;
    framePending = false;
  };
  addEventListener('scroll', () => {
    if (!framePending) { framePending = true; requestAnimationFrame(updateProgress); }
  }, { passive: true });
  updateProgress();

  const hero = document.getElementById('heroVisual');
  if (hero && !reduceMotion && matchMedia('(hover: hover) and (pointer: fine)').matches) {
    hero.addEventListener('pointermove', event => {
      const box = hero.getBoundingClientRect();
      const mx = (event.clientX - box.left) / box.width - .5;
      const my = (event.clientY - box.top) / box.height - .5;
      hero.style.setProperty('--rx', `${(-my * 5).toFixed(2)}deg`);
      hero.style.setProperty('--ry', `${(mx * 7).toFixed(2)}deg`);
      hero.style.setProperty('--hy', `${(-mx * 3).toFixed(2)}deg`);
    });
    hero.addEventListener('pointerleave', () => {
      hero.style.setProperty('--rx', '0deg'); hero.style.setProperty('--ry', '0deg'); hero.style.setProperty('--hy', '0deg');
    });
  }

  const hudLines = document.querySelectorAll('.hero-hud .hud-line strong');
  document.querySelectorAll('.route-pin').forEach(pin => pin.addEventListener('click', () => {
    if (hudLines[0]) hudLines[0].textContent = pin.dataset.title;
    if (hudLines[1]) hudLines[1].textContent = pin.dataset.copy;
    document.querySelectorAll('.route-pin').forEach(marker => marker.classList.toggle('selected', marker === pin));
  }));

  const cards = [...document.querySelectorAll('#mTrack .mq-card')].slice(0, 12);
  const dialog = document.createElement('dialog');
  dialog.className = 'feature-dialog';
  dialog.setAttribute('aria-labelledby', 'featureDialogTitle');
  dialog.innerHTML = '<div class="dialog-inner"><div class="dialog-head"><span class="dialog-icon" aria-hidden="true"></span><button class="dialog-close" type="button" aria-label="Kapat">×</button></div><h3 id="featureDialogTitle"></h3><p class="dialog-copy"></p><a class="dialog-cta" href="#download">Uygulamayı indir</a></div>';
  document.body.append(dialog);
  dialog.querySelector('.dialog-close').addEventListener('click', () => dialog.close());
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  let lastCard = null;
  const openCard = card => {
    lastCard = card;
    dialog.querySelector('.dialog-icon').textContent = card.querySelector('.mq-icon')?.textContent.trim() || '⌖';
    dialog.querySelector('#featureDialogTitle').textContent = card.querySelector('.mq-name')?.textContent.trim() || '';
    dialog.querySelector('.dialog-copy').textContent = card.querySelector('.mq-desc')?.textContent.trim() || '';
    dialog.showModal();
  };
  dialog.addEventListener('close', () => lastCard?.focus());
  cards.forEach(card => {
    card.tabIndex = 0;
    card.setAttribute('role', 'button');
    card.setAttribute('aria-haspopup', 'dialog');
    card.setAttribute('aria-label', `${card.querySelector('.mq-name')?.textContent.trim()}: ayrıntıları aç`);
    card.addEventListener('click', () => openCard(card));
    card.addEventListener('keydown', event => {
      if (event.target !== card || !['Enter', ' '].includes(event.key)) return;
      event.preventDefault(); openCard(card);
    });
    if (!reduceMotion && matchMedia('(hover: hover) and (pointer: fine)').matches) {
      card.addEventListener('pointermove', event => {
        const box = card.getBoundingClientRect();
        const x = (event.clientX - box.left) / box.width;
        const y = (event.clientY - box.top) / box.height;
        card.style.setProperty('--mx', x.toFixed(3)); card.style.setProperty('--my', y.toFixed(3));
        card.style.transform = `perspective(900px) rotateX(${((.5 - y) * 3.5).toFixed(2)}deg) rotateY(${((x - .5) * 4).toFixed(2)}deg) translateY(-3px)`;
      });
      card.addEventListener('pointerleave', () => {
        card.style.transform = ''; card.style.setProperty('--mx', '.5'); card.style.setProperty('--my', '.5');
      });
    }
  });

  const stepDots = [...document.querySelectorAll('.step-dot')];
  const stepBar = document.querySelector('.step-progress');
  if (stepBar && stepDots.length === 4) {
    stepBar.insertAdjacentHTML('afterend', '<div class="step-controls"><button class="step-control" type="button" data-step="prev">← Önceki adım</button><button class="step-control" type="button" data-step="next">Sonraki adım →</button></div>');
    stepBar.setAttribute('aria-label', 'SOS demo adım ilerlemesi');
  }
  const syncStep = n => {
    stepDots.forEach((dot, i) => {
      dot.setAttribute('aria-label', `${i + 1}. adım: ${dot.title}`);
      dot.setAttribute('aria-current', i + 1 === n ? 'step' : 'false');
    });
    const copy = [
      ['SOS demo adımı', 'Manuel başlatma akışının örnek görünümü', 'ETKİLEŞİMLİ DEMO'],
      ['Örnek koordinat', 'Konum aktarımının örnek görünümü', 'SMS ADIMI · DEMO'],
      ['Ekip bildirimi', 'Ekip alarmının örnek görünümü', 'EKİP ALARMI · DEMO'],
      ['Rehber görünümü', 'Bilgilendirme akışının örnek görünümü', 'KURTARMA · DEMO'],
    ][n - 1];
    const info = document.querySelector('.sos-info');
    if (info) {
      info.querySelector('.sos-coord').textContent = copy[0];
      info.querySelector('.sos-alt').textContent = copy[1];
      info.querySelector('.sos-status').textContent = copy[2];
    }
  };
  stepDots.forEach((dot, i) => dot.addEventListener('click', () => syncStep(i + 1)));
  document.querySelector('.step-controls')?.addEventListener('click', event => {
    const button = event.target.closest('button[data-step]');
    if (!button) return;
    const current = Math.max(1, stepDots.findIndex(dot => dot.classList.contains('active')) + 1);
    const next = button.dataset.step === 'next' ? Math.min(4, current + 1) : Math.max(1, current - 1);
    window.showStep(next);
    syncStep(next);
  });
  document.querySelector('.sos-step-nav')?.setAttribute('aria-label', 'SOS demo adımlarını seçin');
  stepDots.forEach((dot, i) => {
    dot.setAttribute('aria-label', `${i + 1}. adım: ${dot.title}`);
    dot.setAttribute('aria-current', i === 0 ? 'step' : 'false');
  });

  const protocolTabs = [...document.querySelectorAll('.ptab')];
  protocolTabs.forEach((tab, index) => {
    const panel = document.getElementById(tab.dataset.t);
    if (!tab.id) tab.id = `protocol-tab-${index + 1}`;
    tab.setAttribute('role', 'tab'); tab.setAttribute('aria-controls', panel?.id || '');
    tab.setAttribute('aria-selected', String(tab.classList.contains('active')));
    tab.tabIndex = tab.classList.contains('active') ? 0 : -1;
    panel?.setAttribute('role', 'tabpanel'); panel?.setAttribute('aria-labelledby', tab.id);
    if (panel && !tab.classList.contains('active')) panel.hidden = true;
    tab.addEventListener('click', () => protocolTabs.forEach(item => {
      const selected = item === tab;
      item.setAttribute('aria-selected', String(selected)); item.tabIndex = selected ? 0 : -1;
      document.getElementById(item.dataset.t)?.toggleAttribute('hidden', !selected);
    }));
    tab.addEventListener('keydown', event => {
      if (!['ArrowRight', 'ArrowLeft', 'Home', 'End'].includes(event.key)) return;
      event.preventDefault();
      const next = event.key === 'Home' ? 0 : event.key === 'End' ? protocolTabs.length - 1 : (index + (event.key === 'ArrowRight' ? 1 : protocolTabs.length - 1)) % protocolTabs.length;
      protocolTabs[next].focus(); protocolTabs[next].click();
    });
  });

  document.querySelectorAll('.faq-q').forEach((button, index) => {
    const answer = button.nextElementSibling;
    if (answer && !answer.id) answer.id = `faq-answer-${index + 1}`;
    button.setAttribute('aria-controls', answer?.id || '');
    button.setAttribute('aria-expanded', String(button.classList.contains('open')));
    button.addEventListener('click', () => requestAnimationFrame(() => {
      document.querySelectorAll('.faq-q').forEach(item => item.setAttribute('aria-expanded', String(item.classList.contains('open'))));
    }));
  });

  if (reduceMotion || innerWidth < 520) document.getElementById('c')?.setAttribute('data-static', 'true');
})();
