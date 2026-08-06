(function(){const t=document.createElement("link").relList;if(t&&t.supports&&t.supports("modulepreload"))return;for(const r of document.querySelectorAll('link[rel="modulepreload"]'))a(r);new MutationObserver(r=>{for(const n of r)if(n.type==="childList")for(const i of n.addedNodes)i.tagName==="LINK"&&i.rel==="modulepreload"&&a(i)}).observe(document,{childList:!0,subtree:!0});function o(r){const n={};return r.integrity&&(n.integrity=r.integrity),r.referrerPolicy&&(n.referrerPolicy=r.referrerPolicy),r.crossOrigin==="use-credentials"?n.credentials="include":r.crossOrigin==="anonymous"?n.credentials="omit":n.credentials="same-origin",n}function a(r){if(r.ep)return;r.ep=!0;const n=o(r);fetch(r.href,n)}})();const d=[{id:"archive-pure",name:"Archive Pure",mark:"I",blurb:"Highest available YouTube stream.",quality:"max"},{id:"crystal",name:"Crystal",mark:"II",blurb:"Top clarity progressive stream.",quality:"max"},{id:"tempered",name:"Tempered",mark:"III",blurb:"Cap around 1080p for everyday use.",quality:"1080"},{id:"audio-ingot",name:"Audio Ingot",mark:"IV",blurb:"Best audio-only track.",quality:"audio"}];function p(e){return d.find(t=>t.id===e)??d[0]}function y(){return crypto.randomUUID()}function v(e){switch(e){case"queued":return"Queued";case"prospecting":return"Prospecting";case"smelting":return"Smelting";case"quenching":return"Quenching";case"finished":return"Forged";case"failed":return"Cracked"}}const f="https://vidforge.samuelbacaro.workers.dev";async function b(){try{const e=await fetch(`${f}/api/health`,{method:"GET",headers:{Accept:"application/json"}});return e.ok?!!(await e.json()).ok:!1}catch{return navigator.onLine}}async function w(e,t){if(t({phase:"prospecting",progress:.1,status:"Reading ore veins in the cloud…"}),!k(e.url))throw new Error("Free cloud engine supports YouTube links only right now.");const a=p(e.alloy);t({phase:"smelting",progress:.35,status:`Smelting ${a.name}…`});let r;try{const n=await fetch(`${f}/api/forge`,{method:"POST",headers:{Accept:"application/json","Content-Type":"application/json"},body:JSON.stringify({url:e.url,alloy:e.alloy})});if(r=await n.json(),!n.ok)throw new Error(r.error||`Cloud forge HTTP ${n.status}`)}catch(n){const i=n instanceof Error?n.message:String(n);throw i==="Load failed"||i==="Failed to fetch"||i.includes("NetworkError")?new Error("Cloud API unreachable. Check your network or try again in a moment."):n instanceof Error?n:new Error(i)}if(r.error)throw new Error(r.error);if(!r.downloadUrl)throw new Error("Cloud forge returned no download URL.");t({phase:"quenching",progress:.8,title:r.title||e.title,status:r.quality?`Quenching ${r.quality}…`:"Opening download…"}),t({phase:"finished",progress:1,title:r.title||e.title,downloadUrl:r.downloadUrl,status:"Ready — tap Download"}),window.open(r.downloadUrl,"_blank","noopener,noreferrer")}function k(e){try{const t=new URL(e),o=t.hostname.replace(/^www\./,"");if(o==="youtu.be")return t.pathname.split("/").filter(Boolean)[0]??null;if(o.endsWith("youtube.com")||o.endsWith("youtube-nocookie.com")||o==="m.youtube.com"){if(t.searchParams.get("v"))return t.searchParams.get("v");const a=t.pathname.split("/").filter(Boolean);if(["shorts","embed","live"].includes(a[0]??""))return a[1]??null}}catch{}return/^[\w-]{11}$/.test(e.trim())?e.trim():null}const h=document.querySelector("#app");if(!h)throw new Error("#app missing");const s={selected:"archive-pure",jobs:[],online:!1,busy:!1};h.innerHTML=`
  <div class="stage">
    <div class="glow" aria-hidden="true"></div>
    <div class="sparks" id="sparks" aria-hidden="true"></div>
    <div class="shell">
      <header class="topbar">
        <div class="brand">
          <strong>VIDFORGE</strong>
          <span>GitHub Pages UI · Cloudflare forge · nothing to install · v4</span>
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
          <span>Worker API · YouTube</span>
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
        <span>No local companion</span>
      </footer>
    </div>
  </div>
`;q();L();g();l();m();setInterval(()=>{m()},2e4);function q(){const e=document.querySelector("#sparks");if(e)for(let t=0;t<24;t++){const o=document.createElement("span");o.className="spark",o.style.left=`${Math.random()*100}%`,o.style.animationDuration=`${7+Math.random()*10}s`,o.style.animationDelay=`${Math.random()*8}s`,o.style.opacity=String(.25+Math.random()*.5),e.appendChild(o)}}function L(){document.querySelector("#strike")?.addEventListener("click",()=>{u()}),document.querySelector("#url")?.addEventListener("keydown",e=>{e.key==="Enter"&&u()}),document.querySelector("#clear")?.addEventListener("click",()=>{s.jobs=s.jobs.filter(e=>e.phase!=="finished"&&e.phase!=="failed"),l()})}function g(){const e=document.querySelector("#ingots");if(e){e.innerHTML="";for(const t of d){const o=document.createElement("button");o.type="button",o.className="ingot",o.setAttribute("role","radio"),o.setAttribute("aria-checked",t.id===s.selected?"true":"false"),o.innerHTML=`
      <span class="mark">${t.mark}</span>
      <strong>${t.name}</strong>
      <p>${t.blurb}</p>
    `,o.addEventListener("click",()=>{s.selected=t.id,g()}),e.appendChild(o)}}}function l(){const e=document.querySelector("#jobs");if(e){if(!s.jobs.length){e.innerHTML=`
      <div class="empty">
        <strong>The anvil is cold.</strong>
        Paste a YouTube link and strike. Runs entirely in your browser via GitHub Pages.
      </div>
    `;return}e.innerHTML=s.jobs.map(t=>{const o=p(t.alloy),a=t.downloadUrl?`<a href="${S(t.downloadUrl)}" target="_blank" rel="noreferrer">Download</a>`:"";return`
        <article class="job">
          <div class="job-top">
            <div>
              <strong>${c(t.title)}</strong>
              <div class="meta">${c(o.name)}</div>
            </div>
            <div class="phase ${t.phase}">${v(t.phase)}</div>
          </div>
          <div class="heat"><i style="width:${Math.round(t.progress*100)}%"></i></div>
          <div class="job-foot">
            <p>${c(t.status)}</p>
            ${a}
          </div>
        </article>
      `}).join("")}}async function m(){s.online=await b();const e=document.querySelector("#engineDot"),t=document.querySelector("#engineText");e&&(e.classList.toggle("on",s.online),e.classList.toggle("off",!s.online)),t&&(t.textContent=s.online?"Cloud forge ready":"Cloud forge offline")}async function u(){const e=document.querySelector("#url"),t=e.value.trim();if(!t||s.busy)return;const o={id:y(),url:t,alloy:s.selected,title:"Unknown ore",phase:"queued",progress:.02,status:"Heating…",createdAt:Date.now()};s.jobs.unshift(o),e.value="",s.busy=!0,document.querySelector("#strike").disabled=!0,l();const a=r=>{Object.assign(o,r),l()};try{await w(o,a)}catch(r){a({phase:"failed",progress:0,status:r instanceof Error?r.message:String(r),error:r instanceof Error?r.message:String(r)})}finally{s.busy=!1,document.querySelector("#strike").disabled=!1,l()}}function c(e){return e.replace(/[&<>"']/g,t=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[t])}function S(e){return c(e)}
