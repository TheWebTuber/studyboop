"use strict";

// Keep each supplied command exactly as it appears in the page.
document.querySelectorAll('[data-copy]').forEach(button => {
  let resetTimer;
  const originalLabel = button.textContent;
  button.addEventListener('click', async () => {
    let copied = false;
    try {
      await navigator.clipboard.writeText(button.dataset.copy);
      copied = true;
    } catch {
      const field = document.createElement('textarea');
      field.value = button.dataset.copy;
      field.style.position = 'fixed';
      field.style.opacity = '0';
      document.body.appendChild(field);
      field.select();
      try { copied = document.execCommand('copy'); } catch { copied = false; }
      field.remove();
    }
    clearTimeout(resetTimer);
    button.textContent = copied ? 'Copied' : 'Copy failed';
    button.classList.toggle('copied', copied);
    resetTimer = setTimeout(() => {
      button.textContent = originalLabel;
      button.classList.remove('copied');
    }, 1600);
  });
});

// A small mouse-following highlight; no motion on touch devices or reduced-motion settings.
const card = document.querySelector('.hero-card');
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');
if (card) {
  card.addEventListener('pointermove', event => {
    if (reducedMotion.matches || !finePointer.matches) return;
    const box = card.getBoundingClientRect();
    card.style.setProperty('--mouse-x', `${event.clientX - box.left}px`);
    card.style.setProperty('--mouse-y', `${event.clientY - box.top}px`);
  });
  card.addEventListener('pointerleave', () => {
    card.style.removeProperty('--mouse-x');
    card.style.removeProperty('--mouse-y');
  });
}
