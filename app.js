document.querySelectorAll('[data-copy]').forEach(button=>{
  button.addEventListener('click',async()=>{
    const text=button.dataset.copy;
    try{await navigator.clipboard.writeText(text)}catch{const t=document.createElement('textarea');t.value=text;document.body.appendChild(t);t.select();document.execCommand('copy');t.remove()}
    const old=button.textContent;button.textContent='Copied';button.classList.add('copied');setTimeout(()=>{button.textContent=old;button.classList.remove('copied')},1300)
  })
})
