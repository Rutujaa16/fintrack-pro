(function(){
  const storageKey = 'vantage:theme';
  const toggleIcon = {dark: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>', light: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3v2M12 19v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M1 12h2M21 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4"/></svg>'};

  function applyTheme(theme){
    if(theme==='light') document.documentElement.setAttribute('data-theme','light');
    else document.documentElement.removeAttribute('data-theme');
    const btn = document.getElementById('theme-toggle');
    if(btn) btn.innerHTML = (theme==='light') ? toggleIcon.light + '<span>Light</span>' : toggleIcon.dark + '<span>Dark</span>';
  }

  function toggleTheme(){
    const current = document.documentElement.getAttribute('data-theme') === 'light' ? 'light' : 'dark';
    const next = current === 'light' ? 'dark' : 'light';
    applyTheme(next);
    localStorage.setItem(storageKey, next);
  }

  document.addEventListener('DOMContentLoaded', function(){
    const saved = localStorage.getItem(storageKey);
    const initial = saved ? saved : (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark');
    applyTheme(initial);

    const btn = document.getElementById('theme-toggle');
    if(btn) btn.addEventListener('click', toggleTheme);
  });
})();
