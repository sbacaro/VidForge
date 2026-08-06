(function(){const t=document.createElement("link").relList;if(t&&t.supports&&t.supports("modulepreload"))return;for(const o of document.querySelectorAll('link[rel="modulepreload"]'))r(o);new MutationObserver(o=>{for(const i of o)if(i.type==="childList")for(const c of i.addedNodes)c.tagName==="LINK"&&c.rel==="modulepreload"&&r(c)}).observe(document,{childList:!0,subtree:!0});function n(o){const i={};return o.integrity&&(i.integrity=o.integrity),o.referrerPolicy&&(i.referrerPolicy=o.referrerPolicy),o.crossOrigin==="use-credentials"?i.credentials="include":o.crossOrigin==="anonymous"?i.credentials="omit":i.credentials="same-origin",i}function r(o){if(o.ep)return;o.ep=!0;const i=n(o);fetch(o.href,i)}})();const b=[{id:"archive-pure",name:"Archive Pure",mark:"I",blurb:"Highest fidelity. Remux when possible.",quality:"max"},{id:"crystal",name:"Crystal",mark:"II",blurb:"Near-lossless clarity for keepers.",quality:"max"},{id:"tempered",name:"Tempered",mark:"III",blurb:"Sharp everyday playback at 1080p.",quality:"1080"},{id:"audio-ingot",name:"Audio Ingot",mark:"IV",blurb:"Strip the image. Keep the sound.",quality:"audio"}],y={engine:"local",localBase:"http://127.0.0.1:8742",apiBase:"",apiKey:""},w="vidforge.pages.v2";function E(){try{const e=localStorage.getItem(w);return e?{...y,...JSON.parse(e)}:{...y}}catch{return{...y}}}function I(e){localStorage.setItem(w,JSON.stringify(e))}function k(e){return b.find(t=>t.id===e)??b[0]}function O(){return crypto.randomUUID()}function P(e){return new Promise(t=>setTimeout(t,e))}function C(e){switch(e){case"queued":return"Queued";case"prospecting":return"Prospecting";case"smelting":return"Smelting";case"quenching":return"Quenching";case"finished":return"Forged";case"failed":return"Cracked"}}async function $(e){try{const t=new AbortController,n=setTimeout(()=>t.abort(),800),r=await fetch(`${v(e)}/api/jobs`,{signal:t.signal,mode:"cors"});return clearTimeout(n),r.ok}catch{return!1}}async function M(e,t,n){const r=v(e.localBase);n({phase:"prospecting",progress:.08,status:"Connecting to local companion…"});const o=await fetch(`${r}/api/forge`,{method:"POST",mode:"cors",headers:{"Content-Type":"application/json"},body:JSON.stringify({url:t.url,alloy:t.alloy})});if(!o.ok)throw new Error(`Local companion HTTP ${o.status}`);const c=(await o.json()).id;for(let u=0;u<900;u++){await P(1e3);const l=await(await fetch(`${r}/api/jobs`,{mode:"cors"})).json(),s=l.find(d=>d.id===c)??l.find(d=>d.url===t.url);if(s){if(n({title:s.title||t.title,phase:x(s.phase),progress:s.progress??0,status:s.status,outputPath:s.output,error:s.error}),s.phase==="finished"){n({phase:"finished",progress:1,status:"Ready on your Mac"});return}if(s.phase==="failed")throw new Error(s.error||s.status||"Local forge failed")}}throw new Error("Timed out waiting for local companion.")}async function B(e,t,n){const r=v(e.apiBase);if(!r)throw new Error("Set a Cobalt-compatible API base in Settings.");const o=k(t.alloy);n({phase:"smelting",progress:.2,status:"Requesting streams…"});const i={url:t.url,filenameStyle:"pretty"};o.quality==="audio"?(i.downloadMode="audio",i.audioFormat="best"):(i.downloadMode="auto",i.videoQuality=o.quality==="1080"?"1080":"max");const c={Accept:"application/json","Content-Type":"application/json"};e.apiKey.trim()&&(c.Authorization=`Api-Key ${e.apiKey.trim()}`);const u=await fetch(`${r}/`,{method:"POST",mode:"cors",headers:c,body:JSON.stringify(i)}),l=await u.json().catch(()=>({}));if(!u.ok||l.status==="error"){const p=l.error?.code||l.text||`HTTP ${u.status}`;throw String(p).includes("auth")||u.status===401||u.status===403?new Error("API auth required. Official Cobalt blocks third-party apps — use your own instance + Api-Key, or the local companion."):new Error(l.error?.message||String(p))}let s=l.url||l.tunnel,d=l.filename||t.title;if(l.status==="picker"&&l.picker?.length){const p=l.picker.find(T=>T.type==="video")??l.picker[0];s=p.url,d=p.filename||d}if(!s)throw new Error("API returned no download URL.");n({phase:"finished",progress:1,title:d,downloadUrl:s,status:"Ready — download started in a new tab"}),window.open(s,"_blank","noopener,noreferrer")}function x(e){switch(e){case"queued":case"prospecting":case"smelting":case"quenching":case"finished":case"failed":return e;default:return"smelting"}}function v(e){return e.replace(/\/+$/,"")}function K(e,t){return e==="local"?t?"Local companion online — max quality on this Mac.":"Local companion offline. Run: vidforge-ui":"Custom Cobalt-compatible API (needs your instance URL and usually an Api-Key)."}const q=document.querySelector("#app");if(!q)throw new Error("#app missing");const a={settings:E(),selected:"archive-pure",jobs:[],localOnline:!1,busy:!1,settingsOpen:!1};q.innerHTML=`
  <div class="stage">
    <div class="glow" aria-hidden="true"></div>
    <div class="sparks" id="sparks" aria-hidden="true"></div>
    <div class="shell">
      <header class="topbar">
        <div class="brand">
          <strong>VIDFORGE</strong>
          <span>Feed a URL. Choose an alloy. Strike.</span>
        </div>
        <button class="icon-btn" id="openSettings" type="button" aria-label="Settings">⚙</button>
      </header>

      <section class="furnace" aria-label="Forge controls">
        <div class="field-label">Ore</div>
        <div class="ore-row">
          <input id="url" type="url" placeholder="https://… paste any supported video link" autocomplete="off" />
          <button class="strike" id="strike" type="button">Strike</button>
        </div>

        <div class="field-label">Alloy</div>
        <div class="ingots" id="ingots" role="radiogroup" aria-label="Alloy"></div>

        <div class="statusline">
          <div class="pill"><span class="dot" id="engineDot"></span><span id="engineText">Checking forge…</span></div>
          <span id="hint">GitHub Pages is the UI. Your Mac runs the fire.</span>
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
        <a href="https://github.com/sbacaro/VidForge#install-mac-companion-no-xcode" target="_blank" rel="noreferrer">Install companion</a>
      </footer>
    </div>

    <div class="drawer" id="drawer" hidden>
      <div class="drawer-panel" role="dialog" aria-modal="true" aria-labelledby="settingsTitle">
        <h3 id="settingsTitle">SETTINGS</h3>
        <label>
          Engine
          <select id="engine">
            <option value="local">Local companion (recommended)</option>
            <option value="custom-api">Custom Cobalt-compatible API</option>
          </select>
        </label>
        <label>
          Local companion URL
          <input id="localBase" type="url" />
        </label>
        <label>
          Custom API base
          <input id="apiBase" type="url" placeholder="https://your-cobalt-instance.example" />
        </label>
        <label>
          API key (optional)
          <input id="apiKey" type="password" autocomplete="off" placeholder="Api-Key token" />
        </label>
        <p class="meta">
          Official api.cobalt.tools requires JWT and is not for third-party apps.
          Use the local companion, or your own API instance.
        </p>
        <div class="drawer-actions">
          <button class="ghost" id="closeSettings" type="button">Close</button>
          <button class="strike" id="saveSettings" type="button">Save</button>
        </div>
      </div>
    </div>
  </div>
`;H();N();A();m();L();g();setInterval(g,4e3);function H(){const e=document.querySelector("#sparks");if(e)for(let t=0;t<24;t++){const n=document.createElement("span");n.className="spark",n.style.left=`${Math.random()*100}%`,n.style.animationDuration=`${7+Math.random()*10}s`,n.style.animationDelay=`${Math.random()*8}s`,n.style.opacity=String(.25+Math.random()*.5),e.appendChild(n)}}function N(){document.querySelector("#strike")?.addEventListener("click",()=>{S()}),document.querySelector("#url")?.addEventListener("keydown",e=>{e.key==="Enter"&&S()}),document.querySelector("#clear")?.addEventListener("click",()=>{a.jobs=a.jobs.filter(e=>e.phase!=="finished"&&e.phase!=="failed"),m()}),document.querySelector("#openSettings")?.addEventListener("click",()=>{a.settingsOpen=!0,L(),document.querySelector("#drawer")?.removeAttribute("hidden")}),document.querySelector("#closeSettings")?.addEventListener("click",h),document.querySelector("#drawer")?.addEventListener("click",e=>{e.target===document.querySelector("#drawer")&&h()}),document.querySelector("#saveSettings")?.addEventListener("click",()=>{const e=document.querySelector("#engine").value,t=document.querySelector("#localBase").value.trim(),n=document.querySelector("#apiBase").value.trim(),r=document.querySelector("#apiKey").value.trim();a.settings={engine:e,localBase:t,apiBase:n,apiKey:r},I(a.settings),h(),g()})}function h(){a.settingsOpen=!1,document.querySelector("#drawer")?.setAttribute("hidden","")}function L(){document.querySelector("#engine").value=a.settings.engine,document.querySelector("#localBase").value=a.settings.localBase,document.querySelector("#apiBase").value=a.settings.apiBase,document.querySelector("#apiKey").value=a.settings.apiKey}function A(){const e=document.querySelector("#ingots");if(e){e.innerHTML="";for(const t of b){const n=document.createElement("button");n.type="button",n.className="ingot",n.setAttribute("role","radio"),n.setAttribute("aria-checked",t.id===a.selected?"true":"false"),n.innerHTML=`
      <span class="mark">${t.mark}</span>
      <strong>${t.name}</strong>
      <p>${t.blurb}</p>
    `,n.addEventListener("click",()=>{a.selected=t.id,A()}),e.appendChild(n)}}}function m(){const e=document.querySelector("#jobs");if(e){if(!a.jobs.length){e.innerHTML=`
      <div class="empty">
        <strong>The anvil is cold.</strong>
        Drop a link above. For max quality, keep <code>vidforge-ui</code> running on this Mac.
      </div>
    `;return}e.innerHTML=a.jobs.map(t=>{const n=k(t.alloy),r=t.downloadUrl?`<a href="${F(t.downloadUrl)}" target="_blank" rel="noreferrer">Download</a>`:t.outputPath?`<span class="meta">${f(t.outputPath)}</span>`:"";return`
        <article class="job">
          <div class="job-top">
            <div>
              <strong>${f(t.title)}</strong>
              <div class="meta">${f(n.name)}</div>
            </div>
            <div class="phase ${t.phase}">${C(t.phase)}</div>
          </div>
          <div class="heat"><i style="width:${Math.round(t.progress*100)}%"></i></div>
          <div class="job-foot">
            <p>${f(t.status)}</p>
            ${r}
          </div>
        </article>
      `}).join("")}}async function g(){a.localOnline=await $(a.settings.localBase);const e=document.querySelector("#engineDot"),t=document.querySelector("#engineText"),n=document.querySelector("#hint");e&&(e.classList.toggle("on",a.localOnline),e.classList.toggle("off",!a.localOnline&&a.settings.engine==="local")),t&&(t.textContent=K(a.settings.engine,a.localOnline)),n&&(n.textContent=a.settings.engine==="local"?"Pages = remote control. Companion = yt-dlp + ffmpeg on your machine.":"Bring your own Cobalt-compatible instance. Official Cobalt JWT is not supported.")}async function S(){const e=document.querySelector("#url"),t=e.value.trim();if(!t||a.busy)return;const n={id:O(),url:t,alloy:a.selected,title:"Unknown ore",phase:"queued",progress:.02,status:"Heating…",createdAt:Date.now()};a.jobs.unshift(n),e.value="",a.busy=!0,document.querySelector("#strike").disabled=!0,m();const r=o=>{Object.assign(n,o),m()};try{if(await g(),a.settings.engine==="local"){if(!a.localOnline)throw new Error('Local companion offline. In Terminal: export PATH="$HOME/.local/bin:$PATH" && vidforge-ui');await M(a.settings,n,r)}else await B(a.settings,n,r)}catch(o){r({phase:"failed",progress:0,status:o instanceof Error?o.message:String(o),error:o instanceof Error?o.message:String(o)})}finally{a.busy=!1,document.querySelector("#strike").disabled=!1,m()}}function f(e){return e.replace(/[&<>"']/g,t=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[t])}function F(e){return f(e)}
