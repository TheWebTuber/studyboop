'use strict';
document.querySelectorAll('[data-copy]').forEach(button => {
  const original = button.textContent;
  let timer;
  button.addEventListener('click', async () => {
    let ok = false;
    try { await navigator.clipboard.writeText(button.dataset.copy); ok = true; }
    catch {
      const field = document.createElement('textarea');
      field.value = button.dataset.copy;
      field.setAttribute('readonly','');
      field.style.position='fixed';field.style.opacity='0';
      document.body.appendChild(field);field.select();
      try { ok = document.execCommand('copy'); } catch { ok = false; }
      field.remove();
    }
    clearTimeout(timer);
    button.textContent = ok ? 'Copied' : 'Copy failed';
    button.classList.toggle('copied', ok);
    timer = setTimeout(() => { button.textContent = original; button.classList.remove('copied'); }, 1500);
  });
});
