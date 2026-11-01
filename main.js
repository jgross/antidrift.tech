// Waitlist forms post to the antidrift Supabase project's join_waitlist()
// function (supabase/migrations/). Signing up twice merges the answers.
const SUPABASE_URL = 'https://ykwjaeglfayegiziuvkg.supabase.co';
// Publishable key: safe in the browser. It can only call join_waitlist().
const SUPABASE_KEY = 'sb_publishable__Gt1fn0UhJSS8qCijqjqzA__PzeuIYw';

// Where the visitor came from, so signups can be compared per channel.
const params = new URLSearchParams(location.search);
const source = params.get('utm_source') || params.get('ref') || document.referrer || 'direct';

// Two forms: email-only in the hero, and the full one with questions at the bottom.
for (const form of document.querySelectorAll('form.waitlist')) {
  const status = form.querySelector('.form-status');
  const show = (text, kind = '') => {
    status.textContent = text;
    status.className = `form-status ${kind}`;
  };

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const data = new FormData(form);

    if (data.get('company_website')) return; // honeypot tripped

    const email = String(data.get('email') || '').trim();
    if (!form.elements.email.checkValidity() || !email) {
      show('That email doesn\'t look right.', 'err');
      form.elements.email.focus();
      return;
    }

    const isHero = form.classList.contains('inline-form');
    const payload = {
      p_email: email,
      p_agents: data.getAll('agents'),
      p_parallel: data.get('parallel') || null,
      p_pay: data.get('pay') || null,
      p_form: isHero ? 'hero' : 'full',
      p_source: source,
      p_campaign: params.get('utm_campaign'),
    };

    const button = form.querySelector('button');
    button.disabled = true;
    show('Sending…');
    try {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/join_waitlist`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: SUPABASE_KEY },
        body: JSON.stringify(payload),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`);
      form.classList.add('done');
      if (isHero) {
        // Carry the email down so the questions are one tap each.
        const full = document.querySelector('form.waitlist.form');
        if (full) full.elements.email.value = email;
        status.innerHTML = 'You\'re in. <a href="#join">Got 20 seconds? Three quick questions ↓</a>';
        status.className = 'form-status ok';
      } else {
        show('You\'re in. One email when it\'s ready. Thanks for the answers.', 'ok');
      }
    } catch (err) {
      console.error('[antidrift] Waitlist signup failed', err);
      show('That didn\'t go through. Try again in a moment?', 'err');
      button.disabled = false;
    }
  });
}
