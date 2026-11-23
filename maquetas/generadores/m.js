const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs'), path = require('path');
const dir = process.argv[2], out = process.argv[3], files = process.argv.slice(4);

const runtime = `
class DCLogic { constructor(p){ this.props = p || {}; this.state = {}; } setState(){} forceUpdate(){} }
function dcRender(){
  const src = document.querySelector('script[data-dc-script]').textContent;
  const Component = new Function('DCLogic', src + '; return Component;')(DCLogic);
  const vals = new Component({}).renderVals();
  const host = document.querySelector('x-dc');
  const helmet = host.querySelector('helmet');
  if (helmet) { while (helmet.firstChild) document.head.appendChild(helmet.firstChild); helmet.remove(); }
  const look = (expr, scope) => {
    expr = expr.trim();
    if (expr === 'true') return true; if (expr === 'false') return false;
    if (/^-?\\d+(\\.\\d+)?$/.test(expr)) return Number(expr);
    const parts = expr.split('.');
    let v = parts[0] in scope ? scope[parts[0]] : vals[parts[0]];
    for (const p of parts.slice(1)) v = v == null ? undefined : v[p];
    return v;
  };
  const sub = (s, scope) => s.replace(/\\{\\{([^}]+)\\}\\}/g, (_, e) => { const v = look(e, scope); return v == null ? '' : String(v); });
  const whole = (s, scope) => { const m = /^\\s*\\{\\{([^}]+)\\}\\}\\s*$/.exec(s); return m ? look(m[1], scope) : s; };
  const walk = (node, scope) => {
    for (const ch of Array.from(node.childNodes)) {
      if (ch.nodeType === 3) { ch.textContent = sub(ch.textContent, scope); continue; }
      if (ch.nodeType !== 1) continue;
      const tag = ch.tagName;
      if (tag === 'SC-FOR') {
        const list = whole(ch.getAttribute('list'), scope) || [];
        const as = ch.getAttribute('as');
        const frag = document.createDocumentFragment();
        list.forEach((item, i) => {
          const wrap = document.createElement('div'); wrap.innerHTML = ch.innerHTML;
          walk(wrap, Object.assign({}, scope, { [as]: item, $index: i }));
          while (wrap.firstChild) frag.appendChild(wrap.firstChild);
        });
        ch.replaceWith(frag); continue;
      }
      if (tag === 'SC-IF') {
        const v = whole(ch.getAttribute('value'), scope);
        if (v) { walk(ch, scope); ch.replaceWith(...Array.from(ch.childNodes)); } else ch.remove();
        continue;
      }
      for (const a of Array.from(ch.attributes)) {
        if (/^on[A-Z]/.test(a.name) || a.name.startsWith('on')) { ch.removeAttribute(a.name); continue; }
        if (a.value.includes('{{')) {
          const w = whole(a.value, scope);
          if (a.name === 'checked') { if (!w) ch.removeAttribute('checked'); continue; }
          ch.setAttribute(a.name, typeof w === 'string' ? w : sub(a.value, scope));
        }
      }
      if (tag === 'svg' || tag === 'SVG') { for (const n of ch.querySelectorAll('*')) for (const a of Array.from(n.attributes)) if (a.value.includes('{{')) n.setAttribute(a.name, sub(a.value, scope)); }
      walk(ch, scope);
    }
  };
  walk(host, {});
  document.body.setAttribute('data-listo', '1');
}`;

const res = {};
(async () => {
  const b = await chromium.launch({ args: ['--host-resolver-rules=MAP * ^NOTFOUND'] });
  for (const f of files) {
    let html = fs.readFileSync(path.join(dir, f), 'utf8');
    html = html.replace('<script src="./support.js"></script>', '');
    const m = /"\$preview":\{"width":(\d+),"height":(\d+)\}/.exec(html);
    const w = m ? +m[1] : 1440, h = m ? +m[2] : 900;
    const ctx = await b.newContext({ viewport: { width: w, height: h } });
    const pg = await ctx.newPage();
    let first = true;
    await pg.route('**/*', r => {
      if (first && r.request().isNavigationRequest()) { first = false; return r.fulfill({ contentType: 'text/html', body: html }); }
      return r.abort('aborted');
    });
    await pg.goto('http://dc.local/');
    await pg.addScriptTag({ content: runtime + '; dcRender();' });
    await pg.waitForSelector('body[data-listo]');
    const hh = await pg.evaluate(() => { const m = document.querySelector('main'); const l = m.lastElementChild; return Math.ceil(l.getBoundingClientRect().bottom - m.getBoundingClientRect().top + 16); }); res[f] = Math.max(844, 60 + 64 + hh);
    await ctx.close();
  }
  await b.close(); fs.writeFileSync(out, JSON.stringify(res));
})();
