(function(){const t=document.createElement("link").relList;if(t&&t.supports&&t.supports("modulepreload"))return;for(const r of document.querySelectorAll('link[rel="modulepreload"]'))n(r);new MutationObserver(r=>{for(const s of r)if(s.type==="childList")for(const l of s.addedNodes)l.tagName==="LINK"&&l.rel==="modulepreload"&&n(l)}).observe(document,{childList:!0,subtree:!0});function o(r){const s={};return r.integrity&&(s.integrity=r.integrity),r.referrerPolicy&&(s.referrerPolicy=r.referrerPolicy),r.crossOrigin==="use-credentials"?s.credentials="include":r.crossOrigin==="anonymous"?s.credentials="omit":s.credentials="same-origin",s}function n(r){if(r.ep)return;r.ep=!0;const s=o(r);fetch(r.href,s)}})();const f=[{id:"archive-pure",name:"Archive Pure",mark:"I",blurb:"Highest available YouTube stream.",quality:"max"},{id:"crystal",name:"Crystal",mark:"II",blurb:"Top clarity progressive stream.",quality:"max"},{id:"tempered",name:"Tempered",mark:"III",blurb:"Cap around 1080p for everyday use.",quality:"1080"},{id:"audio-ingot",name:"Audio Ingot",mark:"IV",blurb:"Best audio-only track.",quality:"audio"}];function m(e){return f.find(t=>t.id===e)??f[0]}function E(){return crypto.randomUUID()}function T(e){switch(e){case"queued":return"Queued";case"prospecting":return"Prospecting";case"smelting":return"Smelting";case"quenching":return"Quenching";case"finished":return"Forged";case"failed":return"Cracked"}}const u="http://127.0.0.1:8742",y="https://vidforge.samuelbacaro.workers.dev";async function b(){try{const e=await fetch(`${u}/api/health`,{method:"GET",headers:{Accept:"application/json"}});if(e.ok){const t=await e.json();if(t.ok!==!1){const o=t.cookiesBrowser??null,n=!!t.cookiesOk,r=o?C(o):"browser";return{mode:"local",cookiesBrowser:o,cookiesOk:n,label:n?`Local forge ready · ${r} cookies`:"Local forge ready · cookies weak"}}}}catch{}try{if((await fetch(`${y}/api/health`,{method:"GET",headers:{Accept:"application/json"}})).ok)return{mode:"cloud",label:"Companion offline — cloud fallback"}}catch{}return{mode:"offline",label:"Forge offline"}}async function $(e,t){const o=await b();if(o.mode==="local"){await S(e,t);return}if(o.mode==="cloud"){await q(e,t);return}throw new Error('Companion offline. In Terminal: export PATH="$HOME/.local/bin:$PATH" && vidforge-ui')}async function S(e,t){t({phase:"prospecting",progress:.08,status:"Sending ore to local forge…"});const o=await fetch(`${u}/api/forge`,{method:"POST",headers:{Accept:"application/json","Content-Type":"application/json"},body:JSON.stringify({url:e.url,alloy:e.alloy})}),n=await o.json();if(!o.ok)throw new Error(n.error||`Local forge HTTP ${o.status}`);const r=n.id;for(t({title:n.title||e.title,phase:p(n.phase),progress:n.progress,status:n.status});;){await O(700);const s=await fetch(`${u}/api/jobs`,{headers:{Accept:"application/json"}});if(!s.ok)throw new Error(`Local jobs HTTP ${s.status}`);const i=(await s.json()).find(L=>L.id===r);if(!i)throw new Error("Local job disappeared from the anvil rack.");if(t({title:i.title||e.title,phase:p(i.phase),progress:i.progress,status:i.status,error:i.error??void 0,output:i.output??void 0}),i.phase==="finished"){i.output&&t({status:`Ready — ${i.output}`,output:i.output});return}if(i.phase==="failed")throw new Error(i.error||i.status||"Local forge failed.")}}async function q(e,t){if(t({phase:"prospecting",progress:.1,status:"Companion offline — trying anonymous cloud…"}),!P(e.url))throw new Error("Cloud fallback supports YouTube links only. Start vidforge-ui for full forging.");const n=m(e.alloy);t({phase:"smelting",progress:.35,status:`Smelting ${n.name} in the cloud…`});let r;try{const s=await fetch(`${y}/api/forge`,{method:"POST",headers:{Accept:"application/json","Content-Type":"application/json"},body:JSON.stringify({url:e.url,alloy:e.alloy})});if(r=await s.json(),!s.ok)throw new Error(r.error||`Cloud forge HTTP ${s.status}`)}catch(s){const l=s instanceof Error?s.message:String(s);throw l==="Load failed"||l==="Failed to fetch"||l.includes("NetworkError")?new Error('Cloud unreachable and companion offline. Start: export PATH="$HOME/.local/bin:$PATH" && vidforge-ui'):s instanceof Error?s:new Error(l)}if(r.error)throw new Error(r.error);if(!r.downloadUrl)throw new Error("Cloud forge returned no download URL.");t({phase:"quenching",progress:.8,title:r.title||e.title,status:r.quality?`Quenching ${r.quality}…`:"Opening download…"}),t({phase:"finished",progress:1,title:r.title||e.title,downloadUrl:r.downloadUrl,status:"Ready — tap Download (cloud stream)"}),window.open(r.downloadUrl,"_blank","noopener,noreferrer")}async function A(e){await fetch(`${u}/api/reveal`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({path:e})})}function p(e){switch(e){case"queued":case"prospecting":case"smelting":case"quenching":case"finished":case"failed":return e;default:return"prospecting"}}function P(e){try{const t=new URL(e),o=t.hostname.replace(/^www\./,"");if(o==="youtu.be")return t.pathname.split("/").filter(Boolean)[0]??null;if(o.endsWith("youtube.com")||o.endsWith("youtube-nocookie.com")||o==="m.youtube.com"){if(t.searchParams.get("v"))return t.searchParams.get("v");const n=t.pathname.split("/").filter(Boolean);if(["shorts","embed","live"].includes(n[0]??""))return n[1]??null}}catch{}return/^[\w-]{11}$/.test(e.trim())?e.trim():null}function C(e){return e&&e.charAt(0).toUpperCase()+e.slice(1)}function O(e){return new Promise(t=>setTimeout(t,e))}const v=document.querySelector("#app");if(!v)throw new Error("#app missing");const a={selected:"archive-pure",jobs:[],engine:{mode:"offline",label:"Checking forge…"},busy:!1};v.innerHTML=`
  <div class="stage">
    <div class="glow" aria-hidden="true"></div>
    <div class="sparks" id="sparks" aria-hidden="true"></div>
    <div class="shell">
      <header class="topbar">
        <div class="brand">
          <strong>VIDFORGE</strong>
          <span>Pages UI · local companion with browser cookies · v5</span>
        </div>
      </header>

      <section class="furnace" aria-label="Forge controls">
        <div class="field-label">Ore</div>
        <div class="ore-row">
          <input id="url" type="url" placeholder="Paste a YouTube URL…" autocomplete="off" />
          <button class="strike" id="strike" type="button">Strike</button>
        </div>

        <div class="field-label">Alloy</div>
        <div class="ingots" id="ingots" role="radiogroup" aria-label="Alloy"></div>

        <div class="statusline">
          <div class="pill"><span class="dot" id="engineDot"></span><span id="engineText">Checking forge…</span></div>
          <span>Prefer local · cookies</span>
        </div>
      </section>

      <section class="rack" aria-label="Job queue">
        <div class="rack-head">
          <h2>ANVIL RACK</h2>
          <button class="text-btn" id="clear" type="button">Clear finished</button>
        </div>
        <div id="jobs"></div>
      </section>

      <footer class="footer">
        <a href="https://github.com/sbacaro/VidForge" target="_blank" rel="noreferrer">GitHub</a>
        <span>·</span>
        <span id="footerHint">Run vidforge-ui for full quality</span>
      </footer>
    </div>
  </div>
`;H();I();w();c();k();setInterval(()=>{k()},12e3);function H(){const e=document.querySelector("#sparks");if(e)for(let t=0;t<24;t++){const o=document.createElement("span");o.className="spark",o.style.left=`${Math.random()*100}%`,o.style.animationDuration=`${7+Math.random()*10}s`,o.style.animationDelay=`${Math.random()*8}s`,o.style.opacity=String(.25+Math.random()*.5),e.appendChild(o)}}function I(){document.querySelector("#strike")?.addEventListener("click",()=>{h()}),document.querySelector("#url")?.addEventListener("keydown",e=>{e.key==="Enter"&&h()}),document.querySelector("#clear")?.addEventListener("click",()=>{a.jobs=a.jobs.filter(e=>e.phase!=="finished"&&e.phase!=="failed"),c()})}function w(){const e=document.querySelector("#ingots");if(e){e.innerHTML="";for(const t of f){const o=document.createElement("button");o.type="button",o.className="ingot",o.setAttribute("role","radio"),o.setAttribute("aria-checked",t.id===a.selected?"true":"false"),o.innerHTML=`
      <span class="mark">${t.mark}</span>
      <strong>${t.name}</strong>
      <p>${t.blurb}</p>
    `,o.addEventListener("click",()=>{a.selected=t.id,w()}),e.appendChild(o)}}}function c(){const e=document.querySelector("#jobs");if(e){if(!a.jobs.length){e.innerHTML=`
      <div class="empty">
        <strong>The anvil is cold.</strong>
        Paste a YouTube link and strike. Best results with the local companion (browser cookies).
      </div>
    `;return}e.innerHTML=a.jobs.map(t=>{const o=m(t.alloy);let n="";return t.downloadUrl?n=`<a href="${g(t.downloadUrl)}" target="_blank" rel="noreferrer">Download</a>`:t.output&&(n=`<button type="button" class="text-btn reveal" data-path="${g(t.output)}">Reveal in Finder</button>`),`
        <article class="job">
          <div class="job-top">
            <div>
              <strong>${d(t.title)}</strong>
              <div class="meta">${d(o.name)}</div>
            </div>
            <div class="phase ${t.phase}">${T(t.phase)}</div>
          </div>
          <div class="heat"><i style="width:${Math.round(t.progress*100)}%"></i></div>
          <div class="job-foot">
            <p>${d(t.status)}</p>
            ${n}
          </div>
        </article>
      `}).join(""),e.querySelectorAll("button.reveal").forEach(t=>{t.addEventListener("click",()=>{const o=t.dataset.path;o&&A(o)})})}}async function k(){a.engine=await b();const e=document.querySelector("#engineDot"),t=document.querySelector("#engineText"),o=document.querySelector("#footerHint");if(e){const n=a.engine.mode==="local"||a.engine.mode==="cloud";e.classList.toggle("on",n&&a.engine.mode==="local"),e.classList.toggle("off",!n||a.engine.mode==="cloud"),a.engine.mode==="cloud"&&(e.classList.add("off"),e.classList.remove("on"))}t&&(t.textContent=a.engine.label),o&&(o.textContent=a.engine.mode==="local"?a.engine.cookiesOk?`Local companion · ${a.engine.cookiesBrowser??"browser"} cookies`:"Local companion · grant cookie access if forge fails":'Run: export PATH="$HOME/.local/bin:$PATH" && vidforge-ui')}async function h(){const e=document.querySelector("#url"),t=e.value.trim();if(!t||a.busy)return;const o={id:E(),url:t,alloy:a.selected,title:"Unknown ore",phase:"queued",progress:.02,status:"Heating…",createdAt:Date.now()};a.jobs.unshift(o),e.value="",a.busy=!0,document.querySelector("#strike").disabled=!0,c();const n=r=>{Object.assign(o,r),c()};try{await $(o,n)}catch(r){n({phase:"failed",progress:0,status:r instanceof Error?r.message:String(r),error:r instanceof Error?r.message:String(r)})}finally{a.busy=!1,document.querySelector("#strike").disabled=!1,c()}}function d(e){return e.replace(/[&<>"']/g,t=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[t])}function g(e){return d(e)}
