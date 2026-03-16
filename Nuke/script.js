const $ = (id) => document.getElementById(id);

let warnTimer = null;
let warnLeft = 0;

const hackWrap = $('hack');
const hackText = $('hackText');

function show(el){ el.classList.remove('hidden'); }
function hide(el){ el.classList.add('hidden'); }

function postNui(eventName, data = {}) {
  fetch(`https://${GetParentResourceName()}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  });
}

function setHack(lines) {
  hackText.textContent = lines.join('\n');
}

function runHackSequence() {
  const boot = [
    '[NUC-CONSOLE] establishing uplink...',
    '[AUTH] token=**************',
    '[LINK] satcom: ok',
    '[LINK] rf: ok',
    '[PROTO] arming payload...',
    '[WARN] civilians: none',
    '[SYS] checksum: OK',
    '',
    '> EXECUTE: NUKE_STRIKE()',
    ''
  ];

  const ascii = [
    '                _ ._  _ , _ ._',
    '              (_ \' ( `  )_  .__)',
    '            ( (  (    )   `)  ) _)',
    '           (__ (_   (_ . _) _) ,__)',
    '               `~~`\\ \' . /`~~`',
    '                    ;   ;',
    '                    /   \\',
    '___________________/_ __ \\___________________',
    '',
    '[IMPACT] detonation confirmed.',
    '[SYS] terminating feed...'
  ];

  show(hackWrap);
  setHack([]);

  let idx = 0;
  const t1 = setInterval(() => {
    idx++;
    setHack(boot.slice(0, idx));
    if (idx >= boot.length) {
      clearInterval(t1);

      setTimeout(() => {
        setHack(boot.concat(ascii));

        setTimeout(() => {
          hide(hackWrap);
          postNui('hackDone', {});
        }, 1800);
      }, 650);
    }
  }, 120);
}

window.addEventListener('message', (e) => {
  const { action, data } = e.data || {};
  if (!action) return;

  if (action === 'hud') {
    show($('hud'));
    $('hudKills').textContent = String(data?.kills ?? 0);
    if (data?.ready) {
      show($('hudReady'));
      show($('hudExit'));
    } else {
      hide($('hudReady'));
      hide($('hudExit'));
    }
  }

  if (action === 'armed') {
    if (!data?.show) { hide($('armed')); return; }
    show($('armed'));
    const ms = Math.max(0, data.ms || 0);
    const total = Math.max(1, data.total || 3000);
    const pct = Math.min(100, Math.floor((ms / total) * 100));
    $('armedFill').style.width = pct + '%';
    $('armedText').textContent = data.holding ? (pct >= 100 ? 'CONFIRMED' : 'HOLDING...') : 'HOLD TO CONFIRM';
  }

  if (action === 'armed_mini') {
    if (data?.show) show($('armedMini')); else hide($('armedMini'));
  }

  if (action === 'count_local') {
    show($('countLocal'));
    $('countLocalNum').textContent = String(data?.seconds ?? 5);
  }
  if (action === 'count_local_hide') hide($('countLocal'));

  if (action === 'warning') {
    show($('warning'));
    warnLeft = Math.max(1, data?.seconds || 5);
    $('warnCount').textContent = String(warnLeft);

    if (warnTimer) clearInterval(warnTimer);
    warnTimer = setInterval(() => {
      warnLeft -= 1;
      if (warnLeft <= 0) {
        clearInterval(warnTimer);
        warnTimer = null;
        $('warnCount').textContent = '0';
        return;
      }
      $('warnCount').textContent = String(warnLeft);
    }, 1000);
  }

  if (action === 'hide_warning') hide($('warning'));

  if (action === 'hide_all') {
    hide($('armed'));
    hide($('armedMini'));
    hide($('warning'));
    hide($('countLocal'));
    hide(hackWrap);
    setHack([]);
  }

  if (action === 'hack') {
    if (!data?.show) { hide(hackWrap); return; }
    runHackSequence();
  }
});
